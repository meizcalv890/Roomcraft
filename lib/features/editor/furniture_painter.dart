import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'furniture_item.dart';
import 'furniture_style.dart';

const Color _dimensionColor = Color(0xFF2F6F9F);

/// Menggambar satu furnitur: bentuk, nama, ikon, ukuran, dan (saat dipilih)
/// garis dimensi gaya gambar kerja.
class FurniturePainter extends CustomPainter {
  FurniturePainter({
    required this.item,
    required this.name,
    required this.pixelsPerCm,
    this.selected = false,
    this.uiScale = 1,
  });

  final FurnitureItem item;

  /// Nama yang ditampilkan (sudah sesuai bahasa aktif).
  final String name;
  final double pixelsPerCm;
  final bool selected;

  /// Pengali ukuran teks dan garis (dipakai saat ekspor beresolusi tinggi).
  final double uiScale;

  Path _buildPath(Size size) {
    if (item.shape.isCurved && item.customPoints.length < 3) {
      return Path()..addOval(Offset.zero & size);
    }

    final offsets = item.localPoints.map((point) {
      // Rotasi 90° searah jarum jam: (x, y) -> (panjang - y, x).
      final x = item.isRotated ? item.lengthCm - point.y : point.x;
      final y = item.isRotated ? point.x : point.y;

      return Offset(x * pixelsPerCm, y * pixelsPerCm);
    }).toList();

    return Path()..addPolygon(offsets, true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    if (selected) {
      canvas.drawShadow(
        path,
        AppColors.forest.withValues(alpha: 0.45),
        6 * uiScale,
        false,
      );
    }

    canvas.drawPath(
      path,
      Paint()..color = item.type.color.withValues(alpha: selected ? 0.95 : 0.8),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (selected ? 2.5 : 1.5) * uiScale
        ..color = selected ? AppColors.forest : AppColors.white,
    );

    _paintLabel(canvas, size, path);

    if (selected) _paintDimensionLines(canvas, size);
  }

  void _paintLabel(Canvas canvas, Size size, Path path) {
    if (size.shortestSide < 30 * uiScale) return;

    canvas.save();
    canvas.clipPath(path);

    final maxWidth = math.max(1.0, size.width - 8 * uiScale);

    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontSize: 10 * uiScale,
          fontWeight: FontWeight.w600,
          color: AppColors.forest,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final dimsPainter = TextPainter(
      text: TextSpan(
        text:
            '${item.effectiveWidthCm.round()} × '
            '${item.effectiveLengthCm.round()} cm',
        style: TextStyle(
          fontSize: 9 * uiScale,
          fontWeight: FontWeight.w500,
          color: AppColors.forestLight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final showDims =
        size.width >= 56 * uiScale &&
        size.height >= namePainter.height + dimsPainter.height + 12 * uiScale;

    final textBlockHeight =
        namePainter.height + (showDims ? dimsPainter.height + 1 * uiScale : 0);

    final icon = item.type.icon;
    final iconSize = 20.0 * uiScale;

    final showIcon = size.height >= iconSize + textBlockHeight + 10 * uiScale;

    final iconPainter = showIcon
        ? (TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontSize: iconSize,
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                color: AppColors.forest,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout())
        : null;

    final totalHeight =
        textBlockHeight + (iconPainter == null ? 0 : iconPainter.height + 2);

    var y = (size.height - totalHeight) / 2;

    if (iconPainter != null) {
      iconPainter.paint(
        canvas,
        Offset((size.width - iconPainter.width) / 2, y),
      );
      y += iconPainter.height + 2;
    }

    namePainter.paint(canvas, Offset((size.width - namePainter.width) / 2, y));
    y += namePainter.height + 1 * uiScale;

    if (showDims) {
      dimsPainter.paint(
        canvas,
        Offset((size.width - dimsPainter.width) / 2, y),
      );
    }

    canvas.restore();
  }

  /// Garis dimensi gaya gambar kerja di luar bentuk furnitur.
  void _paintDimensionLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _dimensionColor
      ..strokeWidth = 1 * uiScale;

    final gap = 12 * uiScale;
    final tick = 4 * uiScale;

    // Dimensi lebar (atas).
    final top = -gap;
    canvas.drawLine(Offset(0, top), Offset(size.width, top), paint);
    canvas.drawLine(Offset(0, top - tick), Offset(0, top + tick), paint);
    canvas.drawLine(
      Offset(size.width, top - tick),
      Offset(size.width, top + tick),
      paint,
    );
    _drawDimensionText(
      canvas,
      '${item.effectiveWidthCm.round()} cm',
      Offset(size.width / 2, top - 8 * uiScale),
    );

    // Dimensi panjang (kiri).
    final left = -gap;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), paint);
    canvas.drawLine(Offset(left - tick, 0), Offset(left + tick, 0), paint);
    canvas.drawLine(
      Offset(left - tick, size.height),
      Offset(left + tick, size.height),
      paint,
    );
    _drawDimensionText(
      canvas,
      '${item.effectiveLengthCm.round()} cm',
      Offset(left - 8 * uiScale, size.height / 2),
      rotate: -math.pi / 2,
    );
  }

  void _drawDimensionText(
    Canvas canvas,
    String text,
    Offset center, {
    double rotate = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10 * uiScale,
          fontWeight: FontWeight.w700,
          color: _dimensionColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotate);

    final background = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: painter.width + 6 * uiScale,
        height: painter.height + 2 * uiScale,
      ),
      Radius.circular(4 * uiScale),
    );

    canvas.drawRRect(
      background,
      Paint()..color = AppColors.white.withValues(alpha: 0.9),
    );

    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FurniturePainter oldDelegate) {
    return !identical(oldDelegate.item, item) ||
        oldDelegate.name != name ||
        oldDelegate.pixelsPerCm != pixelsPerCm ||
        oldDelegate.selected != selected ||
        oldDelegate.uiScale != uiScale;
  }
}