import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'location_screen.dart';

// Shared onboarding chrome. Every page keeps this space free so its content
// never sits under the Skip button or the dots + arrow bar.
const int _kPageCount = 3;
const int _kAgePage = _kPageCount - 1;
const double _kFabSize = 76;
const double _kBarBottom = 24;
const double _kBarHeight = _kFabSize + _kBarBottom;
const double _kTopBarHeight = 48;
const double _kSideGutter = 28;

/// Three-step intro: brand story → categories → age confirmation.
///
/// Pages change only through the arrow, Skip and back controls (no swiping).
/// The dots, arrow and Skip are one overlay owned by this screen, so they look
/// and sit exactly the same on every page.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  /// Whether the age gate was reached with Skip (rather than the arrow).
  /// Skipping means "just let me browse": the store then opens as a guest
  /// without a profile, instead of asking to sign in or create an account.
  bool _skipped = false;

  // The PageView can't be swiped, so _page is only ever set here — the dots
  // and arrow update the moment a control is tapped.
  void _go(int p) {
    if (p < 0 || p > _kAgePage || p == _page) return;
    setState(() => _page = p);
    if (_pc.hasClients) {
      _pc.animateToPage(p, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
    }
  }

  void _next() {
    _skipped = false;
    _go(_page + 1);
  }

  // The age check is mandatory, so Skip lands on the age gate, not the store.
  void _skip() {
    _skipped = true;
    _go(_kAgePage);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onAgeGate = _page == _kAgePage;
    return PopScope<Object?>(
      // Android back steps to the previous page instead of closing the app.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.dark,
          body: Stack(
            children: [
              Positioned.fill(
                child: PageView(
                  controller: _pc,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    const _IntroPage(),
                    _ExplorePage(onNext: _next),
                    AgeGatePage(onBack: () => _go(1), bottomInset: _kBarHeight, guestEntry: _skipped),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: _kTopBarHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: onAgeGate
                              ? const SizedBox.shrink()
                              : TextButton(
                                  key: const Key('onboarding-skip'),
                                  onPressed: _skip,
                                  child: Text('Skip', style: T.sans(18, color: AppColors.gold)),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(_kSideGutter, 0, _kSideGutter, _kBarBottom),
                    child: SizedBox(
                      height: _kFabSize,
                      child: Row(
                        children: [
                          _Dots(_page),
                          const Spacer(),
                          // Hidden on the age gate so it can't bypass the 18+ confirmation.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(a), child: c),
                            ),
                            child: onAgeGate
                                ? const SizedBox(width: _kFabSize, height: _kFabSize)
                                : _NextFab(key: const Key('onboarding-next'), onTap: _next),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int index;
  const _Dots(this.index);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $_kPageCount',
      child: Row(
        key: const Key('onboarding-dots'),
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_kPageCount, (i) {
          final a = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(right: i == _kPageCount - 1 ? 0 : 10),
            width: a ? 34 : 14,
            height: 8,
            decoration: BoxDecoration(
              color: a ? AppColors.gold : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }
}

class _NextFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NextFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Next',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: _kFabSize,
          height: _kFabSize,
          decoration: BoxDecoration(
            color: const Color(0xFF7A1A24),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2),
            boxShadow: [BoxShadow(color: const Color(0xFF7A1A24).withValues(alpha: 0.5), blurRadius: 20)],
          ),
          child: const Icon(Icons.arrow_forward, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// Fills the available height on tall screens (so Spacers still push content
/// apart) and scrolls instead of overflowing on short screens / large text.
/// [bottomInset] keeps room for the shared dots bar below the scroll area.
class _FillScroll extends StatelessWidget {
  final Widget child;
  final double horizontal;
  final double bottomInset;
  const _FillScroll({required this.child, required this.horizontal, this.bottomInset = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: h * 0.12,
          left: 0,
          right: 0,
          height: h * 0.56,
          child: Image.asset('${img}onboard_hero.jpg', fit: BoxFit.cover),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.14, 0.2, 0.58, 0.7],
              colors: [AppColors.dark, AppColors.dark, Color(0x00130D0A), Color(0x00130D0A), AppColors.dark],
            ),
          ),
        ),
        SafeArea(
          child: _FillScroll(
            horizontal: _kSideGutter,
            bottomInset: _kBarHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Center(child: FadeIn(child: ReserveLogo(size: 38))),
                const Spacer(),
                FadeIn(
                  delayMs: 150,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Good taste\ndeserves a better\n', style: T.serif(40, color: Colors.white, height: 1.08)),
                      TextSpan(
                          text: 'experience.',
                          style: T.serif(42, color: AppColors.gold, italic: true, height: 1.1)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                FadeIn(
                  delayMs: 300,
                  child: Text('Discover thoughtfully selected\nspirits, wines and beverages\nfrom trusted retailers.',
                      style: T.sans(17, color: Colors.white.withValues(alpha: 0.9), height: 1.35, weight: FontWeight.w400)),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplorePage extends StatelessWidget {
  final VoidCallback onNext;
  const _ExplorePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16201A), AppColors.darkGreen, Color(0xFF0B120D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 60,
            width: w * 0.46,
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Colors.black],
                stops: [0, 0.35],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('${img}hero_glass.jpg', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: _kTopBarHeight), // room for the shared Skip button
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text.rich(TextSpan(children: [
                          TextSpan(
                              text: 'Explore\na world of\n',
                              style: T.serif(40, color: const Color(0xFFF3ECE2), height: 1.05)),
                          TextSpan(
                              text: 'possibilities.',
                              style: T.serif(40, color: AppColors.gold, italic: true, height: 1.1)),
                        ])),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: w * 0.58,
                          child: Text('Whisky, wine, gin, vodka, rum, tequila, beer and more — all in one place.',
                              style: T.sans(15, color: Colors.white.withValues(alpha: 0.8), height: 1.4)),
                        ),
                        const SizedBox(height: 26),
                        GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.45),
                          itemBuilder: (_, i) => FadeIn(
                            delayMs: 60 * i,
                            child: CategoryTile(
                                category: categories[i], fontSize: 21, goldBorder: true, onTap: onNext),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _kBarHeight), // room for the shared dots + arrow bar
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Final onboarding step: 18+ confirmation before entering the store.
///
/// [onBack] returns to the previous onboarding page. [bottomInset] is extra
/// space kept free at the bottom for the onboarding screen's shared dots bar
/// (leave it at 0 when the page is shown on its own). [guestEntry] is set
/// when onboarding was skipped: after the city step the store opens as a
/// guest instead of asking to sign in.
class AgeGatePage extends StatelessWidget {
  final VoidCallback onBack;
  final double bottomInset;
  final bool guestEntry;
  const AgeGatePage({super.key, required this.onBack, this.bottomInset = 0, this.guestEntry = false});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: h * 0.1,
          left: 0,
          right: 0,
          height: h * 0.46,
          child: Image.asset('${img}age_hero.jpg', fit: BoxFit.cover),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.12, 0.2, 0.46, 0.58],
              colors: [AppColors.dark, AppColors.dark, Color(0x00130D0A), Color(0x22130D0A), AppColors.dark],
            ),
          ),
        ),
        SafeArea(
          child: _FillScroll(
            horizontal: 26,
            bottomInset: bottomInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(children: [
                  CircleIconButton(icon: Icons.arrow_back, color: Colors.white, onTap: onBack),
                ]),
                const Center(child: ReserveLogo(size: 32)),
                const Spacer(),
                Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.4),
                  ),
                  child: Text('18+', style: T.sans(22, color: AppColors.gold, weight: FontWeight.w500)),
                ),
                const SizedBox(height: 16),
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Welcome\nto ', style: T.serif(44, color: const Color(0xFFF6EFE6), height: 1.05)),
                  TextSpan(text: 'Reserve.', style: T.serif(44, color: AppColors.gold, height: 1.05)),
                ])),
                const SizedBox(height: 12),
                Text('Please confirm that you are of the legal drinking age applicable in your state/UT.',
                    style: T.sans(17, color: Colors.white.withValues(alpha: 0.78), height: 1.35)),
                const SizedBox(height: 26),
                PrimaryButton(
                  label: 'I am 18+  ·  Enter Store',
                  color: const Color(0xFF6E1822),
                  onTap: () {
                    context.read<AppState>().completeOnboarding();
                    push(context, LocationScreen(guestEntry: guestEntry));
                  },
                ),
                const SizedBox(height: 14),
                OutlineButtonX(
                  label: 'Exit',
                  textColor: Colors.white,
                  onTap: () async {
                    final ok = await confirmDialog(
                        context, 'Exit Reserve?', 'You must be of legal drinking age to use this app.',
                        confirm: 'Exit');
                    if (!ok) return;
                    if (kIsWeb) {
                      // A web page can't close itself; say how to leave.
                      if (context.mounted) showToast(context, 'You can close this tab to leave Reserve');
                    } else {
                      SystemNavigator.pop();
                    }
                  },
                ),
                const SizedBox(height: 22),
                Center(
                  child: Text('Drink Responsibly\nAvailability and delivery are subject to local laws and regulations.',
                      textAlign: TextAlign.center,
                      style: T.sans(13, color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
                ),
                // Inside onboarding the dots bar below already gives breathing room.
                if (bottomInset == 0) const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
