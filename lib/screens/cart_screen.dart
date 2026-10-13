import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _instructions(BuildContext context) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: state.specialInstructions);
    showAppSheet(
      context,
      title: 'Special Instructions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppTextField(hint: 'e.g. Gift wrap, ring the bell, call on arrival…', controller: ctrl, maxLines: 4),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Save',
          arrow: false,
          onTap: () {
            state.setSpecialInstructions(ctrl.text.trim());
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }

  void _menu(BuildContext context) {
    final state = context.read<AppState>();
    showAppSheet(
      context,
      title: 'Cart Options',
      child: Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.favorite_border, color: AppColors.maroon),
          title: Text('Move all to wishlist', style: T.sans(16)),
          onTap: () {
            for (final c in state.cart) {
              if (!state.isWished(c.product)) state.toggleWish(c.product);
            }
            state.clearCart();
            Navigator.pop(context);
            showToast(context, 'Moved all items to wishlist');
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: AppColors.maroon),
          title: Text('Clear cart', style: T.sans(16)),
          onTap: () {
            state.clearCart();
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(
            title: 'Your Cart (${state.cartCount})',
            underline: true,
            subtitle: 'Review your items before checkout.',
            trailing: IconButton(onPressed: () => _menu(context), icon: const Icon(Icons.more_vert, size: 28)),
          ),
          Expanded(
            child: state.cart.isEmpty
                ? _empty(context)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      ...state.cart.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Dismissible(
                              key: ValueKey(c.product.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                    color: AppColors.maroonSoft, borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.delete_outline, color: AppColors.maroon, size: 30),
                              ),
                              onDismissed: (_) => _remove(context, c),
                              child: _CartTile(item: c, onRemove: () => _remove(context, c)),
                            ),
                          )),
                      AppCard(
                        onTap: () => _instructions(context),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                        child: Row(children: [
                          const Icon(Icons.edit_note, size: 30),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              state.specialInstructions.isEmpty
                                  ? 'Add special instructions (optional)'
                                  : state.specialInstructions,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: T.sans(16, color: AppColors.grey),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      const OrderSummaryCard(),
                    ],
                  ),
          ),
          if (state.cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: PrimaryButton(
                label: 'Proceed to Checkout',
                height: 64,
                fontSize: 24,
                onTap: () async {
                  if (await requireAccount(context, 'check out') && context.mounted) {
                    push(context, const CheckoutScreen());
                  }
                },
              ),
            ),
        ]),
      ),
    );
  }

  void _remove(BuildContext context, CartItem c) {
    final state = context.read<AppState>();
    state.removeFromCart(c.product);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${c.product.name} removed'),
        action: SnackBarAction(
            label: 'UNDO', textColor: AppColors.gold, onPressed: () => state.addToCart(c.product, c.qty)),
      ));
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: FadeIn(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const IconBubble(icon: Icons.shopping_cart_outlined, size: 110, bg: AppColors.chip, color: AppColors.goldText),
          const SizedBox(height: 18),
          Text('Your cart is empty', style: T.serif(26, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Discover something worth pouring.', style: T.sans(15, color: AppColors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            width: 240,
            child: PrimaryButton(
              label: 'Start Shopping',
              fontSize: 19,
              onTap: () {
                context.read<AppState>().setTab(1);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  const _CartTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final p = item.product;
    final wished = context.select<AppState, bool>((s) => s.isWished(p));
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GestureDetector(
            onTap: () => push(context, ProductDetailScreen(product: p)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 118, child: Image.asset(p.image, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(p.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: T.serif(20, weight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: () => state.toggleWish(p),
                  child: Icon(wished ? Icons.favorite : Icons.favorite_border,
                      color: wished ? const Color(0xFFC96A6A) : AppColors.ink, size: 28),
                ),
              ]),
              const SizedBox(height: 4),
              Text(p.type, style: T.sans(15, color: AppColors.grey)),
              const SizedBox(height: 4),
              Text(p.volume, style: T.sans(15, color: AppColors.grey)),
              const SizedBox(height: 6),
              Text(rupees(p.price), style: T.sans(22, color: AppColors.maroon, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                QtyStepper(
                  qty: item.qty,
                  width: 112,
                  height: 44,
                  onChanged: (v) => v <= 0 ? onRemove() : state.setQty(p, v),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.delete_outline, size: 28),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Expanded(child: Text(l, style: T.sans(16.5, color: AppColors.grey))),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(v, key: ValueKey(v), style: T.sans(16.5)),
            ),
          ]),
        );
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Order Summary', style: T.serif(23, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        row('Subtotal', rupees(s.subtotal)),
        row('Delivery Fee', s.deliveryFee == 0 ? 'Free' : rupees(s.deliveryFee)),
        row('Taxes & Charges', rupees(s.taxes)),
        const Divider(height: 26, color: AppColors.border),
        Row(children: [
          Expanded(child: Text('Total', style: T.serif(28, weight: FontWeight.w700))),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(rupees(s.total),
                key: ValueKey(s.total), style: T.serif(28, color: AppColors.maroon, weight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
