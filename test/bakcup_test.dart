import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/storage/backup_service.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';

RoomProjectDraft _project(String id, String name) => RoomProjectDraft(
  id: id,
  name: name,
  widthCm: 300,
  lengthCm: 400,
  roomType: 'Bedroom',
);

void main() {
  const suffix = ' (impor)';

  test('ekspor lalu baca kembali menghasilkan proyek yang sama', () {
    final text = BackupService.exportText([
      _project('a', 'A'),
      _project('b', 'B'),
    ]);

    final parsed = BackupService.parseBackup(text);

    expect(parsed.length, 2);
    expect(parsed.first['name'], 'A');
  });

  test('impor ke daftar kosong menambah semua proyek', () {
    final parsed = BackupService.parseBackup(
      BackupService.exportText([_project('a', 'A'), _project('b', 'B')]),
    );

    final summary = BackupService.merge(const [], parsed, copySuffix: suffix);

    expect(summary.added, 2);
    expect(summary.skipped, 0);
    expect(summary.projects.length, 2);
  });

  test('impor ulang cadangan yang sama dilewati', () {
    final existing = [_project('a', 'A'), _project('b', 'B')];
    final parsed = BackupService.parseBackup(
      BackupService.exportText(existing),
    );

    final summary = BackupService.merge(existing, parsed, copySuffix: suffix);

    expect(summary.added, 0);
    expect(summary.skipped, 2);
    expect(summary.projects.length, 2);
  });

  test('id sama tetapi isi berbeda dijadikan salinan, bukan ditimpa', () {
    final existing = [_project('a', 'A')];
    final parsed = BackupService.parseBackup(
      BackupService.exportText([_project('a', 'Berubah')]),
    );

    final summary = BackupService.merge(existing, parsed, copySuffix: suffix);

    expect(summary.added, 1);
    expect(summary.projects.length, 2);
    expect(summary.projects.first.name, 'A');
    expect(summary.projects.last.name, 'Berubah$suffix');
    expect(summary.projects.last.id, isNot('a'));
  });

  test('format yang salah ditolak', () {
    expect(() => BackupService.parseBackup(''), throwsFormatException);
    expect(
      () => BackupService.parseBackup('bukan json'),
      throwsFormatException,
    );
    expect(
      () => BackupService.parseBackup('{"app":"lain","version":1}'),
      throwsFormatException,
    );
    expect(
      () => BackupService.parseBackup(
        '{"app":"roomcraft","version":99,"projects":[]}',
      ),
      throwsFormatException,
    );
  });
}
