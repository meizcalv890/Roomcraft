import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/language_controller.dart';
import '../../core/l10n/pro_view_strings.dart';
import '../../core/theme/app_theme.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'room_geometry.dart';

// ======================================================================
// Utilitas
// ======================================================================

String _n(double v) =>
    v.roundToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

void _paintText(
  Canvas canvas,
  String text,
  Offset center, {
  double size = 11,
  bool bold = false,
  double rotate = 0,
  Color color = AppColors.forest,
  Color? background,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotate);

  final origin = Offset(-painter.width / 2, -painter.height / 2);

  if (background != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (origin & painter.size).inflate(3),
        const Radius.circular(6),
      ),
      Paint()..color = background,
    );
  }

  painter.paint(canvas, origin);
  canvas.restore();
}

/// Titik denah sebuah furnitur setelah rotasi dan posisi (cm).
List<Offset> itemPlanPoints(FurnitureItem item) {
  return [
    for (final p in item.localPoints)
      Offset(
        item.xCm + (item.isRotated ? item.lengthCm - p.y : p.x),
        item.yCm + (item.isRotated ? p.x : p.y),
      ),
  ];
}

// ======================================================================
// Alat ukur
// ======================================================================

class Measurement {
  const Measurement(this.a, this.b);

  final Offset a;
  final Offset b;

  double get distance => (b - a).distance;
  double get dx => (b.dx - a.dx).abs();
  double get dy => (b.dy - a.dy).abs();

  /// Sudut terhadap garis horizontal, 0 sampai 90 derajat.
  double get angleDeg => math.atan2(dy, dx) * 180 / math.pi;
}

/// Titik-titik yang bisa dijadikan tempat menempel: sudut ruangan, sudut
/// furnitur, dan pusat furnitur.
List<Offset> measureSnapPoints(
  List<RoomPoint> room,
  List<FurnitureItem> items,
) {
  final pts = <Offset>[for (final p in room) Offset(p.x, p.y)];

  for (final item in items) {
    pts.addAll(itemPlanPoints(item));
    pts.add(
      Offset(
        item.xCm + item.effectiveWidthCm / 2,
        item.yCm + item.effectiveLengthCm / 2,
      ),
    );
  }

  return pts;
}

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({
    super.key,
    required this.roomPoints,
    required this.items,
  });

  final List<RoomPoint> roomPoints;
  final List<FurnitureItem> items;

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  static const double _margin = 28;
  static const double _snapPx = 18;

  Offset? _first;
  final List<Measurement> _list = [];

  late final List<Offset> _snapPoints;
  late final Rect _bounds;

  @override
  void initState() {
    super.initState();

    _snapPoints = measureSnapPoints(widget.roomPoints, widget.items);

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in widget.roomPoints) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    if (widget.roomPoints.isEmpty) {
      minX = 0;
      minY = 0;
      maxX = 100;
      maxY = 100;
    }

    _bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _scaleFor(Size size) {
    final w = math.max(1.0, _bounds.width);
    final h = math.max(1.0, _bounds.height);

    return math.max(
      0.01,
      math.min((size.width - _margin * 2) / w, (size.height - _margin * 2) / h),
    );
  }

  Offset _toCanvas(Offset cm, double scale) => Offset(
    _margin + (cm.dx - _bounds.left) * scale,
    _margin + (cm.dy - _bounds.top) * scale,
  );

  Offset _toCm(Offset px, double scale) => Offset(
    (px.dx - _margin) / scale + _bounds.left,
    (px.dy - _margin) / scale + _bounds.top,
  );

  void _tap(Offset local, Size size) {
    final scale = _scaleFor(size);

    Offset? best;
    var bestDistance = _snapPx;

    for (final p in _snapPoints) {
      final d = (_toCanvas(p, scale) - local).distance;

      if (d < bestDistance) {
        best = p;
        bestDistance = d;
      }
    }

    final point = best ?? _toCm(local, scale);

    setState(() {
      final first = _first;

      if (first == null) {
        _first = point;
      } else {
        _list.add(Measurement(first, point));
        _first = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.measureTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: s.undoLastMeasure,
            icon: const Icon(Icons.undo),
            onPressed: _first == null && _list.isEmpty
                ? null
                : () => setState(() {
                    if (_first != null) {
                      _first = null;
                    } else {
                      _list.removeLast();
                    }
                  }),
          ),
          IconButton(
            tooltip: s.clearMeasures,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _first == null && _list.isEmpty
                ? null
                : () => setState(() {
                    _first = null;
                    _list.clear();
                  }),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _first == null ? s.measureTapFirst : s.measureTapSecond,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final scale = _scaleFor(size);

                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 8,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _tap(details.localPosition, size),
                        child: SizedBox.expand(
                          key: const ValueKey('measure_area'),
                          child: CustomPaint(
                            painter: _MeasurePainter(
                              room: widget.roomPoints,
                              items: widget.items,
                              snapPoints: _snapPoints,
                              measurements: _list,
                              pending: _first,
                              scale: scale,
                              toCanvas: (p) => _toCanvas(p, scale),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: _list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        s.measureEmpty,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      shrinkWrap: true,
                      itemCount: _list.length,
                      itemBuilder: (_, index) {
                        final m = _list[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            s.measureRow(
                              index + 1,
                              _n(double.parse(m.distance.toStringAsFixed(1))),
                              _n(double.parse(m.dx.toStringAsFixed(1))),
                              _n(double.parse(m.dy.toStringAsFixed(1))),
                              m.angleDeg.toStringAsFixed(0),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Text(
                s.measureHint,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurePainter extends CustomPainter {
  _MeasurePainter({
    required this.room,
    required this.items,
    required this.snapPoints,
    required this.measurements,
    required this.pending,
    required this.scale,
    required this.toCanvas,
  });

  final List<RoomPoint> room;
  final List<FurnitureItem> items;
  final List<Offset> snapPoints;
  final List<Measurement> measurements;
  final Offset? pending;
  final double scale;
  final Offset Function(Offset cm) toCanvas;

  static const Color _accent = Color(0xFFC2410C);

  @override
  void paint(Canvas canvas, Size size) {
    final roomPath = Path()
      ..addPolygon([for (final p in room) toCanvas(Offset(p.x, p.y))], true);

    canvas.drawPath(roomPath, Paint()..color = AppColors.canvasRoom);
    canvas.drawPath(
      roomPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.forest,
    );

    for (final item in items) {
      final path = Path()
        ..addPolygon([for (final p in itemPlanPoints(item)) toCanvas(p)], true);

      canvas.drawPath(
        path,
        Paint()..color = item.material.color.withValues(alpha: 0.7),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF555555),
      );
    }

    final dot = Paint()..color = AppColors.muted.withValues(alpha: 0.55);

    for (final p in snapPoints) {
      canvas.drawCircle(toCanvas(p), 2.2, dot);
    }

    final line = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _accent;

    for (final m in measurements) {
      final a = toCanvas(m.a);
      final b = toCanvas(m.b);

      canvas.drawLine(a, b, line);
      canvas.drawCircle(a, 4, Paint()..color = _accent);
      canvas.drawCircle(b, 4, Paint()..color = _accent);

      _paintText(
        canvas,
        '${_n(double.parse(m.distance.toStringAsFixed(1)))} cm',
        (a + b) / 2,
        bold: true,
        color: _accent,
        background: Colors.white.withValues(alpha: 0.92),
      );
    }

    final first = pending;

    if (first != null) {
      canvas.drawCircle(
        toCanvas(first),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter oldDelegate) => true;
}

// ======================================================================
// Tampak depan dan samping furnitur
// ======================================================================

class ElevationScreen extends StatefulWidget {
  const ElevationScreen({super.key, required this.item});

  final FurnitureItem item;

  @override
  State<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends State<ElevationScreen> {
  static const _steps = [1.0, 5.0, 10.0, 25.0];

  double _grid = 10;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final item = widget.item;
    final h = item.effectiveHeightCm;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              s.elevationTitle,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            s.elevationSummary(
              _n(item.widthCm),
              _n(item.lengthCm),
              _n(h),
              _n(item.thicknessCm),
            ),
            style: const TextStyle(
              color: AppColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  s.gridStepLabel,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                for (final step in _steps)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${_n(step)} cm'),
                      selected: _grid == step,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _grid = step),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ElevationCard(
            title: s.frontView,
            spanCm: item.widthCm,
            heightCm: h,
            thicknessCm: item.thicknessCm,
            color: item.material.color,
            gridCm: _grid,
          ),
          const SizedBox(height: 12),
          _ElevationCard(
            title: s.sideView,
            spanCm: item.lengthCm,
            heightCm: h,
            thicknessCm: item.thicknessCm,
            color: item.material.color,
            gridCm: _grid,
          ),
          const SizedBox(height: 12),
          Text(
            s.elevationNote,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ElevationCard extends StatelessWidget {
  const _ElevationCard({
    required this.title,
    required this.spanCm,
    required this.heightCm,
    required this.thicknessCm,
    required this.color,
    required this.gridCm,
  });

  final String title;
  final double spanCm;
  final double heightCm;
  final double thicknessCm;
  final Color color;
  final double gridCm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: CustomPaint(
              painter: _ElevationPainter(
                spanCm: spanCm,
                heightCm: heightCm,
                thicknessCm: thicknessCm,
                color: color,
                gridCm: gridCm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({
    required this.spanCm,
    required this.heightCm,
    required this.thicknessCm,
    required this.color,
    required this.gridCm,
  });

  final double spanCm;
  final double heightCm;
  final double thicknessCm;
  final Color color;
  final double gridCm;

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 44.0;

    final span = math.max(1.0, spanCm);
    final height = math.max(1.0, heightCm);

    final scale = math.max(
      0.01,
      math.min(
        (size.width - margin * 2) / span,
        (size.height - margin * 2) / height,
      ),
    );

    final w = span * scale;
    final h = height * scale;

    final rect = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2 - 6,
      w,
      h,
    );

    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.35));

    // Grid: kelipatan diperbesar otomatis jika terlalu rapat.
    var step = gridCm;

    while (step * scale < 7) {
      step *= 2;
    }

    canvas.save();
    canvas.clipRect(rect);

    final minor = Paint()
      ..color = AppColors.gridMinor
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = AppColors.gridMajor
      ..strokeWidth = 1;

    for (var x = step; x < span; x += step) {
      final isMajor = (x % 100).abs() < 0.001;

      canvas.drawLine(
        Offset(rect.left + x * scale, rect.top),
        Offset(rect.left + x * scale, rect.bottom),
        isMajor ? major : minor,
      );
    }

    for (var y = step; y < height; y += step) {
      final isMajor = (y % 100).abs() < 0.001;

      canvas.drawLine(
        Offset(rect.left, rect.bottom - y * scale),
        Offset(rect.right, rect.bottom - y * scale),
        isMajor ? major : minor,
      );
    }

    // Papan atas dan bawah.
    final band = math.max(1.5, thicknessCm * scale);
    final bandPaint = Paint()..color = color.withValues(alpha: 0.9);

    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, band),
      bandPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - band, rect.width, band),
      bandPaint,
    );

    canvas.restore();

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = AppColors.forest,
    );

    // Garis lantai.
    canvas.drawLine(
      Offset(rect.left - 14, rect.bottom),
      Offset(rect.right + 14, rect.bottom),
      Paint()
        ..strokeWidth = 2.5
        ..color = AppColors.forest,
    );

    final dim = Paint()
      ..strokeWidth = 1
      ..color = AppColors.muted;

    // Dimensi lebar (bawah).
    final yDim = rect.bottom + 20;

    canvas.drawLine(Offset(rect.left, yDim), Offset(rect.right, yDim), dim);
    canvas.drawLine(
      Offset(rect.left, yDim - 4),
      Offset(rect.left, yDim + 4),
      dim,
    );
    canvas.drawLine(
      Offset(rect.right, yDim - 4),
      Offset(rect.right, yDim + 4),
      dim,
    );

    _paintText(
      canvas,
      '${_n(spanCm)} cm',
      Offset(rect.center.dx, yDim + 12),
      bold: true,
    );

    // Dimensi tinggi (kiri).
    final xDim = rect.left - 20;

    canvas.drawLine(Offset(xDim, rect.top), Offset(xDim, rect.bottom), dim);
    canvas.drawLine(
      Offset(xDim - 4, rect.top),
      Offset(xDim + 4, rect.top),
      dim,
    );
    canvas.drawLine(
      Offset(xDim - 4, rect.bottom),
      Offset(xDim + 4, rect.bottom),
      dim,
    );

    _paintText(
      canvas,
      '${_n(heightCm)} cm',
      Offset(xDim - 12, rect.center.dy),
      bold: true,
      rotate: -math.pi / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.spanCm != spanCm ||
      oldDelegate.heightCm != heightCm ||
      oldDelegate.thicknessCm != thicknessCm ||
      oldDelegate.color != color ||
      oldDelegate.gridCm != gridCm;
}
