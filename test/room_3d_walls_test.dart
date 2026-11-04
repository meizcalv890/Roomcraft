import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_3d_screen.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';
import 'package:roomcraft/features/editor/room_surface.dart';

void main() {
  const door = FurnitureItem(
    id: 'door',
    type: FurnitureType.custom,
    xCm: 50,
    yCm: 40,
    widthCm: 90,
    lengthCm: 210,
    customName: 'Pintu',
    openingKind: 'door',
  );

  const shelf = FurnitureItem(
    id: 'shelf',
    type: FurnitureType.custom,
    xCm: 180,
    yCm: 80,
    widthCm: 80,
    lengthCm: 30,
    heightCm: 25,
  );

  test('edgeIndex bawaan -1 dan tersimpan di JSON', () {
    final plain = RoomSurface.wall(id: 'a', name: 'A');

    expect(plain.edgeIndex, -1);

    final linked = plain.copyWith(edgeIndex: 2);
    final restored = RoomSurface.fromJson(linked.toJson());

    expect(restored.edgeIndex, 2);
  });

  test('openingKind tersimpan di JSON dan nilai asing diabaikan', () {
    final restored = FurnitureItem.fromJson(door.toJson());

    expect(restored.openingKind, 'door');
    expect(restored.isOpening, isTrue);

    final json = shelf.toJson()..['openingKind'] = 'aneh';

    expect(FurnitureItem.fromJson(json).openingKind, isNull);
  });

  testWidgets('3D menampilkan objek dinding, pintu, dan jendela', (
    tester,
  ) async {
    final base = RoomProjectDraft(
      name: 'Uji',
      widthCm: 400,
      lengthCm: 300,
      roomType: 'Bedroom',
    );

    final wall = RoomSurface.wall(
      id: 'w',
      name: 'Utara',
    ).copyWith(edgeIndex: 0, items: const [door, shelf]);

    final project = base.copyWith(surfaces: [wall]);

    await tester.pumpWidget(
      MaterialApp(
        home: Room3DScreen(project: project, items: const []),
      ),
    );
    await tester.pump();

    expect(find.byType(Room3DScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
