import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:holo_card/holo_card.dart';
import 'package:holo_card_example/main.dart';

void main() {
  testWidgets('gallery renders cards and controls', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HoloGalleryApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HoloCard), findsWidgets);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Effect'), findsOneWidget);
  });
}
