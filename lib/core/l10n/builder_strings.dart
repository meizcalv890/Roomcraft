import '../../features/editor/furniture_material.dart';
import 'app_strings.dart';

/// Teks untuk daftar permukaan dan pembuat furnitur (tahap 3 dan 4).
extension BuilderStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get renameLabel => _s('Rename', 'Ganti nama');

  String get builderTool => _s('Build', 'Rancang');
  String get builderTitle => _s('Furniture builder', 'Perancang furnitur');
  String get outlineSection => _s('Outline (top view)', 'Bentuk (tampak atas)');
  String get editOutline => _s('Edit outline', 'Ubah bentuk');
  String get materialLabel => _s('Material', 'Bahan');
  String get thicknessLabel => _s('Panel thickness', 'Tebal papan');
  String get footprintLabel => _s('Footprint', 'Luas alas');
  String get volumeLabel => _s('Volume (approx.)', 'Volume (perkiraan)');

  String materialName(FurnitureMaterial material) {
    switch (material) {
      case FurnitureMaterial.wood:
        return _s('Solid wood', 'Kayu solid');
      case FurnitureMaterial.plywood:
        return _s('Plywood', 'Multipleks');
      case FurnitureMaterial.mdf:
        return 'MDF';
      case FurnitureMaterial.metal:
        return _s('Metal', 'Logam');
      case FurnitureMaterial.glass:
        return _s('Glass', 'Kaca');
      case FurnitureMaterial.fabric:
        return _s('Fabric', 'Kain');
      case FurnitureMaterial.plastic:
        return _s('Plastic', 'Plastik');
      case FurnitureMaterial.stone:
        return _s('Stone', 'Batu');
    }
  }
}
