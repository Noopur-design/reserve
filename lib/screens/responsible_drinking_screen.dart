import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'help_screen.dart';

class ResponsibleDrinkingScreen extends StatelessWidget {
  const ResponsibleDrinkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final w = MediaQuery.of(context).size.width;
    final tips = [
      (Icons.bar_chart, 'Know your limits', 'Drink slowly and stay within your personal limits.', AppColors.greenSoft, AppColors.green),
      (Icons.directions_car_outlined, 'Never drink and drive', 'Plan a safe ride home.', AppColors.maroonSoft, AppColors.maroon),
      (Icons.water_drop_outlined, 'Stay hydrated', 'Alternate with water and enjoy food.', AppColors.greenSoft, AppColors.green),
      (Icons.eighteen_up_rating_outlined, 'Adults only', 'Alcohol is for adults of legal drinking age.', AppColors.maroonSoft, AppColors.maroon),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PageHeader(title: 'Responsible Drinking', titleSize: 28),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              children: [
                // The header grows with its text (large font sizes) instead of
                // clipping it; the picture fills whatever height that is.
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: w * 0.62),
                  child: Stack(children: [
                    Positioned(
                      right: -10,
                      top: 0,
                      bottom: 0,
                      width: w * 0.42,
                      child: Image.asset('${img}illus_wine_glass.jpg', fit: BoxFit.contain),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 0, 12),
                      child: SizedBox(
                        width: w * 0.55,
                        child: FadeIn(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('RESERVE',
                                style: T.sans(14, color: AppColors.maroon, spacing: 3, weight: FontWeight.w600)),
                            Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                width: 44,
                                height: 2,
                                color: AppColors.maroon),
                            // Shrinks rather than breaking "mindfully".
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('Enjoy\nmindfully',
                                  style: T.serif(44, color: AppColors.maroon, weight: FontWeight.w600, height: 1.05)),
                            ),
                            const SizedBox(height: 12),
                            Text('Good moments begin with responsible choices.',
                                style: T.sans(16.5, color: AppColors.grey, height: 1.4)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                AppCard(
                  color: const Color(0xFFEBE9DF),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('A few things to remember', style: T.serif(26, color: const Color(0xFF1E2B20), weight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    ...List.generate(tips.length, (i) {
                      final (icon, t, s, bg, fg) = tips[i];
                      return FadeIn(
                        delayMs: 80 * i,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: i == tips.length - 1
                                ? null
                                : const Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(children: [
                            IconBubble(icon: icon, size: 64, bg: bg, color: fg),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t, style: T.serif(20, color: const Color(0xFF1E2B20), weight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(s, style: T.sans(15, color: AppColors.grey, height: 1.4)),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 16),
                AppCard(
                  onTap: () => push(context, const HelpScreen()),
                  color: const Color(0xFFF5E6E3),
                  padding: const EdgeInsets.all(20),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      const Icon(Icons.volunteer_activism_outlined, color: AppColors.maroon, size: 60),
                      const VerticalDivider(width: 32, color: Color(0xFFE5C9C4)),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Need support?', style: T.serif(24, color: AppColors.maroon, weight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('If drinking feels difficult to control, reach out to a trusted person or a professional.',
                              style: T.sans(15, color: AppColors.grey, height: 1.4)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.maroon),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => state.setResponsibleAck(!state.responsibleAck),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: state.responsibleAck ? AppColors.maroon : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: AppColors.maroon, width: 1.6),
                        ),
                        child: state.responsibleAck ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text('I understand the importance of responsible drinking.',
                            style: T.sans(16, height: 1.4)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Continue',
                  height: 62,
                  fontSize: 23,
                  onTap: state.responsibleAck
                      ? () {
                          Navigator.pop(context);
                          showToast(context, 'Thank you for drinking responsibly 🍷');
                        }
                      : null,
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
