import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

/// Fade + slight slide page route used across the app.
Route<R> fadeRoute<R>(Widget page) {
  return PageRouteBuilder<R>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<R?> push<R>(BuildContext context, Widget page) =>
    Navigator.of(context).push<R>(fadeRoute<R>(page));

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1600)));
}

/// Width of [text] on one line in [style], resolved the way a Text widget
/// would render it at the current text scale.
double textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool arrow;
  final Color color;
  final Color textColor;
  final double height;
  final double radius;
  final IconData? leading;
  final double fontSize;
  final bool centerLabel;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.arrow = true,
    this.color = AppColors.maroon,
    this.textColor = Colors.white,
    this.height = 58,
    this.radius = 14,
    this.leading,
    this.fontSize = 21,
    this.centerLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [Color.lerp(color, Colors.white, 0.06)!, color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              if (arrow && centerLabel) const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: centerLabel ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      Icon(leading, color: textColor, size: 22),
                      const SizedBox(width: 10),
                    ],
                    // A label that doesn't fit (narrow phone, large text)
                    // shrinks a little instead of being cut off.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: centerLabel ? Alignment.center : Alignment.centerLeft,
                        child: Text(label,
                            maxLines: 1, style: T.serif(fontSize, color: textColor, weight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
              if (arrow) Icon(Icons.arrow_forward, color: textColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class OutlineButtonX extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool arrow;
  final Color borderColor;
  final Color textColor;
  final double height;
  final IconData? leading;
  final double fontSize;
  const OutlineButtonX({
    super.key,
    required this.label,
    this.onTap,
    this.arrow = true,
    this.borderColor = AppColors.gold,
    this.textColor = AppColors.ink,
    this.height = 58,
    this.leading,
    this.fontSize = 21,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Icon(leading, color: textColor, size: 22),
              const SizedBox(width: 10),
            ],
            // Shrinks rather than truncates, like PrimaryButton.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: T.serif(fontSize, color: textColor, weight: FontWeight.w500)),
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 14),
              Icon(Icons.arrow_forward, color: textColor, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// Scales down slightly while pressed — gives every tappable a tactile feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color color;
  final double size;
  final Border? border;
  const CircleIconButton(
      {super.key,
      required this.icon,
      this.onTap,
      this.bg = Colors.transparent,
      this.color = AppColors.ink,
      this.size = 44,
      this.border});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border),
        child: Icon(icon, color: color, size: size * 0.55),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Headers
// ---------------------------------------------------------------------------

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool underline;
  final Widget? trailing;
  final VoidCallback? onBack;
  final Color color;
  final double titleSize;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.underline = false,
    this.trailing,
    this.onBack,
    this.color = AppColors.ink,
    this.titleSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (canPop || onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleIconButton(
                      icon: Icons.arrow_back,
                      color: color,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title, style: T.serif(titleSize, color: color, weight: FontWeight.w600)),
                  ),
                ),
                if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing!),
              ],
            ),
          ),
          if (underline)
            Container(
                margin: const EdgeInsets.only(top: 6),
                width: 52,
                height: 2,
                color: AppColors.gold),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 8, 40, 0),
              child: Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: T.sans(15, color: AppColors.grey, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double size;
  final Color actionColor;
  const SectionTitle(this.title,
      {super.key, this.action, this.onAction, this.size = 25, this.actionColor = AppColors.goldText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.serif(size, weight: FontWeight.w600)),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Row(children: [
              Text(action!, style: T.sans(15, color: actionColor)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: actionColor),
            ]),
          ),
      ],
    );
  }
}

class ReserveLogo extends StatelessWidget {
  final Color color;
  final double size;
  final bool tagline;
  const ReserveLogo({super.key, this.color = Colors.white, this.size = 34, this.tagline = true});

  @override
  Widget build(BuildContext context) {
    // The wide letter-spacing makes the lock-up wider than small phones (and
    // large text); scale the whole logo down instead of wrapping mid-word.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('RESERVE',
              maxLines: 1, style: T.serif(size, color: color, weight: FontWeight.w400, spacing: size * 0.55)),
          if (tagline) ...[
            const SizedBox(height: 6),
            Text('SPIRITS  ·  WINE  ·  BEYOND',
                maxLines: 1, style: T.sans(size * 0.34, color: AppColors.gold, spacing: size * 0.16)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards & controls
// ---------------------------------------------------------------------------

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;
  final double borderWidth;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.card,
    this.borderColor = AppColors.border,
    this.radius = 16,
    this.onTap,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6B4A2B).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.985, child: box);
  }
}

/// Card with an illustration pinned to its right edge (help, chat,
/// notification and policy headers). [builder] gets the width left of the
/// picture, so the text wraps before it instead of running underneath.
class IllustratedCard extends StatelessWidget {
  final String image;

  /// Share of the card's width taken by the illustration.
  final double imageFraction;
  final double minHeight;

  /// Minimum height as a share of the card's width (the larger minimum wins).
  final double minHeightFactor;
  final EdgeInsets padding;
  final Widget Function(BuildContext context, double width) builder;
  const IllustratedCard({
    super.key,
    required this.image,
    required this.builder,
    this.imageFraction = 0.32,
    this.minHeight = 0,
    this.minHeightFactor = 0,
    this.padding = const EdgeInsets.all(18),
  });

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(builder: (context, box) {
        final imageW = box.maxWidth * imageFraction;
        final minH = box.maxWidth * minHeightFactor;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH > minHeight ? minH : minHeight),
          child: Stack(alignment: Alignment.centerLeft, children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: imageW,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                child: Image.asset(image, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: padding.copyWith(right: imageW + _gap),
              child: builder(context, box.maxWidth - padding.left - imageW - _gap),
            ),
          ]),
        );
      }),
    );
  }
}

class RadioDot extends StatelessWidget {
  final bool selected;
  final double size;
  final Color color;
  const RadioDot({super.key, required this.selected, this.size = 26, this.color = AppColors.maroon});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(color: selected ? color : AppColors.greyLight, width: 1.5),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Center(
          child: Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 60,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.maroon : const Color(0xFFE2D9CE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final double height;
  final double width;
  final bool highlightCenter;
  const QtyStepper(
      {super.key,
      required this.qty,
      required this.onChanged,
      this.height = 48,
      this.width = 150,
      this.highlightCenter = false});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback f) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: f,
            child: SizedBox(height: height, child: Icon(i, size: 22, color: AppColors.ink)),
          ),
        );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.chip.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          btn(Icons.remove, () => onChanged(qty - 1)),
          Container(
            width: width * 0.3,
            height: height,
            color: highlightCenter ? AppColors.creamLight : Colors.transparent,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('$qty', key: ValueKey(qty), style: T.sans(18, weight: FontWeight.w600)),
            ),
          ),
          btn(Icons.add, () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  final double size;
  const IconBubble(
      {super.key, required this.icon, this.bg = AppColors.maroonSoft, this.color = AppColors.maroon, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

class HeartButton extends StatelessWidget {
  final Product product;
  final bool filledStyle; // wishlist style (pink heart in white circle)
  final double size;
  const HeartButton({super.key, required this.product, this.filledStyle = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final wished = context.select<AppState, bool>((s) => s.isWished(product));
    return Pressable(
      scale: 0.85,
      onTap: () {
        context.read<AppState>().toggleWish(product);
        showToast(context, wished ? 'Removed from wishlist' : 'Added to wishlist');
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: filledStyle ? 0.9 : 0.75),
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            wished ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(wished),
            size: size * 0.6,
            color: wished ? const Color(0xFFC96A6A) : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool trailingChevron;
  const Pill(
      {super.key, required this.label, this.selected = false, this.onTap, this.icon, this.trailingChevron = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.maroon : AppColors.chip,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.ink),
            const SizedBox(width: 8),
          ],
          Text(label, style: T.serif(16, color: selected ? Colors.white : AppColors.ink, spacing: 0)),
          if (trailingChevron) ...[
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 18, color: selected ? Colors.white : AppColors.ink),
          ],
        ]),
      ),
    );
  }
}

/// Fades & slides content in once, with an optional stagger delay.
class FadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const FadeIn({super.key, required this.child, this.delayMs = 0, this.dy = 18});

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
      ),
      child: widget.child,
    );
  }
}

class CartIconBadge extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const CartIconBadge({super.key, required this.onTap, this.color = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    final count = context.select<AppState, int>((s) => s.cartCount);
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(clipBehavior: Clip.none, children: [
          Center(child: Icon(Icons.shopping_cart_outlined, size: 30, color: color)),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 1.5, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                builder: (_, s, c) => Transform.scale(scale: s, child: c),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.maroon, shape: BoxShape.circle),
                  child: Text('$count', style: T.sans(12, color: Colors.white, weight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final IconData? icon;
  final TextInputType? keyboard;
  final int maxLines;
  final String? label;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  const AppTextField({
    super.key,
    required this.hint,
    this.controller,
    this.icon,
    this.keyboard,
    this.maxLines = 1,
    this.label,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: T.sans(16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: T.sans(15, color: AppColors.greyLight),
        labelStyle: T.sans(14, color: AppColors.grey),
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.grey),
        filled: true,
        fillColor: AppColors.creamLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.maroon, width: 1.4)),
      ),
    );
  }
}

/// Standard modal bottom sheet shell.
Future<R?> showAppSheet<R>(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: T.serif(24, weight: FontWeight.w600)),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String confirm = 'Confirm', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: T.serif(22, weight: FontWeight.w600)),
      content: Text(message, style: T.sans(15, color: AppColors.grey, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: T.sans(15, color: AppColors.grey))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm,
                style: T.sans(15, weight: FontWeight.w700, color: destructive ? AppColors.maroon : AppColors.ink))),
      ],
    ),
  );
  return r ?? false;
}
