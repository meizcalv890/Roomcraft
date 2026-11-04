import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/backup_strings.dart';
import '../../core/l10n/language_controller.dart';
import '../../core/storage/backup_service.dart';
import '../../core/storage/roomcraft_storage.dart';
import '../../core/theme/app_theme.dart';
import '../editor/room_project_draft.dart';

/// Tombol kecil untuk diletakkan di header layar beranda.
class BackupButton extends StatelessWidget {
  const BackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.backupTooltip,
      icon: const Icon(Icons.backup_outlined, color: AppColors.forest),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const BackupScreen())),
    );
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _controller = TextEditingController();

  List<RoomProjectDraft> _projects = const [];
  Object? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    try {
      final projects = RoomcraftStorage.loadProjects();

      setState(() {
        _projects = projects;
        _loadError = null;
      });
    } catch (error) {
      setState(() => _loadError = error);
    }
  }

  String _fileName() {
    final now = DateTime.now();

    String two(int v) => v.toString().padLeft(2, '0');

    return 'roomcraft_backup_${now.year}${two(now.month)}${two(now.day)}.json';
  }

  Future<void> _share() async {
    if (_busy) return;

    final s = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (_projects.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupNothing)));
      return;
    }

    setState(() => _busy = true);

    try {
      final name = _fileName();

      await SharePlus.instance.share(
        ShareParams(
          title: s.backupTitle,
          files: [
            XFile.fromData(
              BackupService.exportBytes(_projects),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupFailed(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final s = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (_projects.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupNothing)));
      return;
    }

    try {
      await Clipboard.setData(
        ClipboardData(text: BackupService.exportText(_projects)),
      );

      messenger.showSnackBar(SnackBar(content: Text(s.backupCopied)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupFailed(error))));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);

    if (!mounted) return;

    setState(() => _controller.text = data?.text ?? '');
  }

  Future<void> _import() async {
    if (_busy) return;

    final s = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final text = _controller.text;

    if (text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupImportEmpty)));
      return;
    }

    setState(() => _busy = true);

    try {
      final summary = await BackupService.importText(
        text,
        copySuffix: s.backupCopySuffix,
      );

      if (!mounted) return;

      _controller.clear();
      _load();

      messenger.showSnackBar(
        SnackBar(
          content: Text(s.backupImportDone(summary.added, summary.skipped)),
        ),
      );
    } on FormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message == BackupError.tooNew
                ? s.backupTooNew
                : s.backupInvalid,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(s.backupFailed(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.forest,
        elevation: 0,
        title: Text(
          s.backupTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.backupExportTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadError != null
                      ? s.backupFailed(_loadError!)
                      : s.backupExportBody(_projects.length),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(s.backupShare),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(s.backupCopy),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.backupImportTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.backupImportBody,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: s.backupImportHint,
                    filled: true,
                    fillColor: AppColors.ivory,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _paste,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: Text(s.backupPaste),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text(s.backupImportAction),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
