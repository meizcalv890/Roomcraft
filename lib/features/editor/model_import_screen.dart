import 'dart:math' as math;
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/language_controller.dart';
import '../../core/l10n/model_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import 'furniture_item.dart';
import 'furniture_material.dart';
import 'model3d.dart';
import 'model_file_picker.dart';

enum SourceUnit { mm, cm, m, inch }

extension on SourceUnit {
  double get toCm {
    switch (this) {
      case SourceUnit.mm:
        return 0.1;
      case SourceUnit.cm:
        return 1;
      case SourceUnit.m:
        return 100;
      case SourceUnit.inch:
        return 2.54;
    }
  }

  String get label {
    switch (this) {
      case SourceUnit.mm:
        return 'mm';
      case SourceUnit.cm:
        return 'cm';
      case SourceUnit.m:
        return 'm';
      case SourceUnit.inch:
        return 'inch';
    }
  }
}

// Pekerjaan berat dijalankan di isolate terpisah agar layar tidak macet.
class _ParseArgs {
  const _ParseArgs(this.bytes, this.text);

  final Uint8List? bytes;
  final String? text;
}

ParseResult _runParse(_ParseArgs a) =>
    parseModelData(bytes: a.bytes, text: a.text);

class _BuildArgs {
  const _BuildArgs(this.raw, this.zUp, this.turns, this.cap);

  final RawMesh raw;
  final bool zUp;
  final int turns;
  final int cap;
}

BuiltModel? _runBuild(_BuildArgs a) => buildModel(
  a.raw,
  zUp: a.zUp,
  quarterTurns: a.turns,
  maxTriangles: a.cap,
);

/// Memuat model OBJ/STL, mengatur orientasi, ukuran, dan bahan, lalu
/// mengembalikan [FurnitureItem] (di posisi 0,0) lewat Navigator.pop.
class ModelImportScreen extends StatefulWidget {
  const ModelImportScreen({
    super.key,
    required this.maxWidthCm,
    required this.maxLengthCm,
  });

  final double maxWidthCm;
  final double maxLengthCm;

  @override
  State<ModelImportScreen> createState() => _ModelImportScreenState();
}

class _ModelImportScreenState extends State<ModelImportScreen> {
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _pasteCtl = TextEditingController();
  final TextEditingController _wCtl = TextEditingController();
  final TextEditingController _dCtl = TextEditingController();
  final TextEditingController _hCtl = TextEditingController();

  RawMesh? _raw;
  BuiltModel? _built;
  String? _message;
  bool _busy = false;
  int _rev = 0;

  SourceUnit _unit = SourceUnit.cm;
  bool _zUp = false;
  int _turns = 0;
  int _cap = 3000;
  bool _keepRatio = true;
  FurnitureMaterial _material = FurnitureMaterial.wood;

  double _w = 100;
  double _d = 100;
  double _h = 100;
  double _baseW = 100;
  double _baseD = 100;
  double _baseH = 100;
  double _scale = 1;

  @override
  void dispose() {
    _nameCtl.dispose();
    _pasteCtl.dispose();
    _wCtl.dispose();
    _dCtl.dispose();
    _hCtl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  String _stripExt(String name) {
    final dot = name.lastIndexOf('.');

    return dot > 0 ? name.substring(0, dot) : name;
  }

  SourceUnit _guessUnit(RawMesh raw) {
    final v = raw.vertices;

    var minV = double.infinity;
    var maxV = -double.infinity;

    // Perkiraan kasar dari seluruh koordinat (cukup untuk menebak satuan).
    for (var i = 0; i < v.length; i++) {
      minV = math.min(minV, v[i]);
      maxV = math.max(maxV, v[i]);
    }

    final extent = maxV - minV;

    if (extent < 10) return SourceUnit.m;
    if (extent <= 300) return SourceUnit.cm;

    return SourceUnit.mm;
  }

  void _applyBase() {
    final b = _built;

    if (b == null) return;

    final f = _unit.toCm;

    _baseW = math.max(1.0, b.sizeX * f);
    _baseH = math.max(1.0, b.sizeY * f);
    _baseD = math.max(1.0, b.sizeZ * f);

    _scale = 1;
    _w = _baseW;
    _d = _baseD;
    _h = _baseH;

    _syncFields();
  }

  void _syncFields() {
    _wCtl.text = _fmt(_w);
    _dCtl.text = _fmt(_d);
    _hCtl.text = _fmt(_h);
  }

  Future<void> _ingest({
    Uint8List? bytes,
    String? text,
    required String name,
  }) async {
    final rev = ++_rev;

    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await compute(_runParse, _ParseArgs(bytes, text));

    if (!mounted || rev != _rev) return;

    final s = context.l10n;
    final mesh = result.mesh;

    if (mesh == null) {
      setState(() {
        _busy = false;
        _raw = null;
        _built = null;
        _message = result.error == parseUnsupported
            ? s.modelUnsupported
            : result.error == parseEmpty
            ? s.modelEmpty
            : s.modelInvalid;
      });
      return;
    }

    _raw = mesh;
    _nameCtl.text = name;
    _unit = _guessUnit(mesh);
    _zUp = false;
    _turns = 0;

    await _rebuild(resetDims: true);
  }

  Future<void> _rebuild({required bool resetDims}) async {
    final raw = _raw;

    if (raw == null) return;

    final rev = ++_rev;

    setState(() => _busy = true);

    final built = await compute(_runBuild, _BuildArgs(raw, _zUp, _turns, _cap));

    if (!mounted || rev != _rev) return;

    final s = context.l10n;

    setState(() {
      _busy = false;
      _built = built;

      if (built == null) {
        _message = s.modelEmpty;
      } else {
        _message = null;

        if (resetDims) _applyBase();
      }
    });
  }

  Future<void> _pickFile() async {
    final s = context.l10n;

    try {
      final picked = await pickModelFile();

      if (picked == null || !mounted) return;

      await _ingest(bytes: picked.bytes, name: _stripExt(picked.name));
    } on FormatException catch (e) {
      if (!mounted) return;

      setState(
        () => _message = e.message == 'too_big' ? s.modelTooBig : s.modelInvalid,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _message = s.modelFailed(e));
    }
  }

  Future<void> _loadPasted() async {
    final s = context.l10n;
    final text = _pasteCtl.text;

    if (text.trim().isEmpty) {
      setState(() => _message = s.modelNeedFirst);
      return;
    }

    await _ingest(text: text, name: s.modelDefaultName);
  }

  void _onDim(int axis, String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));

    if (v == null || v < 1) return;

    setState(() {
      if (_keepRatio) {
        final cur = axis == 0 ? _w : (axis == 1 ? _d : _h);
        final f = v / cur;

        _w *= f;
        _d *= f;
        _h *= f;
        _scale = _w / _baseW;

        if (axis != 0) _wCtl.text = _fmt(_w);
        if (axis != 1) _dCtl.text = _fmt(_d);
        if (axis != 2) _hCtl.text = _fmt(_h);
      } else if (axis == 0) {
        _w = v;
      } else if (axis == 1) {
        _d = v;
      } else {
        _h = v;
      }
    });
  }

  void _onScale(double v) {
    setState(() {
      _scale = v;
      _w = _baseW * v;
      _d = _baseD * v;
      _h = _baseH * v;
      _syncFields();
    });
  }

  void _add() {
    final s = context.l10n;
    final built = _built;

    if (built == null) {
      setState(() => _message = s.modelNeedFirst);
      return;
    }

    final f = math.min(
      1.0,
      math.min(widget.maxWidthCm / _w, widget.maxLengthCm / _d),
    );

    final hull = built.model.footprint();
    final name = _nameCtl.text.trim();

    Navigator.of(context).pop(
      FurnitureItem(
        id: IdGenerator.next(),
        type: FurnitureType.custom,
        xCm: 0,
        yCm: 0,
        widthCm: _w * f,
        lengthCm: _d * f,
        heightCm: _h * f,
        shape: hull.length >= 3
            ? FurnitureShape.polygon
            : FurnitureShape.rectangle,
        customPoints: hull,
        customName: name.isEmpty ? s.modelDefaultName : name,
        material: _material,
        model: built.model,
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.forest,
      ),
    ),
  );

  Widget _dimField(String label, TextEditingController c, int axis) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (t) => _onDim(axis, t),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final built = _built;

    final tooBig = built != null &&
        (_w > widget.maxWidthCm || _d > widget.maxLengthCm);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.modelTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _pickFile,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(s.modelPickFile),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: AppColors.white,
                  ),
                ),
                const SizedBox(height: 14),
                _title(s.modelPasteTitle),
                TextField(
                  controller: _pasteCtl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: s.modelPasteHint,
                    filled: true,
                    fillColor: AppColors.ivory,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _loadPasted,
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(s.modelLoadText),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
              ),
            ),
          if (built != null) ...[
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.modelLoaded(_nameCtl.text, built.triangles),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  if (built.originalTriangles > built.triangles)
                    Text(
                      s.modelSimplified(built.originalTriangles, built.triangles),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _ModelPreview(
                    model: built.model,
                    w: _w,
                    d: _d,
                    h: _h,
                    color: _material.color,
                    hint: s.modelDragHint,
                  ),
                ],
              ),
            ),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: s.modelName,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _title(s.modelUnitLabel),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final u in SourceUnit.values)
                        ChoiceChip(
                          label: Text(u.label),
                          selected: _unit == u,
                          onSelected: (_) {
                            setState(() {
                              _unit = u;
                              _applyBase();
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _title(s.modelUpAxis),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: Text(s.modelYUp),
                        selected: !_zUp,
                        onSelected: (_) {
                          _zUp = false;
                          _rebuild(resetDims: true);
                        },
                      ),
                      ChoiceChip(
                        label: Text(s.modelZUp),
                        selected: _zUp,
                        onSelected: (_) {
                          _zUp = true;
                          _rebuild(resetDims: true);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.rotate_right, size: 16),
                        label: Text(s.modelRotate),
                        onPressed: () {
                          _turns = (_turns + 1) % 4;
                          _rebuild(resetDims: true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _title(s.modelDetail),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in const [1500, 3000, 6000])
                        ChoiceChip(
                          label: Text('$c'),
                          selected: _cap == c,
                          onSelected: (_) {
                            _cap = c;
                            _rebuild(resetDims: false);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(s.modelSize),
                  Row(
                    children: [
                      _dimField(s.modelWidth, _wCtl, 0),
                      _dimField(s.modelDepth, _dCtl, 1),
                      _dimField(s.modelHeight, _hCtl, 2),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(s.modelKeepRatio),
                    value: _keepRatio,
                    onChanged: (v) => setState(() => _keepRatio = v),
                  ),
                  Text(
                    '${s.modelScale}: ${(_scale * 100).round()}%',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  Slider(
                    value: _scale.clamp(0.05, 3.0).toDouble(),
                    min: 0.05,
                    max: 3,
                    onChanged: _onScale,
                  ),
                  if (tooBig)
                    Text(
                      s.modelTooBigForRoom,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _title(s.modelColor),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final m in FurnitureMaterial.values)
                        GestureDetector(
                          onTap: () => setState(() => _material = m),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: m.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _material == m
                                    ? AppColors.forest
                                    : AppColors.line,
                                width: _material == m ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FilledButton.icon(
            onPressed: (_busy || built == null) ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(s.modelAdd),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Pratinjau yang bisa diputar
// ----------------------------------------------------------------------

class _ModelPreview extends StatefulWidget {
  const _ModelPreview({
    required this.model,
    required this.w,
    required this.d,
    required this.h,
    required this.color,
    required this.hint,
  });

  final FurnitureModel model;
  final double w;
  final double d;
  final double h;
  final Color color;
  final String hint;

  @override
  State<_ModelPreview> createState() => _ModelPreviewState();
}

class _ModelPreviewState extends State<_ModelPreview> {
  double _yaw = 0.7;
  double _pitch = 0.5;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _yaw += details.delta.dx * 0.01;
          _pitch = (_pitch + details.delta.dy * 0.01).clamp(-1.4, 1.4).toDouble();
        }),
        child: Container(
          height: 240,
          color: AppColors.canvas,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PreviewPainter(
                    model: widget.model,
                    w: widget.w,
                    d: widget.d,
                    h: widget.h,
                    yaw: _yaw,
                    pitch: _pitch,
                    color: widget.color,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  widget.hint,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tri {
  const _Tri(this.a, this.b, this.c, this.depth);

  final List<double> a;
  final List<double> b;
  final List<double> c;
  final double depth;
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.model,
    required this.w,
    required this.d,
    required this.h,
    required this.yaw,
    required this.pitch,
    required this.color,
  });

  final FurnitureModel model;
  final double w;
  final double d;
  final double h;
  final double yaw;
  final double pitch;
  final Color color;

  // Arah cahaya (sudah dinormalkan).
  static const double _lx = -0.395;
  static const double _ly = 0.543;
  static const double _lz = 0.741;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final diag = math.sqrt(w * w + d * d + h * h);
    final k = math.min(size.width, size.height) * 0.85 / (diag <= 0 ? 1 : diag);

    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    List<double> tf(double nx, double ny, double nz) {
      final x = (nx - 0.5) * w;
      final y = (ny - 0.5) * h;
      final z = (nz - 0.5) * d;

      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      final y2 = y * cosP - z1 * sinP;
      final z2 = y * sinP + z1 * cosP;

      return [x1, y2, z2];
    }

    final tris = <_Tri>[];

    for (final part in model.parts) {
      final v = part.vertices;
      final t = part.triangles;

      final tv = <List<double>>[
        for (var i = 0; i + 2 < v.length; i += 3) tf(v[i], v[i + 1], v[i + 2]),
      ];

      for (var i = 0; i + 2 < t.length; i += 3) {
        final a = tv[t[i]];
        final b = tv[t[i + 1]];
        final c = tv[t[i + 2]];

        tris.add(_Tri(a, b, c, (a[2] + b[2] + c[2]) / 3));
      }
    }

    // Yang jauh digambar lebih dulu.
    tris.sort((p, q) => p.depth.compareTo(q.depth));

    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeJoin = StrokeJoin.round;

    for (final t in tris) {
      final ux = t.b[0] - t.a[0];
      final uy = t.b[1] - t.a[1];
      final uz = t.b[2] - t.a[2];
      final vx = t.c[0] - t.a[0];
      final vy = t.c[1] - t.a[1];
      final vz = t.c[2] - t.a[2];

      var nx = uy * vz - uz * vy;
      var ny = uz * vx - ux * vz;
      var nz = ux * vy - uy * vx;

      final len = math.sqrt(nx * nx + ny * ny + nz * nz);

      if (len < 1e-9) continue;

      nx /= len;
      ny /= len;
      nz /= len;

      // Dua sisi: normal selalu dihadapkan ke kamera.
      if (nz < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }

      final shade = 0.45 + 0.55 * math.max(0.0, nx * _lx + ny * _ly + nz * _lz);
      final shaded = Color.lerp(Colors.black, color, shade)!;

      final path = Path()
        ..moveTo(cx + t.a[0] * k, cy - t.a[1] * k)
        ..lineTo(cx + t.b[0] * k, cy - t.b[1] * k)
        ..lineTo(cx + t.c[0] * k, cy - t.c[1] * k)
        ..close();

      fill.color = shaded;
      edge.color = shaded;

      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.w != w ||
      old.d != d ||
      old.h != h ||
      old.color != color ||
      !identical(old.model, model);
}
