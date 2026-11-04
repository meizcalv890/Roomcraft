import 'app_strings.dart';

/// Teks impor model 3D.
extension ModelStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get modelMenu => _s('Import 3D model', 'Impor model 3D');
  String get modelTitle => _s('Import 3D model', 'Impor model 3D');

  String get modelPickFile =>
      _s('Choose file (OBJ / STL)', 'Pilih file (OBJ / STL)');
  String get modelPasteTitle => _s('Or paste the text', 'Atau tempel teksnya');
  String get modelPasteHint => _s(
    'Paste OBJ or ASCII STL text here',
    'Tempel teks OBJ atau STL ASCII di sini',
  );
  String get modelLoadText => _s('Load pasted text', 'Muat teks tempelan');

  String modelLoaded(String name, int tris) =>
      _s('$name · $tris triangles', '$name · $tris segitiga');

  String get modelUnsupported => _s(
    'This format is not supported yet. Use OBJ or STL.',
    'Format ini belum didukung. Pakai OBJ atau STL.',
  );
  String get modelEmpty => _s(
    'No 3D shapes were found in this file.',
    'Tidak ada bentuk 3D di file ini.',
  );
  String get modelInvalid =>
      _s('The file could not be read.', 'File tidak bisa dibaca.');
  String get modelTooBig => _s(
    'The file is too large (max 40 MB).',
    'File terlalu besar (maks. 40 MB).',
  );
  String modelFailed(Object error) => _s('Failed: $error', 'Gagal: $error');

  String get modelUnitLabel => _s('Units in the file', 'Satuan di file');
  String get modelUpAxis => _s('Which way is up?', 'Arah atas model');
  String get modelYUp => _s('Y is up', 'Y ke atas');
  String get modelZUp => _s('Z is up (CAD, STL)', 'Z ke atas (CAD, STL)');
  String get modelRotate => _s('Rotate 90°', 'Putar 90°');
  String get modelDetail =>
      _s('Detail (max triangles)', 'Detail (maks. segitiga)');
  String modelSimplified(int from, int to) => _s(
    'Simplified from $from to $to triangles.',
    'Disederhanakan dari $from menjadi $to segitiga.',
  );

  String get modelSize => _s('Size (cm)', 'Ukuran (cm)');
  String get modelWidth => _s('Width', 'Lebar');
  String get modelDepth => _s('Depth', 'Kedalaman');
  String get modelHeight => _s('Height', 'Tinggi');
  String get modelKeepRatio => _s('Keep proportions', 'Jaga proporsi');
  String get modelScale => _s('Scale', 'Skala');
  String get modelTooBigForRoom => _s(
    'It will be scaled down to fit the room.',
    'Akan diperkecil agar muat di ruangan.',
  );

  String get modelColor => _s('Color / material', 'Warna / bahan');
  String get modelName => _s('Name', 'Nama');
  String get modelDefaultName => _s('3D model', 'Model 3D');
  String get modelAdd => _s('Add to room', 'Tambahkan ke ruangan');
  String get modelNeedFirst => _s('Load a model first.', 'Muat model dulu.');
  String get modelDragHint => _s('Drag to rotate', 'Seret untuk memutar');
}
