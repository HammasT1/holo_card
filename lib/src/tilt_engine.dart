import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'input/tilt_source.dart';
import 'tilt_math.dart';

/// What the effect layers draw each frame: the current normalized [tilt] and
/// the shimmer [time] in seconds.
@immutable
class HoloFrame {
  /// Creates a frame.
  const HoloFrame(this.tilt, this.time);

  /// A frame at rest.
  static const HoloFrame rest = HoloFrame(Offset.zero, 0);

  /// Normalized tilt, each axis in `-1..1`.
  final Offset tilt;

  /// Seconds of shimmer time (already scaled by the effect's shimmer speed).
  final double time;

  @override
  bool operator ==(Object other) =>
      other is HoloFrame && other.tilt == tilt && other.time == time;

  @override
  int get hashCode => Object.hash(tilt, time);
}

enum _Phase { rest, following, springing, idle }

/// The state machine behind a `HoloCard`'s motion.
///
/// While a [TiltSource] is active the tilt follows it through a low-pass
/// filter. When input ends a spring returns it to rest (or to a held target
/// from the controller), after which the idle animation takes over if enabled.
///
/// It is driven by calling [step] from a ticker and publishes into [frame], so
/// no widget needs to rebuild per frame.
class TiltEngine {
  /// Creates an engine that polls [sources] in priority order.
  ///
  /// [onWake] is called whenever something changed that may need [step] to run
  /// again (a source became active, a setting changed).
  TiltEngine({
    List<TiltSource> sources = const [],
    this.onWake,
    this.followSeconds = 0.05,
  }) : _sources = List<TiltSource>.of(sources) {
    for (final source in _sources) {
      source.addListener(_wake);
    }
  }

  final List<TiltSource> _sources;

  /// Called when [step] should be scheduled.
  final VoidCallback? onWake;

  /// Low-pass time constant used while following input.
  final double followSeconds;

  /// Receives the current [HoloFrame] after every [step].
  final ValueNotifier<HoloFrame> frame = ValueNotifier(HoloFrame.rest);

  _Phase _phase = _Phase.rest;
  Offset _tilt = Offset.zero;
  Offset _velocity = Offset.zero;
  double _time = 0;
  double _phaseTime = 0;
  TiltSpring? _spring;

  bool _idleEnabled = false;
  bool _reducedMotion = false;
  double _shimmerSpeed = 1;
  Offset? _holdTarget;

  /// Current normalized tilt.
  Offset get tilt => _tilt;

  /// Whether the idle animation may run.
  set idleEnabled(bool value) {
    if (_idleEnabled == value) return;
    _idleEnabled = value;
    _wake();
  }

  /// Reduced motion: frozen shimmer and a spring without overshoot.
  set reducedMotion(bool value) {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    _wake();
  }

  /// Multiplier for the shimmer clock.
  set shimmerSpeed(double value) => _shimmerSpeed = value;

  /// Tilt to rest at instead of the center, or `null`.
  set holdTarget(Offset? value) {
    if (_holdTarget == value) return;
    _holdTarget = value;
    _wake();
  }

  bool get _wantsIdle => _idleEnabled && !_reducedMotion && _holdTarget == null;

  Offset? get _input {
    for (final source in _sources) {
      final value = source.value;
      if (value != null) return clampTilt(value);
    }
    return null;
  }

  /// Whether [step] still has work to do. When `false` the ticker can stop.
  bool get isActive {
    if (_input != null) return true;
    switch (_phase) {
      case _Phase.following:
      case _Phase.springing:
      case _Phase.idle:
        return true;
      case _Phase.rest:
        return _wantsIdle || (_restTarget - _tilt).distance > _epsilon;
    }
  }

  static const double _epsilon = 1e-4;

  Offset get _restTarget => _holdTarget ?? Offset.zero;

  void _wake() => onWake?.call();

  void _startSpring() {
    _spring = TiltSpring(
      from: _tilt,
      velocity: _velocity,
      target: _restTarget,
      description: _reducedMotion
          ? TiltSpring.criticalDescription
          : TiltSpring.defaultDescription,
    );
    _phase = _Phase.springing;
    _phaseTime = 0;
  }

  /// Advances the simulation by [dt] seconds and publishes a new [frame].
  void step(double dt) {
    final input = _input;
    if (input != null) {
      _phase = _Phase.following;
      final next = lowPassOffset(_tilt, input, dt, followSeconds);
      _velocity = dt > 0 ? (next - _tilt) / dt : Offset.zero;
      _tilt = next;
    } else {
      switch (_phase) {
        case _Phase.following:
          _startSpring();
        case _Phase.springing:
          _phaseTime += dt;
          final spring = _spring!;
          _tilt = spring.position(_phaseTime);
          _velocity = spring.velocity(_phaseTime);
          if (spring.isDone(_phaseTime)) {
            _tilt = spring.target;
            _velocity = Offset.zero;
            _spring = null;
            _phase = _Phase.rest;
          }
        case _Phase.idle:
          if (_wantsIdle) {
            _phaseTime += dt;
            final next = idleTilt(_phaseTime);
            _velocity = dt > 0 ? (next - _tilt) / dt : Offset.zero;
            _tilt = next;
          } else {
            _startSpring();
          }
        case _Phase.rest:
          if ((_restTarget - _tilt).distance > _epsilon) {
            _startSpring();
          } else if (_wantsIdle) {
            _phase = _Phase.idle;
            _phaseTime = 0;
          }
      }
    }

    if (!_reducedMotion && _phase != _Phase.rest) {
      _time += dt * _shimmerSpeed;
    }
    frame.value = HoloFrame(_tilt, _time);
  }

  /// Adds a lowest-priority input source.
  void addSource(TiltSource source) {
    _sources.add(source);
    source.addListener(_wake);
    _wake();
  }

  /// Removes a source added earlier.
  void removeSource(TiltSource source) {
    if (_sources.remove(source)) source.removeListener(_wake);
    _wake();
  }

  /// Stops listening to the sources and disposes [frame].
  void dispose() {
    for (final source in _sources) {
      source.removeListener(_wake);
    }
    frame.dispose();
  }
}
