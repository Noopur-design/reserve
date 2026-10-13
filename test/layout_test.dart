import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserve_liquor/data/sample_data.dart';
import 'package:reserve_liquor/screens/cart_screen.dart';
import 'package:reserve_liquor/screens/chat_screen.dart';
import 'package:reserve_liquor/screens/checkout_screen.dart';
import 'package:reserve_liquor/screens/delivery_preferences_screen.dart';
import 'package:reserve_liquor/screens/help_screen.dart';
import 'package:reserve_liquor/screens/main_shell.dart';
import 'package:reserve_liquor/screens/notifications_screen.dart';
import 'package:reserve_liquor/screens/onboarding_screen.dart';
import 'package:reserve_liquor/screens/order_detail_screen.dart';
import 'package:reserve_liquor/screens/payment_methods_screen.dart';
import 'package:reserve_liquor/screens/product_detail_screen.dart';
import 'package:reserve_liquor/screens/responsible_drinking_screen.dart';
import 'package:reserve_liquor/screens/terms_screen.dart';
import 'package:reserve_liquor/screens/wishlist_screen.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/widgets/common.dart';

import 'test_utils.dart';

/// Text that is cut off, broken mid-word, shrunk to unreadable sizes or runs
/// under a picture. None of these is a layout error, so the smoke test can't
/// see them; these tests check the places where they happened on narrow
/// phones (360dp) and with large text (1.15x).

Future<void> _show(WidgetTester t, AppState state, Widget page) async {
  await t.pumpWidget(appHarness(state, page));
  // Two frames: fade-in animations start on the first and finish by the second.
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _dispose(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(loadAppFonts);

  const cases = [(Size(360, 740), 1.0), (Size(360, 740), 1.15), (Size(393, 851), 1.15)];

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}dp @${scale}x';

    testWidgets('Home header: wordmark on one line, city never cut off ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      final state = signedInState()..tabIndex = 0;
      await _show(t, state, const MainShell());
      expectTextFits(t, find.text('RESERVE'));
      final place = find.textContaining('Gurugram');
      expectTextFits(t, place);
      // Same spelling as Profile and the saved addresses.
      expect(t.widget<Text>(place).textSpan!.toPlainText(), contains(state.cityLabel.split(',').first));
      await _dispose(t);
    });

    testWidgets('Home buttons and category tiles show their whole label ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      await _show(t, AppState(), const MainShell());
      for (final text in ['Shop Collection', 'Explore Premium']) {
        await t.ensureVisible(find.text(text));
        await t.pump();
        expectTextFits(t, find.text(text));
        expect(shownScale(t, find.text(text)), greaterThanOrEqualTo(0.79), reason: '$text shrunk too far');
      }
      await t.ensureVisible(find.text('Whisky'));
      await t.pump();
      final row = t.state<ScrollableState>(find.ancestor(of: find.text('Whisky'), matching: find.byType(Scrollable)).first);
      final seen = <String>{};
      for (final offset in [0.0, row.position.maxScrollExtent]) {
        row.position.jumpTo(offset);
        await t.pump();
        for (final c in categories) {
          if (find.text(c.name).evaluate().isEmpty) continue;
          expectTextFits(t, find.text(c.name));
          seen.add(c.name);
        }
      }
      expect(seen, hasLength(categories.length));
      await _dispose(t);
    });

    testWidgets('onboarding logo fits on one line ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      await _show(t, AppState(), const OnboardingScreen());
      expectTextFits(t, find.text('RESERVE'));
      expectTextFits(t, find.text('SPIRITS  ·  WINE  ·  BEYOND'));
      for (final text in ['RESERVE', 'SPIRITS  ·  WINE  ·  BEYOND']) {
        final r = t.getRect(find.text(text).first);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
      }
      await _dispose(t);
    });

    testWidgets('saved payment rows keep bank name and number readable ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      await _show(t, signedInState(), const PaymentMethodsScreen());
      for (final text in ['HDFC Bank', '•••• 4242', 'ICICI Bank', '•••• 7681', 'Default']) {
        expectTextFits(t, find.text(text));
      }
      await _dispose(t);
    });

    testWidgets('Responsible Drinking header shows all of its text ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      await _show(t, AppState(), const ResponsibleDrinkingScreen());
      expectTextFits(t, find.text('Enjoy\nmindfully'));
      final sub = find.text('Good moments begin with responsible choices.');
      final header = find.ancestor(of: sub, matching: find.byType(Stack)).first;
      expect(t.getRect(sub).bottom, lessThanOrEqualTo(t.getRect(header).bottom), reason: 'subtitle clipped');
      await _dispose(t);
    });

    testWidgets('button labels are never cut off ($label)', (t) async {
      setScreen(t, size, textScale: scale);

      await _show(t, AppState(), ProductDetailScreen(product: productById('hendricks')));
      expectTextFits(t, find.text('Add to Cart'));
      // The price is shown at full size, not squeezed next to the stepper.
      expect(shownScale(t, find.text('₹4,850').first), closeTo(1, 0.01));
      await _dispose(t);

      await _show(t, AppState(), const CartScreen());
      expectTextFits(t, find.text('Proceed to Checkout'));
      await _dispose(t);

      await _show(t, signedInState(), const CheckoutScreen());
      expectTextFits(t, find.text('Continue to Delivery'));
      await t.tap(find.text('Continue to Delivery'));
      await t.pump(const Duration(seconds: 1));
      expectTextFits(t, find.text('Continue to Payment'));
      await t.tap(find.text('Continue to Payment'));
      await t.pump(const Duration(seconds: 1));
      expectTextFits(t, find.text('Place Order'));
      await _dispose(t);

      final s = signedInState();
      await _show(t, s, OrderDetailScreen(order: s.orders[0]));
      expectTextFits(t, find.text('Buy Again'));
      expectTextFits(t, find.text('Reorder'));
      await _dispose(t);

      await _show(t, AppState(), const Scaffold(body: AgeGatePage(onBack: _noop)));
      expectTextFits(t, find.text('I am 18+  ·  Enter Store'));
      await _dispose(t);
    });

    testWidgets('a long name on Profile stays readable ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      const name = 'Venkataraghavan Subramaniam Iyer';
      final state = signedInState(name: name)..tabIndex = 4;
      await _show(t, state, const MainShell());
      // Wraps at spaces (never mid-word), all of it visible.
      expectNoBrokenWords(t, find.text(name));
      expect(t.widget<Text>(find.text(name)).style!.fontSize, greaterThanOrEqualTo(14));
      expect(shownScale(t, find.text(name)), closeTo(1, 0.001));
      await _dispose(t);
    });

    testWidgets('header card text never runs under the illustration ($label)', (t) async {
      setScreen(t, size, textScale: scale);
      for (final page in const <Widget>[
        HelpScreen(),
        ChatScreen(),
        NotificationsScreen(),
        DeliveryPreferencesScreen(),
        TermsScreen(),
      ]) {
        await _show(t, signedInState(), page);
        final card = find.byType(IllustratedCard);
        expect(card, findsOneWidget, reason: '${page.runtimeType}');
        final image = t.getRect(find.descendant(of: card, matching: find.byType(Image)));
        final texts = find.descendant(of: card, matching: find.byType(RichText));
        for (final e in texts.evaluate()) {
          final r = t.getRect(find.byElementPredicate((x) => x == e));
          expect(r.right, lessThanOrEqualTo(image.left + 0.5),
              reason: '${page.runtimeType}: "${(e.widget as RichText).text.toPlainText()}" runs under the picture');
        }
        expectNoBrokenWords(t, texts);
        await _dispose(t);
      }
    });
  }

  testWidgets('Home header keeps "Delivering to" where there is room for it', (t) async {
    setScreen(t, const Size(412, 915));
    await _show(t, signedInState()..tabIndex = 0, const MainShell());
    expect(find.textContaining('Delivering to Gurugram'), findsOneWidget);
    expectTextFits(t, find.textContaining('Delivering to'));
    await _dispose(t);
  });

  testWidgets('wishlist search with no match fits above the keyboard and says so', (t) async {
    setScreen(t, const Size(360, 740), textScale: 1.15);
    t.view.viewInsets = const FakeViewPadding(bottom: 320 * 3); // a tall keyboard
    addTearDown(t.view.resetViewInsets);
    await _show(t, AppState(), const WishlistScreen());
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump(const Duration(seconds: 1));
    expect(find.text('No matching items'), findsOneWidget);
    expect(find.text('Nothing in your wishlist matches "zzz".'), findsOneWidget);
    expect(find.text('Your wishlist is empty'), findsNothing);
    await _dispose(t);
  });
}

void _noop() {}
