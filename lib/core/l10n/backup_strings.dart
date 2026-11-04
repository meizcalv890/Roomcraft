import 'app_strings.dart';

/// Teks fitur cadangan data.
extension BackupStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get backupTooltip => _s('Backup & restore', 'Cadangan & pulihkan');
  String get backupTitle => _s('Backup & restore', 'Cadangan & pulihkan');

  String get backupExportTitle => _s('Back up my projects', 'Cadangkan proyek');
  String backupExportBody(int count) => _s(
    '$count project(s) will be saved into one file you can keep in Drive '
        'or send to yourself.',
    '$count proyek akan disimpan dalam satu file yang bisa Anda simpan di '
        'Drive atau kirim ke diri sendiri.',
  );
  String get backupShare => _s('Share backup file', 'Bagikan file cadangan');
  String get backupCopy => _s('Copy as text', 'Salin sebagai teks');
  String get backupCopied =>
      _s('Backup copied to clipboard', 'Cadangan tersalin ke papan klip');
  String get backupNothing =>
      _s('There are no projects to back up yet.', 'Belum ada proyek untuk dicadangkan.');

  String get backupImportTitle => _s('Restore from backup', 'Pulihkan dari cadangan');
  String get backupImportBody => _s(
    'Open your backup file, copy all of its text, then paste it here. '
        'Existing projects are never overwritten: changed ones are added '
        'as copies.',
    'Buka file cadangan, salin seluruh isinya, lalu tempel di sini. '
        'Proyek yang sudah ada tidak pernah ditimpa: yang berbeda '
        'ditambahkan sebagai salinan.',
  );
  String get backupPaste => _s('Paste from clipboard', 'Tempel dari papan klip');
  String get backupImportAction => _s('Restore', 'Pulihkan');
  String get backupImportHint =>
      _s('Paste the backup text here', 'Tempel teks cadangan di sini');
  String get backupImportEmpty =>
      _s('Paste the backup text first.', 'Tempel teks cadangan terlebih dahulu.');
  String get backupInvalid => _s(
    'This is not a valid Roomcraft backup.',
    'Ini bukan cadangan Roomcraft yang valid.',
  );
  String get backupTooNew => _s(
    'This backup was made by a newer version of the app.',
    'Cadangan ini dibuat oleh versi aplikasi yang lebih baru.',
  );
  String backupImportDone(int added, int skipped) => _s(
    'Restored $added project(s); $skipped skipped (already here or invalid).',
    '$added proyek dipulihkan; $skipped dilewati (sudah ada atau tidak valid).',
  );
  String backupFailed(Object error) =>
      _s('Backup failed: $error', 'Cadangan gagal: $error');
  String get backupCopySuffix => _s(' (restored)', ' (dipulihkan)');
}
