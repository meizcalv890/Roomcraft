import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_strings.dart';
import 'language_controller.dart';

/// Tombol pemilih bahasa. Dipakai di beranda dan di editor.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key, this.compact = false});

  /// Tampilan polos untuk AppBar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.maybeOf(context);
    final strings = context.l10n;

    return PopupMenuButton<AppLanguage>(
      tooltip: strings.languageLabel,
      initialValue: controller?.language,
      onSelected: (language) => controller?.setLanguage(language),
      itemBuilder: (_) => [
        for (final language in AppLanguage.values)
          CheckedPopupMenuItem<AppLanguage>(
            value: language,
            checked: controller?.language == language,
            child: Text(language.nativeName),
          ),
      ],
      child: compact
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.translate_rounded, color: AppColors.forest),
            )
          : Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.translate_rounded,
                color: AppColors.forest,
              ),
            ),
    );
  }
}