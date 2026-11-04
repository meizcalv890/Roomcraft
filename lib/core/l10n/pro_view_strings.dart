import 'app_strings.dart';

/// Teks alat ukur dan tampak furnitur (penyempurnaan).
extension ProViewStrings on AppStrings {
  String _s(String en, String id) => language == AppLanguage.id ? id : en;

  String get measureMenu => _s('Measure distance', 'Ukur jarak');
  String get measureTitle => _s('Measure', 'Alat ukur');
  String get measureTapFirst =>
      _s('Tap the first point', 'Ketuk titik pertama');
  String get measureTapSecond =>
      _s('Tap the second point', 'Ketuk titik kedua');
  String get measureHint => _s(
    'Points snap to room corners, furniture corners and centers. '
        'Pinch to zoom for precision.',
    'Titik menempel ke sudut ruangan, sudut dan pusat furnitur. '
        'Cubit untuk zoom agar lebih presisi.',
  );
  String get measureEmpty => _s('No measurements yet.', 'Belum ada ukuran.');
  String get clearMeasures => _s('Clear all', 'Hapus semua');
  String get undoLastMeasure => _s('Undo last', 'Batalkan terakhir');
  String measureRow(int n, String dist, String dx, String dy, String angle) =>
      _s(
        '#$n  $dist cm  (Δx $dx · Δy $dy · $angle°)',
        '#$n  $dist cm  (Δx $dx · Δy $dy · $angle°)',
      );

  String get elevationMenu =>
      _s('Front & side views', 'Tampak depan & samping');
  String get elevationTitle => _s('Front & side views', 'Tampak furnitur');
  String get selectFirst => _s(
    'Select a furniture item first.',
    'Pilih satu furnitur terlebih dahulu.',
  );
  String get frontView => _s('Front view', 'Tampak depan');
  String get sideView => _s('Side view', 'Tampak samping');
  String get gridStepLabel => _s('Grid', 'Grid');
  String elevationSummary(String w, String l, String h, String t) => _s(
    'W $w × L $l × H $h cm · panel $t cm',
    'L $w × P $l × T $h cm · papan $t cm',
  );
  String get elevationNote => _s(
    'Views are silhouettes of the extruded shape. The darker bands at the '
        'top and bottom show the panel thickness.',
    'Tampak berupa siluet bentuk yang diekstrusi. Pita lebih gelap di atas '
        'dan bawah menunjukkan tebal papan.',
  );
}
