import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holo_card/src/tilt_math.dart';

void main() {
  group('tiltFromPosition', () {
    const size = Size(200, 100);

    test('center maps to zero', () {
      expect(tiltFromPosition(const Offset(100, 50), size), Offset.zero);
    });

    test('corners map to +-1', () {
      expect(tiltFromPosition(Offset.zero, size), const Offset(-1, -1));
      expect(
          tiltFromPosition(const Offset(200, 100), size), const Offset(1, 1));
    });

    test('clamps positions outside the box', () {
      expect(
          tiltFromPosition(const Offset(900, -900), size), const Offset(1, -1));
    });

    test('empty size gives zero', () {
      expect(tiltFromPosition(const Offset(5, 5), Size.zero), Offset.zero);
    });
  });

  test('clampTilt clamps each axis', () {
    expect(clampTilt(const Offset(3, -4)), const Offset(1, -1));
    expect(clampTilt(const Offset(0.2, -0.3)), const Offset(0.2, -0.3));
  });

  group('cardMatrix', () {
    test('zero tilt keeps identity apart from perspective', () {
      final m = cardMatrix(Offset.zero, 0.35, 0.0012);
      expect(m.entry(3, 2), 0.0012);
      expect(m.entry(0, 0), 1);
      expect(m.entry(1, 1), 1);
    });

    test('full horizontal tilt rotates around Y by maxTiltAngle', () {
      final m = cardMatrix(const Offset(1, 0), 0.4, 0);
      expect(m.entry(0, 0), closeTo(math.cos(0.4), 1e-9));
      // The right edge is pushed away from the viewer (+z, into the screen).
      expect(m.entry(2, 0), greaterThan(0));
    });

    test('full vertical tilt rotates around X by maxTiltAngle', () {
      final m = cardMatrix(const Offset(0, 1), 0.4, 0);
      expect(m.entry(1, 1), closeTo(math.cos(0.4), 1e-9));
      // The bottom edge is pushed away from the viewer.
      expect(m.entry(2, 1), greaterThan(0));
    });
  });

  group('lowPass', () {
    test('moves toward the input without overshooting', () {
      var v = 0.0;
      for (var i = 0; i < 10; i++) {
        final next = lowPass(v, 1, 1 / 60, 0.1);
        expect(next, greaterThan(v));
        expect(next, lessThan(1));
        v = next;
      }
    });

    test('is frame-rate independent', () {
      var a = 0.0;
      for (var i = 0; i < 60; i++) {
        a = lowPass(a, 1, 1 / 60, 0.2);
      }
      var b = 0.0;
      for (var i = 0; i < 120; i++) {
        b = lowPass(b, 1, 1 / 120, 0.2);
      }
      expect(a, closeTo(b, 1e-9));
      expect(a, closeTo(1 - math.exp(-1 / 0.2), 1e-9));
    });

    test('zero time constant returns the input, zero dt keeps the value', () {
      expect(lowPass(0.3, 1, 0.016, 0), 1);
      expect(lowPass(0.3, 1, 0, 0.1), 0.3);
    });

    test('offset variant filters both axes', () {
      final r = lowPassOffset(Offset.zero, const Offset(1, -1), 0.1, 0.1);
      expect(r.dx, greaterThan(0));
      expect(r.dy, lessThan(0));
      expect(r.dx, -r.dy);
    });
  });

  group('idleTilt', () {
    test('starts exactly at rest', () {
      expect(idleTilt(0), Offset.zero);
    });

    test('stays within the amplitude', () {
      for (var t = 0.0; t < 30; t += 0.1) {
        final v = idleTilt(t, amplitude: 0.5);
        expect(v.dx.abs(), lessThanOrEqualTo(0.5));
        expect(v.dy.abs(), lessThanOrEqualTo(0.5));
      }
    });

    test('is continuous across the ramp', () {
      final a = idleTilt(0.0);
      final b = idleTilt(0.01);
      expect((a - b).distance, lessThan(0.01));
    });

    test('no ramp when rampSeconds is zero', () {
      expect(idleTilt(0.5, rampSeconds: 0).distance, greaterThan(0));
    });
  });

  group('TiltSpring', () {
    test('starts at the origin position and settles on the target', () {
      final spring = TiltSpring(
        from: const Offset(0.8, -0.6),
        velocity: Offset.zero,
        target: Offset.zero,
      );
      expect(spring.position(0), const Offset(0.8, -0.6));
      expect(spring.isDone(0), isFalse);
      expect(spring.isDone(10), isTrue);
      expect((spring.position(10)).distance, lessThan(0.01));
    });

    test('default spring overshoots slightly, critical one does not', () {
      var maxCrossing = 0.0;
      final under = TiltSpring(
        from: const Offset(1, 0),
        velocity: Offset.zero,
        target: Offset.zero,
      );
      for (var t = 0.0; t < 3; t += 0.01) {
        maxCrossing = math.min(maxCrossing, under.position(t).dx);
      }
      expect(maxCrossing, lessThan(0));

      final critical = TiltSpring(
        from: const Offset(1, 0),
        velocity: Offset.zero,
        target: Offset.zero,
        description: TiltSpring.criticalDescription,
      );
      for (var t = 0.0; t < 3; t += 0.01) {
        expect(critical.position(t).dx, greaterThanOrEqualTo(-1e-6));
      }
    });

    test('initial velocity is respected', () {
      final spring = TiltSpring(
        from: Offset.zero,
        velocity: const Offset(2, 0),
        target: Offset.zero,
      );
      expect(spring.velocity(0).dx, closeTo(2, 1e-9));
      expect(spring.position(0.05).dx, greaterThan(0));
    });
  });
}
