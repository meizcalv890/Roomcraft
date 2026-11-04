import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/units/length_unit.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_path.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';

void main() {
  test('luas persegi panjang', () {
    expect(RoomPath.rectangle(300, 400).areaCm2, closeTo(120000, 0.001));
  });

  test('luas lingkaran dari dua busur', () {
    final circle = RoomPath.circle(200);

    expect(circle.areaCm2, closeTo(math.pi * 100 * 100, 0.5));
    expect(circle.isValid, isTrue);

    final b = circle.bounds;
    expect(b.width, closeTo(200, 0.001));
    expect(b.height, closeTo(200, 0.001));
  });

  test('luas persegi membulat', () {
    final path = RoomPath.roundedRect(300, 400, 40);

    expect(path.areaCm2, closeTo(300 * 400 - (4 - math.pi) * 40 * 40, 0.5));
    expect(path.isValid, isTrue);
    expect(path.bounds.width, closeTo(300, 0.001));
    expect(path.bounds.height, closeTo(400, 0.001));
  });

  test('membagi sisi busur tidak mengubah bentuk', () {
    final path = RoomPath.roundedRect(300, 400, 40);
    final split = path.splitEdge(1);

    expect(split.length, path.length + 1);
    expect(split.areaCm2, closeTo(path.areaCm2, 0.01));
  });

  test('mengubah panjang sisi menggeser titik ujung', () {
    final path = RoomPath.rectangle(300, 400).setChordLength(0, 250);

    expect(path.chordLength(0), closeTo(250, 0.001));
    expect(path.nodes[1].x, closeTo(250, 0.001));
  });

  test('sisi yang saling memotong tidak valid', () {
    final bowtie = RoomPath(const [
      PathNode(0, 0),
      PathNode(100, 100),
      PathNode(100, 0),
      PathNode(0, 100),
    ]);

    expect(bowtie.isValid, isFalse);
  });

  test('JSON bolak-balik', () {
    final path = RoomPath.roundedRect(300, 400, 40);
    final restored = RoomPath.fromJson(path.toJson());

    expect(restored, isNotNull);
    expect(restored!.sameAs(path), isTrue);
  });

  test('satuan: parse dan format', () {
    expect(LengthUnit.parseCm('2,5m', LengthUnit.cm), closeTo(250, 1e-9));
    expect(LengthUnit.parseCm('12 in', LengthUnit.cm), closeTo(30.48, 1e-9));
    expect(LengthUnit.parseCm('120', LengthUnit.mm), closeTo(12, 1e-9));
    expect(LengthUnit.parseCm('abc', LengthUnit.cm), isNull);
    expect(LengthUnit.m.formatValue(250), '2.5');
    expect(LengthUnit.cm.formatValue(300), '300');
  });

  test('withRoomPath menggeser furnitur bersama ruangan', () {
    const project = RoomProjectDraft(
      name: 't',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Bedroom',
      furniture: [
        FurnitureItem(
          id: 'a',
          type: FurnitureType.bed,
          xCm: 100,
          yCm: 100,
          widthCm: 100,
          lengthCm: 100,
        ),
      ],
    );

    final updated = project.withRoomPath(
      RoomPath.rectangle(400, 300).shifted(-20, -10),
    );

    expect(updated.widthCm, closeTo(400, 0.001));
    expect(updated.lengthCm, closeTo(300, 0.001));
    expect(updated.roomPath, isNotNull);
    expect(updated.furniture.first.xCm, closeTo(120, 0.001));
    expect(updated.furniture.first.yCm, closeTo(110, 0.001));
  });
}
