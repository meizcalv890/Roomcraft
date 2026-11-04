import 'app_strings.dart';

/// Teks penyempurnaan akhir: dinding terhubung ke 3D, pintu, jendela.
extension FinishStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get linkEdgeTooltip => _s(
    'Link to a room edge (shows in 3D)',
    'Hubungkan ke sisi denah (tampil di 3D)',
  );
  String get linkEdgeTitle => _s('Room edge', 'Sisi denah');
  String get linkEdgeNone => _s('Not linked', 'Tidak terhubung');
  String linkEdgeItem(int number, String length) =>
      _s('Edge $number · $length', 'Sisi $number · $length');
  String get linkEdgeNote => _s(
    'The wall is seen from inside the room, left to right. Only straight '
        'edges appear in 3D.',
    'Dinding dilihat dari dalam ruangan, kiri ke kanan. Hanya sisi lurus '
        'yang tampil di 3D.',
  );

  String get doorName => _s('Door', 'Pintu');
  String get windowName => _s('Window', 'Jendela');
  String get openingsTitle => _s('Openings', 'Bukaan');
  String get autosaved =>
      _s('Changes are saved automatically.', 'Perubahan tersimpan otomatis.');
  String get wallDepthNote => _s(
    'For wall objects, "Height" in the builder is the depth that sticks out '
        'from the wall.',
    'Untuk objek dinding, "Tinggi" di pembuat furnitur adalah kedalaman '
        'tonjolan dari dinding.',
  );
}
