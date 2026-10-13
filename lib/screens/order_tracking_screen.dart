import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'chat_screen.dart';
import 'help_screen.dart';
import 'order_detail_screen.dart';

int trackingStep(OrderStatus s) => switch (s) {
      OrderStatus.processing => 0,
      OrderStatus.packed => 1,
      OrderStatus.shipped || OrderStatus.outForDelivery => 2,
      OrderStatus.delivered => 3,
      OrderStatus.cancelled => 0,
    };

void callPartner(BuildContext context) {
  showAppSheet(
    context,
    title: 'Call Delivery Partner',
    child: Column(children: [
      const CircleAvatar(radius: 44, backgroundImage: AssetImage('${img}avatar_rahul.png')),
      const SizedBox(height: 12),
      Text('Rahul', style: T.serif(24, weight: FontWeight.w600)),
      Text('+91 98765 43210', style: T.sans(16, color: AppColors.grey)),
      const SizedBox(height: 20),
      PrimaryButton(
        label: 'Copy Number',
        leading: Icons.copy,
        arrow: false,
        onTap: () {
          Clipboard.setData(const ClipboardData(text: '+919876543210'));
          Navigator.pop(context);
          showToast(context, 'Number copied — paste it in your dialer');
        },
      ),
    ]),
  );
}

void showOrderItems(BuildContext context, Order order) {
  showAppSheet(
    context,
    title: 'Order Items (${order.itemCount})',
    child: Column(children: [
      ...order.items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              ProductThumb(image: i.product.image, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.product.name, style: T.serif(17, weight: FontWeight.w600)),
                  Text('${i.product.type} · ${i.product.volume}', style: T.sans(13, color: AppColors.grey)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(rupees(i.total), style: T.serif(17, weight: FontWeight.w700)),
                Text('Qty: ${i.qty}', style: T.sans(13, color: AppColors.grey)),
              ]),
            ]),
          )),
      const Divider(color: AppColors.border),
      Row(children: [
        Expanded(child: Text('Total paid', style: T.serif(20, weight: FontWeight.w600))),
        Text(rupees(order.total), style: T.serif(20, color: AppColors.maroon, weight: FontWeight.w700)),
      ]),
    ]),
  );
}

class OrderTrackingScreen extends StatefulWidget {
  final Order order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final DateTime _eta = DateTime.now().add(const Duration(minutes: 80));
  Timer? _doneTimer;

  Order get o => widget.order;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(seconds: 14));
    if (trackingStep(o.status) == 2) {
      _progress.forward();
      _progress.addStatusListener((s) {
        if (s == AnimationStatus.completed) _delivered();
      });
    }
  }

  void _delivered() {
    if (!mounted) return;
    context.read<AppState>().markDelivered(o);
    Navigator.of(context).pushReplacement(fadeRoute(OrderDetailScreen(order: o)));
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final step = trackingStep(o.status);
    final title = switch (step) {
      0 => 'Your order is confirmed',
      1 => 'Your order is packed',
      _ => 'Your order is on the way',
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF16261B),
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F1D14), Color(0xFF1C2E20)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                PageHeader(title: title, color: Colors.white, titleSize: 28),
                Text(o.id, style: T.sans(18, color: Colors.white.withValues(alpha: 0.9), weight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 36),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) => TrackSteps(step: step, dark: true, lastProgress: _progress.value),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: w * 0.5,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset('${img}map_tracking.jpg', fit: BoxFit.cover),
                      Positioned(
                        right: w * 0.13,
                        top: w * 0.02,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Container(
                            width: w * 0.28,
                            height: w * 0.28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.green.withValues(alpha: 0.5 * (1 - _pulse.value)), width: 3),
                            ),
                            transform: Matrix4.diagonal3Values(0.7 + 0.5 * _pulse.value, 0.7 + 0.5 * _pulse.value, 1),
                            transformAlignment: Alignment.center,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00F4EDE4), AppColors.cream],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Column(children: [
                      Text(step == 2 ? 'Arriving by' : 'Expected by', style: T.sans(18, color: AppColors.grey)),
                      FadeIn(
                        child: Text(fmtTime(_eta).replaceFirst(RegExp(r'^0'), ''),
                            style: T.serif(52, color: AppColors.maroon, weight: FontWeight.w700)),
                      ),
                      Text(
                          step == 2
                              ? 'Your order is out for delivery and\nwill reach you soon.'
                              : 'We\'re preparing your order. You\'ll be\nnotified when it\'s on the way.',
                          textAlign: TextAlign.center,
                          style: T.sans(16.5, color: AppColors.grey, height: 1.45)),
                      const SizedBox(height: 20),
                      PartnerCard(onCall: () => callPartner(context)),
                      const SizedBox(height: 12),
                      AddressInfoCard(address: o.address),
                      const SizedBox(height: 12),
                      AppCard(
                        onTap: () => showOrderItems(context, o),
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                        child: Row(children: [
                          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF7A5028), size: 32),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Order Items', style: T.sans(17)),
                              Text('${o.itemsLabel}  •  ${rupees(o.total)}',
                                  style: T.sans(15, color: AppColors.grey)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, size: 28),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      if (step < 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlineButtonX(
                            label: 'Cancel Order',
                            arrow: false,
                            borderColor: AppColors.maroon,
                            textColor: AppColors.maroon,
                            fontSize: 19,
                            onTap: () async {
                              final ok = await confirmDialog(context, 'Cancel order?',
                                  'Your payment of ${rupees(o.total)} will be refunded in 5–7 days.',
                                  confirm: 'Cancel Order', destructive: true);
                              if (ok && context.mounted) {
                                context.read<AppState>().cancelOrder(o);
                                Navigator.pop(context);
                                showToast(context, 'Order ${o.id} cancelled');
                              }
                            },
                          ),
                        ),
                      HelpBanner(onTap: () => push(context, const HelpScreen())),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Confirmed → Packed → Out for Delivery → Delivered progress row.
class TrackSteps extends StatelessWidget {
  final int step;
  final bool dark;
  final double lastProgress;
  const TrackSteps({super.key, required this.step, this.dark = false, this.lastProgress = 0});

  @override
  Widget build(BuildContext context) {
    const labels = ['Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];
    const times = ['10:12 AM', '11:30 AM', '06:20 PM', '07:40 PM'];
    final activeLine = dark ? AppColors.gold : AppColors.green;
    final idleLine = dark ? Colors.white30 : AppColors.border;

    return LayoutBuilder(builder: (context, c) {
      final seg = c.maxWidth / 4;
      return SizedBox(
        height: 130,
        child: Stack(children: [
          // connector lines
          for (var i = 0; i < 3; i++)
            Positioned(
              left: seg * i + seg / 2 + 30,
              top: 34,
              width: seg - 60,
              height: 3,
              child: Stack(children: [
                Container(color: idleLine),
                FractionallySizedBox(
                  widthFactor: i < step ? 1 : (i == step && i == 2 ? lastProgress : 0),
                  child: Container(color: activeLine),
                ),
              ]),
            ),
          for (var i = 0; i < 4; i++)
            Positioned(
              left: seg * i,
              width: seg,
              top: 0,
              child: Column(children: [
                _circle(i),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(labels[i],
                      style: T.sans(15,
                          color: dark
                              ? (i <= step ? AppColors.gold : Colors.white70)
                              : AppColors.ink,
                          weight: !dark && i == 3 && step == 3 ? FontWeight.w700 : FontWeight.w500)),
                ),
                const SizedBox(height: 4),
                Text(i <= step ? times[i] : '',
                    style: T.sans(13.5, color: dark ? Colors.white70 : AppColors.grey)),
              ]),
            ),
        ]),
      );
    });
  }

  Widget _circle(int i) {
    final done = i <= step;
    if (dark) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? const Color(0xFF5A1219) : Colors.transparent,
          border: Border.all(color: done ? AppColors.gold : Colors.white38, width: done ? 5 : 1.5),
        ),
        child: Icon(
            [Icons.assignment_turned_in_outlined, Icons.inventory_2_outlined, Icons.local_shipping_outlined, Icons.flag_outlined][i],
            color: Colors.white,
            size: 28),
      );
    }
    final isFinal = i == 3 && step == 3;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFinal ? AppColors.green : AppColors.creamLight,
        border: Border.all(color: done ? AppColors.green : AppColors.border, width: 2),
      ),
      child: Icon(
          isFinal
              ? Icons.check
              : [Icons.assignment_outlined, Icons.inventory_2_outlined, Icons.local_shipping_outlined, Icons.flag_outlined][i],
          color: isFinal ? Colors.white : AppColors.green,
          size: isFinal ? 34 : 28),
    );
  }
}

class PartnerCard extends StatelessWidget {
  final VoidCallback onCall;
  const PartnerCard({super.key, required this.onCall});

  @override
  Widget build(BuildContext context) {
    Widget sq(IconData i, VoidCallback f) => Pressable(
          onTap: f,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(i, color: AppColors.green, size: 30),
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const CircleAvatar(radius: 42, backgroundImage: AssetImage('${img}avatar_rahul.png')),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delivery Partner', style: T.sans(14, color: AppColors.grey)),
            Text('Rahul', style: T.serif(26, weight: FontWeight.w600)),
            FittedBox(
                fit: BoxFit.scaleDown, child: Text('+91 98765 43210', style: T.sans(16, color: AppColors.grey))),
          ]),
        ),
        sq(Icons.phone, onCall),
        const SizedBox(width: 10),
        sq(Icons.chat_bubble_outline, () => push(context, const ChatScreen())),
      ]),
    );
  }
}

class AddressInfoCard extends StatelessWidget {
  final Address address;
  final Color iconColor;
  const AddressInfoCard({super.key, required this.address, this.iconColor = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.location_on_outlined, color: iconColor, size: 32),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delivery Address', style: T.sans(14.5, color: AppColors.grey)),
            const SizedBox(height: 2),
            Text(address.name, style: T.serif(24, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${address.line1},\n${address.line2.replaceAll(' - ', ' – ')}',
                style: T.sans(16, color: AppColors.grey, height: 1.45)),
          ]),
        ),
      ]),
    );
  }
}

class HelpBanner extends StatelessWidget {
  final VoidCallback onTap;
  const HelpBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.beigeSoft,
      borderColor: AppColors.beigeSoft,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        const IconBubble(icon: Icons.headset_mic_outlined, size: 70, bg: Color(0xFFE6CFB2), color: AppColors.ink),
        const SizedBox(width: 22),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Need help with your order?', style: T.serif(19, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Contact our support team anytime.', style: T.sans(15, color: AppColors.grey)),
          ]),
        ),
        const Icon(Icons.chevron_right, size: 28),
      ]),
    );
  }
}
