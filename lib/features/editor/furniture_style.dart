import 'package:flutter/material.dart';

import 'furniture_item.dart';

enum FurnitureCategory { sleeping, seating, work, storage, dining, other }

extension FurnitureTypeStyle on FurnitureType {
  IconData get icon {
    switch (this) {
      case FurnitureType.bed:
        return Icons.bed_outlined;
      case FurnitureType.sofa:
        return Icons.weekend_outlined;
      case FurnitureType.desk:
        return Icons.desk_outlined;
      case FurnitureType.chair:
        return Icons.chair_outlined;
      case FurnitureType.wardrobe:
        return Icons.inventory_2_outlined;
      case FurnitureType.diningTable:
        return Icons.table_restaurant_outlined;
      case FurnitureType.custom:
        return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case FurnitureType.bed:
        return const Color(0xFFD8C6AA);
      case FurnitureType.sofa:
        return const Color(0xFFB8C8B1);
      case FurnitureType.desk:
        return const Color(0xFFE4D3B8);
      case FurnitureType.chair:
        return const Color(0xFFC7D6D0);
      case FurnitureType.wardrobe:
        return const Color(0xFFD7C5BB);
      case FurnitureType.diningTable:
        return const Color(0xFFE2D8A9);
      case FurnitureType.custom:
        return const Color(0xFFD0C7E8);
    }
  }

  FurnitureCategory get category {
    switch (this) {
      case FurnitureType.bed:
        return FurnitureCategory.sleeping;
      case FurnitureType.sofa:
      case FurnitureType.chair:
        return FurnitureCategory.seating;
      case FurnitureType.desk:
        return FurnitureCategory.work;
      case FurnitureType.wardrobe:
        return FurnitureCategory.storage;
      case FurnitureType.diningTable:
        return FurnitureCategory.dining;
      case FurnitureType.custom:
        return FurnitureCategory.other;
    }
  }
}