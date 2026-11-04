import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/builder_strings.dart';
import '../../core/l10n/finish_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/shape_strings.dart';
import '../../core/l10n/surface_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units/length_unit.dart';
import '../../core/utils/id_generator.dart';
import 'furniture_builder.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'furniture_painter.dart';
import 'furniture_style.dart';
import 'room_geometry.dart';
import 'room_path.dart';
import 'room_shape_editor.dart';
import 'room_surface.dart';

class _SView {
  const _SView(this.scale, this.origin);

  /// Piksel per cm.
  final double scale;

  /// Posisi layar dari titik dunia (0, 0).
  final Offset origin;

  Offset toScreen(double x, double y) =>
      Offset(origin.dx + x * scale, origin.dy + y * scale);

  Offset toWorld(Offset p) =>
      Offset((p.dx - origin.dx) / scale, (p.dy - origin.dy) / scale);
}

/// Pilihan dari katalog: tipe furnitur atau bukaan (pintu/jendela).
class _CatalogPick {
  const _CatalogPick.type(FurnitureType this.type) : opening = null;
  const _CatalogPick.opening(String this.opening) : type = null;

  final FurnitureType? type;
  final String? opening;
}

/// Editor satu permukaan (dinding atau profil bebas).
/// Mengembalikan [RoomSurface] hasil perubahan lewat Navigator.pop.
///
/// [roomEdgeLengthsCm] berisi panjang tiap sisi denah lantai agar dinding
/// bisa dihubungkan ke salah satunya (tampil di 3D). [onChanged] dipanggil
/// beberapa saat setelah perubahan, untuk simpan otomatis.
class SurfaceEditorScreen extends StatefulWidget {
  const SurfaceEditorScreen({
    super.key,
    required this.surface,
    this.roomEdgeLengthsCm = const [],
    this.onChanged,
  });

  final RoomSurface surface;
  final List<double> roomEdgeLengthsCm;
  final ValueChanged<RoomSurface>? onChanged;

  @override
  State<SurfaceEditorScreen> createState() => _SurfaceEditorScreenState();
}

class _SurfaceEditorScreenState extends State<SurfaceEditorScreen> {
  late RoomSurface _surface = widget.surface;

  // Simpan otomatis: perubahan dideteksi dari objek permukaan yang diganti.
  RoomSurface? _reported;
  Timer? _autosave;

  String? _selectedId;
  bool _showGrid = true;

  double? _scale;
  Offset? _origin;
  Size _viewSize = Size.zero;

  String? _dragId;
  double _dragRawX = 0;
  double _dragRawY = 0;

  double _gestureStartScale = 1;
  Offset _gestureStartOrigin = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  FurnitureItem? get _selected {
    for (final item in _surface.items) {
      if (item.id == _selectedId) return item;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    _reported = widget.surface;
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Simpan otomatis
  // ------------------------------------------------------------------

  void _noteChange() {
    if (identical(_surface, _reported)) return;

    _reported = _surface;

    if (widget.onChanged == null) return;

    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush() {
    _autosave?.cancel();
    _autosave = null;

    widget.onChanged?.call(_surface);
  }

  // ------------------------------------------------------------------
  // Tampilan
  // ------------------------------------------------------------------

  _SView _fit(Size size) {
    final w = _surface.widthCm;
    final h = _surface.heightCm;
    const pad = 56.0;

    final s = math
        .min((size.width - pad * 2) / w, (size.height - pad * 2) / h)
        .clamp(0.05, 80.0)
        .toDouble();

    return _SView(
      s,
      Offset((size.width - w * s) / 2, (size.height - h * s) / 2),
    );
  }

  _SView _view() {
    final s = _scale;
    final o = _origin;

    if (s != null && o != null) return _SView(s, o);

    return _fit(_viewSize);
  }

  void _freezeView() {
    final v = _view();
    _scale = v.scale;
    _origin = v.origin;
  }

  void _resetView() {
    setState(() {
      _scale = null;
      _origin = null;
    });
  }

  void _zoomAt(Offset focal, double factor) {
    final v = _view();
    final ns = (v.scale * factor).clamp(0.05, 80.0).toDouble();
    final world = v.toWorld(focal);

    setState(() {
      _scale = ns;
      _origin = focal - world * ns;
    });
  }

  // ------------------------------------------------------------------
  // Pembantu perubahan
  // ------------------------------------------------------------------

  void _updateItem(FurnitureItem updated) {
    setState(() {
      _surface = _surface.copyWith(
        items: [
          for (final item in _surface.items)
            item.id == updated.id ? updated : item,
        ],
      );
    });
  }

  double _clampX(FurnitureItem item, double x) {
    final maxX = math.max(0.0, _surface.widthCm - item.effectiveWidthCm);
    return x.clamp(0.0, maxX).toDouble();
  }

  double _clampY(FurnitureItem item, double y) {
    final maxY = math.max(0.0, _surface.heightCm - item.effectiveLengthCm);
    return y.clamp(0.0, maxY).toDouble();
  }

  double _snap(double value) {
    final step = _surface.snapCm;

    if (step <= 0) return value;

    return (value / step).roundToDouble() * step;
  }

  FurnitureItem? _hitItem(Offset screenPos, _SView v) {
    final world = v.toWorld(screenPos);

    bool contains(FurnitureItem item) =>
        world.dx >= item.xCm &&
        world.dx <= item.rightCm &&
        world.dy >= item.yCm &&
        world.dy <= item.bottomCm;

    // Objek terpilih digambar paling atas, jadi diperiksa lebih dulu.
    final selected = _selected;

    if (selected != null && contains(selected)) return selected;

    for (final item in _surface.items.reversed) {
      if (contains(item)) return item;
    }

    return null;
  }

  // ------------------------------------------------------------------
  // Gestur
  // ------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    final item = _hitItem(details.localPosition, _view());

    setState(() => _selectedId = item?.id);
  }

  void _onScaleStart(ScaleStartDetails details) {
    final v = _view();

    _dragId = null;

    if (details.pointerCount == 1) {
      final item = _hitItem(details.localFocalPoint, v);

      if (item != null) {
        _freezeView();

        setState(() {
          _dragId = item.id;
          _dragRawX = item.xCm;
          _dragRawY = item.yCm;
          _selectedId = item.id;
        });

        return;
      }
    }

    _freezeView();

    _gestureStartScale = v.scale;
    _gestureStartOrigin = v.origin;
    _gestureStartFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final v = _view();
    final dragId = _dragId;

    if (dragId != null) {
      FurnitureItem? item;

      for (final candidate in _surface.items) {
        if (candidate.id == dragId) item = candidate;
      }

      if (item == null) return;

      // Posisi mentah mengikuti jari; yang ditampilkan adalah hasil snap.
      _dragRawX = _clampX(
        item,
        _dragRawX + details.focalPointDelta.dx / v.scale,
      );
      _dragRawY = _clampY(
        item,
        _dragRawY + details.focalPointDelta.dy / v.scale,
      );

      _updateItem(
        item.copyWith(
          xCm: _clampX(item, _snap(_dragRawX)),
          yCm: _clampY(item, _snap(_dragRawY)),
        ),
      );

      return;
    }

    final ns = (_gestureStartScale * details.scale)
        .clamp(0.05, 80.0)
        .toDouble();

    final world0 = Offset(
      (_gestureStartFocal.dx - _gestureStartOrigin.dx) / _gestureStartScale,
      (_gestureStartFocal.dy - _gestureStartOrigin.dy) / _gestureStartScale,
    );

    setState(() {
      _scale = ns;
      _origin = details.localFocalPoint - world0 * ns;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _dragId = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _zoomAt(event.localPosition, event.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12);
    }
  }

  // ------------------------------------------------------------------
  // Aksi objek
  // ------------------------------------------------------------------

  /// Posisi terdekat dari tengah yang berada di dalam bentuk permukaan
  /// dan tidak menimpa objek lain.
  Offset _findFreeSpot(FurnitureItem item) {
    final w = item.effectiveWidthCm;
    final h = item.effectiveLengthCm;

    final maxX = math.max(0.0, _surface.widthCm - w);
    final maxY = math.max(0.0, _surface.heightCm - h);

    final center = Offset(maxX / 2, maxY / 2);
    final step = math.max(10.0, math.max(maxX, maxY) / 60);
    final polygon = _surface.polygon;

    final candidates = <Offset>[center];

    for (var y = 0.0; y <= maxY; y += step) {
      for (var x = 0.0; x <= maxX; x += step) {
        candidates.add(Offset(x, y));
      }
    }

    candidates.sort(
      (a, b) =>
          (a - center).distanceSquared.compareTo((b - center).distanceSquared),
    );

    Offset? firstInside;

    for (final c in candidates) {
      if (!isRectInsidePolygon(c.dx, c.dy, c.dx + w, c.dy + h, polygon)) {
        continue;
      }

      firstInside ??= c;

      final overlaps = _surface.items.any(
        (other) =>
            c.dx < other.rightCm &&
            c.dx + w > other.xCm &&
            c.dy < other.bottomCm &&
            c.dy + h > other.yCm,
      );

      if (!overlaps) return c;
    }

    return firstInside ?? center;
  }

  Future<void> _addObject() async {
    final pick = await showModalBottomSheet<_CatalogPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ObjectCatalog(),
    );

    if (pick == null || !mounted) return;

    final s = context.l10n;
    final opening = pick.opening;

    FurnitureItem item;

    if (opening != null) {
      final isDoor = opening == 'door';

      item = FurnitureItem(
        id: IdGenerator.next(),
        type: FurnitureType.custom,
        xCm: 0,
        yCm: 0,
        widthCm: math.min(isDoor ? 90.0 : 120.0, _surface.widthCm),
        lengthCm: math.min(isDoor ? 210.0 : 120.0, _surface.heightCm),
        customName: isDoor ? s.doorName : s.windowName,
        material: isDoor ? FurnitureMaterial.wood : FurnitureMaterial.glass,
        openingKind: opening,
      );

      final spot = _findFreeSpot(item);

      // Pintu berdiri di lantai; jendela dengan ambang 90 cm.
      final sill = isDoor ? 0.0 : 90.0;
      final y = math.max(0.0, _surface.heightCm - sill - item.lengthCm);

      item = item
          .copyWith(xCm: spot.dx, yCm: y)
          .fittedTo(_surface.widthCm, _surface.heightCm);
    } else {
      final type = pick.type!;

      item = FurnitureItem(
        id: IdGenerator.next(),
        type: type,
        xCm: 0,
        yCm: 0,
        widthCm: math.min(type.defaultWidthCm, _surface.widthCm),
        lengthCm: math.min(type.defaultLengthCm, _surface.heightCm),
      );

      final spot = _findFreeSpot(item);
      item = item.copyWith(xCm: spot.dx, yCm: spot.dy);
    }

    setState(() {
      _surface = _surface.copyWith(items: [..._surface.items, item]);
      _selectedId = item.id;
    });
  }

  void _rotateSelected() {
    final item = _selected;

    if (item == null) return;

    _updateItem(
      item
          .copyWith(rotation: (item.rotation + 90) % 180)
          .fittedTo(_surface.widthCm, _surface.heightCm),
    );
  }

  void _duplicateSelected() {
    final item = _selected;

    if (item == null) return;

    final duplicate = item
        .copyWith(
          id: IdGenerator.next(),
          xCm: item.xCm + 20,
          yCm: item.yCm + 20,
        )
        .fittedTo(_surface.widthCm, _surface.heightCm);

    setState(() {
      _surface = _surface.copyWith(items: [..._surface.items, duplicate]);
      _selectedId = duplicate.id;
    });
  }

  void _deleteSelected() {
    final item = _selected;

    if (item == null) return;

    setState(() {
      _surface = _surface.copyWith(
        items: _surface.items.where((entry) => entry.id != item.id).toList(),
      );
      _selectedId = null;
    });
  }

  Future<void> _editSelected() async {
    final item = _selected;

    if (item == null) return;

    final updated = await showDialog<FurnitureItem>(
      context: context,
      builder: (_) => _ObjectDialog(
        item: item,
        unit: _surface.unit,
        surfaceWidth: _surface.widthCm,
        surfaceHeight: _surface.heightCm,
      ),
    );

    if (updated == null || !mounted) return;

    _updateItem(updated);
  }

  /// Pembuat furnitur: bentuk bebas, bahan, tebal, dan kedalaman tonjolan.
  Future<void> _openBuilder() async {
    final item = _selected;

    if (item == null) return;

    final updated = await openFurnitureBuilder(
      context,
      item,
      maxWidthCm: _surface.widthCm,
      maxLengthCm: _surface.heightCm,
    );

    if (updated == null || !mounted) return;

    _updateItem(updated);
  }

  Future<void> _editShape() async {
    final path = await Navigator.of(context).push<RoomPath>(
      MaterialPageRoute<RoomPath>(
        builder: (_) => RoomShapeEditorScreen(initial: _surface.path),
      ),
    );

    if (path == null || !mounted) return;

    setState(() {
      _surface = _surface.withPath(path);
      _scale = null;
      _origin = null;
    });
  }

  // ------------------------------------------------------------------
  // Pengaturan permukaan (satuan, grid, snap)
  // ------------------------------------------------------------------

  List<double> _gridOptions() {
    if (_surface.unit == LengthUnit.inch) {
      return const [0, 2.54, 12.7, 30.48, 60.96];
    }

    return const [0, 1, 5, 10, 25, 50, 100];
  }

  List<double> _snapOptions() {
    switch (_surface.unit) {
      case LengthUnit.cm:
        return const [0, 0.5, 1, 5, 10, 25];
      case LengthUnit.mm:
        return const [0, 0.5, 1, 5, 10];
      case LengthUnit.m:
        return const [0, 5, 10, 25, 50];
      case LengthUnit.inch:
        return const [0, 1.27, 2.54, 12.7, 30.48];
    }
  }

  void _setUnit(LengthUnit unit) {
    var next = _surface.copyWith(unit: unit);

    // Pilihan grid dan snap menyesuaikan satuan baru.
    final grid = unit == LengthUnit.inch
        ? const [0.0, 2.54, 12.7, 30.48, 60.96]
        : const [0.0, 1.0, 5.0, 10.0, 25.0, 50.0, 100.0];

    if (!grid.contains(next.gridCm)) next = next.copyWith(gridCm: 0);

    setState(() => _surface = next);

    final snaps = _snapOptions();

    if (!snaps.contains(_surface.snapCm)) {
      setState(() {
        _surface = _surface.copyWith(snapCm: snaps.length > 1 ? snaps[1] : 0);
      });
    }
  }

  // ------------------------------------------------------------------
  // Tampilan
  // ------------------------------------------------------------------

  List<FurnitureItem> _outsideItems() {
    final polygon = _surface.polygon;

    return _surface.items
        .where(
          (item) => !isRectInsidePolygon(
            item.xCm,
            item.yCm,
            item.rightCm,
            item.bottomCm,
            polygon,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    _noteChange();

    final s = context.l10n;
    final unit = _surface.unit;
    final selected = _selected;
    final outside = _outsideItems();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Simpan perubahan terakhir sebelum menutup.
        _flush();
        Navigator.of(context).pop(_surface);
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        appBar: AppBar(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.forest,
          elevation: 0,
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _surface.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${unit.formatValue(_surface.widthCm)} × '
                '${unit.formatValue(_surface.heightCm)} ${unit.symbol}',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: s.editShapeTooltip,
              onPressed: _editShape,
              icon: const Icon(Icons.architecture),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildToolbar(s),
              Expanded(child: _buildCanvas(s)),
              if (outside.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8C47C)),
                  ),
                  child: Text(
                    s.outsideSurface,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF684500),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      Text(
                        s.surfaceHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      if (widget.onChanged != null)
                        Text(
                          s.autosaved,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              if (selected != null) _buildSelectedBar(s, selected),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addObject,
                    icon: const Icon(Icons.add),
                    label: Text(s.addObject),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  /// Pemilih sisi denah untuk dinding (dipakai tampilan 3D).
  Widget _buildEdgeLink(AppStrings s) {
    final unit = _surface.unit;
    final edges = widget.roomEdgeLengthsCm;
    final linked = _surface.edgeIndex < edges.length ? _surface.edgeIndex : -1;

    String len(double cm) => '${unit.formatValue(cm)} ${unit.symbol}';

    return PopupMenuButton<int>(
      tooltip: s.linkEdgeTooltip,
      onSelected: (value) =>
          setState(() => _surface = _surface.copyWith(edgeIndex: value)),
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Text(
              s.linkEdgeNote,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ),
        CheckedPopupMenuItem<int>(
          value: -1,
          checked: linked < 0,
          child: Text(s.linkEdgeNone),
        ),
        for (var i = 0; i < edges.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: linked == i,
            child: Text(s.linkEdgeItem(i + 1, len(edges[i]))),
          ),
      ],
      child: _chipBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 16),
            const SizedBox(width: 4),
            Text(
              linked < 0
                  ? s.linkEdgeTitle
                  : s.linkEdgeItem(linked + 1, len(edges[linked])),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(AppStrings s) {
    final unit = _surface.unit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_surface.kind == SurfaceKind.wall &&
                widget.roomEdgeLengthsCm.isNotEmpty) ...[
              _buildEdgeLink(s),
              const SizedBox(width: 8),
            ],
            PopupMenuButton<LengthUnit>(
              tooltip: s.unitLabel,
              onSelected: _setUnit,
              itemBuilder: (_) => [
                for (final value in LengthUnit.values)
                  CheckedPopupMenuItem<LengthUnit>(
                    value: value,
                    checked: value == unit,
                    child: Text(value.symbol),
                  ),
              ],
              child: _chipBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten, size: 16),
                    const SizedBox(width: 4),
                    Text(unit.symbol, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: const Icon(Icons.grid_4x4, size: 16),
              label: Text(s.grid),
              selected: _showGrid,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _showGrid = !_showGrid),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<double>(
              tooltip: s.gridSizeLabel,
              onSelected: (value) =>
                  setState(() => _surface = _surface.copyWith(gridCm: value)),
              itemBuilder: (_) => [
                for (final option in _gridOptions())
                  CheckedPopupMenuItem<double>(
                    value: option,
                    checked: _surface.gridCm == option,
                    child: Text(
                      option == 0 ? s.gridAuto : unit.formatWithUnit(option),
                    ),
                  ),
              ],
              child: _chipBox(
                child: Text(
                  '${s.gridSizeLabel}: '
                  '${_surface.gridCm == 0 ? s.gridAuto : unit.formatWithUnit(_surface.gridCm)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              s.snap,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            for (final option in _snapOptions())
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    option == 0
                        ? s.snapOff
                        : '${unit.formatValue(option)} ${unit.symbol}',
                  ),
                  selected: _surface.snapCm == option,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(
                    () => _surface = _surface.copyWith(snapCm: option),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(AppStrings s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewSize = constraints.biggest;

          final view = _view();
          final steps = _surfaceGridSteps(
            view.scale,
            _surface.unit,
            _surface.gridCm,
          );

          return Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SurfacePainter(
                        surface: _surface,
                        view: view,
                        selectedId: _selectedId,
                        showGrid: _showGrid,
                        legend: s.shapeGridLegend(
                          _surface.unit.formatWithUnit(steps.minor),
                          _surface.unit.formatWithUnit(steps.major),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ZoomButton(
                          icon: Icons.add,
                          tooltip: s.zoomIn,
                          onTap: () => _zoomAt(
                            constraints.biggest.center(Offset.zero),
                            1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ZoomButton(
                          icon: Icons.remove,
                          tooltip: s.zoomOut,
                          onTap: () => _zoomAt(
                            constraints.biggest.center(Offset.zero),
                            1 / 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ZoomButton(
                          icon: Icons.fit_screen,
                          tooltip: s.resetView,
                          onTap: _resetView,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedBar(AppStrings s, FurnitureItem item) {
    final unit = _surface.unit;

    String fmt(double cm) => unit.formatValue(cm);

    final distances = s.surfaceDistances(
      fmt(item.xCm),
      fmt(item.yCm),
      fmt(_surface.widthCm - item.rightCm),
      fmt(_surface.heightCm - item.bottomCm),
    );

    Widget tool(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool danger = false,
    }) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: danger ? AppColors.danger : AppColors.forest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          minimumSize: const Size(44, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
              Expanded(
                child: Text(
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${fmt(item.effectiveWidthCm)} × '
                '${fmt(item.effectiveLengthCm)} ${unit.symbol}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            distances,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          if (!item.isOpening) ...[
            const SizedBox(height: 2),
            Text(
              s.wallDepthNote,
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 4,
            children: [
              tool(
                Icons.rotate_90_degrees_cw_outlined,
                s.toolRotate,
                _rotateSelected,
              ),
              tool(Icons.copy_outlined, s.toolDuplicate, _duplicateSelected),
              tool(Icons.tune_outlined, s.toolAdjust, _editSelected),
              tool(Icons.handyman_outlined, s.builderTool, _openBuilder),
              tool(
                Icons.delete_outline,
                s.toolDelete,
                _deleteSelected,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Katalog dan dialog
// ----------------------------------------------------------------------

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.forest, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectCatalog extends StatelessWidget {
  const _ObjectCatalog();

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.chooseFurniture,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                children: [
                  _CatalogTile(
                    icon: Icons.door_front_door_outlined,
                    color: FurnitureMaterial.wood.color,
                    label: s.doorName,
                    onTap: () => Navigator.pop(
                      context,
                      const _CatalogPick.opening('door'),
                    ),
                  ),
                  _CatalogTile(
                    icon: Icons.window_outlined,
                    color: FurnitureMaterial.glass.color,
                    label: s.windowName,
                    onTap: () => Navigator.pop(
                      context,
                      const _CatalogPick.opening('window'),
                    ),
                  ),
                  for (final type in FurnitureType.values)
                    _CatalogTile(
                      icon: type.icon,
                      color: type.color,
                      label: type.label,
                      onTap: () =>
                          Navigator.pop(context, _CatalogPick.type(type)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectDialog extends StatefulWidget {
  const _ObjectDialog({
    required this.item,
    required this.unit,
    required this.surfaceWidth,
    required this.surfaceHeight,
  });

  final FurnitureItem item;
  final LengthUnit unit;
  final double surfaceWidth;
  final double surfaceHeight;

  @override
  State<_ObjectDialog> createState() => _ObjectDialogState();
}

class _ObjectDialogState extends State<_ObjectDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item.customName ?? '',
  );
  late final TextEditingController _x = _controller(widget.item.xCm);
  late final TextEditingController _y = _controller(widget.item.yCm);
  late final TextEditingController _w = _controller(widget.item.widthCm);
  late final TextEditingController _h = _controller(widget.item.lengthCm);

  bool _invalid = false;

  TextEditingController _controller(double cm) =>
      TextEditingController(text: widget.unit.formatValue(cm));

  @override
  void dispose() {
    _name.dispose();
    _x.dispose();
    _y.dispose();
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) =>
      LengthUnit.parseCm(controller.text, widget.unit);

  void _apply() {
    final x = _parse(_x);
    final y = _parse(_y);
    final w = _parse(_w);
    final h = _parse(_h);

    if (x == null ||
        y == null ||
        w == null ||
        h == null ||
        w <= 0 ||
        h <= 0 ||
        x < 0 ||
        y < 0) {
      setState(() => _invalid = true);
      return;
    }

    final name = _name.text.trim();

    final base = widget.item.copyWith(xCm: x, yCm: y, widthCm: w, lengthCm: h);

    final named = name.isEmpty
        ? base.copyWith(clearCustomName: true)
        : base.copyWith(customName: name);

    Navigator.pop(
      context,
      named.fittedTo(widget.surfaceWidth, widget.surfaceHeight),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          suffixText: number ? widget.unit.symbol : null,
          filled: true,
          fillColor: AppColors.white,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(s.objectProperties),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(s.nameLabel, _name, number: false),
            _field('X', _x),
            _field('Y', _y),
            _field(s.width, _w),
            _field(s.heightLabel, _h),
            if (_invalid)
              Text(
                s.invalidProperties,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _apply, child: Text(s.apply)),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        elevation: 1,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: AppColors.forest),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Grid dan painter
// ----------------------------------------------------------------------

class _Steps {
  const _Steps(this.minor, this.major);

  final double minor;
  final double major;
}

const List<double> _metricList = [
  0.1,
  0.5,
  1,
  5,
  10,
  25,
  50,
  100,
  200,
  500,
  1000,
  2000,
  5000,
];

const List<double> _inchList = [
  0.635,
  1.27,
  2.54,
  12.7,
  30.48,
  60.96,
  152.4,
  304.8,
  762,
  1524,
  3048,
];

/// Jika [overrideCm] > 0, grid memakai jarak itu (diperbesar otomatis bila
/// terlalu rapat di layar). Jika tidak, mengikuti zoom.
_Steps _surfaceGridSteps(double scale, LengthUnit unit, double overrideCm) {
  if (overrideCm > 0) {
    var minor = overrideCm;

    while (minor * scale < 6) {
      minor *= 2;
    }

    return _Steps(minor, minor * 5);
  }

  final list = unit == LengthUnit.inch ? _inchList : _metricList;

  var minor = list.last;

  for (final step in list) {
    if (step * scale >= 10) {
      minor = step;
      break;
    }
  }

  var major = minor * 5;

  for (final step in list) {
    if (step >= minor * 4 - 1e-9) {
      final ratio = step / minor;

      if ((ratio - ratio.roundToDouble()).abs() < 1e-6) {
        major = step;
        break;
      }
    }
  }

  return _Steps(minor, major);
}

void _label(
  Canvas canvas,
  String text,
  Offset center, {
  double fontSize = 10.5,
  Color color = AppColors.forest,
  Color? background,
  FontWeight weight = FontWeight.w600,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final topLeft = center - Offset(painter.width / 2, painter.height / 2);

  if (background != null) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (topLeft & painter.size).inflate(3),
        const Radius.circular(5),
      ),
      Paint()..color = background,
    );
  }

  painter.paint(canvas, topLeft);
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.surface,
    required this.view,
    required this.selectedId,
    required this.showGrid,
    required this.legend,
  });

  final RoomSurface surface;
  final _SView view;
  final String? selectedId;
  final bool showGrid;
  final String legend;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.canvas);

    if (showGrid) _paintGrid(canvas, size);

    _paintShape(canvas);
    _paintItems(canvas);
    _paintEdgeLabels(canvas);

    _label(
      canvas,
      legend,
      const Offset(12, 14),
      fontSize: 10,
      color: AppColors.muted,
      weight: FontWeight.w700,
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final steps = _surfaceGridSteps(view.scale, surface.unit, surface.gridCm);
    final topLeft = view.toWorld(Offset.zero);
    final bottomRight = view.toWorld(Offset(size.width, size.height));

    final minorPaint = Paint()
      ..color = AppColors.gridMinor
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = AppColors.gridMajor
      ..strokeWidth = 1.4;

    void lines({required bool vertical}) {
      final from = vertical ? topLeft.dx : topLeft.dy;
      final to = vertical ? bottomRight.dx : bottomRight.dy;

      final k0 = (from / steps.minor).floor();
      final k1 = (to / steps.minor).ceil();

      for (var k = k0; k <= k1; k++) {
        final value = k * steps.minor;
        final ratio = value / steps.major;
        final isMajor = (ratio - ratio.roundToDouble()).abs() < 1e-6;
        final paint = isMajor ? majorPaint : minorPaint;

        if (vertical) {
          final x = view.origin.dx + value * view.scale;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        } else {
          final y = view.origin.dy + value * view.scale;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      }
    }

    lines(vertical: true);
    lines(vertical: false);
  }

  void _paintShape(Canvas canvas) {
    final polygon = surface.polygon
        .map((point) => view.toScreen(point.x, point.y))
        .toList();

    final shapePath = Path()..addPolygon(polygon, true);

    canvas.drawPath(shapePath, Paint()..color = AppColors.canvasRoom);

    canvas.drawPath(
      shapePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.4
        ..color = AppColors.forest,
    );
  }

  void _paintItems(Canvas canvas) {
    void draw(FurnitureItem item, {required bool selected}) {
      final size = Size(
        item.effectiveWidthCm * view.scale,
        item.effectiveLengthCm * view.scale,
      );

      canvas.save();
      canvas.translate(
        view.origin.dx + item.xCm * view.scale,
        view.origin.dy + item.yCm * view.scale,
      );

      FurniturePainter(
        item: item,
        name: item.displayName,
        pixelsPerCm: view.scale,
        selected: selected,
      ).paint(canvas, size);

      canvas.restore();
    }

    FurnitureItem? selectedItem;

    for (final item in surface.items) {
      if (item.id == selectedId) {
        selectedItem = item;
      } else {
        draw(item, selected: false);
      }
    }

    if (selectedItem != null) draw(selectedItem, selected: true);
  }

  void _paintEdgeLabels(Canvas canvas) {
    final path = surface.path;
    final unit = surface.unit;
    final orient = path.orientation.toDouble();

    for (var i = 0; i < path.length; i++) {
      final a = path.p(i);
      final c = path.p(i + 1);
      final chord = (c - a).distance;

      if (chord < 1e-6) continue;

      final dir = (c - a) / chord;
      final perp = Offset(-dir.dy, dir.dx);
      final outward = perp * (-orient);

      final mid = path.pointAt(i, 0.5);
      final position = view.toScreen(mid.dx, mid.dy) + outward * 16;

      final arc = path.arcOf(i);

      final text = arc == null
          ? unit.formatValue(chord)
          : '${unit.formatValue(chord)} · R${unit.formatValue(arc.radius)}';

      _label(
        canvas,
        text,
        position,
        background: Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SurfacePainter oldDelegate) => true;
}
