import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'saved_addresses_screen.dart';

class DeliveryPreferencesScreen extends StatefulWidget {
  const DeliveryPreferencesScreen({super.key});

  @override
  State<DeliveryPreferencesScreen> createState() => _DeliveryPreferencesScreenState();
}

class _DeliveryPreferencesScreenState extends State<DeliveryPreferencesScreen> {
  late final AppState s = context.read<AppState>();
  late int _type = s.deliveryType;
  late bool _email = s.emailNotif;
  late bool _sms = s.smsNotif;
  late String _addrId = s.preferredAddressId;
  late final _instr = TextEditingController(text: s.deliveryInstructions);

  @override
  void dispose() {
    _instr.dispose();
    super.dispose();
  }

  void _chooseAddress() {
    final state = context.read<AppState>();
    showAppSheet(
      context,
      title: 'Preferred Address',
      child: Column(children: [
        ...state.addresses.map((a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: RadioDot(selected: a.id == _addrId, size: 24),
              title: Text('${a.label} · ${a.name}', style: T.serif(17)),
              subtitle: Text('${a.line1}, ${a.line2}', style: T.sans(13, color: AppColors.grey)),
              onTap: () {
                setState(() => _addrId = a.id);
                Navigator.pop(context);
              },
            )),
        const SizedBox(height: 8),
        OutlineButtonX(
          label: 'Manage Addresses',
          fontSize: 18,
          onTap: () {
            Navigator.pop(context);
            push(context, const SavedAddressesScreen());
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final addr = state.addresses.firstWhere((a) => a.id == _addrId, orElse: () => state.addresses.first);

    Widget typeOption(int i, IconData icon, String t, String sub) {
      final sel = _type == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: () => setState(() => _type = i),
          color: sel ? const Color(0xFFF6E6E1) : AppColors.card,
          borderColor: sel ? const Color(0xFFE2B9B0) : AppColors.border,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(children: [
            RadioDot(selected: sel, size: 28),
            const SizedBox(width: 18),
            IconBubble(icon: icon, size: 58, bg: AppColors.maroonSoft),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: T.serif(19, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(sub, style: T.sans(15, color: AppColors.grey)),
              ]),
            ),
          ]),
        ),
      );
    }

    Widget toggle(IconData icon, String t, String sub, bool v, ValueChanged<bool> f, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              border: last ? null : const Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            IconBubble(icon: icon, size: 58, bg: AppColors.maroonSoft),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: T.serif(18, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(sub, style: T.sans(14.5, color: AppColors.grey)),
              ]),
            ),
            AppSwitch(value: v, onChanged: f),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const PageHeader(
            title: 'Delivery Preferences',
            titleSize: 30,
            subtitle: 'Choose your delivery options for a smoother experience.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              children: [
                IllustratedCard(
                  image: '${img}illus_parcel.jpg',
                  imageFraction: 0.3,
                  minHeight: 170,
                  padding: const EdgeInsets.all(20),
                  builder: (context, width) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBubble(icon: Icons.local_shipping_outlined, size: (width * 0.3).clamp(52.0, 68.0)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Flexible delivery, on your terms.',
                            style: T.serif(21, color: AppColors.maroon, weight: FontWeight.w600, height: 1.2)),
                        const SizedBox(height: 8),
                        Text('Set your preferences and we\'ll deliver the way you like.',
                            style: T.sans(14.5, color: AppColors.grey, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                SectionTitle('Preferred Delivery Address', size: 22, action: '', onAction: _chooseAddress),
                const SizedBox(height: 12),
                AppCard(
                  onTap: _chooseAddress,
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  child: Row(children: [
                    const IconBubble(icon: Icons.location_on_outlined, size: 58),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(addr.label, style: T.serif(19, weight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('${addr.line1},\n${addr.line2.replaceAll(' - ', ' – ')}',
                            style: T.sans(15, color: AppColors.grey, height: 1.4)),
                      ]),
                    ),
                    Text('Change', style: T.sans(15, color: AppColors.maroon)),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('Delivery Type', style: T.serif(24, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Choose how you\'d like to receive your orders.', style: T.sans(15.5, color: AppColors.grey)),
                const SizedBox(height: 14),
                typeOption(0, Icons.home_outlined, 'Home Delivery', 'Deliver to my saved address'),
                typeOption(1, Icons.storefront_outlined, 'Pickup from Store', 'I\'ll pick up from a nearby store'),
                typeOption(2, Icons.location_on_outlined, 'Deliver to a Different Address',
                    'Choose a different address at checkout'),
                const SizedBox(height: 16),
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Delivery Instructions ', style: T.serif(22, weight: FontWeight.w500)),
                  TextSpan(text: '(Optional)', style: T.sans(15, color: AppColors.grey)),
                ])),
                const SizedBox(height: 12),
                TextField(
                  controller: _instr,
                  maxLength: 200,
                  maxLines: 3,
                  minLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: T.sans(15.5),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.description_outlined, color: AppColors.grey),
                    ),
                    hintText: 'e.g. Leave at the door, Call before delivery, etc.',
                    hintStyle: T.sans(14.5, color: AppColors.greyLight),
                    filled: true,
                    fillColor: AppColors.card,
                    counterStyle: T.sans(13, color: AppColors.grey),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.maroon)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Notification Preferences', style: T.serif(24, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Choose how you want to be notified about your delivery.',
                    style: T.sans(15.5, color: AppColors.grey)),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Column(children: [
                    toggle(Icons.mail_outline, 'Email Notifications', 'Get order and delivery updates via email',
                        _email, (v) => setState(() => _email = v)),
                    toggle(Icons.phone_iphone, 'SMS Notifications', 'Get delivery updates via SMS', _sms,
                        (v) => setState(() => _sms = v),
                        last: true),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: PrimaryButton(
              label: 'Save Preferences',
              height: 62,
              fontSize: 22,
              onTap: () {
                state.saveDeliveryPrefs(
                  type: _type,
                  instructions: _instr.text.trim(),
                  email: _email,
                  sms: _sms,
                  addressId: _addrId,
                );
                Navigator.pop(context);
                showToast(context, 'Delivery preferences saved');
              },
            ),
          ),
        ]),
      ),
    );
  }
}
