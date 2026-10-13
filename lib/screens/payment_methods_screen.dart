import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  // Demo-only forms: values stay on the device and only the last 4 digits /
  // UPI handle are kept for display.
  void _addCard(BuildContext context) {
    final state = context.read<AppState>();
    final number = TextEditingController();
    final bank = TextEditingController();
    final key = GlobalKey<FormState>();
    showAppSheet(
      context,
      title: 'Add Card',
      child: Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(
            hint: 'Card number',
            label: 'Card number',
            controller: number,
            icon: Icons.credit_card,
            keyboard: TextInputType.number,
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return d.length < 12 || d.length > 19 ? 'Enter a valid card number' : null;
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            hint: 'e.g. HDFC Bank',
            label: 'Issuing bank',
            controller: bank,
            icon: Icons.account_balance_outlined,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save Card',
            onTap: () {
              if (!key.currentState!.validate()) return;
              final d = number.text.replaceAll(RegExp(r'\D'), '');
              final isVisa = d.startsWith('4');
              state.addPayment(PaymentCard(
                'p${DateTime.now().millisecondsSinceEpoch}',
                bank.text.trim(),
                '•••• ${d.substring(d.length - 4)}',
                isVisa ? '${img}logo_visa.jpg' : '${img}logo_mastercard.jpg',
              ));
              Navigator.pop(context);
              showToast(context, 'Card added');
            },
          ),
        ]),
      ),
    );
  }

  void _addUpi(BuildContext context) {
    final state = context.read<AppState>();
    final id = TextEditingController();
    final key = GlobalKey<FormState>();
    showAppSheet(
      context,
      title: 'Add UPI ID',
      child: Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppTextField(
            hint: 'name@bank',
            label: 'UPI ID',
            controller: id,
            icon: Icons.alternate_email,
            validator: (v) => RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid UPI ID',
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Verify & Save',
            onTap: () {
              if (!key.currentState!.validate()) return;
              state.addPayment(PaymentCard('p${DateTime.now().millisecondsSinceEpoch}', 'UPI', id.text.trim(), '${img}logo_upi.jpg'));
              Navigator.pop(context);
              showToast(context, 'UPI ID saved');
            },
          ),
        ]),
      ),
    );
  }

  void _netBanking(BuildContext context) {
    const banks = ['HDFC Bank', 'ICICI Bank', 'State Bank of India', 'Axis Bank', 'Kotak Mahindra Bank'];
    showAppSheet(
      context,
      title: 'Net Banking',
      child: Column(
        children: banks
            .map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance, color: Color(0xFF8A5A22)),
                  title: Text(b, style: T.sans(16)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.read<AppState>().addPayment(PaymentCard(
                        'p${DateTime.now().millisecondsSinceEpoch}', b, 'Net Banking', '${img}logo_upi.jpg'));
                    Navigator.pop(context);
                    showToast(context, '$b linked for Net Banking');
                  },
                ))
            .toList(),
      ),
    );
  }

  void _addNew(BuildContext context) {
    showAppSheet(
      context,
      title: 'Add Payment Method',
      child: Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.credit_card, color: AppColors.maroon),
          title: Text('Credit or Debit Card', style: T.sans(16)),
          onTap: () {
            Navigator.pop(context);
            _addCard(context);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.qr_code, color: AppColors.maroon),
          title: Text('UPI', style: T.sans(16)),
          onTap: () {
            Navigator.pop(context);
            _addUpi(context);
          },
        ),
      ]),
    );
  }

  void _options(BuildContext context, PaymentCard c) {
    final state = context.read<AppState>();
    showAppSheet(
      context,
      title: c.title,
      child: Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline, color: AppColors.green),
          title: Text('Set as default', style: T.sans(16)),
          onTap: () {
            state.setDefaultPayment(c.id);
            Navigator.pop(context);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.copy, color: AppColors.grey),
          title: Text('Copy details', style: T.sans(16)),
          onTap: () {
            Clipboard.setData(ClipboardData(text: c.subtitle));
            Navigator.pop(context);
            showToast(context, 'Copied');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: AppColors.maroon),
          title: Text('Remove', style: T.sans(16, color: AppColors.maroon)),
          onTap: () {
            state.removePayment(c.id);
            Navigator.pop(context);
            showToast(context, '${c.title} removed');
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Stack(children: [
              Positioned(
                right: 0,
                top: 30,
                width: w * 0.24,
                height: w * 0.4,
                child: Image.asset('${img}illus_leaf_shield.jpg', fit: BoxFit.cover),
              ),
              const PageHeader(
                title: 'Payment Methods',
                titleSize: 32,
                subtitle: 'Manage your payment options for faster and secure checkout.',
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AppCard(
                  color: const Color(0xFFF4E8E2),
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    const IconBubble(icon: Icons.credit_score_outlined, size: 76, bg: Color(0xFFEBD8C8), color: Color(0xFF8A5A22)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your payments are secure',
                            style: T.serif(19, color: AppColors.maroon, weight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('We use industry-standard encryption to keep your information safe.',
                            style: T.sans(14.5, color: AppColors.grey, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 26),
                Row(children: [
                  Expanded(child: Text('Saved Payment Methods', style: T.serif(23, weight: FontWeight.w500))),
                  GestureDetector(
                    onTap: () => _addNew(context),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline, color: AppColors.maroon, size: 28),
                      const SizedBox(width: 8),
                      Text('Add New', style: T.sans(17, color: AppColors.maroon)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                ...state.savedPayments.map((c) {
                  final sel = c.id == state.defaultPaymentId;
                  // Smaller logo and gaps on narrow phones so the name keeps
                  // enough room; the Default chip sits under the details.
                  final narrow = w < 400;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => state.setDefaultPayment(c.id),
                      borderColor: sel ? AppColors.maroon.withValues(alpha: 0.4) : AppColors.border,
                      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                      child: Row(children: [
                        RadioDot(selected: sel, size: 28),
                        SizedBox(width: narrow ? 12 : 18),
                        Container(
                          width: narrow ? 64 : 90,
                          height: narrow ? 50 : 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(c.logo, fit: BoxFit.cover),
                        ),
                        SizedBox(width: narrow ? 12 : 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: T.serif(19, weight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            // Card digits / UPI ID shrink rather than lose characters.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(c.subtitle, maxLines: 1, style: T.sans(15.5, color: AppColors.grey)),
                            ),
                            if (sel) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration:
                                    BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(16)),
                                child: Text('Default', style: T.sans(13.5, color: AppColors.green)),
                              ),
                            ],
                          ]),
                        ),
                        IconButton(onPressed: () => _options(context, c), icon: const Icon(Icons.more_vert)),
                      ]),
                    ),
                  );
                }),
                const Divider(height: 36, color: AppColors.border),
                Text('Add Payment Method', style: T.serif(23, weight: FontWeight.w500)),
                const SizedBox(height: 14),
                for (final (icon, t, s, f) in [
                  (Icons.credit_card, 'Credit or Debit Card', 'Visa, Mastercard, RuPay and more', _addCard),
                  (Icons.qr_code_2, 'UPI', 'Google Pay, PhonePe, Paytm and more', _addUpi),
                  (Icons.account_balance, 'Net Banking', 'All major banks', _netBanking),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => f(context),
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                      child: Row(children: [
                        IconBubble(icon: icon, size: 64, bg: const Color(0xFFF0E1D8), color: AppColors.maroon),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t, style: T.serif(20, weight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(s, style: T.sans(15, color: AppColors.grey)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
                const SizedBox(height: 6),
                AppCard(
                  color: AppColors.greenSoft.withValues(alpha: 0.7),
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    const IconBubble(
                        icon: Icons.verified_user_outlined, size: 64, bg: AppColors.greenSoft, color: AppColors.green),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Safe & Secure Payments', style: T.serif(18, weight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Your payment information is encrypted and secure.',
                            style: T.sans(14.5, color: AppColors.grey)),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
