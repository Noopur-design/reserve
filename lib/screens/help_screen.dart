import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'chat_screen.dart';
import 'payment_methods_screen.dart';
import 'terms_screen.dart';
import 'wishlist_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _q = '';
  int? _openFaq;

  static const topics = [
    (Icons.inventory_2_outlined, 'My Orders', 'Track, return\nor cancel'),
    (Icons.credit_card, 'Payments', 'Payment issues\n& refunds'),
    (Icons.local_shipping_outlined, 'Delivery', 'Tracking &\nshipping info'),
    (Icons.view_in_ar_outlined, 'Products', 'Product info\n& availability'),
    (Icons.history, 'Returns &\nRefunds', 'Hassle-free\nreturns'),
    (Icons.person_outline, 'Account', 'Profile, login\n& security'),
    (Icons.favorite_border, 'Wishlist', 'Manage your\nsaved items'),
    (Icons.local_offer_outlined, 'Offers &\nPromotions', 'Discounts &\ncoupons'),
  ];

  Future<void> _topic(int i) async {
    switch (i) {
      case 1:
        // Saved payment methods need an account (same as Profile).
        if (await requireAccount(context, 'manage payment methods') && mounted) {
          push(context, const PaymentMethodsScreen());
        }
      case 4:
        push(context, const PolicyDetailScreen(index: 3));
      case 6:
        push(context, const WishlistScreen());
      default:
        push(context, ChatScreen(initialTopic: topics[i].$2.replaceAll('\n', ' ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final faqList = faqs.where((f) => _q.isEmpty || f.$1.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PageHeader(title: 'Help & Support', titleSize: 32, subtitle: 'We\'re here to help you'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              children: [
                AppTextField(
                  hint: 'Search for help, orders, payments, etc...',
                  icon: Icons.search,
                  onChanged: (v) => setState(() => _q = v),
                ),
                const SizedBox(height: 16),
                // Illustration on the right; the text column gets the rest
                // and never runs underneath it.
                IllustratedCard(
                  image: '${img}illus_headset.jpg',
                  imageFraction: 0.4,
                  minHeightFactor: 0.52,
                  padding: const EdgeInsets.all(20),
                  builder: (context, width) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Need help?',
                          maxLines: 1, style: T.serif(34, color: AppColors.maroon, weight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    Text('Find quick answers or reach out to our support team.',
                        style: T.sans(15.5, color: AppColors.grey, height: 1.4)),
                    const SizedBox(height: 14),
                    _SupportButton(
                      label: 'Contact Support',
                      trailing: Icons.arrow_forward,
                      serif: true,
                      onTap: () => push(context, const ChatScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                _SectionHeader('Popular Topics', size: 26, onViewAll: () => push(context, const ChatScreen())),
                const SizedBox(height: 14),
                _TopicGrid(topics: topics, onTap: _topic),
                const SizedBox(height: 26),
                _SectionHeader('Frequently Asked Questions',
                    size: 24, onViewAll: () => setState(() => _openFaq = null)),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Column(
                    children: List.generate(faqList.length, (i) {
                      final open = _openFaq == i;
                      return Container(
                        decoration: BoxDecoration(
                          border: i == faqList.length - 1
                              ? null
                              : const Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Column(children: [
                          InkWell(
                            onTap: () => setState(() => _openFaq = open ? null : i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(children: [
                                Expanded(child: Text(faqList[i].$1, style: T.sans(16.5))),
                                AnimatedRotation(
                                  turns: open ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: const Icon(Icons.chevron_right, color: AppColors.grey),
                                ),
                              ]),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(faqList[i].$2, style: T.sans(14.5, color: AppColors.grey, height: 1.5)),
                            ),
                          ),
                        ]),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  color: const Color(0xFFF3E6E2),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const IconBubble(icon: Icons.headset_mic_outlined, size: 60, bg: Color(0xFFEBD3CF)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Still need help?',
                              style: T.serif(22, color: AppColors.maroon, weight: FontWeight.w600, height: 1.2)),
                          const SizedBox(height: 4),
                          Text('Our support team is available 24/7 to assist you.',
                              style: T.sans(14, color: AppColors.grey, height: 1.4)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _SupportButton(
                      label: 'Chat with Us',
                      leading: Icons.chat_bubble,
                      onTap: () => push(context, const ChatScreen()),
                    ),
                  ]),
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

/// Section title with a "View All" link. Long titles wrap onto a second line
/// instead of being cut off by the link.
class _SectionHeader extends StatelessWidget {
  final String title;
  final double size;
  final VoidCallback onViewAll;
  const _SectionHeader(this.title, {required this.size, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, maxLines: 2, style: T.serif(size, weight: FontWeight.w600, height: 1.2))),
      const SizedBox(width: 12),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onViewAll,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('View All', style: T.sans(15, color: AppColors.grey)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.grey),
        ]),
      ),
    ]);
  }
}

/// Full-width maroon action button whose label shrinks rather than truncates.
class _SupportButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? leading;
  final IconData? trailing;
  final bool serif;
  const _SupportButton({required this.label, required this.onTap, this.leading, this.trailing, this.serif = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.maroon,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: AppColors.maroon.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[
              Icon(leading, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                maxLines: 1,
                style: serif
                    ? T.serif(16, color: Colors.white, weight: FontWeight.w500)
                    : T.sans(15, color: Colors.white, weight: FontWeight.w600)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Icon(trailing, color: Colors.white, size: 20),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Four-column topic tiles. Every tile uses the same font sizes and the same
/// height (measured from the wrapped text), so titles and subtitles line up
/// and nothing is clipped or broken mid-word at any width or text scale.
class _TopicGrid extends StatelessWidget {
  final List<(IconData, String, String)> topics;
  final ValueChanged<int> onTap;
  const _TopicGrid({required this.topics, required this.onTap});

  static const _cols = 4;
  static const _spacing = 10.0;
  static const _hPad = 4.0;
  static const _icon = 46.0;

  static TextStyle _titleStyle(double size) => T.sans(size, weight: FontWeight.w700, height: 1.2);
  static TextStyle _subStyle(double size) => T.sans(size, color: AppColors.grey, height: 1.3);

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final textScale = scaler.scale(1);
    final base = DefaultTextStyle.of(context).style;
    return LayoutBuilder(builder: (context, box) {
      final tileW = (box.maxWidth - _spacing * (_cols - 1)) / _cols;
      final inner = tileW - 2 * _hPad - 2 - 2; // padding, border, rounding slack

      TextPainter paint(String text, TextStyle style, [double maxWidth = double.infinity]) => TextPainter(
            text: TextSpan(text: text, style: base.merge(style)),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            textScaler: scaler,
          )..layout(maxWidth: maxWidth);

      double widest(Iterable<String> parts, TextStyle style) {
        var w = 0.0;
        for (final part in parts) {
          final p = paint(part, style);
          if (p.width > w) w = p.width;
          p.dispose();
        }
        return w;
      }

      double tallest(Iterable<String> texts, TextStyle style) {
        var h = 0.0;
        for (final t in texts) {
          final p = paint(t, style, inner);
          if (p.height > h) h = p.height;
          p.dispose();
        }
        return h;
      }

      // Largest size (up to [size]) at which every line fits; never below a
      // readable [minPx] on screen, except that a single word must always fit
      // so nothing is split mid-word. Lines that still don't fit wrap.
      double fit(double size, double minPx, List<String> texts, TextStyle Function(double) style) {
        final lineFit = size * inner / widest(texts.expand((t) => t.split('\n')), style(size));
        final wordFit = size * inner / widest(texts.expand((t) => t.split(RegExp(r'\s+'))), style(size));
        final readable = lineFit < minPx / textScale ? minPx / textScale : lineFit;
        return [size, readable, wordFit].reduce((a, b) => a < b ? a : b);
      }

      final titles = [for (final t in topics) t.$2];
      final subs = [for (final t in topics) t.$3];
      final titleSize = fit(14, 11, titles, _titleStyle);
      final subSize = fit(12, 10, subs, _subStyle);
      final titleH = tallest(titles, _titleStyle(titleSize));
      final subH = tallest(subs, _subStyle(subSize));
      // Card padding + icon + gaps + text, +2 border and +2 rounding slack.
      final extent = 12 + _icon + 8 + titleH + 6 + subH + 10 + 4;

      return GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topics.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _cols, mainAxisSpacing: _spacing, crossAxisSpacing: _spacing, mainAxisExtent: extent),
        itemBuilder: (_, i) {
          final (icon, t, s) = topics[i];
          return AppCard(
            onTap: () => onTap(i),
            padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 10),
            child: Column(children: [
              IconBubble(icon: icon, size: _icon, bg: AppColors.maroonSoft),
              const SizedBox(height: 8),
              Text(t, textAlign: TextAlign.center, style: _titleStyle(titleSize)),
              const SizedBox(height: 6),
              // Subtitles sit at the bottom so they line up across a row.
              const Spacer(),
              Text(s, textAlign: TextAlign.center, style: _subStyle(subSize)),
            ]),
          );
        },
      );
    });
  }
}
