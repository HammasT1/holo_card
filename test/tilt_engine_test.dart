import 'package:flutter_test/flutter_test.dart';
import 'package:holo_card/src/input/tilt_source.dart';
import 'package:holo_card/src/tilt_engine.dart';

const _dt = 1 / 60;

void _run(TiltEngine engine, double seconds) {
  for (var t = 0.0; t < seconds; t += _dt) {
    engine.step(_dt);
  }
}

void main() {
  late ManualTiltSource pointer;
  late TiltEngine engine;
  late int wakes;

  setUp(() {
    wakes = 0;
    pointer = ManualTiltSource();
    engine = TiltEngine(sources: [pointer], onWake: () => wakes++);
  });

  tearDown(() {
    engine.dispose();
    pointer.dispose();
  });

  test('is idle and at rest initially', () {
    expect(engine.isActive, isFalse);
    engine.step(_dt);
    expect(engine.frame.value, HoloFrame.rest);
  });

  test('follows an active source and wakes on change', () {
    pointer.value = const Offset(1, 0);
    expect(wakes, 1);
    expect(engine.isActive, isTrue);
    _run(engine, 1);
    expect(engine.tilt.dx, closeTo(1, 0.01));
    expect(engine.tilt.dy, closeTo(0, 1e-9));
  });

  test('clamps out of range input', () {
    pointer.value = const Offset(5, -5);
    _run(engine, 1);
    expect(engine.tilt.dx, lessThanOrEqualTo(1));
    expect(engine.tilt.dy, greaterThanOrEqualTo(-1));
  });

  test('springs back to rest after release and then goes inactive', () {
    pointer.value = const Offset(1, 1);
    _run(engine, 0.5);
    pointer.release();
    expect(engine.isActive, isTrue);
    _run(engine, 5);
    expect(engine.tilt.distance, lessThan(1e-3));
    expect(engine.isActive, isFalse);
  });

  test('spring return is smooth: no jump on release', () {
    pointer.value = const Offset(1, 0);
    _run(engine, 0.5);
    final before = engine.tilt;
    pointer.release();
    engine.step(_dt);
    expect((engine.tilt - before).distance, lessThan(0.1));
  });

  test('higher priority source wins', () {
    final gyro = ManualTiltSource();
    final e = TiltEngine(sources: [pointer, gyro]);
    gyro.value = const Offset(-1, 0);
    for (var i = 0; i < 60; i++) {
      e.step(_dt);
    }
    expect(e.tilt.dx, lessThan(-0.9));
    pointer.value = const Offset(1, 0);
    for (var i = 0; i < 120; i++) {
      e.step(_dt);
    }
    expect(e.tilt.dx, greaterThan(0.9));
    e.dispose();
    gyro.dispose();
  });

  test('sources can be added and removed at runtime', () {
    final extra = ManualTiltSource();
    engine.addSource(extra);
    extra.value = const Offset(0, 1);
    _run(engine, 1);
    expect(engine.tilt.dy, closeTo(1, 0.01));
    engine.removeSource(extra);
    final before = wakes;
    extra.value = const Offset(0, -1); // no longer listened to
    expect(wakes, before);
    extra.dispose();
  });

  group('hold target', () {
    test('springs to the target and stays', () {
      engine.holdTarget = const Offset(0.5, -0.5);
      expect(engine.isActive, isTrue);
      _run(engine, 5);
      expect(engine.tilt.dx, closeTo(0.5, 1e-3));
      expect(engine.tilt.dy, closeTo(-0.5, 1e-3));
      expect(engine.isActive, isFalse);
    });

    test('pointer overrides and then returns to the target', () {
      engine.holdTarget = const Offset(0.5, 0);
      _run(engine, 3);
      pointer.value = const Offset(-1, 0);
      _run(engine, 1);
      expect(engine.tilt.dx, lessThan(-0.9));
      pointer.release();
      _run(engine, 5);
      expect(engine.tilt.dx, closeTo(0.5, 1e-3));
    });

    test('clearing the target returns to center', () {
      engine.holdTarget = const Offset(0.5, 0.5);
      _run(engine, 3);
      engine.holdTarget = null;
      _run(engine, 5);
      expect(engine.tilt.distance, lessThan(1e-3));
    });

    test('setting the same target again does not wake', () {
      engine.holdTarget = const Offset(0.2, 0.2);
      final n = wakes;
      engine.holdTarget = const Offset(0.2, 0.2);
      expect(wakes, n);
    });
  });

  group('idle animation', () {
    test('sways on its own and stays active', () {
      engine.idleEnabled = true;
      expect(engine.isActive, isTrue);
      _run(engine, 4);
      expect(engine.tilt.distance, greaterThan(0.05));
      expect(engine.isActive, isTrue);
    });

    test('stopping returns the card to rest', () {
      engine.idleEnabled = true;
      _run(engine, 4);
      engine.idleEnabled = false;
      _run(engine, 5);
      expect(engine.tilt.distance, lessThan(1e-3));
      expect(engine.isActive, isFalse);
    });

    test('is suppressed by reduced motion', () {
      engine
        ..reducedMotion = true
        ..idleEnabled = true;
      expect(engine.isActive, isFalse);
      _run(engine, 2);
      expect(engine.tilt, Offset.zero);
    });

    test('is suppressed while a target is held', () {
      engine
        ..idleEnabled = true
        ..holdTarget = const Offset(0.3, 0.3);
      _run(engine, 5);
      expect(engine.tilt.dx, closeTo(0.3, 1e-3));
      expect(engine.tilt.dy, closeTo(0.3, 1e-3));
    });

    test('a pointer interrupts idle without a jump', () {
      engine.idleEnabled = true;
      _run(engine, 4);
      final before = engine.tilt;
      pointer.value = const Offset(1, 1);
      engine.step(_dt);
      final gap = (const Offset(1, 1) - before).distance;
      // Filtered: covers only part of the gap in one frame.
      expect((engine.tilt - before).distance, lessThan(gap * 0.5));
    });
  });

  group('shimmer time', () {
    test('advances while moving, scaled by speed, and freezes at rest', () {
      engine.shimmerSpeed = 2;
      pointer.value = const Offset(1, 0);
      _run(engine, 1);
      expect(engine.frame.value.time, closeTo(2, 0.1));
      pointer.release();
      _run(engine, 6);
      final frozen = engine.frame.value.time;
      _run(engine, 1);
      expect(engine.frame.value.time, frozen);
    });

    test('is frozen by reduced motion', () {
      engine.reducedMotion = true;
      pointer.value = const Offset(1, 0);
      _run(engine, 1);
      expect(engine.frame.value.time, 0);
    });
  });

  test('reduced motion settles without overshoot', () {
    engine.reducedMotion = true;
    pointer.value = const Offset(1, 0);
    _run(engine, 1);
    pointer.release();
    for (var t = 0.0; t < 3; t += _dt) {
      engine.step(_dt);
      expect(engine.tilt.dx, greaterThanOrEqualTo(-1e-3));
    }
  });

  test('HoloFrame has value equality', () {
    expect(const HoloFrame(Offset(1, 2), 3), const HoloFrame(Offset(1, 2), 3));
    expect(const HoloFrame(Offset(1, 2), 3).hashCode,
        const HoloFrame(Offset(1, 2), 3).hashCode);
    expect(const HoloFrame(Offset(1, 2), 3) == const HoloFrame(Offset(1, 2), 4),
        isFalse);
  });
}
