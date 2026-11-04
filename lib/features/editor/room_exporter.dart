import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/l10n/app_strings.dart';
import 'furniture_item.dart';
import 'furniture_painter.dart';
import 'room_canvas.dart';
import 'room_geometry.dart';

/// Merender denah ke PNG secara langsung dengan resolusi tetap.
///
/// Berbeda dengan menangkap layar, hasilnya tidak ikut memuat tombol zoom,
/// teks petunjuk, ataupun tingkat zoom/posisi geser yang sedang aktif.
/// Teks pada gambar mengikuti bahasa yang sedang aktif.
Future<Uint8List> renderRoomPng({
  required double widthCm,
  required double lengthCm,
  required List<RoomPoint> roomPoints,
  required List<FurnitureItem> items,
  double maxSidePx = 2400,
}) async {
  final strings = AppStrings.current;

  final safeWidth = widthCm > 0 ? widthCm : 1.0;
  final safeLength = lengthCm > 0 ? lengthCm : 1.0;

  const uiScale = 2.0;
  const margin = 48.0 * uiScale;

  final scale = ((maxSidePx - margin * 2) / math.max(safeWidth, safeLength))
      .clamp(0.1, 6.0)
      .toDouble();

  final width = (safeWidth * scale + margin * 2).ceil();
  final height = (safeLength * scale + margin * 2).ceil();
  final size = Size(width.toDouble(), height.toDouble());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);

  final points = roomPoints.length >= 3
      ? roomPoints
      : RoomShape.rectangle.points(safeWidth, safeLength);

  RoomCanvasPainter(
    widthCm: safeWidth,
    lengthCm: safeLength,
    roomPoints: points,
    scale: scale,
    zoom: 1,
    margin: margin,
    uiScale: uiScale,
    planLabel: strings.planLabel,
  ).paint(canvas, size);

  for (final item in items) {
    final itemSize = Size(
      item.effectiveWidthCm * scale,
      item.effectiveLengthCm * scale,
    );

    canvas.save();
    canvas.translate(margin + item.xCm * scale, margin + item.yCm * scale);

    FurniturePainter(
      item: item,
      name: item.displayName,
      pixelsPerCm: scale,
      uiScale: uiScale,
    ).paint(canvas, itemSize);

    canvas.restore();
  }

  final picture = recorder.endRecording();
  ui.Image? image;

  try {
    image = await picture.toImage(width, height);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception(strings.pngFailed);
    }

    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    image?.dispose();
    picture.dispose();
  }
}
