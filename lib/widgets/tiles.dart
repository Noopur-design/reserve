import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../screens/category_screen.dart';
import '../screens/product_detail_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class AppBottomNav extends StatelessWidget {
  /// When shown on a pushed screen, tapping a tab pops back to the shell.
  final bool inShell;
  final int? activeOverride;
  const AppBottomNav({super.key, this.inShell = false, this.activeOverride});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore, 'Explore'),
    (Icons.search, Icons.search, 'Search'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'Orders'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = activeOverride ?? state.tabIndex;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(_items.length, (i) {
              final (icon, activeIcon, label) = _items[i];
              final sel = i == active;
              final color = sel ? AppColors.maroon : AppColors.grey;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    state.setTab(i);
                    if (!inShell) Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: sel ? 1.12 : 1,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(sel ? activeIcon : icon, color: color, size: 28),
                      ),
                      const SizedBox(height: 3),
                      Text(label,
                          style: T.sans(13, color: color, weight: sel ? FontWeight.w600 : FontWeight.w500)),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: sel ? 22 : 0,
                        height: 3,
                        decoration:
                            BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(2)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image tiles
// ---------------------------------------------------------------------------

/// Dark photographic tile with a serif label and a circled arrow (categories,
/// cities).
class PhotoTile extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback? onTap;
  final double radius;
  final double fontSize;
  final bool selected;
  final bool goldBorder;

  /// Small tiles (e.g. the Home category row) drop the arrow and shrink a
  /// long label to fit, so the name is never cut off.
  final bool showArrow;
  const PhotoTile({
    super.key,
    required this.image,
    required this.label,
    this.onTap,
    this.radius = 16,
    this.fontSize = 22,
    this.selected = false,
    this.goldBorder = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? AppColors.maroon : (goldBorder ? AppColors.gold.withValues(alpha: 0.55) : Colors.transparent),
            width: selected ? 3 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(image, fit: BoxFit.cover, alignment: Alignment.topCenter),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [Colors.transparent, Color(0xE6120B08)],
                ),
              ),
            ),
            Positioned(
              left: showArrow ? 12 : 8,
              right: 8,
              bottom: 10,
              child: showArrow
                  ? Row(children: [
                      Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.serif(fontSize, color: Colors.white, weight: FontWeight.w500)),
                      ),
                      Container(
                        width: fontSize * 1.45,
                        height: fontSize * 1.45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.3),
                        ),
                        child: Icon(Icons.arrow_forward, color: Colors.white, size: fontSize * 0.8),
                      ),
                    ])
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(label,
                          maxLines: 1, style: T.serif(fontSize, color: Colors.white, weight: FontWeight.w500)),
                    ),
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Category category;
  final double fontSize;
  final bool goldBorder;
  final bool showArrow;
  final VoidCallback? onTap;
  const CategoryTile(
      {super.key,
      required this.category,
      this.fontSize = 20,
      this.goldBorder = false,
      this.showArrow = true,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return PhotoTile(
      image: category.image,
      label: category.name,
      fontSize: fontSize,
      goldBorder: goldBorder,
      showArrow: showArrow,
      onTap: onTap ?? () => push(context, CategoryScreen(category: category)),
    );
  }
}

// ---------------------------------------------------------------------------
// Product card (listing grid)
// ---------------------------------------------------------------------------

class ProductCard extends StatelessWidget {
  final Product product;

  /// Unique hero tag within the current route (null disables the hero).
  final String? heroTag;
  const ProductCard({super.key, required this.product, this.heroTag});

  // The image gets 11/20 of the card height, the text block 9/20.
  static const _imageFlex = 11;
  static const _textFlex = 9;
  static const _textPadding = EdgeInsets.fromLTRB(12, 10, 10, 10);
  static const _buttonSize = 38.0;
  static final _nameStyle = T.serif(18, weight: FontWeight.w600);
  static final _typeStyle = T.sans(13.5, color: AppColors.grey);
  static final _volumeStyle = T.sans(13, color: AppColors.greyLight);
  static final _priceStyle = T.serif(21, color: AppColors.maroon, weight: FontWeight.w700);

  /// Smallest card height whose text block still fits at the current text
  /// scale (used by [productGridDelegate] so large text never overflows).
  static double minHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Cards always sit inside a Scaffold, whose Material sets bodyMedium as
    // the default text style (it adds a 1.43 line height). Resolve against it
    // like the card's Text widgets do, even when [context] is above the
    // Scaffold.
    final base = Theme.of(context).textTheme.bodyMedium ?? DefaultTextStyle.of(context).style;
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

    final priceRow = line(_priceStyle) > _buttonSize ? line(_priceStyle) : _buttonSize;
    final text = _textPadding.vertical + line(_nameStyle) + 3 + line(_typeStyle) + 4 + line(_volumeStyle) + priceRow;
    // +2 for the 1px border on each side, +2 slack for rounding.
    return text * (_imageFlex + _textFlex) / _textFlex + 4;
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: () => push(context, ProductDetailScreen(product: product, heroTag: heroTag)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: const Color(0xFF6B4A2B).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: _imageFlex,
              child: Stack(fit: StackFit.expand, children: [
                heroTag == null
                    ? Image.asset(product.image, fit: BoxFit.cover)
                    : Hero(tag: heroTag!, child: Image.asset(product.image, fit: BoxFit.cover)),
                Positioned(top: 10, right: 10, child: HeartButton(product: product, size: 38)),
              ]),
            ),
            Expanded(
              flex: _textFlex,
              child: Padding(
                padding: _textPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle),
                    const SizedBox(height: 3),
                    Text(product.type, maxLines: 1, overflow: TextOverflow.ellipsis, style: _typeStyle),
                    const SizedBox(height: 4),
                    Text(product.volume, maxLines: 1, style: _volumeStyle),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(rupees(product.price), style: _priceStyle),
                          ),
                        ),
                        AddSquareButton(product: product),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddSquareButton extends StatelessWidget {
  final Product product;
  const AddSquareButton({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final qty = context.select<AppState, int>((s) => s.qtyInCart(product));
    return Pressable(
      scale: 0.85,
      onTap: () {
        context.read<AppState>().addToCart(product);
        showToast(context, '${product.name} added to cart');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: qty > 0 ? AppColors.maroon : AppColors.goldButton,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: qty > 0
            ? Text('$qty', style: T.sans(15, color: Colors.white, weight: FontWeight.w700))
            : const Icon(Icons.add, color: AppColors.ink, size: 22),
      ),
    );
  }
}

class ProductThumb extends StatelessWidget {
  final String image;
  final double size;
  final double radius;
  const ProductThumb({super.key, required this.image, this.size = 64, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: AppColors.chip,
        width: size,
        height: size,
        child: Image.asset(image, fit: BoxFit.cover),
      ),
    );
  }
}

/// Grid delegate sized to product cards so they look right on any width:
/// the usual 0.6 aspect ratio, taller when the text scale needs more room.
/// [width] is the screen width; the grid has 16px side padding.
SliverGridDelegate productGridDelegate(BuildContext context, double width) {
  const spacing = 14.0;
  final cols = width > 600 ? 3 : 2;
  final cardWidth = (width - 32 - spacing * (cols - 1)) / cols;
  final minHeight = ProductCard.minHeight(context);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    mainAxisExtent: cardWidth / 0.6 > minHeight ? cardWidth / 0.6 : minHeight,
  );
}
