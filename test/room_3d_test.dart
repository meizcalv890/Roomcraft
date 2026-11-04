import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_3d_screen.dart';
import 'package:roomcraft/features/editor/room_path.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';

void main() {
  testWidgets('layar 3D tampil tanpa error untuk ruangan persegi', (
    tester,
  ) async {
    final project = RoomProjectDraft(
      name: 'Uji',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Bedroom',
    );

    const item = FurnitureItem(
      id: 'a',
      type: FurnitureType.bed,
      xCm: 20,
      yCm: 30,
      widthCm: 200,
      lengthCm: 160,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Room3DScreen(project: project, items: const [item]),
      ),
    );
    await tester.pump();

    expect(find.byType(Room3DScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar 3D tampil untuk ruangan melengkung dan bentuk bebas', (
    tester,
  ) async {
    final base = RoomProjectDraft(
      name: 'Bulat',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Bedroom',
    );

    final project = base.withRoomPath(RoomPath.roundedRect(400, 300, 60));

    final item = FurnitureItem(
      id: 'b',
      type: FurnitureType.desk,
      xCm: 100,
      yCm: 100,
      widthCm: 120,
      lengthCm: 60,
      heightCm: 75,
      shapePath: RoomPath.roundedRect(120, 60, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Room3DScreen(project: project, items: [item]),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
