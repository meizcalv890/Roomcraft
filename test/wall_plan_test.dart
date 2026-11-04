import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_path.dart';
import 'package:roomcraft/features/editor/room_surface.dart';
import 'package:roomcraft/features/editor/wall_plan.dart';

void main() {
  final path = RoomPath.rectangle(400, 300);

  // Lemari gantung 80 cm lebar, tinggi 60 cm, dalam 35 cm, mulai x=100.
  // Tinggi dinding 250, yCm=50 dari atas, jadi berada di ketinggian 140–200.
  RoomSurface wall() =>
      RoomSurface.wall(
        id: 'w1',
        name: 'Dinding',
        widthCm: 400,
        heightCm: 250,
      ).copyWith(
        edgeIndex: 0,
        items: [
          const FurnitureItem(
            id: 'c1',
            type: FurnitureType.custom,
            xCm: 100,
            yCm: 50,
            widthCm: 80,
            lengthCm: 60,
            heightCm: 35,
          ),
        ],
      );

  test('objek dinding menjadi jejak di denah pada sisi yang tertaut', () {
    final prints = buildWallFootprints(path: path, surfaces: [wall()]);

    expect(prints.length, 1);
    expect(isWallFootprintId(prints.first.item.id), isTrue);
    expect(prints.first.item.xCm, closeTo(100, 0.01));
    expect(prints.first.item.widthCm, closeTo(80, 0.01));
    expect(prints.first.item.yCm, closeTo(0, 0.01));
    expect(prints.first.item.lengthCm, closeTo(35, 0.01));
    expect(prints.first.bottomCm, closeTo(140, 0.01));
    expect(prints.first.topCm, closeTo(200, 0.01));
  });

  test('dinding yang belum tertaut tidak muncul di denah', () {
    final unlinked = wall().copyWith(edgeIndex: -1);

    expect(buildWallFootprints(path: path, surfaces: [unlinked]), isEmpty);
  });

  test('furnitur tinggi menabrak, furnitur rendah lewat di bawahnya', () {
    final prints = buildWallFootprints(path: path, surfaces: [wall()]);

    const tall = FurnitureItem(
      id: 'f1',
      type: FurnitureType.wardrobe,
      xCm: 120,
      yCm: 10,
      widthCm: 40,
      lengthCm: 40,
    );

    const low = FurnitureItem(
      id: 'f2',
      type: FurnitureType.desk,
      xCm: 120,
      yCm: 10,
      widthCm: 40,
      lengthCm: 40,
    );

    expect(findWallHits(prints, [tall]).length, 1);
    expect(findWallHits(prints, [low]), isEmpty);
  });

  test('furnitur yang jauh dari dinding tidak dianggap menabrak', () {
    final prints = buildWallFootprints(path: path, surfaces: [wall()]);

    const far = FurnitureItem(
      id: 'f3',
      type: FurnitureType.wardrobe,
      xCm: 120,
      yCm: 200,
      widthCm: 40,
      lengthCm: 40,
    );

    expect(findWallHits(prints, [far]), isEmpty);
  });
}
