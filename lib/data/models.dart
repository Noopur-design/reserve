class Category {
  final String id;
  final String name;
  final String image;
  final String tagline;
  const Category(this.id, this.name, this.image, this.tagline);
}

class Product {
  final String id;
  final String name;
  final String type;
  final String categoryId;
  final String brand;
  final int volumeMl;
  final int price;
  final String image;
  final double rating;
  final int reviews;
  final String description;
  final String tastingNotes;
  final String aboutBrand;
  final String serving;
  final Map<String, String> specs;

  const Product({
    required this.id,
    required this.name,
    required this.type,
    required this.categoryId,
    required this.brand,
    required this.price,
    required this.image,
    this.volumeMl = 700,
    this.rating = 4.6,
    this.reviews = 1200,
    this.description = 'Rich and balanced with a smooth, warming finish.',
    this.tastingNotes =
        'Nose: Vanilla, honey and baked orchard fruit.\nPalate: Smooth malt, toffee and gentle spice.\nFinish: Medium, warm and lingering.',
    this.aboutBrand = 'A celebrated distillery known for craftsmanship, patience and character in every bottle.',
    this.serving = 'Neat, with a splash of water, or over a large ice cube. Pairs well with dark chocolate and nuts.',
    this.specs = const {},
  });

  String get volume => '$volumeMl ml';
}

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, [this.qty = 1]);
  int get total => product.price * qty;
}

class Address {
  final String id;
  String name;
  String line1;
  String line2;
  String phone;
  String label; // Home / Work / Other
  Address({
    required this.id,
    required this.name,
    required this.line1,
    required this.line2,
    required this.phone,
    this.label = 'Home',
  });

  /// Independent copy, e.g. so a placed order keeps the address it was sent
  /// to even if the saved address is edited later.
  Address copy() => Address(id: id, name: name, line1: line1, line2: line2, phone: phone, label: label);
}

enum OrderStatus { processing, packed, shipped, outForDelivery, delivered, cancelled }

class Order {
  final String id;
  final DateTime date;
  final List<CartItem> items;
  OrderStatus status;
  final int total;
  final Address address;
  final String deliveryOption;
  final String paymentMethod;

  Order({
    required this.id,
    required this.date,
    required this.items,
    required this.status,
    required this.total,
    required this.address,
    this.deliveryOption = 'Standard Delivery',
    this.paymentMethod = 'UPI',
  });

  int get itemCount => items.fold(0, (s, i) => s + i.qty);

  /// "1 item" / "7 items" — counts bottles, not product lines.
  String get itemsLabel => '$itemCount ${itemCount == 1 ? 'item' : 'items'}';
}

class PaymentCard {
  final String id;
  final String title;
  final String subtitle;
  final String logo;
  PaymentCard(this.id, this.title, this.subtitle, this.logo);
}

/// The signed-in customer. Accounts live on the device only (see AppState),
/// so there is no server id — the 10-digit phone number is the key.
class UserProfile {
  final String name;
  final String phone; // normalised: 10 digits, no country code
  final String email; // '' when not given
  final String? photoPath; // file in the app documents directory

  const UserProfile({required this.name, required this.phone, this.email = '', this.photoPath});

  /// Up to two letters, e.g. "Riya Kapoor" -> "RK".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String lead(String s) => String.fromCharCode(s.runes.first);
    final first = lead(parts.first);
    final last = parts.length > 1 ? lead(parts.last) : '';
    return (first + last).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// "+91 98765 43210"
  String get displayPhone =>
      phone.length == 10 ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}' : phone;

  UserProfile copyWith({String? name, String? email, String? photoPath, bool clearPhoto = false}) =>
      UserProfile(
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      );
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;
  final bool askOrderNumber;
  ChatMessage(this.text, this.fromUser, this.time, {this.askOrderNumber = false});
}
