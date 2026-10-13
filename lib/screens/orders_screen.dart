import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/address_form.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'order_detail_screen.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool inShell;
  const OrdersScreen({super.key, this.inShell = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _tab = 0;
  bool _searching = false;
  String _q = '';
  bool _newestFirst = true;

  static const _tabs = ['All Orders', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

  bool _match(Order o) {
    final okTab = switch (_tab) {
      1 => o.status == OrderStatus.processing || o.status == OrderStatus.packed,
      2 => o.status == OrderStatus.shipped || o.status == OrderStatus.outForDelivery,
      3 => o.status == OrderStatus.delivered,
      4 => o.status == OrderStatus.cancelled,
      _ => true,
    };
    if (!okTab) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return o.id.contains(q) || o.items.any((i) => i.product.name.toLowerCase().contains(q));
  }

  void _open(Order o) {
    if (o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled) {
      push(context, OrderDetailScreen(order: o));
    } else {
      push(context, OrderTrackingScreen(order: o));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.orders.where(_match).toList();
    if (!_newestFirst) list.sort((a, b) => a.date.compareTo(b.date));

    // The title is centred, so it may use twice the space left of the two
    // action icons; shrink it for large fonts instead of running under them.
    const actionSize = 44.0;
    final titleRoom = MediaQuery.of(context).size.width - 2 * (12 + 2 * actionSize + 6);
    final titleWidth = textWidth(context, 'My Orders', T.serif(32, weight: FontWeight.w600));
    final titleSize = titleWidth > titleRoom ? (32 * titleRoom / titleWidth).clamp(18.0, 32.0) : 32.0;
    const actionConstraints = BoxConstraints.tightFor(width: actionSize, height: actionSize);

    final body = SafeArea(
      bottom: false,
      child: Column(children: [
        PageHeader(
          title: 'My Orders',
          titleSize: titleSize,
          onBack: widget.inShell ? () => state.setTab(0) : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                constraints: actionConstraints,
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _q = '';
                    }),
                icon: Icon(_searching ? Icons.close : Icons.search, size: 28)),
            IconButton(
              constraints: actionConstraints,
              padding: EdgeInsets.zero,
              onPressed: () => showAppSheet(
                context,
                title: 'Sort Orders',
                child: Column(children: [
                  for (final (v, l) in [(true, 'Newest first'), (false, 'Oldest first')])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l, style: T.sans(16)),
                      trailing: RadioDot(selected: _newestFirst == v, size: 22),
                      onTap: () {
                        setState(() => _newestFirst = v);
                        Navigator.pop(context);
                      },
                    ),
                ]),
              ),
              icon: const Icon(Icons.tune, size: 28),
            ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _searching
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: AppTextField(
                    hint: 'Search by order ID or product',
                    icon: Icons.search,
                    onChanged: (v) => setState(() => _q = v),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 12),
        SizedBox(
          // Grows with the font size so the pills never clip their labels.
          height: (26 + MediaQuery.textScalerOf(context).scale(16) * 1.4).clamp(50.0, 70.0),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => Pill(label: _tabs[i], selected: _tab == i, onTap: () => setState(() => _tab = i)),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.greyLight),
                    const SizedBox(height: 10),
                    Text('No orders here yet', style: T.serif(20)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  itemCount: list.length,
                  itemBuilder: (_, i) => FadeIn(
                    key: ValueKey('${list[i].id}-$_tab'),
                    delayMs: 50 * i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OrderCard(order: list[i], onTap: () => _open(list[i])),
                    ),
                  ),
                ),
        ),
      ]),
    );

    if (widget.inShell) return Container(color: AppColors.cream, child: body);
    return Scaffold(body: body, bottomNavigationBar: const AppBottomNav(activeOverride: 3));
  }
}

class StatusChip extends StatelessWidget {
  final OrderStatus status;
  const StatusChip(this.status, {super.key});

  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  static const _iconSize = 20.0;
  static const _gap = 8.0;
  static TextStyle _labelStyle(Color color) => T.serif(15, color: color, spacing: 0);

  /// Natural width of the widest chip ("Out for Delivery").
  static double _widest(BuildContext context) =>
      _padding.horizontal + _iconSize + _gap + textWidth(context, 'Out for Delivery', _labelStyle(AppColors.ink));

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      OrderStatus.delivered => ('Delivered', Icons.check_circle, AppColors.greenSoft, AppColors.green),
      OrderStatus.outForDelivery => ('Out for Delivery', Icons.local_shipping, const Color(0xFFF6E7CF), const Color(0xFF8A5A14)),
      OrderStatus.shipped => ('Shipped', Icons.local_shipping_outlined, const Color(0xFFF6E7CF), const Color(0xFF8A5A14)),
      OrderStatus.packed => ('Packed', Icons.inventory_2_outlined, AppColors.maroonSoft, AppColors.maroon),
      OrderStatus.processing => ('Processing', Icons.inventory_2_outlined, AppColors.maroonSoft, AppColors.maroon),
      OrderStatus.cancelled => ('Cancelled', Icons.highlight_off, AppColors.chip, AppColors.grey),
    };
    return Container(
      padding: _padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: _iconSize, color: fg),
        const SizedBox(width: _gap),
        Text(label, maxLines: 1, style: _labelStyle(fg)),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  static const _gap = 8.0;
  static const _minThumb = 44.0;

  @override
  Widget build(BuildContext context) {
    final itemsLabel = order.itemsLabel;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Non-breaking spaces keep "12 Oct 2024" and "3 items" whole, so a narrow
    // header wraps at the bullet instead of mid-date.
    final nbsp = String.fromCharCode(0xA0);
    String keep(String s) => s.replaceAll(' ', nbsp);
    final meta = '${keep(fmtDate(order.date))}  •  ${keep(itemsLabel)}';
    final idStyle = T.serif(20, weight: FontWeight.w600);
    final metaStyle = T.sans(14.5, color: AppColors.grey, height: 1.3);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      child: LayoutBuilder(builder: (context, box) {
        // The status chip sits in the header (as in the reference) only when
        // the widest status still leaves the order id and date room; the
        // check uses the widest status so every card makes the same choice.
        // Otherwise it moves down next to "View Details".
        final idRoom = textWidth(context, 'Order ${order.id}', idStyle) * 0.9;
        final metaRoom = textWidth(context, meta, metaStyle);
        final chipInHeader =
            StatusChip._widest(context) + 10 + 22 + (idRoom > metaRoom ? idRoom : metaRoom) <= box.maxWidth;

        // Keep enough room for the price column; thumbnails take what's left.
        final priceRoom = (96 * textScale).clamp(box.maxWidth * 0.3, box.maxWidth * 0.45);
        // Up to three thumbnails, then a "+N" tile for the rest. On narrow
        // cards a thumbnail gives way to the "+N" tile rather than shrinking
        // below [_minThumb] or squeezing the price.
        final fitTiles = ((box.maxWidth - priceRoom) / (_minThumb + _gap)).floor();
        var count = order.items.length < 3 ? order.items.length : 3;
        while (count > 1 && count + (order.items.length > count ? 1 : 0) > fitTiles) {
          count--;
        }
        final shown = order.items.take(count).toList();
        final extra = order.items.length - shown.length;
        final tiles = shown.length + (extra > 0 ? 1 : 0);
        final thumb = ((box.maxWidth - priceRoom - _gap * tiles) / tiles).clamp(_minThumb, 80.0);

        final viewDetails = Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.maroon, width: 1.3),
            ),
            child: Text('View Details',
                maxLines: 1, style: T.serif(16, color: AppColors.maroon, weight: FontWeight.w600, spacing: 0)),
          ),
        );

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Order ${order.id}', maxLines: 1, style: idStyle),
                ),
                const SizedBox(height: 4),
                Text(meta, style: metaStyle),
              ]),
            ),
            if (chipInHeader) ...[
              const SizedBox(width: 10),
              StatusChip(order.status),
            ],
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right, size: 22, color: AppColors.grey),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            for (final item in shown)
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: _ItemThumb(item: item, size: thumb),
              ),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: _MoreTile(count: extra, size: thumb),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(rupees(order.total), maxLines: 1, style: T.serif(22, weight: FontWeight.w700)),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(itemsLabel, maxLines: 1, style: T.sans(15, color: AppColors.grey)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // Status (when not in the header) on the left, shrinking rather
            // than overflowing; the button keeps its natural size.
            Expanded(
              child: chipInHeader
                  ? const SizedBox.shrink()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: StatusChip(order.status),
                    ),
            ),
            const SizedBox(width: 10),
            viewDetails,
          ]),
        ]);
      }),
    );
  }
}

/// Order line thumbnail with an "×2" badge when more than one unit was bought.
class _ItemThumb extends StatelessWidget {
  final CartItem item;
  final double size;
  const _ItemThumb({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        ProductThumb(image: item.product.image, size: size),
        if (item.qty > 1)
          Positioned(
            right: 4,
            bottom: 4,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.maroon,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text('×${item.qty}',
                    style: T.sans(11.5, color: Colors.white, weight: FontWeight.w700, height: 1.2)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// "+N" tile shown after the first three thumbnails.
class _MoreTile extends StatelessWidget {
  final int count;
  final double size;
  const _MoreTile({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('+$count', maxLines: 1, style: T.serif(19, weight: FontWeight.w600, color: AppColors.grey)),
      ),
    );
  }
}
