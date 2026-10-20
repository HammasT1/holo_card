import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'foil_shader.dart';
import 'holo_card_controller.dart';
import 'holo_effect.dart';
import 'input/gyroscope_tilt_source.dart';
import 'input/tilt_source.dart';
import 'painters.dart';
import 'tilt_engine.dart';
import 'tilt_math.dart';

/// Wraps [child] in a 3D collectible-style card.
///
/// The card tilts toward the pointer (hover on desktop and web, drag on touch)
/// or the device gyroscope, with a glare that follows the light and a
/// holographic foil whose colors shift with the tilt angle.
///
/// ```dart
/// HoloCard(
///   effect: HoloEffect.rainbow,
///   child: MyCardContent(),
/// )
/// ```
///
/// [child] is never rebuilt while the card moves, and it keeps receiving taps
/// and keeps its semantics. Honors reduced-motion settings
/// (`MediaQuery.disableAnimations`): no idle animation, no gyroscope, a calmer
/// foil and a spring with no overshoot.
class HoloCard extends StatefulWidget {
  /// Creates a holographic card around [child].
  const HoloCard({
    required this.child,
    super.key,
    this.effect = HoloEffect.rainbow,
    this.maxTiltAngle = 0.35,
    this.perspective = 0.0012,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.glareIntensity = 0.6,
    this.foilIntensity = 0.7,
    this.shadow = true,
    this.enableGyroscope = true,
    this.enablePointer = true,
    this.idleAnimation = true,
    this.controller,
    this.onTiltChanged,
  })  : assert(maxTiltAngle >= 0, 'maxTiltAngle must not be negative.'),
        assert(glareIntensity >= 0 && glareIntensity <= 1,
            'glareIntensity must be in 0..1.'),
        assert(foilIntensity >= 0 && foilIntensity <= 1,
            'foilIntensity must be in 0..1.');

  /// The content of the card.
  final Widget child;

  /// The foil look. Defaults to [HoloEffect.rainbow].
  final HoloEffect effect;

  /// The rotation, in radians, at full tilt. Defaults to `0.35` (about 20°).
  final double maxTiltAngle;

  /// The perspective strength (the `[3][2]` matrix entry). Larger values
  /// exaggerate the 3D look. Defaults to `0.0012`.
  final double perspective;

  /// The corner radius used to clip the effect layers and shape the shadow.
  /// Match your child's own radius. Defaults to a 20 logical pixel radius.
  final BorderRadius borderRadius;

  /// Strength of the moving glare, `0` (off) to `1`. Defaults to `0.6`.
  final double glareIntensity;

  /// Strength of the holographic foil, `0` (off) to `1`. Defaults to `0.7`.
  final double foilIntensity;

  /// Whether to draw a drop shadow that shifts as the card tilts.
  final bool shadow;

  /// Whether to tilt with the device gyroscope. Only has an effect on Android
  /// and iOS; ignored on every other platform and in the browser.
  final bool enableGyroscope;

  /// Whether to tilt with the pointer: hover for mouse, drag for touch.
  final bool enablePointer;

  /// Whether the card sways gently on its own while untouched.
  final bool idleAnimation;

  /// Optional programmatic control.
  final HoloCardController? controller;

  /// Called whenever the normalized tilt changes (each axis in `-1..1`).
  ///
  /// This can fire every frame during motion, so keep the callback cheap and
  /// avoid calling `setState` on large trees from it.
  final ValueChanged<Offset>? onTiltChanged;

  @override
  State<HoloCard> createState() => _HoloCardState();
}

class _HoloCardState extends State<HoloCard>
    with SingleTickerProviderStateMixin {
  final ManualTiltSource _pointer = ManualTiltSource();
  GyroscopeTiltSource? _gyro;
  late final TiltEngine _engine;
  late final Ticker _ticker;
  Duration? _lastElapsed;
  Offset _lastReportedTilt = Offset.zero;
  ui.FragmentProgram? _program;
  bool _reducedMotion = false;
  int? _pointerId;

  @override
  void initState() {
    super.initState();
    _engine = TiltEngine(sources: [_pointer], onWake: _wake);
    _ticker = createTicker(_onTick);
    _engine.frame.addListener(_reportTilt);
    widget.controller?.addListener(_syncController);
    FoilShader.load().then((program) {
      if (mounted && program != null) setState(() => _program = program);
    });
    _syncController();
    _syncGyro();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _syncGyro();
    }
    _syncController();
  }

  @override
  void didUpdateWidget(HoloCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncController);
      widget.controller?.addListener(_syncController);
    }
    if (!widget.enablePointer) _releasePointer();
    _syncController();
    _syncGyro();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncController);
    _engine.frame.removeListener(_reportTilt);
    _ticker.dispose();
    _gyro?.dispose();
    _engine.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _syncController() {
    final controller = widget.controller;
    _engine
      ..reducedMotion = _reducedMotion
      ..shimmerSpeed = widget.effect.shimmerSpeed
      ..idleEnabled = controller?.idleOverride ?? widget.idleAnimation
      ..holdTarget = controller?.targetTilt;
  }

  void _syncGyro() {
    final wanted =
        widget.enableGyroscope && !_reducedMotion && gyroscopeSupported;
    if (wanted && _gyro == null) {
      _gyro = GyroscopeTiltSource()..start();
      _engine.addSource(_gyro!);
    } else if (!wanted && _gyro != null) {
      _engine.removeSource(_gyro!);
      _gyro!.dispose();
      _gyro = null;
    }
  }

  void _wake() {
    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    final dt = last == null
        ? 1 / 60
        : ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _engine.step(dt);
    if (!_engine.isActive) _ticker.stop();
  }

  void _reportTilt() {
    final callback = widget.onTiltChanged;
    final tilt = _engine.tilt;
    if (callback == null || tilt == _lastReportedTilt) return;
    _lastReportedTilt = tilt;
    callback(tilt);
  }

  void _updatePointer(PointerEvent event) {
    if (!widget.enablePointer) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _pointerId = event.pointer;
    _pointer.value = tiltFromPosition(event.localPosition, box.size);
  }

  void _releasePointer() {
    _pointerId = null;
    _pointer.release();
  }

  void _onPointerEnd(PointerEvent event) {
    // A mouse stays hovering after a button is released.
    if (event is PointerUpEvent && event.kind == ui.PointerDeviceKind.mouse) {
      return;
    }
    if (_pointerId == event.pointer || event is PointerCancelEvent) {
      _releasePointer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effect = widget.effect;
    final reduced = _reducedMotion;
    final foilIntensity = widget.foilIntensity * (reduced ? 0.5 : 1);
    final program = _program;
    final frame = _engine.frame;

    final foil = program != null
        ? HoloFoilShaderPainter(
            frame: frame,
            program: program,
            effect: effect,
            intensity: foilIntensity,
          )
        : HoloFoilFallbackPainter(
            frame: frame,
            effect: effect,
            intensity: foilIntensity,
          );

    final card = ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          RepaintBoundary(child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                    key: const ValueKey('holo_foil'), painter: foil),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('holo_glare'),
                  painter: HoloGlarePainter(
                    frame: frame,
                    intensity: widget.glareIntensity * (reduced ? 0.6 : 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onExit: (_) => _releasePointer(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: _updatePointer,
        onPointerDown: _updatePointer,
        onPointerMove: _updatePointer,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.shadow)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('holo_shadow'),
                      painter: HoloShadowPainter(
                        frame: frame,
                        borderRadius: widget.borderRadius,
                        reduced: reduced,
                      ),
                    ),
                  ),
                ),
              ),
            ValueListenableBuilder<HoloFrame>(
              valueListenable: frame,
              child: card,
              builder: (context, value, child) => Transform(
                alignment: Alignment.center,
                transform: cardMatrix(
                  value.tilt,
                  widget.maxTiltAngle * (reduced ? 0.6 : 1),
                  widget.perspective,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
