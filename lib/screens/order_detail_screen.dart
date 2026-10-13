import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'help_screen.dart';
import 'order_tracking_screen.dart';

/// Completed order details (delivered or cancelled).
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    final cancelled = order.status == OrderStatus.cancelled;
    final date = fmtDate(order.date);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(
            title: cancelled ? 'Order Cancelled' : 'Order Delivered',
            titleSize: 32,
            trailing: CircleIconButton(
              icon: Icons.headset_mic_outlined,
              bg: AppColors.creamLight,
              border: Border.all(color: AppColors.border),
              onTap: () => push(context, const HelpScreen()),
            ),
          ),
          Text(order.id, style: T.sans(17, color: AppColors.grey)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                if (!cancelled) const TrackSteps(step: 3),
                if (!cancelled) const SizedBox(height: 6),
                FadeIn(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
                    decoration: BoxDecoration(
                      color: cancelled ? AppColors.maroonSoft : AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            // Shrinks rather than overflows on narrow phones with large text.
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(cancelled ? 'Cancelled' : 'Delivered',
                                    style: T.serif(34, weight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: cancelled ? AppColors.maroon : AppColors.green,
                              child: Icon(cancelled ? Icons.close : Icons.check, color: Colors.white, size: 22),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                              cancelled
                                  ? 'This order was cancelled. Any payment has been refunded to your original payment method.'
                                  : 'Your order has been successfully delivered on $date at 7:40 PM.',
                              style: T.sans(15.5, color: AppColors.grey, height: 1.45)),
                        ]),
                      ),
                      if (!cancelled) Image.asset('${img}illus_box.jpg', width: w * 0.26),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                if (!cancelled) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: w * 0.36,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset('${img}map_delivered.jpg', fit: BoxFit.cover),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Pressable(
                            onTap: () => showToast(context, 'Opening ${order.address.line1} in Maps…'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                              ),
                              child: Row(children: [
                                const Icon(Icons.location_on, size: 18, color: AppColors.green),
                                const SizedBox(width: 8),
                                Text('View on Maps', style: T.sans(14, weight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PartnerCard(onCall: () => callPartner(context)),
                  const SizedBox(height: 12),
                ],
                AddressInfoCard(address: order.address, iconColor: const Color(0xFFB07A2A)),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(children: [
                    InkWell(
                      onTap: () => showOrderItems(context, order),
                      child: Row(children: [
                        Expanded(
                            child: Text('Order Items (${order.itemCount})', style: T.serif(20, weight: FontWeight.w600))),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    ...order.items.map((i) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                          child: Row(children: [
                            ProductThumb(image: i.product.image, size: 84),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(i.product.name, style: T.serif(19, weight: FontWeight.w600)),
                                Text(i.product.type, style: T.sans(15, color: AppColors.grey)),
                                Text(i.product.volume, style: T.sans(15, color: AppColors.grey)),
                              ]),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(rupees(i.total), style: T.serif(19, weight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('Qty: ${i.qty}', style: T.sans(14, color: AppColors.grey)),
                            ]),
                          ]),
                        )),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(children: [
              Expanded(
                child: OutlineButtonX(
                  label: 'Reorder',
                  leading: Icons.refresh,
                  arrow: false,
                  borderColor: AppColors.maroon,
                  textColor: AppColors.maroon,
                  fontSize: 20,
                  onTap: () async {
                    if (!await requireAccount(context, 'reorder') || !context.mounted) return;
                    context.read<AppState>().reorder(order);
                    push(context, const CartScreen());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Buy Again',
                  leading: Icons.shopping_bag_outlined,
                  arrow: false,
                  fontSize: 20,
                  onTap: () async {
                    if (!await requireAccount(context, 'buy this again') || !context.mounted) return;
                    final s = context.read<AppState>();
                    s.clearCart();
                    s.reorder(order);
                    push(context, const CheckoutScreen());
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
