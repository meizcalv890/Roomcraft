import 'app_strings.dart';

/// Teks untuk tampilan 3D (tahap 5).
extension View3dStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get view3dTooltip => _s('3D view', 'Tampilan 3D');
  String get view3dTitle => _s('3D view', 'Tampilan 3D');
  String get presetPerspective => _s('Perspective', 'Perspektif');
  String get presetTop => _s('Top', 'Atas');
  String get presetFront => _s('Front', 'Depan');
  String get presetSide => _s('Side', 'Samping');
  String get showWalls => _s('Walls', 'Dinding');
  String wallHeightLabel(String value) =>
      _s('Wall height: $value', 'Tinggi dinding: $value');
  String get hint3d => _s(
    'Drag to orbit · pinch or scroll to zoom · double-tap to reset',
    'Tarik untuk memutar · cubit atau scroll untuk zoom · ketuk dua kali untuk reset',
  );
}
