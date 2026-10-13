import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    Widget group(String title, String sub, List<(IconData, String, String, String)> rows) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 24),
        Text(title, style: T.serif(26, weight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(sub, style: T.sans(15.5, color: AppColors.grey)),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: List.generate(rows.length, (i) {
              final (icon, t, s, key) = rows[i];
              final v = state.notificationPrefs[key] ?? false;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  IconBubble(icon: icon, size: 60, bg: AppColors.maroonSoft),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: T.serif(18.5, weight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(s, style: T.sans(14.5, color: AppColors.grey, height: 1.35)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  AppSwitch(
                    value: v,
                    onChanged: (nv) {
                      state.toggleNotif(key, nv);
                      showToast(context, '$t ${nv ? 'enabled' : 'disabled'}');
                    },
                  ),
                ]),
              );
            }),
          ),
        ),
      ]);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const PageHeader(
            title: 'Notifications',
            titleSize: 32,
            subtitle: 'Stay updated with the latest news, offers and order updates.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              children: [
                IllustratedCard(
                  image: '${img}illus_bell.jpg',
                  imageFraction: 0.3,
                  minHeight: 120,
                  builder: (context, width) => Row(children: [
                    IconBubble(
                        icon: Icons.notifications_none,
                        size: (width * 0.3).clamp(52.0, 76.0),
                        bg: AppColors.greenSoft,
                        color: AppColors.green),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Never miss an update',
                            style: T.serif(23, color: AppColors.maroon, weight: FontWeight.w600, height: 1.2)),
                        const SizedBox(height: 4),
                        Text('Choose what you want to be notified about.', style: T.sans(14, color: AppColors.grey)),
                      ]),
                    ),
                  ]),
                ),
                group('Order Updates', 'Get notified about your orders in real time.', [
                  (Icons.inventory_2_outlined, 'Order Confirmations', 'Get notified when your order is placed.', 'order_confirm'),
                  (Icons.local_shipping_outlined, 'Shipping Updates', 'Get notified when your order is shipped.', 'shipping'),
                  (Icons.check_box_outlined, 'Delivery Updates', 'Get notified when your order is out for delivery and delivered.', 'delivery'),
                ]),
                group('Offers & Promotions', 'Be the first to know about new launches, deals and exclusive offers.', [
                  (Icons.local_offer_outlined, 'Special Offers', 'Get notified about discounts, sales and exclusive deals.', 'offers'),
                  (Icons.card_giftcard, 'New Arrivals', 'Get notified about new products and upcoming launches.', 'arrivals'),
                ]),
                group('General Notifications', 'Stay informed with important updates.', [
                  (Icons.notifications_none, 'App Updates', 'Get notified about new features and important announcements.', 'app'),
                  (Icons.description_outlined, 'Policy Updates', 'Get notified about changes in our terms, policies and services.', 'policy'),
                ]),
                const SizedBox(height: 20),
                AppCard(
                  color: AppColors.greenSoft.withValues(alpha: 0.7),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const IconBubble(
                        icon: Icons.verified_user_outlined, size: 60, bg: AppColors.greenSoft, color: AppColors.green),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your Preferences are Safe',
                            style: T.serif(18, color: AppColors.green, weight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('You can update your notification preferences anytime.',
                            style: T.sans(14, color: AppColors.grey)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
