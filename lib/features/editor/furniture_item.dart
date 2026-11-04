import 'dart:math' as math;

import '../../core/l10n/app_strings.dart';
import '../../core/utils/id_generator.dart';
import 'furniture_material.dart';
import 'model3d.dart';
import 'room_geometry.dart';
import 'room_path.dart';

enum FurnitureType { bed, sofa, desk, chair, wardrobe, diningTable, custom }

extension FurnitureTypeInfo on FurnitureType {
  /// Nama tipe furnitur sesuai bahasa aktif.
  String get label => AppStrings.current.furnitureTypeLabel(this);

  double get defaultWidthCm {
    switch (this) {
      case FurnitureType.bed:
        return 200;
      case FurnitureType.sofa:
        return 180;
      case FurnitureType.desk:
        return 120;
      case FurnitureType.chair:
        return 45;
      case FurnitureType.wardrobe:
        return 120;
      case FurnitureType.diningTable:
        return 100;
      case FurnitureType.custom:
        return 100;
    }
  }

  double get defaultLengthCm {
    switch (this) {
      case FurnitureType.bed:
        return 160;
      case FurnitureType.sofa:
        return 85;
      case FurnitureType.desk:
        return 60;
      case FurnitureType.chair:
        return 45;
      case FurnitureType.wardrobe:
        return 60;
      case FurnitureType.diningTable:
        return 100;
      case FurnitureType.custom:
        return 80;
    }
  }
}

enum FurnitureShape { rectangle, circle, oval, lShape, uShape, polygon }

/// Elips didekati dengan banyak titik agar tampak melengkung.
List<RoomPoint> _ellipsePoints(double w, double h, {int segments = 32}) {
  return List<RoomPoint>.generate(segments, (i) {
    final angle = 2 * math.pi * i / segments;

    return RoomPoint(
      w / 2 + (w / 2) * math.cos(angle),
      h / 2 + (h / 2) * math.sin(angle),
    );
  });
}

extension FurnitureShapeInfo on FurnitureShape {
  /// Nama bentuk furnitur sesuai bahasa aktif.
  String get label => AppStrings.current.furnitureShapeLabel(this);

  /// Lingkaran dan oval digambar sebagai elips sungguhan.
  bool get isCurved =>
      this == FurnitureShape.circle || this == FurnitureShape.oval;

  List<RoomPoint> points(double width, double length) {
    final w = width > 0 ? width : 1.0;
    final h = length > 0 ? length : 1.0;

    switch (this) {
      case FurnitureShape.rectangle:
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h),
          RoomPoint(0, h),
        ];

      case FurnitureShape.circle:
      case FurnitureShape.oval:
        return _ellipsePoints(w, h);

      case FurnitureShape.lShape:
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h * 0.38),
          RoomPoint(w * 0.38, h * 0.38),
          RoomPoint(w * 0.38, h),
          RoomPoint(0, h),
        ];

      case FurnitureShape.uShape:
        return [
          RoomPoint(0, 0),
          RoomPoint(w, 0),
          RoomPoint(w, h),
          RoomPoint(w * 0.72, h),
          RoomPoint(w * 0.72, h * 0.32),
          RoomPoint(w * 0.28, h * 0.32),
          RoomPoint(w * 0.28, h),
          RoomPoint(0, h),
        ];

      case FurnitureShape.polygon:
        return [
          RoomPoint(w * 0.18, 0),
          RoomPoint(w * 0.88, h * 0.08),
          RoomPoint(w, h * 0.62),
          RoomPoint(w * 0.62, h),
          RoomPoint(w * 0.08, h * 0.78),
          RoomPoint(0, h * 0.28),
        ];
    }
  }
}

double _readFinite(Object? value, double fallback) {
  if (value is num && value.isFinite) return value.toDouble();
  return fallback;
}

double _readPositive(Object? value, double fallback) {
  if (value is num && value.isFinite && value > 0) return value.toDouble();
  return fallback;
}

RoomPath? _readShapePath(Object? raw) {
  final path = RoomPath.fromJson(raw);

  if (path == null || !path.isValid) return null;

  return path;
}

class FurnitureItem {
  const FurnitureItem({
    required this.id,
    required this.type,
    required this.xCm,
    required this.yCm,
    required this.widthCm,
    required this.lengthCm,
    this.rotation = 0,
    this.shape = FurnitureShape.rectangle,
    this.customPoints = const [],
    this.customName,
    this.heightCm = 0,
    this.thicknessCm = 1.8,
    this.material = FurnitureMaterial.wood,
    this.shapePath,
    this.openingKind,
    this.model,
  });

  final String id;
  final FurnitureType type;
  final double xCm;
  final double yCm;
  final double widthCm;
  final double lengthCm;

  /// Hanya bernilai 0 atau 90 derajat.
  final int rotation;
  final FurnitureShape shape;

  /// Koordinat lokal ternormalisasi 0..1.
  final List<RoomPoint> customPoints;
  final String? customName;

  /// Tinggi furnitur (cm). 0 berarti memakai tinggi bawaan jenisnya.
  /// Untuk objek di dinding, nilai ini dipakai sebagai kedalaman tonjolan.
  final double heightCm;

  /// Tebal papan atau bahan (cm).
  final double thicknessCm;

  final FurnitureMaterial material;

  /// Bentuk tampak atas yang bisa disunting (sisi lurus dan busur),
  /// dalam cm pada orientasi asli. Null untuk bentuk bawaan.
  final RoomPath? shapePath;

  /// 'door' atau 'window' untuk bukaan di dinding; null untuk objek biasa.
  final String? openingKind;

  /// Jaring 3D hasil impor atau perancang (koordinat 0..1). Lebar, panjang,
  /// dan tinggi furnitur menjadi ukuran modelnya. Null untuk furnitur biasa.
  final FurnitureModel? model;

  bool get isOpening => openingKind != null;

  bool get isRotated => rotation % 180 != 0;

  double get effectiveWidthCm => isRotated ? lengthCm : widthCm;

  double get effectiveLengthCm => isRotated ? widthCm : lengthCm;

  double get rightCm => xCm + effectiveWidthCm;

  double get bottomCm => yCm + effectiveLengthCm;

  /// Nama kustom bila ada, selain itu nama tipe sesuai bahasa aktif.
  String get displayName {
    final name = customName?.trim();
    return (name == null || name.isEmpty) ? type.label : name;
  }

  /// Titik bentuk dalam sentimeter pada orientasi asli (sebelum rotasi).
  List<RoomPoint> get localPoints {
    if (customPoints.length >= 3) {
      return customPoints
          .map((point) => RoomPoint(point.x * widthCm, point.y * lengthCm))
          .toList();
    }

    return shape.points(widthCm, lengthCm);
  }

  /// Menyesuaikan ukuran dan posisi agar berada di dalam bounding box ruangan.
  FurnitureItem fittedTo(double roomWidthCm, double roomLengthCm) {
    final maxWidth = isRotated ? roomLengthCm : roomWidthCm;
    final maxLength = isRotated ? roomWidthCm : roomLengthCm;

    final width = math.min(widthCm, maxWidth);
    final length = math.min(lengthCm, maxLength);

    final effectiveWidth = isRotated ? length : width;
    final effectiveLength = isRotated ? width : length;

    final x = xCm
        .clamp(0.0, math.max(0.0, roomWidthCm - effectiveWidth))
        .toDouble();
    final y = yCm
        .clamp(0.0, math.max(0.0, roomLengthCm - effectiveLength))
        .toDouble();

    return copyWith(xCm: x, yCm: y, widthCm: width, lengthCm: length);
  }

  FurnitureItem copyWith({
    String? id,
    double? xCm,
    double? yCm,
    double? widthCm,
    double? lengthCm,
    int? rotation,
    FurnitureShape? shape,
    List<RoomPoint>? customPoints,
    String? customName,
    bool clearCustomName = false,
    double? heightCm,
    double? thicknessCm,
    FurnitureMaterial? material,
    RoomPath? shapePath,
    bool clearShapePath = false,
    String? openingKind,
    FurnitureModel? model,
    bool clearModel = false,
  }) {
    return FurnitureItem(
      id: id ?? this.id,
      type: type,
      xCm: xCm ?? this.xCm,
      yCm: yCm ?? this.yCm,
      widthCm: widthCm ?? this.widthCm,
      lengthCm: lengthCm ?? this.lengthCm,
      rotation: rotation ?? this.rotation,
      shape: shape ?? this.shape,
      customPoints: customPoints ?? this.customPoints,
      customName: clearCustomName ? null : (customName ?? this.customName),
      heightCm: heightCm ?? this.heightCm,
      thicknessCm: thicknessCm ?? this.thicknessCm,
      material: material ?? this.material,
      shapePath: clearShapePath ? null : (shapePath ?? this.shapePath),
      openingKind: openingKind ?? this.openingKind,
      model: clearModel ? null : (model ?? this.model),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'xCm': xCm,
      'yCm': yCm,
      'widthCm': widthCm,
      'lengthCm': lengthCm,
      'rotation': rotation,
      'shape': shape.name,
      'customPoints': customPoints.map((point) => point.toJson()).toList(),
      'customName': customName,
      'heightCm': heightCm,
      'thicknessCm': thicknessCm,
      'material': material.name,
      'shapePath': shapePath?.toJson(),
      'openingKind': openingKind,
      'model': model?.toJson(),
    };
  }

  factory FurnitureItem.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'bed';
    final shapeName = json['shape'] as String? ?? 'rectangle';

    final type = FurnitureType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => FurnitureType.bed,
    );

    final shape = FurnitureShape.values.firstWhere(
      (value) => value.name == shapeName,
      orElse: () => FurnitureShape.rectangle,
    );

    final points = (json['customPoints'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((point) => RoomPoint.fromJson(Map<String, dynamic>.from(point)))
        .toList();

    final rawId = json['id'];
    final rawRotation = json['rotation'];
    final rawOpening = json['openingKind'];

    return FurnitureItem(
      id: rawId is String && rawId.isNotEmpty ? rawId : IdGenerator.next(),
      type: type,
      xCm: math.max(0.0, _readFinite(json['xCm'], 0)),
      yCm: math.max(0.0, _readFinite(json['yCm'], 0)),
      widthCm: _readPositive(json['widthCm'], type.defaultWidthCm),
      lengthCm: _readPositive(json['lengthCm'], type.defaultLengthCm),
      rotation: rawRotation is num && rawRotation.toInt() % 180 == 90 ? 90 : 0,
      shape: shape,
      customPoints: points,
      customName: json['customName'] as String?,
      heightCm: math.max(0.0, _readFinite(json['heightCm'], 0)),
      thicknessCm: _readPositive(json['thicknessCm'], 1.8),
      material: FurnitureMaterial.values.firstWhere(
        (value) => value.name == json['material'],
        orElse: () => FurnitureMaterial.wood,
      ),
      shapePath: _readShapePath(json['shapePath']),
      openingKind: (rawOpening == 'door' || rawOpening == 'window')
          ? rawOpening as String
          : null,
      model: FurnitureModel.fromJson(json['model']),
    );
  }
}
