import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserve_liquor/data/models.dart';
import 'package:reserve_liquor/data/sample_data.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device accounts, guest mode and profile persistence (AppState).

const _phone = '9876543210';
const _password = 'secret1';

/// Lets pending writes land, re-reads storage and builds a new store, the
/// way the app starts on the next launch.
Future<AppState> _relaunch() async {
  await pumpEventQueue();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return AppState.load();
}

Future<SharedPreferences> _storage() async {
  await pumpEventQueue();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs;
}

Future<AppState> _withAccount({String name = 'Arjun Mehra'}) async {
  final s = await AppState.load();
  expect(s.createAccount(name: name, phone: _phone, email: 'arjun@example.com', password: _password), isNull);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install is a guest that has not seen onboarding', () async {
    final s = await AppState.load();
    expect(s.onboarded, isFalse);
    expect(s.isGuest, isTrue);
    expect(s.user, isNull);
    expect(s.userName, 'Guest');
  });

  test('createAccount signs in and is remembered after a restart', () async {
    final s = await _withAccount();
    expect(s.isSignedIn, isTrue);
    expect(s.user!.name, 'Arjun Mehra');
    expect(s.user!.phone, _phone);
    expect(s.user!.email, 'arjun@example.com');
    expect(s.user!.initials, 'AM');
    expect(s.onboarded, isTrue);

    final again = await _relaunch();
    expect(again.isSignedIn, isTrue);
    expect(again.user!.name, 'Arjun Mehra');
    expect(again.user!.email, 'arjun@example.com');
    expect(again.accountExists(_phone), isTrue);
    expect(again.accountExists('+91 98765 43210'), isTrue);
    expect(again.onboarded, isTrue);
  });

  test('createAccount validates its input', () async {
    final s = await AppState.load();
    expect(s.createAccount(name: 'A', phone: _phone, password: _password), 'Enter your full name');
    expect(s.createAccount(name: 'Arjun', phone: '12345', password: _password),
        'Enter a valid 10-digit mobile number');
    expect(s.createAccount(name: 'Arjun', phone: '5876543210', password: _password),
        'Enter a valid 10-digit mobile number');
    expect(s.createAccount(name: 'Arjun', phone: _phone, email: 'not-an-email', password: _password),
        'Enter a valid email address');
    expect(s.createAccount(name: 'Arjun', phone: _phone, password: '12345'),
        'Password must be at least 6 characters');
    expect(s.isGuest, isTrue);
    expect(s.accountExists(_phone), isFalse);
  });

  test('a phone number can only be registered once', () async {
    final s = await _withAccount();
    s.signOut();
    // Same number in another format.
    expect(s.createAccount(name: 'Someone Else', phone: '+91 98765 43210', password: 'other12'),
        'An account with this number already exists. Sign in instead.');
    expect(s.isGuest, isTrue);
    // The original account is untouched.
    expect(s.signIn(_phone, _password), isNull);
    expect(s.user!.name, 'Arjun Mehra');
  });

  test('signIn tells an unknown number apart from a wrong password', () async {
    final s = await _withAccount();
    s.signOut();
    expect(s.signIn('9123456789', _password), 'No account found for this number. Create an account to continue.');
    expect(s.signIn(_phone, 'wrong-password'), 'Incorrect password. Please try again.');
    expect(s.signIn('123', _password), 'Enter a valid 10-digit phone number');
    expect(s.isGuest, isTrue);

    expect(s.signIn(_phone, _password), isNull);
    expect(s.isSignedIn, isTrue);
    expect((await _relaunch()).isSignedIn, isTrue);
  });

  test('passwords are only stored as salted hashes', () async {
    const secret = 'Sup3r-Secret!';
    final s = await AppState.load();
    expect(s.createAccount(name: 'Arjun Mehra', phone: _phone, password: secret), isNull);
    expect(s.createAccount(name: 'Neha Rao', phone: '9123456789', password: secret), isNull);

    final prefs = await _storage();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains(secret)), reason: 'prefs[$key] holds the password');
    }
    final accounts = jsonDecode(prefs.getString('accounts')!) as Map<String, dynamic>;
    final a = accounts[_phone] as Map<String, dynamic>;
    final b = accounts['9123456789'] as Map<String, dynamic>;
    expect(a['passwordHash'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a['salt'], isNotEmpty);
    expect(a['salt'], isNot(b['salt']));
    // Same password, different salt, different hash.
    expect(a['passwordHash'], isNot(b['passwordHash']));
  });

  test('continuing as a guest creates no profile and is not remembered', () async {
    final s = await AppState.load();
    s.continueAsGuest();
    expect(s.isGuest, isTrue);
    expect(s.user, isNull);
    expect(s.userName, 'Guest');
    expect(s.onboarded, isTrue);

    final prefs = await _storage();
    expect(prefs.getString('accounts'), isNull, reason: 'no account may be created for a guest');
    expect(prefs.getString('session_phone'), isNull);

    final again = await _relaunch();
    expect(again.isGuest, isTrue);
    expect(again.onboarded, isTrue, reason: 'onboarding is not shown again');
  });

  test('guests cannot edit a profile', () async {
    final s = await AppState.load();
    s.continueAsGuest();
    s.updateProfile(name: 'Hacker', email: 'x@example.com');
    expect(s.user, isNull);
    expect(s.userName, 'Guest');
    expect((await _storage()).getString('accounts'), isNull);
  });

  test('signing out ends the session but keeps the account', () async {
    final s = await _withAccount();
    s.signOut();
    expect(s.isGuest, isTrue);
    expect(s.accountExists(_phone), isTrue);
    expect((await _storage()).getString('session_phone'), isNull);

    final again = await _relaunch();
    expect(again.isGuest, isTrue);
    expect(again.accountExists(_phone), isTrue);
    expect(again.signIn(_phone, _password), isNull);
    expect(again.user!.name, 'Arjun Mehra');
  });

  test('updateProfile saves name, email and photo', () async {
    final s = await _withAccount();
    s.updateProfile(name: '  Arjun   K  Mehra ', email: ' arjun.k@example.com ', photoPath: '/data/avatar_1.jpg');
    expect(s.user!.name, 'Arjun K Mehra');
    expect(s.user!.email, 'arjun.k@example.com');

    var again = await _relaunch();
    expect(again.user!.name, 'Arjun K Mehra');
    expect(again.user!.email, 'arjun.k@example.com');
    expect(again.user!.photoPath, '/data/avatar_1.jpg');

    // A blank name is ignored; the photo can be removed.
    again.updateProfile(name: '   ', clearPhoto: true);
    again = await _relaunch();
    expect(again.user!.name, 'Arjun K Mehra');
    expect(again.user!.photoPath, isNull);
  });

  test('the user\'s own addresses and UPI handles follow the signed-in user', () async {
    final s = await _withAccount();
    Iterable<String> own(AppState st) => st.addresses.where((a) => a.id == 'a1' || a.id == 'a2').map((a) => a.name);
    expect(own(s), everyElement('Arjun Mehra'));
    expect(s.addresses.firstWhere((a) => a.id == 'a1').phone, '+91 98765 43210');
    // Other people's addresses keep their own names.
    expect(s.addresses.firstWhere((a) => a.id == 'a4').name, 'Neha Sharma');
    expect(s.savedPayments.firstWhere((p) => p.id == 'p3').subtitle, 'arjun.mehra@okicici');

    s.updateProfile(name: 'Arjun Singh');
    expect(own(s), everyElement('Arjun Singh'));
    expect(own(await _relaunch()), everyElement('Arjun Singh'));

    s.signOut();
    expect(own(s), everyElement('Guest'));
    expect(s.addresses.firstWhere((a) => a.id == 'a1').phone, isEmpty);
  });

  test('deleteAccount removes the account from the phone and signs out', () async {
    final s = await _withAccount();
    s.deleteAccount();
    expect(s.isGuest, isTrue);
    expect(s.accountExists(_phone), isFalse);
    expect(s.signIn(_phone, _password), 'No account found for this number. Create an account to continue.');

    final prefs = await _storage();
    expect(prefs.getString('session_phone'), isNull);
    expect(jsonDecode(prefs.getString('accounts')!), isEmpty);

    final again = await _relaunch();
    expect(again.isGuest, isTrue);
    expect(again.accountExists(_phone), isFalse);
    // The number is free to register again.
    expect(again.createAccount(name: 'Arjun Mehra', phone: _phone, password: 'another1'), isNull);
  });

  test('deleteAccount is a no-op for guests', () async {
    final s = await _withAccount();
    s.signOut();
    s.deleteAccount();
    expect(s.accountExists(_phone), isTrue);
  });

  test('signing out resets the session\'s shopping data for the next person', () async {
    final s = await _withAccount();
    s.clearCart();
    s.addToCart(productById('macallan18'), 2);
    final order = s.placeOrder();
    s.toggleWish(productById('jameson'));
    s.saveAddress(Address(id: 'a9', name: 'Arjun Mehra', line1: '1 Private Lane', line2: 'Pune', phone: '+91 98765 43210'));
    s.addPayment(PaymentCard('p9', 'Axis Bank', '•••• 1111', 'assets/images/logo_visa.jpg'));
    s.addRecentSearch('something private');

    s.signOut();
    expect(s.orders.map((o) => o.id), isNot(contains(order.id)));
    expect(s.orders, hasLength(5), reason: 'back to the demo sample orders');
    expect(s.cart.map((c) => c.product.id), ['monkey', 'hendricks']);
    expect(s.wishlist, isNot(contains('jameson')));
    expect(s.addresses.map((a) => a.id), isNot(contains('a9')));
    expect(s.savedPayments.map((p) => p.id), isNot(contains('p9')));
    expect(s.recentSearches, isNot(contains('something private')));

    // The next account starts from the same demo data.
    expect(s.createAccount(name: 'Neha Rao', phone: '9123456789', password: _password), isNull);
    expect(s.orders.map((o) => o.id), isNot(contains(order.id)));
    expect(s.addresses.firstWhere((a) => a.id == 'a1').name, 'Neha Rao');
  });

  test('a placed order keeps the address it was sent to', () async {
    final s = await _withAccount();
    final order = s.placeOrder();
    expect(order.address.name, 'Arjun Mehra');
    expect(order.address.line1, 'Flat 502, DLF Phase 4');

    s.updateProfile(name: 'Arjun Singh');
    s.saveAddress(Address(
        id: 'a1', name: 'Arjun Singh', line1: 'New Flat 9', line2: 'Gurugram, Haryana - 122002', phone: '+91 98765 43210'));
    expect(order.address.name, 'Arjun Mehra');
    expect(order.address.line1, 'Flat 502, DLF Phase 4');
    expect(order.address.phone, '+91 98765 43210');
  });

  test('a Home address edited to deliver to someone else is not overwritten', () async {
    final s = await _withAccount();
    s.saveAddress(Address(
        id: 'a1',
        name: 'Riya (Mom)',
        line1: 'Flat 502, DLF Phase 4',
        line2: 'Gurugram, Haryana - 122002',
        phone: '+91 99999 00000'));
    s.updateProfile(photoPath: '/data/avatar_2.jpg');
    s.updateProfile(name: 'Arjun Singh');
    final home = s.addresses.firstWhere((a) => a.id == 'a1');
    expect(home.name, 'Riya (Mom)');
    expect(home.phone, '+91 99999 00000');
    // Work was never edited, so it still follows the profile.
    expect(s.addresses.firstWhere((a) => a.id == 'a2').name, 'Arjun Singh');
  });

  test('order counts use the right plural', () {
    Order withQty(List<int> qty) => Order(
          id: '#1',
          date: DateTime(2024),
          items: [for (final q in qty) CartItem(productById('monkey'), q)],
          status: OrderStatus.processing,
          total: 0,
          address: Address(id: 'x', name: 'x', line1: 'x', line2: 'x', phone: ''),
        );
    expect(withQty([1]).itemsLabel, '1 item');
    expect(withQty([2]).itemsLabel, '2 items');
    expect(withQty([1, 3]).itemsLabel, '4 items');
  });

  test('the city is Gurugram everywhere, also when an older build saved "Gurgaon"', () async {
    expect((await AppState.load()).cityLabel, 'Gurugram, Haryana');
    SharedPreferences.setMockInitialValues({'city': 'Gurgaon', 'state': 'Haryana'});
    final s = await AppState.load();
    expect(s.city, 'Gurugram');
    expect(s.cityLabel, 'Gurugram, Haryana');
    expect(cities.map((c) => c.$1), contains('Gurugram'));
    expect(cities.map((c) => c.$1), isNot(contains('Gurgaon')));
  });

  test('resetPassword replaces the old password', () async {
    final s = await _withAccount();
    s.signOut();
    expect(s.resetPassword('9123456789', 'newpass1'), 'No account found for this number');
    expect(s.resetPassword(_phone, '123'), 'Password must be at least 6 characters');
    expect(s.resetPassword(_phone, 'newpass1'), isNull);
    expect(s.isGuest, isTrue, reason: 'resetting does not sign in');

    final again = await _relaunch();
    expect(again.signIn(_phone, _password), 'Incorrect password. Please try again.');
    expect(again.signIn(_phone, 'newpass1'), isNull);
  });

  test('onboarding and the delivery city are remembered', () async {
    final s = await AppState.load();
    s.completeOnboarding();
    s.setCity('Mumbai', 'Maharashtra');
    final again = await _relaunch();
    expect(again.onboarded, isTrue);
    expect(again.city, 'Mumbai');
    expect(again.state, 'Maharashtra');
  });

  test('without storage (e.g. AppState()) nothing is persisted but everything works', () async {
    final s = AppState();
    expect(s.createAccount(name: 'Arjun Mehra', phone: _phone, password: _password), isNull);
    expect(s.isSignedIn, isTrue);
    expect((await _storage()).getKeys(), isEmpty);
  });
}
