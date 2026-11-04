import 'package:flutter/material.dart';

import 'furniture_item.dart';

enum FurnitureMaterial {
  wood,
  plywood,
  mdf,
  metal,
  glass,
  fabric,
  plastic,
  stone,
}

extension FurnitureMaterialInfo on FurnitureMaterial {
  Color get color {
    switch (this) {
      case FurnitureMaterial.wood:
        return const Color(0xFFC49A6C);
      case FurnitureMaterial.plywood:
        return const Color(0xFFE3C99A);
      case FurnitureMaterial.mdf:
        return const Color(0xFFB59A78);
      case FurnitureMaterial.metal:
        return const Color(0xFF9AA5AE);
      case FurnitureMaterial.glass:
        return const Color(0xFFBFE3EA);
      case FurnitureMaterial.fabric:
        return const Color(0xFFA9B8D6);
      case FurnitureMaterial.plastic:
        return const Color(0xFFE8E2D4);
      case FurnitureMaterial.stone:
        return const Color(0xFFB8B2A7);
    }
  }
}

extension FurnitureTypeHeight on FurnitureType {
  /// Tinggi bawaan (cm) bila pengguna belum mengisinya.
  double get defaultHeightCm {
    switch (this) {
      case FurnitureType.bed:
        return 50;
      case FurnitureType.sofa:
        return 85;
      case FurnitureType.desk:
        return 75;
      case FurnitureType.chair:
        return 90;
      case FurnitureType.wardrobe:
        return 200;
      case FurnitureType.diningTable:
        return 75;
      case FurnitureType.custom:
        return 75;
    }
  }
}

extension FurnitureItemSpec on FurnitureItem {
  /// Tinggi yang dipakai: isian pengguna, atau bawaan jenis furnitur.
  double get effectiveHeightCm =>
      heightCm > 0 ? heightCm : type.defaultHeightCm;
}
