import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'delivery_preferences_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'payment_methods_screen.dart';
import 'responsible_drinking_screen.dart';
import 'saved_addresses_screen.dart';
import 'sign_in_screen.dart';
import 'terms_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Widget item(IconData icon, String label, Color bg, Color fg, VoidCallback onTap, {bool last = false}) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            IconBubble(icon: icon, bg: bg, color: fg, size: 56),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  Expanded(child: Text(label, style: T.sans(18.5))),
                  const Icon(Icons.chevron_right, color: AppColors.grey),
                ]),
              ),
            ),
          ]),
        ),
      );
    }

    Widget group(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
              child: Text(title, style: T.sans(14.5, color: AppColors.grey, spacing: 2, weight: FontWeight.w600)),
            ),
            AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
          ],
        );

    const beige = Color(0xFFEFE3D3);
    const pink = Color(0xFFF4E1DE);
    const sage = Color(0xFFE4E8DC);
    const brown = Color(0xFF8A5A22);

    // Account-only pages ask guests to sign in first.
    VoidCallback gated(String reason, VoidCallback open) => () async {
          if (await requireAccount(context, reason) && context.mounted) open();
        };
    final guest = state.isGuest;
    final city = state.cityLabel;
    void editProfile() => push(context, const EditProfileScreen());

    return Container(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            FadeIn(child: guest ? _GuestHeader(city: city) : _UserHeader(city: city, onEdit: editProfile)),
            group('MY ACCOUNT', [
              item(Icons.shopping_bag_outlined, 'My Orders', beige, brown,
                  gated('see your orders', () => state.setTab(3))),
              item(Icons.favorite_border, 'Wishlist', pink, AppColors.maroon,
                  () => push(context, const WishlistScreen())),
              item(Icons.location_on_outlined, 'Saved Addresses', sage, AppColors.green,
                  gated('save delivery addresses', () => push(context, const SavedAddressesScreen())),
                  last: true),
            ]),
            group('PAYMENTS & PREFERENCES', [
              item(Icons.credit_card, 'Payment Methods', beige, brown,
                  gated('save payment methods', () => push(context, const PaymentMethodsScreen()))),
              item(Icons.local_shipping_outlined, 'Delivery Preferences', pink, AppColors.maroon,
                  gated('set delivery preferences', () => push(context, const DeliveryPreferencesScreen()))),
              item(Icons.notifications_none, 'Notifications', sage, AppColors.green,
                  gated('manage notifications', () => push(context, const NotificationsScreen())),
                  last: true),
            ]),
            group('SUPPORT & LEGAL', [
              item(Icons.wine_bar_outlined, 'Responsible Drinking', beige, brown,
                  () => push(context, const ResponsibleDrinkingScreen())),
              item(Icons.headset_mic_outlined, 'Help & Support', pink, AppColors.maroon,
                  () => push(context, const HelpScreen())),
              item(Icons.description_outlined, 'Terms & Privacy', sage, AppColors.green,
                  () => push(context, const TermsScreen())),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Material(
                  color: const Color(0xFFF6E3E0),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: guest
                        ? () => openSignIn(context)
                        : () async {
                            final ok = await confirmDialog(context, 'Log out?',
                                'Your account stays on this device. Sign back in anytime with your number and password.',
                                confirm: 'Log Out', destructive: true);
                            if (!ok || !context.mounted) return;
                            state.signOut();
                            Navigator.of(context).pushAndRemoveUntil(fadeRoute(const SignInScreen()), (_) => false);
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        IconBubble(icon: guest ? Icons.login : Icons.logout, bg: pink, color: AppColors.maroon, size: 56),
                        const SizedBox(width: 20),
                        Expanded(
                            child: Text(guest ? 'Sign In' : 'Log Out', style: T.sans(18.5, color: AppColors.maroon))),
                        const Icon(Icons.chevron_right, color: AppColors.maroon),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Signed-in header: avatar + name open Edit Profile, as does the gear.
class _UserHeader extends StatelessWidget {
  final String city;
  final VoidCallback onEdit;
  const _UserHeader({required this.city, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>((s) => s.userName);
    return Row(children: [
      Expanded(
        child: Semantics(
          button: true,
          label: 'Edit profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
                ),
                child: const UserAvatar(size: 104),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LayoutBuilder(builder: (context, box) {
                    // Long names wrap onto more lines; the size only drops as
                    // far as needed for the longest word to fit on a line.
                    final widest = name
                        .split(' ')
                        .map((w) => textWidth(context, w, T.serif(32, weight: FontWeight.w500)))
                        .fold(0.0, (a, b) => a > b ? a : b);
                    final size = widest > box.maxWidth ? (32 * (box.maxWidth - 1) / widest).clamp(14.0, 32.0) : 32.0;
                    return Text(name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: T.serif(size, weight: FontWeight.w500, height: 1.15));
                  }),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 20, color: AppColors.grey),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(city,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.sans(16, color: AppColors.grey)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      CircleIconButton(
        icon: Icons.settings_outlined,
        size: 56,
        bg: AppColors.creamLight,
        border: Border.all(color: AppColors.border),
        onTap: onEdit,
      ),
    ]);
  }
}

/// Guest header: nothing is saved without an account, so offer one.
class _GuestHeader extends StatelessWidget {
  final String city;
  const _GuestHeader({required this.city});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const UserAvatar(size: 76),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Guest', style: T.serif(30, weight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(city,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: T.sans(15, color: AppColors.grey)),
                ),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Sign in to check out, track your orders and manage your profile',
            style: T.sans(15.5, color: AppColors.grey, height: 1.45)),
        const SizedBox(height: 16),
        const AuthButtons(),
      ]),
    );
  }
}

/// Stand-alone My Orders (pushed from outside the shell).
class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});
  @override
  Widget build(BuildContext context) => const OrdersScreen();
}
