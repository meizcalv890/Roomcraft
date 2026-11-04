import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/furniture_item.dart';
import 'package:roomcraft/features/editor/room_geometry.dart';
import 'package:roomcraft/features/editor/room_project_draft.dart';
import 'package:roomcraft/core/l10n/app_strings.dart';
void main() {
  test('Proyek lama tetap menjadi persegi panjang', () {
    final project = RoomProjectDraft.fromJson({
      'id': 'legacy',
      'name': 'Kamar lama',
      'widthCm': 300,
      'lengthCm': 400,
      'roomType': 'Bedroom',
      'furniture': [],
    });

    expect(project.roomShape, RoomShape.rectangle);
    expect(project.areaM2, 12);
    expect(project.effectiveRoomPoints, hasLength(4));
  });

  test('Luas bentuk L dihitung berdasarkan titik', () {
    final points = RoomShape.lShape.points(300, 400);

    expect(polygonAreaCm2(points) / 10000, closeTo(8.64, 0.01));
  });

  test('Geometri furnitur tetap ada setelah serialisasi', () {
    final item = FurnitureItem(
      id: 'custom-1',
      type: FurnitureType.custom,
      xCm: 10,
      yCm: 20,
      widthCm: 100,
      lengthCm: 80,
      shape: FurnitureShape.polygon,
      customName: 'Meja sudut',
      customPoints: const [
        RoomPoint(0.1, 0),
        RoomPoint(1, 0.2),
        RoomPoint(0.6, 1),
        RoomPoint(0, 0.7),
      ],
    );

    final restored = FurnitureItem.fromJson(item.toJson());

    expect(restored.shape, FurnitureShape.polygon);
    expect(restored.customName, 'Meja sudut');
    expect(restored.customPoints, hasLength(4));
    expect(restored.type, FurnitureType.custom);
  });

  test('Geometri ruangan tetap ada setelah serialisasi', () {
    final project = RoomProjectDraft(
      name: 'Ruang L',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Custom',
      roomShape: RoomShape.lShape,
      roomPoints: RoomShape.lShape.points(300, 400),
    );

    final restored = RoomProjectDraft.fromJson(project.toJson());

    expect(restored.roomShape, RoomShape.lShape);
    expect(restored.effectiveRoomPoints, hasLength(6));
    expect(restored.areaM2, closeTo(project.areaM2, 0.001));
  });

  test('Poligon dengan kurang dari tiga titik tidak valid', () {
    expect(
      isValidPolygon(const [RoomPoint(0, 0), RoomPoint(100, 0)]),
      isFalse,
    );
  });

  // ---------------------------------------------------------------
  // Tes baru
  // ---------------------------------------------------------------

  test('Bentuk non-poligon tidak memakai titik lama setelah ukuran berubah',
      () {
    final project = RoomProjectDraft(
      name: 'L',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Custom',
      roomShape: RoomShape.lShape,
      roomPoints: RoomShape.lShape.points(300, 400),
    );

    final resized = project.copyWith(widthCm: 500, lengthCm: 500);

    // 72% dari 500 x 500 cm = 18 m².
    expect(resized.areaM2, closeTo(18.0, 0.01));
  });

  test('Poligon kustom tetap memakai titik yang tersimpan', () {
    const points = [
      RoomPoint(0, 0),
      RoomPoint(200, 0),
      RoomPoint(200, 100),
      RoomPoint(0, 100),
    ];

    final project = RoomProjectDraft(
      name: 'Poligon',
      widthCm: 300,
      lengthCm: 400,
      roomType: 'Custom',
      roomShape: RoomShape.polygon,
      roomPoints: points,
    );

    expect(project.effectiveRoomPoints, points);
    expect(project.areaM2, closeTo(2.0, 0.001));
  });

  test('Poligon yang berpotongan sendiri tidak valid', () {
    expect(
      isValidPolygon(const [
        RoomPoint(0, 0),
        RoomPoint(100, 0),
        RoomPoint(10, 50),
        RoomPoint(100, 90),
      ]),
      isFalse,
    );
  });

  test('Poligon sederhana dengan titik negatif tidak valid', () {
    expect(
      isValidPolygon(const [
        RoomPoint(-10, 0),
        RoomPoint(100, 0),
        RoomPoint(100, 100),
      ]),
      isFalse,
    );
  });

  test('Persegi panjang diperiksa terhadap bentuk L, bukan bounding box', () {
    final l = RoomShape.lShape.points(300, 400);

    expect(isRectInsidePolygon(0, 0, 100, 400, l), isTrue);
    expect(isRectInsidePolygon(0, 0, 300, 176, l), isTrue);
    expect(isRectInsidePolygon(100, 100, 250, 300, l), isFalse);
  });

  test('Furnitur berotasi disesuaikan ke dalam ruangan', () {
    const item = FurnitureItem(
      id: 'a',
      type: FurnitureType.bed,
      xCm: 500,
      yCm: 500,
      widthCm: 200,
      lengthCm: 160,
      rotation: 90,
    );

    final fitted = item.fittedTo(300, 400);

    expect(fitted.xCm, 140);
    expect(fitted.yCm, 200);
  });

  test('Mengubah ukuran proyek menyesuaikan furnitur ke dalam ruangan', () {
    const item = FurnitureItem(
      id: 'a',
      type: FurnitureType.wardrobe,
      xCm: 250,
      yCm: 350,
      widthCm: 120,
      lengthCm: 60,
    );

    final project = RoomProjectDraft(
      name: 'Kecil',
      widthCm: 200,
      lengthCm: 200,
      roomType: 'Bedroom',
      furniture: const [item],
    ).withFurnitureFitted();

    final fitted = project.furniture.single;

    expect(fitted.rightCm, lessThanOrEqualTo(200));
    expect(fitted.bottomCm, lessThanOrEqualTo(200));
  });

  test('Duplikat furnitur mempertahankan bentuk dan nama kustom', () {
    const item = FurnitureItem(
      id: 'a',
      type: FurnitureType.custom,
      xCm: 0,
      yCm: 0,
      widthCm: 100,
      lengthCm: 80,
      shape: FurnitureShape.lShape,
      customName: 'Meja sudut',
    );

    final copy = item.copyWith(id: 'b');

    expect(copy.id, 'b');
    expect(copy.shape, FurnitureShape.lShape);
    expect(copy.customName, 'Meja sudut');
  });

  test('Data furnitur rusak dibersihkan saat dibaca', () {
    final item = FurnitureItem.fromJson({
      'type': 'bed',
      'xCm': -50,
      'widthCm': 0,
      'lengthCm': 'abc',
      'rotation': 45,
    });

    expect(item.id, isNotEmpty);
    expect(item.xCm, 0);
    expect(item.widthCm, FurnitureType.bed.defaultWidthCm);
    expect(item.lengthCm, FurnitureType.bed.defaultLengthCm);
    expect(item.rotation, 0);
  });

    test('Label enum mengikuti bahasa aktif', () {
    AppStrings.current = const AppStrings(AppLanguage.id);
    expect(FurnitureType.bed.label, 'Tempat tidur');
    expect(RoomShape.lShape.label, 'Bentuk L');

    AppStrings.current = const AppStrings(AppLanguage.en);
    expect(FurnitureType.bed.label, 'Bed');
    expect(RoomShape.lShape.label, 'L-shape');
  });

  test('Nama kustom tidak ikut diterjemahkan', () {
    const item = FurnitureItem(
      id: 'a',
      type: FurnitureType.custom,
      xCm: 0,
      yCm: 0,
      widthCm: 100,
      lengthCm: 80,
      customName: 'Meja sudut',
    );

    AppStrings.current = const AppStrings(AppLanguage.en);
    expect(item.displayName, 'Meja sudut');
  });
}
