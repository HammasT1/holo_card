import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

/// The maximum number of colors a [HoloEffect] can use.
///
/// Extra colors passed to [HoloEffect.custom] are ignored.
const int kMaxHoloColors = 6;

/// A holographic foil look: a color palette plus band density, shimmer speed,
/// sparkle amount and the blend mode used to composite the foil on the card.
///
/// Use one of the presets ([rainbow], [galaxy], [gold], [chrome], [aurora]) or
/// build your own with [HoloEffect.custom].
@immutable
class HoloEffect {
  /// Creates a custom effect.
  ///
  /// [colors] needs at least two entries; only the first [kMaxHoloColors] are
  /// used. [bandDensity] is roughly how many color bands cross the card
  /// diagonal, and [shimmerSpeed] scales how fast the foil drifts and sparkles
  /// over time (`0` freezes it, leaving only the tilt-driven motion).
  HoloEffect.custom({
    required List<Color> colors,
    this.bandDensity = 3.0,
    this.shimmerSpeed = 1.0,
    this.sparkle = 0.5,
    this.blendMode = BlendMode.overlay,
    this.name = 'custom',
  })  : assert(colors.length >= 2, 'A HoloEffect needs at least two colors.'),
        assert(bandDensity > 0, 'bandDensity must be positive.'),
        assert(shimmerSpeed >= 0, 'shimmerSpeed must not be negative.'),
        assert(sparkle >= 0 && sparkle <= 1, 'sparkle must be in 0..1.'),
        colors = List<Color>.unmodifiable(colors.take(kMaxHoloColors));

  const HoloEffect._preset({
    required this.name,
    required this.colors,
    required this.bandDensity,
    required this.shimmerSpeed,
    required this.sparkle,
    required this.blendMode,
  });

  /// A short human readable name, handy for pickers.
  final String name;

  /// The palette the foil cycles through (2 to [kMaxHoloColors] colors).
  final List<Color> colors;

  /// Approximate number of color bands across the card diagonal.
  final double bandDensity;

  /// Multiplier for the time-driven foil drift and sparkle twinkle.
  final double shimmerSpeed;

  /// Strength of the sparkle layer, from `0` (none) to `1`.
  final double sparkle;

  /// How the foil is composited over the card content.
  final BlendMode blendMode;

  /// Full-spectrum rainbow foil.
  static const HoloEffect rainbow = HoloEffect._preset(
    name: 'Rainbow',
    colors: [
      Color(0xFFFF4D6D),
      Color(0xFFFFC145),
      Color(0xFF7CF29C),
      Color(0xFF3DD6FF),
      Color(0xFF8A6BFF),
      Color(0xFFFF5FD2),
    ],
    bandDensity: 3.2,
    shimmerSpeed: 1.0,
    sparkle: 0.45,
    blendMode: BlendMode.screen,
  );

  /// Deep blues and purples with bright pink and cyan flecks.
  static const HoloEffect galaxy = HoloEffect._preset(
    name: 'Galaxy',
    colors: [
      Color(0xFF3B1E8F),
      Color(0xFF7B2FF7),
      Color(0xFFFF4FD8),
      Color(0xFF22D3EE),
      Color(0xFF1B2A8A),
    ],
    bandDensity: 2.4,
    shimmerSpeed: 0.8,
    sparkle: 0.9,
    blendMode: BlendMode.hardLight,
  );

  /// Warm metallic gold.
  static const HoloEffect gold = HoloEffect._preset(
    name: 'Gold',
    colors: [
      Color(0xFFFFE08A),
      Color(0xFFE6A82B),
      Color(0xFFFFF3C4),
      Color(0xFFB9791A),
    ],
    bandDensity: 2.6,
    shimmerSpeed: 0.6,
    sparkle: 0.35,
    blendMode: BlendMode.softLight,
  );

  /// Cool brushed-steel chrome.
  static const HoloEffect chrome = HoloEffect._preset(
    name: 'Chrome',
    colors: [
      Color(0xFFF2F6FA),
      Color(0xFF8E9BAA),
      Color(0xFFFFFFFF),
      Color(0xFF55606E),
      Color(0xFFBFD4E8),
    ],
    bandDensity: 3.6,
    shimmerSpeed: 0.5,
    sparkle: 0.25,
    blendMode: BlendMode.softLight,
  );

  /// Soft green, teal and violet northern-lights ribbons.
  static const HoloEffect aurora = HoloEffect._preset(
    name: 'Aurora',
    colors: [
      Color(0xFF2CFFB0),
      Color(0xFF22C7E8),
      Color(0xFF7A5CFF),
      Color(0xFFC86BFF),
      Color(0xFF3AF2C8),
    ],
    bandDensity: 2.0,
    shimmerSpeed: 1.2,
    sparkle: 0.4,
    blendMode: BlendMode.screen,
  );

  /// All built-in presets, in display order.
  static const List<HoloEffect> presets = [
    rainbow,
    galaxy,
    gold,
    chrome,
    aurora
  ];

  @override
  bool operator ==(Object other) =>
      other is HoloEffect &&
      other.name == name &&
      listEquals(other.colors, colors) &&
      other.bandDensity == bandDensity &&
      other.shimmerSpeed == shimmerSpeed &&
      other.sparkle == sparkle &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(colors),
        bandDensity,
        shimmerSpeed,
        sparkle,
        blendMode,
      );

  @override
  String toString() => 'HoloEffect($name)';
}
