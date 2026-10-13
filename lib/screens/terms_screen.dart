import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'help_screen.dart';
import 'responsible_drinking_screen.dart';

const _policyIcons = [
  Icons.description_outlined,
  Icons.verified_user_outlined,
  Icons.cookie_outlined,
  Icons.published_with_changes,
  Icons.local_shipping_outlined,
  Icons.policy_outlined,
  Icons.people_outline,
  Icons.mail_outline,
];

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const PageHeader(title: 'Terms & Privacy', titleSize: 30),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                IllustratedCard(
                  image: '${img}illus_shield.jpg',
                  imageFraction: 0.4,
                  minHeight: w * 0.72,
                  padding: const EdgeInsets.all(22),
                  builder: (context, width) => FadeIn(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Headline and label shrink rather than wrap next to
                      // the picture on narrow phones.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('OUR COMMITMENT',
                            maxLines: 1,
                            style: T.sans(14, color: AppColors.maroon, spacing: 3, weight: FontWeight.w600)),
                      ),
                      Container(
                          margin: const EdgeInsets.symmetric(vertical: 10), width: 44, height: 2, color: AppColors.maroon),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Your trust\nmatters.',
                            style: T.serif(40, color: AppColors.maroon, weight: FontWeight.w700, height: 1.05)),
                      ),
                      const SizedBox(height: 14),
                      Text('We value your privacy and are committed to keeping your information safe and transparent.',
                          style: T.sans(15, color: AppColors.grey, height: 1.45)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(policies.length, (i) {
                  final (title, sub, _) = policies[i];
                  final even = i.isEven;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeIn(
                      delayMs: 40 * i,
                      child: AppCard(
                        onTap: () {
                          if (i == 6) {
                            push(context, const ResponsibleDrinkingScreen());
                          } else {
                            push(context, PolicyDetailScreen(index: i));
                          }
                        },
                        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                        child: Row(children: [
                          IconBubble(
                            icon: _policyIcons[i],
                            size: 64,
                            bg: even ? const Color(0xFFF4E1DC) : AppColors.greenSoft,
                            color: even ? AppColors.maroon : AppColors.green,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(title, style: T.serif(21, weight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(sub, style: T.sans(15, color: AppColors.grey, height: 1.4)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.grey),
                        ]),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class PolicyDetailScreen extends StatelessWidget {
  final int index;
  const PolicyDetailScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final (title, sub, body) = policies[index];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          PageHeader(title: title, titleSize: 26),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(children: [
                  IconBubble(icon: _policyIcons[index], size: 64),
                  const SizedBox(width: 16),
                  Expanded(child: Text(sub, style: T.sans(16, color: AppColors.grey, height: 1.4))),
                ]),
                const SizedBox(height: 20),
                Text('Last updated: 01 Sep 2026', style: T.sans(13, color: AppColors.greyLight)),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(body, style: T.sans(16, height: 1.65)),
                ),
                const SizedBox(height: 20),
                AppCard(
                  onTap: () => push(context, const HelpScreen()),
                  color: AppColors.beigeSoft,
                  child: Row(children: [
                    const Icon(Icons.help_outline, color: AppColors.maroon),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Questions about this policy? Contact support.', style: T.sans(15))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
