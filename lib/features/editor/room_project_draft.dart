import 'dart:math' as math;

import 'furniture_item.dart';
import 'room_geometry.dart';
import 'room_path.dart';
import 'room_surface.dart';

double _readDimension(Object? value, double fallback) {
  if (value is num && value.isFinite && value > 0) return value.toDouble();
  return fallback;
}

class RoomProjectDraft {
  const RoomProjectDraft({
    required this.name,
    required this.widthCm,
    required this.lengthCm,
    required this.roomType,
    this.id = '',
    this.furniture = const [],
    this.updatedAt,
    this.roomShape = RoomShape.rectangle,
    this.roomPoints = const [],
    this.roomPath,
    this.surfaces = const [],
  });

  final String id;
  final String name;

  /// Ukuran bounding box ruangan, dalam sentimeter.
  final double widthCm;
  final double lengthCm;

  final String roomType;
  final List<FurnitureItem> furniture;
  final DateTime? updatedAt;

  final RoomShape roomShape;

  /// Titik batas ruangan dalam sentimeter. Hanya dipakai untuk
  /// [RoomShape.polygon] tanpa [roomPath].
  final List<RoomPoint> roomPoints;

  /// Bentuk bebas (sisi lurus dan busur). Jika ada, ini yang dipakai
  /// dan mengalahkan [roomShape] serta [roomPoints].
  final RoomPath? roomPath;

  /// Dinding dan profil bebas, masing-masing dengan ukuran, grid,
  /// satuan, dan objeknya sendiri.
  final List<RoomSurface> surfaces;

  List<RoomPoint> get effectiveRoomPoints {
    final path = roomPath;

    if (path != null) return path.toPolygon(stepDeg: 3);

    if (roomShape == RoomShape.polygon && roomPoints.length >= 3) {
      return roomPoints;
    }

    return roomShape.points(widthCm, lengthCm);
  }

  /// Jalur yang bisa disunting, dibuat dari bentuk saat ini jika belum ada.
  RoomPath get currentPath {
    return roomPath ?? RoomPath.fromPoints(effectiveRoomPoints);
  }

  double get areaM2 {
    final path = roomPath;

    if (path != null) return path.areaCm2 / 10000;

    return polygonAreaCm2(effectiveRoomPoints) / 10000;
  }

  /// Menyesuaikan seluruh furnitur agar tetap berada dalam bounding box
  /// ruangan setelah ukuran ruangan berubah.
  RoomProjectDraft withFurnitureFitted() {
    return copyWith(
      furniture: furniture
          .map((item) => item.fittedTo(widthCm, lengthCm))
          .toList(),
    );
  }

  /// Memasang bentuk baru. Jalur digeser agar pojok kiri-atasnya berada di
  /// (0, 0), dan furnitur ikut digeser sama besar sehingga posisinya
  /// terhadap ruangan tidak berubah.
  RoomProjectDraft withRoomPath(RoomPath path) {
    final b = path.bounds;
    final shifted = path.shifted(-b.minX, -b.minY);

    final w = math.max(1.0, b.width);
    final l = math.max(1.0, b.height);

    final moved = furniture
        .map(
          (item) => item
              .copyWith(xCm: item.xCm - b.minX, yCm: item.yCm - b.minY)
              .fittedTo(w, l),
        )
        .toList();

    return RoomProjectDraft(
      id: id,
      name: name,
      widthCm: w,
      lengthCm: l,
      roomType: roomType,
      furniture: moved,
      updatedAt: updatedAt,
      roomShape: RoomShape.polygon,
      roomPoints: shifted.toPolygon(stepDeg: 3),
      roomPath: shifted,
      surfaces: surfaces,
    );
  }

  RoomProjectDraft copyWith({
    String? id,
    String? name,
    double? widthCm,
    double? lengthCm,
    String? roomType,
    List<FurnitureItem>? furniture,
    DateTime? updatedAt,
    RoomShape? roomShape,
    List<RoomPoint>? roomPoints,
    RoomPath? roomPath,
    bool clearRoomPath = false,
    List<RoomSurface>? surfaces,
  }) {
    return RoomProjectDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      widthCm: widthCm ?? this.widthCm,
      lengthCm: lengthCm ?? this.lengthCm,
      roomType: roomType ?? this.roomType,
      furniture: furniture ?? this.furniture,
      updatedAt: updatedAt ?? this.updatedAt,
      roomShape: roomShape ?? this.roomShape,
      roomPoints: roomPoints ?? this.roomPoints,
      roomPath: clearRoomPath ? null : (roomPath ?? this.roomPath),
      surfaces: surfaces ?? this.surfaces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'widthCm': widthCm,
      'lengthCm': lengthCm,
      'roomType': roomType,
      'roomShape': roomShape.name,
      'roomPoints': effectiveRoomPoints.map((point) => point.toJson()).toList(),
      'roomPath': roomPath?.toJson(),
      'furniture': furniture.map((item) => item.toJson()).toList(),
      'surfaces': surfaces.map((surface) => surface.toJson()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RoomProjectDraft.fromJson(Map<String, dynamic> json) {
    final shapeName = json['roomShape'] as String? ?? 'rectangle';

    final shape = RoomShape.values.firstWhere(
      (value) => value.name == shapeName,
      orElse: () => RoomShape.rectangle,
    );

    final points = (json['roomPoints'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((point) => RoomPoint.fromJson(Map<String, dynamic>.from(point)))
        .toList();

    final furniture = (json['furniture'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => FurnitureItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final surfaces = (json['surfaces'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (surface) => RoomSurface.fromJson(Map<String, dynamic>.from(surface)),
        )
        .toList();

    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName
        : 'Proyek tanpa nama';

    final rawType = json['roomType'];
    final roomType = rawType is String && rawType.isNotEmpty
        ? rawType
        : 'Bedroom';

    var width = _readDimension(json['widthCm'], 300);
    var length = _readDimension(json['lengthCm'], 400);

    // Jalur bebas hanya dipakai jika datanya valid. Ukuran ruangan
    // selalu mengikuti batas jalur agar tidak pernah tidak sinkron.
    var path = RoomPath.fromJson(json['roomPath']);

    if (path != null && !path.isValid) path = null;

    if (path != null) {
      final b = path.bounds;
      width = math.max(1.0, b.maxX);
      length = math.max(1.0, b.maxY);
    }

    return RoomProjectDraft(
      id: json['id'] as String? ?? '',
      name: name,
      widthCm: width,
      lengthCm: length,
      roomType: roomType,
      furniture: furniture,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      roomShape: shape,
      roomPoints: points,
      roomPath: path,
      surfaces: surfaces,
    );
  }
}
