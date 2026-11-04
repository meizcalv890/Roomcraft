import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../storage/roomcraft_storage.dart';
import 'app_strings.dart';

/// Menyimpan bahasa aktif, memperbarui [AppStrings.current], dan
/// mengingat pilihan pengguna.
class LanguageController extends ChangeNotifier {
  LanguageController({AppLanguage? initial})
    : _language = initial ?? _detect() {
    AppStrings.current = AppStrings(_language);
  }

  AppLanguage _language;

  AppLanguage get language => _language;

  /// Urutan: pilihan tersimpan, lalu bahasa perangkat, lalu Inggris.
  static AppLanguage _detect() {
    try {
      final saved = AppLanguage.fromCode(RoomcraftStorage.loadLanguageCode());
      if (saved != null) return saved;
    } catch (_) {
      // Penyimpanan belum siap: pakai bahasa perangkat.
    }

    final code = ui.PlatformDispatcher.instance.locale.languageCode;
    return code == 'id' ? AppLanguage.id : AppLanguage.en;
  }

  void setLanguage(AppLanguage language) {
    if (language == _language) return;

    _language = language;
    AppStrings.current = AppStrings(language);
    notifyListeners();

    RoomcraftStorage.saveLanguageCode(language.code).catchError((Object _) {});
  }
}

/// Menyebarkan [LanguageController] ke seluruh pohon widget. Widget yang
/// memanggil `context.l10n` otomatis dibangun ulang saat bahasa berganti.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Null jika tidak ada scope (mis. pada tes widget tunggal).
  static LanguageController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LanguageScope>()
        ?.notifier;
  }
}

extension AppStringsContext on BuildContext {
  /// Teks sesuai bahasa aktif. Tanpa [LanguageScope], bahasa bawaan dipakai.
  AppStrings get l10n {
    LanguageScope.maybeOf(this); // mendaftarkan dependensi agar ikut rebuild
    return AppStrings.current;
  }
}