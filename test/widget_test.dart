
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:roomcraft/app.dart';

late Directory testDirectory;

/// Menunggu teks muncul tanpa bergantung pada pumpAndSettle.
Future<void> pumpUntilText(
  WidgetTester tester,
  String text, {
  int maxAttempts = 60,
}) async {
  final finder = find.text(text);

  for (var i = 0; i < maxAttempts; i++) {
    if (finder.evaluate().isNotEmpty) return;

    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(
    finder,
    findsOneWidget,
    reason: 'Teks "$text" tidak ditemukan setelah menunggu.',
  );
}

/// Membuka dialog pembuatan proyek.
Future<void> openCreateProjectDialog(WidgetTester tester) async {
  await tester.pumpWidget(const RoomcraftApp());

  await pumpUntilText(tester, 'Your canvas awaits');

  await tester.tap(find.text('Create new project'));

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text('New room project'), findsOneWidget);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    testDirectory = await Directory.systemTemp.createTemp(
      'roomcraft_test_',
    );

    Hive.init(testDirectory.path);
    await Hive.openBox<String>('roomcraft_data');
  });

  setUp(() async {
    await Hive.box<String>('roomcraft_data').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await testDirectory.delete(recursive: true);
  });

  testWidgets('Roomcraft dashboard loads', (tester) async {
    await openCreateProjectDialog(tester);

    // Pastikan dialog dapat dibuka dari dashboard.
    expect(find.text('Project name'), findsOneWidget);
    expect(find.text('Room dimensions (cm)'), findsOneWidget);

    // Tutup dialog agar tes ini berakhir dalam keadaan bersih.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ROOMCRAFT'), findsOneWidget);
    expect(find.text('My projects'), findsOneWidget);
    expect(find.text('Your canvas awaits'), findsOneWidget);
  });

  testWidgets('Create project form opens', (tester) async {
    await openCreateProjectDialog(tester);

    expect(find.text('New room project'), findsOneWidget);
    expect(find.text('Project name'), findsOneWidget);
    expect(find.text('Room dimensions (cm)'), findsOneWidget);
  });

  testWidgets('New project opens its room workspace', (tester) async {
    await openCreateProjectDialog(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'My Bedroom',
    );

    final createButton = find.text('Create project');
    expect(createButton, findsOneWidget);

    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();

    // Beri kesempatan operasi penyimpanan asinkron selesai.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
    });

    // Proseskan pembaruan UI dan animasi navigasi.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tunggu halaman editor dan data proyek yang diharapkan.
    await pumpUntilText(tester, 'ROOM DESIGN WORKSPACE');
    await pumpUntilText(tester, 'My Bedroom');
    await pumpUntilText(tester, '300 × 400 cm');

    expect(find.text('ROOM DESIGN WORKSPACE'), findsOneWidget);
    expect(find.text('My Bedroom'), findsOneWidget);
    expect(find.text('300 × 400 cm'), findsOneWidget);
  });
}
