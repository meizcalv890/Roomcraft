import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/builder_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/language_menu_button.dart';
import '../../core/l10n/model_strings.dart';
import '../../core/l10n/plan_strings.dart';
import '../../core/l10n/pro_strings.dart';
import '../../core/l10n/pro_view_strings.dart';
import '../../core/l10n/shape_strings.dart';
import '../../core/l10n/surface_strings.dart';
import '../../core/l10n/view3d_strings.dart';
import '../../core/storage/roomcraft_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import 'furniture_builder.dart';
import 'furniture_item.dart';
import 'furniture_style.dart';
import 'model_import_screen.dart';
import 'pro_tools.dart';
import 'pro_views.dart';
import 'project_svg.dart';
import 'room_3d_screen.dart';
import 'room_canvas.dart';
import 'room_exporter.dart';
import 'room_geometry.dart';
import 'room_path.dart';
import 'room_project_draft.dart';
import 'room_shape_editor.dart';
import 'room_surface.dart';
import 'surfaces_screen.dart';
import 'wall_plan.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project});

  final RoomProjectDraft project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  final List<FurnitureItem> _items = [];
  String? _selectedId;
  Timer? _saveDebounce;

  /// True jika ada perubahan yang belum tersimpan.
  bool _dirty = false;
  bool _isExporting = false;

  bool _showGrid = true;

  /// Jarak snap dalam cm. 0 berarti snap dimatikan.
  double _snapCm = 5;

  // Magnet ke objek lain dan tepi denah.
  bool _snapObjects = true;

  // Riwayat undo/redo.
  final List<List<FurnitureItem>> _undo = [];
  final List<List<FurnitureItem>> _redo = [];
  List<FurnitureItem> _baseline = [];
  String? _historyDragId;

  // Posisi "mentah" saat menggeser, agar snap tidak membuat furnitur macet.
  String? _dragId;
  double _dragRawX = 0;
  double _dragRawY = 0;

  /// Daftar dinding terbaru dari simpan otomatis editor dinding. // FINISH
  List<RoomSurface>? _surfacesOverride;

  late final List<RoomPoint> _roomPoints;

  double get _areaM2 => widget.project.areaM2;

  /// Dinding terkini: hasil simpan otomatis bila ada, jika tidak bawaan. // FINISH
  List<RoomSurface> get _currentSurfaces =>
      _surfacesOverride ?? widget.project.surfaces;

  FurnitureItem? get _selectedItem {
    for (final item in _items) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _roomPoints = widget.project.effectiveRoomPoints;

    _items.addAll(
      widget.project.furniture.map(
        (item) =>
            item.fittedTo(widget.project.widthCm, widget.project.lengthCm),
      ),
    );

    _baseline = List<FurnitureItem>.of(_items);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();

    // Simpan hanya jika memang ada perubahan yang belum tersimpan.
    if (_dirty) unawaited(_persistProject());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Simpan segera ketika aplikasi masuk latar belakang.
    if (state != AppLifecycleState.resumed) {
      _saveDebounce?.cancel();
      if (_dirty) unawaited(_persistProject());
    }
  }

  Future<void> _persistProject() async {
    if (widget.project.id.isEmpty) return;

    _dirty = false;

    final updatedProject = widget.project.copyWith(
      furniture: List<FurnitureItem>.unmodifiable(_items),
      surfaces: _currentSurfaces, // FINISH
      updatedAt: DateTime.now(),
    );

    try {
      await RoomcraftStorage.saveProject(updatedProject);
    } catch (_) {
      _dirty = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
    }
  }

  /// Menyimpan dengan jeda, tanpa mencatat riwayat.
  void _queueSave() {
    _dirty = true;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_persistProject()),
    );
  }

  /// Dipanggil setelah setiap perubahan furnitur: catat riwayat lalu simpan.
  void _scheduleSave() {
    _recordHistory();
    _queueSave();
  }

  /// Satu kali geser dihitung satu langkah undo.
  void _recordHistory() {
    final dragging = _dragId != null;

    if (dragging && _historyDragId == _dragId) {
      _baseline = List<FurnitureItem>.of(_items);
      return;
    }

    _undo.add(_baseline);

    if (_undo.length > 50) _undo.removeAt(0);

    _redo.clear();
    _baseline = List<FurnitureItem>.of(_items);
    _historyDragId = dragging ? _dragId : null;
  }

  void _undoAction() {
    if (_undo.isEmpty) return;

    setState(() {
      _redo.add(List<FurnitureItem>.of(_items));

      final previous = _undo.removeLast();

      _items
        ..clear()
        ..addAll(previous);

      _baseline = List<FurnitureItem>.of(_items);

      if (_selectedItem == null) _selectedId = null;
    });

    _queueSave();
  }

  void _redoAction() {
    if (_redo.isEmpty) return;

    setState(() {
      _undo.add(List<FurnitureItem>.of(_items));

      final next = _redo.removeLast();

      _items
        ..clear()
        ..addAll(next);

      _baseline = List<FurnitureItem>.of(_items);

      if (_selectedItem == null) _selectedId = null;
    });

    _queueSave();
  }

  double _clampX(FurnitureItem item, double x) {
    final maxX = math.max(0.0, widget.project.widthCm - item.effectiveWidthCm);
    return x.clamp(0.0, maxX).toDouble();
  }

  double _clampY(FurnitureItem item, double y) {
    final maxY = math.max(
      0.0,
      widget.project.lengthCm - item.effectiveLengthCm,
    );
    return y.clamp(0.0, maxY).toDouble();
  }

  double _snap(double value) {
    if (_snapCm <= 0) return value;
    return (value / _snapCm).roundToDouble() * _snapCm;
  }

  /// Menempelkan satu sumbu ke tepi objek lain atau tepi denah bila
  /// jaraknya kurang dari 6 cm.
  double _magnet(double value, FurnitureItem item, bool isX) {
    const threshold = 6.0;

    final size = isX ? item.effectiveWidthCm : item.effectiveLengthCm;
    final limit = isX ? widget.project.widthCm : widget.project.lengthCm;

    final targets = <double>[0, limit - size];

    for (final other in _items) {
      if (other.id == item.id) continue;

      final start = isX ? other.xCm : other.yCm;
      final end = isX ? other.rightCm : other.bottomCm;

      targets.addAll([start, end, start - size, end - size]);
    }

    var best = value;
    var bestDistance = threshold;

    for (final target in targets) {
      final distance = (target - value).abs();

      if (distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }

    return best;
  }

  void _endDrag() {
    _dragId = null;
    _historyDragId = null;
  }

  /// Jarak furnitur ke tepi denah, untuk pemasangan yang presisi.
  String _positionInfo(FurnitureItem item) {
    final right = widget.project.widthCm - item.rightCm;
    final bottom = widget.project.lengthCm - item.bottomCm;

    return context.l10n.positionInfo(
      item.xCm.round(),
      item.yCm.round(),
      right.round(),
      bottom.round(),
    );
  }

  /// Panjang tiap sisi denah lantai (cm), untuk menghubungkan dinding. // FINISH
  List<double> _roomEdgeLengths() {
    final path = widget.project.currentPath;

    return [
      for (var i = 0; i < path.length; i++)
        (path.p(i + 1) - path.p(i)).distance,
    ];
  }

  /// Mencari posisi terdekat dari tengah ruangan yang berada di dalam
  /// bentuk ruangan dan tidak menimpa furnitur lain. Penting untuk bentuk
  /// L/U karena titik tengah bounding box bisa berada di area kosong.
  Offset _findFreeSpot(FurnitureItem item) {
    final w = item.effectiveWidthCm;
    final l = item.effectiveLengthCm;

    final maxX = math.max(0.0, widget.project.widthCm - w);
    final maxY = math.max(0.0, widget.project.lengthCm - l);

    final center = Offset(maxX / 2, maxY / 2);
    final step = math.max(10.0, math.max(maxX, maxY) / 60);

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
      if (!isRectInsidePolygon(c.dx, c.dy, c.dx + w, c.dy + l, _roomPoints)) {
        continue;
      }

      firstInside ??= c;

      final overlaps = _items.any(
        (other) =>
            c.dx < other.rightCm &&
            c.dx + w > other.xCm &&
            c.dy < other.bottomCm &&
            c.dy + l > other.yCm,
      );

      if (!overlaps) return c;
    }

    return firstInside ?? center;
  }

  void _addFurniture(FurnitureType type) {
    var item = FurnitureItem(
      id: IdGenerator.next(),
      type: type,
      xCm: 0,
      yCm: 0,
      widthCm: math.min(type.defaultWidthCm, widget.project.widthCm),
      lengthCm: math.min(type.defaultLengthCm, widget.project.lengthCm),
    );

    final spot = _findFreeSpot(item);
    item = item.copyWith(xCm: spot.dx, yCm: spot.dy);

    setState(() {
      _items.add(item);
      _selectedId = item.id;
    });

    _scheduleSave();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.addedToPlan(type.label)),
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  void _moveFurniture(String id, double dx, double dy) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final item = _items[index];

    // Awal geseran: catat posisi asli furnitur.
    if (_dragId != id) {
      _dragId = id;
      _dragRawX = item.xCm;
      _dragRawY = item.yCm;
    }

    // Posisi mentah terus mengikuti jari; yang ditampilkan adalah hasil snap.
    _dragRawX = _clampX(item, _dragRawX + dx);
    _dragRawY = _clampY(item, _dragRawY + dy);

    var nx = _snap(_dragRawX);
    var ny = _snap(_dragRawY);

    if (_snapObjects) {
      nx = _magnet(nx, item, true);
      ny = _magnet(ny, item, false);
    }

    setState(() {
      _items[index] = item.copyWith(
        xCm: _clampX(item, nx),
        yCm: _clampY(item, ny),
      );
    });

    _scheduleSave();
  }

  void _rotateSelected() {
    final item = _selectedItem;
    if (item == null) return;

    final rotated = item
        .copyWith(rotation: (item.rotation + 90) % 180)
        .fittedTo(widget.project.widthCm, widget.project.lengthCm);

    setState(() {
      final index = _items.indexWhere((entry) => entry.id == item.id);
      if (index != -1) _items[index] = rotated;
    });

    _scheduleSave();
  }

  void _duplicateSelected() {
    final item = _selectedItem;
    if (item == null) return;

    // copyWith mempertahankan bentuk, titik kustom, nama, bahan, dan tinggi.
    final duplicate = item
        .copyWith(
          id: IdGenerator.next(),
          xCm: item.xCm + 20,
          yCm: item.yCm + 20,
        )
        .fittedTo(widget.project.widthCm, widget.project.lengthCm);

    setState(() {
      _items.add(duplicate);
      _selectedId = duplicate.id;
    });

    _scheduleSave();
  }

  /// [factor] mengubah ukuran secara proporsional (mis. 0.9 atau 1.1)
  /// sehingga rasio lebar : panjang furnitur tidak rusak.
  void _resizeSelected(double factor) {
    final item = _selectedItem;
    if (item == null) return;

    final maxFactor = math.min(
      widget.project.widthCm / item.effectiveWidthCm,
      widget.project.lengthCm / item.effectiveLengthCm,
    );

    final minSide = math.min(item.widthCm, item.lengthCm);

    var f = math.min(factor, maxFactor);

    if (f < 1 && minSide * f < 20) f = 20 / minSide;

    // Tidak ada perubahan berarti (sudah mentok minimum atau maksimum).
    if (factor < 1 ? f >= 1 : f <= 1) return;

    final resized = item
        .copyWith(
          widthCm: item.widthCm * f,
          lengthCm: item.lengthCm * f,
          heightCm: item.model != null && item.heightCm > 0
              ? item.heightCm * f
              : null,
        )
        .fittedTo(widget.project.widthCm, widget.project.lengthCm);

    setState(() {
      final index = _items.indexWhere((entry) => entry.id == item.id);
      if (index != -1) _items[index] = resized;
    });

    _scheduleSave();
  }

  void _deleteSelected() {
    final item = _selectedItem;
    if (item == null) return;

    setState(() {
      _items.removeWhere((entry) => entry.id == item.id);
      _selectedId = null;
    });

    _scheduleSave();
  }

  List<String> _computeWarnings(List<WallFootprint> wallPrints) {
    final s = context.l10n;
    final warnings = <String>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];

      // Diperiksa terhadap bentuk ruangan yang sebenarnya, bukan hanya
      // bounding box, sehingga bentuk L/U dan lengkung ikut diperhitungkan.
      final inside = isRectInsidePolygon(
        item.xCm,
        item.yCm,
        item.rightCm,
        item.bottomCm,
        _roomPoints,
      );

      if (!inside) {
        warnings.add(s.warnOutside(item.displayName));
      }

      for (var j = i + 1; j < _items.length; j++) {
        final other = _items[j];

        final overlaps =
            item.xCm < other.rightCm &&
            item.rightCm > other.xCm &&
            item.yCm < other.bottomCm &&
            item.bottomCm > other.yCm;

        if (overlaps) {
          warnings.add(s.warnOverlap(item.displayName, other.displayName));
        }
      }
    }

    for (final hit in findWallHits(wallPrints, _items)) {
      warnings.add(s.warnWallHit(hit.wall.label, hit.floor.displayName));
    }

    return warnings.toSet().toList();
  }

  Future<void> _editSelectedProperties() async {
    final item = _selectedItem;
    if (item == null) return;

    final values = await showDialog<Map<String, double>>(
      context: context,
      builder: (_) => _FurniturePropertiesDialog(item: item),
    );

    if (values == null || !mounted) return;

    final updated = item
        .copyWith(
          xCm: values['x']!,
          yCm: values['y']!,
          widthCm: values['width']!,
          lengthCm: values['length']!,
          rotation: values['rotation']!.round(),
        )
        .fittedTo(widget.project.widthCm, widget.project.lengthCm);

    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) return;

    setState(() => _items[index] = updated);

    _scheduleSave();
  }

  /// Membuka pembuat furnitur untuk objek yang dipilih: bentuk bebas
  /// (lurus dan melengkung), tinggi, tebal papan, dan bahan.
  Future<void> _openBuilder() async {
    final item = _selectedItem;

    if (item == null) return;

    final updated = await openFurnitureBuilder(
      context,
      item,
      maxWidthCm: widget.project.widthCm,
      maxLengthCm: widget.project.lengthCm,
    );

    if (updated == null || !mounted) return;

    final index = _items.indexWhere((entry) => entry.id == item.id);

    if (index == -1) return;

    setState(() => _items[index] = updated);

    _scheduleSave();
  }

  /// Membuka tampilan 3D dengan furnitur dan dinding terkini. // FINISH
  void _open3D() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Room3DScreen(
          project: widget.project.copyWith(surfaces: _currentSurfaces),
          items: List<FurnitureItem>.of(_items),
        ),
      ),
    );
  }

  void _openCutList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CutListScreen(
          items: [
            for (final item in _items)
              if (item.model == null) item,
          ],
        ),
      ),
    );
  }

  void _openClearance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClearanceScreen(
          items: List<FurnitureItem>.of(_items),
          widthCm: widget.project.widthCm,
          lengthCm: widget.project.lengthCm,
        ),
      ),
    );
  }

  /// Alat ukur dua titik dengan magnet ke sudut.
  void _openMeasure() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeasureScreen(
          roomPoints: _roomPoints,
          items: List<FurnitureItem>.of(_items),
        ),
      ),
    );
  }

  /// Tampak depan dan samping furnitur yang dipilih.
  void _openElevation() {
    final item = _selectedItem;

    if (item == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.selectFirst)));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ElevationScreen(item: item)),
    );
  }

  Future<void> _exportSvg() async {
    if (_isExporting) return;

    final s = context.l10n;

    setState(() => _isExporting = true);

    try {
      final bytes = buildProjectSvgBytes(
        title: widget.project.name,
        room: _roomPoints,
        items: List<FurnitureItem>.of(_items),
        wallPrints: buildWallFootprints(
          path: widget.project.currentPath,
          surfaces: _currentSurfaces,
        ),
        surfaces: _currentSurfaces,
      );

      final safeName = widget.project.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      final fileName =
          'roomcraft_${safeName.isEmpty ? "design" : safeName}.svg';

      await SharePlus.instance.share(
        ShareParams(
          title: s.shareTitle,
          files: [
            XFile.fromData(bytes, mimeType: 'image/svg+xml', name: fileName),
          ],
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.exportFailed(error))));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Membuka layar impor model 3D lalu menaruh hasilnya di ruangan.
  Future<void> _importModel() async {
    final imported = await Navigator.of(context).push<FurnitureItem>(
      MaterialPageRoute<FurnitureItem>(
        builder: (_) => ModelImportScreen(
          maxWidthCm: widget.project.widthCm,
          maxLengthCm: widget.project.lengthCm,
        ),
      ),
    );

    if (imported == null || !mounted) return;

    var item = imported.fittedTo(
      widget.project.widthCm,
      widget.project.lengthCm,
    );

    final spot = _findFreeSpot(item);

    item = item.copyWith(xCm: spot.dx, yCm: spot.dy);

    setState(() {
      _items.add(item);
      _selectedId = item.id;
    });

    _scheduleSave();
  }

  Future<void> _showFurnitureCatalog() async {
    final type = await showModalBottomSheet<FurnitureType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FurnitureCatalogSheet(),
    );

    if (type != null && mounted) _addFurniture(type);
  }

  /// Menyimpan daftar dinding setiap kali editor dinding berubah, tanpa
  /// menutup editor. Furnitur terkini ikut disimpan. // FINISH
  Future<void> _autosaveSurfaces(List<RoomSurface> list) async {
    _surfacesOverride = list;

    if (widget.project.id.isEmpty) return;

    try {
      await RoomcraftStorage.saveProject(
        widget.project.copyWith(
          furniture: List<FurnitureItem>.unmodifiable(_items),
          surfaces: list,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Gagal simpan otomatis tidak mengganggu; simpan akhir akan mencoba lagi.
    }
  }

  /// Membuka daftar dinding dan profil bebas. Jika ada perubahan, proyek
  /// disimpan lalu editor dibuka ulang agar data selalu sinkron.
  Future<void> _openSurfaces() async {
    final result = await Navigator.of(context).push<List<RoomSurface>>(
      MaterialPageRoute<List<RoomSurface>>(
        builder: (_) => SurfacesScreen(
          surfaces: _currentSurfaces, // FINISH
          roomEdgeLengthsCm: _roomEdgeLengths(),
          onAutosave: _autosaveSurfaces,
        ),
      ),
    );

    if (result == null || !mounted) return;

    _saveDebounce?.cancel();

    final updated = widget.project.copyWith(
      furniture: List<FurnitureItem>.of(_items),
      surfaces: result,
      updatedAt: DateTime.now(),
    );

    // Mencegah dispose editor lama menimpa data dengan daftar lama.
    _dirty = false;

    try {
      await RoomcraftStorage.saveProject(updated);
    } catch (_) {
      _dirty = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => EditorScreen(project: updated)),
    );
  }

  /// Membuka editor bentuk. Jika diterapkan, proyek disimpan lalu editor
  /// dibuka ulang dengan bentuk baru, sehingga semua perhitungan (grid,
  /// peringatan, ekspor) memakai bentuk yang baru.
  Future<void> _editRoomShape() async {
    final path = await Navigator.of(context).push<RoomPath>(
      MaterialPageRoute<RoomPath>(
        builder: (_) =>
            RoomShapeEditorScreen(initial: widget.project.currentPath),
      ),
    );

    if (path == null || !mounted) return;

    _saveDebounce?.cancel();

    final updated = widget.project
        .copyWith(
          furniture: List<FurnitureItem>.of(_items),
          surfaces: _currentSurfaces, // FINISH
        )
        .withRoomPath(path)
        .copyWith(updatedAt: DateTime.now());

    // Mencegah dispose editor lama menimpa data dengan bentuk lama.
    _dirty = false;

    try {
      await RoomcraftStorage.saveProject(updated);
    } catch (_) {
      _dirty = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
      return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.shapeUpdated;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => EditorScreen(project: updated)),
    );

    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportAndShareDesign() async {
    if (_isExporting) return;

    final s = context.l10n;

    setState(() => _isExporting = true);

    try {
      final pngBytes = await renderRoomPng(
        widthCm: widget.project.widthCm,
        lengthCm: widget.project.lengthCm,
        roomPoints: _roomPoints,
        items: [
          ..._items,
          for (final wall in buildWallFootprints(
            path: widget.project.currentPath,
            surfaces: _currentSurfaces,
          ))
            wall.item,
        ],
      );

      final safeName = widget.project.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      final fileName =
          'roomcraft_${safeName.isEmpty ? "design" : safeName}.png';

      final message = [
        s.shareRoom(widget.project.name),
        s.shareSize(
          widget.project.widthCm.round(),
          widget.project.lengthCm.round(),
        ),
        s.shareArea(_areaM2.toStringAsFixed(2)),
        s.shareFurniture(_items.length),
        s.shareMadeWith,
      ].join('\n');

      await SharePlus.instance.share(
        ShareParams(
          title: s.shareTitle,
          text: message,
          files: [
            XFile.fromData(pngBytes, mimeType: 'image/png', name: fileName),
          ],
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.exportFailed(error))));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final selected = _selectedItem;
    final wallPrints = buildWallFootprints(
      path: widget.project.currentPath,
      surfaces: _currentSurfaces,
    );
    final warnings = _computeWarnings(wallPrints);

    return Scaffold(
      backgroundColor: AppColors.ivory,
       appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: s.view3dTooltip,
            onPressed: _open3D,
            icon: const Icon(Icons.view_in_ar_outlined),
          ),
          IconButton(
            tooltip: s.editShapeTooltip,
            onPressed: _editRoomShape,
            icon: const Icon(Icons.architecture),
          ),
          IconButton(
            tooltip: s.surfacesTooltip,
            onPressed: _openSurfaces,
            icon: const Icon(Icons.layers_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: s.proToolsTooltip,
            icon: const Icon(Icons.construction_outlined),
            onSelected: (value) {
              switch (value) {
                case 'measure':
                  _openMeasure();
                case 'elevation':
                  _openElevation();
                case 'cut':
                  _openCutList();
                case 'gap':
                  _openClearance();
                case 'svg':
                  unawaited(_exportSvg());
                case 'model':
                  unawaited(_importModel());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'measure', child: Text(s.measureMenu)),
              PopupMenuItem(value: 'elevation', child: Text(s.elevationMenu)),
              PopupMenuItem(value: 'cut', child: Text(s.cutListMenu)),
              PopupMenuItem(value: 'gap', child: Text(s.clearanceMenu)),
              PopupMenuItem(value: 'svg', child: Text(s.exportSvgMenu)),
              PopupMenuItem(value: 'model', child: Text(s.modelMenu)),
            ],
          ),
          IconButton(
            tooltip: s.exportTooltip,
            onPressed: _isExporting ? null : _exportAndShareDesign,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                      Text(
                        s.workspaceTitle,
                        style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const LanguageMenuButton(compact: true),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.plan2d,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _RoomMetrics(
              widthCm: widget.project.widthCm,
              lengthCm: widget.project.lengthCm,
              areaM2: _areaM2,
              itemCount: _items.length,
            ),
            _GridControls(
              showGrid: _showGrid,
              snapCm: _snapCm,
              snapObjects: _snapObjects,
              canUndo: _undo.isNotEmpty,
              canRedo: _redo.isNotEmpty,
              onUndo: _undoAction,
              onRedo: _redoAction,
              onToggleGrid: () => setState(() => _showGrid = !_showGrid),
              onToggleSnapObjects: () =>
                  setState(() => _snapObjects = !_snapObjects),
              onSnapChanged: (value) => setState(() => _snapCm = value),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: RoomCanvas(
                        widthCm: widget.project.widthCm,
                        lengthCm: widget.project.lengthCm,
                        roomPoints: _roomPoints,
                        items: [
                          ..._items,
                          for (final wall in wallPrints) wall.item,
                        ],
                        selectedId: _selectedId,
                        showGrid: _showGrid,
                        onSelect: (id) => setState(
                          () => _selectedId = isWallFootprintId(id) ? null : id,
                        ),
                        onMove: (id, dx, dy) {
                          if (isWallFootprintId(id)) return;
                          _moveFurniture(id, dx, dy);
                        },
                        onMoveEnd: _endDrag,
                      ),
                    ),
                  ),
                  if (warnings.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: _LayoutWarningPanel(warnings: warnings),
                      ),
                    ),
                ],
              ),
            ),
            if (selected != null)
              _SelectedFurnitureToolbar(
                item: selected,
                infoText: _positionInfo(selected),
                onRotate: _rotateSelected,
                onDuplicate: _duplicateSelected,
                onSmaller: () => _resizeSelected(0.9),
                onLarger: () => _resizeSelected(1.1),
                onEditProperties: _editSelectedProperties,
                onBuilder: _openBuilder,
                onDelete: _deleteSelected,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showFurnitureCatalog,
                  icon: const Icon(Icons.add),
                  label: Text(s.addFurniture),
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
    );
  }
}

class _RoomMetrics extends StatelessWidget {
  const _RoomMetrics({
    required this.widthCm,
    required this.lengthCm,
    required this.areaM2,
    required this.itemCount,
  });

  final double widthCm;
  final double lengthCm;
  final double areaM2;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: s.metricDimensions,
              value: '${widthCm.round()} × ${lengthCm.round()} cm',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: s.metricArea,
              value: '${areaM2.toStringAsFixed(2)} m²',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: s.metricFurniture,
              value: s.objectsCount(itemCount),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.7,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kontrol undo/redo, grid, magnet, dan snap di atas kanvas.
class _GridControls extends StatelessWidget {
  const _GridControls({
    required this.showGrid,
    required this.snapCm,
    required this.snapObjects,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleGrid,
    required this.onToggleSnapObjects,
    required this.onSnapChanged,
  });

  final bool showGrid;
  final double snapCm;
  final bool snapObjects;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleSnapObjects;
  final ValueChanged<double> onSnapChanged;

  static const _snapOptions = [0.0, 1.0, 5.0, 10.0, 25.0];

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: s.undoLabel,
              visualDensity: VisualDensity.compact,
              onPressed: canUndo ? onUndo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: s.redoLabel,
              visualDensity: VisualDensity.compact,
              onPressed: canRedo ? onRedo : null,
              icon: const Icon(Icons.redo),
            ),
            const SizedBox(width: 4),
            FilterChip(
              avatar: const Icon(Icons.grid_4x4, size: 16),
              label: Text(s.grid),
              selected: showGrid,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onToggleGrid(),
            ),
            const SizedBox(width: 6),
            FilterChip(
              avatar: const Icon(Icons.filter_center_focus, size: 16),
              label: Text(s.snapObjects),
              selected: snapObjects,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onToggleSnapObjects(),
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
            for (final option in _snapOptions)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(option == 0 ? s.snapOff : '${option.round()} cm'),
                  selected: snapCm == option,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSnapChanged(option),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Katalog furnitur. Dibuat sebagai StatefulWidget sendiri agar pencarian
/// dan kategori tidak ter-reset ketika sheet dibangun ulang
/// (mis. saat keyboard muncul).
class _FurnitureCatalogSheet extends StatefulWidget {
  const _FurnitureCatalogSheet();

  @override
  State<_FurnitureCatalogSheet> createState() => _FurnitureCatalogSheetState();
}

class _FurnitureCatalogSheetState extends State<_FurnitureCatalogSheet> {
  /// null berarti "semua kategori".
  static final List<FurnitureCategory?> _categories = [
    null,
    ...FurnitureCategory.values,
  ];

  String _query = '';
  FurnitureCategory? _category;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    final filtered = FurnitureType.values.where((type) {
      final matchesQuery = type.label.toLowerCase().contains(
        _query.toLowerCase(),
      );
      final matchesCategory = _category == null || type.category == _category;

      return matchesQuery && matchesCategory;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
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
            const SizedBox(height: 18),
            Text(
              s.chooseFurniture,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.catalogSubtitle,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(s.categoryLabel(value)),
                          selected: _category == value,
                          onSelected: (_) => setState(() => _category = value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(s.furnitureNotFound)),
                    )
                  : GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                      children: filtered
                          .map(
                            (type) => _CatalogTile(
                              type: type,
                              onTap: () => Navigator.pop(context, type),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.type, required this.onTap});

  final FurnitureType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(type.icon, color: AppColors.forest, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${type.defaultWidthCm.round()} × '
                '${type.defaultLengthCm.round()} cm',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FurniturePropertiesDialog extends StatefulWidget {
  const _FurniturePropertiesDialog({required this.item});

  final FurnitureItem item;

  @override
  State<_FurniturePropertiesDialog> createState() =>
      _FurniturePropertiesDialogState();
}

class _FurniturePropertiesDialogState
    extends State<_FurniturePropertiesDialog> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _widthController;
  late final TextEditingController _lengthController;
  late int _rotation;

  bool _invalid = false;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _xController = TextEditingController(text: item.xCm.toStringAsFixed(0));
    _yController = TextEditingController(text: item.yCm.toStringAsFixed(0));
    _widthController = TextEditingController(
      text: item.widthCm.toStringAsFixed(0),
    );
    _lengthController = TextEditingController(
      text: item.lengthCm.toStringAsFixed(0),
    );
    _rotation = item.isRotated ? 90 : 0;
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.'));
  }

  void _apply() {
    final x = _parse(_xController);
    final y = _parse(_yController);
    final width = _parse(_widthController);
    final length = _parse(_lengthController);

    if (x == null ||
        y == null ||
        width == null ||
        length == null ||
        !x.isFinite ||
        !y.isFinite ||
        !width.isFinite ||
        !length.isFinite ||
        width <= 0 ||
        length <= 0 ||
        x < 0 ||
        y < 0) {
      // Ditampilkan di dalam dialog, karena Snackbar akan tertutup dialog.
      setState(() => _invalid = true);
      return;
    }

    Navigator.pop<Map<String, double>>(context, {
      'x': x,
      'y': y,
      'width': width,
      'length': length,
      'rotation': _rotation.toDouble(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(s.propertiesOf(widget.item.displayName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PropertyInput(label: s.posX, controller: _xController),
            _PropertyInput(label: s.posY, controller: _yController),
            _PropertyInput(label: s.widthCm, controller: _widthController),
            _PropertyInput(label: s.lengthCm, controller: _lengthController),
            Text(
              s.rotation,
              style: const TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('0°')),
                ButtonSegment(value: 90, label: Text('90°')),
              ],
              selected: {_rotation},
              onSelectionChanged: (value) =>
                  setState(() => _rotation = value.first),
            ),
            const SizedBox(height: 10),
            Text(
              s.positionNote,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (_invalid) ...[
              const SizedBox(height: 8),
              Text(
                s.invalidProperties,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
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

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    ),
  );
}

class _LayoutWarningPanel extends StatelessWidget {
  const _LayoutWarningPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1D6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8C47C)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: Color(0xFF8A5A00),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            warnings.take(2).join(' '),
            style: const TextStyle(fontSize: 11, color: Color(0xFF684500)),
          ),
        ),
        if (warnings.length > 2)
          Text(
            '+${warnings.length - 2}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
      ],
    ),
  );
}

class _SelectedFurnitureToolbar extends StatelessWidget {
  const _SelectedFurnitureToolbar({
    required this.item,
    required this.infoText,
    required this.onRotate,
    required this.onDuplicate,
    required this.onSmaller,
    required this.onLarger,
    required this.onEditProperties,
    required this.onBuilder,
    required this.onDelete,
  });

  final FurnitureItem item;
  final String infoText;
  final VoidCallback onRotate;
  final VoidCallback onDuplicate;
  final VoidCallback onSmaller;
  final VoidCallback onLarger;
  final VoidCallback onEditProperties;
  final VoidCallback onBuilder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

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
                '${item.effectiveWidthCm.round()} × '
                '${item.effectiveLengthCm.round()} cm',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            infoText,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 4,
            runSpacing: 0,
            children: [
              _ToolButton(
                icon: Icons.rotate_90_degrees_cw_outlined,
                label: s.toolRotate,
                onTap: onRotate,
              ),
              _ToolButton(
                icon: Icons.copy_outlined,
                label: s.toolDuplicate,
                onTap: onDuplicate,
              ),
              _ToolButton(
                icon: Icons.remove,
                label: s.toolSmaller,
                onTap: onSmaller,
              ),
              _ToolButton(
                icon: Icons.add,
                label: s.toolLarger,
                onTap: onLarger,
              ),
              _ToolButton(
                icon: Icons.tune_outlined,
                label: s.toolAdjust,
                onTap: onEditProperties,
              ),
              _ToolButton(
                icon: Icons.handyman_outlined,
                label: s.builderTool,
                onTap: onBuilder,
              ),
              _ToolButton(
                icon: Icons.delete_outline,
                label: s.toolDelete,
                onTap: onDelete,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: danger ? AppColors.danger : AppColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
}
