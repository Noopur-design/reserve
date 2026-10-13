import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserve_liquor/screens/location_screen.dart';
import 'package:reserve_liquor/screens/onboarding_screen.dart';
import 'package:reserve_liquor/state/app_state.dart';

import 'test_utils.dart';

/// Onboarding: arrow-only navigation, Skip, and one consistent set of dots.

const _dots = Key('onboarding-dots');
const _next = Key('onboarding-next');
const _skip = Key('onboarding-skip');
const _enterStore = 'I am 18+  ·  Enter Store';

double _page(WidgetTester t) => t.widget<PageView>(find.byType(PageView)).controller!.page!;

/// Index of the wide gold dot.
int _activeDot(WidgetTester t) {
  final dots = find.descendant(of: find.byKey(_dots), matching: find.byType(AnimatedContainer));
  expect(dots, findsNWidgets(3));
  final widths = [for (var i = 0; i < 3; i++) t.getSize(dots.at(i)).width];
  // Active dot is 34 wide, the others 14 (+10 gap after the first two).
  final active = widths.indexWhere((w) => w > 30);
  expect(widths.where((w) => w > 30).length, 1, reason: 'exactly one active dot: $widths');
  return active;
}

Future<AppState> _pumpOnboarding(WidgetTester t, {Size size = const Size(412, 915), double scale = 1.0}) async {
  setScreen(t, size, textScale: scale);
  final state = AppState();
  await t.pumpWidget(appHarness(state, const OnboardingScreen()));
  await t.pump(const Duration(seconds: 1));
  return state;
}

/// One frame to start the page animation, then let it finish.
Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tapKey(WidgetTester t, Key key) async {
  await t.tap(find.byKey(key));
  await _settle(t);
}

Future<void> _dispose(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('swiping never changes the page', (t) async {
    await _pumpOnboarding(t);
    expect(_page(t), 0);

    await t.drag(find.byType(PageView), const Offset(-300, 0));
    await _settle(t);
    await t.fling(find.byType(PageView), const Offset(-400, 0), 2500);
    await _settle(t);
    expect(_page(t), 0);
    expect(_activeDot(t), 0);

    // Not from the middle page either, in either direction.
    await _tapKey(t, _next);
    expect(_page(t), 1);
    await t.fling(find.byType(PageView), const Offset(400, 0), 2500);
    await _settle(t);
    await t.fling(find.byType(PageView), const Offset(-400, 0), 2500);
    await _settle(t);
    expect(_page(t), 1);
    expect(_activeDot(t), 1);
    await _dispose(t);
  });

  testWidgets('the arrow advances one page at a time', (t) async {
    await _pumpOnboarding(t);
    expect(find.byKey(_next), findsOneWidget);
    await _tapKey(t, _next);
    expect(_page(t), 1);
    expect(_activeDot(t), 1);
    await _tapKey(t, _next);
    expect(_page(t), 2);
    expect(_activeDot(t), 2);
    expect(find.text(_enterStore), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('Skip jumps straight to the age gate from any page', (t) async {
    await _pumpOnboarding(t);
    expect(find.byKey(_skip), findsOneWidget);
    await _tapKey(t, _skip);
    expect(_page(t), 2);
    expect(_activeDot(t), 2);
    expect(find.text(_enterStore), findsOneWidget);

    // Back to the explore page, then Skip from there.
    await t.tap(find.descendant(of: find.byType(AgeGatePage), matching: find.byIcon(Icons.arrow_back)));
    await _settle(t);
    expect(_page(t), 1);
    expect(find.byKey(_skip), findsOneWidget);
    await _tapKey(t, _skip);
    expect(_page(t), 2);
    await _dispose(t);
  });

  for (final (size, scale) in [(const Size(360, 740), 1.15), (const Size(412, 915), 1.0)]) {
    testWidgets('dots keep the same position and size on every page (${size.width.toInt()}dp @${scale}x)',
        (t) async {
      await _pumpOnboarding(t, size: size, scale: scale);
      final rects = <Rect>[t.getRect(find.byKey(_dots))];
      await _tapKey(t, _next);
      rects.add(t.getRect(find.byKey(_dots)));
      await _tapKey(t, _next);
      rects.add(t.getRect(find.byKey(_dots)));
      expect(find.byKey(_dots), findsOneWidget);
      expect(rects[1], rects[0]);
      expect(rects[2], rects[0]);
      // Sits in the bottom bar, inside the screen.
      expect(rects[0].bottom, lessThanOrEqualTo(size.height));
      expect(rects[0].top, greaterThan(size.height / 2));
      await _dispose(t);
    });
  }

  testWidgets('arrow and Skip are gone on the age gate, so it cannot be bypassed', (t) async {
    final state = await _pumpOnboarding(t);
    final arrowCenter = t.getCenter(find.byKey(_next));
    final skipCenter = t.getCenter(find.byKey(_skip));
    await _tapKey(t, _next);
    await _tapKey(t, _next);
    expect(_page(t), 2);
    expect(find.byKey(_next), findsNothing);
    expect(find.byKey(_skip), findsNothing);

    // Tapping where the arrow / Skip used to be does nothing.
    await t.tapAt(arrowCenter);
    await _settle(t);
    await t.tapAt(skipCenter);
    await _settle(t);
    expect(_page(t), 2);
    expect(find.byType(LocationScreen), findsNothing);
    expect(state.onboarded, isFalse);
    await _dispose(t);
  });

  testWidgets('age-gate back arrow and Android back step to the previous page', (t) async {
    await _pumpOnboarding(t);
    await _tapKey(t, _skip);
    expect(_page(t), 2);

    await t.tap(find.descendant(of: find.byType(AgeGatePage), matching: find.byIcon(Icons.arrow_back)));
    await _settle(t);
    expect(_page(t), 1);
    expect(find.byKey(_next), findsOneWidget, reason: 'the arrow comes back off the age gate');

    await t.binding.handlePopRoute();
    await _settle(t);
    expect(_page(t), 0);
    expect(_activeDot(t), 0);
    await _dispose(t);
  });

  testWidgets('Enter Store completes onboarding and opens the location step', (t) async {
    final state = await _pumpOnboarding(t);
    await _tapKey(t, _skip);
    await t.tap(find.text(_enterStore));
    await _settle(t);
    expect(state.onboarded, isTrue);
    expect(find.byType(LocationScreen), findsOneWidget);
    await _dispose(t);
  });

  bool guestEntry(WidgetTester t) => t.widget<LocationScreen>(find.byType(LocationScreen)).guestEntry;

  testWidgets('only a skipped onboarding opens the store as a guest', (t) async {
    await _pumpOnboarding(t);
    await _tapKey(t, _skip);
    await t.tap(find.text(_enterStore));
    await _settle(t);
    expect(guestEntry(t), isTrue);
    await _dispose(t);

    // Arrow all the way: sign in / create an account comes next.
    await _pumpOnboarding(t);
    await _tapKey(t, _next);
    await _tapKey(t, _next);
    await t.tap(find.text(_enterStore));
    await _settle(t);
    expect(guestEntry(t), isFalse);
    await _dispose(t);

    // Skip, then back and the arrow again: no longer a skip.
    await _pumpOnboarding(t);
    await _tapKey(t, _skip);
    await t.tap(find.descendant(of: find.byType(AgeGatePage), matching: find.byIcon(Icons.arrow_back)));
    await _settle(t);
    await _tapKey(t, _next);
    await t.tap(find.text(_enterStore));
    await _settle(t);
    expect(guestEntry(t), isFalse);
    await _dispose(t);
  });
}
