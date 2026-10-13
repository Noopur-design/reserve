import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reserve_liquor/data/models.dart';
import 'package:reserve_liquor/data/profile_photo.dart';
import 'package:reserve_liquor/main.dart';
import 'package:reserve_liquor/screens/main_shell.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/theme/app_theme.dart';
import 'package:reserve_liquor/widgets/user_avatar.dart';
import 'package:reserve_liquor/widgets/web_frame.dart';

import 'test_utils.dart';

/// The web build: inline (data URL) profile photos and the desktop phone
/// frame. `kIsWeb` is false under `flutter test`, so the frame is switched on
/// explicitly with `webAppBuilder(..., frame: true)`.

// A 1×1 PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const _pngDataUrl = 'data:image/png;base64,$_pngBase64';

Widget _avatarHarness(UserProfile profile) => ChangeNotifierProvider.value(
      value: AppState(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: UserAvatar(size: 96, profile: profile))),
      ),
    );

/// The app's web setup around [home], with the frame forced on (or off).
Widget _webHarness(Widget home, {bool frame = true}) => MaterialApp(
      theme: AppTheme.web,
      scrollBehavior: const WebScrollBehavior(),
      builder: (context, child) => webAppBuilder(context, child, frame: frame),
      home: home,
    );

/// A page that records the MediaQuery it is laid out with and can open a
/// dialog, a bottom sheet, a snack bar and a second page.
class _Probe extends StatelessWidget {
  const _Probe(this.onMediaQuery);
  final void Function(MediaQueryData) onMediaQuery;

  @override
  Widget build(BuildContext context) {
    onMediaQuery(MediaQuery.of(context));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('Dialog'), content: Text('Inside the phone')),
            ),
            child: const Text('dialog'),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(height: 200, child: Center(child: Text('Sheet'))),
            ),
            child: const Text('sheet'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toast'))),
            child: const Text('snack'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Center(child: Text('Second page'))),
            )),
            child: const Text('push'),
          ),
        ]),
      ),
    );
  }
}

void _expectInside(Rect inner, Rect outer, String what) {
  const e = 0.01;
  expect(
    inner.left >= outer.left - e &&
        inner.top >= outer.top - e &&
        inner.right <= outer.right + e &&
        inner.bottom <= outer.bottom + e,
    isTrue,
    reason: '$what $inner is not inside $outer',
  );
}

void main() {
  group('ProfilePhoto (web photos as data URLs)', () {
    test('builds and recognises data URLs', () {
      final url = ProfilePhoto.toDataUrl(base64Decode(_pngBase64), mimeType: 'image/png');
      expect(url, _pngDataUrl);
      expect(ProfilePhoto.isDataUrl(url), isTrue);
      expect(ProfilePhoto.isDataUrl('/data/user/0/files/avatar_1.jpg'), isFalse);
      expect(ProfilePhoto.isDataUrl(null), isFalse);
      // Unknown types are labelled JPEG.
      expect(ProfilePhoto.toDataUrl([1, 2, 3]), startsWith('data:image/jpeg;base64,'));
      expect(ProfilePhoto.toDataUrl([1, 2, 3], mimeType: 'application/octet-stream'),
          startsWith('data:image/jpeg;base64,'));
    });

    test('decodes once and reuses the image provider', () {
      final a = ProfilePhoto.imageFor(_pngDataUrl);
      expect(a, isNotNull);
      expect(a!.bytes, base64Decode(_pngBase64));
      expect(identical(ProfilePhoto.imageFor(_pngDataUrl), a), isTrue);
    });

    test('rejects malformed data URLs', () {
      expect(ProfilePhoto.imageFor('data:image/png;base64,***'), isNull);
      expect(ProfilePhoto.imageFor('data:image/png,abc'), isNull);
      expect(ProfilePhoto.imageFor('data:image/png;base64,'), isNull);
      expect(ProfilePhoto.imageFor('/not/a/data/url.png'), isNull);
    });
  });

  group('UserAvatar', () {
    testWidgets('shows a data-URL photo', (t) async {
      await t.pumpWidget(_avatarHarness(
          const UserProfile(name: 'Riya Kapoor', phone: '9876543210', photoPath: _pngDataUrl)));
      final image = t.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, base64Decode(_pngBase64));
      expect(find.text('RK'), findsNothing);
      expect(find.bySemanticsLabel('Profile photo of Riya Kapoor'), findsOneWidget);

      // Rebuilding reuses the decoded photo instead of decoding it again.
      await t.pumpWidget(_avatarHarness(
          const UserProfile(name: 'Riya K', phone: '9876543210', photoPath: _pngDataUrl)));
      expect(identical(t.widget<Image>(find.byType(Image)).image, image.image), isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('falls back to initials for a broken data URL', (t) async {
      await t.pumpWidget(_avatarHarness(
          const UserProfile(name: 'Riya Kapoor', phone: '9876543210', photoPath: 'data:image/png;base64,%%%')));
      expect(find.byType(Image), findsNothing);
      expect(find.text('RK'), findsOneWidget);
    });

    testWidgets('a missing photo file still shows initials', (t) async {
      await t.pumpWidget(_avatarHarness(
          const UserProfile(name: 'Riya Kapoor', phone: '9876543210', photoPath: '/no/such/avatar.jpg')));
      expect(find.byType(Image), findsNothing);
      expect(find.text('RK'), findsOneWidget);
    });
  });

  test('an account with a data-URL photo can be updated and deleted', () {
    final s = signedInState();
    s.updateProfile(photoPath: _pngDataUrl);
    expect(s.user!.photoPath, _pngDataUrl);
    s.deleteAccount();
    expect(s.user, isNull);
    expect(s.signIn('9876543210', 'secret1'), isNotNull, reason: 'the account should be gone');
  });

  test('the web theme keeps phone metrics on desktop browsers', () {
    final theme = AppTheme.web;
    expect(theme.visualDensity, VisualDensity.standard);
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(theme.colorScheme.primary, AppTheme.light.colorScheme.primary);
  });

  group('WebFrame', () {
    testWidgets('frames the app as a phone on a wide screen', (t) async {
      setScreen(t, const Size(1440, 900));
      late MediaQueryData mq;
      await t.pumpWidget(_webHarness(_Probe((d) => mq = d)));

      expect(find.byKey(const Key('web-frame-phone')), findsOneWidget);
      expect(find.text(WebFrame.caption), findsOneWidget);

      // 900 high: 24 margin top and bottom, 10 bezel each side and the
      // caption leave an 800 high screen; nothing needs scaling.
      final screen = t.getRect(find.byKey(const Key('web-frame-screen')));
      expect(screen.size, const Size(412, 800));
      expect(screen.center.dx, closeTo(720, 0.01));
      expect(mq.size, const Size(412, 800));
      expect(mq.padding, WebFrame.screenPadding);
      expect(mq.viewPadding, WebFrame.screenPadding);
      expect(mq.viewInsets, EdgeInsets.zero);
      _expectInside(t.getRect(find.byType(Scaffold)), screen, 'the page');
    });

    testWidgets('dialogs, sheets and snack bars stay inside the phone', (t) async {
      setScreen(t, const Size(1440, 900));
      await t.pumpWidget(_webHarness(_Probe((_) {})));
      final screen = t.getRect(find.byKey(const Key('web-frame-screen')));

      await t.tap(find.text('dialog'));
      await t.pumpAndSettle();
      _expectInside(t.getRect(find.byType(AlertDialog)), screen, 'the dialog');
      // The dimmed barrier covers the phone screen, not the whole window.
      expect(t.getRect(find.byType(ModalBarrier).last), screen);
      Navigator.of(t.element(find.text('Inside the phone'))).pop();
      await t.pumpAndSettle();

      await t.tap(find.text('sheet'));
      await t.pumpAndSettle();
      final sheet = t.getRect(find.byType(BottomSheet));
      _expectInside(sheet, screen, 'the bottom sheet');
      expect(sheet.bottom, closeTo(screen.bottom, 0.01));
      Navigator.of(t.element(find.text('Sheet'))).pop();
      await t.pumpAndSettle();

      await t.tap(find.text('snack'));
      await t.pump(const Duration(milliseconds: 750));
      _expectInside(t.getRect(find.byType(SnackBar)), screen, 'the snack bar');
    });

    testWidgets('a short window scales the phone down instead of squashing it', (t) async {
      setScreen(t, const Size(1280, 600));
      late MediaQueryData mq;
      await t.pumpWidget(_webHarness(_Probe((d) => mq = d)));

      expect(mq.size, const Size(412, WebFrame.minScreenHeight));
      final phone = t.getRect(find.byKey(const Key('web-frame-phone')));
      expect(phone.top, greaterThanOrEqualTo(WebFrame.margin - 0.01));
      expect(phone.height, lessThan(WebFrame.minScreenHeight));
      final screen = t.getRect(find.byKey(const Key('web-frame-screen')));
      expect(screen.width / screen.height, closeTo(412 / WebFrame.minScreenHeight, 0.001));
    });

    testWidgets('fills a narrow viewport (phones, a 412 px iframe)', (t) async {
      setScreen(t, const Size(412, 860));
      late MediaQueryData mq;
      await t.pumpWidget(_webHarness(_Probe((d) => mq = d)));

      expect(find.byKey(const Key('web-frame-phone')), findsNothing);
      expect(find.byKey(const Key('web-frame-backdrop')), findsNothing);
      expect(find.text(WebFrame.caption), findsNothing);
      expect(mq.size, const Size(412, 860));
      expect(mq.padding, EdgeInsets.zero);
      expect(t.getRect(find.byType(Scaffold)), Offset.zero & const Size(412, 860));
    });

    testWidgets('is off unless running on the web', (t) async {
      setScreen(t, const Size(1440, 900));
      late MediaQueryData mq;
      await t.pumpWidget(_webHarness(_Probe((d) => mq = d), frame: false));
      expect(find.byKey(const Key('web-frame-phone')), findsNothing);
      expect(mq.size, const Size(1440, 900));

      // The default follows kIsWeb, which is false in tests (and on phones).
      await t.pumpWidget(MaterialApp(builder: webAppBuilder, home: _Probe((d) => mq = d)));
      expect(find.byKey(const Key('web-frame-phone')), findsNothing);
      expect(mq.size, const Size(1440, 900));
    });

    testWidgets('keeps the open page when the window is resized across the breakpoint', (t) async {
      setScreen(t, const Size(1440, 900));
      await t.pumpWidget(_webHarness(_Probe((_) {})));
      await t.tap(find.text('push'));
      await t.pumpAndSettle();
      expect(find.text('Second page'), findsOneWidget);

      setScreen(t, const Size(400, 800));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('web-frame-phone')), findsNothing);
      expect(find.text('Second page'), findsOneWidget);

      setScreen(t, const Size(1440, 900));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('web-frame-phone')), findsOneWidget);
      expect(find.text('Second page'), findsOneWidget);
    });

    testWidgets('still clamps the text scale inside the frame', (t) async {
      setScreen(t, const Size(1440, 900), textScale: 2.0);
      late MediaQueryData mq;
      await t.pumpWidget(_webHarness(_Probe((d) => mq = d)));
      expect(mq.size, const Size(412, 800));
      expect(mq.textScaler.scale(10), closeTo(11.5, 0.001));
    });

    test('lets a mouse drag lists like a finger', () {
      expect(const WebScrollBehavior().dragDevices, contains(PointerDeviceKind.mouse));
      expect(const WebScrollBehavior().dragDevices, contains(PointerDeviceKind.touch));
    });

    testWidgets('the store lays out inside the frame without overflow', (t) async {
      await loadAppFonts();
      setScreen(t, const Size(1440, 900));
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: signedInState(),
        child: _webHarness(const MainShell()),
      ));
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('web-frame-phone')), findsOneWidget);
      final screen = t.getRect(find.byKey(const Key('web-frame-screen')));
      _expectInside(t.getRect(find.byType(MainShell)), screen, 'the store');
      await scrollThroughAll(t);
      expect(t.takeException(), isNull);
    });
  });
}
