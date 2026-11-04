import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/language_controller.dart';
import '../../core/theme/app_theme.dart';
import 'furniture_item.dart';
import 'furniture_painter.dart';
import 'room_geometry.dart';

/// Garis grid gelap untuk setiap kelipatan 1 meter.
const Color _gridMeterColor = Color(0xFFB9B2A0);

/// Ukuran grid pada tingkat zoom tertentu (dalam sentimeter).
class GridSteps {
  const GridSteps(this.minor, this.major);

  /// Jarak antar garis tipis (detail).
  final double minor;

  /// Jarak antar garis tebal (kelipatan) dan label penggaris.
  final double major;
}

String formatCm(double value) {
  if (value >= 100 && value % 100 == 0) return '${(value / 100).round()} m';
  return '${value.round()} cm';
}

class RoomCanvas extends StatefulWidget {
  const RoomCanvas({
    super.key,
    required this.widthCm,
    required this.lengthCm,
    this.roomPoints = const [],
    this.items = const [],
    this.selectedId,
    this.showGrid = true,
    this.onSelect,
    this.onMove,
    this.onMoveEnd,
  });

  final double widthCm;
  final double lengthCm;

  /// Titik batas ruangan dalam sentimeter. Jika kurang dari tiga titik,
  /// ruangan digambar sebagai persegi panjang.
  final List<RoomPoint> roomPoints;
  final List<FurnitureItem> items;
  final String? selectedId;
  final bool showGrid;
  final ValueChanged<String?>? onSelect;
  final void Function(String id, double dxCm, double dyCm)? onMove;

  /// Dipanggil ketika geseran furnitur selesai atau dibatalkan.
  final VoidCallback? onMoveEnd;

  @override
  State<RoomCanvas> createState() => _RoomCanvasState();
}

class _RoomCanvasState extends State<RoomCanvas> {
  static const double _minZoom = 0.6;
  static const double _maxZoom = 8.0;
  static const double _margin = 48;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _changeZoom(double factor, Size viewportSize) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final nextScale = (currentScale * factor)
        .clamp(_minZoom, _maxZoom)
        .toDouble();

    if ((nextScale - currentScale).abs() < 0.001) {
      return;
    }

    final focalPoint = Offset(viewportSize.width / 2, viewportSize.height / 2);

    final scenePoint = _transformationController.toScene(focalPoint);

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(nextScale, nextScale, 1, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  Widget _chip(String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        final availableWidth = math.max(100.0, constraints.maxWidth - 100);
        final availableHeight = math.max(100.0, constraints.maxHeight - 120);

        final safeWidth = widget.widthCm > 0 ? widget.widthCm : 1.0;
        final safeLength = widget.lengthCm > 0 ? widget.lengthCm : 1.0;

        final roomPoints = widget.roomPoints.length >= 3
            ? widget.roomPoints
            : RoomShape.rectangle.points(safeWidth, safeLength);

        final scale = math
            .min(availableWidth / safeWidth, availableHeight / safeLength)
            .clamp(0.03, 1.2)
            .toDouble();

        final roomWidth = safeWidth * scale;
        final roomHeight = safeLength * scale;

        final canvasWidth = roomWidth + _margin * 2;
        final canvasHeight = roomHeight + _margin * 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: strings.roomPlanSemantics(
                widget.widthCm.round(),
                widget.lengthCm.round(),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => widget.onSelect?.call(null),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: _minZoom,
                  maxScale: _maxZoom,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(140),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: AnimatedBuilder(
                      animation: _transformationController,
                      builder: (context, _) {
                        final zoom = _transformationController.value
                            .getMaxScaleOnAxis();

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(canvasWidth, canvasHeight),
                              painter: RoomCanvasPainter(
                                widthCm: safeWidth,
                                lengthCm: safeLength,
                                roomPoints: roomPoints,
                                scale: scale,
                                zoom: zoom,
                                margin: _margin,
                                showGrid: widget.showGrid,
                                planLabel: strings.planLabel,
                              ),
                            ),
                            for (final item in widget.items)
                              _buildFurniture(item, scale, zoom),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Kontrol zoom. Setiap IconButton hanya memiliki
            // satu tooltip agar tidak ditemukan dua kali oleh tes.
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('zoom_in'),
                      tooltip: strings.zoomIn,
                      onPressed: () => _changeZoom(1.25, viewportSize),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const ValueKey('zoom_out'),
                      tooltip: strings.zoomOut,
                      onPressed: () => _changeZoom(0.8, viewportSize),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      key: const ValueKey('reset_zoom'),
                      tooltip: strings.resetView,
                      onPressed: _resetView,
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
              ),
            ),

            // Keterangan skala grid yang ikut berubah saat zoom.
            if (widget.showGrid)
              Positioned(
                bottom: 44,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: Center(
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _transformationController,
                      builder: (context, matrix, _) {
                        final steps = RoomCanvasPainter.stepsFor(
                          scale * matrix.getMaxScaleOnAxis(),
                        );

                        return _chip(
                          strings.gridLegend(
                            formatCm(steps.minor),
                            formatCm(steps.major),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: Center(child: _chip(strings.dragHint)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFurniture(FurnitureItem item, double scale, double zoom) {
    final strings = context.l10n;
    final width = item.effectiveWidthCm * scale;
    final height = item.effectiveLengthCm * scale;
    final isSelected = item.id == widget.selectedId;

    // Delta gestur dihitung dalam piksel layar, sedangkan kanvas bisa
    // diperbesar oleh InteractiveViewer. Karena itu dibagi dengan zoom.
    final screenPixelsPerCm = scale * zoom;

    return Positioned(
      key: ValueKey('furniture_${item.id}'),
      left: _margin + item.xCm * scale,
      top: _margin + item.yCm * scale,
      width: width,
      height: height,
      child: Semantics(
        label: strings.furnitureSemantics(
          item.displayName,
          item.effectiveWidthCm.round(),
          item.effectiveLengthCm.round(),
        ),
        selected: isSelected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect?.call(item.id),
          onPanStart: (_) => widget.onSelect?.call(item.id),
          onPanUpdate: (details) {
            widget.onMove?.call(
              item.id,
              details.delta.dx / screenPixelsPerCm,
              details.delta.dy / screenPixelsPerCm,
            );
          },
          onPanEnd: (_) => widget.onMoveEnd?.call(),
          onPanCancel: () => widget.onMoveEnd?.call(),
          child: CustomPaint(
            painter: FurniturePainter(
              item: item,
              name: item.displayName,
              pixelsPerCm: scale,
              selected: isSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class RoomCanvasPainter extends CustomPainter {
  RoomCanvasPainter({
    required this.widthCm,
    required this.lengthCm,
    required this.roomPoints,
    required this.scale,
    required this.zoom,
    required this.margin,
    this.showGrid = true,
    this.planLabel = 'ROOM PLAN',
    this.uiScale = 1,
  });

  final double widthCm;
  final double lengthCm;
  final List<RoomPoint> roomPoints;
  final double scale;
  final double zoom;
  final double margin;
  final bool showGrid;

  /// Teks judul denah di bawah ruangan (sesuai bahasa aktif).
  final String planLabel;

  /// Pengali ukuran teks dan garis (dipakai saat ekspor beresolusi tinggi).
  final double uiScale;

  /// Memilih jarak grid agar garis tipis tidak lebih rapat dari ±8 piksel
  /// dan garis tebal tidak lebih rapat dari ±40 piksel.
  static GridSteps stepsFor(double pixelsPerCm, {double uiScale = 1}) {
    const steps = [1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 200.0, 500.0, 1000.0];

    var minor = steps.last;

    for (final step in steps) {
      if (step * pixelsPerCm >= 8 * uiScale) {
        minor = step;
        break;
      }
    }

    var major = steps.last;

    for (final step in steps) {
      if (step > minor &&
          step % minor == 0 &&
          step * pixelsPerCm >= 40 * uiScale) {
        major = step;
        break;
      }
    }

    return GridSteps(minor, major);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final roomWidth = widthCm * scale;
    final roomHeight = lengthCm * scale;

    final roomPath = Path()
      ..addPolygon(
        roomPoints
            .map(
              (point) =>
                  Offset(margin + point.x * scale, margin + point.y * scale),
            )
            .toList(),
        true,
      );

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.canvas);

    canvas.drawPath(roomPath, Paint()..color = AppColors.canvasRoom);

    if (showGrid) {
      _paintGrid(canvas, roomPath, roomWidth, roomHeight);
    }

    canvas.drawPath(
      roomPath,
      Paint()
        ..color = AppColors.forest
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 4 * uiScale,
    );

    if (showGrid) {
      _paintRuler(canvas);
    }

    _drawText(
      canvas,
      '${widthCm.round()} cm',
      Offset(margin + roomWidth / 2, margin - 32 * uiScale),
      centered: true,
      bold: true,
    );

    _drawText(
      canvas,
      '${lengthCm.round()} cm',
      Offset(margin - 36 * uiScale, margin + roomHeight / 2),
      centered: true,
      bold: true,
      rotate: -math.pi / 2,
    );

    // Label luas diletakkan di bawah ruangan agar tidak menimpa furnitur
    // dan tetap benar untuk bentuk cekung seperti L dan U.
    final area = polygonAreaCm2(roomPoints) / 10000;

    _drawText(
      canvas,
      '$planLabel  ·  ${area.toStringAsFixed(2)} m²',
      Offset(margin + roomWidth / 2, margin + roomHeight + 22 * uiScale),
      fontSize: 11,
      centered: true,
      bold: true,
      color: AppColors.muted,
    );
  }

  /// 0 = garis tipis, 1 = garis tebal, 2 = garis meter (kelipatan 100 cm).
  int _styleFor(double value, GridSteps steps) {
    if (value % 100 == 0) return 2;
    if (value % steps.major == 0) return 1;
    return 0;
  }

  void _paintGrid(
    Canvas canvas,
    Path roomPath,
    double roomWidth,
    double roomHeight,
  ) {
    final steps = stepsFor(scale * zoom, uiScale: uiScale);

    final paints = [
      Paint()
        ..color = AppColors.gridMinor
        ..strokeWidth = 0.6 * uiScale,
      Paint()
        ..color = AppColors.gridMajor
        ..strokeWidth = 1.0 * uiScale,
      Paint()
        ..color = _gridMeterColor
        ..strokeWidth = 1.4 * uiScale,
    ];

    canvas.save();
    canvas.clipPath(roomPath);

    // Tiga lapis: tipis dulu, lalu tebal, lalu garis meter di paling atas.
    for (var style = 0; style < 3; style++) {
      for (var k = 1; k * steps.minor < widthCm; k++) {
        final x = k * steps.minor;

        if (_styleFor(x, steps) != style) continue;

        canvas.drawLine(
          Offset(margin + x * scale, margin),
          Offset(margin + x * scale, margin + roomHeight),
          paints[style],
        );
      }

      for (var k = 1; k * steps.minor < lengthCm; k++) {
        final y = k * steps.minor;

        if (_styleFor(y, steps) != style) continue;

        canvas.drawLine(
          Offset(margin, margin + y * scale),
          Offset(margin + roomWidth, margin + y * scale),
          paints[style],
        );
      }
    }

    canvas.restore();
  }

  /// Penggaris di tepi atas dan kiri: tanda kecil + angka pada garis tebal.
  void _paintRuler(Canvas canvas) {
    final steps = stepsFor(scale * zoom, uiScale: uiScale);

    final tickPaint = Paint()
      ..color = AppColors.muted
      ..strokeWidth = 1 * uiScale;

    String label(double value) => value >= 100 && value % 100 == 0
        ? '${(value / 100).round()} m'
        : '${value.round()}';

    for (var k = 1; k * steps.major <= widthCm; k++) {
      final x = k * steps.major;
      final px = margin + x * scale;

      canvas.drawLine(
        Offset(px, margin - 5 * uiScale),
        Offset(px, margin),
        tickPaint,
      );

      _drawText(
        canvas,
        label(x),
        Offset(px, margin - 11 * uiScale),
        fontSize: 8.5,
        centered: true,
        color: AppColors.muted,
      );
    }

    for (var k = 1; k * steps.major <= lengthCm; k++) {
      final y = k * steps.major;
      final py = margin + y * scale;

      canvas.drawLine(
        Offset(margin - 5 * uiScale, py),
        Offset(margin, py),
        tickPaint,
      );

      _drawText(
        canvas,
        label(y),
        Offset(margin - 16 * uiScale, py),
        fontSize: 8.5,
        centered: true,
        color: AppColors.muted,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 12,
    bool bold = false,
    bool centered = false,
    double rotate = 0,
    Color color = AppColors.forest,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize * uiScale,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotate);

    painter.paint(
      canvas,
      Offset(
        centered ? -painter.width / 2 : 0,
        centered ? -painter.height / 2 : 0,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RoomCanvasPainter oldDelegate) {
    return oldDelegate.widthCm != widthCm ||
        oldDelegate.lengthCm != lengthCm ||
        oldDelegate.scale != scale ||
        oldDelegate.zoom != zoom ||
        oldDelegate.margin != margin ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.planLabel != planLabel ||
        oldDelegate.uiScale != uiScale ||
        !listEquals(oldDelegate.roomPoints, roomPoints);
  }
}