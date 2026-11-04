import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/builder_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/shape_strings.dart';
import '../../core/l10n/surface_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units/length_unit.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'room_geometry.dart';
import 'room_path.dart';
import 'room_shape_editor.dart';

/// Membuka pembuat furnitur. Mengembalikan furnitur hasil perubahan,
/// atau null jika dibatalkan.
Future<FurnitureItem?> openFurnitureBuilder(
  BuildContext context,
  FurnitureItem item, {
  required double maxWidthCm,
  required double maxLengthCm,
}) {
  return Navigator.of(context).push<FurnitureItem>(
    MaterialPageRoute<FurnitureItem>(
      builder: (_) => FurnitureBuilderScreen(
        item: item,
        maxWidthCm: maxWidthCm,
        maxLengthCm: maxLengthCm,
      ),
    ),
  );
}

class FurnitureBuilderScreen extends StatefulWidget {
  const FurnitureBuilderScreen({
    super.key,
    required this.item,
    required this.maxWidthCm,
    required this.maxLengthCm,
  });

  final FurnitureItem item;
  final double maxWidthCm;
  final double maxLengthCm;

  @override
  State<FurnitureBuilderScreen> createState() => _FurnitureBuilderScreenState();
}

class _FurnitureBuilderScreenState extends State<FurnitureBuilderScreen> {
  late RoomPath _path = _initialPath(widget.item);
  late FurnitureMaterial _material = widget.item.material;

  late final TextEditingController _name = TextEditingController(
    text: widget.item.customName ?? '',
  );
  late final TextEditingController _height;
  late final TextEditingController _thickness;

  LengthUnit _unit = LengthUnit.cm;
  bool _invalid = false;

  /// Bentuk awal: bentuk tersimpan (diskalakan ke ukuran sekarang), atau
  /// dibuat dari bentuk bawaan furnitur.
  static RoomPath _initialPath(FurnitureItem item) {
    final w = item.widthCm;
    final l = item.lengthCm;
    final saved = item.shapePath;

    if (saved != null && saved.isValid) {
      final b = saved.bounds;
      final sx = b.width > 1e-6 ? w / b.width : 1.0;
      final sy = b.height > 1e-6 ? l / b.height : 1.0;

      return RoomPath([
        for (final node in saved.nodes)
          PathNode(
            (node.x - b.minX) * sx,
            (node.y - b.minY) * sy,
            bulge: node.bulge,
          ),
      ]);
    }

    if (item.customPoints.length >= 3) {
      return RoomPath.fromPoints(item.localPoints);
    }

    if (item.shape == FurnitureShape.circle && (w - l).abs() < 1) {
      return RoomPath.circle(w);
    }

    return RoomPath.fromPoints(item.shape.points(w, l));
  }

  @override
  void initState() {
    super.initState();

    _unit =
        context.getInheritedWidgetOfExactType<UnitScope>()?.notifier?.unit ??
        LengthUnit.cm;

    _height = TextEditingController(
      text: _unit.formatValue(widget.item.effectiveHeightCm),
    );
    _thickness = TextEditingController(
      text: _unit.formatValue(widget.item.thicknessCm),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _thickness.dispose();
    super.dispose();
  }

  void _preset(int index) {
    final b = _path.bounds;
    final w = math.max(10.0, b.width);
    final l = math.max(10.0, b.height);

    late final RoomPath next;

    switch (index) {
      case 0:
        next = RoomPath.rectangle(w, l);
        break;
      case 1:
        next = RoomPath.roundedRect(w, l, math.min(w, l) * 0.2);
        break;
      case 2:
        next = RoomPath.circle(math.min(w, l));
        break;
      case 3:
        next = RoomPath.fromPoints(FurnitureShape.lShape.points(w, l));
        break;
      default:
        next = RoomPath.fromPoints(FurnitureShape.uShape.points(w, l));
        break;
    }

    setState(() => _path = next);
  }

  Future<void> _editOutline() async {
    final path = await Navigator.of(context).push<RoomPath>(
      MaterialPageRoute<RoomPath>(
        builder: (_) => RoomShapeEditorScreen(initial: _path),
      ),
    );

    if (path == null || !mounted) return;

    setState(() => _path = path);
  }

  void _save() {
    final h = LengthUnit.parseCm(_height.text, _unit);
    final t = LengthUnit.parseCm(_thickness.text, _unit);

    if (h == null || h <= 0 || t == null || t <= 0 || !_path.isValid) {
      setState(() => _invalid = true);
      return;
    }

    final b = _path.bounds;
    final shifted = _path.shifted(-b.minX, -b.minY);
    final w = math.max(1.0, b.width);
    final l = math.max(1.0, b.height);

    final points = shifted
        .toPolygon(stepDeg: 4)
        .map((p) => RoomPoint(p.x / w, p.y / l))
        .toList();

    var next = widget.item.copyWith(
      widthCm: w,
      lengthCm: l,
      shape: FurnitureShape.polygon,
      customPoints: points,
      shapePath: shifted,
      heightCm: h,
      thicknessCm: t,
      material: _material,
    );

    final name = _name.text.trim();

    next = name.isEmpty
        ? next.copyWith(clearCustomName: true)
        : next.copyWith(customName: name);

    Navigator.pop(
      context,
      next.fittedTo(widget.maxWidthCm, widget.maxLengthCm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final valid = _path.isValid;
    final h = LengthUnit.parseCm(_height.text, _unit) ?? 0;
    final area = valid ? _path.areaCm2 / 10000 : 0.0;
    final volume = area * (h / 100);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.builderTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.white,
              ),
              child: Text(s.apply),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            s.outlineSection,
            style: const TextStyle(
              color: AppColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 210,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: CustomPaint(
              size: Size.infinite,
              painter: _PreviewPainter(
                path: _path,
                color: _material.color,
                unit: _unit,
                valid: valid,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ActionChip(
                label: Text(s.presetRect),
                onPressed: () => _preset(0),
              ),
              ActionChip(
                label: Text(s.presetRounded),
                onPressed: () => _preset(1),
              ),
              ActionChip(
                label: Text(s.presetCircle),
                onPressed: () => _preset(2),
              ),
              ActionChip(label: Text(s.presetL), onPressed: () => _preset(3)),
              ActionChip(label: Text(s.presetU), onPressed: () => _preset(4)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _editOutline,
              icon: const Icon(Icons.architecture),
              label: Text(s.editOutline),
            ),
          ),
          if (!valid)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.invalidShape,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: s.nameLabel,
              counterText: '',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.materialLabel,
            style: const TextStyle(
              color: AppColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final material in FurnitureMaterial.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: material.color,
                    radius: 8,
                  ),
                  label: Text(s.materialName(material)),
                  selected: _material == material,
                  onSelected: (_) => setState(() => _material = material),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.heightLabel,
                    suffixText: _unit.symbol,
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _thickness,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.thicknessLabel,
                    suffixText: _unit.symbol,
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: s.footprintLabel,
                  value: '${area.toStringAsFixed(3)} m²',
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  label: s.volumeLabel,
                  value: '${volume.toStringAsFixed(3)} m³',
                ),
              ],
            ),
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                s.invalidProperties,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.forest,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.path,
    required this.color,
    required this.unit,
    required this.valid,
  });

  final RoomPath path;
  final Color color;
  final LengthUnit unit;
  final bool valid;

  @override
  void paint(Canvas canvas, Size size) {
    final b = path.bounds;
    final w = math.max(b.width, 1.0);
    final h = math.max(b.height, 1.0);
    const pad = 34.0;

    final scale = math
        .min((size.width - pad * 2) / w, (size.height - pad * 2) / h)
        .clamp(0.01, 100.0)
        .toDouble();

    final dx = (size.width - w * scale) / 2 - b.minX * scale;
    final dy = (size.height - h * scale) / 2 - b.minY * scale;

    Offset toScreen(double x, double y) =>
        Offset(dx + x * scale, dy + y * scale);

    final polygon = path
        .toPolygon(stepDeg: 3)
        .map((p) => toScreen(p.x, p.y))
        .toList();

    if (polygon.length >= 3) {
      final shape = Path()..addPolygon(polygon, true);

      canvas.drawPath(shape, Paint()..color = color.withValues(alpha: 0.85));
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.2
          ..color = valid ? AppColors.forest : AppColors.danger,
      );
    }

    void label(String text, Offset center) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }

    label(
      '${unit.formatValue(b.width)} ${unit.symbol}',
      Offset(size.width / 2, dy + h * scale + 16),
    );

    label(
      '${unit.formatValue(b.height)} ${unit.symbol}',
      Offset(dx - 18, size.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) => true;
}
