import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  int _seg = 0;
  String _q = '';
  String _cat = 'all';

  void _filter() {
    showAppSheet(
      context,
      title: 'Filter Wishlist',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Pill(
              label: 'All',
              selected: _cat == 'all',
              onTap: () {
                setState(() => _cat = 'all');
                Navigator.pop(context);
              }),
          ...categories.map((c) => Pill(
                label: c.name,
                selected: _cat == c.id,
                onTap: () {
                  setState(() => _cat = c.id);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    var items = state.wishlist.map(productById).toList();
    if (_seg == 1) items = items.take(3).toList();
    if (_cat != 'all') items = items.where((p) => p.categoryId == _cat).toList();
    if (_q.isNotEmpty) items = items.where((p) => p.name.toLowerCase().contains(_q.toLowerCase())).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PageHeader(title: 'Wishlist', titleSize: 36),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.creamLight,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 18),
                    const Icon(Icons.search, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v),
                        style: T.sans(16),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search in wishlist...',
                          hintStyle: T.sans(16, color: AppColors.greyLight),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              CircleIconButton(
                icon: Icons.tune,
                size: 60,
                bg: _cat == 'all' ? AppColors.chip : AppColors.maroonSoft,
                onTap: _filter,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(30)),
              child: LayoutBuilder(
                builder: (_, c) => Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: _seg == 0 ? 0 : c.maxWidth / 2,
                    width: c.maxWidth / 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration:
                          BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  Row(children: [
                    for (final (i, l) in [(0, 'All Items (${state.wishlist.length})'), (1, 'Recently Added')])
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _seg = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: T.serif(19, color: _seg == i ? Colors.white : AppColors.ink, spacing: 0),
                                  child: Text(l, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                // Scrolls when the keyboard leaves too little room.
                ? LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              IconBubble(icon: Icons.favorite_border, size: box.maxHeight < 260 ? 72 : 100),
                              const SizedBox(height: 16),
                              Text(state.wishlist.isEmpty ? 'Your wishlist is empty' : 'No matching items',
                                  textAlign: TextAlign.center, style: T.serif(22, weight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  state.wishlist.isEmpty
                                      ? 'Tap the heart on any product to save it here.'
                                      : _q.isNotEmpty
                                          ? 'Nothing in your wishlist matches "$_q".'
                                          : 'Nothing in your wishlist matches this filter.',
                                  textAlign: TextAlign.center,
                                  style: T.sans(15, color: AppColors.grey)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(builder: (context, box) {
                    final cols = w > 600 ? 3 : 2;
                    final cardWidth = (box.maxWidth - 32 - 14 * (cols - 1)) / cols;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: _WishCard.extent(context, cardWidth),
                      ),
                      itemBuilder: (_, i) => FadeIn(
                        key: ValueKey(items[i].id),
                        delayMs: 40 * i,
                        child: _WishCard(product: items[i]),
                      ),
                    );
                  }),
          ),
        ]),
      ),
      bottomNavigationBar: const AppBottomNav(activeOverride: 4),
    );
  }
}

class _WishCard extends StatelessWidget {
  final Product product;
  const _WishCard({required this.product});

  static const _imageRatio = 0.78; // image height relative to card width
  static const _padding = EdgeInsets.fromLTRB(12, 10, 12, 12);
  static const _buttonHeight = 42.0;
  static final _nameStyle = T.serif(17, weight: FontWeight.w600);
  static final _metaStyle = T.sans(13.5, color: AppColors.grey);
  static final _priceStyle = T.serif(22, weight: FontWeight.w600);

  /// Card height for [cardWidth]: a proportional image plus the text block
  /// measured at the current text scale, so the card never overflows.
  static double extent(BuildContext context, double cardWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    // Resolve against the inherited style exactly like a Text widget does.
    final base = DefaultTextStyle.of(context).style;
    double line(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: base.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final content = line(_nameStyle) + 2 + line(_metaStyle) * 2 + 6 + line(_priceStyle) + 8 + _buttonHeight;
    // +2 for the 1px border on each side, +2 slack for rounding.
    return cardWidth * _imageRatio + _padding.vertical + content + 4;
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: () => push(context, ProductDetailScreen(product: product)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The image takes whatever height the text block leaves.
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(product.image, fit: BoxFit.cover),
              Positioned(top: 10, right: 10, child: HeartButton(product: product, filledStyle: true, size: 42)),
            ]),
          ),
          Padding(
            padding: _padding,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle),
              const SizedBox(height: 2),
              Text(product.type, maxLines: 1, overflow: TextOverflow.ellipsis, style: _metaStyle),
              Text(product.volume, maxLines: 1, overflow: TextOverflow.ellipsis, style: _metaStyle),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rupees(product.price), maxLines: 1, style: _priceStyle),
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () {
                  context.read<AppState>().addToCart(product);
                  showToast(context, '${product.name} added to cart');
                },
                child: Container(
                  height: _buttonHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(8)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Add to Cart', maxLines: 1, style: T.serif(16, color: Colors.white, spacing: 0)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
