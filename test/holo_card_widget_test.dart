import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holo_card/holo_card.dart';
import 'package:holo_card/src/foil_shader.dart';
import 'package:holo_card/src/input/gyroscope_tilt_source.dart';
import 'package:holo_card/src/painters.dart';

const _cardKey = Key('card');

/// A widget test that runs on a desktop platform (so the gyroscope is off
/// unless a test opts in) and always restores the platform override.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// Pumps [seconds] of 60 fps frames. One large pump would be a single frame,
/// which the engine deliberately clamps to 50 ms.
Future<void> _run(WidgetTester tester, num seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Widget _app(
  Widget card, {
  bool reducedMotion = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 420, child: card),
        ),
      ),
    ),
  );
}

Widget _content({VoidCallback? onTap}) => Container(
      key: _cardKey,
      color: Colors.indigo,
      child: Center(
        child: TextButton(
          onPressed: onTap,
          child: const Text('Tap me'),
        ),
      ),
    );

CustomPaint _layer(WidgetTester tester, String key) =>
    tester.widget<CustomPaint>(
      find.byKey(ValueKey(key)),
    );

void main() {
  setUp(() {
    FoilShader.resetForTesting();
    // Default to the fallback so tests do not depend on shader support in the
    // test engine; the shader path has its own test.
    FoilShader.loader = () => Future.error(UnsupportedError('no shader'));
  });

  tearDown(() {
    debugGyroStreamFactory = null;
    FoilShader.resetForTesting();
  });

  _test('renders the child and the effect layers', (tester) async {
    await tester.pumpWidget(_app(HoloCard(child: _content())));
    expect(find.byKey(_cardKey), findsOneWidget);
    expect(find.text('Tap me'), findsOneWidget);
    expect(find.byKey(const ValueKey('holo_foil')), findsOneWidget);
    expect(find.byKey(const ValueKey('holo_glare')), findsOneWidget);
    expect(find.byKey(const ValueKey('holo_shadow')), findsOneWidget);
  });

  _test('shadow can be turned off', (tester) async {
    await tester.pumpWidget(_app(HoloCard(shadow: false, child: _content())));
    expect(find.byKey(const ValueKey('holo_shadow')), findsNothing);
  });

  _test('does not rebuild the child while tilting', (tester) async {
    var builds = 0;
    final child = Builder(builder: (context) {
      builds++;
      return const SizedBox.expand();
    });
    await tester.pumpWidget(_app(HoloCard(idleAnimation: false, child: child)));
    final initial = builds;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
        tester.getCenter(find.byType(HoloCard)) + const Offset(100, 50));
    for (var i = 0; i < 20; i++) {
      await _run(tester, 0.016);
    }
    expect(builds, initial);
    await mouse.removePointer();
  });

  group('pointer', () {
    _test('hover tilts toward the pointer and reports tilt', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      final box = tester.getRect(find.byType(HoloCard));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(box.centerRight - const Offset(2, 0));
      for (var i = 0; i < 30; i++) {
        await _run(tester, 0.016);
      }
      expect(tilts, isNotEmpty);
      expect(tilts.last.dx, greaterThan(0.8));
      expect(tilts.last.dy.abs(), lessThan(0.1));

      // The card is actually rotated.
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(HoloCard),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.entry(2, 0), isNot(0));

      await mouse.removePointer();
    });

    _test('leaving the card springs back to rest', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      final box = tester.getRect(find.byType(HoloCard));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(box.bottomRight - const Offset(2, 2));
      await _run(tester, 0.3);
      expect(tilts.last.distance, greaterThan(0.5));
      await mouse.moveTo(const Offset(1, 1)); // exits the card
      await tester.pump(); // exit handled
      await _run(tester, 4);
      expect(tilts.last.distance, lessThan(0.01));
      await mouse.removePointer();
    });

    _test('touch drag tilts and release springs back', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      final box = tester.getRect(find.byType(HoloCard));
      final gesture =
          await tester.startGesture(box.topLeft + const Offset(10, 10));
      await _run(tester, 0.3);
      expect(tilts.last.dx, lessThan(-0.5));
      expect(tilts.last.dy, lessThan(-0.5));
      await gesture.up();
      await _run(tester, 4);
      expect(tilts.last.distance, lessThan(0.01));
    });

    _test('a cancelled touch releases', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      final box = tester.getRect(find.byType(HoloCard));
      final gesture =
          await tester.startGesture(box.bottomRight - const Offset(5, 5));
      await _run(tester, 0.3);
      await gesture.cancel();
      await _run(tester, 4);
      expect(tilts.last.distance, lessThan(0.01));
    });

    _test('enablePointer: false ignores the pointer', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        enablePointer: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getRect(find.byType(HoloCard)).centerRight -
          const Offset(2, 0));
      await _run(tester, 0.3);
      expect(tilts, isEmpty);
      await mouse.removePointer();
    });

    _test('disabling the pointer while hovering releases it', (tester) async {
      final tilts = <Offset>[];
      Widget build(bool enabled) => _app(HoloCard(
            idleAnimation: false,
            enablePointer: enabled,
            onTiltChanged: tilts.add,
            child: _content(),
          ));
      await tester.pumpWidget(build(true));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getRect(find.byType(HoloCard)).centerRight -
          const Offset(2, 0));
      await _run(tester, 0.3);
      expect(tilts.last.dx, greaterThan(0.5));
      await tester.pumpWidget(build(false));
      await _run(tester, 4);
      expect(tilts.last.distance, lessThan(0.01));
      await mouse.removePointer();
    });
  });

  _test('taps on a button inside the card still work', (tester) async {
    var taps = 0;
    await tester
        .pumpWidget(_app(HoloCard(child: _content(onTap: () => taps++))));
    await tester.tap(find.text('Tap me'));
    await tester.pump();
    expect(taps, 1);
    // Tilting did not break the next tap either.
    await tester.tap(find.text('Tap me'));
    expect(taps, 2);
    await _run(tester, 3);
  });

  _test('keeps the child semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(HoloCard(
      child: Semantics(
        label: 'Membership card for Sam',
        child: const SizedBox.expand(),
      ),
    )));
    expect(find.bySemanticsLabel('Membership card for Sam'), findsOneWidget);
    handle.dispose();
  });

  group('idle animation and reduced motion', () {
    _test('idle animation sways the card on its own', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      for (var i = 0; i < 180; i++) {
        await _run(tester, 0.016);
      }
      expect(tilts, isNotEmpty);
      expect(tilts.map((t) => t.distance).reduce((a, b) => a > b ? a : b),
          greaterThan(0.05));
    });

    _test('reduced motion disables the idle animation', (tester) async {
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(
        HoloCard(onTiltChanged: tilts.add, child: _content()),
        reducedMotion: true,
      ));
      for (var i = 0; i < 180; i++) {
        await _run(tester, 0.016);
      }
      expect(tilts, isEmpty);
      // And no ticker is left running.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    _test('reduced motion lowers the foil intensity', (tester) async {
      await tester.pumpWidget(_app(
        HoloCard(foilIntensity: 0.8, child: _content()),
      ));
      final normal =
          _layer(tester, 'holo_foil').painter! as HoloFoilFallbackPainter;
      await tester.pumpWidget(_app(
        HoloCard(foilIntensity: 0.8, child: _content()),
        reducedMotion: true,
      ));
      final reduced =
          _layer(tester, 'holo_foil').painter! as HoloFoilFallbackPainter;
      expect(reduced.intensity, lessThan(normal.intensity));
    });

    _test('reduced motion turns the gyroscope off', (tester) async {
      final controller = StreamController<GyroSample>.broadcast();
      debugGyroStreamFactory = () => controller.stream;
      await tester.pumpWidget(_app(
        HoloCard(child: _content()),
        reducedMotion: true,
      ));
      expect(controller.hasListener, isFalse);
      await controller.close();
    });
  });

  group('shader and fallback', () {
    _test('uses the gradient fallback when the shader fails to load',
        (tester) async {
      await tester.pumpWidget(_app(HoloCard(child: _content())));
      await tester.pump();
      expect(
        _layer(tester, 'holo_foil').painter,
        isA<HoloFoilFallbackPainter>(),
      );
      expect(tester.takeException(), isNull);
      // Painting the fallback at a tilt must not throw.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getRect(find.byType(HoloCard)).bottomRight);
      await _run(tester, 0.1);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    });

    _test('every preset paints with the fallback', (tester) async {
      for (final effect in HoloEffect.presets) {
        await tester.pumpWidget(_app(
          HoloCard(effect: effect, idleAnimation: false, child: _content()),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: effect.name);
      }
    });

    _test('the program is cached: loaded once', (tester) async {
      var loads = 0;
      FoilShader.loader = () {
        loads++;
        return Future.error(UnsupportedError('no shader'));
      };
      await tester.pumpWidget(_app(Column(children: [
        Expanded(child: HoloCard(child: _content())),
        Expanded(child: HoloCard(child: _content())),
      ])));
      await tester.pump();
      expect(loads, 1);
    });

    _test('switches to the shader painter once it loads', (tester) async {
      FoilShader.resetForTesting();
      FoilShader.loader =
          () => ui.FragmentProgram.fromAsset('shaders/holo_foil.frag');
      final program = await tester.runAsync(FoilShader.load);
      if (program == null) {
        markTestSkipped('FragmentProgram is unavailable in this test engine.');
        return;
      }
      await tester.pumpWidget(_app(HoloCard(child: _content())));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(
        _layer(tester, 'holo_foil').painter,
        isA<HoloFoilShaderPainter>(),
      );
      await _run(tester, 0.1);
      expect(tester.takeException(), isNull);
    });
  });

  group('controller', () {
    _test('tiltTo moves the card and reset returns it', (tester) async {
      final controller = HoloCardController();
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        controller: controller,
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      controller.tiltTo(const Offset(0.6, -0.4));
      await tester.pump();
      await _run(tester, 4);
      expect(tilts.last.dx, closeTo(0.6, 0.01));
      expect(tilts.last.dy, closeTo(-0.4, 0.01));

      controller.reset();
      await tester.pump();
      await _run(tester, 4);
      expect(tilts.last.distance, lessThan(0.01));
      controller.dispose();
    });

    _test('startIdle and stopIdle override idleAnimation', (tester) async {
      final controller = HoloCardController();
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        controller: controller,
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      await _run(tester, 3);
      expect(tilts, isEmpty);

      controller.startIdle();
      for (var i = 0; i < 180; i++) {
        await _run(tester, 0.016);
      }
      expect(tilts, isNotEmpty);

      controller.stopIdle();
      await tester.pump();
      await _run(tester, 5);
      expect(tilts.last.distance, lessThan(0.01));
      controller.dispose();
    });

    _test('swapping controllers rewires the listener', (tester) async {
      final a = HoloCardController();
      final b = HoloCardController();
      final tilts = <Offset>[];
      Widget build(HoloCardController? c) => _app(HoloCard(
            controller: c,
            idleAnimation: false,
            onTiltChanged: tilts.add,
            child: _content(),
          ));
      await tester.pumpWidget(build(a));
      await tester.pumpWidget(build(b));
      a.tiltTo(const Offset(1, 0)); // no longer attached
      await _run(tester, 2);
      expect(tilts, isEmpty);
      b.tiltTo(const Offset(1, 0));
      await tester.pump();
      await _run(tester, 3);
      expect(tilts.last.dx, closeTo(1, 0.01));
      a.dispose();
      b.dispose();
    });
  });

  group('gyroscope', () {
    _test('tilts from gyroscope samples and unsubscribes on dispose',
        (tester) async {
      final stream = StreamController<GyroSample>.broadcast();
      debugGyroStreamFactory = () => stream.stream;
      final tilts = <Offset>[];
      await tester.pumpWidget(_app(HoloCard(
        idleAnimation: false,
        onTiltChanged: tilts.add,
        child: _content(),
      )));
      expect(stream.hasListener, isTrue);
      for (var i = 0; i < 30; i++) {
        stream.add((rate: const Offset(1.2, 0), dt: 1 / 60));
        await _run(tester, 0.016);
      }
      expect(tilts, isNotEmpty);
      expect(tilts.last.dx, greaterThan(0.2));

      await tester.pumpWidget(const SizedBox());
      expect(stream.hasListener, isFalse);
      await stream.close();
    });

    _test('enableGyroscope can be toggled at runtime', (tester) async {
      final stream = StreamController<GyroSample>.broadcast();
      debugGyroStreamFactory = () => stream.stream;
      Widget build(bool on) => _app(HoloCard(
            enableGyroscope: on,
            idleAnimation: false,
            child: _content(),
          ));
      await tester.pumpWidget(build(false));
      expect(stream.hasListener, isFalse);
      await tester.pumpWidget(build(true));
      expect(stream.hasListener, isTrue);
      await tester.pumpWidget(build(false));
      expect(stream.hasListener, isFalse);
      await stream.close();
    });

    _test('a missing sensor on mobile never crashes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_app(HoloCard(child: _content())));
      await _run(tester, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    _test('is ignored on platforms without a gyroscope', (tester) async {
      // debugGyroStreamFactory is null and the test platform is not mobile.
      await tester.pumpWidget(_app(HoloCard(child: _content())));
      expect(gyroscopeSupported, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  _test('disposes cleanly while animating', (tester) async {
    final controller = HoloCardController();
    await tester.pumpWidget(_app(HoloCard(
      controller: controller,
      child: _content(),
    )));
    await _run(tester, 0.5);
    await tester.pumpWidget(const SizedBox());
    // No ticker or listener may fire after disposal.
    controller.tiltTo(const Offset(1, 1));
    await _run(tester, 1);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  _test('asserts on out of range intensities', (tester) async {
    expect(
      () => HoloCard(glareIntensity: 2, child: const SizedBox()),
      throwsAssertionError,
    );
    expect(
      () => HoloCard(foilIntensity: -1, child: const SizedBox()),
      throwsAssertionError,
    );
  });
}
