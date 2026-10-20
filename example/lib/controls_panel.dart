import 'package:flutter/material.dart';
import 'package:holo_card/holo_card.dart';

/// Live settings shared between the gallery and its controls.
class DemoSettings {
  /// Creates settings with the demo defaults.
  const DemoSettings({
    this.maxTiltAngle = 0.35,
    this.glare = 0.6,
    this.foil = 0.7,
    this.gyroscope = true,
    this.idle = true,
  });

  /// Rotation in radians at full tilt.
  final double maxTiltAngle;

  /// Glare intensity, 0 to 1.
  final double glare;

  /// Foil intensity, 0 to 1.
  final double foil;

  /// Whether the gyroscope drives the card (mobile only).
  final bool gyroscope;

  /// Whether the idle sway is on.
  final bool idle;

  /// Returns a copy with the given fields replaced.
  DemoSettings copyWith({
    double? maxTiltAngle,
    double? glare,
    double? foil,
    bool? gyroscope,
    bool? idle,
  }) =>
      DemoSettings(
        maxTiltAngle: maxTiltAngle ?? this.maxTiltAngle,
        glare: glare ?? this.glare,
        foil: foil ?? this.foil,
        gyroscope: gyroscope ?? this.gyroscope,
        idle: idle ?? this.idle,
      );
}

/// Sliders, an effect picker and toggles for the demo.
class ControlsPanel extends StatelessWidget {
  /// Creates the panel.
  const ControlsPanel({
    required this.settings,
    required this.onSettings,
    required this.effect,
    required this.onEffect,
    required this.controller,
    super.key,
  });

  /// Current settings.
  final DemoSettings settings;

  /// Called with updated settings.
  final ValueChanged<DemoSettings> onSettings;

  /// The selected card's effect.
  final HoloEffect effect;

  /// Called when another effect is picked.
  final ValueChanged<HoloEffect> onEffect;

  /// Controller shared with the displayed cards.
  final HoloCardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Effect', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in HoloEffect.presets)
              ChoiceChip(
                label: Text(preset.name),
                selected: preset == effect,
                onSelected: (_) => onEffect(preset),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _slider(
          'Tilt angle',
          settings.maxTiltAngle,
          0,
          0.7,
          (v) => onSettings(settings.copyWith(maxTiltAngle: v)),
        ),
        _slider(
          'Glare',
          settings.glare,
          0,
          1,
          (v) => onSettings(settings.copyWith(glare: v)),
        ),
        _slider(
          'Foil',
          settings.foil,
          0,
          1,
          (v) => onSettings(settings.copyWith(foil: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Gyroscope'),
          subtitle: const Text('Android and iOS only'),
          value: settings.gyroscope,
          onChanged: (v) => onSettings(settings.copyWith(gyroscope: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Idle animation'),
          value: settings.idle,
          onChanged: (v) => onSettings(settings.copyWith(idle: v)),
        ),
        const SizedBox(height: 8),
        Text('Controller', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => controller.tiltTo(const Offset(1, -1)),
              child: const Text('Tilt to corner'),
            ),
            OutlinedButton(
              onPressed: controller.reset,
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(width: 38, child: Text(value.toStringAsFixed(2))),
      ],
    );
  }
}
