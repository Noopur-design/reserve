import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'main_shell.dart';
import 'sign_in_screen.dart';

/// "Where should we deliver?" — also reused from Home to change city
/// (pass [changeOnly] so it pops back instead of continuing to sign-in).
class LocationScreen extends StatefulWidget {
  final bool changeOnly;

  /// Onboarding was skipped: Continue / Skip open the store as a guest (no
  /// profile is created) instead of the sign-in page.
  final bool guestEntry;
  const LocationScreen({super.key, this.changeOnly = false, this.guestEntry = false});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _search = TextEditingController();
  String? _city;
  String? _state;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _city = s.city;
    _state = s.state;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<(String, String)> get _all => [
        for (final c in cities) (c.$1, c.$2),
        ...extraCities,
      ];

  void _pick(String c, String s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _city = c;
      _state = s;
      _query = '';
      _search.clear();
    });
  }

  void _continue() {
    if (_query.trim().length == 6 && int.tryParse(_query.trim()) != null) {
      // Pincode entered — accept it as a Gurugram pincode for the demo.
      _city = 'Gurugram';
      _state = 'Haryana';
    }
    if (_city == null) {
      showToast(context, 'Please select a city to continue');
      return;
    }
    final app = context.read<AppState>()..setCity(_city!, _state!);
    if (widget.changeOnly) {
      Navigator.pop(context);
      showToast(context, 'Delivering to ${app.cityLabel}');
    } else {
      _next();
    }
  }

  /// Leaves onboarding: straight into the store as a guest when onboarding
  /// was skipped, otherwise to sign in / create an account.
  void _next() {
    if (widget.guestEntry) {
      context.read<AppState>().continueAsGuest();
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
    } else {
      push(context, const SignInScreen());
    }
  }

  void _viewAll() {
    showAppSheet(
      context,
      title: 'All Cities',
      child: Column(
        children: _all
            .map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.maroon),
                  title: Text(c.$1, style: T.serif(18)),
                  subtitle: Text(c.$2, style: T.sans(13, color: AppColors.grey)),
                  trailing: _city == c.$1 ? const Icon(Icons.check_circle, color: AppColors.maroon) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _pick(c.$1, c.$2);
                  },
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final matches = _query.isEmpty
        ? <(String, String)>[]
        : _all.where((c) => c.$1.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1E9DF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: w * 0.98,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            bottom: 0,
                            width: w * 0.64,
                            height: w * 0.36,
                            child: Opacity(
                                opacity: 0.8,
                                child: Image.asset('${img}map_light.jpg', fit: BoxFit.cover)),
                          ),
                          Positioned(
                            right: 0,
                            top: w * 0.18,
                            bottom: 0,
                            width: w * 0.4,
                            child: ShaderMask(
                              shaderCallback: (r) => const LinearGradient(
                                colors: [Colors.transparent, Colors.black],
                                stops: [0, 0.25],
                              ).createShader(r),
                              blendMode: BlendMode.dstIn,
                              child: Image.asset('${img}india_gate.jpg', fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            left: w * 0.31 - 55,
                            bottom: w * 0.17 - 55,
                            child: const _PulsingPin(),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(children: [
                                CircleIconButton(
                                    icon: Icons.arrow_back,
                                    color: AppColors.goldText,
                                    onTap: () => Navigator.maybePop(context)),
                                const Spacer(),
                                if (!widget.changeOnly)
                                  TextButton(
                                    onPressed: _next,
                                    child: Text('Skip', style: T.sans(18, color: AppColors.goldText)),
                                  ),
                              ]),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            top: 64,
                            width: w * 0.62,
                            child: FadeIn(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(TextSpan(children: [
                                    TextSpan(text: 'Where should\nwe ', style: T.serif(38, height: 1.1)),
                                    TextSpan(
                                        text: 'deliver?',
                                        style: T.serif(38, italic: true, color: AppColors.goldText, height: 1.1)),
                                  ])),
                                  const SizedBox(height: 12),
                                  Text('Enter your location to see product availability and delivery options in your area.',
                                      style: T.sans(15, color: AppColors.grey, height: 1.45)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.creamLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
                        ),
                        child: Row(children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.location_on_outlined, color: AppColors.maroon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _query = v),
                              onSubmitted: (_) => _continue(),
                              style: T.sans(16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search your area, city or pincode',
                                hintStyle: T.sans(15.5, color: AppColors.greyLight),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 28, color: AppColors.border),
                          IconButton(
                            onPressed: () {
                              if (matches.isNotEmpty) _pick(matches.first.$1, matches.first.$2);
                            },
                            icon: const Icon(Icons.search, size: 28),
                          ),
                          const SizedBox(width: 6),
                        ]),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: matches.isEmpty
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: matches
                                      .map((c) => ListTile(
                                            leading: const Icon(Icons.place_outlined, color: AppColors.maroon),
                                            title: Text(c.$1, style: T.serif(17)),
                                            subtitle: Text(c.$2, style: T.sans(13, color: AppColors.grey)),
                                            onTap: () => _pick(c.$1, c.$2),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
                      child: SectionTitle('Popular Cities', size: 27, action: 'View All', onAction: _viewAll),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cities.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92),
                        itemBuilder: (_, i) {
                          final c = cities[i];
                          return FadeIn(
                            delayMs: 50 * i,
                            child: PhotoTile(
                              image: c.$3,
                              label: c.$1,
                              fontSize: 17,
                              selected: _city == c.$1,
                              onTap: () => _pick(c.$1, c.$2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
              child: Column(
                children: [
                  PrimaryButton(label: widget.changeOnly ? 'Save Location' : 'Continue', onTap: _continue, fontSize: 24),
                  const SizedBox(height: 12),
                  Text('Product availability and delivery timings depend\non local state/UT regulations.',
                      textAlign: TextAlign.center, style: T.sans(13, color: AppColors.grey, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingPin extends StatefulWidget {
  const _PulsingPin();

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 50 + 60 * _c.value,
            height: 50 + 60 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.maroon.withValues(alpha: 0.12 * (1 - _c.value)),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -6 - 4 * (0.5 - (_c.value - 0.5).abs())),
            child: const Icon(Icons.location_on, color: AppColors.maroon, size: 52),
          ),
        ]),
      ),
    );
  }
}
