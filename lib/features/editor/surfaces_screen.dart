import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/builder_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/surface_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/units/length_unit.dart';
import '../../core/utils/id_generator.dart';
import 'room_surface.dart';
import 'surface_editor_screen.dart';


/// Daftar dinding dan profil bebas sebuah proyek. Mengembalikan daftar baru
/// saat ditutup, atau null jika tidak ada perubahan.
///
/// [roomEdgeLengthsCm] adalah panjang tiap sisi denah lantai, agar dinding
/// bisa dihubungkan ke salah satunya. [onAutosave] dipanggil setiap daftar
/// berubah, supaya perubahan langsung tersimpan.
class SurfacesScreen extends StatefulWidget {
  const SurfacesScreen({
    super.key,
    required this.surfaces,
    this.roomEdgeLengthsCm = const [],
    this.onAutosave,
  });

  final List<RoomSurface> surfaces;
  final List<double> roomEdgeLengthsCm;
  final ValueChanged<List<RoomSurface>>? onAutosave;

  @override
  State<SurfacesScreen> createState() => _SurfacesScreenState();
}

class _SurfacesScreenState extends State<SurfacesScreen> {
  late List<RoomSurface> _surfaces = List<RoomSurface>.of(widget.surfaces);
  bool _changed = false;

  void _set(List<RoomSurface> next) {
    setState(() {
      _surfaces = next;
      _changed = true;
    });

    widget.onAutosave?.call(next);
  }

  /// Dipanggil editor dinding beberapa saat setelah perubahan.
  void _autosave(RoomSurface updated) {
    if (!mounted) return;

    _set([
      for (final item in _surfaces) item.id == updated.id ? updated : item,
    ]);
  }

  Future<void> _create() async {
    final surface = await showDialog<RoomSurface>(
      context: context,
      builder: (_) => const _NewSurfaceDialog(),
    );

    if (surface == null || !mounted) return;

    _set([..._surfaces, surface]);

    await _open(surface);
  }

  Future<void> _open(RoomSurface surface) async {
    final result = await Navigator.of(context).push<RoomSurface>(
      MaterialPageRoute<RoomSurface>(
        builder: (_) => SurfaceEditorScreen(
          surface: surface,
          roomEdgeLengthsCm: widget.roomEdgeLengthsCm,
          onChanged: _autosave,
        ),
      ),
    );

    if (result == null || !mounted) return;

    _set([for (final item in _surfaces) item.id == result.id ? result : item]);
  }

  Future<void> _rename(RoomSurface surface) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: surface.name),
    );

    if (name == null || !mounted) return;

    _set([
      for (final item in _surfaces)
        item.id == surface.id ? item.copyWith(name: name) : item,
    ]);
  }

  void _duplicate(RoomSurface surface) {
    final copy = surface.copyWith(
      id: IdGenerator.next(),
      name: '${surface.name}${context.l10n.copySuffix}',
      items: [
        for (final item in surface.items) item.copyWith(id: IdGenerator.next()),
      ],
    );

    _set([..._surfaces, copy]);
  }

  Future<void> _delete(RoomSurface surface) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final s = dialogContext.l10n;

        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(s.deleteSurfaceTitle),
          content: Text(s.deleteSurfaceBody(surface.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    _set(_surfaces.where((item) => item.id != surface.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed ? _surfaces : null);
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        appBar: AppBar(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.forest,
          elevation: 0,
          title: Text(
            s.surfacesTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.white,
          icon: const Icon(Icons.add),
          label: Text(s.newSurface),
        ),
        body: _surfaces.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 48,
                        color: AppColors.forest,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.noSurfaces,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.noSurfacesBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: _surfaces.length,
                itemBuilder: (context, index) =>
                    _buildCard(s, _surfaces[index]),
              ),
      ),
    );
  }

  Widget _buildCard(AppStrings s, RoomSurface surface) {
    final unit = surface.unit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(surface),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.ivory,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    surface.kind == SurfaceKind.wall
                        ? Icons.crop_portrait
                        : Icons.change_history,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surface.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.kindLabel(surface.kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${unit.formatValue(surface.widthCm)} × '
                        '${unit.formatValue(surface.heightCm)} ${unit.symbol}'
                        '  ·  ${s.objectsCount(surface.items.length)}',
                        style: const TextStyle(
                          color: AppColors.forestLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _rename(surface);
                        break;
                      case 'duplicate':
                        _duplicate(surface);
                        break;
                      case 'delete':
                        _delete(surface);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(s.renameLabel)),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(s.duplicateSurface),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        s.delete,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();

    if (name.isEmpty) return;

    Navigator.pop(context, name.length > 40 ? name.substring(0, 40) : name);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(s.renameLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(hintText: s.surfaceNameHint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(s.apply)),
      ],
    );
  }
}

class _NewSurfaceDialog extends StatefulWidget {
  const _NewSurfaceDialog();

  @override
  State<_NewSurfaceDialog> createState() => _NewSurfaceDialogState();
}

class _NewSurfaceDialogState extends State<_NewSurfaceDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _width = TextEditingController(text: '300');
  final TextEditingController _height = TextEditingController(text: '250');

  SurfaceKind _kind = SurfaceKind.wall;
  bool _invalid = false;

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _setKind(SurfaceKind kind) {
    setState(() {
      _kind = kind;
      _width.text = kind == SurfaceKind.wall ? '300' : '220';
      _height.text = kind == SurfaceKind.wall ? '250' : '240';
    });
  }

  void _submit() {
    final name = _name.text.trim();
    final w = LengthUnit.parseCm(_width.text, LengthUnit.cm);
    final h = LengthUnit.parseCm(_height.text, LengthUnit.cm);

    if (name.isEmpty || w == null || h == null || w < 10 || h < 10) {
      setState(() => _invalid = true);
      return;
    }

    final id = IdGenerator.next();

    Navigator.pop(
      context,
      _kind == SurfaceKind.wall
          ? RoomSurface.wall(id: id, name: name, widthCm: w, heightCm: h)
          : RoomSurface.underStairs(
              id: id,
              name: name,
              widthCm: w,
              heightCm: h,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(s.newSurface),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: s.surfaceName,
                hintText: s.surfaceNameHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SurfaceKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: SurfaceKind.wall, label: Text(s.kindWall)),
                ButtonSegment(
                  value: SurfaceKind.profile,
                  label: Text(s.presetUnderStairs),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => _setKind(value.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _width,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: s.width,
                      suffixText: 'cm',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: s.heightLabel,
                      suffixText: 'cm',
                    ),
                  ),
                ),
              ],
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
        FilledButton(onPressed: _submit, child: Text(s.apply)),
      ],
    );
  }
}
