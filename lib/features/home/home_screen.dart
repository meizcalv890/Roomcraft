import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/l10n/language_menu_button.dart';
import '../../core/storage/roomcraft_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../editor/editor_screen.dart';
import '../editor/room_geometry.dart';
import '../editor/room_project_draft.dart';
import '../backup/backup_screen.dart';
import '../../core/l10n/shape_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RoomProjectDraft> _projects = [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();

    // Muat ulang otomatis setiap kali ada penulisan yang berhasil, termasuk
    // penyimpanan tertunda dari layar editor yang baru ditutup.
    RoomcraftStorage.revision.addListener(_onStorageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProjects();
    });
  }

  @override
  void dispose() {
    RoomcraftStorage.revision.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (mounted) _loadProjects();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadProjects() async {
    try {
      final projects = RoomcraftStorage.loadProjects();

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _loading = false;
        _loadFailed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat proyek Roomcraft: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadFailed = true;
      });

      _showMessage(context.l10n.msgLoadFailed);
    }
  }

  Future<void> _recoverCorruptedData() async {
    try {
      await RoomcraftStorage.backupAndResetCorruptedData();
      // _loadProjects dipanggil otomatis lewat listener revision.
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.l10n.msgRecoverFailed(error));
    }
  }

  Future<void> _createProject() async {
    final draft = await showDialog<RoomProjectDraft>(
      context: context,
      builder: (_) => const _ProjectFormDialog(),
    );

    if (!mounted || draft == null) return;

    final project = draft.copyWith(
      id: IdGenerator.next(),
      updatedAt: DateTime.now(),
    );

    try {
      await RoomcraftStorage.saveProject(project);

      if (!mounted) return;

      setState(() {
        _projects = [
          project,
          ..._projects.where((item) => item.id != project.id),
        ];
      });

      await _openProject(project);
    } catch (error, stackTrace) {
      debugPrint('Gagal membuat proyek: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(context.l10n.msgSaveFailed(error));
    }
  }

  Future<void> _editProject(RoomProjectDraft project) async {
    final draft = await showDialog<RoomProjectDraft>(
      context: context,
      builder: (_) => _ProjectFormDialog(initialProject: project),
    );

    if (!mounted || draft == null) return;

    // Bentuk bebas (lurus + busur) diatur lewat editor bentuk, sehingga
    // dialog ini hanya mengubah nama dan jenis ruangan untuk proyek itu.
    final hasCustomPath = project.roomPath != null;

    final shapeFieldsChanged =
        (draft.widthCm - project.widthCm).abs() > 0.5 ||
        (draft.lengthCm - project.lengthCm).abs() > 0.5 ||
        draft.roomShape != project.roomShape;

    final updatedProject = hasCustomPath
        ? project.copyWith(
            name: draft.name,
            roomType: draft.roomType,
            updatedAt: DateTime.now(),
          )
        : project
              .copyWith(
                name: draft.name,
                widthCm: draft.widthCm,
                lengthCm: draft.lengthCm,
                roomType: draft.roomType,
                roomShape: draft.roomShape,
                roomPoints: draft.roomPoints,
                updatedAt: DateTime.now(),
              )
              .withFurnitureFitted();

    try {
      await RoomcraftStorage.saveProject(updatedProject);

      if (!mounted) return;

      setState(() {
        _projects = _projects
            .map((item) => item.id == updatedProject.id ? updatedProject : item)
            .toList();
      });

      _showMessage(
        hasCustomPath && shapeFieldsChanged
            ? context.l10n.customShapeHomeNote
            : context.l10n.msgProjectUpdated,
      );
    } catch (error, stackTrace) {
      debugPrint('Gagal mengedit proyek: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(context.l10n.msgUpdateFailed(error));
    }
  }

  Future<void> _duplicateProject(RoomProjectDraft project) async {
    final suffix = context.l10n.copySuffix;
    final maxBaseLength = 40 - suffix.length;
    final baseName = project.name.length > maxBaseLength
        ? project.name.substring(0, maxBaseLength)
        : project.name;

    final duplicate = project.copyWith(
      id: IdGenerator.next(),
      name: '$baseName$suffix',
      updatedAt: DateTime.now(),
    );

    try {
      await RoomcraftStorage.saveProject(duplicate);

      if (!mounted) return;

      setState(() {
        _projects = [
          duplicate,
          ..._projects.where((item) => item.id != duplicate.id),
        ];
      });

      _showMessage(context.l10n.msgProjectDuplicated);
    } catch (error, stackTrace) {
      debugPrint('Gagal menduplikasi proyek: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(context.l10n.msgDuplicateFailed(error));
    }
  }

  Future<void> _deleteProject(RoomProjectDraft project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final s = dialogContext.l10n;

        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(s.deleteTitle),
          content: Text(s.deleteBody(project.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.delete),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await RoomcraftStorage.deleteProject(project.id);

      if (!mounted) return;

      setState(() {
        _projects = _projects.where((item) => item.id != project.id).toList();
      });

      _showMessage(context.l10n.msgProjectDeleted);
    } catch (error, stackTrace) {
      debugPrint('Gagal menghapus proyek: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(context.l10n.msgDeleteFailed(error));
    }
  }

  Future<void> _openProject(RoomProjectDraft project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditorScreen(project: project)),
    );

    if (mounted) await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.space_dashboard_rounded,
                          color: AppColors.sand,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ROOMCRAFT',
                              style: theme.textTheme.titleLarge?.copyWith(
                                letterSpacing: 1.2,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              s.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.05,
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const BackupButton(),
                      const LanguageMenuButton(),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(23),
                    decoration: BoxDecoration(
                      color: AppColors.forest,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.architecture_rounded,
                                size: 14,
                                color: AppColors.sand,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.heroBadge,
                                style: const TextStyle(
                                  color: AppColors.sand,
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s.heroTitle,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 32,
                            height: 1.12,
                            letterSpacing: -1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.heroSubtitle,
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _createProject,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(s.createNewProject),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sand,
                              foregroundColor: AppColors.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.myProjects,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        _loading
                            ? s.loadingCaps
                            : s.projectsCount(_projects.length),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_loadFailed)
                    _LoadErrorCard(onRecover: _recoverCorruptedData)
                  else if (_projects.isEmpty)
                    _EmptyProjects(onCreate: _createProject)
                  else
                    ..._projects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProjectCard(
                          project: project,
                          onTap: () => _openProject(project),
                          onEdit: () => _editProject(project),
                          onDuplicate: () => _duplicateProject(project),
                          onDelete: () => _deleteProject(project),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEE9DE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.forest,
                          size: 23,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.tipTitle,
                                style: const TextStyle(
                                  color: AppColors.forest,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                s.tipBody,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      s.footer,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1,
                        color: AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.onRecover});

  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 34),
          const SizedBox(height: 10),
          Text(
            s.loadErrorTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.loadErrorBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRecover,
            child: Text(s.backupAndReset),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 25),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.grid_on_rounded,
              size: 36,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            s.emptyTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            s.emptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(s.startRoom),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final RoomProjectDraft project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.ivory,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.grid_4x4_rounded,
                  size: 34,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${s.roomTypeLabel(project.roomType)}  ·  '
                      '${project.roomShape.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${project.widthCm.toStringAsFixed(0)} × '
                      '${project.lengthCm.toStringAsFixed(0)} cm  ·  '
                      '${project.areaM2.toStringAsFixed(2)} m²',
                      style: const TextStyle(
                        color: AppColors.forestLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (project.furniture.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.furnitureCount(project.furniture.length),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: s.projectActions,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.muted,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'duplicate':
                      onDuplicate();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(s.editProject),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(s.duplicateProject),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        s.deleteProject,
                        style: const TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({this.initialProject});

  final RoomProjectDraft? initialProject;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _widthController;
  late final TextEditingController _lengthController;
  late final TextEditingController _pointsController;

  late String _roomType;
  late RoomShape _roomShape;

  bool get _isEditing => widget.initialProject != null;

  /// Menampilkan 300.0 sebagai "300" dan 12.5 sebagai "12.5".
  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static double? _parseNumber(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();

    final project = widget.initialProject;

    _nameController = TextEditingController(text: project?.name ?? '');
    _widthController = TextEditingController(
      text: _fmt(project?.widthCm ?? 300),
    );
    _lengthController = TextEditingController(
      text: _fmt(project?.lengthCm ?? 400),
    );

    _roomType = project?.roomType ?? 'Bedroom';
    _roomShape = project?.roomShape ?? RoomShape.rectangle;

    final initialPoints = project?.roomPoints ?? const <RoomPoint>[];

    _pointsController = TextEditingController(
      text: _formatPoints(
        _roomShape == RoomShape.polygon && initialPoints.length >= 3
            ? initialPoints
            : RoomShape.rectangle.points(
                project?.widthCm ?? 300,
                project?.lengthCm ?? 400,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  String _formatPoints(List<RoomPoint> points) {
    return points.map((p) => '${_fmt(p.x)}, ${_fmt(p.y)}').join('\n');
  }

  /// Mengembalikan null jika formatnya salah. Baris kosong diabaikan.
  List<RoomPoint>? _parsePoints(String text) {
    final result = <RoomPoint>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'[,;\s]+'));

      if (parts.length != 2) return null;

      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);

      if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
      if (x < 0 || y < 0) return null;

      result.add(RoomPoint(x, y));
    }

    return result;
  }

  String? _validateDimension(String? value) {
    final s = context.l10n;
    final number = _parseNumber(value);

    if (number == null || !number.isFinite || number <= 0) {
      return s.dimensionInvalid;
    }

    if (number > 2000) {
      return s.dimensionTooLarge;
    }

    return null;
  }

  /// Validasi poligon ditampilkan langsung di bawah field, bukan lewat
  /// Snackbar yang akan tertutup oleh dialog.
  String? _validatePoints(String? value) {
    if (_roomShape != RoomShape.polygon) return null;

    final s = context.l10n;
    final points = _parsePoints(value ?? '');

    if (points == null) return s.pointsFormatError;

    if (points.length < 3) return s.pointsMinError;

    if (!isValidPolygon(points)) return s.polygonInvalidError;

    final width = _parseNumber(_widthController.text);
    final length = _parseNumber(_lengthController.text);

    if (width != null &&
        length != null &&
        points.any((p) => p.x > width || p.y > length)) {
      return s.pointsOutsideError;
    }

    return null;
  }

  void _changeShape(RoomShape? shape) {
    if (shape == null || shape == _roomShape) return;

    final width = _parseNumber(_widthController.text) ?? 300;
    final length = _parseNumber(_lengthController.text) ?? 400;

    setState(() {
      // Titik awal poligon diambil dari bentuk yang sedang dipilih,
      // bukan selalu persegi panjang.
      if (shape == RoomShape.polygon) {
        _pointsController.text = _formatPoints(
          _roomShape.points(width, length),
        );
      }

      _roomShape = shape;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final width = _parseNumber(_widthController.text)!;
    final length = _parseNumber(_lengthController.text)!;

    final points = _roomShape == RoomShape.polygon
        ? _parsePoints(_pointsController.text)!
        : <RoomPoint>[];

    Navigator.of(context).pop(
      RoomProjectDraft(
        id: widget.initialProject?.id ?? '',
        name: _nameController.text.trim(),
        widthCm: width,
        lengthCm: length,
        roomType: _roomType,
        roomShape: _roomShape,
        roomPoints: points,
        furniture: widget.initialProject?.furniture ?? const [],
        updatedAt: widget.initialProject?.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    // Jenis ruangan lama yang tidak ada di daftar (mis. "Custom") tetap
    // ditampilkan agar dropdown tidak error.
    final roomTypeKeys = <String>[
      ...AppStrings.roomTypeKeys,
      if (!AppStrings.roomTypeKeys.contains(_roomType)) _roomType,
    ];

    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(_isEditing ? s.editRoomProject : s.newRoomProject),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? s.formEditSubtitle : s.formNewSubtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  s.projectName,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 40,
                  decoration: InputDecoration(
                    hintText: s.projectNameHint,
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.nameRequired;
                    }
                    if (value.trim().length > 40) {
                      return s.nameTooLong;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  s.roomType,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _roomType,
                  decoration: const InputDecoration(),
                  items: roomTypeKeys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(s.roomTypeLabel(key)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _roomType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  s.roomDimensions,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: s.width,
                          suffixText: 'cm',
                        ),
                        validator: _validateDimension,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: s.length,
                          suffixText: 'cm',
                        ),
                        validator: _validateDimension,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  s.roomShape,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RoomShape>(
                  initialValue: _roomShape,
                  decoration: InputDecoration(helperText: s.roomShapeHelper),
                  items: RoomShape.values
                      .map(
                        (shape) => DropdownMenuItem(
                          value: shape,
                          child: Text(shape.label),
                        ),
                      )
                      .toList(),
                  onChanged: _changeShape,
                ),
                if (_roomShape == RoomShape.polygon) ...[
                  const SizedBox(height: 16),
                  Text(
                    s.cornerPoints,
                    style: const TextStyle(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.cornerPointsHelp,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pointsController,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: '0, 0\n300, 0\n250, 200\n0, 200',
                      alignLabelWithHint: true,
                    ),
                    validator: _validatePoints,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? s.saveChanges : s.createProject),
        ),
      ],
    );
  }
}
