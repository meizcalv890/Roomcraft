import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'furniture_item.dart';
import 'furniture_material.dart';
import 'room_geometry.dart';
import 'room_path.dart';
import 'room_surface.dart';

/// Awalan id untuk bentuk bayangan objek dinding di denah.
const String wallFootprintPrefix = 'wall:';

bool isWallFootprintId(String? id) =>
    id != null && id.startsWith(wallFootprintPrefix);

/// Jejak objek dinding pada denah lantai, plus rentang ketinggiannya.
class WallFootprint {
  const WallFootprint({
    required this.item,
    required this.polygon,
    required this.bottomCm,
    required this.topCm,
    required this.label,
  });

  /// Furnitur bayangan untuk digambar di kanvas denah.
  final FurnitureItem item;

  /// Sudut jejak pada denah (cm).
  final List<Offset> polygon;

  /// Tinggi bawah dan atas dari lantai (cm).
  final double bottomCm;
  final double topCm;

  final String label;
}

class WallHit {
  const WallHit({required this.wall, required this.floor});

  final WallFootprint wall;
  final FurnitureItem floor;
}

/// Sudut furnitur lantai pada denah (cm), sudah memperhitungkan rotasi.
List<Offset> floorPolygon(FurnitureItem item) => [
  for (final p in item.localPoints)
    Offset(
      item.xCm + (item.isRotated ? item.lengthCm - p.y : p.x),
      item.yCm + (item.isRotated ? p.x : p.y),
    ),
];

double _signedArea(List<Offset> pts) {
  var sum = 0.0;

  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }

  return sum / 2;
}

/// Mengubah objek pada dinding yang tertaut ke sisi lurus denah menjadi
/// bentuk di denah. Aturannya sama dengan tampilan 3D.
List<WallFootprint> buildWallFootprints({
  required RoomPath path,
  required List<RoomSurface> surfaces,
}) {
  if (path.length < 3) return const [];

  final plan = [for (var i = 0; i < path.length; i++) path.p(i)];
  final area = _signedArea(plan);
  final result = <WallFootprint>[];

  for (final surface in surfaces) {
    final edge = surface.edgeIndex;

    if (surface.kind != SurfaceKind.wall || edge < 0 || edge >= path.length) {
      continue;
    }

    if (path.arcOf(edge) != null) continue;

    final a = path.p(edge);
    final b = path.p(edge + 1);
    final len = (b - a).distance;

    if (len < 1) continue;

    final u = (b - a) / len;

    // Normal ke dalam ruangan.
    var n = Offset(-u.dy, u.dx);

    if (area < 0) n = -n;

    // Arah "kanan" bagi orang yang berdiri di dalam menghadap dinding.
    final right = Offset(n.dy, -n.dx);
    final forward = right.dx * u.dx + right.dy * u.dy > 0;

    final start = forward ? a : b;
    final dir = forward ? u : -u;

    for (final item in surface.items) {
      final x0 = item.xCm;

      if (x0 >= len) continue;

      final x1 = math.min(item.rightCm, len);

      if (x1 - x0 < 0.5) continue;

      final bottom = math.max(
        0.0,
        surface.heightCm - (item.yCm + item.effectiveLengthCm),
      );
      final top = bottom + item.effectiveLengthCm;

      final double depth;

      if (item.openingKind != null) {
        depth = 2;
      } else {
        depth = item.heightCm > 0
            ? item.heightCm.clamp(1.0, 100.0).toDouble()
            : 5.0;
      }

      final p0 = start + dir * x0;
      final p1 = start + dir * x1;
      final polygon = [p0, p1, p1 + n * depth, p0 + n * depth];

      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = -double.infinity;
      var maxY = -double.infinity;

      for (final p in polygon) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }

      final w = math.max(0.5, maxX - minX);
      final h = math.max(0.5, maxY - minY);

      final ghost = FurnitureItem(
        id: '$wallFootprintPrefix${surface.id}:${item.id}',
        type: FurnitureType.custom,
        xCm: minX,
        yCm: minY,
        widthCm: w,
        lengthCm: h,
        shape: FurnitureShape.polygon,
        customPoints: [
          for (final p in polygon)
            RoomPoint((p.dx - minX) / w, (p.dy - minY) / h),
        ],
        customName: item.displayName,
        material: item.material,
      );

      result.add(
        WallFootprint(
          item: ghost,
          polygon: polygon,
          bottomCm: bottom,
          topCm: top,
          label: item.displayName,
        ),
      );
    }
  }

  return result;
}

/// Objek dinding yang benar-benar bersentuhan dengan furnitur lantai:
/// jejaknya tumpang tindih di denah DAN furnitur lantai cukup tinggi untuk
/// mencapai bagian bawah objek dinding.
List<WallHit> findWallHits(
  List<WallFootprint> walls,
  List<FurnitureItem> floorItems,
) {
  final hits = <WallHit>[];

  for (final wall in walls) {
    for (final floor in floorItems) {
      // Furnitur lantai lebih rendah dari bawah objek dinding: lewat di bawah.
      if (floor.effectiveHeightCm <= wall.bottomCm) continue;

      if (polygonsOverlap(wall.polygon, floorPolygon(floor))) {
        hits.add(WallHit(wall: wall, floor: floor));
      }
    }
  }

  return hits;
}

// ----------------------------------------------------------------------
// Geometri poligon sederhana
// ----------------------------------------------------------------------

class _Box {
  _Box(List<Offset> pts) {
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }

  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;
}

Offset _centroid(List<Offset> pts) {
  var x = 0.0;
  var y = 0.0;

  for (final p in pts) {
    x += p.dx;
    y += p.dy;
  }

  return Offset(x / pts.length, y / pts.length);
}

double _orient(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

bool _segmentsCross(Offset p1, Offset p2, Offset p3, Offset p4) {
  const eps = 1e-3;

  final d1 = _orient(p3, p4, p1);
  final d2 = _orient(p3, p4, p2);
  final d3 = _orient(p1, p2, p3);
  final d4 = _orient(p1, p2, p4);

  return ((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) &&
      ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps));
}

bool _contains(List<Offset> poly, Offset p) {
  var inside = false;

  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i];
    final b = poly[j];

    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }

  return inside;
}

/// Titik digeser sedikit ke dalam agar titik di tepi tidak ambigu.
Offset _nudge(Offset p, Offset center) => p + (center - p) * 0.03;

/// Apakah dua poligon saling menimpa. Hanya bersinggungan tidak dihitung.
bool polygonsOverlap(List<Offset> a, List<Offset> b) {
  if (a.length < 3 || b.length < 3) return false;

  final boxA = _Box(a);
  final boxB = _Box(b);
  const eps = 0.5;

  if (boxA.maxX - eps <= boxB.minX ||
      boxB.maxX - eps <= boxA.minX ||
      boxA.maxY - eps <= boxB.minY ||
      boxB.maxY - eps <= boxA.minY) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      if (_segmentsCross(
        a[i],
        a[(i + 1) % a.length],
        b[j],
        b[(j + 1) % b.length],
      )) {
        return true;
      }
    }
  }

  final ca = _centroid(a);
  final cb = _centroid(b);

  if (_contains(b, ca) || _contains(a, cb)) return true;

  for (final p in a) {
    if (_contains(b, _nudge(p, ca))) return true;
  }

  for (final p in b) {
    if (_contains(a, _nudge(p, cb))) return true;
  }

  return false;
}
