import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'room_geometry.dart';

double _round4(double v) => (v * 10000).round() / 10000;

// ======================================================================
// Model tersimpan (koordinat 0..1 pada lebar, tinggi, dan kedalaman)
// ======================================================================

/// Satu bagian jaring segitiga. Sumbu: x = lebar, y = tinggi (ke atas),
/// z = kedalaman (sumbu y pada denah). Semuanya dalam rentang 0..1.
class MeshPart {
  const MeshPart({
    required this.name,
    required this.vertices,
    required this.triangles,
    this.colorValue,
  });

  final String name;

  /// x, y, z berurutan.
  final List<double> vertices;

  /// Indeks titik, tiga demi tiga.
  final List<int> triangles;

  /// Warna ARGB khusus bagian ini; null = ikut bahan furnitur.
  final int? colorValue;

  int get triangleCount => triangles.length ~/ 3;

  Map<String, dynamic> toJson() => {
    'n': name,
    'v': vertices,
    't': triangles,
    if (colorValue != null) 'c': colorValue,
  };

  static MeshPart? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final v = raw['v'];
    final t = raw['t'];

    if (v is! List || t is! List) return null;

    final verts = <double>[];

    for (final e in v) {
      if (e is! num || !e.isFinite) return null;
      verts.add(e.toDouble());
    }

    if (verts.length % 3 != 0) return null;

    final count = verts.length ~/ 3;
    final tris = <int>[];

    for (final e in t) {
      if (e is! int || e < 0 || e >= count) return null;
      tris.add(e);
    }

    if (tris.length % 3 != 0) return null;

    final name = raw['n'];
    final color = raw['c'];

    return MeshPart(
      name: name is String && name.isNotEmpty ? name : 'part',
      vertices: verts,
      triangles: tris,
      colorValue: color is int ? color : null,
    );
  }
}

class _P {
  const _P(this.x, this.z);

  final double x;
  final double z;
}

/// Model 3D sebuah furnitur: beberapa bagian jaring segitiga.
class FurnitureModel {
  FurnitureModel(this.parts);

  final List<MeshPart> parts;

  Map<String, dynamic>? _json;

  int get triangleCount {
    var n = 0;

    for (final part in parts) {
      n += part.triangleCount;
    }

    return n;
  }

  /// Disimpan sementara agar penyimpanan proyek tidak membangun ulang
  /// puluhan ribu angka setiap kali.
  Map<String, dynamic> toJson() => _json ??= {
    'parts': [for (final p in parts) p.toJson()],
  };

  static FurnitureModel? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final list = raw['parts'];

    if (list is! List) return null;

    final parts = <MeshPart>[];

    for (final e in list) {
      final part = MeshPart.fromJson(e);

      if (part != null && part.triangleCount > 0) parts.add(part);
    }

    if (parts.isEmpty) return null;

    return FurnitureModel(parts);
  }

  /// Jejak tampak atas (selubung cembung), koordinat 0..1. Kosong bila
  /// bentuknya terlalu tipis untuk membentuk poligon.
  List<RoomPoint> footprint() {
    final seen = <int>{};
    final pts = <_P>[];

    for (final part in parts) {
      final v = part.vertices;

      for (var i = 0; i + 2 < v.length; i += 3) {
        final x = v[i];
        final z = v[i + 2];
        final key = (x * 2000).round() * 4001 + (z * 2000).round();

        if (seen.add(key)) pts.add(_P(x, z));
      }
    }

    if (pts.length < 3) return const [];

    pts.sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.z.compareTo(b.z));

    double cross(_P o, _P a, _P b) =>
        (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x);

    final lower = <_P>[];

    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }

      lower.add(p);
    }

    final upper = <_P>[];

    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }

      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();

    var hull = [...lower, ...upper];

    if (hull.length < 3) return const [];

    if (hull.length > 48) {
      final step = (hull.length / 48).ceil();

      hull = [for (var i = 0; i < hull.length; i += step) hull[i]];
    }

    if (hull.length < 3) return const [];

    return [for (final p in hull) RoomPoint(p.x, p.z)];
  }
}

// ======================================================================
// Pembacaan file (jaring mentah)
// ======================================================================

class RawGroup {
  RawGroup(this.name);

  String name;
  final List<int> indices = [];
}

/// Titik x, y, z berurutan dan kelompok segitiga (OBJ: o/g).
class RawMesh {
  RawMesh(this.vertices, this.groups);

  final List<double> vertices;
  final List<RawGroup> groups;

  int get triangleCount {
    var n = 0;

    for (final g in groups) {
      n += g.indices.length ~/ 3;
    }

    return n;
  }
}

const String parseUnsupported = 'unsupported';
const String parseEmpty = 'empty';
const String parseInvalid = 'invalid';

class ParseResult {
  const ParseResult.ok(RawMesh this.mesh) : error = null;
  const ParseResult.fail(String this.error) : mesh = null;

  final RawMesh? mesh;
  final String? error;
}

RawMesh parseObj(String text) {
  final verts = <double>[];
  final groups = <RawGroup>[];

  var current = RawGroup('model');
  groups.add(current);

  var vCount = 0;
  final space = RegExp(r'\s+');

  for (final rawLine in const LineSplitter().convert(text)) {
    final line = rawLine.trim();

    if (line.isEmpty || line.startsWith('#')) continue;

    final parts = line.split(space);
    final tag = parts[0];

    if (tag == 'v') {
      if (parts.length < 4) continue;

      final x = double.tryParse(parts[1]);
      final y = double.tryParse(parts[2]);
      final z = double.tryParse(parts[3]);

      final ok =
          x != null &&
          y != null &&
          z != null &&
          x.isFinite &&
          y.isFinite &&
          z.isFinite;

      verts.addAll(ok ? [x, y, z] : [0.0, 0.0, 0.0]);
      vCount++;
    } else if (tag == 'f') {
      final idx = <int>[];

      for (var i = 1; i < parts.length; i++) {
        final k = int.tryParse(parts[i].split('/')[0]);

        if (k == null || k == 0) {
          idx.clear();
          break;
        }

        final v = k > 0 ? k - 1 : vCount + k;

        if (v < 0 || v >= vCount) {
          idx.clear();
          break;
        }

        idx.add(v);
      }

      for (var i = 1; i + 1 < idx.length; i++) {
        current.indices.addAll([idx[0], idx[i], idx[i + 1]]);
      }
    } else if (tag == 'o' || tag == 'g') {
      final name = parts.length > 1 ? parts.sublist(1).join(' ') : 'part';

      if (current.indices.isEmpty) {
        current.name = name;
      } else {
        current = RawGroup(name);
        groups.add(current);
      }
    }
  }

  return RawMesh(verts, groups);
}

bool _isBinaryStl(Uint8List b) {
  if (b.length < 84) return false;

  final count = ByteData.sublistView(b).getUint32(80, Endian.little);

  return 84 + count * 50 == b.length;
}

RawMesh parseStlBinary(Uint8List b) {
  final data = ByteData.sublistView(b);
  final count = data.getUint32(80, Endian.little);

  final verts = <double>[];
  final group = RawGroup('model');

  var off = 84;

  for (var i = 0; i < count; i++) {
    off += 12; // normal

    for (var k = 0; k < 9; k++) {
      final f = data.getFloat32(off, Endian.little);

      verts.add(f.isFinite ? f : 0.0);
      off += 4;
    }

    off += 2; // atribut

    group.indices.addAll([i * 3, i * 3 + 1, i * 3 + 2]);
  }

  return RawMesh(verts, [group]);
}

RawMesh parseStlAscii(String text) {
  final verts = <double>[];
  final re = RegExp(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)');

  for (final m in re.allMatches(text)) {
    for (var i = 1; i <= 3; i++) {
      final v = double.tryParse(m.group(i)!);

      verts.add(v != null && v.isFinite ? v : 0.0);
    }
  }

  final tris = verts.length ~/ 9;

  verts.removeRange(tris * 9, verts.length);

  final group = RawGroup('model');

  for (var i = 0; i < tris * 3; i++) {
    group.indices.add(i);
  }

  return RawMesh(verts, [group]);
}

bool _isUnsupportedBinary(Uint8List b) {
  if (b.length >= 4 &&
      b[0] == 0x67 &&
      b[1] == 0x6C &&
      b[2] == 0x54 &&
      b[3] == 0x46) {
    return true; // glTF biner (GLB)
  }

  if (b.length >= 2 && b[0] == 0x50 && b[1] == 0x4B) return true; // ZIP

  return false;
}

RawMesh _parseText(String text) {
  if (text.contains('facet') && text.contains('vertex')) {
    return parseStlAscii(text);
  }

  return parseObj(text);
}

/// Membaca file model dari [bytes] atau [text]. Tidak pernah melempar galat.
ParseResult parseModelData({Uint8List? bytes, String? text}) {
  try {
    final RawMesh mesh;

    if (bytes != null) {
      if (_isBinaryStl(bytes)) {
        mesh = parseStlBinary(bytes);
      } else if (_isUnsupportedBinary(bytes)) {
        return const ParseResult.fail(parseUnsupported);
      } else {
        final decoded = utf8.decode(bytes, allowMalformed: true);

        if (decoded.trimLeft().startsWith('{')) {
          return const ParseResult.fail(parseUnsupported);
        }

        mesh = _parseText(decoded);
      }
    } else {
      final t = text ?? '';

      if (t.trimLeft().startsWith('{')) {
        return const ParseResult.fail(parseUnsupported);
      }

      mesh = _parseText(t);
    }

    if (mesh.triangleCount == 0) return const ParseResult.fail(parseEmpty);

    return ParseResult.ok(mesh);
  } catch (_) {
    return const ParseResult.fail(parseInvalid);
  }
}

// ======================================================================
// Membangun model: orientasi, normalisasi, penyederhanaan
// ======================================================================

class BuiltModel {
  const BuiltModel({
    required this.model,
    required this.sizeX,
    required this.sizeY,
    required this.sizeZ,
    required this.originalTriangles,
  });

  final FurnitureModel model;

  /// Ukuran asli dalam satuan file, setelah orientasi.
  final double sizeX;
  final double sizeY;
  final double sizeZ;

  final int originalTriangles;

  int get triangles => model.triangleCount;
}

class _Clustered {
  const _Clustered(this.map, this.pos);

  final Int32List map;
  final List<double> pos;
}

_Clustered _cluster(
  Float64List xs,
  Float64List ys,
  Float64List zs,
  Uint8List used,
  int grid,
) {
  final n = xs.length;
  final map = Int32List(n)..fillRange(0, n, -1);
  final ids = <int, int>{};
  final sums = <double>[];
  final counts = <int>[];
  final top = grid - 1;

  for (var i = 0; i < n; i++) {
    if (used[i] == 0) continue;

    final ix = (xs[i] * grid).floor().clamp(0, top).toInt();
    final iy = (ys[i] * grid).floor().clamp(0, top).toInt();
    final iz = (zs[i] * grid).floor().clamp(0, top).toInt();

    final key = (ix * grid + iy) * grid + iz;

    var id = ids[key];

    if (id == null) {
      id = counts.length;
      ids[key] = id;
      sums.addAll([0.0, 0.0, 0.0]);
      counts.add(0);
    }

    sums[id * 3] += xs[i];
    sums[id * 3 + 1] += ys[i];
    sums[id * 3 + 2] += zs[i];
    counts[id]++;
    map[i] = id;
  }

  final pos = List<double>.filled(counts.length * 3, 0.0);

  for (var c = 0; c < counts.length; c++) {
    pos[c * 3] = sums[c * 3] / counts[c];
    pos[c * 3 + 1] = sums[c * 3 + 1] / counts[c];
    pos[c * 3 + 2] = sums[c * 3 + 2] / counts[c];
  }

  return _Clustered(map, pos);
}

int _countTriangles(RawMesh raw, Int32List map) {
  var count = 0;

  for (final g in raw.groups) {
    final idx = g.indices;

    for (var t = 0; t + 2 < idx.length; t += 3) {
      final a = map[idx[t]];
      final b = map[idx[t + 1]];
      final c = map[idx[t + 2]];

      if (a != b && b != c && a != c) count++;
    }
  }

  return count;
}

void _limitParts(List<MeshPart> parts, int limit) {
  while (parts.length > limit) {
    final b = parts.removeLast();
    final a = parts.removeLast();
    final offset = a.vertices.length ~/ 3;

    parts.add(
      MeshPart(
        name: a.name,
        vertices: [...a.vertices, ...b.vertices],
        triangles: [...a.triangles, for (final i in b.triangles) i + offset],
        colorValue: a.colorValue,
      ),
    );
  }
}

/// Mengubah jaring mentah menjadi model tersimpan.
/// [zUp]: sumbu atas model adalah Z (umum pada CAD dan STL).
/// [quarterTurns]: putaran 90° pada sumbu tegak.
/// [maxTriangles]: batas segitiga; di atasnya model disederhanakan.
BuiltModel? buildModel(
  RawMesh raw, {
  required bool zUp,
  required int quarterTurns,
  required int maxTriangles,
}) {
  final n = raw.vertices.length ~/ 3;

  if (n == 0) return null;

  final xs = Float64List(n);
  final ys = Float64List(n);
  final zs = Float64List(n);
  final used = Uint8List(n);

  for (final g in raw.groups) {
    for (final i in g.indices) {
      if (i >= 0 && i < n) used[i] = 1;
    }
  }

  final turns = quarterTurns % 4;

  var minX = double.infinity;
  var minY = double.infinity;
  var minZ = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;
  var maxZ = -double.infinity;

  for (var i = 0; i < n; i++) {
    var x = raw.vertices[i * 3];
    var y = raw.vertices[i * 3 + 1];
    var z = raw.vertices[i * 3 + 2];

    if (zUp) {
      final t = y;
      y = z;
      z = -t;
    }

    for (var k = 0; k < turns; k++) {
      final t = x;
      x = -z;
      z = t;
    }

    xs[i] = x;
    ys[i] = y;
    zs[i] = z;

    if (used[i] == 1) {
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      minZ = math.min(minZ, z);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      maxZ = math.max(maxZ, z);
    }
  }

  if (minX == double.infinity) return null;

  final ex = maxX - minX;
  final ey = maxY - minY;
  final ez = maxZ - minZ;

  final sx = ex > 1e-9 ? 1 / ex : 0.0;
  final sy = ey > 1e-9 ? 1 / ey : 0.0;
  final sz = ez > 1e-9 ? 1 / ez : 0.0;

  for (var i = 0; i < n; i++) {
    if (used[i] == 0) continue;

    xs[i] = (xs[i] - minX) * sx;
    ys[i] = (ys[i] - minY) * sy;
    zs[i] = (zs[i] - minZ) * sz;
  }

  final original = raw.triangleCount;

  // Penyatuan titik kembar (STL menyimpan tiap segitiga sendiri-sendiri).
  var clustered = _cluster(xs, ys, zs, used, 4096);
  var total = _countTriangles(raw, clustered.map);

  var grid = 512;

  while (total > maxTriangles && grid >= 4) {
    clustered = _cluster(xs, ys, zs, used, grid);
    total = _countTriangles(raw, clustered.map);
    grid = (grid * 0.8).floor();
  }

  if (total == 0) return null;

  final parts = <MeshPart>[];

  for (final g in raw.groups) {
    final local = <int, int>{};
    final verts = <double>[];
    final tris = <int>[];
    final idx = g.indices;

    for (var t = 0; t + 2 < idx.length; t += 3) {
      final a = clustered.map[idx[t]];
      final b = clustered.map[idx[t + 1]];
      final c = clustered.map[idx[t + 2]];

      if (a == b || b == c || a == c) continue;

      for (final v in [a, b, c]) {
        var li = local[v];

        if (li == null) {
          li = verts.length ~/ 3;
          local[v] = li;

          verts.addAll([
            _round4(clustered.pos[v * 3]),
            _round4(clustered.pos[v * 3 + 1]),
            _round4(clustered.pos[v * 3 + 2]),
          ]);
        }

        tris.add(li);
      }
    }

    if (tris.isNotEmpty) {
      parts.add(MeshPart(name: g.name, vertices: verts, triangles: tris));
    }
  }

  if (parts.isEmpty) return null;

  _limitParts(parts, 40);

  return BuiltModel(
    model: FurnitureModel(parts),
    sizeX: ex,
    sizeY: ey,
    sizeZ: ez,
    originalTriangles: original,
  );
}
