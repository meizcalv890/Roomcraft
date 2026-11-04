import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/units/length_unit.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_path.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';
import 'package:roomcraft/features/editor/room_surface.dart';

void main() {
  test('dinding punya ukuran dari bentuknya', () {
    final wall = RoomSurface.wall(
      id: 'w',
      name: 'Utara',
      widthCm: 320,
      heightCm: 260,
    );

    expect(wall.widthCm, closeTo(320, 0.001));
    expect(wall.heightCm, closeTo(260, 0.001));
  });

  test('profil kolong tangga valid dan memuat objek', () {
    final surface = RoomSurface.underStairs(id: 'u', name: 'Kolong');

    expect(surface.path.isValid, isTrue);
    expect(surface.kind, SurfaceKind.profile);
  });

  test('JSON bolak-balik mempertahankan satuan, grid, dan objek', () {
    final surface = RoomSurface.wall(id: 'w', name: 'Utara').copyWith(
      unit: LengthUnit.inch,
      gridCm: 12.7,
      snapCm: 2.54,
      items: const [
        FurnitureItem(
          id: 'a',
          type: FurnitureType.bed,
          xCm: 10,
          yCm: 20,
          widthCm: 100,
          lengthCm: 50,
          customName: 'Rak',
        ),
      ],
    );

    final restored = RoomSurface.fromJson(surface.toJson());

    expect(restored.unit, LengthUnit.inch);
    expect(restored.gridCm, closeTo(12.7, 1e-9));
    expect(restored.snapCm, closeTo(2.54, 1e-9));
    expect(restored.items.single.displayName, 'Rak');
    expect(restored.path.sameAs(surface.path), isTrue);
  });

  test('withPath menggeser objek bersama bentuk', () {
    final surface = RoomSurface.wall(id: 'w', name: 'Utara').copyWith(
      items: const [
        FurnitureItem(
          id: 'a',
          type: FurnitureType.bed,
          xCm: 50,
          yCm: 50,
          widthCm: 40,
          lengthCm: 40,
        ),
      ],
    );

    final moved = surface.withPath(
      RoomPath.rectangle(300, 250).shifted(-10, -5),
    );

    expect(moved.items.single.xCm, closeTo(60, 0.001));
    expect(moved.items.single.yCm, closeTo(55, 0.001));
  });

  test('proyek lama tanpa surfaces tetap terbaca', () {
    final project = RoomProjectDraft.fromJson({
      'id': 'p',
      'name': 'Lama',
      'widthCm': 300,
      'lengthCm': 400,
      'roomType': 'Bedroom',
    });

    expect(project.surfaces, isEmpty);
  });

  test('surfaces ikut tersimpan di proyek', () {
    final project = RoomProjectDraft(
      id: 'p',
      name: 'Baru',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Bedroom',
      surfaces: [RoomSurface.wall(id: 'w', name: 'Utara')],
    );

    final restored = RoomProjectDraft.fromJson(project.toJson());

    expect(restored.surfaces.single.name, 'Utara');
  });
}
