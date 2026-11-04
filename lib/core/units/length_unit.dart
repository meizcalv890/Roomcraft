import 'package:flutter/widgets.dart';

import '../storage/roomcraft_storage.dart';

/// Satuan panjang untuk tampilan dan input. Data selalu disimpan dalam cm.
enum LengthUnit {
  cm('cm', 1.0),
  mm('mm', 0.1),
  m('m', 100.0),
  inch('in', 2.54);

  const LengthUnit(this.symbol, this.cmPerUnit);

  final String symbol;
  final double cmPerUnit;

  double fromCm(double cm) => cm / cmPerUnit;

  double toCm(double value) => value * cmPerUnit;

  int get decimals {
    switch (this) {
      case LengthUnit.cm:
        return 1;
      case LengthUnit.mm:
        return 1;
      case LengthUnit.m:
        return 3;
      case LengthUnit.inch:
        return 2;
    }
  }

  /// Angka tanpa satuan, mis. 250 atau 12.5.
  String formatValue(double cm) {
    var text = fromCm(cm).toStringAsFixed(decimals);

    if (text.contains('.')) {
      text = text.replaceAll(RegExp(r'0+$'), '');

      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }

    if (text == '-0') text = '0';

    return text;
  }

  String formatWithUnit(double cm) => '${formatValue(cm)} $symbol';

  /// Membaca input pengguna dan mengembalikan nilai dalam cm.
  /// Boleh memakai akhiran satuan sendiri, mis. "2,5m", "120 cm", "12in".
  static double? parseCm(String text, LengthUnit defaultUnit) {
    final cleaned = text.trim().toLowerCase().replaceAll(',', '.');

    final match = RegExp(r'^(-?\d+(?:\.\d+)?|-?\.\d+)\s*(mm|cm|m|in|")?$')
        .firstMatch(cleaned);

    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);

    if (value == null || !value.isFinite) return null;

    final suffix = match.group(2);

    final unit = switch (suffix) {
      'mm' => LengthUnit.mm,
      'cm' => LengthUnit.cm,
      'm' => LengthUnit.m,
      'in' || '"' => LengthUnit.inch,
      _ => defaultUnit,
    };

    return value * unit.cmPerUnit;
  }
}

/// Menyimpan satuan aktif dan mengingat pilihan pengguna.
class UnitController extends ChangeNotifier {
  UnitController({LengthUnit? initial}) : _unit = initial ?? _load();

  LengthUnit _unit;

  LengthUnit get unit => _unit;

  static LengthUnit _load() {
    try {
      final code = RoomcraftStorage.loadUnitCode();

      for (final unit in LengthUnit.values) {
        if (unit.name == code) return unit;
      }
    } catch (_) {
      // Penyimpanan belum siap: pakai cm.
    }

    return LengthUnit.cm;
  }

  void setUnit(LengthUnit unit) {
    if (unit == _unit) return;

    _unit = unit;
    notifyListeners();

    RoomcraftStorage.saveUnitCode(unit.name).catchError((Object _) {});
  }
}

/// Menyebarkan [UnitController] ke seluruh pohon widget.
class UnitScope extends InheritedNotifier<UnitController> {
  const UnitScope({
    super.key,
    required UnitController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Null jika tidak ada scope (mis. pada tes widget tunggal).
  static UnitController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UnitScope>()?.notifier;
  }
}
