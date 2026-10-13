import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import '../widgets/user_avatar.dart';
import 'cart_screen.dart';
import 'category_screen.dart';
import 'location_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    final featured = [
      productById('macallan18'),
      productById('glenlivet12'),
      productById('hendricks'),
      productById('jameson'),
      productById('absolut'),
      productById('chivas12'),
    ];

    return Container(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ---------- Header ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => state.setTab(4),
                      child: const UserAvatar(size: 56),
                    ),
                    Expanded(
                      child: Column(children: [
                        // Shrinks on narrow phones / large text instead of
                        // breaking the word.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('RESERVE', maxLines: 1, style: T.serif(26, weight: FontWeight.w500, spacing: 9)),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => push(context, const LocationScreen(changeOnly: true)),
                          child: LayoutBuilder(builder: (context, box) {
                            // The city matters most: drop the state, then the
                            // "Delivering to" prefix, before cutting it off.
                            const prefix = 'Delivering to ';
                            final prefixStyle = T.sans(14, color: AppColors.grey);
                            final placeStyle = T.sans(14, weight: FontWeight.w700);
                            final room = box.maxWidth - 18 - 4 - 18; // pin, gap, chevron
                            final prefixW = textWidth(context, prefix, prefixStyle);
                            final options = [
                              (true, state.cityLabel),
                              (true, state.city),
                              (false, state.cityLabel),
                              (false, state.city),
                            ];
                            var (showPrefix, place) = options.last;
                            for (final (withPrefix, text) in options) {
                              if ((withPrefix ? prefixW : 0) + textWidth(context, text, placeStyle) <= room) {
                                (showPrefix, place) = (withPrefix, text);
                                break;
                              }
                            }
                            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.location_on, size: 18, color: AppColors.goldText),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text.rich(
                                  TextSpan(children: [
                                    if (showPrefix) TextSpan(text: prefix, style: prefixStyle),
                                    TextSpan(text: place, style: placeStyle),
                                  ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.grey),
                            ]);
                          }),
                        ),
                      ]),
                    ),
                    IconButton(
                      onPressed: () => state.setTab(2),
                      icon: const Icon(Icons.search, size: 30),
                    ),
                    CartIconBadge(onTap: () => push(context, const CartScreen())),
                  ],
                ),
              ),
            ),

            // ---------- Hero ----------
            SliverToBoxAdapter(
              child: SizedBox(
                height: w * 1.12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: w * 0.85,
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.black, Colors.transparent],
                          stops: [0, 0.72, 1],
                        ).createShader(r),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset('${img}home_hero.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 0,
                      child: FadeIn(
                        child: Column(children: [
                          Text('Pour something', style: T.serif(44, height: 1.0, weight: FontWeight.w500)),
                          Text('memorable.',
                              style: T.serif(46, italic: true, color: const Color(0xFF7A5028), height: 1.1)),
                          const SizedBox(height: 8),
                          Text('Explore spirits selected for every occasion.',
                              style: T.sans(16, color: AppColors.grey)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: _HeroButtons(width: w - 32),
              ),
            ),

            // ---------- Categories ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                child: SectionTitle('Shop by Category',
                    size: 28, action: 'View All', onAction: () => state.setTab(1)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: w * 0.33,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => SizedBox(
                    width: (w - 58) / 4,
                    child: FadeIn(
                        delayMs: 50 * i,
                        child: CategoryTile(category: categories[i], fontSize: 17, showArrow: false)),
                  ),
                ),
              ),
            ),

            // ---------- Featured ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                child: SectionTitle('Curated For You',
                    size: 28,
                    action: 'View All',
                    onAction: () => push(context, CategoryScreen(category: categoryById('whisky')))),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 340,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => SizedBox(width: 200, child: ProductCard(product: featured[i])),
                ),
              ),
            ),

            // ---------- Promo ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                child: Pressable(
                  onTap: () => push(context, ProductDetailScreen(product: productById('macallan18'))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 170,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset('${img}p_macallan_18.jpg', fit: BoxFit.cover, alignment: const Alignment(0, -0.2)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xF0130D0A), Color(0x00130D0A)], stops: [0.35, 0.9]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('RESERVE SELECT',
                                  style: T.sans(12, color: AppColors.gold, spacing: 3, weight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('The Macallan\nDouble Cask 18', style: T.serif(24, color: Colors.white, height: 1.1)),
                              const SizedBox(height: 10),
                              Text('Shop now  →', style: T.sans(14, color: AppColors.gold, weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Shop Collection" + "Explore Premium". Side by side when both labels fit
/// (with their arrows if there's room), otherwise stacked, so a label is
/// never cut off or shrunk to an unreadable size on narrow phones.
class _HeroButtons extends StatelessWidget {
  final double width;
  const _HeroButtons({required this.width});

  static const _gap = 12.0;
  static const _minScale = 0.8; // smallest acceptable label shrink

  @override
  Widget build(BuildContext context) {
    final style = T.serif(18, weight: FontWeight.w500);
    final unit = (width - _gap) / 103; // flex 53 : 50
    final shopRoom = unit * 53 - 44; // PrimaryButton side padding
    final exploreRoom = unit * 50 - 36 - 2.8; // OutlineButtonX side padding + border
    final shopW = textWidth(context, 'Shop Collection', style);
    final exploreW = textWidth(context, 'Explore Premium', style);
    final sideBySide = shopRoom >= shopW * _minScale && exploreRoom >= exploreW * _minScale;
    final arrows = !sideBySide || (shopW + 24 <= shopRoom && exploreW + 36 <= exploreRoom);

    final shop = PrimaryButton(
      label: 'Shop Collection',
      fontSize: 18,
      height: 56,
      radius: 10,
      arrow: arrows,
      centerLabel: !(sideBySide && arrows),
      onTap: () => push(context, CategoryScreen(category: categoryById('whisky'))),
    );
    final explore = OutlineButtonX(
      label: 'Explore Premium',
      fontSize: 18,
      height: 56,
      arrow: arrows,
      onTap: () => push(context, CategoryScreen(category: categoryById('premium'))),
    );
    if (!sideBySide) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [shop, const SizedBox(height: _gap), explore]);
    }
    return Row(children: [
      Expanded(flex: 53, child: shop),
      const SizedBox(width: _gap),
      Expanded(flex: 50, child: explore),
    ]);
  }
}
