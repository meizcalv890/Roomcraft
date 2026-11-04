import 'app_strings.dart';

/// Teks peringatan objek dinding di denah.
extension PlanStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String warnWallHit(String wallObject, String floorItem) => _s(
    '$wallObject (on the wall) hits $floorItem.',
    '$wallObject (di dinding) menabrak $floorItem.',
  );
}
