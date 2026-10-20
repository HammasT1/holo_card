# Decisions

Choices made where the brief was open or ambiguous.

* **Name.** `holo_card` returned 404 from `pub.dev/api/packages/holo_card` on
  2026-10-20, so it looked free. Confirm at <https://pub.dev/packages/holo_card>
  before publishing: names can be taken any time.
* **Minimum versions.** Dart `^3.6.0`, Flutter `>=3.27.0`. 3.27 is where
  `Color.r/.g/.b` (used to feed the shader) landed without deprecation noise;
  `sensors_plus` 7 itself needs less. Only tested on Flutter 3.47.5 / Dart
  3.13.4, so the lower bound is an expectation, not a measurement.
* **Tilt units.** Tilt is *normalized*: each axis in `-1..1`. `onTiltChanged`
  and `HoloCardController.tiltTo` use these units; rotation is
  `tilt * maxTiltAngle`. This keeps the API independent of the angle setting.
* **Direction.** The edge nearest the pointer is pushed away from the viewer
  (like pressing on the card). Gyroscope uses the same convention: the card
  turns the same way the device turns. The gyroscope sign is derived from the
  right-hand rule and **has not been verified on hardware**.
* **Gyroscope model.** A gyroscope gives rotation *rate*, so it is integrated
  into an angle that leaks back to zero (1.2 s time constant) and is low-pass
  filtered. The card therefore follows how the device is turned and settles when
  held still, rather than reading absolute orientation.
* **Input priority.** Pointer beats gyroscope beats controller target beats
  idle. A programmatic `tiltTo` is a resting position, not an override of live
  input.
* **No `setState` per frame.** A `TiltEngine` publishes a `HoloFrame` into a
  `ValueNotifier`; a `ValueListenableBuilder` rebuilds only the `Transform`
  (the child is passed through untouched) and the painters repaint through
  `repaint:`. The ticker stops entirely when the card is at rest.
* **Shimmer clock.** The foil's time uniform advances only while the card is
  moving (interaction, spring, idle). A resting card with idle animation off is
  fully static and costs nothing.
* **Blend modes.** Chosen per preset after looking at renders: `screen` for
  rainbow and aurora (`overlay` was too faint on dark cards), `hardLight` for
  galaxy, `softLight` for gold and chrome. Blending relies on the foil being
  drawn after the child in the same compositing target. Verified only on
  web/CanvasKit (headless Chrome); not yet seen on Impeller or on a device.
* **Reduced motion.** Disables idle animation and the gyroscope, freezes the
  shimmer clock, halves foil intensity, reduces rotation and shadow travel, and
  uses a critically damped spring (no overshoot). Pointer tilt still works
  because it is user-initiated.
* **Input widget.** A raw `Listener` (not `GestureDetector`) so the card never
  enters the gesture arena and child buttons, scrolls and taps are untouched.
  The hit-test box is outside the `Transform`, so tilting never moves the
  region being tested.
* **`HoloEffect` is a class,** not an enum, so `custom` can share the type.
  `HoloEffect.custom` is not `const` (it truncates the color list).
* **Gyroscope availability** is Android and iOS only, never web, to match what
  the README promises.
* **Frame delta clamp.** One tick never advances more than 50 ms, so resuming
  after a stall does not teleport the card.
* **Screenshots.** `screenshots/effects.png` is a real render of the example.
  The GIFs and the live demo URL in the README are placeholders for you to
  record and deploy.
* **Repository URL** in `pubspec.yaml` is `https://github.com/HammasT1/holo_card`,
  guessed from the git remote of the repo this package currently sits in.
  Change it if the package lives elsewhere.
* **Workflows** live in this package's `.github/` as requested. They only run
  once the package is its own repository root (they do nothing inside the
  parent `flutter-ui-and-animations` repo).
* **Git identity** was not configured on this machine, so commits used the
  author of the existing history, passed per-command; no git config was changed.
