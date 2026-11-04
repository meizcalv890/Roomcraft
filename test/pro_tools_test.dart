import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/pro_tools.dart';
import 'package:roomcraft/features/editor/room_geometry.dart';

void main() {
  const a = FurnitureItem(
    id: 'a',
    type: FurnitureType.desk,
    xCm: 0,
    yCm: 0,
    widthCm: 100,
    lengthCm: 50,
  );

  const b = FurnitureItem(
    id: 'b',
    type: FurnitureType.desk,
    xCm: 120,
    yCm: 0,
    widthCm: 100,
    lengthCm: 50,
  );

  test('daftar potong menghasilkan panel dan luas positif', () {
    final parts = buildCutList(const [a]);

    expect(parts, isNotEmpty);
    expect(parts.fold<double>(0, (s, p) => s + p.areaM2), greaterThan(0));
  });

  test('lembar bahan dibulatkan ke atas', () {
    expect(sheetsFor(0), 0);
    expect(sheetsFor(1), 1);
    expect(sheetsFor(5), 2);
  });

  test('celah antar furnitur terdeteksi', () {
    final issues = computeGaps(const [a, b], 400, 300, 60);

    expect(
      issues.any((i) => i.b != null && (i.gapCm - 20).abs() < 0.001),
      isTrue,
    );
  });

  test('furnitur berjauhan tidak dilaporkan', () {
    final far = b.copyWith(xCm: 300);

    expect(
      computeGaps([a, far], 500, 300, 60).where((i) => i.b != null),
      isEmpty,
    );
  });

  test('SVG berisi poligon dan dimensi', () {
    final svg = buildRoomSvg(
      title: 'Uji <&>',
      room: const [
        RoomPoint(0, 0),
        RoomPoint(400, 0),
        RoomPoint(400, 300),
        RoomPoint(0, 300),
      ],
      items: const [a],
    );

    expect(svg, contains('<svg'));
    expect(svg, contains('400 cm'));
    expect(svg, contains('Uji &lt;&amp;&gt;'));
  });
}
