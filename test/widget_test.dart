import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reserve_liquor/data/sample_data.dart';
import 'package:reserve_liquor/main.dart';
import 'package:reserve_liquor/screens/cart_screen.dart';
import 'package:reserve_liquor/screens/checkout_screen.dart';
import 'package:reserve_liquor/screens/create_account_screen.dart';
import 'package:reserve_liquor/screens/edit_profile_screen.dart';
import 'package:reserve_liquor/screens/help_screen.dart';
import 'package:reserve_liquor/screens/location_screen.dart';
import 'package:reserve_liquor/screens/main_shell.dart';
import 'package:reserve_liquor/screens/onboarding_screen.dart';
import 'package:reserve_liquor/screens/order_tracking_screen.dart';
import 'package:reserve_liquor/screens/orders_screen.dart';
import 'package:reserve_liquor/screens/payment_methods_screen.dart';
import 'package:reserve_liquor/screens/sign_in_screen.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_utils.dart';

/// Start-up routing and the sign-in / guest flows, driven through the UI.

/// Builds the app the way main() does, from whatever is in storage.
Future<AppState> _launch(WidgetTester t) async {
  // Flush pending storage writes (pumpEventQueue would hang under the
  // widget tester's fake clock).
  await t.pump();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final state = await AppState.load();
  await t.pumpWidget(ChangeNotifierProvider.value(value: state, child: const ReserveApp()));
  await t.pump(const Duration(seconds: 1));
  return state;
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settle(t);
}

Future<void> _dispose(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

/// The mobile number field on the sign-in / create-account pages.
Finder _phoneField() => find.descendant(
    of: find.ancestor(of: find.text('+91'), matching: find.byType(AuthInput)), matching: find.byType(TextField));

/// Fills in Create Account (password "secret1") and ticks the age box.
Future<void> _fillCreateAccount(WidgetTester t, {required String name, required String phone}) async {
  await t.enterText(find.widgetWithText(TextField, 'Full name'), name);
  await t.enterText(_phoneField(), '');
  await t.enterText(_phoneField(), phone);
  await t.enterText(find.widgetWithText(TextField, 'Create password'), 'secret1');
  await t.enterText(find.widgetWithText(TextField, 'Confirm password'), 'secret1');
  final box = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AgeCheckbox');
  await t.ensureVisible(box);
  await t.tapAt(t.getTopLeft(box) + const Offset(13, 13));
  await _settle(t);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a fresh install starts on onboarding', (t) async {
    setScreen(t, const Size(412, 915));
    await _launch(t);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('RESERVE'), findsWidgets);
    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('first run with Skip: age gate → city → the store as a guest, no profile made', (t) async {
    setScreen(t, const Size(412, 915));
    final state = await _launch(t);
    await _tap(t, find.byKey(const Key('onboarding-skip')));
    await _tap(t, find.text('I am 18+  ·  Enter Store'));
    expect(find.byType(LocationScreen), findsOneWidget);
    expect(state.onboarded, isTrue);
    await _tap(t, find.widgetWithText(PrimaryButton, 'Continue'));
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
    expect(state.isGuest, isTrue);
    await t.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accounts'), isNull);
    expect(prefs.getString('session_phone'), isNull);
    await _dispose(t);
  });

  testWidgets('first run without Skip: the store asks to sign in or create an account', (t) async {
    setScreen(t, const Size(412, 915));
    final state = await _launch(t);
    await _tap(t, find.byKey(const Key('onboarding-next')));
    await _tap(t, find.byKey(const Key('onboarding-next')));
    await _tap(t, find.text('I am 18+  ·  Enter Store'));
    // Skipping only the city step still leads to sign in.
    await _tap(t, find.widgetWithText(TextButton, 'Skip'));
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(state.isGuest, isTrue);
    expect(find.text('Create Account'), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('after onboarding, a signed-out user must sign in (or skip) to enter', (t) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    setScreen(t, const Size(412, 915));
    await _launch(t);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    await _dispose(t);
  });

  testWidgets('a saved session opens the app as that user', (t) async {
    setScreen(t, const Size(412, 915));
    final first = await AppState.load();
    expect(first.createAccount(name: 'Arjun Mehra', phone: '9876543210', password: 'secret1'), isNull);

    await _launch(t);
    expect(find.byType(MainShell), findsOneWidget);
    // Home header shows the user's own avatar (initials, no stock photo).
    expect(find.text('AM'), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('Skip on sign in browses as a guest without creating a profile', (t) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    setScreen(t, const Size(412, 915));
    final state = await _launch(t);
    await _tap(t, find.text('Skip'));
    expect(find.byType(MainShell), findsOneWidget);
    expect(state.isGuest, isTrue);
    expect(state.user, isNull);

    // Account-only areas ask the guest to sign in.
    state.setTab(3);
    await _settle(t);
    expect(find.text('Sign in to see your orders'), findsOneWidget);
    state.setTab(4);
    await _settle(t);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Sign in to check out, track your orders and manage your profile'), findsOneWidget);

    await t.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accounts'), isNull);
    expect(prefs.getString('session_phone'), isNull);
    await _dispose(t);

    // Guests are not remembered: the next launch asks to sign in again.
    await _launch(t);
    expect(find.byType(SignInScreen), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('an unknown number is offered Create Account, which signs straight in', (t) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    setScreen(t, const Size(412, 915));
    final state = await _launch(t);

    await t.enterText(find.widgetWithText(TextField, 'Mobile number'), '9876543210');
    await t.enterText(find.widgetWithText(TextField, 'Enter your password'), 'secret1');
    await _tap(t, find.widgetWithText(PrimaryButton, 'Sign In'));
    expect(find.text('No account found'), findsOneWidget);
    expect(state.isGuest, isTrue, reason: 'no way in without an account');

    await _tap(t, find.descendant(of: find.byType(AlertDialog), matching: find.text('Create Account')));
    expect(find.byType(CreateAccountScreen), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget, reason: 'number carried over');

    await t.enterText(find.widgetWithText(TextField, 'Full name'), 'Arjun Mehra');
    await t.enterText(find.widgetWithText(TextField, 'Create password'), 'secret1');
    await t.enterText(find.widgetWithText(TextField, 'Confirm password'), 'secret1');

    // The legal-age / terms box is required.
    await _tap(t, find.widgetWithText(PrimaryButton, 'Create Account'));
    expect(find.text('Please confirm to continue'), findsOneWidget);
    expect(state.isGuest, isTrue);

    final box = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AgeCheckbox');
    await t.ensureVisible(box);
    await t.tapAt(t.getTopLeft(box) + const Offset(13, 13));
    await _settle(t);
    await _tap(t, find.widgetWithText(PrimaryButton, 'Create Account'));
    await _settle(t);

    expect(find.byType(MainShell), findsOneWidget);
    expect(state.isSignedIn, isTrue);
    expect(state.user!.name, 'Arjun Mehra');
    state.setTab(4);
    await _settle(t);
    expect(find.text('Arjun Mehra'), findsOneWidget);
    await _dispose(t);

    // Remembered on the next launch.
    final again = await _launch(t);
    expect(find.byType(MainShell), findsOneWidget);
    expect(again.user!.name, 'Arjun Mehra');
    await _dispose(t);
  });

  testWidgets('guests must sign in before checking out', (t) async {
    setScreen(t, const Size(412, 915));
    final state = AppState()..continueAsGuest();
    await t.pumpWidget(appHarness(state, const CartScreen()));
    await t.pump(const Duration(seconds: 1));
    await _tap(t, find.widgetWithText(PrimaryButton, 'Proceed to Checkout'));
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.byType(CheckoutScreen), findsNothing);

    await _tap(t, find.widgetWithText(OutlineButtonX, 'Create Account'));
    expect(find.byType(CreateAccountScreen), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('a guest who signs in at checkout carries on to checkout', (t) async {
    setScreen(t, const Size(412, 915));
    final state = AppState();
    expect(state.createAccount(name: 'Arjun Mehra', phone: '9876543210', password: 'secret1'), isNull);
    state.signOut(); // an existing account, browsing as a guest
    await t.pumpWidget(appHarness(state, const CartScreen()));
    await t.pump(const Duration(seconds: 1));

    await _tap(t, find.widgetWithText(PrimaryButton, 'Proceed to Checkout'));
    await _tap(t, find.widgetWithText(PrimaryButton, 'Sign In'));
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing, reason: 'back returns to the cart instead');

    await t.enterText(_phoneField(), '9876543210');
    await t.enterText(find.widgetWithText(TextField, 'Enter your password'), 'secret1');
    await _tap(t, find.widgetWithText(PrimaryButton, 'Sign In'));
    await _settle(t);
    expect(state.isSignedIn, isTrue);
    expect(find.byType(CheckoutScreen), findsOneWidget);

    // The cart is still underneath (no restart on Home).
    await _tap(t, find.byIcon(Icons.arrow_back).last);
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    await _dispose(t);
  });

  testWidgets('a guest who creates an account at checkout carries on to checkout', (t) async {
    setScreen(t, const Size(412, 915));
    final state = AppState()..continueAsGuest();
    await t.pumpWidget(appHarness(state, const CartScreen()));
    await t.pump(const Duration(seconds: 1));

    await _tap(t, find.widgetWithText(PrimaryButton, 'Proceed to Checkout'));
    await _tap(t, find.widgetWithText(OutlineButtonX, 'Create Account'));
    expect(find.byType(CreateAccountScreen), findsOneWidget);
    await _fillCreateAccount(t, name: 'Arjun Mehra', phone: '9876543210');
    await _tap(t, find.widgetWithText(PrimaryButton, 'Create Account'));
    await _settle(t);

    expect(state.isSignedIn, isTrue);
    expect(find.byType(CheckoutScreen), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('pasted or autofilled numbers with +91 or a leading 0 keep the right digits', (t) async {
    setScreen(t, const Size(412, 915));
    final state = AppState();
    expect(state.createAccount(name: 'Arjun Mehra', phone: '9876543210', password: 'secret1'), isNull);
    state.signOut();
    await t.pumpWidget(appHarness(state, const SignInScreen()));
    await t.pump(const Duration(seconds: 1));

    String phoneText() => t.widget<TextField>(_phoneField()).controller!.text;
    for (final (input, expected) in [
      ('+91 98765 43210', '9876543210'),
      ('+91-91234-56789', '9123456789'),
      ('09876543210', '9876543210'),
      ('0091 98765 43210', '9876543210'),
      ('98765 43210', '9876543210'),
      ('987654321099', '9876543210'),
    ]) {
      await t.enterText(_phoneField(), '');
      await t.enterText(_phoneField(), input);
      await t.pump();
      expect(phoneText(), expected, reason: input);
    }
    // Typing past a full number keeps it.
    await t.enterText(_phoneField(), '98765432105');
    expect(phoneText(), '9876543210');

    // A pasted +91 number signs in to the right account.
    await t.enterText(_phoneField(), '');
    await t.enterText(_phoneField(), '+91 98765 43210');
    await t.enterText(find.widgetWithText(TextField, 'Enter your password'), 'secret1');
    await _tap(t, find.widgetWithText(PrimaryButton, 'Sign In'));
    await _settle(t);
    expect(state.isSignedIn, isTrue);
    expect(state.user!.phone, '9876543210');
    await _dispose(t);

    // Create Account registers the pasted number, not "9198765432".
    final fresh = AppState();
    await t.pumpWidget(appHarness(fresh, const CreateAccountScreen()));
    await t.pump(const Duration(seconds: 1));
    await _fillCreateAccount(t, name: 'Neha Rao', phone: '+91 91234 56789');
    expect(t.widget<TextField>(_phoneField()).controller!.text, '9123456789');
    await _tap(t, find.widgetWithText(PrimaryButton, 'Create Account'));
    await _settle(t);
    expect(fresh.accountExists('9123456789'), isTrue);
    expect(fresh.user!.phone, '9123456789');
    await _dispose(t);
  });

  testWidgets('Delete account in Edit Profile removes the account and signs out', (t) async {
    setScreen(t, const Size(412, 915));
    final first = await AppState.load();
    expect(first.createAccount(name: 'Arjun Mehra', phone: '9876543210', password: 'secret1'), isNull);
    final state = await _launch(t);
    state.setTab(4);
    await _settle(t);
    await _tap(t, find.byIcon(Icons.settings_outlined));
    expect(find.text('Edit Profile'), findsOneWidget);

    // Cancelling keeps everything.
    await t.scrollUntilVisible(find.byKey(const Key('delete-account')), 200,
        scrollable: find.descendant(of: find.byType(EditProfileScreen), matching: find.byType(Scrollable)).first);
    await _tap(t, find.byKey(const Key('delete-account')));
    expect(find.text('Delete your account?'), findsOneWidget);
    await _tap(t, find.text('Cancel'));
    expect(state.isSignedIn, isTrue);

    await _tap(t, find.byKey(const Key('delete-account')));
    await _tap(t, find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(state.isGuest, isTrue);
    expect(state.accountExists('9876543210'), isFalse);
    await _dispose(t);

    // Gone after a restart too.
    final again = await _launch(t);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(again.accountExists('9876543210'), isFalse);
    await _dispose(t);
  });

  testWidgets('order pages say "1 item" for a single bottle', (t) async {
    setScreen(t, const Size(412, 915));
    final state = signedInState();
    final single = state.orders.firstWhere((o) => o.id == '#8124091654');
    await t.pumpWidget(appHarness(state, OrderTrackingScreen(order: single)));
    await t.pump(const Duration(seconds: 1));
    await t.scrollUntilVisible(find.textContaining('1 item  •'), 200);
    expect(find.textContaining('1 items'), findsNothing);
    await _dispose(t);
  });

  testWidgets('Help › Payments asks guests to sign in instead of opening saved cards', (t) async {
    setScreen(t, const Size(412, 915));
    final state = AppState()..continueAsGuest();
    await t.pumpWidget(appHarness(state, const HelpScreen()));
    await t.pump(const Duration(seconds: 1));
    await _tap(t, find.text('Payments'));
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.byType(PaymentMethodsScreen), findsNothing);
    await _dispose(t);
  });

  testWidgets('signed-in users go straight to checkout', (t) async {
    setScreen(t, const Size(412, 915));
    final state = signedInState();
    await t.pumpWidget(appHarness(state, const CartScreen()));
    await t.pump(const Duration(seconds: 1));
    await _tap(t, find.widgetWithText(PrimaryButton, 'Proceed to Checkout'));
    expect(find.byType(CheckoutScreen), findsOneWidget);
    await _dispose(t);
  });

  testWidgets('My Orders counts every bottle, not just every product', (t) async {
    setScreen(t, const Size(412, 915));
    final state = signedInState();
    state.addToCart(productById('macallan18'), 2);
    state.addToCart(productById('jameson'), 3);
    final order = state.placeOrder(); // + the sample cart's two single bottles
    expect(order.items.length, 4);
    expect(order.itemCount, 7);

    await t.pumpWidget(appHarness(state, const OrdersScreen()));
    await t.pump(const Duration(seconds: 1));
    final nbsp = String.fromCharCode(0xA0);
    expect(find.textContaining('7${nbsp}items'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    await _dispose(t);
  });

  test('Cart totals match the reference design', () {
    final s = AppState();
    expect(s.subtotal, 8349);
    expect(s.deliveryFee, 99);
    expect(s.taxes, 142);
    expect(s.total, 8590);
  });
}
