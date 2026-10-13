import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';

enum SortMode { popular, priceLow, priceHigh, rating }

class CategoryScreen extends StatefulWidget {
  final Category category;
  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  SortMode _sort = SortMode.popular;
  final Set<String> _brands = {};
  RangeValues? _price;
  double _minRating = 0;

  late final List<Product> _base = productsFor(widget.category.id);
  late final int _maxPrice = _base.isEmpty ? 20000 : _base.map((p) => p.price).reduce((a, b) => a > b ? a : b);

  List<Product> get _items {
    var list = _base.where((p) {
      if (_brands.isNotEmpty && !_brands.contains(p.brand)) return false;
      if (_price != null && (p.price < _price!.start || p.price > _price!.end)) return false;
      if (p.rating < _minRating) return false;
      return true;
    }).toList();
    switch (_sort) {
      case SortMode.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortMode.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortMode.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortMode.popular:
        list.sort((a, b) => b.reviews.compareTo(a.reviews));
    }
    return list;
  }

  bool get _hasFilters => _brands.isNotEmpty || _price != null || _minRating > 0;

  void _openSort() {
    const labels = {
      SortMode.popular: 'Popularity',
      SortMode.priceLow: 'Price: Low to High',
      SortMode.priceHigh: 'Price: High to Low',
      SortMode.rating: 'Customer Rating',
    };
    showAppSheet(
      context,
      title: 'Sort By',
      child: Column(
        children: labels.entries
            .map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.value, style: T.sans(16)),
                  trailing: RadioDot(selected: _sort == e.key, size: 22),
                  onTap: () {
                    setState(() => _sort = e.key);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _openBrand() {
    final all = _base.map((p) => p.brand).toSet().toList()..sort();
    final temp = {..._brands};
    showAppSheet(
      context,
      title: 'Brand',
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(children: [
          ...all.map((b) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.maroon,
                value: temp.contains(b),
                title: Text(b, style: T.sans(16)),
                onChanged: (v) => setS(() => v! ? temp.add(b) : temp.remove(b)),
              )),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Apply',
            arrow: false,
            onTap: () {
              setState(() => _brands
                ..clear()
                ..addAll(temp));
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  void _openPrice() {
    var temp = _price ?? RangeValues(0, _maxPrice.toDouble());
    showAppSheet(
      context,
      title: 'Price Range',
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${rupees(temp.start)} – ${rupees(temp.end)}',
              style: T.serif(22, color: AppColors.maroon, weight: FontWeight.w600)),
          RangeSlider(
            values: temp,
            min: 0,
            max: _maxPrice.toDouble(),
            divisions: 40,
            activeColor: AppColors.maroon,
            inactiveColor: AppColors.border,
            onChanged: (v) => setS(() => temp = v),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Apply',
            arrow: false,
            onTap: () {
              setState(() => _price = temp);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  void _openFilter() {
    var rating = _minRating;
    showAppSheet(
      context,
      title: 'Filters',
      child: StatefulBuilder(
        builder: (ctx, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Minimum rating', style: T.serif(18)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [0.0, 4.0, 4.5, 4.7]
                .map((r) => Pill(
                      label: r == 0 ? 'Any' : '$r ★ +',
                      selected: rating == r,
                      onTap: () => setS(() => rating = r),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlineButtonX(
                label: 'Clear All',
                arrow: false,
                fontSize: 18,
                onTap: () {
                  setState(() {
                    _minRating = 0;
                    _brands.clear();
                    _price = null;
                    _sort = SortMode.popular;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Apply',
                arrow: false,
                fontSize: 18,
                onTap: () {
                  setState(() => _minRating = rating);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final items = _items;
    final c = widget.category;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.dark,
                height: 250 + MediaQuery.of(context).padding.top,
                child: Stack(fit: StackFit.expand, children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: w * 0.55,
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        stops: [0, 0.4],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                          c.id == 'whisky' ? '${img}header_whisky.jpg' : c.image,
                          fit: BoxFit.cover),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 20, 40),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleIconButton(
                            icon: Icons.arrow_back, color: Colors.white, onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: FadeIn(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: T.serif(48, color: Colors.white, height: 1)),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: w * 0.6,
                                child: Text(c.tagline,
                                    style: T.sans(16.5, color: Colors.white.withValues(alpha: 0.9), height: 1.35)),
                              ),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                transform: Matrix4.translationValues(0, -24, 0),
                padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Side margins line up with the product grid below.
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(children: [
                      _FilterPill(label: 'Filter', icon: Icons.tune, filled: true, dot: _hasFilters, onTap: _openFilter),
                      const SizedBox(width: 12),
                      _FilterPill(label: 'Sort', icon: Icons.swap_vert, onTap: _openSort, dot: _sort != SortMode.popular),
                      const SizedBox(width: 12),
                      _FilterPill(label: 'Brand', chevron: true, onTap: _openBrand, dot: _brands.isNotEmpty),
                      const SizedBox(width: 12),
                      _FilterPill(label: 'Price', chevron: true, onTap: _openPrice, dot: _price != null),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Text('${items.length} Products', style: T.sans(15, color: AppColors.grey)),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: items.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Icon(Icons.local_bar_outlined, size: 60, color: AppColors.greyLight),
                          const SizedBox(height: 10),
                          Text('No products match your filters', style: T.serif(18)),
                        ]),
                      ),
                    )
                  : SliverGrid.builder(
                      gridDelegate: productGridDelegate(context, w),
                      itemCount: items.length,
                      itemBuilder: (_, i) => FadeIn(delayMs: 40 * (i % 6), child: ProductCard(product: items[i], heroTag: 'cat-${items[i].id}')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final bool chevron;
  final bool dot;
  final VoidCallback onTap;
  const _FilterPill(
      {required this.label, this.icon, this.filled = false, this.chevron = false, this.dot = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: filled ? AppColors.maroon : AppColors.creamLight,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: filled ? AppColors.maroon : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: fg, size: 21), const SizedBox(width: 10)],
          Text(label, style: T.serif(18, color: fg, spacing: 0)),
          if (chevron) ...[const SizedBox(width: 8), Icon(Icons.keyboard_arrow_down, color: fg, size: 22)],
          if (dot) ...[
            const SizedBox(width: 8),
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: filled ? AppColors.gold : AppColors.maroon, shape: BoxShape.circle)),
          ],
        ]),
      ),
    );
  }
}
