import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/profile_photo.dart';
import '../data/sample_data.dart';

/// Single app-wide store (Provider + ChangeNotifier). The catalogue, cart and
/// orders are local sample data; accounts, the session and a few settings are
/// kept on the device with SharedPreferences, so the app works fully offline.
///
/// Without [prefs] (e.g. in tests) everything still works, it just isn't
/// persisted.
class AppState extends ChangeNotifier {
  AppState({SharedPreferences? prefs}) : _prefs = prefs {
    _seed();
    _restore();
    _applyUser();
  }

  /// Opens SharedPreferences and restores the saved session. Falls back to an
  /// in-memory store if platform storage can't be opened.
  static Future<AppState> load() async {
    try {
      return AppState(prefs: await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Reserve: local storage unavailable, running in memory ($e)');
      return AppState();
    }
  }

  final SharedPreferences? _prefs;

  static const _kAccounts = 'accounts';
  static const _kSession = 'session_phone';
  static const _kOnboarded = 'onboarded';
  static const _kCity = 'city';
  static const _kState = 'state';

  static const minPasswordLength = 6;

  // ---------- Session / navigation ----------
  String city = 'Gurugram';
  String state = 'Haryana';
  int tabIndex = 0;

  /// "Gurugram, Haryana" — the one way the delivery city is shown.
  String get cityLabel => '$city, $state';

  bool _onboarded = false;
  UserProfile? _user;

  /// phone -> {name, email, salt, passwordHash, photoPath}. Passwords are only
  /// ever stored as a salted SHA-256 hash.
  final Map<String, Map<String, dynamic>> _accounts = {};

  bool get onboarded => _onboarded;
  UserProfile? get user => _user;
  bool get isSignedIn => _user != null;

  /// True whenever nobody is signed in (e.g. after "Skip"). Guest sessions
  /// are never persisted, so a restart asks to sign in again.
  bool get isGuest => _user == null;

  /// Older name for [isSignedIn].
  bool get signedIn => isSignedIn;
  String get userName => _user?.name ?? 'Guest';

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  void setUserName(String n) => updateProfile(name: n);

  void setCity(String c, String s) {
    city = c;
    state = s;
    _prefs?.setString(_kCity, c);
    _prefs?.setString(_kState, s);
    notifyListeners();
  }

  void completeOnboarding() {
    if (_onboarded) return;
    _onboarded = true;
    _prefs?.setBool(_kOnboarded, true);
    notifyListeners();
  }

  // ---------- Accounts ----------

  /// Digits only, without the +91 / 0091 / leading 0 prefix.
  static String normalizePhone(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.length == 14 && d.startsWith('0091')) d = d.substring(4);
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// Indian mobile numbers: 10 digits starting with 6–9.
  static bool isValidPhone(String input) => RegExp(r'^[6-9]\d{9}$').hasMatch(normalizePhone(input));

  static bool isValidEmail(String input) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$').hasMatch(input.trim());

  bool accountExists(String phone) => _accounts.containsKey(normalizePhone(phone));

  /// Creates a local account and signs in. Returns an error message, or null
  /// on success.
  String? createAccount({
    required String name,
    required String phone,
    String email = '',
    required String password,
  }) {
    final n = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ph = normalizePhone(phone);
    final em = email.trim();
    if (n.length < 2) return 'Enter your full name';
    if (!isValidPhone(ph)) return 'Enter a valid 10-digit mobile number';
    if (em.isNotEmpty && !isValidEmail(em)) return 'Enter a valid email address';
    if (password.length < minPasswordLength) return 'Password must be at least $minPasswordLength characters';
    if (_accounts.containsKey(ph)) return 'An account with this number already exists. Sign in instead.';
    final salt = _newSalt();
    _accounts[ph] = {
      'name': n,
      'email': em,
      'salt': salt,
      'passwordHash': _hash(salt, password),
      'photoPath': null,
    };
    _saveAccounts();
    _startSession(ph);
    return null;
  }

  /// Returns an error message, or null when signed in.
  String? signIn(String phone, String password) {
    final ph = normalizePhone(phone);
    if (ph.length != 10) return 'Enter a valid 10-digit phone number';
    final acc = _accounts[ph];
    if (acc == null) return 'No account found for this number. Create an account to continue.';
    if (_hash(acc['salt'] as String, password) != acc['passwordHash']) {
      return 'Incorrect password. Please try again.';
    }
    _startSession(ph);
    return null;
  }

  /// Sets a new password for an existing account (after OTP check in the UI).
  String? resetPassword(String phone, String newPassword) {
    final ph = normalizePhone(phone);
    final acc = _accounts[ph];
    if (acc == null) return 'No account found for this number';
    if (newPassword.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    final salt = _newSalt();
    acc['salt'] = salt;
    acc['passwordHash'] = _hash(salt, newPassword);
    _saveAccounts();
    return null;
  }

  /// Browse without an account. Nothing is created or saved.
  void continueAsGuest() {
    _user = null;
    _prefs?.remove(_kSession);
    tabIndex = 0;
    completeOnboarding();
    _applyUser();
    notifyListeners();
  }

  /// Ends the session; the account itself stays on the device. This session's
  /// cart, wishlist, orders, addresses, cards and preferences go back to the
  /// demo sample data, so the next person on the phone doesn't see them.
  void signOut() {
    _user = null;
    _prefs?.remove(_kSession);
    tabIndex = 0;
    _seed();
    _applyUser();
    notifyListeners();
  }

  /// Permanently deletes the signed-in account (profile, password hash and
  /// photo) from this device, then signs out. Does nothing for guests.
  void deleteAccount() {
    final u = _user;
    if (u == null) return;
    _accounts.remove(u.phone);
    _saveAccounts();
    final photo = u.photoPath;
    // A web photo is a data URL inside the account record, already gone.
    if (photo != null && !kIsWeb && !ProfilePhoto.isDataUrl(photo)) {
      try {
        final f = File(photo);
        if (f.existsSync()) f.deleteSync();
      } catch (e) {
        debugPrint('Reserve: could not delete the profile photo ($e)');
      }
    }
    signOut();
  }

  /// Updates the signed-in user's profile. Blank names are ignored.
  void updateProfile({String? name, String? email, String? photoPath, bool clearPhoto = false}) {
    final u = _user;
    if (u == null) return;
    final n = name?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final updated = u.copyWith(
      name: (n == null || n.isEmpty) ? null : n,
      email: email?.trim(),
      photoPath: photoPath,
      clearPhoto: clearPhoto,
    );
    _user = updated;
    final acc = _accounts[u.phone];
    if (acc != null) {
      acc['name'] = updated.name;
      acc['email'] = updated.email;
      acc['photoPath'] = updated.photoPath;
      _saveAccounts();
    }
    _applyUser();
    notifyListeners();
  }

  void _startSession(String phone) {
    _user = _profileFor(phone);
    _prefs?.setString(_kSession, phone);
    completeOnboarding();
    _applyUser();
    notifyListeners();
  }

  UserProfile? _profileFor(String phone) {
    final acc = _accounts[phone];
    if (acc == null) return null;
    return UserProfile(
      name: acc['name'] as String? ?? 'Reserve Member',
      phone: phone,
      email: acc['email'] as String? ?? '',
      photoPath: acc['photoPath'] as String?,
    );
  }

  void _restore() {
    final p = _prefs;
    if (p == null) return;
    _onboarded = p.getBool(_kOnboarded) ?? false;
    city = p.getString(_kCity) ?? city;
    // Older builds saved the city's former name.
    if (city == 'Gurgaon') city = 'Gurugram';
    state = p.getString(_kState) ?? state;
    try {
      final raw = p.getString(_kAccounts);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>)
            .forEach((k, v) => _accounts[k] = Map<String, dynamic>.from(v as Map));
      }
    } catch (e) {
      debugPrint('Reserve: could not read saved accounts ($e)');
    }
    final phone = p.getString(_kSession);
    if (phone != null) _user = _profileFor(phone);
  }

  void _saveAccounts() => _prefs?.setString(_kAccounts, jsonEncode(_accounts));

  static String _newSalt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  // Name and phone last written to the user's own Home / Work addresses.
  String _ownerName = 'Guest';
  String _ownerPhone = '';

  /// Keeps the user's own addresses (Home / Work) and sample UPI handles in
  /// step with whoever is signed in. An address whose name or phone the user
  /// changed in Saved Addresses (e.g. to deliver to someone else) is left
  /// alone.
  void _applyUser() {
    final u = _user;
    final name = u?.name ?? 'Guest';
    final phone = u?.displayPhone ?? '';
    for (final a in addresses) {
      if ((a.id == 'a1' || a.id == 'a2') && a.name == _ownerName && a.phone == _ownerPhone) {
        a.name = name;
        a.phone = phone;
      }
    }
    _ownerName = name;
    _ownerPhone = phone;
    var handle = 'guest';
    if (u != null) {
      handle = u.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '.').replaceAll(RegExp(r'^\.+|\.+$'), '');
      if (handle.isEmpty) handle = u.phone;
    }
    for (final (id, title, suffix, logo) in [
      ('p3', 'Google Pay', 'okicici', 'assets/images/logo_gpay.jpg'),
      ('p4', 'PhonePe', 'ibl', 'assets/images/logo_phonepe.jpg'),
    ]) {
      final i = savedPayments.indexWhere((p) => p.id == id);
      if (i != -1) savedPayments[i] = PaymentCard(id, title, '$handle@$suffix', logo);
    }
  }

  // ---------- Cart ----------
  final List<CartItem> cart = [];
  String specialInstructions = '';

  int get cartCount => cart.fold(0, (s, i) => s + i.qty);
  int get subtotal => cart.fold(0, (s, i) => s + i.total);
  int get deliveryFee => cart.isEmpty ? 0 : (deliveryOption == 2 ? 0 : 99);
  int get taxes => cart.isEmpty ? 0 : (subtotal * 0.017).round();
  int get total => subtotal + deliveryFee + taxes;

  int qtyInCart(Product p) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    return i == -1 ? 0 : cart[i].qty;
  }

  void addToCart(Product p, [int qty = 1]) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    if (i == -1) {
      cart.add(CartItem(p, qty));
    } else {
      cart[i].qty += qty;
    }
    notifyListeners();
  }

  void setQty(Product p, int qty) {
    final i = cart.indexWhere((c) => c.product.id == p.id);
    if (i == -1) return;
    if (qty <= 0) {
      cart.removeAt(i);
    } else {
      cart[i].qty = qty.clamp(1, 12);
    }
    notifyListeners();
  }

  void removeFromCart(Product p) {
    cart.removeWhere((c) => c.product.id == p.id);
    notifyListeners();
  }

  void setSpecialInstructions(String v) {
    specialInstructions = v;
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  // ---------- Wishlist ----------
  final List<String> wishlist = [];

  bool isWished(Product p) => wishlist.contains(p.id);

  void toggleWish(Product p) {
    if (!wishlist.remove(p.id)) wishlist.insert(0, p.id);
    notifyListeners();
  }

  // ---------- Addresses ----------
  final List<Address> addresses = [];
  String defaultAddressId = 'a1';
  String checkoutAddressId = 'a1';

  Address get defaultAddress =>
      addresses.firstWhere((a) => a.id == defaultAddressId, orElse: () => addresses.first);

  Address get checkoutAddress =>
      addresses.firstWhere((a) => a.id == checkoutAddressId, orElse: () => addresses.first);

  void selectCheckoutAddress(String id) {
    checkoutAddressId = id;
    notifyListeners();
  }

  void setDefaultAddress(String id) {
    defaultAddressId = id;
    notifyListeners();
  }

  void saveAddress(Address a) {
    final i = addresses.indexWhere((x) => x.id == a.id);
    if (i == -1) {
      addresses.add(a);
    } else {
      addresses[i] = a;
    }
    notifyListeners();
  }

  void deleteAddress(String id) {
    if (addresses.length <= 1) return;
    addresses.removeWhere((a) => a.id == id);
    if (defaultAddressId == id) defaultAddressId = addresses.first.id;
    if (checkoutAddressId == id) checkoutAddressId = addresses.first.id;
    notifyListeners();
  }

  // ---------- Checkout ----------
  int deliveryOption = 0; // 0 standard, 1 scheduled, 2 pickup
  DateTime? scheduledDate;
  String? scheduledSlot;
  int paymentOption = 0; // 0 UPI, 1 card, 2 netbanking, 3 wallets
  bool ageConfirmed = true;

  void setDeliveryOption(int i) {
    deliveryOption = i;
    notifyListeners();
  }

  void setSchedule(DateTime d, String slot) {
    scheduledDate = d;
    scheduledSlot = slot;
    notifyListeners();
  }

  void setPaymentOption(int i) {
    paymentOption = i;
    notifyListeners();
  }

  void setAgeConfirmed(bool v) {
    ageConfirmed = v;
    notifyListeners();
  }

  static const deliveryNames = ['Standard Delivery', 'Scheduled Delivery', 'Store Pickup'];
  static const paymentNames = ['UPI', 'Credit / Debit Card', 'Net Banking', 'Wallets'];

  // ---------- Orders ----------
  final List<Order> orders = [];

  Order placeOrder() {
    final order = Order(
      id: '#${8124092817 + orders.length * 7 + DateTime.now().second}',
      date: DateTime.now(),
      items: cart.map((c) => CartItem(c.product, c.qty)).toList(),
      status: OrderStatus.outForDelivery,
      total: total,
      address: checkoutAddress.copy(),
      deliveryOption: deliveryNames[deliveryOption],
      paymentMethod: paymentNames[paymentOption],
    );
    orders.insert(0, order);
    cart.clear();
    specialInstructions = '';
    notifyListeners();
    return order;
  }

  void markDelivered(Order o) {
    o.status = OrderStatus.delivered;
    notifyListeners();
  }

  void cancelOrder(Order o) {
    o.status = OrderStatus.cancelled;
    notifyListeners();
  }

  void reorder(Order o) {
    for (final i in o.items) {
      addToCart(i.product, i.qty);
    }
  }

  // ---------- Search ----------
  final List<String> recentSearches = [];

  void addRecentSearch(String q) {
    q = q.trim();
    if (q.isEmpty) return;
    recentSearches.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    recentSearches.insert(0, q);
    if (recentSearches.length > 12) recentSearches.removeLast();
    notifyListeners();
  }

  void clearRecentSearches() {
    recentSearches.clear();
    notifyListeners();
  }

  List<Product> search(String q) {
    final s = q.toLowerCase().trim();
    if (s.isEmpty) return [];
    final under = RegExp(r'under\s*₹?\s*([\d,]+)').firstMatch(s);
    if (under != null) {
      final limit = int.parse(under.group(1)!.replaceAll(',', ''));
      final rest = s.replaceAll(under.group(0)!, '').trim();
      return products
          .where((p) => p.price <= limit && (rest.isEmpty || _matches(p, rest)))
          .toList();
    }
    if (s.contains('gift') || s.contains('hamper')) {
      return products.where((p) => p.price >= 4000).toList();
    }
    return products.where((p) => _matches(p, s)).toList();
  }

  bool _matches(Product p, String s) {
    final words = s.split(RegExp(r'\s+')).where((w) => w.length > 1 && w != 'best' && w != 'premium');
    final hay = '${p.name} ${p.type} ${p.brand} ${categoryById(p.categoryId).name}'.toLowerCase();
    if (words.isEmpty) return s.contains('premium') ? p.price >= 4000 : true;
    return words.every((w) => hay.contains(w) || hay.contains(w.replaceAll(RegExp(r's$'), '')));
  }

  // ---------- Payments ----------
  final List<PaymentCard> savedPayments = [];
  String defaultPaymentId = 'p1';

  void setDefaultPayment(String id) {
    defaultPaymentId = id;
    notifyListeners();
  }

  void addPayment(PaymentCard c) {
    savedPayments.add(c);
    notifyListeners();
  }

  void removePayment(String id) {
    savedPayments.removeWhere((p) => p.id == id);
    if (defaultPaymentId == id && savedPayments.isNotEmpty) defaultPaymentId = savedPayments.first.id;
    notifyListeners();
  }

  // ---------- Preferences ----------
  int deliveryType = 0; // home / pickup / different
  String deliveryInstructions = '';
  bool emailNotif = true;
  bool smsNotif = true;
  String preferredAddressId = 'a1';

  final Map<String, bool> notificationPrefs = {};

  void toggleNotif(String key, bool v) {
    notificationPrefs[key] = v;
    notifyListeners();
  }

  void saveDeliveryPrefs({
    required int type,
    required String instructions,
    required bool email,
    required bool sms,
    required String addressId,
  }) {
    deliveryType = type;
    deliveryInstructions = instructions;
    emailNotif = email;
    smsNotif = sms;
    preferredAddressId = addressId;
    notifyListeners();
  }

  bool responsibleAck = false;
  void setResponsibleAck(bool v) {
    responsibleAck = v;
    notifyListeners();
  }

  // ---------- Seed ----------
  /// Resets everything that belongs to the person using the app (cart,
  /// wishlist, addresses, orders, cards, preferences, searches) to the demo
  /// sample data. Runs at start-up and on sign-out.
  void _seed() {
    // a1 / a2 are the user's own addresses; name and phone come from the
    // signed-in account (see _applyUser).
    _ownerName = 'Guest';
    _ownerPhone = '';
    addresses.clear();
    defaultAddressId = checkoutAddressId = preferredAddressId = 'a1';
    addresses.addAll([
      Address(
          id: 'a1',
          name: 'Guest',
          line1: 'Flat 502, DLF Phase 4',
          line2: 'Gurugram, Haryana - 122002',
          phone: '',
          label: 'Home'),
      Address(
          id: 'a2',
          name: 'Guest',
          line1: 'Cyber City',
          line2: 'Gurugram, Haryana - 122002',
          phone: '',
          label: 'Work'),
      Address(
          id: 'a3',
          name: 'Riya Kapoor',
          line1: 'Sector 54',
          line2: 'Gurugram, Haryana - 122011',
          phone: '+91 87654 32109',
          label: 'Other'),
      Address(
          id: 'a4',
          name: 'Neha Sharma',
          line1: 'B-12, South City 1',
          line2: 'Gurugram, Haryana - 122001',
          phone: '+91 76543 21098',
          label: 'Other'),
    ]);

    cart
      ..clear()
      ..addAll([CartItem(productById('monkey')), CartItem(productById('hendricks'))]);
    specialInstructions = '';
    wishlist
      ..clear()
      ..addAll(['macallan12', 'jackno7', 'absolut', 'tanqueray', 'chivas12', 'baileys']);

    savedPayments
      ..clear()
      ..addAll([
        PaymentCard('p1', 'HDFC Bank', '•••• 4242', 'assets/images/logo_visa.jpg'),
        PaymentCard('p2', 'ICICI Bank', '•••• 7681', 'assets/images/logo_mastercard.jpg'),
        // UPI handles are filled in from the signed-in user's name (_applyUser).
        PaymentCard('p3', 'Google Pay', 'guest@okicici', 'assets/images/logo_gpay.jpg'),
        PaymentCard('p4', 'PhonePe', 'guest@ibl', 'assets/images/logo_phonepe.jpg'),
      ]);
    defaultPaymentId = 'p1';

    recentSearches
      ..clear()
      ..addAll([
        'Macallan 18',
        'Glenfiddich 12',
        'Chivas Regal',
        'Red Wine',
        'Johnnie Walker',
        'Tequila',
        'Vodka',
        'Glenlivet 15',
        'Rum',
      ]);

    deliveryOption = 0;
    scheduledDate = null;
    scheduledSlot = null;
    paymentOption = 0;
    ageConfirmed = true;
    deliveryType = 0;
    deliveryInstructions = '';
    emailNotif = true;
    smsNotif = true;
    responsibleAck = false;
    notificationPrefs
      ..clear()
      ..addAll({
        'order_confirm': true,
        'shipping': true,
        'delivery': true,
        'offers': true,
        'arrivals': true,
        'app': true,
        'policy': false,
      });

    // Sample orders go to the user's own Home address, so they follow the
    // signed-in user like a1 does (orders placed in the app keep a copy).
    final home = addresses.first;
    orders.clear();
    orders.addAll([
      Order(
          id: '#8124092817',
          date: DateTime(2024, 10, 12),
          items: [CartItem(productById('monkey')), CartItem(productById('hendricks'))],
          status: OrderStatus.delivered,
          total: 8590,
          address: home),
      Order(
          id: '#8124091654',
          date: DateTime(2024, 9, 28),
          items: [CartItem(productById('redwine'))],
          status: OrderStatus.outForDelivery,
          total: 2499,
          address: home),
      Order(
          id: '#8124089331',
          date: DateTime(2024, 9, 15),
          items: [
            CartItem(productById('monkey')),
            CartItem(productById('hendricks')),
            CartItem(productById('redwine'))
          ],
          status: OrderStatus.packed,
          total: 11990,
          address: home),
      Order(
          id: '#8124076620',
          date: DateTime(2024, 9, 2),
          items: [CartItem(productById('hendricks'))],
          status: OrderStatus.processing,
          total: 4850,
          address: home),
      Order(
          id: '#8124069982',
          date: DateTime(2024, 8, 20),
          items: [CartItem(productById('monkey')), CartItem(productById('redwine'))],
          status: OrderStatus.cancelled,
          total: 5998,
          address: home),
    ]);
  }
}
