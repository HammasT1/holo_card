import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'holo_effect.dart';
import 'tilt_engine.dart';

Color _withOpacity(Color color, double opacity) =>
    color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

/// Paints the card's drop shadow, which slides against the tilt.
class HoloShadowPainter extends CustomPainter {
  /// Creates a shadow painter repainting on [frame].
  HoloShadowPainter({
    required this.frame,
    required this.borderRadius,
    required this.reduced,
  }) : super(repaint: frame);

  /// Source of the current tilt.
  final ValueListenable<HoloFrame> frame;

  /// Corner radius of the card.
  final BorderRadius borderRadius;

  /// Whether to dampen the shadow motion.
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final tilt = frame.value.tilt;
    final shift = reduced ? 0.4 : 1.0;
    final offset = Offset(tilt.dx * 18 * shift, 14 + tilt.dy * 12 * shift);
    final rrect = borderRadius.toRRect(Offset.zero & size).shift(offset);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(HoloShadowPainter old) =>
      old.frame != frame ||
      old.borderRadius != borderRadius ||
      old.reduced != reduced;
}

/// Paints a soft radial highlight that follows the tilt.
class HoloGlarePainter extends CustomPainter {
  /// Creates a glare painter repainting on [frame].
  HoloGlarePainter({required this.frame, required this.intensity})
      : super(repaint: frame);

  /// Source of the current tilt.
  final ValueListenable<HoloFrame> frame;

  /// Glare strength, `0..1`.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;
    final tilt = frame.value.tilt;
    final center = Offset(
      size.width * (0.5 + tilt.dx * 0.5),
      size.height * (0.5 + tilt.dy * 0.5),
    );
    // Brighter the further the light is pushed from the middle.
    final strength = intensity * (0.4 + 0.6 * math.min(1.0, tilt.distance));
    final radius = size.longestSide * 0.85;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            _withOpacity(const Color(0xFFFFFFFF), 0.55 * strength),
            _withOpacity(const Color(0xFFFFFFFF), 0.18 * strength),
            const Color(0x00FFFFFF),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(HoloGlarePainter old) =>
      old.frame != frame || old.intensity != intensity;
}

/// Paints the holographic foil with the fragment shader.
class HoloFoilShaderPainter extends CustomPainter {
  /// Creates a shader foil painter repainting on [frame].
  HoloFoilShaderPainter({
    required this.frame,
    required this.program,
    required this.effect,
    required this.intensity,
  }) : super(repaint: frame);

  /// Source of the current tilt and shimmer time.
  final ValueListenable<HoloFrame> frame;

  /// The compiled foil program.
  final ui.FragmentProgram program;

  /// Palette, density and blend mode.
  final HoloEffect effect;

  /// Foil strength, `0..1`.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;
    final f = frame.value;
    final shader = program.fragmentShader();
    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, f.tilt.dx)
      ..setFloat(i++, f.tilt.dy)
      ..setFloat(i++, f.time)
      ..setFloat(i++, intensity)
      ..setFloat(i++, effect.bandDensity)
      ..setFloat(i++, effect.sparkle)
      ..setFloat(i++, effect.colors.length.clamp(2, kMaxHoloColors).toDouble());
    for (var c = 0; c < kMaxHoloColors; c++) {
      final color = effect.colors[math.min(c, effect.colors.length - 1)];
      shader
        ..setFloat(i++, color.r)
        ..setFloat(i++, color.g)
        ..setFloat(i++, color.b);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = effect.blendMode,
    );
  }

  @override
  bool shouldRepaint(HoloFoilShaderPainter old) =>
      old.frame != frame ||
      old.program != program ||
      old.effect != effect ||
      old.intensity != intensity;
}

/// Paints a tilt-driven animated gradient. Used when the shader is unavailable.
class HoloFoilFallbackPainter extends CustomPainter {
  /// Creates a fallback foil painter repainting on [frame].
  HoloFoilFallbackPainter({
    required this.frame,
    required this.effect,
    required this.intensity,
  }) : super(repaint: frame);

  /// Source of the current tilt and shimmer time.
  final ValueListenable<HoloFrame> frame;

  /// Palette and blend mode.
  final HoloEffect effect;

  /// Foil strength, `0..1`.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;
    final f = frame.value;
    final base = effect.colors.take(kMaxHoloColors).toList();
    final colors = [
      ...base,
      base.first
    ]; // close the loop so tiling is seamless
    final stops = [
      for (var i = 0; i < colors.length; i++) i / (colors.length - 1)
    ];
    final span = size.longestSide / effect.bandDensity.clamp(0.5, 8.0) * 2;
    final slide =
        (f.tilt.dx * 0.9 + f.tilt.dy * 0.6) * span + f.time * span * 0.1;
    final start =
        Offset(size.width / 2 + slide, size.height / 2 + slide * 0.65);
    final end = start + Offset(span, span * 0.65);
    final alpha = (0.35 + 0.35 * f.tilt.distance.clamp(0.0, 1.0)) * intensity;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          [for (final c in colors) _withOpacity(c, alpha)],
          stops,
          TileMode.repeated,
        )
        ..blendMode = effect.blendMode,
    );
  }

  @override
  bool shouldRepaint(HoloFoilFallbackPainter old) =>
      old.frame != frame || old.effect != effect || old.intensity != intensity;
}
