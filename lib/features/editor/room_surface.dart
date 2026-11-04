import 'dart:math' as math;

import '../../core/units/length_unit.dart';
import 'furniture_item.dart';
import 'room_geometry.dart';
import 'room_path.dart';

enum SurfaceKind { wall, profile }

/// Satu bidang kerja selain denah lantai: tampak dinding atau profil bebas
/// (mis. kolong tangga). Titik (0, 0) berada di pojok kiri-atas.
class RoomSurface {
  const RoomSurface({
    required this.id,
    required this.name,
    required this.kind,
    required this.path,
    this.items = const [],
    this.unit = LengthUnit.cm,
    this.gridCm = 0,
    this.snapCm = 5,
    this.edgeIndex = -1,
  });

  final String id;
  final String name;
  final SurfaceKind kind;

  /// Bentuk permukaan. Dinding = persegi panjang; profil = bentuk bebas.
  final RoomPath path;

  /// Objek di permukaan ini. xCm/yCm diukur dari kiri dan atas;
  /// lengthCm berarti tinggi.
  final List<FurnitureItem> items;

  /// Satuan tampilan permukaan ini.
  final LengthUnit unit;

  /// Jarak garis grid tipis dalam cm. 0 = otomatis mengikuti zoom.
  final double gridCm;

  /// Jarak snap dalam cm. 0 = mati.
  final double snapCm;

  /// Nomor sisi denah lantai (mulai dari 0) tempat dinding ini menempel,
  /// dipakai tampilan 3D. -1 berarti tidak terhubung.
  final int edgeIndex;

  double get widthCm => math.max(1.0, path.bounds.maxX);
  double get heightCm => math.max(1.0, path.bounds.maxY);

  List<RoomPoint> get polygon => path.toPolygon(stepDeg: 3);

  factory RoomSurface.wall({
    required String id,
    required String name,
    double widthCm = 300,
    double heightCm = 250,
  }) {
    return RoomSurface(
      id: id,
      name: name,
      kind: SurfaceKind.wall,
      path: RoomPath.rectangle(widthCm, heightCm),
    );
  }

  /// Profil kolong tangga: tinggi di sisi kiri, menurun ke sisi kanan.
  factory RoomSurface.underStairs({
    required String id,
    required String name,
    double widthCm = 220,
    double heightCm = 240,
  }) {
    return RoomSurface(
      id: id,
      name: name,
      kind: SurfaceKind.profile,
      path: RoomPath([
        PathNode(0, 0),
        PathNode(widthCm, heightCm * 0.55),
        PathNode(widthCm, heightCm),
        PathNode(0, heightCm),
      ]),
    );
  }

  /// Untuk [edgeIndex], nilai -1 berarti "tidak terhubung".
  RoomSurface copyWith({
    String? id,
    String? name,
    SurfaceKind? kind,
    RoomPath? path,
    List<FurnitureItem>? items,
    LengthUnit? unit,
    double? gridCm,
    double? snapCm,
    int? edgeIndex,
  }) {
    return RoomSurface(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      items: items ?? this.items,
      unit: unit ?? this.unit,
      gridCm: gridCm ?? this.gridCm,
      snapCm: snapCm ?? this.snapCm,
      edgeIndex: edgeIndex ?? this.edgeIndex,
    );
  }

  /// Memasang bentuk baru. Bentuk digeser agar pojok kiri-atasnya di (0, 0)
  /// dan objek ikut digeser sama besar, lalu dijaga tetap di dalam kotak.
  RoomSurface withPath(RoomPath newPath) {
    final b = newPath.bounds;
    final shifted = newPath.shifted(-b.minX, -b.minY);

    final w = math.max(1.0, b.width);
    final h = math.max(1.0, b.height);

    final moved = items
        .map(
          (item) => item
              .copyWith(xCm: item.xCm - b.minX, yCm: item.yCm - b.minY)
              .fittedTo(w, h),
        )
        .toList();

    return copyWith(path: shifted, items: moved);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind.name,
      'path': path.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'unit': unit.name,
      'gridCm': gridCm,
      'snapCm': snapCm,
      'edgeIndex': edgeIndex,
    };
  }

  static double _num(Object? value, double fallback) {
    if (value is num && value.isFinite && value >= 0) return value.toDouble();
    return fallback;
  }

  factory RoomSurface.fromJson(Map<String, dynamic> json) {
    var path = RoomPath.fromJson(json['path']);

    if (path == null || !path.isValid) path = RoomPath.rectangle(300, 250);

    final kind = SurfaceKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => SurfaceKind.wall,
    );

    final unit = LengthUnit.values.firstWhere(
      (value) => value.name == json['unit'],
      orElse: () => LengthUnit.cm,
    );

    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => FurnitureItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final rawName = json['name'];
    final rawEdge = json['edgeIndex'];

    return RoomSurface(
      id: json['id'] as String? ?? '',
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : 'Surface',
      kind: kind,
      path: path,
      items: items,
      unit: unit,
      gridCm: _num(json['gridCm'], 0),
      snapCm: _num(json['snapCm'], 5),
      edgeIndex: rawEdge is int && rawEdge >= 0 ? rawEdge : -1,
    );
  }
}
