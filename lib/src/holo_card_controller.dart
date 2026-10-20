import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Programmatic control of a `HoloCard`.
///
/// Create one, pass it to `HoloCard.controller` and call its methods. The
/// controller is a [ChangeNotifier]; call [dispose] when you are done with it.
///
/// Tilt values are *normalized*: each axis is in `-1..1`, where `Offset(1, 0)`
/// tilts the card fully toward the right edge and `Offset(0, 1)` toward the
/// bottom edge. Real rotation is this value times `HoloCard.maxTiltAngle`.
///
/// Real pointer or gyroscope input always takes over from a programmatic tilt;
/// when the user lets go, the card returns to [targetTilt] if one is set.
class HoloCardController extends ChangeNotifier {
  /// Creates a controller with no held tilt and no idle override.
  HoloCardController();

  Offset? _targetTilt;
  bool? _idleOverride;

  /// The tilt last requested with [tiltTo], or `null` when the card is free to
  /// rest at the center.
  Offset? get targetTilt => _targetTilt;

  /// `true` or `false` when idle animation was forced with [startIdle] or
  /// [stopIdle], `null` when `HoloCard.idleAnimation` decides.
  bool? get idleOverride => _idleOverride;

  /// Springs the card to [tilt] (normalized, clamped to `-1..1` per axis) and
  /// keeps it there until [reset] or user input.
  ///
  /// Holding a tilt pauses the idle animation.
  void tiltTo(Offset tilt) {
    _targetTilt = Offset(tilt.dx.clamp(-1.0, 1.0), tilt.dy.clamp(-1.0, 1.0));
    notifyListeners();
  }

  /// Clears any programmatic tilt and springs the card back to rest (or to its
  /// idle animation if that is enabled).
  void reset() {
    _targetTilt = null;
    notifyListeners();
  }

  /// Forces the idle animation on, even if `HoloCard.idleAnimation` is false.
  ///
  /// Still ignored when the platform asks for reduced motion.
  void startIdle() {
    _idleOverride = true;
    notifyListeners();
  }

  /// Forces the idle animation off, even if `HoloCard.idleAnimation` is true.
  void stopIdle() {
    _idleOverride = false;
    notifyListeners();
  }
}
