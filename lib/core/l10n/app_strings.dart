import '../../features/editor/furniture_item.dart';
import '../../features/editor/furniture_style.dart';
import '../../features/editor/room_geometry.dart';

enum AppLanguage {
  en('en', 'English'),
  id('id', 'Bahasa Indonesia');

  const AppLanguage(this.code, this.nativeName);

  final String code;
  final String nativeName;

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// Semua teks aplikasi. Setiap teks punya versi Inggris dan Indonesia
/// berdampingan, sehingga tidak mungkin ada teks yang lupa diterjemahkan.
///
/// Widget mengambilnya lewat `context.l10n`. Kode non-widget (mis. label
/// model) memakai [AppStrings.current].
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  /// Diperbarui oleh LanguageController setiap bahasa berganti.
  static AppStrings current = const AppStrings(AppLanguage.en);

  String _t(String en, String id) => language == AppLanguage.id ? id : en;

  // ------------------------------------------------------------------
  // Umum
  // ------------------------------------------------------------------
  String get cancel => _t('Cancel', 'Batal');
  String get delete => _t('Delete', 'Hapus');
  String get apply => _t('Apply', 'Terapkan');
  String get languageLabel => _t('Language', 'Bahasa');

  // ------------------------------------------------------------------
  // Beranda
  // ------------------------------------------------------------------
  String get tagline =>
      _t('YOUR PERSONAL ROOM PLANNER', 'PERENCANA RUANG PRIBADIMU');
  String get heroBadge => _t('DESIGN YOUR SPACE', 'RANCANG RUANGMU');
  String get heroTitle =>
      _t('A room that\nfeels like you.', 'Ruang yang\nterasa seperti dirimu.');
  String get heroSubtitle => _t(
    'Plan your room, arrange your furniture, '
        'and make every corner count.',
    'Rancang ruanganmu, tata furniturnya, '
        'dan manfaatkan setiap sudutnya.',
  );
  String get createNewProject => _t('Create new project', 'Buat proyek baru');
  String get myProjects => _t('My projects', 'Proyek saya');
  String get loadingCaps => _t('LOADING...', 'MEMUAT...');
  String projectsCount(int n) => _t('$n PROJECTS', '$n PROYEK');

  String get emptyTitle => _t('Your canvas awaits', 'Kanvasmu menunggu');
  String get emptyBody => _t(
    'Create your first room and start planning '
        'a space that works for you.',
    'Buat ruangan pertamamu dan mulai merancang '
        'ruang yang sesuai untukmu.',
  );
  String get startRoom => _t('Start a room', 'Mulai ruangan');

  String get tipTitle => _t('A little design tip', 'Tips desain singkat');
  String get tipBody => _t(
    'Measure your room before arranging '
        'furniture for a more accurate layout.',
    'Ukur ruanganmu sebelum menata furnitur '
        'agar tata letaknya lebih akurat.',
  );
  String get footer => _t(
    'DESIGNED FOR YOUR SPACE  ·  ROOMCRAFT',
    'DIRANCANG UNTUK RUANGMU  ·  ROOMCRAFT',
  );

  String get loadErrorTitle =>
      _t('Project data cannot be read', 'Data proyek tidak dapat dibaca');
  String get loadErrorBody => _t(
    'A copy of the old data will be backed up before '
        'the project list is cleared.',
    'Salinan data lama akan dicadangkan sebelum '
        'daftar proyek dikosongkan.',
  );
  String get backupAndReset => _t('Back up & reset', 'Cadangkan & reset');

  String get msgLoadFailed =>
      _t('Failed to load the project list.', 'Gagal memuat daftar proyek.');
  String msgRecoverFailed(Object e) =>
      _t('Failed to recover data: $e', 'Gagal memulihkan data: $e');
  String msgSaveFailed(Object e) =>
      _t('Project could not be saved: $e', 'Proyek gagal disimpan: $e');
  String get msgProjectUpdated =>
      _t('Project updated successfully.', 'Proyek berhasil diperbarui.');
  String msgUpdateFailed(Object e) =>
      _t('Failed to update project: $e', 'Gagal memperbarui proyek: $e');
  String get msgProjectDuplicated =>
      _t('Project duplicated successfully.', 'Proyek berhasil diduplikasi.');
  String msgDuplicateFailed(Object e) =>
      _t('Failed to duplicate project: $e', 'Gagal menduplikasi proyek: $e');
  String get msgProjectDeleted =>
      _t('Project deleted successfully.', 'Proyek berhasil dihapus.');
  String msgDeleteFailed(Object e) =>
      _t('Failed to delete project: $e', 'Gagal menghapus proyek: $e');

  String get deleteTitle => _t('Delete project?', 'Hapus proyek?');
  String deleteBody(String name) => _t(
    'Are you sure you want to delete "$name"? '
        'This action cannot be undone.',
    'Yakin ingin menghapus "$name"? '
        'Tindakan ini tidak dapat dibatalkan.',
  );
  String get copySuffix => _t(' (Copy)', ' (Salinan)');

  String furnitureCount(int n) => _t('$n furniture', '$n furnitur');
  String get projectActions => _t('Project actions', 'Aksi proyek');
  String get editProject => _t('Edit project', 'Edit proyek');
  String get duplicateProject => _t('Duplicate project', 'Duplikasi proyek');
  String get deleteProject => _t('Delete project', 'Hapus proyek');

  // ------------------------------------------------------------------
  // Formulir proyek
  // ------------------------------------------------------------------
  String get newRoomProject => _t('New room project', 'Proyek ruangan baru');
  String get editRoomProject => _t('Edit room project', 'Edit proyek ruangan');
  String get formNewSubtitle => _t(
    'Name your project and define the shape of your space.',
    'Beri nama proyek dan tentukan bentuk ruangmu.',
  );
  String get formEditSubtitle => _t(
    'Update your room details. Existing furniture will be kept.',
    'Perbarui detail ruangan. Furnitur yang ada akan dipertahankan.',
  );
  String get projectName => _t('Project name', 'Nama proyek');
  String get projectNameHint => _t('e.g. My bedroom', 'mis. Kamar tidurku');
  String get nameRequired =>
      _t('Project name is required', 'Nama proyek wajib diisi');
  String get nameTooLong => _t(
    'Maximum name length is 40 characters',
    'Nama maksimal 40 karakter',
  );
  String get roomType => _t('Room type', 'Jenis ruangan');

  /// [key] adalah nilai yang tersimpan di data proyek (selalu Inggris),
  /// jadi data lama tetap terbaca di kedua bahasa.
  String roomTypeLabel(String key) {
    switch (key) {
      case 'Bedroom':
        return _t('Bedroom', 'Kamar tidur');
      case 'Dorm room':
        return _t('Dorm room', 'Kamar asrama');
      case 'Study room':
        return _t('Study room', 'Ruang belajar');
      case 'Living room':
        return _t('Living room', 'Ruang tamu');
      case 'Other':
        return _t('Other', 'Lainnya');
      case 'Custom':
        return _t('Custom', 'Kustom');
      default:
        return key;
    }
  }

  static const roomTypeKeys = [
    'Bedroom',
    'Dorm room',
    'Study room',
    'Living room',
    'Other',
  ];

  String get roomDimensions =>
      _t('Room dimensions (cm)', 'Ukuran ruangan (cm)');
  String get width => _t('Width', 'Lebar');
  String get length => _t('Length', 'Panjang');
  String get dimensionInvalid =>
      _t('Enter a valid positive number', 'Masukkan angka positif yang valid');
  String get dimensionTooLarge => _t(
    'Maximum room dimension is 2000 cm',
    'Ukuran ruangan maksimal 2000 cm',
  );
  String get roomShape => _t('Room shape', 'Bentuk ruangan');
  String get roomShapeHelper =>
      _t('Choose the outline of your room.', 'Pilih garis luar ruanganmu.');
  String get cornerPoints =>
      _t('Custom corner points (cm)', 'Titik sudut kustom (cm)');
  String get cornerPointsHelp => _t(
    'Enter one corner per line as X, Y. '
        'Coordinates start at the top-left corner (0, 0). '
        'Use at least 3 points and keep them inside the dimensions.',
    'Tulis satu sudut per baris sebagai X, Y. '
        'Koordinat dimulai dari sudut kiri atas (0, 0). '
        'Pakai minimal 3 titik dan jaga tetap di dalam ukuran ruangan.',
  );
  String get pointsFormatError => _t(
    'Invalid format. Use one point per line: X, Y (no negatives).',
    'Format salah. Tulis satu titik per baris: X, Y (tanpa angka negatif).',
  );
  String get pointsMinError =>
      _t('Enter at least 3 points.', 'Masukkan minimal 3 titik.');
  String get polygonInvalidError => _t(
    'Invalid polygon: zero area or edges cross each other.',
    'Poligon tidak valid: luas nol atau sisinya saling berpotongan.',
  );
  String get pointsOutsideError => _t(
    'Every point must be inside the room dimensions.',
    'Semua titik harus berada di dalam ukuran ruangan.',
  );
  String get saveChanges => _t('Save changes', 'Simpan perubahan');
  String get createProject => _t('Create project', 'Buat proyek');

  // ------------------------------------------------------------------
  // Label enum
  // ------------------------------------------------------------------
  String roomShapeLabel(RoomShape shape) {
    switch (shape) {
      case RoomShape.rectangle:
        return _t('Rectangle', 'Persegi panjang');
      case RoomShape.lShape:
        return _t('L-shape', 'Bentuk L');
      case RoomShape.uShape:
        return _t('U-shape', 'Bentuk U');
      case RoomShape.polygon:
        return _t('Custom polygon', 'Poligon kustom');
    }
  }

  String furnitureShapeLabel(FurnitureShape shape) {
    switch (shape) {
      case FurnitureShape.rectangle:
        return _t('Rectangle', 'Persegi panjang');
      case FurnitureShape.circle:
        return _t('Circle', 'Lingkaran');
      case FurnitureShape.oval:
        return _t('Oval', 'Oval');
      case FurnitureShape.lShape:
        return _t('L-shape', 'Bentuk L');
      case FurnitureShape.uShape:
        return _t('U-shape', 'Bentuk U');
      case FurnitureShape.polygon:
        return _t('Custom polygon', 'Poligon kustom');
    }
  }

  String furnitureTypeLabel(FurnitureType type) {
    switch (type) {
      case FurnitureType.bed:
        return _t('Bed', 'Tempat tidur');
      case FurnitureType.sofa:
        return _t('Sofa', 'Sofa');
      case FurnitureType.desk:
        return _t('Desk', 'Meja kerja');
      case FurnitureType.chair:
        return _t('Chair', 'Kursi');
      case FurnitureType.wardrobe:
        return _t('Wardrobe', 'Lemari');
      case FurnitureType.diningTable:
        return _t('Dining table', 'Meja makan');
      case FurnitureType.custom:
        return _t('Custom object', 'Objek kustom');
    }
  }

  /// `null` berarti "semua kategori".
  String categoryLabel(FurnitureCategory? category) {
    switch (category) {
      case null:
        return _t('All', 'Semua');
      case FurnitureCategory.sleeping:
        return _t('Sleeping', 'Tidur');
      case FurnitureCategory.seating:
        return _t('Seating', 'Duduk');
      case FurnitureCategory.work:
        return _t('Work', 'Kerja');
      case FurnitureCategory.storage:
        return _t('Storage', 'Penyimpanan');
      case FurnitureCategory.dining:
        return _t('Dining', 'Makan');
      case FurnitureCategory.other:
        return _t('Other', 'Lainnya');
    }
  }

  // ------------------------------------------------------------------
  // Editor
  // ------------------------------------------------------------------
  String get workspaceTitle =>
      _t('ROOM DESIGN WORKSPACE', 'RUANG KERJA DESAIN RUANGAN');
  String get plan2d => _t('2D PLAN', 'DENAH 2D');
  String get exportTooltip =>
      _t('Export and share design', 'Ekspor dan bagikan desain');

  String get metricDimensions => _t('DIMENSIONS', 'DIMENSI');
  String get metricArea => _t('AREA', 'LUAS');
  String get metricFurniture => _t('FURNITURE', 'FURNITUR');
  String objectsCount(int n) => _t('$n items', '$n objek');

  String get grid => _t('Grid', 'Grid');
  String get snap => _t('Snap', 'Snap');
  String get snapOff => _t('Off', 'Mati');

  String get addFurniture => _t('Add furniture', 'Tambah furnitur');
  String addedToPlan(String name) =>
      _t('$name added to the plan', '$name ditambahkan ke denah');

  String get toolRotate => _t('Rotate', 'Putar');
  String get toolDuplicate => _t('Duplicate', 'Duplikat');
  String get toolSmaller => _t('Smaller', 'Kecil');
  String get toolLarger => _t('Larger', 'Besar');
  String get toolAdjust => _t('Adjust', 'Atur');
  String get toolDelete => _t('Delete', 'Hapus');

  String positionInfo(int left, int top, int right, int bottom) => _t(
    'From plan edge — left $left · top $top · '
        'right $right · bottom $bottom cm',
    'Dari tepi denah — kiri $left · atas $top · '
        'kanan $right · bawah $bottom cm',
  );

  String warnOutside(String name) => _t(
    '$name is outside the room boundary.',
    '$name berada di luar batas ruangan.',
  );
  String warnOverlap(String a, String b) =>
      _t('$a overlaps with $b.', '$a bertumpang tindih dengan $b.');

  String get chooseFurniture => _t('Choose furniture', 'Pilih furnitur');
  String get catalogSubtitle => _t(
    'Search by name or pick a category.',
    'Cari berdasarkan nama atau pilih kategori.',
  );
  String get searchHint => _t('Search furniture...', 'Cari furnitur...');
  String get furnitureNotFound =>
      _t('No furniture found.', 'Furnitur tidak ditemukan.');

  String propertiesOf(String name) =>
      _t('$name properties', 'Properti $name');
  String get posX => _t('Position X (cm)', 'Posisi X (cm)');
  String get posY => _t('Position Y (cm)', 'Posisi Y (cm)');
  String get widthCm => _t('Width (cm)', 'Lebar (cm)');
  String get lengthCm => _t('Length (cm)', 'Panjang (cm)');
  String get rotation => _t('Rotation', 'Rotasi');
  String get positionNote => _t(
    'Position is measured from the top-left corner of the room.',
    'Posisi dihitung dari sudut kiri atas ruangan.',
  );
  String get invalidProperties => _t(
    'Check the values. Position cannot be negative and '
        'sizes must be greater than zero.',
    'Periksa nilai. Posisi tidak boleh negatif dan '
        'ukuran harus lebih dari nol.',
  );

  String get saveError => _t(
    'Changes could not be saved yet. Try making a change again.',
    'Perubahan belum berhasil disimpan. Coba lakukan perubahan lagi.',
  );

  String exportFailed(Object e) =>
      _t('Export failed: $e', 'Ekspor gagal: $e');
  String get pngFailed => _t(
    'Failed to convert the plan to PNG.',
    'Gagal mengubah denah menjadi PNG.',
  );
  String get shareTitle => _t('Roomcraft design', 'Desain Roomcraft');
  String shareRoom(String name) =>
      _t('Room design: $name', 'Desain ruangan: $name');
  String shareSize(int w, int l) => _t('Size: $w × $l cm', 'Ukuran: $w × $l cm');
  String shareArea(String area) => _t('Area: $area m²', 'Luas: $area m²');
  String shareFurniture(int n) =>
      _t('Furniture count: $n', 'Jumlah furnitur: $n');
  String get shareMadeWith => _t('Made with Roomcraft', 'Dibuat dengan Roomcraft');

  // ------------------------------------------------------------------
  // Kanvas
  // ------------------------------------------------------------------
  String get zoomIn => _t('Zoom in', 'Perbesar');
  String get zoomOut => _t('Zoom out', 'Perkecil');
  String get resetView => _t('Reset view', 'Atur ulang tampilan');
  String get dragHint =>
      _t('Drag to move · Pinch to zoom', 'Geser untuk memindah · Cubit untuk zoom');
  String get planLabel => _t('ROOM PLAN', 'DENAH RUANGAN');
  String roomPlanSemantics(int w, int l) =>
      _t('Room plan, $w by $l centimeters', 'Denah ruangan, $w kali $l sentimeter');
  String furnitureSemantics(String name, int w, int l) =>
      _t('$name, $w by $l centimeters', '$name, $w kali $l sentimeter');
  String gridLegend(String minor, String major) => _t(
    'Grid $minor  ·  thick $major  ·  dark = 1 m',
    'Grid $minor  ·  tebal $major  ·  gelap = 1 m',
  );
}