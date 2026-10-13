Regenerate the portfolio screenshots into `showcase/raw/` from the project root, no device needed: `flutter test tool/screenshots/screenshots_test.dart`

- `01-…16-*.png`: 16 screens on a 412 × 915 dp phone at 3× (1236 × 2745 px).
- `pair-*.png`: the four build screens for the case study's Design → Build pairs, on a 440 × 978 dp phone (1320 × 2934 px), which is closer to the concept PNGs' density.
- Tracking shots are rendered 24 dp taller and the bottom 24 dp is cropped off. `OrderTrackingScreen` lifts its cream sheet with `Matrix4.translationValues(0, -24, 0)`, which leaves a 24 dp strip of the green Scaffold background at the bottom of the screen. That is an app bug, still present on devices: fix it in `lib/screens/order_tracking_screen.dart` (add 24 dp of cream below the sheet, or pad the list), then drop `cropBottom` here.

Render only some shots with `--name`, for example `--name 11-tracking` or `--name pair-` (several `--name` flags must all match).
Add `--dart-define=NO_STATUS_BAR=true` to leave out the drawn 9:41 status bar. The `design-*.png` references are plain copies from the "Liquor project app ui images" folder and are not regenerated; `showcase/build/make_images.py` crops the drawn phone bezel off `design-tracking`.
