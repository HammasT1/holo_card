import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

import '../tilt_math.dart';
import 'tilt_source.dart';

/// One gyroscope reading: angular [rate] in radians per second (`dx` is the
/// rotation about the device's Y axis, `dy` about its X axis) and the time
/// [dt] in seconds since the previous reading.
typedef GyroSample = ({Offset rate, double dt});

/// Creates the stream of [GyroSample]s. Replaced in tests.
typedef GyroSampleStreamFactory = Stream<GyroSample> Function();

/// Whether this platform has a gyroscope this package will use: Android and
/// iOS, outside the browser.
bool get gyroscopeSupported =>
    debugGyroStreamFactory != null ||
    (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS));

/// Overrides the gyroscope stream (and the platform check) in tests.
@visibleForTesting
GyroSampleStreamFactory? debugGyroStreamFactory;

// Goes through the platform interface rather than importing `sensors_plus`
// directly: the plugin package only declares Android, iOS and web, which would
// make pub.dev list this package as unsupported on desktop. `sensors_plus`
// stays in pubspec.yaml so its native side is registered on mobile.
Stream<GyroSample> _sensorsPlusSamples() {
  DateTime? last;
  return SensorsPlatform.instance
      .gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
      .map(
    (event) {
      final dt = last == null
          ? 0.0
          : event.timestamp.difference(last!).inMicroseconds / 1e6;
      last = event.timestamp;
      return (rate: Offset(event.y, event.x), dt: dt);
    },
  );
}

/// Turns gyroscope angular velocity into a relative tilt.
///
/// Rotation rate is integrated into an angle that slowly leaks back to zero,
/// so the card follows how the device is being turned and settles when it is
/// held still. The result is low-pass filtered to hide sensor noise.
class GyroscopeTiltSource extends ValueNotifier<Offset?> implements TiltSource {
  /// Creates a source. Call [start] to begin listening.
  GyroscopeTiltSource({
    GyroSampleStreamFactory? streamFactory,
    this.fullTiltRadians = 0.5,
    this.leakSeconds = 1.2,
    this.smoothingSeconds = 0.05,
    this.deadZone = 0.015,
  })  : _streamFactory =
            streamFactory ?? debugGyroStreamFactory ?? _sensorsPlusSamples,
        super(null);

  final GyroSampleStreamFactory _streamFactory;

  /// Device rotation, in radians, that maps to a full (`1.0`) tilt.
  final double fullTiltRadians;

  /// Time constant for the angle leaking back toward zero.
  final double leakSeconds;

  /// Time constant of the low-pass filter applied to the output.
  final double smoothingSeconds;

  /// Tilt magnitude below which the source reports itself inactive.
  final double deadZone;

  StreamSubscription<GyroSample>? _subscription;
  Offset _angle = Offset.zero;
  Offset _filtered = Offset.zero;

  /// Starts listening to the gyroscope. Errors (no sensor, permission denied)
  /// are swallowed and leave the source inactive.
  void start() {
    if (_subscription != null) return;
    try {
      _subscription = _streamFactory().listen(
        (sample) => addSample(sample.rate, sample.dt),
        onError: (Object _) => _deactivate(),
        cancelOnError: false,
      );
    } catch (_) {
      _deactivate();
    }
  }

  /// Stops listening and marks the source inactive.
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    _deactivate();
  }

  /// Feeds one reading. Public so tests can drive the filter directly.
  @visibleForTesting
  void addSample(Offset rate, double dt) {
    if (dt <= 0 || dt > 0.5) return;
    final retained = lowPass(1, 0, dt, leakSeconds); // exp(-dt / leakSeconds)
    _angle = (_angle + rate * dt) * retained;
    final normalized = clampTilt(_angle / fullTiltRadians);
    _filtered = lowPassOffset(_filtered, normalized, dt, smoothingSeconds);
    value = _filtered.distance < deadZone ? null : _filtered;
  }

  void _deactivate() {
    _angle = Offset.zero;
    _filtered = Offset.zero;
    value = null;
  }

  @override
  void dispose() {
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
    super.dispose();
  }
}
