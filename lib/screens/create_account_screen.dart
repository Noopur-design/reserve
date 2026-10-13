import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'sign_in_screen.dart';
import 'terms_screen.dart';

/// Registers a local (on-device) account, then signs straight in.
class CreateAccountScreen extends StatefulWidget {
  final String? initialPhone;

  /// True when pushed from [SignInScreen]: "Sign in instead" then pops back
  /// with the phone number rather than opening a second sign-in page.
  final bool returnToSignIn;

  /// True when opened from a "Sign in required" prompt: on success the page
  /// pops with `true` (instead of restarting the app on Home) so the user
  /// carries on where they were, e.g. checkout.
  final bool returnOnSuccess;
  const CreateAccountScreen({
    super.key,
    this.initialPhone,
    this.returnToSignIn = false,
    this.returnOnSuccess = false,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _name = TextEditingController();
  late final _phone = TextEditingController(text: widget.initialPhone ?? '');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _termsTap = TapGestureRecognizer()..onTap = () => push(context, const TermsScreen());
  bool _obscure = true;
  bool _agreed = false;
  bool _loading = false;
  Map<String, String?> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors[key] != null) setState(() => _errors = {..._errors, key: null});
  }

  Future<void> _goSignIn([String? phone]) async {
    if (widget.returnToSignIn) {
      Navigator.pop(context, phone ?? '');
    } else if (widget.returnOnSuccess) {
      // Stay underneath so the prompt that opened this page gets the result.
      final ok = await push<bool>(context, SignInScreen(initialPhone: phone, returnOnSuccess: true));
      if (ok == true && mounted) Navigator.pop(context, true);
    } else {
      Navigator.of(context).pushReplacement(fadeRoute(SignInScreen(initialPhone: phone)));
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    final phone = AppState.normalizePhone(_phone.text);
    final email = _email.text.trim();
    final errors = <String, String?>{
      'name': _name.text.trim().length < 2 ? 'Enter your full name' : null,
      'phone': AppState.isValidPhone(phone) ? null : 'Enter a valid 10-digit mobile number',
      'email': email.isNotEmpty && !AppState.isValidEmail(email) ? 'Enter a valid email address' : null,
      'password': _password.text.length < AppState.minPasswordLength
          ? 'Use at least ${AppState.minPasswordLength} characters'
          : null,
      'confirm': _confirm.text != _password.text ? 'Passwords don\'t match' : null,
      'agree': _agreed ? null : 'Please confirm to continue',
    };
    setState(() => _errors = errors);
    if (errors.values.any((e) => e != null)) return;

    if (state.accountExists(phone)) {
      final signIn = await confirmDialog(
        context,
        'Account already exists',
        '+91 ${phone.substring(0, 5)} ${phone.substring(5)} is already registered on this device. '
            'Sign in with it instead?',
        confirm: 'Sign In',
      );
      if (signIn && mounted) _goSignIn(phone);
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final err = state.createAccount(name: _name.text, phone: phone, email: email, password: _password.text);
    setState(() => _loading = false);
    if (err != null) {
      showToast(context, err);
      return;
    }
    TextInput.finishAutofillContext();
    showToast(context, 'Welcome to Reserve, ${state.user?.firstName ?? ''}!');
    if (widget.returnOnSuccess) {
      Navigator.pop(context, true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: Column(children: [
        const AuthTopBar(),
        const ReserveLogo(size: 30),
        const SizedBox(height: 28),
        FadeIn(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Create ', style: T.serif(36, color: Colors.white)),
              TextSpan(text: 'Account', style: T.serif(36, color: AppColors.gold, italic: true)),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text('Create your profile to check out\nand track your orders.',
            textAlign: TextAlign.center,
            style: T.sans(16, color: Colors.white.withValues(alpha: 0.85), height: 1.45)),
        const SizedBox(height: 26),
        AutofillGroup(
          child: Column(children: [
            AuthInput(
              icon: Icons.person_outline,
              hint: 'Full name',
              controller: _name,
              action: TextInputAction.next,
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              error: _errors['name'],
              onChanged: (_) => _clearError('name'),
            ),
            const SizedBox(height: 14),
            AuthInput(
              icon: Icons.phone_iphone,
              hint: 'Mobile number',
              controller: _phone,
              prefix: Text('+91', style: T.sans(17, color: AppColors.gold)),
              keyboard: TextInputType.phone,
              formatters: const [PhoneInputFormatter()],
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              error: _errors['phone'],
              onChanged: (_) => _clearError('phone'),
            ),
            const SizedBox(height: 14),
            AuthInput(
              icon: Icons.mail_outline,
              hint: 'Email (optional)',
              controller: _email,
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              error: _errors['email'],
              onChanged: (_) => _clearError('email'),
            ),
            const SizedBox(height: 14),
            AuthInput(
              icon: Icons.lock_outline,
              hint: 'Create password',
              helper: 'At least ${AppState.minPasswordLength} characters',
              controller: _password,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              action: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              error: _errors['password'],
              onChanged: (_) => _clearError('password'),
            ),
            const SizedBox(height: 14),
            AuthInput(
              icon: Icons.lock_outline,
              hint: 'Confirm password',
              controller: _confirm,
              obscure: _obscure,
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              error: _errors['confirm'],
              onChanged: (_) => _clearError('confirm'),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _AgeCheckbox(
          value: _agreed,
          error: _errors['agree'],
          termsTap: _termsTap,
          onChanged: (v) => setState(() {
            _agreed = v;
            if (v) _errors = {..._errors, 'agree': null};
          }),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _loading
              ? Container(
                  key: const ValueKey('l'),
                  height: 62,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: AppColors.gold),
                )
              : PrimaryButton(
                  key: const ValueKey('b'),
                  label: 'Create Account',
                  height: 62,
                  fontSize: 22,
                  color: const Color(0xFF6E1822),
                  onTap: _submit,
                ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already have an account?  ', style: T.sans(16, color: Colors.white70)),
            GestureDetector(
              onTap: () {
                final phone = AppState.normalizePhone(_phone.text);
                _goSignIn(phone.length == 10 ? phone : null);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sign In', style: T.sans(17, color: AppColors.gold, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _AgeCheckbox extends StatelessWidget {
  final bool value;
  final String? error;
  final TapGestureRecognizer termsTap;
  final ValueChanged<bool> onChanged;
  const _AgeCheckbox({required this.value, required this.error, required this.termsTap, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        checked: value,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: value ? AppColors.gold : Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: error != null ? authErrorColor : AppColors.gold, width: 1.4),
              ),
              child: value ? const Icon(Icons.check, size: 19, color: AppColors.dark) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'I confirm I am of legal drinking age and agree to the '),
                  TextSpan(
                    text: 'Terms & Privacy Policy',
                    recognizer: termsTap,
                    style: T.sans(15, color: AppColors.gold, weight: FontWeight.w600, height: 1.45)
                        .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.gold),
                  ),
                  const TextSpan(text: '.'),
                ]),
                style: T.sans(15, color: Colors.white.withValues(alpha: 0.85), height: 1.45),
              ),
            ),
          ]),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 6, 0, 0),
          child: Text(error!, style: T.sans(14, color: authErrorColor)),
        ),
    ]);
  }
}
