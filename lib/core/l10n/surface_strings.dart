import '../../features/editor/room_surface.dart';
import 'app_strings.dart';

/// Teks untuk permukaan: dinding dan profil bebas (tahap 3).
extension SurfaceStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get surfacesTitle => _s('Walls & profiles', 'Dinding & profil');
  String get surfacesTooltip => _s('Walls & profiles', 'Dinding & profil');
  String get newSurface => _s('New surface', 'Permukaan baru');
  String get editSurface => _s('Edit surface', 'Ubah permukaan');
  String get noSurfaces => _s('No surfaces yet', 'Belum ada permukaan');
  String get noSurfacesBody => _s(
    'Add a wall to plan shelves, windows, and cabinets, or a free profile '
        'such as the space under a staircase.',
    'Tambahkan dinding untuk merencanakan rak, jendela, dan lemari, atau '
        'profil bebas seperti ruang di bawah tangga.',
  );

  String get kindWall => _s('Wall', 'Dinding');
  String get kindProfile => _s(
    'Free profile (under stairs, niche)',
    'Profil bebas (kolong tangga, ceruk)',
  );

  String kindLabel(SurfaceKind kind) {
    switch (kind) {
      case SurfaceKind.wall:
        return kindWall;
      case SurfaceKind.profile:
        return kindProfile;
    }
  }

  String get surfaceName => _s('Surface name', 'Nama permukaan');
  String get surfaceNameHint =>
      _s('e.g. North wall, Under stairs', 'mis. Dinding utara, Kolong tangga');
  String get heightLabel => _s('Height', 'Tinggi');
  String get presetUnderStairs =>
      _s('Under-stairs shape', 'Bentuk kolong tangga');

  String get duplicateSurface => _s('Duplicate', 'Duplikat');
  String get deleteSurfaceTitle => _s('Delete surface?', 'Hapus permukaan?');
  String deleteSurfaceBody(String name) => _s(
    '"$name" and all its objects will be removed.',
    '"$name" beserta seluruh objeknya akan dihapus.',
  );

  String get gridSizeLabel => _s('Grid size', 'Ukuran grid');
  String get gridAuto => _s('Auto', 'Otomatis');
  String get addObject => _s('Add object', 'Tambah objek');
  String get objectProperties => _s('Object properties', 'Properti objek');
  String get nameLabel => _s('Name', 'Nama');
  String get outsideSurface => _s(
    'Some objects are outside the surface shape.',
    'Ada objek yang berada di luar bentuk permukaan.',
  );
  String get surfaceHint => _s(
    'Drag an object to move it · pinch or scroll to zoom',
    'Tarik objek untuk memindah · cubit atau scroll untuk zoom',
  );

  String surfaceDistances(String l, String t, String r, String b) => _s(
    'Left $l · Top $t · Right $r · Bottom $b',
    'Kiri $l · Atas $t · Kanan $r · Bawah $b',
  );
}
