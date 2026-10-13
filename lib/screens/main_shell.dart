import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_gate.dart';
import '../widgets/tiles.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.select<AppState, int>((s) => s.tabIndex);
    final guest = context.select<AppState, bool>((s) => s.isGuest);
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<AppState>().setTab(0);
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: KeyedSubtree(
            key: ValueKey('$tab-$guest'),
            child: switch (tab) {
              0 => const HomeScreen(),
              1 => const SearchScreen(),
              2 => const SearchScreen(autofocus: true),
              3 when guest => GuestGate(
                  header: 'My Orders',
                  title: 'Sign in to see your orders',
                  message: 'Track deliveries, reorder favourites and get invoices once you have an account.',
                  onBack: () => context.read<AppState>().setTab(0),
                ),
              3 => const OrdersScreen(inShell: true),
              _ => const ProfileScreen(),
            },
          ),
        ),
        bottomNavigationBar: const AppBottomNav(inShell: true),
      ),
    );
  }
}
