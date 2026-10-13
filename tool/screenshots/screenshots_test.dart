// Renders the real app screens off-device (flutter_tester, no phone) and saves
// crisp 3x PNG screenshots for the portfolio case study into showcase/raw/.
//
// Lives outside test/ so the normal `flutter test` run ignores it.
// Run from the project root:
//   flutter test tool/screenshots/screenshots_test.dart
// Without the drawn status bar (time / signal / battery):
//   flutter test tool/screenshots/screenshots_test.dart --dart-define=NO_STATUS_BAR=true

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reserve_liquor/data/sample_data.dart';
import 'package:reserve_liquor/main.dart';
import 'package:reserve_liquor/screens/cart_screen.dart';
import 'package:reserve_liquor/screens/category_screen.dart';
import 'package:reserve_liquor/screens/checkout_screen.dart';
import 'package:reserve_liquor/screens/help_screen.dart';
import 'package:reserve_liquor/screens/location_screen.dart';
import 'package:reserve_liquor/screens/main_shell.dart';
import 'package:reserve_liquor/screens/onboarding_screen.dart';
import 'package:reserve_liquor/screens/order_detail_screen.dart';
import 'package:reserve_liquor/screens/order_tracking_screen.dart';
import 'package:reserve_liquor/screens/product_detail_screen.dart';
import 'package:reserve_liquor/screens/wishlist_screen.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/theme/app_theme.dart';
import 'package:reserve_liquor/widgets/common.dart';

import '../../test/test_utils.dart' show loadAppFonts;

// ---------------------------------------------------------------------------
// Device setup
// ---------------------------------------------------------------------------

/// A 412 x 915 dp phone (Pixel 7 class) at 3x, i.e. 1236 x 2745 px images.
const Size kLogicalSize = Size(412, 915);

/// A large 440 x 978 dp phone, used for the "Design -> Build" pair images
/// (pair-*.png, 1320 x 2934 px). Its density is closer to the concept PNGs,
/// and 440 dp is one of the widths the layout test matrix covers.
const Size kPairSize = Size(440, 978);

const double kPixelRatio = 3;

/// OrderTrackingScreen lifts its cream sheet 24 dp (Matrix4 translate), which
/// leaves a 24 dp strip of the green Scaffold background at the bottom of the
/// screen (an app bug, logged for a later fix; lib/ is not changed here).
/// Tracking shots are rendered this much taller and the strip is cropped off,
/// so the saved image is still exactly one phone screen.
const double kTrackingStrip = 24;

/// Height of the simulated status bar (logical px). The app's SafeAreas lay
/// out below it exactly as on a phone.
const double kStatusBarHeight = 36;

const bool kDrawStatusBar = !bool.fromEnvironment('NO_STATUS_BAR');

const String kOutDir = 'showcase/raw';

/// Demo account shown on the signed-in screens.
const String kUserName = 'Aarav Mehta';

/// Loads the Material icons font from the Flutter SDK so Icons.* render as
/// glyphs (flutter_tester otherwise draws them as boxes).
Future<void> _loadMaterialIcons() async {
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final r?) r,
    'C:/src/flutter',
  ];
  for (final root in roots) {
    for (final name in ['MaterialIcons-Regular.otf', 'materialicons-regular.otf']) {
      final f = File('$root/bin/cache/artifacts/material_fonts/$name');
      if (f.existsSync()) {
        final bytes = f.readAsBytesSync();
        final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        return;
      }
    }
  }
  throw StateError('MaterialIcons-Regular.otf not found under $roots');
}

void _configureView(WidgetTester t, Size size) {
  t.view.physicalSize = size * kPixelRatio;
  t.view.devicePixelRatio = kPixelRatio;
  const inset = FakeViewPadding(top: kStatusBarHeight * kPixelRatio);
  t.view.padding = inset;
  t.view.viewPadding = inset;
  t.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

AppState _guestState() => AppState();

AppState _signedInState() {
  final s = AppState();
  final err = s.createAccount(
    name: kUserName,
    phone: '9876543210',
    email: 'aarav.mehta@example.com',
    password: 'reserve-demo',
  );
  if (err != null) throw StateError(err);
  return s;
}

// ---------------------------------------------------------------------------
// Status bar (drawn, Android style)
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  final bool light;
  const _StatusBar({required this.light});

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : AppColors.ink;
    // Sits above the Navigator, so it needs its own Material for text styling.
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: kStatusBarHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 4, 22, 0),
            child: Row(children: [
              Text('9:41', style: T.sans(15, color: c, weight: FontWeight.w700, spacing: 0.2)),
              const Spacer(),
              Icon(Icons.signal_cellular_alt, size: 17, color: c),
              const SizedBox(width: 5),
              Icon(Icons.wifi, size: 17, color: c),
              const SizedBox(width: 4),
              Transform.rotate(angle: 1.5708, child: Icon(Icons.battery_full, size: 19, color: c)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _Stage {
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  final home = ValueNotifier<Widget?>(null);
  final lightStatus = ValueNotifier<bool>(false);

  Widget build(AppState state) => RepaintBoundary(
        key: boundary,
        child: ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => Stack(children: [
              Positioned.fill(child: clampTextScale(context, child)),
              if (kDrawStatusBar)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: lightStatus,
                    builder: (_, light, __) => _StatusBar(light: light),
                  ),
                ),
            ]),
            home: ValueListenableBuilder<Widget?>(
              valueListenable: home,
              builder: (_, w, __) => w ?? const ColoredBox(color: AppColors.cream, child: SizedBox.expand()),
            ),
          ),
        ),
      );
}

/// Pumps frame by frame so tickers, staggered FadeIns and route transitions
/// run exactly as on a device (one big pump would skip them).
Future<void> _settle(WidgetTester t, [Duration d = const Duration(milliseconds: 3000)]) async {
  const step = Duration(milliseconds: 50);
  for (var i = 0; i < d.inMilliseconds ~/ step.inMilliseconds; i++) {
    await t.pump(step);
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t, const Duration(milliseconds: 1500));
}

/// Decodes every bundled image into the image cache before any screen is
/// built, so photos are on screen in the very first frame.
Future<void> _precacheAllImages(WidgetTester t, BuildContext context) async {
  final files = Directory('assets/images')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(n))
      .toList()
    ..sort();
  imageCache.maximumSizeBytes = 512 << 20;
  await t.runAsync(() async {
    await Future.wait(files.map((n) => precacheImage(AssetImage('$img$n'), context)));
  });
}

void _expectImagesDecoded(WidgetTester t, String name) {
  for (final e in find.byType(RawImage).evaluate()) {
    final raw = e.widget as RawImage;
    expect(raw.image, isNotNull, reason: '$name: an image is not decoded yet (${e.toStringShort()})');
  }
}

Future<void> _capture(WidgetTester t, _Stage stage, String name, {double cropBottom = 0}) async {
  _expectImagesDecoded(t, name);
  final boundary = stage.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    var image = await boundary.toImage(pixelRatio: kPixelRatio);
    if (cropBottom > 0) {
      // Keep the top part only (see kTrackingStrip).
      final w = image.width;
      final h = image.height - (cropBottom * kPixelRatio).round();
      final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(image, rect, rect, Paint()..filterQuality = FilterQuality.none);
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      picture.dispose();
      image.dispose();
      image = cropped;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final out = File('$kOutDir/$name');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${out.path}');
  });
}

// ---------------------------------------------------------------------------
// Shots
// ---------------------------------------------------------------------------

class _Shot {
  final String file;
  final String what;
  final AppState Function() state;

  /// The app's root page (what the Navigator starts with).
  final Widget Function(AppState s) base;

  /// Optional page pushed on top, the way the app navigates to it.
  final Widget Function(AppState s)? push;

  /// Interaction before capture (taps through pages / steps).
  final Future<void> Function(WidgetTester t)? act;

  /// Light status-bar icons (for screens with a dark top).
  final bool lightStatus;

  /// Logical screen size of the saved image (before [cropBottom] is added).
  final Size size;

  /// Extra logical height rendered below [size] and then cropped off.
  final double cropBottom;

  const _Shot(this.file, this.what,
      {required this.state,
      required this.base,
      this.push,
      this.act,
      this.lightStatus = false,
      this.size = kLogicalSize,
      this.cropBottom = 0});

  /// The same shot at another size, saved under another file name.
  _Shot at(Size newSize, String newFile) => _Shot(newFile, '$what, ${newSize.width.round()} dp',
      state: state,
      base: base,
      push: push,
      act: act,
      lightStatus: lightStatus,
      size: newSize,
      cropBottom: cropBottom);
}

MainShell _tab(AppState s, int i) {
  s.tabIndex = i;
  return const MainShell();
}

final _shots = <_Shot>[
  _Shot('01-onboarding.png', 'Onboarding: intro',
      state: _guestState, base: (_) => const OnboardingScreen(), lightStatus: true),
  _Shot('02-categories.png', 'Onboarding: category explorer',
      state: _guestState,
      base: (_) => const OnboardingScreen(),
      act: (t) => _tap(t, find.byKey(const Key('onboarding-next'))),
      lightStatus: true),
  _Shot('03-age-gate.png', 'Onboarding: 18+ age gate',
      state: _guestState,
      base: (_) => const OnboardingScreen(),
      act: (t) async {
        await _tap(t, find.byKey(const Key('onboarding-next')));
        await _tap(t, find.byKey(const Key('onboarding-next')));
      },
      lightStatus: true),
  _Shot('04-location.png', 'Delivery city picker',
      state: _guestState, base: (_) => const OnboardingScreen(), push: (_) => const LocationScreen()),
  _Shot('05-home.png', 'Home tab (signed in)', state: _signedInState, base: (s) => _tab(s, 0)),
  _Shot('06-explore.png', 'Explore tab', state: _signedInState, base: (s) => _tab(s, 1)),
  _Shot('07-category.png', 'Whisky category',
      state: _signedInState,
      base: (s) => _tab(s, 0),
      push: (_) => CategoryScreen(category: categoryById('whisky')),
      lightStatus: true),
  _Shot('08-product.png', 'Product detail: Macallan 18',
      state: _signedInState,
      base: (s) => _tab(s, 0),
      push: (_) => ProductDetailScreen(product: productById('macallan18')),
      lightStatus: true),
  _Shot('09-cart.png', 'Cart', state: _signedInState, base: (s) => _tab(s, 0), push: (_) => const CartScreen()),
  _Shot('10-checkout.png', 'Checkout: payment step',
      state: _signedInState,
      base: (s) => _tab(s, 0),
      push: (_) => const CheckoutScreen(),
      act: (t) async {
        await _tap(t, find.text('Continue to Delivery'));
        await _tap(t, find.text('Continue to Payment'));
      }),
  // The seeded cart placed through the app's own placeOrder(): an order that
  // is out for delivery, as right after checkout.
  _Shot('11-tracking.png', 'Order tracking (simulated)',
      state: _signedInState,
      base: (s) => _tab(s, 3),
      push: (s) => OrderTrackingScreen(order: s.placeOrder()),
      lightStatus: true,
      cropBottom: kTrackingStrip),
  _Shot('12-delivered.png', 'Order delivered',
      state: _signedInState, base: (s) => _tab(s, 3), push: (s) => OrderDetailScreen(order: s.orders[0])),
  _Shot('13-orders.png', 'My Orders', state: _signedInState, base: (s) => _tab(s, 3)),
  _Shot('14-profile.png', 'Profile tab (signed in)', state: _signedInState, base: (s) => _tab(s, 4)),
  _Shot('15-wishlist.png', 'Wishlist',
      state: _signedInState, base: (s) => _tab(s, 4), push: (_) => const WishlistScreen()),
  _Shot('16-help.png', 'Help & Support',
      state: _signedInState, base: (s) => _tab(s, 4), push: (_) => const HelpScreen()),
];

/// Build screens for the "Design -> Build" pairs, at [kPairSize].
final _pairShots = [
  for (final f in ['05-home.png', '08-product.png', '10-checkout.png', '11-tracking.png'])
    _shots.firstWhere((s) => s.file == f).at(kPairSize, 'pair-$f'),
];

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await _loadMaterialIcons();
  });

  for (final shot in [..._shots, ..._pairShots]) {
    testWidgets('${shot.file}  (${shot.what})', (t) async {
      _configureView(t, Size(shot.size.width, shot.size.height + shot.cropBottom));
      final state = shot.state();
      final stage = _Stage()..lightStatus.value = shot.lightStatus;

      // 1. Empty app shell, then decode every photo into the cache.
      await t.pumpWidget(stage.build(state));
      await t.pump();
      await _precacheAllImages(t, stage.navigator.currentContext!);

      // 2. The real start page, plus the page reached from it.
      stage.home.value = shot.base(state);
      await _settle(t, const Duration(milliseconds: 600));
      if (shot.push != null) {
        stage.navigator.currentState!.push(fadeRoute(shot.push!(state)));
        await _settle(t, const Duration(milliseconds: 600));
      }
      if (shot.act != null) await shot.act!(t);

      // 3. Let entrance animations finish, then capture.
      await _settle(t, const Duration(milliseconds: 3000));
      await _capture(t, stage, shot.file, cropBottom: shot.cropBottom);

      // Tear down so repeating animations / timers are disposed.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  }
}
