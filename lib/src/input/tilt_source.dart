import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A source of normalized tilt input (each axis in `-1..1`).
///
/// The value is `null` while the source is inactive (for example the pointer
/// is not over the card). Sources are polled by the tilt engine, which uses the
/// first active source in priority order, so any number of them can be
/// combined.
abstract interface class TiltSource implements ValueListenable<Offset?> {
  /// Releases resources held by the source.
  void dispose();
}

/// A [TiltSource] driven by hand, used for pointer input.
class ManualTiltSource extends ValueNotifier<Offset?> implements TiltSource {
  /// Creates an inactive source.
  ManualTiltSource() : super(null);

  /// Marks the source inactive.
  void release() => value = null;
}
