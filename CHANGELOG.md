## 0.1.0

* Initial release.
* `HoloCard`: 3D tilt (pointer hover, touch drag, gyroscope), moving glare and
  a holographic foil layer, with a drop shadow and a gentle idle animation.
* Foil rendered by a fragment shader, with an automatic gradient fallback when
  shaders are unavailable.
* `HoloEffect` presets (`rainbow`, `galaxy`, `gold`, `chrome`, `aurora`) and
  `HoloEffect.custom`.
* `HoloCardController` for programmatic tilt and idle control.
* Respects reduced motion (`MediaQuery.disableAnimations`).
