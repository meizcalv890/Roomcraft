import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/pro_views.dart';
import 'package:roomcraft/features/editor/room_geometry.dart';

void main() {
  const item = FurnitureItem(
    id: 'a',
    type: FurnitureType.desk,
    xCm: 50,
    yCm: 50,
    widthCm: 120,
    lengthCm: 60,
  );

  test('pengukuran jarak, selisih, dan sudut', () {
    const m = Measurement(Offset(0, 0), Offset(300, 400));

    expect(m.distance, closeTo(500, 1e-9));
    expect(m.dx, 300);
    expect(m.dy, 400);
    expect(m.angleDeg, closeTo(53.13, 0.01));
  });

  test('titik tempel mencakup sudut ruangan dan pusat furnitur', () {
    final pts = measureSnapPoints(
      const [RoomPoint(0, 0), RoomPoint(400, 0), RoomPoint(400, 300)],
      const [item],
    );

    expect(pts, contains(const Offset(0, 0)));
    expect(pts, contains(const Offset(110, 80)));
  });

  testWidgets('layar tampak furnitur tampil tanpa error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ElevationScreen(item: item)),
    );
    await tester.pump();

    expect(find.byType(ElevationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar ukur mencatat dua ketukan menjadi satu ukuran', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeasureScreen(
          roomPoints: [
            RoomPoint(0, 0),
            RoomPoint(400, 0),
            RoomPoint(400, 300),
            RoomPoint(0, 300),
          ],
          items: [item],
        ),
      ),
    );
    await tester.pump();

    final area = find.byKey(const ValueKey('measure_area'));

    expect(area, findsOneWidget);

    final center = tester.getCenter(area);

    await tester.tapAt(center - const Offset(80, 30));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(center + const Offset(80, 30));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('#1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
