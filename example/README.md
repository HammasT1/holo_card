# holo_card example

A gallery app for the [`holo_card`](../README.md) package: five sample cards
(built only from Flutter widgets, gradients and icons, with no image assets)
and a live controls panel.

## Run it

```sh
cd example
flutter pub get
flutter run -d chrome     # web
flutter run -d linux      # or windows / macos
flutter run               # a connected Android or iOS device
```

## What to try

* Move the mouse over a card (or drag with a finger) to tilt it.
* Swipe the pager to change cards; pick a different **Effect** for the current one.
* Drag the **Tilt angle**, **Glare** and **Foil** sliders.
* On a phone, turn **Gyroscope** on and physically rotate the device.
  The gyroscope switch does nothing on desktop and web.
* **Tilt to corner** and **Reset** drive the card through `HoloCardController`.
* Tap **Add** on the headphones card: taps inside a card still work.
* Turn on your OS "reduce motion" setting to see the calmer variant.

## Build the web demo

```sh
flutter build web --release
```

The `pages.yml` workflow in the repository root does this and publishes the
result to GitHub Pages.
