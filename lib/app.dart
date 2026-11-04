import 'package:flutter/material.dart';

import 'core/l10n/language_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/units/length_unit.dart';
import 'features/home/home_screen.dart';

class RoomcraftApp extends StatefulWidget {
  const RoomcraftApp({super.key});

  @override
  State<RoomcraftApp> createState() => _RoomcraftAppState();
}

class _RoomcraftAppState extends State<RoomcraftApp> {
  late final LanguageController _languageController;
  late final UnitController _unitController;

  @override
  void initState() {
    super.initState();
    _languageController = LanguageController();
    _unitController = UnitController();
  }

  @override
  void dispose() {
    _languageController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kedua scope berada di atas MaterialApp agar dialog, bottom sheet,
    // dan halaman baru ikut berganti bahasa dan satuan.
    return LanguageScope(
      controller: _languageController,
      child: UnitScope(
        controller: _unitController,
        child: MaterialApp(
          title: 'Roomcraft',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
