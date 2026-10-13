import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/common.dart';
import 'order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 0;
  bool _forward = true;

  void _goto(int s) => setState(() {
        _forward = s > _step;
        _step = s;
      });

  Future<bool> _back() async {
    if (_step > 0) {
      _goto(_step - 1);
      return false;
    }
    return true;
  }

  Future<void> _placeOrder() async {
    final state = context.read<AppState>();
    if (!state.ageConfirmed) {
      showToast(context, 'Please confirm you are of legal drinking age');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppColors.maroon),
            const SizedBox(height: 20),
            Text('Processing payment…', style: T.serif(20)),
            const SizedBox(height: 6),
            Text('via ${AppState.paymentNames[state.paymentOption]}', style: T.sans(14, color: AppColors.grey)),
          ]),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.pop(context);
    final order = state.placeOrder();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, c) => Transform.scale(scale: v, child: c),
              child: const IconBubble(icon: Icons.check, size: 84, bg: AppColors.green, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text('Order Placed!', style: T.serif(26, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Order ${order.id}\n${rupees(order.total)} paid via ${order.paymentMethod}',
                textAlign: TextAlign.center, style: T.sans(15, color: AppColors.grey, height: 1.5)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Track Order', fontSize: 19, onTap: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(OrderTrackingScreen(order: order)), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = [_AddressStep(), _DeliveryStep(), _PaymentStep()];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            PageHeader(
              title: 'Checkout',
              titleSize: 34,
              underline: true,
              onBack: () async {
                if (await _back() && context.mounted) Navigator.pop(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: _Stepper(step: _step, onTap: (i) => i < _step ? _goto(i) : null),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) {
                  final isIn = c.key == ValueKey(_step);
                  final dx = (isIn == _forward) ? 0.15 : -0.15;
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                        position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: c),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: pages[_step]),
              ),
            ),
            if (_step < 2)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: PrimaryButton(
                    label: _step == 0 ? 'Continue to Delivery' : 'Continue to Payment',
                    height: 64,
                    fontSize: 24,
                    onTap: () {
                      if (_step == 1 && state.deliveryOption == 1 && state.scheduledSlot == null) {
                        _pickSchedule(context);
                        return;
                      }
                      _goto(_step + 1);
                    },
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF5E111B), Color(0xFF4A0C14)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('Total Amount', style: T.sans(15, color: Colors.white70)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(rupees(state.total),
                                style: T.serif(32, color: Colors.white, weight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      Container(width: 1, height: 50, color: Colors.white24, margin: const EdgeInsets.only(right: 14)),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Place Order',
                          color: AppColors.goldButton,
                          textColor: AppColors.ink,
                          height: 64,
                          fontSize: 22,
                          // On narrow phones the label needs the arrow's room.
                          arrow: MediaQuery.sizeOf(context).width >= 400,
                          onTap: state.ageConfirmed ? _placeOrder : null,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

Future<void> _pickSchedule(BuildContext context) async {
  final state = context.read<AppState>();
  final now = DateTime.now();
  final days = List.generate(6, (i) => DateTime(now.year, now.month, now.day + i + 1));
  var day = state.scheduledDate ?? days.first;
  var slot = state.scheduledSlot ?? '12 PM – 3 PM';
  const slots = ['9 AM – 12 PM', '12 PM – 3 PM', '3 PM – 6 PM', '6 PM – 9 PM'];
  await showAppSheet(
    context,
    title: 'Schedule Delivery',
    child: StatefulBuilder(
      builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date', style: T.serif(18)),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final d = days[i];
              final sel = d == day;
              const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return Pressable(
                onTap: () => setS(() => day = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.maroon : AppColors.creamLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? AppColors.maroon : AppColors.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(wd[d.weekday - 1], style: T.sans(13, color: sel ? Colors.white70 : AppColors.grey)),
                    Text('${d.day}', style: T.serif(22, color: sel ? Colors.white : AppColors.ink)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text('Time slot', style: T.serif(18)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slots.map((s) => Pill(label: s, selected: s == slot, onTap: () => setS(() => slot = s))).toList(),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Confirm Slot',
          arrow: false,
          onTap: () {
            state.setSchedule(day, slot);
            Navigator.pop(ctx);
          },
        ),
      ]),
    ),
  );
}

class _Stepper extends StatelessWidget {
  final int step;
  final ValueChanged<int> onTap;
  const _Stepper({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const labels = ['Address', 'Delivery', 'Payment'];
    final children = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final done = i < step;
      final active = i == step;
      final color = done ? AppColors.green : (active ? AppColors.maroon : AppColors.grey);
      children.add(GestureDetector(
        onTap: () => onTap(i),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.green : (active ? AppColors.maroon : Colors.transparent),
              border: Border.all(color: done || active ? color : AppColors.greyLight, width: 1.4),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, key: ValueKey('c'))
                  : Text('${i + 1}',
                      key: ValueKey('n$i'),
                      style: T.sans(18, color: active ? Colors.white : AppColors.ink, weight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 8),
          Text(labels[i], style: T.serif(17, color: color, spacing: 0)),
        ]),
      ));
      if (i < 2) {
        children.add(Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: 1,
            color: AppColors.greyLight.withValues(alpha: 0.6),
          ),
        ));
      }
    }
    // Lay out at a comfortable minimum width and scale down on narrow phones.
    return LayoutBuilder(
      builder: (_, c) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: c.maxWidth < 400 ? 400 : c.maxWidth, child: Row(children: children)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

class _StepIntro extends StatelessWidget {
  final String title;
  final String sub;
  const _StepIntro(this.title, this.sub);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.serif(32, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub, style: T.sans(16.5, color: AppColors.grey, height: 1.35)),
        ]),
      );
}

class _SelectCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _SelectCard({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: onTap,
        color: selected ? const Color(0xFFF8EDEA) : AppColors.card,
        borderColor: selected ? AppColors.maroon : AppColors.border,
        borderWidth: selected ? 1.4 : 1,
        padding: const EdgeInsets.fromLTRB(18, 20, 20, 20),
        child: child,
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      children: [
        const _StepIntro('Delivery Address', 'Select a delivery address for your order.'),
        ...state.addresses.map((a) {
          final sel = a.id == state.checkoutAddressId;
          return _SelectCard(
            selected: sel,
            onTap: () => state.selectCheckoutAddress(a.id),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              RadioDot(selected: sel, size: 28),
              const SizedBox(width: 22),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(a.name, style: T.serif(22, weight: FontWeight.w600))),
                    GestureDetector(
                      onTap: () => showAddressForm(context, existing: a),
                      child: Text('Edit', style: T.sans(17, color: AppColors.maroon)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('${a.line1}\n${a.line2}\n${a.phone}',
                      style: T.sans(16, color: AppColors.grey, height: 1.55)),
                ]),
              ),
            ]),
          );
        }),
        DashedBorder(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final a = await showAddressForm(context);
              if (a != null) state.selectCheckoutAddress(a.id);
            },
            child: SizedBox(
              height: 92,
              child: Row(children: [
                const SizedBox(width: 50),
                const Icon(Icons.add, color: AppColors.maroon, size: 32),
                const SizedBox(width: 30),
                Text('Add New Address', style: T.serif(21, color: AppColors.maroon)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final est =
        '${fmtShort(now.add(const Duration(days: 3)))} – ${fmtShort(now.add(const Duration(days: 7)))}';

    Widget option(int i, String title, String price, String l1, String l2, IconData icon, Widget foot) {
      final sel = state.deliveryOption == i;
      return _SelectCard(
        selected: sel,
        onTap: () {
          state.setDeliveryOption(i);
          if (i == 1) _pickSchedule(context);
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: RadioDot(selected: sel, size: 28)),
          const SizedBox(width: 22),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: T.serif(22, weight: FontWeight.w600))),
                Text(price, style: T.serif(22, weight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(l1, style: T.sans(16, color: AppColors.grey)),
              const SizedBox(height: 4),
              Text(l2, style: T.sans(15, color: AppColors.grey)),
              const Divider(height: 28, color: AppColors.border),
              Row(children: [
                Icon(icon, color: i == 0 ? AppColors.maroon : AppColors.grey, size: 30),
                const SizedBox(width: 18),
                Expanded(child: foot),
              ]),
            ]),
          ),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      children: [
        const _StepIntro('Delivery Options', 'Choose a delivery option that works best for you.'),
        option(
          0,
          'Standard Delivery',
          '₹99',
          '3 – 5 working days',
          'Reliable and suitable for most areas.',
          Icons.local_shipping_outlined,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estimated delivery', style: T.sans(14, color: AppColors.grey)),
            Text(est, style: T.sans(17, color: AppColors.maroon, weight: FontWeight.w600)),
          ]),
        ),
        option(
          1,
          'Scheduled Delivery',
          '₹99',
          'Choose date & time',
          'Available in select pincodes only.',
          Icons.calendar_month_outlined,
          Text(
            state.scheduledSlot == null
                ? 'Select your preferred date & time at the next step.'
                : '${fmtShort(state.scheduledDate!)}, ${state.scheduledSlot}  ·  Change',
            style: T.sans(14.5,
                color: state.scheduledSlot == null ? AppColors.grey : AppColors.maroon, weight: FontWeight.w600),
          ),
        ),
        option(
          2,
          'Store Pickup',
          'Free',
          'Pick up from our nearest store.',
          'Available in selected cities only.',
          Icons.storefront_outlined,
          Text('You\'ll be notified when your order is ready for pickup.',
              style: T.sans(14.5, color: AppColors.grey)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.beigeSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, color: Color(0xFF7A5028), size: 36),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                  'Delivery availability, timing and charges may vary based on your area and products in your order.',
                  style: T.sans(15, color: const Color(0xFF7A5028), height: 1.4)),
            ),
          ]),
        ),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final opts = [
      (Image.asset('${img}logo_upi.jpg', width: 120), 'UPI', 'Pay with any UPI app (PhonePe, Google Pay, Paytm etc.)'),
      (const Icon(Icons.credit_card, size: 64, color: Color(0xFF1F2A44)), 'Credit / Debit Card', 'Visa, Mastercard, Rupay and more.'),
      (const Icon(Icons.account_balance, size: 58, color: Color(0xFF2555A8)), 'Net Banking', 'Pay through your bank account.'),
      (const Icon(Icons.account_balance_wallet_outlined, size: 58, color: Color(0xFFF07A1A)), 'Wallets', 'Pay using Amazon Pay, Paytm, Mobikwik etc.'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      children: [
        const _StepIntro('Select Payment Method', 'Choose your preferred payment option.'),
        ...List.generate(opts.length, (i) {
          final (logo, title, sub) = opts[i];
          final sel = state.paymentOption == i;
          return _SelectCard(
            selected: sel,
            onTap: () => state.setPaymentOption(i),
            child: IntrinsicHeight(
              child: Row(children: [
                SizedBox(width: 120, child: Center(child: logo)),
                const VerticalDivider(width: 28, color: AppColors.border),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(title, style: T.serif(21, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(sub, style: T.sans(15, color: AppColors.grey, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 10),
                RadioDot(selected: sel, size: 30),
              ]),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.beigeSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.lock, color: Color(0xFFB88A2E), size: 38),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your payment information is secure.', style: T.serif(17, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('We use industry-standard encryption to keep your details safe.',
                    style: T.sans(14, color: AppColors.grey, height: 1.35)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => state.setAgeConfirmed(!state.ageConfirmed),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: state.ageConfirmed ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.green, width: 1.6),
                ),
                child: state.ageConfirmed ? const Icon(Icons.check, color: Colors.white) : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text('Please confirm you are 18+ and of the legal drinking age in your state/UT.',
                    style: T.sans(15.5, height: 1.4)),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
