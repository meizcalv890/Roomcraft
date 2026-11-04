import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/shape_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units/length_unit.dart';
import 'room_geometry.dart';
import 'room_path.dart';


const Color _accent = Color(0xFFE08A1E);

enum _DragKind { none, node, arc }

enum _HitKind { none, node, arc, edge }

class _Hit {
  const _Hit(this.kind, [this.index = 0]);

  final _HitKind kind;
  final int index;
}

class _View {
  const _View(this.scale, this.origin);

  /// Piksel per cm.
  final double scale;

  /// Posisi layar dari titik dunia (0, 0).
  final Offset origin;

  Offset toScreen(double x, double y) =>
      Offset(origin.dx + x * scale, origin.dy + y * scale);

  Offset toWorld(Offset p) =>
      Offset((p.dx - origin.dx) / scale, (p.dy - origin.dy) / scale);
}

/// Layar penyunting bentuk ruangan. Mengembalikan [RoomPath] baru lewat
/// Navigator.pop jika pengguna menekan "Terapkan".
class RoomShapeEditorScreen extends StatefulWidget {
  const RoomShapeEditorScreen({super.key, required this.initial});

  final RoomPath initial;

  @override
  State<RoomShapeEditorScreen> createState() => _RoomShapeEditorScreenState();
}

class _RoomShapeEditorScreenState extends State<RoomShapeEditorScreen> {
  static LengthUnit _lastUnit = LengthUnit.cm;

  late RoomPath _path = widget.initial;

  final List<RoomPath> _undo = [];
  final List<RoomPath> _redo = [];

  LengthUnit _unit = _lastUnit;
  bool _showGrid = true;
  bool _align = true;
  double _snapCm = 5;

  int? _selNode;
  int? _selEdge;
  int _tab = 0; // 0 = sisi, 1 = titik

  // Tampilan. Null berarti otomatis pas ke layar.
  double? _scale;
  Offset? _origin;
  Size _viewSize = Size.zero;

  // Keadaan gestur.
  _DragKind _drag = _DragKind.none;
  int _dragIndex = 0;
  bool _dragMoved = false;
  Offset _grab = Offset.zero;
  double _gestureStartScale = 1;
  Offset _gestureStartOrigin = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  bool get _dirty => !_path.sameAs(widget.initial);

  @override
  void initState() {
    super.initState();
    _unit =
        context.getInheritedWidgetOfExactType<UnitScope>()?.notifier?.unit ??
        _lastUnit;

    final options = _snapOptions();

    if (!options.contains(_snapCm)) {
      _snapCm = options.length > 1 ? options[1] : 0;
    }
  }

  // ------------------------------------------------------------------
  // Tampilan dan koordinat
  // ------------------------------------------------------------------

  _View _fit(Size size) {
    final b = _path.bounds;
    const pad = 56.0;

    final w = math.max(b.width, 1.0);
    final h = math.max(b.height, 1.0);

    final s = math
        .min((size.width - pad * 2) / w, (size.height - pad * 2) / h)
        .clamp(0.05, 80.0)
        .toDouble();

    return _View(
      s,
      Offset(
        (size.width - w * s) / 2 - b.minX * s,
        (size.height - h * s) / 2 - b.minY * s,
      ),
    );
  }

  _View _view() {
    final s = _scale;
    final o = _origin;

    if (s != null && o != null) return _View(s, o);

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
  // Perubahan bentuk, undo, redo
  // ------------------------------------------------------------------

  void _apply(RoomPath next, {bool keepView = true}) {
    if (next.sameAs(_path)) return;

    if (keepView && _scale == null) _freezeView();

    setState(() {
      _undo.add(_path);

      if (_undo.length > 100) _undo.removeAt(0);

      _redo.clear();
      _path = next;
      _fixSelection();

      if (!keepView) {
        _scale = null;
        _origin = null;
      }
    });
  }

  void _fixSelection() {
    final n = _path.length;

    if (_selNode != null && _selNode! >= n) _selNode = null;
    if (_selEdge != null && _selEdge! >= n) _selEdge = null;
  }

  void _undoStep() {
    if (_undo.isEmpty) return;

    setState(() {
      _redo.add(_path);
      _path = _undo.removeLast();
      _fixSelection();
    });
  }

  void _redoStep() {
    if (_redo.isEmpty) return;

    setState(() {
      _undo.add(_path);
      _path = _redo.removeLast();
      _fixSelection();
    });
  }

  /// Dipanggil sekali pada gerakan pertama sebuah seretan.
  void _beginDragChange() {
    if (_dragMoved) return;

    _dragMoved = true;
    _undo.add(_path);

    if (_undo.length > 100) _undo.removeAt(0);

    _redo.clear();
  }

  // ------------------------------------------------------------------
  // Snap
  // ------------------------------------------------------------------

  List<double> _snapOptions() {
    switch (_unit) {
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

  double _snapValue(double value) {
    if (_snapCm <= 0) return value;

    return (value / _snapCm).roundToDouble() * _snapCm;
  }

  void _setUnit(LengthUnit unit) {
    context.getInheritedWidgetOfExactType<UnitScope>()?.notifier?.setUnit(unit);
    setState(() {
      _unit = unit;
      _lastUnit = unit;

      final options = _snapOptions();

      if (!options.contains(_snapCm)) {
        _snapCm = options.length > 1 ? options[1] : 0;
      }
    });
  }

  // ------------------------------------------------------------------
  // Pencarian objek di bawah jari
  // ------------------------------------------------------------------

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;

    if (len2 < 1e-9) return (p - a).distance;

    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2)
        .clamp(0.0, 1.0)
        .toDouble();

    return (p - (a + ab * t)).distance;
  }

  _Hit _hitTest(Offset pos, _View v) {
    const nodeRadius = 20.0;
    const edgeRadius = 12.0;

    int? bestNode;
    var best = nodeRadius;

    for (var i = 0; i < _path.length; i++) {
      final n = _path.nodes[i];
      final d = (v.toScreen(n.x, n.y) - pos).distance;

      if (d <= best) {
        best = d;
        bestNode = i;
      }
    }

    if (bestNode != null) return _Hit(_HitKind.node, bestNode);

    int? bestArc;
    best = nodeRadius;

    for (var i = 0; i < _path.length; i++) {
      final m = _path.pointAt(i, 0.5);
      final d = (v.toScreen(m.dx, m.dy) - pos).distance;

      if (d <= best) {
        best = d;
        bestArc = i;
      }
    }

    if (bestArc != null) return _Hit(_HitKind.arc, bestArc);

    int? bestEdge;
    best = edgeRadius;

    for (var i = 0; i < _path.length; i++) {
      final pts = _path
          .edgePolyline(i, stepDeg: 8)
          .map((o) => v.toScreen(o.dx, o.dy))
          .toList();

      for (var k = 0; k < pts.length - 1; k++) {
        final d = _distToSegment(pos, pts[k], pts[k + 1]);

        if (d <= best) {
          best = d;
          bestEdge = i;
        }
      }
    }

    if (bestEdge != null) return _Hit(_HitKind.edge, bestEdge);

    return const _Hit(_HitKind.none);
  }

  // ------------------------------------------------------------------
  // Gestur
  // ------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    final hit = _hitTest(details.localPosition, _view());

    setState(() {
      switch (hit.kind) {
        case _HitKind.node:
          _selNode = hit.index;
          _selEdge = null;
          _tab = 1;
          break;
        case _HitKind.arc:
        case _HitKind.edge:
          _selEdge = hit.index;
          _selNode = null;
          _tab = 0;
          break;
        case _HitKind.none:
          _selNode = null;
          _selEdge = null;
          break;
      }
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    final v = _view();

    _drag = _DragKind.none;
    _dragMoved = false;

    if (details.pointerCount == 1) {
      final hit = _hitTest(details.localFocalPoint, v);

      if (hit.kind == _HitKind.node) {
        final n = _path.nodes[hit.index];

        _freezeView();

        setState(() {
          _drag = _DragKind.node;
          _dragIndex = hit.index;
          _grab = v.toScreen(n.x, n.y) - details.localFocalPoint;
          _selNode = hit.index;
          _selEdge = null;
          _tab = 1;
        });

        return;
      }

      if (hit.kind == _HitKind.arc) {
        final m = _path.pointAt(hit.index, 0.5);

        _freezeView();

        setState(() {
          _drag = _DragKind.arc;
          _dragIndex = hit.index;
          _grab = v.toScreen(m.dx, m.dy) - details.localFocalPoint;
          _selEdge = hit.index;
          _selNode = null;
          _tab = 0;
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

    switch (_drag) {
      case _DragKind.node:
        final target = v.toWorld(details.localFocalPoint + _grab);

        var x = _snapValue(target.dx);
        var y = _snapValue(target.dy);

        if (_align) {
          // Menempel ke sumbu titik tetangga agar sisi tegak/mendatar.
          final tolerance = 8 / v.scale;

          for (final q in [_path.p(_dragIndex - 1), _path.p(_dragIndex + 1)]) {
            if ((x - q.dx).abs() <= tolerance) x = q.dx;
            if ((y - q.dy).abs() <= tolerance) y = q.dy;
          }
        }

        _beginDragChange();
        setState(() => _path = _path.moveNode(_dragIndex, x, y));
        break;

      case _DragKind.arc:
        final i = _dragIndex;
        final a = _path.p(i);
        final c = _path.p(i + 1);
        final chord = (c - a).distance;

        if (chord < 1e-6) return;

        final dir = (c - a) / chord;
        final perp = Offset(-dir.dy, dir.dx);
        final mid = (a + c) / 2;
        final target = v.toWorld(details.localFocalPoint + _grab);

        var s = (target.dx - mid.dx) * perp.dx + (target.dy - mid.dy) * perp.dy;

        // Dekat garis lurus: kembali menjadi sisi lurus.
        if (s.abs() * v.scale < 8) {
          s = 0;
        } else {
          s = _snapValue(s);
        }

        final bulge = (2 * s / chord)
            .clamp(-RoomPath.maxBulge, RoomPath.maxBulge)
            .toDouble();

        _beginDragChange();
        setState(() => _path = _path.setBulge(i, bulge));
        break;

      case _DragKind.none:
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
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _drag = _DragKind.none;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _zoomAt(event.localPosition, event.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12);
    }
  }

  // ------------------------------------------------------------------
  // Aksi dari panel angka
  // ------------------------------------------------------------------

  void _setLength(int i, String text) {
    final cm = LengthUnit.parseCm(text, _unit);

    if (cm == null || cm < RoomPath.minEdgeCm) return;

    _apply(_path.setChordLength(i, cm));
  }

  void _setSagitta(int i, String text) {
    final cm = LengthUnit.parseCm(text, _unit);
    final chord = _path.chordLength(i);

    if (cm == null || cm <= 0 || chord <= 0) return;

    final magnitude = (2 * cm / chord).clamp(0.001, RoomPath.maxBulge);
    final sign = _path.nodes[i].bulge >= 0 ? 1.0 : -1.0;

    _apply(_path.setBulge(i, sign * magnitude));
  }

  void _setRadius(int i, String text) {
    final cm = LengthUnit.parseCm(text, _unit);
    final chord = _path.chordLength(i);

    if (cm == null || cm <= 0 || chord <= 0) return;

    // Busur kecil (kurang dari setengah lingkaran).
    final r = math.max(cm, chord / 2);
    final sagitta = r - math.sqrt(math.max(0.0, r * r - chord * chord / 4));
    final magnitude = (2 * sagitta / chord).clamp(0.001, RoomPath.maxBulge);
    final sign = _path.nodes[i].bulge >= 0 ? 1.0 : -1.0;

    _apply(_path.setBulge(i, sign * magnitude));
  }

  void _setEdgeType(int i, {required bool arc}) {
    if (arc == _path.nodes[i].isArc) return;

    if (!arc) {
      _apply(_path.setBulge(i, 0));
      return;
    }

    // Busur awal: tinggi seperempat panjang sisi, melengkung ke luar.
    _apply(_path.setBulge(i, _path.bulgeFor(outward: true, magnitude: 0.5)));
  }

  void _setDirection(int i, {required bool outward}) {
    if (!_path.nodes[i].isArc) return;

    final magnitude = _path.nodes[i].bulge.abs();

    _apply(
      _path.setBulge(i, _path.bulgeFor(outward: outward, magnitude: magnitude)),
    );
  }

  void _setCoordinate(int i, {required bool isX, required String text}) {
    final cm = LengthUnit.parseCm(text, _unit);

    if (cm == null) return;

    final node = _path.nodes[i];

    _apply(_path.moveNode(i, isX ? cm : node.x, isX ? node.y : cm));
  }

  void _deleteNode(int i) {
    if (_path.length <= 3) return;

    setState(() {
      _selNode = null;
    });

    _apply(_path.removeNode(i));
  }

  void _applyPreset(int preset) {
    final b = _path.bounds;
    final w = math.max(100.0, b.width);
    final l = math.max(100.0, b.height);

    late final RoomPath next;

    switch (preset) {
      case 0:
        next = RoomPath.rectangle(w, l);
        break;
      case 1:
        next = RoomPath.fromPoints(RoomShape.lShape.points(w, l));
        break;
      case 2:
        next = RoomPath.fromPoints(RoomShape.uShape.points(w, l));
        break;
      case 3:
        next = RoomPath.roundedRect(w, l, math.min(w, l) * 0.15);
        break;
      default:
        next = RoomPath.circle(math.min(w, l));
        break;
    }

    _selNode = null;
    _selEdge = null;

    _apply(next, keepView: false);
  }

  Future<bool?> _confirmDiscard() {
    final s = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(s.discardTitle),
        content: Text(s.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.discardAction),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tampilan
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final valid = _path.isValid;
    final panelHeight = (MediaQuery.sizeOf(context).height * 0.38)
        .clamp(200.0, 360.0)
        .toDouble();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final discard = await _confirmDiscard();

        if (discard == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        appBar: AppBar(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.forest,
          elevation: 0,
          title: Text(
            s.shapeEditorTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: s.undoLabel,
              onPressed: _undo.isEmpty ? null : _undoStep,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: s.redoLabel,
              onPressed: _redo.isEmpty ? null : _redoStep,
              icon: const Icon(Icons.redo),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: FilledButton(
                onPressed: valid
                    ? () => Navigator.of(context).pop<RoomPath>(_path)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: AppColors.white,
                ),
                child: Text(s.apply),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildToolbar(s),
              Expanded(child: _buildCanvas(s, valid)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  valid ? s.shapeHint : s.invalidShape,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: valid ? AppColors.muted : AppColors.danger,
                    fontWeight: valid ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: panelHeight, child: _buildPanel(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PopupMenuButton<int>(
              tooltip: s.startFrom,
              onSelected: _applyPreset,
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(s.presetRect)),
                PopupMenuItem(value: 1, child: Text(s.presetL)),
                PopupMenuItem(value: 2, child: Text(s.presetU)),
                PopupMenuItem(value: 3, child: Text(s.presetRounded)),
                PopupMenuItem(value: 4, child: Text(s.presetCircle)),
              ],
              child: _chipBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(s.startFrom, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<LengthUnit>(
              tooltip: s.unitLabel,
              onSelected: _setUnit,
              itemBuilder: (_) => [
                for (final unit in LengthUnit.values)
                  CheckedPopupMenuItem<LengthUnit>(
                    value: unit,
                    checked: unit == _unit,
                    child: Text(unit.symbol),
                  ),
              ],
              child: _chipBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten, size: 16),
                    const SizedBox(width: 4),
                    Text(_unit.symbol, style: const TextStyle(fontSize: 12)),
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
            FilterChip(
              avatar: const Icon(Icons.align_horizontal_left, size: 16),
              label: Text(s.alignLabel),
              selected: _align,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _align = !_align),
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
                        : '${_unit.formatValue(option)} ${_unit.symbol}',
                  ),
                  selected: _snapCm == option,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _snapCm = option),
                ),
              ),
          ],
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

  Widget _buildCanvas(AppStrings s, bool valid) {
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
          final steps = _gridStepsFor(view.scale, _unit);

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
                      painter: _ShapePainter(
                        path: _path,
                        view: view,
                        unit: _unit,
                        showGrid: _showGrid,
                        selNode: _selNode,
                        selEdge: _selEdge,
                        valid: valid,
                        legend: s.shapeGridLegend(
                          _unit.formatWithUnit(steps.minor),
                          _unit.formatWithUnit(steps.major),
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
                        _MiniButton(
                          icon: Icons.add,
                          tooltip: s.zoomIn,
                          onTap: () => _zoomAt(
                            constraints.biggest.center(Offset.zero),
                            1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MiniButton(
                          icon: Icons.remove,
                          tooltip: s.zoomOut,
                          onTap: () => _zoomAt(
                            constraints.biggest.center(Offset.zero),
                            1 / 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MiniButton(
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

  // ------------------------------------------------------------------
  // Panel angka: daftar sisi dan daftar titik
  // ------------------------------------------------------------------

  Widget _buildPanel(AppStrings s) {
    final n = _path.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text('${s.edgesLabel} ($n)')),
                  ButtonSegment(value: 1, label: Text('${s.pointsLabel} ($n)')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: n,
              itemBuilder: (context, i) =>
                  _tab == 0 ? _edgeRow(s, i) : _nodeRow(s, i),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _rowDecoration(bool selected) {
    return BoxDecoration(
      color: selected
          ? AppColors.sand.withValues(alpha: 0.35)
          : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? AppColors.forest : AppColors.line,
        width: selected ? 1.5 : 1,
      ),
    );
  }

  Widget _edgeRow(AppStrings s, int i) {
    final n = _path.length;
    final node = _path.nodes[i];
    final selected = _selEdge == i;
    final arc = _path.arcOf(i);
    final chord = _path.chordLength(i);

    return InkWell(
      key: ValueKey('edge-row-$i'),
      onTap: () => setState(() {
        _selEdge = i;
        _selNode = null;
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        padding: const EdgeInsets.all(8),
        decoration: _rowDecoration(selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.edgeLabel(i + 1, (i + 1) % n + 1),
                    style: const TextStyle(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                ChoiceChip(
                  label: Text(s.straightLabel),
                  selected: !node.isArc,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _setEdgeType(i, arc: false),
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: Text(s.arcLabel),
                  selected: node.isArc,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _setEdgeType(i, arc: true),
                ),
                IconButton(
                  tooltip: s.addPointTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                  onPressed: () => _apply(_path.splitEdge(i)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _NumField(
              key: ValueKey('len-$i'),
              label: node.isArc ? s.chordLabel : s.edgeLength,
              text: _unit.formatValue(chord),
              suffix: _unit.symbol,
              onSubmit: (text) => _setLength(i, text),
            ),
            if (arc != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumField(
                      key: ValueKey('sag-$i'),
                      label: s.arcHeight,
                      text: _unit.formatValue(_path.sagitta(i).abs()),
                      suffix: _unit.symbol,
                      onSubmit: (text) => _setSagitta(i, text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumField(
                      key: ValueKey('rad-$i'),
                      label: s.radiusLabel,
                      text: _unit.formatValue(arc.radius),
                      suffix: _unit.symbol,
                      onSubmit: (text) => _setRadius(i, text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(s.outwardLabel),
                    selected: _path.isArcOutward(i),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _setDirection(i, outward: true),
                  ),
                  ChoiceChip(
                    label: Text(s.inwardLabel),
                    selected: !_path.isArcOutward(i),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _setDirection(i, outward: false),
                  ),
                  Text(
                    '${s.arcLengthLabel}: '
                    '${_unit.formatWithUnit(arc.length)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nodeRow(AppStrings s, int i) {
    final node = _path.nodes[i];
    final selected = _selNode == i;

    return InkWell(
      key: ValueKey('node-row-$i'),
      onTap: () => setState(() {
        _selNode = i;
        _selEdge = null;
      }),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
        decoration: _rowDecoration(selected),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: _NumField(
                key: ValueKey('x-$i'),
                label: 'X',
                text: _unit.formatValue(node.x),
                suffix: _unit.symbol,
                onSubmit: (text) => _setCoordinate(i, isX: true, text: text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumField(
                key: ValueKey('y-$i'),
                label: 'Y',
                text: _unit.formatValue(node.y),
                suffix: _unit.symbol,
                onSubmit: (text) => _setCoordinate(i, isX: false, text: text),
              ),
            ),
            IconButton(
              tooltip: s.deletePointTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.danger,
              onPressed: _path.length <= 3 ? null : () => _deleteNode(i),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Widget kecil
// ----------------------------------------------------------------------

class _MiniButton extends StatelessWidget {
  const _MiniButton({
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

/// Kolom angka yang menerapkan nilainya saat Enter ditekan atau saat
/// fokus berpindah. Nilai yang salah dikembalikan ke nilai sebelumnya.
class _NumField extends StatefulWidget {
  const _NumField({
    super.key,
    required this.label,
    required this.text,
    required this.onSubmit,
    this.suffix,
  });

  final String label;
  final String text;
  final String? suffix;
  final ValueChanged<String> onSubmit;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();

    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text == widget.text) return;

    widget.onSubmit(_controller.text);

    // Jika nilai ditolak, tampilan kembali ke nilai lama. Jika diterima,
    // didUpdateWidget akan mengisi nilai baru pada frame berikutnya.
    if (mounted) _controller.text = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onSubmitted: (_) => _commit(),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Grid dan painter
// ----------------------------------------------------------------------

class _GridSteps {
  const _GridSteps(this.minor, this.major);

  final double minor;
  final double major;
}

const List<double> _metricSteps = [
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

const List<double> _inchSteps = [
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

/// Garis tipis minimal 10 piksel; garis tebal berupa kelipatan bulatnya.
_GridSteps _gridStepsFor(double scale, LengthUnit unit) {
  final list = unit == LengthUnit.inch ? _inchSteps : _metricSteps;

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

  return _GridSteps(minor, major);
}

void _drawLabel(
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

class _ShapePainter extends CustomPainter {
  _ShapePainter({
    required this.path,
    required this.view,
    required this.unit,
    required this.showGrid,
    required this.selNode,
    required this.selEdge,
    required this.valid,
    required this.legend,
  });

  final RoomPath path;
  final _View view;
  final LengthUnit unit;
  final bool showGrid;
  final int? selNode;
  final int? selEdge;
  final bool valid;
  final String legend;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.canvas);

    if (showGrid) _paintGrid(canvas, size);

    _paintShape(canvas, size);
    _paintLabels(canvas);
    _paintHandles(canvas);

    _drawLabel(
      canvas,
      legend,
      const Offset(12, 14),
      fontSize: 10,
      color: AppColors.muted,
      weight: FontWeight.w700,
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final steps = _gridStepsFor(view.scale, unit);
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

    // Sumbu asal (0, 0).
    final axisPaint = Paint()
      ..color = _accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.6;

    canvas.drawLine(
      Offset(view.origin.dx, 0),
      Offset(view.origin.dx, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, view.origin.dy),
      Offset(size.width, view.origin.dy),
      axisPaint,
    );
  }

  void _paintShape(Canvas canvas, Size size) {
    final polygon = path
        .toPolygon(stepDeg: 3)
        .map((point) => view.toScreen(point.x, point.y))
        .toList();

    if (polygon.length >= 3) {
      canvas.drawPath(
        Path()..addPolygon(polygon, true),
        Paint()
          ..color = valid
              ? AppColors.canvasRoom
              : AppColors.danger.withValues(alpha: 0.12),
      );
    }

    for (var i = 0; i < path.length; i++) {
      final points = path
          .edgePolyline(i, stepDeg: 3)
          .map((o) => view.toScreen(o.dx, o.dy))
          .toList();

      final edgePath = Path()..moveTo(points.first.dx, points.first.dy);

      for (var k = 1; k < points.length; k++) {
        edgePath.lineTo(points[k].dx, points[k].dy);
      }

      final selected = selEdge == i;

      canvas.drawPath(
        edgePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..strokeWidth = selected ? 4 : 2.4
          ..color = selected
              ? _accent
              : (valid ? AppColors.forest : AppColors.danger),
      );
    }

    if (valid) {
      final b = path.bounds;
      final center = view.toScreen(
        (b.minX + b.maxX) / 2,
        (b.minY + b.maxY) / 2,
      );

      _drawLabel(
        canvas,
        '${(path.areaCm2 / 10000).toStringAsFixed(2)} m²',
        center,
        fontSize: 13,
        color: AppColors.muted,
        weight: FontWeight.w700,
      );
    }
  }

  void _paintLabels(Canvas canvas) {
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
      final screenMid = view.toScreen(mid.dx, mid.dy);
      final position = screenMid + outward * 18;

      final arc = path.arcOf(i);

      final text = arc == null
          ? unit.formatValue(chord)
          : '${unit.formatValue(chord)} · R${unit.formatValue(arc.radius)}';

      _drawLabel(
        canvas,
        text,
        position,
        background: Colors.white.withValues(alpha: 0.85),
        color: selEdge == i ? _accent : AppColors.forest,
      );
    }
  }

  void _paintHandles(Canvas canvas) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.forest;

    // Pegangan lengkung: belah ketupat di tengah tiap sisi.
    for (var i = 0; i < path.length; i++) {
      final m = path.pointAt(i, 0.5);
      final c = view.toScreen(m.dx, m.dy);
      final r = selEdge == i ? 8.0 : 6.0;

      final diamond = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();

      canvas.drawPath(
        diamond,
        Paint()..color = path.nodes[i].isArc ? _accent : AppColors.white,
      );
      canvas.drawPath(diamond, outline);
    }

    // Titik sudut bernomor.
    for (var i = 0; i < path.length; i++) {
      final n = path.nodes[i];
      final c = view.toScreen(n.x, n.y);
      final selected = selNode == i;

      canvas.drawCircle(
        c,
        selected ? 11 : 10,
        Paint()..color = selected ? _accent : AppColors.white,
      );
      canvas.drawCircle(c, selected ? 11 : 10, outline);

      _drawLabel(
        canvas,
        '${i + 1}',
        c,
        fontSize: 10,
        color: selected ? Colors.white : AppColors.forest,
        weight: FontWeight.w800,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) => true;
}
