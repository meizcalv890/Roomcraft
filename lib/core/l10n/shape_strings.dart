import 'app_strings.dart';

/// Teks untuk editor bentuk ruangan (tahap 2).
extension ShapeStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get editShapeTooltip => _s('Edit room shape', 'Ubah bentuk ruangan');
  String get shapeEditorTitle => _s('Room shape', 'Bentuk ruangan');
  String get undoLabel => _s('Undo', 'Urungkan');
  String get redoLabel => _s('Redo', 'Ulangi');
  String get unitLabel => _s('Unit', 'Satuan');
  String get alignLabel => _s('Align', 'Sejajar');
  String get edgesLabel => _s('Edges', 'Sisi');
  String get pointsLabel => _s('Points', 'Titik');

  String edgeLabel(int a, int b) => _s('Edge $a → $b', 'Sisi $a → $b');
  String pointLabel(int a) => _s('Point $a', 'Titik $a');

  String get edgeLength => _s('Length', 'Panjang');
  String get chordLabel => _s('Straight distance', 'Jarak lurus');
  String get straightLabel => _s('Straight', 'Lurus');
  String get arcLabel => _s('Arc', 'Busur');
  String get arcHeight => _s('Arc height', 'Tinggi busur');
  String get radiusLabel => _s('Radius', 'Jari-jari');
  String get arcLengthLabel => _s('Arc length', 'Panjang busur');
  String get outwardLabel => _s('Outward', 'Keluar');
  String get inwardLabel => _s('Inward', 'Ke dalam');
  String get addPointTooltip =>
      _s('Add point in the middle', 'Tambah titik di tengah');
  String get deletePointTooltip => _s('Delete point', 'Hapus titik');

  String get startFrom => _s('Start from', 'Mulai dari');
  String get presetRect => _s('Rectangle', 'Persegi panjang');
  String get presetL => _s('L-shape', 'Bentuk L');
  String get presetU => _s('U-shape', 'Bentuk U');
  String get presetRounded => _s('Rounded rectangle', 'Persegi membulat');
  String get presetCircle => _s('Circle', 'Lingkaran');

  String get shapeHint => _s(
    'Drag a point to move it · drag ◇ to curve an edge · tap an edge to select it',
    'Tarik titik untuk memindah · tarik ◇ untuk melengkungkan sisi · ketuk sisi untuk memilih',
  );

  String get invalidShape => _s(
    'Invalid shape: edges cross each other or are too short.',
    'Bentuk tidak valid: sisi saling memotong atau terlalu pendek.',
  );

  String get discardTitle => _s('Discard changes?', 'Buang perubahan?');
  String get discardBody => _s(
    'The shape changes have not been applied.',
    'Perubahan bentuk belum diterapkan.',
  );
  String get discardAction => _s('Discard', 'Buang');

  String get shapeUpdated =>
      _s('Room shape updated', 'Bentuk ruangan diperbarui');

  String get customShapeHomeNote => _s(
    'Custom shape kept. Change it with the shape button inside the editor.',
    'Bentuk kustom dipertahankan. Ubah lewat tombol bentuk di dalam editor.',
  );

  String shapeGridLegend(String minor, String major) =>
      _s('Grid  $minor · $major', 'Grid  $minor · $major');
}
