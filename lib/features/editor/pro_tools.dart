import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/builder_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/pro_strings.dart';
import '../../core/theme/app_theme.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'room_geometry.dart';

// ======================================================================
// Daftar potong
// ======================================================================

enum PartKind { top, bottom, frontBack, sides, sideStrip }

class CutPart {
  const CutPart({
    required this.itemName,
    required this.kind,
    required this.qty,
    required this.aCm,
    required this.bCm,
    required this.thicknessCm,
    required this.material,
  });

  final String itemName;
  final PartKind kind;
  final int qty;
  final double aCm;
  final double bCm;
  final double thicknessCm;
  final FurnitureMaterial material;

  double get areaM2 => qty * aCm * bCm / 10000;
}

double polygonArea(List<Offset> pts) {
  var sum = 0.0;

  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }

  return sum.abs() / 2;
}

double polygonPerimeter(List<Offset> pts) {
  var sum = 0.0;

  for (var i = 0; i < pts.length; i++) {
    sum += (pts[(i + 1) % pts.length] - pts[i]).distance;
  }

  return sum;
}

List<CutPart> buildCutList(List<FurnitureItem> items) {
  final parts = <CutPart>[];

  for (final item in items) {
    final local = [for (final p in item.localPoints) Offset(p.x, p.y)];
    final t = item.thicknessCm;
    final inner = item.effectiveHeightCm - 2 * t;
    final isBox = local.length == 4;
    final name = item.displayName;
    final mat = item.material;

    CutPart part(PartKind k, int q, double a, double b) => CutPart(
      itemName: name,
      kind: k,
      qty: q,
      aCm: a,
      bCm: b,
      thicknessCm: t,
      material: mat,
    );

    if (isBox) {
      parts.add(part(PartKind.top, 1, item.widthCm, item.lengthCm));
      parts.add(part(PartKind.bottom, 1, item.widthCm, item.lengthCm));

      if (inner > 0) {
        parts.add(part(PartKind.frontBack, 2, item.widthCm, inner));
        parts.add(part(PartKind.sides, 2, item.lengthCm, inner));
      }
    } else {
      final area = polygonArea(local);
      final side = area <= 0 ? 0.0 : area;

      // Papan outline dihitung sebagai bidang dengan luas sebenarnya.
      parts.add(part(PartKind.top, 1, math.sqrt(side), math.sqrt(side)));
      parts.add(part(PartKind.bottom, 1, math.sqrt(side), math.sqrt(side)));

      if (inner > 0) {
        parts.add(part(PartKind.sideStrip, 1, polygonPerimeter(local), inner));
      }
    }
  }

  return parts;
}

Map<FurnitureMaterial, List<CutPart>> groupByMaterial(List<CutPart> parts) {
  final map = <FurnitureMaterial, List<CutPart>>{};

  for (final p in parts) {
    map.putIfAbsent(p.material, () => []).add(p);
  }

  return map;
}

const double sheetAreaM2 = 1.22 * 2.44;

int sheetsFor(double areaM2) =>
    areaM2 <= 0 ? 0 : (areaM2 * 1.15 / sheetAreaM2).ceil();

String _n(double v) =>
    v.roundToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String partLabel(AppStrings s, PartKind k) {
  switch (k) {
    case PartKind.top:
      return s.partTop;
    case PartKind.bottom:
      return s.partBottom;
    case PartKind.frontBack:
      return s.partFrontBack;
    case PartKind.sides:
      return s.partSides;
    case PartKind.sideStrip:
      return s.partSideStrip;
  }
}

String cutListText(AppStrings s, List<CutPart> parts) {
  final b = StringBuffer();

  groupByMaterial(parts).forEach((material, list) {
    final area = list.fold<double>(0, (sum, p) => sum + p.areaM2);

    b.writeln('== ${s.materialName(material)} ==');

    for (final p in list) {
      b.writeln(
        '${p.itemName} | ${partLabel(s, p.kind)} | '
        '${s.qtyLabel} ${p.qty} | ${_n(p.aCm)} x ${_n(p.bCm)} x '
        '${_n(p.thicknessCm)} cm',
      );
    }

    b.writeln(s.totalPanelArea(area.toStringAsFixed(2)));
    b.writeln(s.sheetsNeeded(sheetsFor(area)));
    b.writeln();
  });

  return b.toString();
}

class CutListScreen extends StatelessWidget {
  const CutListScreen({super.key, required this.items});

  final List<FurnitureItem> items;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final parts = buildCutList(items);
    final groups = groupByMaterial(parts);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.cutListTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: s.copyText,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: parts.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final done = s.copiedText;

                    await Clipboard.setData(
                      ClipboardData(text: cutListText(s, parts)),
                    );

                    messenger.showSnackBar(SnackBar(content: Text(done)));
                  },
          ),
        ],
      ),
      body: parts.isEmpty
          ? Center(child: Text(s.noFurnitureYet))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final entry in groups.entries) ...[
                  _MaterialGroup(
                    title: s.materialName(entry.key),
                    color: entry.key.color,
                    parts: entry.value,
                    s: s,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  s.cutListNote,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
    );
  }
}

class _MaterialGroup extends StatelessWidget {
  const _MaterialGroup({
    required this.title,
    required this.color,
    required this.parts,
    required this.s,
  });

  final String title;
  final Color color;
  final List<CutPart> parts;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final area = parts.fold<double>(0, (sum, p) => sum + p.areaM2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.itemName} · ${partLabel(s, p.kind)} ×${p.qty}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${_n(p.aCm)} × ${_n(p.bCm)} × ${_n(p.thicknessCm)} cm',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 18),
          Text(
            s.totalPanelArea(area.toStringAsFixed(2)),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            s.sheetsNeeded(sheetsFor(area)),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Cek jarak dan lorong
// ======================================================================

class GapIssue {
  const GapIssue(this.a, this.b, this.gapCm);

  final String a;

  /// Null berarti celah ke tepi ruangan.
  final String? b;
  final double gapCm;
}

double _rectGap(FurnitureItem a, FurnitureItem b) {
  final dx = math.max(0.0, math.max(b.xCm - a.rightCm, a.xCm - b.rightCm));
  final dy = math.max(0.0, math.max(b.yCm - a.bottomCm, a.yCm - b.bottomCm));

  return math.sqrt(dx * dx + dy * dy);
}

List<GapIssue> computeGaps(
  List<FurnitureItem> items,
  double widthCm,
  double lengthCm,
  double minCm,
) {
  final issues = <GapIssue>[];

  for (var i = 0; i < items.length; i++) {
    final a = items[i];

    for (var j = i + 1; j < items.length; j++) {
      final gap = _rectGap(a, items[j]);

      if (gap < minCm) {
        issues.add(GapIssue(a.displayName, items[j].displayName, gap));
      }
    }

    // Celah sempit di belakang atau samping furnitur (menempel = wajar).
    final edges = [
      a.xCm,
      widthCm - a.rightCm,
      a.yCm,
      lengthCm - a.bottomCm,
    ].where((v) => v > 0.5 && v < minCm);

    if (edges.isNotEmpty) {
      issues.add(GapIssue(a.displayName, null, edges.reduce(math.min)));
    }
  }

  issues.sort((x, y) => x.gapCm.compareTo(y.gapCm));

  return issues;
}

class ClearanceScreen extends StatefulWidget {
  const ClearanceScreen({
    super.key,
    required this.items,
    required this.widthCm,
    required this.lengthCm,
  });

  final List<FurnitureItem> items;
  final double widthCm;
  final double lengthCm;

  @override
  State<ClearanceScreen> createState() => _ClearanceScreenState();
}

class _ClearanceScreenState extends State<ClearanceScreen> {
  double _min = 60;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final issues = computeGaps(
      widget.items,
      widget.widthCm,
      widget.lengthCm,
      _min,
    );

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.clearanceTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.minGapLabel('${_min.round()} cm'),
                style: const TextStyle(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Slider(
            min: 30,
            max: 120,
            divisions: 18,
            value: _min,
            onChanged: (v) => setState(() => _min = v),
          ),
          Expanded(
            child: widget.items.isEmpty
                ? Center(child: Text(s.noFurnitureYet))
                : issues.isEmpty
                ? Center(child: Text(s.allClear))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: issues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final issue = issues[index];
                      final cm = _n(issue.gapCm);
                      final bad = issue.gapCm < 1;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bad
                              ? const Color(0xFFFFE9E5)
                              : const Color(0xFFFFF1D6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          issue.b == null
                              ? s.gapToEdge(issue.a, cm)
                              : s.gapBetween(issue.a, issue.b!, cm),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              s.gapNote,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Ekspor SVG skala 1:1 (satuan cm)
// ======================================================================

String _xml(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String buildRoomSvg({
  required String title,
  required List<RoomPoint> room,
  required List<FurnitureItem> items,
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
  final w = maxX - minX;
  final h = maxY - minY;

  String n(double v) => v.toStringAsFixed(1);

  final b = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${n(w + pad * 2)}cm" height="${n(h + pad * 2)}cm" '
      'viewBox="${n(minX - pad)} ${n(minY - pad)} '
      '${n(w + pad * 2)} ${n(h + pad * 2)}" '
      'font-family="sans-serif">',
    )
    ..writeln('<title>${_xml(title)}</title>')
    ..writeln(
      '<rect x="${n(minX - pad)}" y="${n(minY - pad)}" '
      'width="${n(w + pad * 2)}" height="${n(h + pad * 2)}" fill="#ffffff"/>',
    );

  for (var x = (minX / 100).ceil() * 100.0; x <= maxX; x += 100) {
    b.writeln(
      '<line x1="${n(x)}" y1="${n(minY)}" x2="${n(x)}" y2="${n(maxY)}" '
      'stroke="#d8d2c4" stroke-width="0.5"/>',
    );
  }

  for (var y = (minY / 100).ceil() * 100.0; y <= maxY; y += 100) {
    b.writeln(
      '<line x1="${n(minX)}" y1="${n(y)}" x2="${n(maxX)}" y2="${n(y)}" '
      'stroke="#d8d2c4" stroke-width="0.5"/>',
    );
  }

  b.writeln(
    '<polygon points="${room.map((p) => '${n(p.x)},${n(p.y)}').join(' ')}" '
    'fill="#f7f3ea" fill-opacity="0.6" stroke="#1f3d2b" stroke-width="2"/>',
  );

  for (final item in items) {
    final pts = [
      for (final p in item.localPoints)
        Offset(
          item.xCm + (item.isRotated ? item.lengthCm - p.y : p.x),
          item.yCm + (item.isRotated ? p.x : p.y),
        ),
    ];

    b.writeln(
      '<polygon points="${pts.map((p) => '${n(p.dx)},${n(p.dy)}').join(' ')}" '
      'fill="${_hex(item.material.color)}" fill-opacity="0.75" '
      'stroke="#333333" stroke-width="1"/>',
    );

    final cx = item.xCm + item.effectiveWidthCm / 2;
    final cy = item.yCm + item.effectiveLengthCm / 2;

    b.writeln(
      '<text x="${n(cx)}" y="${n(cy)}" font-size="12" text-anchor="middle" '
      'fill="#1f3d2b">${_xml(item.displayName)}</text>',
    );
    b.writeln(
      '<text x="${n(cx)}" y="${n(cy + 14)}" font-size="9" '
      'text-anchor="middle" fill="#555555">'
      '${item.effectiveWidthCm.round()} × ${item.effectiveLengthCm.round()}'
      '</text>',
    );
  }

  b.writeln(
    '<text x="${n(minX + w / 2)}" y="${n(minY - 20)}" font-size="14" '
    'text-anchor="middle" fill="#1f3d2b">${w.round()} cm</text>',
  );
  b.writeln(
    '<text transform="translate(${n(minX - 20)} ${n(minY + h / 2)}) '
    'rotate(-90)" font-size="14" text-anchor="middle" fill="#1f3d2b">'
    '${h.round()} cm</text>',
  );

  b.writeln('</svg>');

  return b.toString();
}

Uint8List buildRoomSvgBytes({
  required String title,
  required List<RoomPoint> room,
  required List<FurnitureItem> items,
}) {
  return Uint8List.fromList(
    utf8.encode(buildRoomSvg(title: title, room: room, items: items)),
  );
}
