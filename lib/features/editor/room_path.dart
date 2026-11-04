import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'room_geometry.dart';

/// Satu titik sudut jalur ruangan, beserta jenis sisi yang keluar darinya
/// menuju titik berikutnya.
class PathNode {
  const PathNode(this.x, this.y, {this.bulge = 0});

  final double x;
  final double y;

  /// 0 = sisi lurus. Selain itu busur dengan bulge = tan(sudut / 4).
  /// Tanda bulge menentukan ke sisi mana busur melengkung.
  final double bulge;

  bool get isArc => bulge.abs() > 1e-6;

  PathNode copyWith({double? x, double? y, double? bulge}) {
    return PathNode(x ?? this.x, y ?? this.y, bulge: bulge ?? this.bulge);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'bulge': bulge};

  static double _num(Object? value, double fallback) {
    if (value is num && value.isFinite) return value.toDouble();
    return fallback;
  }

  factory PathNode.fromJson(Map<String, dynamic> json) {
    return PathNode(
      _num(json['x'], 0),
      _num(json['y'], 0),
      bulge: _num(
        json['bulge'],
        0,
      ).clamp(-RoomPath.maxBulge, RoomPath.maxBulge).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PathNode && other.x == x && other.y == y && other.bulge == bulge;

  @override
  int get hashCode => Object.hash(x, y, bulge);
}

/// Geometri busur lingkaran sebuah sisi.
class ArcInfo {
  const ArcInfo({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweep,
  });

  final Offset center;
  final double radius;
  final double startAngle;

  /// Sudut sapuan bertanda (radian).
  final double sweep;

  double get length => radius * sweep.abs();

  Offset pointAtFraction(double t) {
    final angle = startAngle + sweep * t;

    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }
}

class PathBounds {
  const PathBounds(this.minX, this.minY, this.maxX, this.maxY);

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
}

enum PathIssue { none, tooFewNodes, shortEdge, selfIntersecting }

/// Bentuk tertutup yang tersusun dari sisi lurus dan busur.
/// Semua ukuran dalam sentimeter. Objek ini tidak dapat diubah (immutable);
/// setiap operasi menghasilkan RoomPath baru.
class RoomPath {
  const RoomPath(this.nodes);

  final List<PathNode> nodes;

  static const double maxBulge = 4;
  static const double minEdgeCm = 1;

  int get length => nodes.length;

  // ------------------------------------------------------------------
  // Pembuat bentuk dasar
  // ------------------------------------------------------------------

  static RoomPath rectangle(double w, double l) {
    return RoomPath([
      PathNode(0, 0),
      PathNode(w, 0),
      PathNode(w, l),
      PathNode(0, l),
    ]);
  }

  /// Persegi panjang dengan empat pojok membulat.
  static RoomPath roundedRect(double w, double l, double radius) {
    final maxR = math.max(0.0, math.min(w, l) / 2 - 1);
    final r = radius.clamp(0.0, maxR).toDouble();

    if (r < 1) return rectangle(w, l);

    // Pojok membulat melengkung ke luar. Untuk jalur searah jarum jam
    // (luas bertanda positif), arah luar berarti bulge negatif.
    final k = -math.tan(math.pi / 8);

    return RoomPath([
      PathNode(r, 0),
      PathNode(w - r, 0, bulge: k),
      PathNode(w, r),
      PathNode(w, l - r, bulge: k),
      PathNode(w - r, l),
      PathNode(r, l, bulge: k),
      PathNode(0, l - r),
      PathNode(0, r, bulge: k),
    ]);
  }

  /// Lingkaran dari dua busur setengah lingkaran.
  static RoomPath circle(double diameter) {
    final d = math.max(10.0, diameter);
    final r = d / 2;

    return RoomPath([PathNode(0, r, bulge: 1), PathNode(d, r, bulge: 1)]);
  }

  /// Mengubah daftar titik (poligon lurus) menjadi jalur.
  static RoomPath fromPoints(List<RoomPoint> points) {
    final nodes = <PathNode>[];

    for (final point in points) {
      if (nodes.isNotEmpty &&
          (nodes.last.x - point.x).abs() < 1e-6 &&
          (nodes.last.y - point.y).abs() < 1e-6) {
        continue;
      }

      nodes.add(PathNode(point.x, point.y));
    }

    if (nodes.length > 1 &&
        (nodes.first.x - nodes.last.x).abs() < 1e-6 &&
        (nodes.first.y - nodes.last.y).abs() < 1e-6) {
      nodes.removeLast();
    }

    if (nodes.length < 3) return rectangle(300, 400);

    return RoomPath(nodes);
  }

  // ------------------------------------------------------------------
  // Akses titik dan sisi. Sisi i berjalan dari titik i ke titik i + 1,
  // dan sisi terakhir menutup ke titik pertama.
  // ------------------------------------------------------------------

  Offset p(int i) {
    final node = nodes[i % nodes.length];
    return Offset(node.x, node.y);
  }

  double chordLength(int i) => (p(i + 1) - p(i)).distance;

  /// Tinggi busur bertanda (jarak tegak lurus dari tali busur).
  double sagitta(int i) => nodes[i].bulge * chordLength(i) / 2;

  ArcInfo? arcOf(int i) {
    final node = nodes[i % nodes.length];

    if (!node.isArc) return null;

    final a = p(i);
    final c = p(i + 1);
    final chord = (c - a).distance;

    if (chord < 1e-9) return null;

    final b = node.bulge;
    final dir = (c - a) / chord;
    final perp = Offset(-dir.dy, dir.dx);
    final sAbs = b.abs() * chord / 2;
    final radius = chord * (1 + b * b) / (4 * b.abs());
    final mid = (a + c) / 2;
    final center = mid + perp * (b.sign * (sAbs - radius));

    return ArcInfo(
      center: center,
      radius: radius,
      startAngle: math.atan2(a.dy - center.dy, a.dx - center.dx),
      sweep: -4 * math.atan(b),
    );
  }

  /// Panjang sepanjang sisi: panjang busur untuk sisi melengkung,
  /// jarak lurus untuk sisi lurus.
  double edgeLength(int i) => arcOf(i)?.length ?? chordLength(i);

  Offset pointAt(int i, double t) {
    final arc = arcOf(i);

    if (arc != null) return arc.pointAtFraction(t);

    final a = p(i);
    final c = p(i + 1);

    return a + (c - a) * t;
  }

  /// Titik-titik sepanjang sisi i, dari awal sampai akhir.
  List<Offset> edgePolyline(int i, {double stepDeg = 4}) {
    final arc = arcOf(i);

    if (arc == null) return [p(i), p(i + 1)];

    final steps = math.max(
      2,
      (arc.sweep.abs() * 180 / math.pi / stepDeg).ceil(),
    );

    final result = <Offset>[
      for (var k = 0; k <= steps; k++) arc.pointAtFraction(k / steps),
    ];

    result[0] = p(i);
    result[result.length - 1] = p(i + 1);

    return result;
  }

  /// Poligon halus untuk menggambar, menghitung, dan memeriksa tabrakan.
  List<RoomPoint> toPolygon({double stepDeg = 4}) {
    final out = <RoomPoint>[];

    for (var i = 0; i < nodes.length; i++) {
      final pts = edgePolyline(i, stepDeg: stepDeg);

      for (var k = 0; k < pts.length - 1; k++) {
        out.add(RoomPoint(pts[k].dx, pts[k].dy));
      }
    }

    return out;
  }

  // ------------------------------------------------------------------
  // Ukuran dan luas
  // ------------------------------------------------------------------

  static bool _angleInArc(ArcInfo arc, double angle) {
    const twoPi = 2 * math.pi;

    var delta = arc.sweep >= 0
        ? angle - arc.startAngle
        : arc.startAngle - angle;

    delta = delta % twoPi;

    if (delta < 0) delta += twoPi;

    return delta <= arc.sweep.abs();
  }

  /// Batas persis, termasuk titik terjauh pada busur.
  PathBounds get bounds {
    if (nodes.isEmpty) return const PathBounds(0, 0, 0, 0);

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    void add(Offset o) {
      minX = math.min(minX, o.dx);
      minY = math.min(minY, o.dy);
      maxX = math.max(maxX, o.dx);
      maxY = math.max(maxY, o.dy);
    }

    for (var i = 0; i < nodes.length; i++) {
      add(p(i));

      final arc = arcOf(i);

      if (arc == null) continue;

      for (var k = 0; k < 4; k++) {
        final angle = k * math.pi / 2;

        if (_angleInArc(arc, angle)) {
          add(
            Offset(
              arc.center.dx + arc.radius * math.cos(angle),
              arc.center.dy + arc.radius * math.sin(angle),
            ),
          );
        }
      }
    }

    return PathBounds(minX, minY, maxX, maxY);
  }

  /// Luas bertanda (positif untuk jalur searah jarum jam di layar).
  /// Dihitung eksak: luas poligon titik ditambah/dikurangi segmen busur.
  double get signedArea {
    if (nodes.length < 2) return 0;

    var sum = 0.0;

    for (var i = 0; i < nodes.length; i++) {
      final a = p(i);
      final b = p(i + 1);
      sum += a.dx * b.dy - b.dx * a.dy;
    }

    var area = sum / 2;

    for (var i = 0; i < nodes.length; i++) {
      final arc = arcOf(i);

      if (arc == null) continue;

      final theta = arc.sweep.abs();
      final segment = arc.radius * arc.radius / 2 * (theta - math.sin(theta));

      area -= nodes[i].bulge.sign * segment;
    }

    return area;
  }

  double get areaCm2 => signedArea.abs();

  /// +1 jika searah jarum jam di layar, -1 jika sebaliknya.
  int get orientation => signedArea >= 0 ? 1 : -1;

  /// Apakah busur sisi i melengkung ke luar ruangan.
  bool isArcOutward(int i) => nodes[i].bulge * orientation < 0;

  /// Bulge untuk arah dan besar tertentu.
  double bulgeFor({required bool outward, required double magnitude}) {
    final m = magnitude.abs().clamp(0.0, maxBulge).toDouble();

    return (outward ? -1.0 : 1.0) * orientation * m;
  }

  PathIssue get issue {
    if (nodes.length < 2) return PathIssue.tooFewNodes;

    for (var i = 0; i < nodes.length; i++) {
      if (chordLength(i) < minEdgeCm) return PathIssue.shortEdge;
    }

    final polygon = toPolygon(stepDeg: 10);

    if (polygon.length < 3 || !isValidPolygon(polygon)) {
      return PathIssue.selfIntersecting;
    }

    return PathIssue.none;
  }

  bool get isValid => issue == PathIssue.none;

  // ------------------------------------------------------------------
  // Operasi penyuntingan (masing-masing menghasilkan jalur baru)
  // ------------------------------------------------------------------

  RoomPath moveNode(int i, double x, double y) {
    final list = List<PathNode>.of(nodes);
    list[i] = list[i].copyWith(x: x, y: y);

    return RoomPath(list);
  }

  RoomPath setBulge(int i, double bulge) {
    final list = List<PathNode>.of(nodes);

    list[i] = list[i].copyWith(
      bulge: bulge.clamp(-maxBulge, maxBulge).toDouble(),
    );

    return RoomPath(list);
  }

  /// Mengubah jarak lurus sisi i dengan menggeser titik ujungnya
  /// searah sisi tersebut.
  RoomPath setChordLength(int i, double newLength) {
    final a = p(i);
    final c = p(i + 1);
    final current = (c - a).distance;

    final dir = current < 1e-9 ? const Offset(1, 0) : (c - a) / current;
    final end = a + dir * newLength;

    return moveNode((i + 1) % nodes.length, end.dx, end.dy);
  }

  /// Menambah titik di tengah sisi i. Bentuk busur tetap sama persis.
  RoomPath splitEdge(int i) {
    final mid = pointAt(i, 0.5);
    final b = nodes[i].bulge;
    final half = b == 0 ? 0.0 : math.tan(math.atan(b) / 2);

    final list = List<PathNode>.of(nodes);

    list[i] = list[i].copyWith(bulge: half);
    list.insert(i + 1, PathNode(mid.dx, mid.dy, bulge: half));

    return RoomPath(list);
  }

  /// Menghapus titik i. Minimal tersisa 3 titik.
  RoomPath removeNode(int i) {
    if (nodes.length <= 3) return this;

    final list = List<PathNode>.of(nodes)..removeAt(i);
    final prev = i == 0 ? list.length - 1 : i - 1;

    list[prev] = list[prev].copyWith(bulge: 0);

    return RoomPath(list);
  }

  RoomPath shifted(double dx, double dy) {
    return RoomPath([
      for (final node in nodes) node.copyWith(x: node.x + dx, y: node.y + dy),
    ]);
  }

  bool sameAs(RoomPath other) {
    if (other.nodes.length != nodes.length) return false;

    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] != other.nodes[i]) return false;
    }

    return true;
  }

  // ------------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------------

  List<Map<String, dynamic>> toJson() => [
    for (final node in nodes) node.toJson(),
  ];

  /// Null jika data tidak valid.
  static RoomPath? fromJson(Object? raw) {
    if (raw is! List) return null;

    final nodes = raw
        .whereType<Map>()
        .map((item) => PathNode.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    if (nodes.length < 2) return null;

    return RoomPath(nodes);
  }
}
