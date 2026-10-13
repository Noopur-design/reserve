import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PageHeader(title: 'Saved Addresses', titleSize: 34, subtitle: 'Manage your delivery addresses'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                PrimaryButton(
                  label: 'Add New Address',
                  leading: Icons.add_circle_outline,
                  arrow: false,
                  height: 64,
                  fontSize: 22,
                  onTap: () async {
                    final a = await showAddressForm(context);
                    if (a != null && context.mounted) showToast(context, 'Address added');
                  },
                ),
                const SizedBox(height: 16),
                ...state.addresses.map((a) {
                  final isDefault = a.id == state.defaultAddressId;
                  final isWork = a.label == 'Work';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FadeIn(
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                        child: Column(children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            IconBubble(
                              icon: Icons.location_on_outlined,
                              size: 60,
                              bg: isWork ? AppColors.greenSoft : AppColors.maroonSoft,
                              color: isWork ? AppColors.green : AppColors.maroon,
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  _LabelChip(label: a.label),
                                  const SizedBox(width: 8),
                                  // Right-aligned; shrinks rather than overflows on narrow phones.
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: isDefault
                                          ? FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                    color: AppColors.greenSoft,
                                                    borderRadius: BorderRadius.circular(20)),
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  const Icon(Icons.check_circle, size: 20, color: AppColors.green),
                                                  const SizedBox(width: 6),
                                                  Text('Default',
                                                      style: T.serif(15, color: AppColors.green, spacing: 0)),
                                                ]),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                Text(a.name, style: T.serif(24, weight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                Text('${a.line1},\n${a.line2.replaceAll(' - ', ' – ')}',
                                    style: T.sans(16, color: AppColors.grey, height: 1.5)),
                              ]),
                            ),
                          ]),
                          const Divider(height: 28, color: AppColors.border),
                          Row(children: [
                            TextButton.icon(
                              onPressed: () => showAddressForm(context, existing: a),
                              icon: const Icon(Icons.edit_outlined, color: AppColors.ink),
                              label: Text('Edit', style: T.sans(16)),
                            ),
                            Container(width: 1, height: 28, color: AppColors.border),
                            TextButton.icon(
                              onPressed: () async {
                                if (state.addresses.length <= 1) {
                                  showToast(context, 'You need at least one address');
                                  return;
                                }
                                final ok = await confirmDialog(context, 'Delete address?',
                                    '${a.label} – ${a.line1} will be removed.',
                                    confirm: 'Delete', destructive: true);
                                if (ok) state.deleteAddress(a.id);
                              },
                              icon: const Icon(Icons.delete_outline, color: AppColors.maroon),
                              label: Text('Delete', style: T.serif(16, color: AppColors.maroon, spacing: 0)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                state.setDefaultAddress(a.id);
                                showToast(context, '${a.label} set as default');
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isDefault ? AppColors.green : AppColors.greyLight, width: 1.6),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: isDefault
                                    ? Container(
                                        decoration:
                                            const BoxDecoration(color: AppColors.green, shape: BoxShape.circle))
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ]),
                        ]),
                      ),
                    ),
                  );
                }),
                AppCard(
                  color: AppColors.greenSoft.withValues(alpha: 0.6),
                  padding: const EdgeInsets.all(18),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      const IconBubble(
                          icon: Icons.local_shipping_outlined, size: 60, bg: AppColors.greenSoft, color: AppColors.green),
                      const VerticalDivider(width: 32, color: AppColors.border),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Delivery available in your area',
                                  style: T.serif(18, color: AppColors.green, weight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('We deliver to all saved addresses', style: T.sans(15, color: AppColors.grey)),
                            ]),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: const AppBottomNav(activeOverride: 4),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final work = label == 'Work';
    final icon = switch (label) {
      'Home' => Icons.home,
      'Work' => Icons.apartment,
      _ => Icons.place,
    };
    final fg = work ? AppColors.green : AppColors.maroon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: work ? AppColors.greenSoft : AppColors.maroonSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 8),
        Text(label, style: T.serif(17, color: fg, spacing: 0)),
      ]),
    );
  }
}
