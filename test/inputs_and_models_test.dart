import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holo_card/holo_card.dart';
import 'package:holo_card/src/input/gyroscope_tilt_source.dart';
import 'package:holo_card/src/input/tilt_source.dart';

void main() {
  group('ManualTiltSource', () {
    test('notifies and releases', () {
      final source = ManualTiltSource();
      var calls = 0;
      source.addListener(() => calls++);
      source.value = const Offset(0.5, 0);
      expect(source.value, const Offset(0.5, 0));
      source.release();
      expect(source.value, isNull);
      expect(calls, 2);
      source.dispose();
    });
  });

  group('GyroscopeTiltSource', () {
    test('integrates rotation rate into a normalized tilt', () {
      final source = GyroscopeTiltSource();
      for (var i = 0; i < 20; i++) {
        source.addSample(const Offset(1, 0), 1 / 60);
      }
      expect(source.value, isNotNull);
      expect(source.value!.dx, greaterThan(0));
      expect(source.value!.dy, closeTo(0, 1e-9));
      source.dispose();
    });

    test('is clamped to a full tilt', () {
      final source = GyroscopeTiltSource();
      for (var i = 0; i < 600; i++) {
        source.addSample(const Offset(20, -20), 1 / 60);
      }
      expect(source.value!.dx, lessThanOrEqualTo(1));
      expect(source.value!.dy, greaterThanOrEqualTo(-1));
      source.dispose();
    });

    test('decays back to inactive when held still', () {
      final source = GyroscopeTiltSource();
      for (var i = 0; i < 20; i++) {
        source.addSample(const Offset(1, 0), 1 / 60);
      }
      for (var i = 0; i < 60 * 15; i++) {
        source.addSample(Offset.zero, 1 / 60);
      }
      expect(source.value, isNull);
      source.dispose();
    });

    test('ignores bad time steps', () {
      final source = GyroscopeTiltSource();
      source.addSample(const Offset(5, 5), 0);
      source.addSample(const Offset(5, 5), 2);
      expect(source.value, isNull);
      source.dispose();
    });

    test('low-pass smooths a sudden spike', () {
      final smooth = GyroscopeTiltSource(smoothingSeconds: 0.5);
      final raw = GyroscopeTiltSource(smoothingSeconds: 0);
      smooth.addSample(const Offset(3, 0), 1 / 60);
      raw.addSample(const Offset(3, 0), 1 / 60);
      expect((smooth.value?.dx ?? 0), lessThan(raw.value!.dx));
      smooth.dispose();
      raw.dispose();
    });

    test('subscribes on start, cancels on stop and dispose', () async {
      final controller = StreamController<GyroSample>.broadcast(sync: true);
      final source =
          GyroscopeTiltSource(streamFactory: () => controller.stream);
      source.start();
      source.start(); // idempotent
      expect(controller.hasListener, isTrue);
      for (var i = 0; i < 10; i++) {
        controller.add((rate: const Offset(1, 1), dt: 1 / 60));
      }
      expect(source.value, isNotNull);
      await source.stop();
      expect(controller.hasListener, isFalse);
      expect(source.value, isNull);

      source.start();
      expect(controller.hasListener, isTrue);
      source.dispose();
      expect(controller.hasListener, isFalse);
      await controller.close();
    });

    test('stream errors leave the source inactive', () {
      final controller = StreamController<GyroSample>(sync: true);
      final source =
          GyroscopeTiltSource(streamFactory: () => controller.stream);
      source.start();
      controller.addError(StateError('no sensor'));
      expect(source.value, isNull);
      source.dispose();
      controller.close();
    });

    test('a throwing stream factory is swallowed', () {
      final source = GyroscopeTiltSource(
        streamFactory: () => throw UnsupportedError('nope'),
      );
      expect(source.start, returnsNormally);
      expect(source.value, isNull);
      source.dispose();
    });
  });

  group('HoloCardController', () {
    test('tiltTo clamps, stores and notifies', () {
      final c = HoloCardController();
      var calls = 0;
      c.addListener(() => calls++);
      c.tiltTo(const Offset(3, -3));
      expect(c.targetTilt, const Offset(1, -1));
      expect(calls, 1);
      c.dispose();
    });

    test('reset clears the target', () {
      final c = HoloCardController()..tiltTo(const Offset(0.5, 0.5));
      var calls = 0;
      c.addListener(() => calls++);
      c.reset();
      expect(c.targetTilt, isNull);
      expect(calls, 1);
      c.dispose();
    });

    test('startIdle and stopIdle override the widget flag', () {
      final c = HoloCardController();
      expect(c.idleOverride, isNull);
      c.startIdle();
      expect(c.idleOverride, isTrue);
      c.stopIdle();
      expect(c.idleOverride, isFalse);
      c.dispose();
    });

    test('is disposable and rejects use afterwards', () {
      final c = HoloCardController()..dispose();
      expect(() => c.addListener(() {}), throwsFlutterError);
    });
  });

  group('HoloEffect', () {
    test('presets are available and valid', () {
      expect(HoloEffect.presets, hasLength(5));
      for (final e in HoloEffect.presets) {
        expect(e.colors.length, inInclusiveRange(2, kMaxHoloColors));
        expect(e.name, isNotEmpty);
        expect(e.bandDensity, greaterThan(0));
      }
    });

    test('custom keeps parameters and truncates extra colors', () {
      final e = HoloEffect.custom(
        colors: List.filled(9, const Color(0xFFFF0000)),
        bandDensity: 5,
        shimmerSpeed: 2,
        sparkle: 0.1,
        blendMode: BlendMode.screen,
      );
      expect(e.colors, hasLength(kMaxHoloColors));
      expect(e.bandDensity, 5);
      expect(e.shimmerSpeed, 2);
      expect(e.sparkle, 0.1);
      expect(e.blendMode, BlendMode.screen);
    });

    test('custom colors are unmodifiable', () {
      final e = HoloEffect.custom(
        colors: [const Color(0xFF000000), const Color(0xFFFFFFFF)],
      );
      expect(
          () => e.colors.add(const Color(0xFF123456)), throwsUnsupportedError);
    });

    test('asserts on invalid input', () {
      expect(
        () => HoloEffect.custom(colors: [const Color(0xFF000000)]),
        throwsAssertionError,
      );
      expect(
        () => HoloEffect.custom(
          colors: [const Color(0xFF000000), const Color(0xFFFFFFFF)],
          bandDensity: 0,
        ),
        throwsAssertionError,
      );
    });

    test('value equality and toString', () {
      HoloEffect make() => HoloEffect.custom(
            colors: [const Color(0xFF000000), const Color(0xFFFFFFFF)],
          );
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make() == HoloEffect.rainbow, isFalse);
      expect(HoloEffect.gold.toString(), 'HoloEffect(Gold)');
    });
  });
}
