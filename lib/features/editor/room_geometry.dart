import 'dart:math' as math;

import '../../core/l10n/app_strings.dart';

/// Semua koordinat geometri disimpan dalam sentimeter.
class RoomPoint {
  const RoomPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory RoomPoint.fromJson(Map<String, dynamic> json) {
    final x = json['x'];
    final y = json['y'];

    return RoomPoint(
      x is num && x.isFinite ? x.toDouble() : 0,
      y is num && y.isFinite ? y.toDouble() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoomPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'RoomPoint($x, $y)';
}

enum RoomShape { rectangle, lShape, uShape, polygon }

extension RoomShapeInfo on RoomShape {
  /// Nama bentuk sesuai bahasa aktif.
  String get label => AppStrings.current.roomShapeLabel(this);

  /// Membuat titik bentuk berdasarkan ukuran bounding box.
  List<RoomPoint> points(double width, double length) {
    final w = math.max(1.0, width);
    final h = math.max(1.0, length);

    switch (this) {
      case RoomShape.rectangle:
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h),
          RoomPoint(0, h),
        ];

      case RoomShape.lShape:
        // Luas = 72% dari bounding box.
        // Contoh 300 x 400 cm menghasilkan 8,64 m².
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h * 0.44),
          RoomPoint(w * 0.5, h * 0.44),
          RoomPoint(w * 0.5, h),
          RoomPoint(0, h),
        ];

      case RoomShape.uShape:
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h),
          RoomPoint(w * 0.72, h),
          RoomPoint(w * 0.72, h * 0.30),
          RoomPoint(w * 0.28, h * 0.30),
          RoomPoint(w * 0.28, h),
          RoomPoint(0, h),
        ];

      case RoomShape.polygon:
        return [
          RoomPoint(w * 0.12, 0),
          RoomPoint(w * 0.88, 0),
          RoomPoint(w, h * 0.25),
          RoomPoint(w * 0.82, h * 0.82),
          RoomPoint(w * 0.48, h),
          RoomPoint(w * 0.08, h * 0.72),
          RoomPoint(0, h * 0.28),
        ];
    }
  }
}

/// Menghitung luas poligon menggunakan rumus shoelace.
/// Hasilnya dalam sentimeter persegi.
double polygonAreaCm2(List<RoomPoint> points) {
  if (points.length < 3) return 0;

  var sum = 0.0;

  for (var i = 0; i < points.length; i++) {
    final current = points[i];
    final next = points[(i + 1) % points.length];

    sum += current.x * next.y - next.x * current.y;
  }

  return sum.abs() / 2;
}

double _cross(RoomPoint o, RoomPoint a, RoomPoint b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

bool _onSegment(RoomPoint a, RoomPoint b, RoomPoint p) =>
    p.x >= math.min(a.x, b.x) &&
    p.x <= math.max(a.x, b.x) &&
    p.y >= math.min(a.y, b.y) &&
    p.y <= math.max(a.y, b.y);

/// Dua ruas berpotongan secara tegas (bukan sekadar bersentuhan).
bool _segmentsCrossStrictly(
  RoomPoint p1,
  RoomPoint p2,
  RoomPoint p3,
  RoomPoint p4,
) {
  final d1 = _cross(p3, p4, p1);
  final d2 = _cross(p3, p4, p2);
  final d3 = _cross(p1, p2, p3);
  final d4 = _cross(p1, p2, p4);

  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// Dua ruas berpotongan atau bersentuhan.
bool _segmentsIntersect(
  RoomPoint p1,
  RoomPoint p2,
  RoomPoint p3,
  RoomPoint p4,
) {
  if (_segmentsCrossStrictly(p1, p2, p3, p4)) return true;

  final d1 = _cross(p3, p4, p1);
  final d2 = _cross(p3, p4, p2);
  final d3 = _cross(p1, p2, p3);
  final d4 = _cross(p1, p2, p4);

  if (d1 == 0 && _onSegment(p3, p4, p1)) return true;
  if (d2 == 0 && _onSegment(p3, p4, p2)) return true;
  if (d3 == 0 && _onSegment(p1, p2, p3)) return true;
  if (d4 == 0 && _onSegment(p1, p2, p4)) return true;

  return false;
}

/// Poligon sederhana: sisi-sisinya tidak saling berpotongan.
bool isSimplePolygon(List<RoomPoint> points) {
  final n = points.length;
  if (n < 3) return false;

  for (var i = 0; i < n; i++) {
    final a1 = points[i];
    final a2 = points[(i + 1) % n];

    for (var j = i + 1; j < n; j++) {
      final adjacent = j == i + 1 || (i == 0 && j == n - 1);
      if (adjacent) continue;

      final b1 = points[j];
      final b2 = points[(j + 1) % n];

      if (_segmentsIntersect(a1, a2, b1, b2)) return false;
    }
  }

  return true;
}

/// Memastikan poligon memiliki setidaknya tiga titik valid,
/// luas positif, dan tidak berpotongan dengan dirinya sendiri.
bool isValidPolygon(List<RoomPoint> points) {
  if (points.length < 3) return false;

  if (points.any(
    (point) =>
        !point.x.isFinite || !point.y.isFinite || point.x < 0 || point.y < 0,
  )) {
    return false;
  }

  return polygonAreaCm2(points) > 0 && isSimplePolygon(points);
}

double _distanceToSegment(RoomPoint p, RoomPoint a, RoomPoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lengthSq = dx * dx + dy * dy;

  var cx = a.x;
  var cy = a.y;

  if (lengthSq != 0) {
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq)
        .clamp(0.0, 1.0)
        .toDouble();
    cx = a.x + t * dx;
    cy = a.y + t * dy;
  }

  final ex = p.x - cx;
  final ey = p.y - cy;

  return math.sqrt(ex * ex + ey * ey);
}

/// Titik di dalam poligon. Titik tepat di tepi dianggap di dalam.
bool isPointInPolygon(
  RoomPoint point,
  List<RoomPoint> polygon, {
  double epsilon = 0.01,
}) {
  final n = polygon.length;
  if (n < 3) return false;

  for (var i = 0; i < n; i++) {
    if (_distanceToSegment(point, polygon[i], polygon[(i + 1) % n]) <=
        epsilon) {
      return true;
    }
  }

  var inside = false;

  for (var i = 0, j = n - 1; i < n; j = i++) {
    final a = polygon[i];
    final b = polygon[j];

    final crosses =
        (a.y > point.y) != (b.y > point.y) &&
        point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;

    if (crosses) inside = !inside;
  }

  return inside;
}

/// Apakah persegi panjang berada sepenuhnya di dalam poligon
/// (mendukung poligon cekung seperti bentuk L dan U).
bool isRectInsidePolygon(
  double left,
  double top,
  double right,
  double bottom,
  List<RoomPoint> polygon, {
  double epsilon = 0.01,
}) {
  if (polygon.length < 3) return false;

  final corners = [
    RoomPoint(left, top),
    RoomPoint(right, top),
    RoomPoint(right, bottom),
    RoomPoint(left, bottom),
  ];

  if (corners.any(
    (corner) => !isPointInPolygon(corner, polygon, epsilon: epsilon),
  )) {
    return false;
  }

  // Sudut poligon tidak boleh menembus bagian dalam persegi panjang.
  for (final vertex in polygon) {
    if (vertex.x > left + epsilon &&
        vertex.x < right - epsilon &&
        vertex.y > top + epsilon &&
        vertex.y < bottom - epsilon) {
      return false;
    }
  }

  // Sisi poligon tidak boleh memotong sisi persegi panjang.
  for (var i = 0; i < 4; i++) {
    final r1 = corners[i];
    final r2 = corners[(i + 1) % 4];

    for (var j = 0; j < polygon.length; j++) {
      final p1 = polygon[j];
      final p2 = polygon[(j + 1) % polygon.length];

      if (_segmentsCrossStrictly(r1, r2, p1, p2)) return false;
    }
  }

  return true;
}
