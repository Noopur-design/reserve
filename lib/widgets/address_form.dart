import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
String fmtShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Add / edit address bottom sheet. Returns the saved address.
Future<Address?> showAddressForm(BuildContext context, {Address? existing}) {
  final state = context.read<AppState>();
  final name = TextEditingController(text: existing?.name ?? state.userName);
  final line1 = TextEditingController(text: existing?.line1 ?? '');
  final line2 = TextEditingController(text: existing?.line2 ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '+91 ');
  var label = existing?.label ?? 'Home';
  final key = GlobalKey<FormState>();

  return showAppSheet<Address>(
    context,
    title: existing == null ? 'Add New Address' : 'Edit Address',
    child: StatefulBuilder(
      builder: (ctx, setS) => Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            spacing: 10,
            children: ['Home', 'Work', 'Other']
                .map((l) => Pill(label: l, selected: label == l, onTap: () => setS(() => label = l)))
                .toList(),
          ),
          const SizedBox(height: 16),
          AppTextField(
              hint: 'Full name',
              label: 'Name',
              controller: name,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          AppTextField(
              hint: 'Flat / House no., Building, Street',
              label: 'Address line',
              controller: line1,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          AppTextField(
              hint: 'City, State - Pincode',
              label: 'City & Pincode',
              controller: line2,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          AppTextField(
              hint: '+91 98765 43210',
              label: 'Phone',
              controller: phone,
              keyboard: TextInputType.phone,
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Enter a valid phone' : null),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save Address',
            onTap: () {
              if (!key.currentState!.validate()) return;
              final a = Address(
                id: existing?.id ?? 'a${DateTime.now().millisecondsSinceEpoch}',
                name: name.text.trim(),
                line1: line1.text.trim(),
                line2: line2.text.trim(),
                phone: phone.text.trim(),
                label: label,
              );
              state.saveAddress(a);
              Navigator.pop(ctx, a);
            },
          ),
        ]),
      ),
    ),
  );
}

/// Dashed rounded border used by "Add New Address".
class DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  const DashedBorder({super.key, required this.child, this.radius = 16});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(radius), child: child);
}

class _DashPainter extends CustomPainter {
  final double radius;
  _DashPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.greyLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
