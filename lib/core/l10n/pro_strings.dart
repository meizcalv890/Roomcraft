import 'app_strings.dart';

/// Teks alat profesional (tahap 6).
extension ProStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get proToolsTooltip => _s('Pro tools', 'Alat profesional');
  String get cutListMenu => _s('Cut list & materials', 'Daftar potong & bahan');
  String get clearanceMenu => _s('Clearance check', 'Cek jarak & lorong');
  String get exportSvgMenu => _s('Export SVG (1:1 cm)', 'Ekspor SVG (1:1 cm)');
  String get snapObjects => _s('Magnet', 'Magnet');

  String get cutListTitle =>
      _s('Cut list & materials', 'Daftar potong & bahan');
  String get clearanceTitle => _s('Clearance check', 'Cek jarak & lorong');
  String get noFurnitureYet =>
      _s('No furniture in the plan yet.', 'Belum ada furnitur di denah.');

  String get partTop => _s('Top', 'Papan atas');
  String get partBottom => _s('Bottom', 'Papan bawah');
  String get partFrontBack => _s('Front/back', 'Depan/belakang');
  String get partSides => _s('Sides', 'Samping');
  String get partSideStrip =>
      _s('Side strip (perimeter)', 'Strip samping (keliling)');

  String get qtyLabel => _s('qty', 'jml');
  String totalPanelArea(String m2) =>
      _s('Panel area: $m2 m²', 'Luas panel: $m2 m²');
  String sheetsNeeded(int n) => _s(
    '≈ $n sheet(s) of 122×244 cm (incl. 15% waste)',
    '≈ $n lembar 122×244 cm (termasuk sisa 15%)',
  );
  String get cutListNote => _s(
    'Estimate for a simple box construction. Curved outlines use the real '
        'outline area; always verify before cutting.',
    'Perkiraan untuk konstruksi kotak sederhana. Bentuk lengkung memakai luas '
        'outline sebenarnya; selalu periksa ulang sebelum memotong.',
  );
  String get copyText => _s('Copy as text', 'Salin sebagai teks');
  String get copiedText => _s('Copied to clipboard', 'Tersalin ke papan klip');

  String minGapLabel(String value) =>
      _s('Minimum gap: $value', 'Jarak minimum: $value');
  String gapBetween(String a, String b, String cm) =>
      _s('$a ↔ $b: $cm cm', '$a ↔ $b: $cm cm');
  String gapToEdge(String a, String cm) =>
      _s('$a ↔ room edge: $cm cm', '$a ↔ tepi ruangan: $cm cm');
  String get allClear => _s(
    'All gaps are at least the minimum.',
    'Semua celah memenuhi jarak minimum.',
  );
  String get gapNote => _s(
    'Gaps use each object\'s bounding box. 0 means overlapping.',
    'Celah dihitung dari kotak pembatas tiap objek. 0 berarti bertumpuk.',
  );
}
