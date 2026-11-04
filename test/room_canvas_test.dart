import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/features/editor/room_canvas.dart';

void main() {
  testWidgets('Room canvas renders zoom controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: RoomCanvas(widthCm: 300, lengthCm: 400),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(find.text('Drag to move · Pinch to zoom'), findsOneWidget);
  });

  testWidgets('Room canvas supports another room size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: RoomCanvas(widthCm: 250, lengthCm: 350),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Room plan, 250 by 350 centimeters'),
      findsOneWidget,
    );
  });
  
    test('Jarak grid menyesuaikan tingkat zoom', () {
    final zoomedOut = RoomCanvasPainter.stepsFor(0.2);
    final zoomedIn = RoomCanvasPainter.stepsFor(4);

    expect(zoomedOut.minor, 50);
    expect(zoomedOut.major, 200);
    expect(zoomedIn.minor, 5);
    expect(zoomedIn.major, 10);
  });
}
