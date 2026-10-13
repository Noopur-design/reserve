import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/create_account_screen.dart';
import '../screens/sign_in_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'user_avatar.dart';

// ---------------------------------------------------------------------------
// Guest restrictions: things that need an account (orders, addresses,
// payments, checkout) show one of these instead.
// ---------------------------------------------------------------------------

void openSignIn(BuildContext context) => push(context, const SignInScreen());

void openCreateAccount(BuildContext context) => push(context, const CreateAccountScreen());

/// "Sign In" + "Create Account", stacked so long labels never clip.
class AuthButtons extends StatelessWidget {
  /// Called with `true` for Create Account and `false` for Sign In instead of
  /// opening the page here ([requireAccount] closes its sheet first and
  /// opens the page itself).
  final ValueChanged<bool>? onChoose;
  const AuthButtons({super.key, this.onChoose});

  @override
  Widget build(BuildContext context) {
    void open(bool create) {
      if (onChoose != null) {
        onChoose!(create);
      } else {
        push(context, create ? const CreateAccountScreen() : const SignInScreen());
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PrimaryButton(
        label: 'Sign In',
        arrow: false,
        height: 54,
        fontSize: 19,
        onTap: () => open(false),
      ),
      const SizedBox(height: 12),
      OutlineButtonX(
        label: 'Create Account',
        arrow: false,
        height: 54,
        fontSize: 19,
        borderColor: AppColors.maroon,
        textColor: AppColors.maroon,
        onTap: () => open(true),
      ),
    ]);
  }
}

/// Full-page prompt shown in place of an account-only page for guests.
class GuestGate extends StatelessWidget {
  final String title;
  final String message;

  /// Optional page title shown in a [PageHeader] above the prompt.
  final String? header;
  final VoidCallback? onBack;
  const GuestGate({
    super.key,
    this.title = 'Sign in to continue',
    this.message = 'Create a free account or sign in to check out, track your orders and manage your profile.',
    this.header,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          if (header != null) PageHeader(title: header!, titleSize: 32, onBack: onBack),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (c.maxHeight - 48).clamp(0, double.infinity)),
                  child: FadeIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: UserAvatar(size: 104)),
                        const SizedBox(height: 22),
                        Text(title,
                            textAlign: TextAlign.center, style: T.serif(27, weight: FontWeight.w600, height: 1.2)),
                        const SizedBox(height: 10),
                        Text(message,
                            textAlign: TextAlign.center, style: T.sans(15.5, color: AppColors.grey, height: 1.45)),
                        const SizedBox(height: 28),
                        const AuthButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Returns true straight away for signed-in users. Guests get a sheet
/// explaining why an account is needed ([reason], e.g. "check out") with
/// Sign In / Create Account buttons. The chosen page returns here once the
/// user is in, so this resolves to true and the caller carries on (e.g. to
/// checkout); it resolves to false if they back out.
Future<bool> requireAccount(BuildContext context, String reason) async {
  final state = context.read<AppState>();
  if (state.isSignedIn) return true;
  final nav = Navigator.of(context);
  final create = await showAppSheet<bool>(
    context,
    title: 'Sign in required',
    child: Builder(
      builder: (sheetContext) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const UserAvatar(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Text('You\'re browsing as a guest. Sign in or create a free account to $reason.',
                style: T.sans(15.5, color: AppColors.grey, height: 1.45)),
          ),
        ]),
        const SizedBox(height: 20),
        AuthButtons(onChoose: (create) => Navigator.of(sheetContext).pop(create)),
      ]),
    ),
  );
  if (create == null || !nav.mounted) return state.isSignedIn;
  await nav.push<Object>(fadeRoute<Object>(
    create ? const CreateAccountScreen(returnOnSuccess: true) : const SignInScreen(returnOnSuccess: true),
  ));
  return state.isSignedIn;
}
