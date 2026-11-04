import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'furniture_item.dart';
import 'furniture_material.dart';
import 'room_geometry.dart';
import 'room_surface.dart';
import 'wall_plan.dart';

String _xml(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _n(double v) => v.toStringAsFixed(1);

/// SVG skala 1:1 (cm): denah lantai beserta objek dinding, lalu tiap
/// permukaan (dinding/profil) di bawahnya.
String buildProjectSvg({
  required String title,
  required List<RoomPoint> room,
  required List<FurnitureItem> items,
  required List<WallFootprint> wallPrints,
  required List<RoomSurface> surfaces,
}) {
  var minX = double.infinity;
  var maxX = -double.infinity;
  var minY = double.infinity;
  var maxY = -double.infinity;

  for (final p in room) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }

  if (room.isEmpty) {
    minX = 0;
    maxX = 100;
    minY = 0;
    maxY = 100;
  }

  const pad = 50.0;
  const gap = 90.0;

  final planW = maxX - minX;
  final planH = maxY - minY;

  // Tata letak lembar dinding di bawah denah.
  var totalMaxX = maxX;
  var cursorY = maxY + gap;

  final sheets = StringBuffer();

  for (final surface in surfaces) {
    final ox = minX;
    final oy = cursorY;
    final w = surface.widthCm;
    final h = surface.heightCm;

    sheets.writeln(
      '<text x="${_n(ox)}" y="${_n(oy - 14)}" font-size="14" '
      'fill="#1f3d2b">${_xml(surface.name)} — ${w.round()} × ${h.round()} cm'
      '</text>',
    );

    for (var x = 0.0; x <= w; x += 50) {
      sheets.writeln(
        '<line x1="${_n(ox + x)}" y1="${_n(oy)}" x2="${_n(ox + x)}" '
        'y2="${_n(oy + h)}" stroke="#d8d2c4" stroke-width="0.5"/>',
      );
    }

    for (var y = 0.0; y <= h; y += 50) {
      sheets.writeln(
        '<line x1="${_n(ox)}" y1="${_n(oy + y)}" x2="${_n(ox + w)}" '
        'y2="${_n(oy + y)}" stroke="#d8d2c4" stroke-width="0.5"/>',
      );
    }

    final outline = surface.polygon
        .map((p) => '${_n(ox + p.x)},${_n(oy + p.y)}')
        .join(' ');

    sheets.writeln(
      '<polygon points="$outline" fill="#f7f3ea" fill-opacity="0.6" '
      'stroke="#1f3d2b" stroke-width="2"/>',
    );

    for (final item in surface.items) {
      final iw = item.effectiveWidthCm;
      final ih = item.effectiveLengthCm;

      final fill = item.openingKind == 'window'
          ? '#bfd9e6'
          : _hex(item.material.color);

      sheets.writeln(
        '<rect x="${_n(ox + item.xCm)}" y="${_n(oy + item.yCm)}" '
        'width="${_n(iw)}" height="${_n(ih)}" fill="$fill" '
        'fill-opacity="0.75" stroke="#333333" stroke-width="1"/>',
      );

      final cx = ox + item.xCm + iw / 2;
      final cy = oy + item.yCm + ih / 2;

      sheets.writeln(
        '<text x="${_n(cx)}" y="${_n(cy)}" font-size="11" '
        'text-anchor="middle" fill="#1f3d2b">${_xml(item.displayName)}</text>',
      );
      sheets.writeln(
        '<text x="${_n(cx)}" y="${_n(cy + 13)}" font-size="9" '
        'text-anchor="middle" fill="#555555">'
        '${iw.round()} × ${ih.round()}</text>',
      );
    }

    totalMaxX = math.max(totalMaxX, ox + w);
    cursorY = oy + h + gap;
  }

  final totalMaxY = surfaces.isEmpty ? maxY : cursorY - gap;

  final vbW = totalMaxX - minX + pad * 2;
  final vbH = totalMaxY - minY + pad * 2;

  final b = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${_n(vbW)}cm" height="${_n(vbH)}cm" '
      'viewBox="${_n(minX - pad)} ${_n(minY - pad)} ${_n(vbW)} ${_n(vbH)}" '
      'font-family="sans-serif">',
    )
    ..writeln('<title>${_xml(title)}</title>')
    ..writeln(
      '<rect x="${_n(minX - pad)}" y="${_n(minY - pad)}" '
      'width="${_n(vbW)}" height="${_n(vbH)}" fill="#ffffff"/>',
    );

  for (var x = (minX / 100).ceil() * 100.0; x <= maxX; x += 100) {
    b.writeln(
      '<line x1="${_n(x)}" y1="${_n(minY)}" x2="${_n(x)}" y2="${_n(maxY)}" '
      'stroke="#d8d2c4" stroke-width="0.5"/>',
    );
  }

  for (var y = (minY / 100).ceil() * 100.0; y <= maxY; y += 100) {
    b.writeln(
      '<line x1="${_n(minX)}" y1="${_n(y)}" x2="${_n(maxX)}" y2="${_n(y)}" '
      'stroke="#d8d2c4" stroke-width="0.5"/>',
    );
  }

  b.writeln(
    '<polygon points="${room.map((p) => '${_n(p.x)},${_n(p.y)}').join(' ')}" '
    'fill="#f7f3ea" fill-opacity="0.6" stroke="#1f3d2b" stroke-width="2"/>',
  );

  for (final item in items) {
    final pts = floorPolygon(item);

    b.writeln(
      '<polygon points="${pts.map((p) => '${_n(p.dx)},${_n(p.dy)}').join(' ')}" '
      'fill="${_hex(item.material.color)}" fill-opacity="0.75" '
      'stroke="#333333" stroke-width="1"/>',
    );

    final cx = item.xCm + item.effectiveWidthCm / 2;
    final cy = item.yCm + item.effectiveLengthCm / 2;

    b.writeln(
      '<text x="${_n(cx)}" y="${_n(cy)}" font-size="12" text-anchor="middle" '
      'fill="#1f3d2b">${_xml(item.displayName)}</text>',
    );
    b.writeln(
      '<text x="${_n(cx)}" y="${_n(cy + 14)}" font-size="9" '
      'text-anchor="middle" fill="#555555">'
      '${item.effectiveWidthCm.round()} × ${item.effectiveLengthCm.round()}'
      '</text>',
    );
  }

  // Objek dinding di denah: garis putus-putus, di atas furnitur lantai.
  for (final wall in wallPrints) {
    b.writeln(
      '<polygon points="${wall.polygon.map((p) => '${_n(p.dx)},${_n(p.dy)}').join(' ')}" '
      'fill="${_hex(wall.item.material.color)}" fill-opacity="0.55" '
      'stroke="#7a4b1e" stroke-width="1" stroke-dasharray="4 3"/>',
    );

    final cx = wall.item.xCm + wall.item.widthCm / 2;
    final cy = wall.item.yCm + wall.item.lengthCm / 2;

    b.writeln(
      '<text x="${_n(cx)}" y="${_n(cy)}" font-size="9" text-anchor="middle" '
      'fill="#7a4b1e">${_xml(wall.label)}</text>',
    );
  }

  b.writeln(
    '<text x="${_n(minX + planW / 2)}" y="${_n(minY - 20)}" font-size="14" '
    'text-anchor="middle" fill="#1f3d2b">${planW.round()} cm</text>',
  );
  b.writeln(
    '<text transform="translate(${_n(minX - 20)} ${_n(minY + planH / 2)}) '
    'rotate(-90)" font-size="14" text-anchor="middle" fill="#1f3d2b">'
    '${planH.round()} cm</text>',
  );

  b.write(sheets.toString());
  b.writeln('</svg>');

  return b.toString();
}

Uint8List buildProjectSvgBytes({
  required String title,
  required List<RoomPoint> room,
  required List<FurnitureItem> items,
  required List<WallFootprint> wallPrints,
  required List<RoomSurface> surfaces,
}) {
  return Uint8List.fromList(
    utf8.encode(
      buildProjectSvg(
        title: title,
        room: room,
        items: items,
        wallPrints: wallPrints,
        surfaces: surfaces,
      ),
    ),
  );
}
