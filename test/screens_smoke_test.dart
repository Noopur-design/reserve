import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserve_liquor/data/sample_data.dart';
import 'package:reserve_liquor/screens/cart_screen.dart';
import 'package:reserve_liquor/screens/category_screen.dart';
import 'package:reserve_liquor/screens/chat_screen.dart';
import 'package:reserve_liquor/screens/checkout_screen.dart';
import 'package:reserve_liquor/screens/create_account_screen.dart';
import 'package:reserve_liquor/screens/delivery_preferences_screen.dart';
import 'package:reserve_liquor/screens/edit_profile_screen.dart';
import 'package:reserve_liquor/screens/help_screen.dart';
import 'package:reserve_liquor/screens/location_screen.dart';
import 'package:reserve_liquor/screens/main_shell.dart';
import 'package:reserve_liquor/screens/notifications_screen.dart';
import 'package:reserve_liquor/screens/onboarding_screen.dart';
import 'package:reserve_liquor/screens/order_detail_screen.dart';
import 'package:reserve_liquor/screens/order_tracking_screen.dart';
import 'package:reserve_liquor/screens/orders_screen.dart';
import 'package:reserve_liquor/screens/payment_methods_screen.dart';
import 'package:reserve_liquor/screens/product_detail_screen.dart';
import 'package:reserve_liquor/screens/responsible_drinking_screen.dart';
import 'package:reserve_liquor/screens/saved_addresses_screen.dart';
import 'package:reserve_liquor/screens/sign_in_screen.dart';
import 'package:reserve_liquor/screens/terms_screen.dart';
import 'package:reserve_liquor/screens/wishlist_screen.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/widgets/auth_gate.dart';
import 'package:reserve_liquor/widgets/common.dart';

import 'test_utils.dart';

/// Renders every screen (as a guest and as a signed-in user where they
/// differ) across common phone sizes and text scales, scrolling each one to
/// the end. Any overflow or exception fails the test.

class _Case {
  final Widget Function(AppState s) build;
  final bool signedIn;
  final String userName;

  /// Optional interaction after the first frame (open a sheet, go to the
  /// next onboarding page, ...).
  final Future<void> Function(WidgetTester t)? act;
  const _Case(this.build, {this.signedIn = false, this.userName = 'Riya Kapoor', this.act});
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump(); // start any route / page animation
  await t.pump(const Duration(seconds: 1));
}

MainShell _tab(AppState s, int i) {
  s.tabIndex = i;
  return const MainShell();
}

final _cases = <String, _Case>{
  // ---- Onboarding (pages reached through the arrow / Skip) ----
  'onboarding intro': _Case((_) => const OnboardingScreen()),
  'onboarding explore (arrow)': _Case((_) => const OnboardingScreen(),
      act: (t) => _tap(t, find.byKey(const Key('onboarding-next')))),
  'onboarding age gate (arrow)': _Case((_) => const OnboardingScreen(), act: (t) async {
    await _tap(t, find.byKey(const Key('onboarding-next')));
    await _tap(t, find.byKey(const Key('onboarding-next')));
  }),
  'onboarding age gate (skip)': _Case((_) => const OnboardingScreen(),
      act: (t) => _tap(t, find.byKey(const Key('onboarding-skip')))),
  'age gate standalone': _Case((_) => Scaffold(body: AgeGatePage(onBack: () {}))),
  'location': _Case((_) => const LocationScreen()),

  // ---- Auth ----
  'sign in': _Case((_) => const SignInScreen()),
  'sign in errors': _Case((_) => const SignInScreen(),
      act: (t) => _tap(t, find.widgetWithText(PrimaryButton, 'Sign In'))),
  'sign in forgot password': _Case((_) => const SignInScreen(),
      act: (t) => _tap(t, find.text('Forgot Password?'))),
  'sign in (from a prompt)': _Case((_) => const SignInScreen(returnOnSuccess: true)),
  'create account': _Case((_) => const CreateAccountScreen()),
  'create account errors': _Case((_) => const CreateAccountScreen(),
      act: (t) => _tap(t, find.widgetWithText(PrimaryButton, 'Create Account'))),
  'guest gate': _Case((_) => const Scaffold(body: GuestGate(header: 'My Orders'))),
  'edit profile': _Case((_) => const EditProfileScreen(), signedIn: true),
  'edit profile photo sheet': _Case((_) => const EditProfileScreen(),
      signedIn: true, act: (t) => _tap(t, find.text('Add a photo'))),
  'edit profile (guest)': _Case((_) => const EditProfileScreen()),
  'edit profile delete dialog': _Case((_) => const EditProfileScreen(), signedIn: true, act: (t) async {
    // The page's list (the text fields have scrollables of their own).
    await t.scrollUntilVisible(find.byKey(const Key('delete-account')), 200,
        scrollable: find.byType(Scrollable).first);
    await _tap(t, find.byKey(const Key('delete-account')));
  }),

  // ---- Main shell ----
  'shell home (guest)': _Case((s) => _tab(s, 0)),
  'shell home (signed in)': _Case((s) => _tab(s, 0), signedIn: true),
  'shell explore': _Case((s) => _tab(s, 1)),
  'shell search': _Case((s) => _tab(s, 2)),
  'shell orders (guest)': _Case((s) => _tab(s, 3)),
  'shell orders (signed in)': _Case((s) => _tab(s, 3), signedIn: true),
  'shell profile (guest)': _Case((s) => _tab(s, 4)),
  'shell profile (signed in)': _Case((s) => _tab(s, 4), signedIn: true),
  'shell profile (long name)': _Case((s) => _tab(s, 4),
      signedIn: true, userName: 'Venkataraghavan Subramaniam Iyer'),

  // ---- Catalogue / cart ----
  'category whisky': _Case((_) => CategoryScreen(category: categoryById('whisky'))),
  'category beer': _Case((_) => CategoryScreen(category: categoryById('beer'))),
  'product detail': _Case((_) => ProductDetailScreen(product: productById('macallan18'))),
  'cart (guest)': _Case((_) => const CartScreen()),
  'cart (guest) sign-in sheet': _Case((_) => const CartScreen(),
      act: (t) => _tap(t, find.widgetWithText(PrimaryButton, 'Proceed to Checkout'))),
  'cart (signed in)': _Case((_) => const CartScreen(), signedIn: true),
  'checkout': _Case((_) => const CheckoutScreen(), signedIn: true),
  'wishlist': _Case((_) => const WishlistScreen()),
  'wishlist (no matches)': _Case((_) => const WishlistScreen(), act: (t) async {
    await t.enterText(find.byType(TextField), 'no such bottle');
    await t.pump(const Duration(seconds: 1));
  }),

  // ---- Orders ----
  'orders': _Case((_) => const OrdersScreen(), signedIn: true),
  'orders (quantities)': _Case((s) {
    // 4 products, 7 bottles: exercises the "+N" tile and "×N" badges.
    s.addToCart(productById('macallan18'), 2);
    s.addToCart(productById('jameson'), 3);
    s.placeOrder();
    return const OrdersScreen();
  }, signedIn: true),
  'tracking': _Case((s) => OrderTrackingScreen(order: s.orders[1]), signedIn: true),
  'tracking packed': _Case((s) => OrderTrackingScreen(order: s.orders[2]), signedIn: true),
  'delivered': _Case((s) => OrderDetailScreen(order: s.orders[0]), signedIn: true),
  'cancelled': _Case((s) => OrderDetailScreen(order: s.orders[4]), signedIn: true),

  // ---- Account & support ----
  'addresses': _Case((_) => const SavedAddressesScreen(), signedIn: true),
  'payment methods': _Case((_) => const PaymentMethodsScreen(), signedIn: true),
  'delivery prefs': _Case((_) => const DeliveryPreferencesScreen(), signedIn: true),
  'notifications': _Case((_) => const NotificationsScreen(), signedIn: true),
  'responsible': _Case((_) => const ResponsibleDrinkingScreen()),
  'help': _Case((_) => const HelpScreen()),
  'chat': _Case((_) => const ChatScreen()),
  'terms': _Case((_) => const TermsScreen()),
  'policy': _Case((_) => const PolicyDetailScreen(index: 1)),
};

void main() {
  setUpAll(loadAppFonts);

  const sizes = [Size(360, 740), Size(393, 851), Size(412, 915), Size(440, 956)];
  const scales = [1.0, 1.15];

  for (final size in sizes) {
    for (final scale in scales) {
      final label = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';
      for (final entry in _cases.entries) {
        final c = entry.value;
        testWidgets('${entry.key} renders ($label)', (tester) async {
          setScreen(tester, size, textScale: scale);
          final state = c.signedIn ? signedInState(name: c.userName) : AppState();
          final page = c.build(state);
          double? seenScale;
          await tester.pumpWidget(appHarness(
            state,
            Builder(builder: (context) {
              seenScale = MediaQuery.textScalerOf(context).scale(1);
              return page;
            }),
          ));
          await tester.pump(const Duration(seconds: 2));
          // The app's clamp must not hide the scale under test.
          expect(seenScale, closeTo(scale, 1e-9));

          if (c.act != null) {
            await c.act!(tester);
            await tester.pump(const Duration(seconds: 1));
          }

          await scrollThroughAll(tester);

          // No takeException() here on purpose: flutter_test fails the test on
          // any reported error (overflow included) and prints the widget that
          // caused it, which takeException() would swallow.

          // Tear down so repeating animations/timers are disposed.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        });
      }
    }
  }

  testWidgets('checkout walks through all three steps', (tester) async {
    setScreen(tester, const Size(412, 915));
    final state = signedInState();
    await tester.pumpWidget(appHarness(state, const CheckoutScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Continue to Delivery'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Delivery Options'), findsOneWidget);
    await tester.tap(find.text('Continue to Payment'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(find.text('Place Order'), findsOneWidget);
  });
}
