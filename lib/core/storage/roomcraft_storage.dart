import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../features/editor/room_project_draft.dart';

class RoomcraftStorage {
  RoomcraftStorage._();

  static const String _boxName = 'roomcraft_data';
  static const String _projectsKey = 'projects';
  static const String _corruptBackupPrefix = 'projects_corrupt_backup_';

    static const String _languageKey = 'language';

  /// Kode bahasa tersimpan ('en' atau 'id'), atau null jika belum dipilih.
  static String? loadLanguageCode() => _box.get(_languageKey);

  static Future<void> saveLanguageCode(String code) async {
    await _box.put(_languageKey, code);
  }

    static const String _unitKey = 'unit';

  /// Nama satuan tersimpan ('cm', 'mm', 'm', 'inch'), atau null.
  static String? loadUnitCode() => _box.get(_unitKey);

  static Future<void> saveUnitCode(String code) async {
    await _box.put(_unitKey, code);
  }

  static Future<void> _writeQueue = Future<void>.value();

  /// Bertambah setiap kali sebuah operasi tulis berhasil. UI dapat
  /// mendengarkannya untuk memuat ulang data tanpa bergantung pada urutan
  /// navigasi atau penyimpanan otomatis yang tertunda.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Box<String> get _box => Hive.box<String>(_boxName);

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  /// Menjalankan operasi tulis secara berurutan.
  /// Jika operasi sebelumnya gagal, operasi berikutnya tetap dapat berjalan.
  static Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _writeQueue.then<void>((_) async {
      await operation();
      revision.value++;
    });

    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Roomcraft: operasi penyimpanan gagal: $error');
      },
    );

    return result;
  }

  static int _byNewest(RoomProjectDraft a, RoomProjectDraft b) {
    final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return bDate.compareTo(aDate);
  }

  static List<RoomProjectDraft> loadProjects() {
    final raw = _box.get(_projectsKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        throw const FormatException('Data proyek harus berupa daftar.');
      }

      final projects = decoded.map((item) {
        if (item is! Map) {
          throw const FormatException('Format salah satu proyek tidak valid.');
        }

        return RoomProjectDraft.fromJson(Map<String, dynamic>.from(item));
      }).toList()..sort(_byNewest);

      return projects;
    } catch (error, stackTrace) {
      debugPrint('Roomcraft: gagal membaca data proyek: $error');
      debugPrintStack(stackTrace: stackTrace);

      // Jangan menganggap data yang rusak sebagai daftar kosong
      // untuk kemudian menimpanya secara tidak sengaja.
      rethrow;
    }
  }

  static Future<void> _writeProjectsNow(List<RoomProjectDraft> projects) async {
    final json = jsonEncode(
      projects.map((project) => project.toJson()).toList(),
    );

    await _box.put(_projectsKey, json);
  }

  static Future<void> saveProjects(List<RoomProjectDraft> projects) {
    final snapshot = List<RoomProjectDraft>.of(projects);

    return _enqueueWrite(() => _writeProjectsNow(snapshot));
  }

  static Future<void> saveProject(RoomProjectDraft project) {
    return _enqueueWrite(() async {
      final projects = loadProjects();

      final index = projects.indexWhere((item) => item.id == project.id);

      if (index == -1) {
        projects.insert(0, project);
      } else {
        projects[index] = project;
      }

      projects.sort(_byNewest);

      await _writeProjectsNow(projects);
    });
  }

  static Future<void> deleteProject(String id) {
    return _enqueueWrite(() async {
      final projects = loadProjects()
        ..removeWhere((project) => project.id == id);

      await _writeProjectsNow(projects);
    });
  }

  /// Menyimpan salinan data yang rusak ke kunci cadangan, lalu
  /// mengosongkan daftar proyek agar aplikasi dapat dipakai lagi.
  static Future<void> backupAndResetCorruptedData() {
    return _enqueueWrite(() async {
      final raw = _box.get(_projectsKey);

      if (raw != null && raw.isNotEmpty) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await _box.put('$_corruptBackupPrefix$stamp', raw);
      }

      await _box.delete(_projectsKey);
    });
  }
}
