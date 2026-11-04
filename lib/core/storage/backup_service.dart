import 'dart:convert';
import 'dart:typed_data';

import '../../features/editor/room_project_draft.dart';
import '../utils/id_generator.dart';
import 'roomcraft_storage.dart';

class BackupSummary {
  const BackupSummary({
    required this.added,
    required this.skipped,
    required this.projects,
  });

  final int added;
  final int skipped;

  /// Daftar proyek setelah digabung.
  final List<RoomProjectDraft> projects;
}

/// Pesan galat [FormatException.message] yang dipakai UI.
class BackupError {
  BackupError._();

  static const String invalid = 'invalid';
  static const String tooNew = 'too_new';
}

/// Ekspor dan impor seluruh proyek sebagai satu teks JSON.
class BackupService {
  BackupService._();

  static const String appId = 'roomcraft';
  static const int formatVersion = 1;

  static String exportText(List<RoomProjectDraft> projects) {
    return jsonEncode({
      'app': appId,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'projects': [for (final project in projects) project.toJson()],
    });
  }

  static Uint8List exportBytes(List<RoomProjectDraft> projects) {
    return Uint8List.fromList(utf8.encode(exportText(projects)));
  }

  /// Membaca teks cadangan. Melempar [FormatException] dengan pesan
  /// [BackupError.invalid] atau [BackupError.tooNew].
  static List<Map<String, dynamic>> parseBackup(String text) {
    var source = text.trim();

    if (source.startsWith('\uFEFF')) source = source.substring(1).trim();

    if (source.isEmpty) throw const FormatException(BackupError.invalid);

    Object? decoded;

    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException(BackupError.invalid);
    }

    if (decoded is! Map || decoded['app'] != appId) {
      throw const FormatException(BackupError.invalid);
    }

    final version = decoded['version'];

    if (version is! int) throw const FormatException(BackupError.invalid);

    if (version > formatVersion) {
      throw const FormatException(BackupError.tooNew);
    }

    final list = decoded['projects'];

    if (list is! List) throw const FormatException(BackupError.invalid);

    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Menggabungkan proyek cadangan ke daftar yang ada tanpa menimpa:
  /// yang identik dilewati, yang beda isi tapi id sama dijadikan salinan.
  static BackupSummary merge(
    List<RoomProjectDraft> existing,
    List<Map<String, dynamic>> incoming, {
    required String copySuffix,
  }) {
    final result = List<RoomProjectDraft>.of(existing);
    final byId = <String, RoomProjectDraft>{
      for (final project in existing) project.id: project,
    };

    var added = 0;
    var skipped = 0;

    for (final raw in incoming) {
      final RoomProjectDraft draft;

      try {
        draft = RoomProjectDraft.fromJson(raw);
      } catch (_) {
        skipped++;
        continue;
      }

      final current = draft.id.isEmpty ? null : byId[draft.id];

      if (current != null &&
          jsonEncode(current.toJson()) == jsonEncode(draft.toJson())) {
        skipped++;
        continue;
      }

      var toAdd = draft;

      if (current != null || draft.id.isEmpty) {
        final copy = Map<String, dynamic>.of(raw)
          ..['id'] = IdGenerator.next()
          ..['name'] = '${draft.name}$copySuffix';

        try {
          toAdd = RoomProjectDraft.fromJson(copy);
        } catch (_) {
          skipped++;
          continue;
        }
      }

      result.add(toAdd);
      byId[toAdd.id] = toAdd;
      added++;
    }

    return BackupSummary(added: added, skipped: skipped, projects: result);
  }

  /// Membaca [text], menggabungkannya ke penyimpanan, lalu menyimpan.
  static Future<BackupSummary> importText(
    String text, {
    required String copySuffix,
  }) async {
    final incoming = parseBackup(text);

    final summary = merge(
      RoomcraftStorage.loadProjects(),
      incoming,
      copySuffix: copySuffix,
    );

    if (summary.added > 0) {
      await RoomcraftStorage.saveProjects(summary.projects);
    }

    return summary;
  }
}
