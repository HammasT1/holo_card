import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Clamps both axes of [tilt] to `-1..1`.
Offset clampTilt(Offset tilt) =>
    Offset(tilt.dx.clamp(-1.0, 1.0), tilt.dy.clamp(-1.0, 1.0));

/// Converts a [position] inside a box of [size] to a normalized tilt in
/// `-1..1` per axis, with `Offset.zero` at the center of the box.
Offset tiltFromPosition(Offset position, Size size) {
  if (size.isEmpty) return Offset.zero;
  return clampTilt(Offset(
    (position.dx / size.width - 0.5) * 2,
    (position.dy / size.height - 0.5) * 2,
  ));
}

/// Builds the card transform: perspective plus a rotation around the Y axis
/// for horizontal tilt and around the X axis for vertical tilt.
///
/// Moving the pointer toward the right edge pushes that edge away from the
/// viewer, as if pressing on the card.
Matrix4 cardMatrix(Offset tilt, double maxTiltAngle, double perspective) {
  return Matrix4.identity()
    ..setEntry(3, 2, perspective)
    ..rotateX(tilt.dy * maxTiltAngle)
    ..rotateY(-tilt.dx * maxTiltAngle);
}

/// Exponential low-pass filter step.
///
/// Moves [previous] toward [input] with time constant [timeConstant] seconds,
/// independent of the frame rate. A zero time constant returns [input].
double lowPass(
  double previous,
  double input,
  double dt,
  double timeConstant,
) {
  if (timeConstant <= 0 || dt <= 0) return timeConstant <= 0 ? input : previous;
  final alpha = 1 - math.exp(-dt / timeConstant);
  return previous + (input - previous) * alpha;
}

/// [lowPass] applied to both axes of an [Offset].
Offset lowPassOffset(
  Offset previous,
  Offset input,
  double dt,
  double timeConstant,
) =>
    Offset(
      lowPass(previous.dx, input.dx, dt, timeConstant),
      lowPass(previous.dy, input.dy, dt, timeConstant),
    );

/// The gentle automatic tilt used by the idle animation.
///
/// A slow Lissajous figure of the given [amplitude] (in normalized tilt units).
/// The motion eases in over [rampSeconds] so that it starts exactly at rest.
Offset idleTilt(
  double seconds, {
  double amplitude = 0.55,
  double rampSeconds = 1.5,
}) {
  final ramp = rampSeconds <= 0
      ? 1.0
      : Curves.easeInOut.transform((seconds / rampSeconds).clamp(0.0, 1.0));
  return Offset(
    math.sin(seconds * 0.9) * amplitude * ramp,
    math.sin(seconds * 0.7 + 1.1) * amplitude * 0.8 * ramp,
  );
}

/// A two-axis spring that returns the tilt to a target.
///
/// Wraps a pair of [SpringSimulation]s that start from a position and velocity
/// at time zero and settle on [target].
@immutable
class TiltSpring {
  /// Creates a spring from [from] with initial [velocity] toward [target].
  TiltSpring({
    required Offset from,
    required Offset velocity,
    required this.target,
    SpringDescription? description,
  })  : _x = SpringSimulation(
          description ?? defaultDescription,
          from.dx,
          target.dx,
          velocity.dx,
        ),
        _y = SpringSimulation(
          description ?? defaultDescription,
          from.dy,
          target.dy,
          velocity.dy,
        );

  /// A lightly under-damped spring: a small, natural overshoot.
  static final SpringDescription defaultDescription =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 160,
    ratio: 0.55,
  );

  /// A critically damped spring: settles with no overshoot. Used for reduced
  /// motion.
  static final SpringDescription criticalDescription =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 160,
    ratio: 1,
  );

  final SpringSimulation _x;
  final SpringSimulation _y;

  /// Where the spring settles.
  final Offset target;

  /// Position after [seconds] have elapsed.
  Offset position(double seconds) => Offset(_x.x(seconds), _y.x(seconds));

  /// Velocity (normalized tilt units per second) after [seconds].
  Offset velocity(double seconds) => Offset(_x.dx(seconds), _y.dx(seconds));

  /// Whether both axes have come to rest at [seconds].
  bool isDone(double seconds) => _x.isDone(seconds) && _y.isDone(seconds);
}
