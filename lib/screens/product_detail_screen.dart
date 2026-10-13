import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String? heroTag;
  const ProductDetailScreen({super.key, required this.product, this.heroTag});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _pc = PageController();
  int _page = 0;
  int _qty = 1;
  int? _open;

  Product get p => widget.product;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _addToCart() {
    context.read<AppState>().addToCart(p, _qty);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$_qty × ${p.name} added to cart'),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: AppColors.gold,
          onPressed: () => push(context, const CartScreen()),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final wished = context.select<AppState, bool>((s) => s.isWished(p));
    final heroH = w * 0.95;

    final sections = [
      (Icons.wine_bar_outlined, 'Tasting Notes', p.tastingNotes),
      (Icons.inventory_2_outlined, 'About the Brand', p.aboutBrand),
      (Icons.local_bar_outlined, 'Serving Suggestions', p.serving),
      (
        Icons.description_outlined,
        'Specifications',
        (p.specs.isEmpty
                ? {'Type': p.type, 'Brand': p.brand, 'Volume': p.volume}
                : p.specs)
            .entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n')
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.dark,
                    height: heroH,
                    child: Stack(children: [
                      PageView.builder(
                        controller: _pc,
                        itemCount: 5,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) {
                          final image = Image.asset(p.image,
                              fit: BoxFit.cover,
                              width: w,
                              height: heroH,
                              alignment: Alignment(0, -0.2 + i * 0.1));
                          return i == 0
                              ? (widget.heroTag == null ? image : Hero(tag: widget.heroTag!, child: image))
                              : Transform.scale(scale: 1 + i * 0.08, child: image);
                        },
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: i == _page ? 14 : 10,
                              height: i == _page ? 14 : 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? const Color(0xFFF1DDBE) : Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    transform: Matrix4.translationValues(0, -24, 0),
                    decoration: const BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 120),
                    child: FadeIn(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: T.serif(32, weight: FontWeight.w600, height: 1.1)),
                        const SizedBox(height: 8),
                        Text('${p.type}  ·  ${p.volume}', style: T.sans(17, color: AppColors.grey)),
                        const SizedBox(height: 10),
                        Row(children: [
                          ...List.generate(
                              5,
                              (i) => Icon(i < p.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: const Color(0xFFE39B2D), size: 24)),
                          const SizedBox(width: 8),
                          Text('${p.rating}', style: T.sans(16, weight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('(${_fmt(p.reviews)} reviews)',
                                overflow: TextOverflow.ellipsis, style: T.sans(16, color: AppColors.grey)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _PriceRow(
                          price: rupees(p.price),
                          stepper: QtyStepper(
                            qty: _qty,
                            width: 120,
                            height: 50,
                            highlightCenter: true,
                            onChanged: (v) => setState(() => _qty = v.clamp(1, 12)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(p.description, style: T.sans(16.5, color: AppColors.grey, height: 1.5)),
                        const SizedBox(height: 16),
                        ...List.generate(sections.length, (i) {
                          final (icon, title, body) = sections[i];
                          final open = _open == i;
                          return Column(children: [
                            const Divider(height: 1, color: AppColors.border),
                            InkWell(
                              onTap: () => setState(() => _open = open ? null : i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(children: [
                                  IconBubble(icon: icon, size: 54, bg: AppColors.chip, color: const Color(0xFF7A5028)),
                                  const SizedBox(width: 20),
                                  Expanded(child: Text(title, style: T.serif(21))),
                                  AnimatedRotation(
                                    turns: open ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 250),
                                    child: const Icon(Icons.keyboard_arrow_down, size: 30),
                                  ),
                                ]),
                              ),
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 260),
                              crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              firstChild: const SizedBox(width: double.infinity),
                              secondChild: Padding(
                                padding: const EdgeInsets.fromLTRB(74, 0, 8, 16),
                                child: Text(body, style: T.sans(15, color: AppColors.grey, height: 1.6)),
                              ),
                            ),
                          ]);
                        }),
                        const Divider(height: 1, color: AppColors.border),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            // Top overlay buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  CircleIconButton(
                      icon: Icons.arrow_back_ios_new,
                      size: 44,
                      color: Colors.white,
                      bg: Colors.black26,
                      onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  CircleIconButton(
                    icon: wished ? Icons.favorite : Icons.favorite_border,
                    color: wished ? const Color(0xFFE88A8A) : Colors.white,
                    bg: Colors.black26,
                    onTap: () {
                      context.read<AppState>().toggleWish(p);
                      showToast(context, wished ? 'Removed from wishlist' : 'Added to wishlist');
                    },
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.ios_share,
                    color: Colors.white,
                    bg: Colors.black26,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '${p.name} – ${rupees(p.price)} on Reserve'));
                      showToast(context, 'Product link copied to clipboard');
                    },
                  ),
                ]),
              ),
            ),
            // Bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF5E111B), Color(0xFF4A0C14)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(rupees(p.price * _qty),
                                key: ValueKey(_qty), style: T.serif(34, color: Colors.white, weight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: w * 0.52,
                        child: PrimaryButton(
                          label: 'Add to Cart',
                          color: AppColors.goldButton,
                          textColor: AppColors.ink,
                          height: 64,
                          fontSize: 22,
                          // On narrow phones the label needs the arrow's room.
                          arrow: w >= 400,
                          onTap: _addToCart,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }
}

/// Price, "In Stock" and the quantity stepper on one line when they fit at
/// full size; otherwise the stock line moves under the price so the price
/// never has to shrink.
class _PriceRow extends StatelessWidget {
  final String price;
  final Widget stepper;
  const _PriceRow({required this.price, required this.stepper});

  static const _stepperWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final priceStyle = T.serif(38, color: AppColors.maroon, weight: FontWeight.w700);
    final stockStyle = T.sans(16, color: AppColors.greenStock, weight: FontWeight.w600);
    final stock = Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.greenStock, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('In Stock', style: stockStyle),
    ]);
    return LayoutBuilder(builder: (context, box) {
      // price + divider (1 + 2 x 14) + stock + gap + stepper
      final inline = textWidth(context, price, priceStyle) + 29 + 18 + textWidth(context, 'In Stock', stockStyle) + 12 +
              _stepperWidth <=
          box.maxWidth - 1; // 1px slack for rounding
      if (inline) {
        return Row(children: [
          Text(price, maxLines: 1, style: priceStyle),
          Container(margin: const EdgeInsets.symmetric(horizontal: 14), width: 1, height: 40, color: AppColors.border),
          stock,
          const Spacer(),
          stepper,
        ]);
      }
      return Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(price, maxLines: 1, style: priceStyle),
            ),
            const SizedBox(height: 2),
            stock,
          ]),
        ),
        const SizedBox(width: 12),
        stepper,
      ]);
    });
  }
}
