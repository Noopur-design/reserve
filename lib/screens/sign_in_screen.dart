import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'create_account_screen.dart';
import 'main_shell.dart';

/// Demo one-time code: there is no SMS backend in this offline build.
const demoOtp = '123456';

/// Error text colour that stays readable on the dark auth screens.
const authErrorColor = Color(0xFFFF9C8F);

String _pretty(String phone) =>
    phone.length == 10 ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}' : phone;

/// Mobile number fields: digits only, at most 10. A pasted or autofilled
/// "+91 98765 43210" / "098765 43210" loses its prefix first (see
/// [AppState.normalizePhone]), instead of being cut to the wrong 10 digits.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits == newValue.text && digits.length <= 10) return newValue;
    var phone = AppState.normalizePhone(digits);
    if (phone.length > 10) {
      // Typing past a full number: keep what's there.
      if (AppState.normalizePhone(oldValue.text).length >= 10) return oldValue;
      phone = phone.substring(0, 10);
    }
    return TextEditingValue(text: phone, selection: TextSelection.collapsed(offset: phone.length));
  }
}

class SignInScreen extends StatefulWidget {
  final String? initialPhone;

  /// True when opened from a "Sign in required" prompt: after signing in (or
  /// creating an account) the page pops with `true` so the user carries on
  /// where they were, e.g. checkout.
  final bool returnOnSuccess;
  const SignInScreen({super.key, this.initialPhone, this.returnOnSuccess = false});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _phone = TextEditingController(text: widget.initialPhone ?? '');
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enterApp() {
    if (widget.returnOnSuccess) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const MainShell()), (_) => false);
    }
  }

  void _skip() {
    context.read<AppState>().continueAsGuest();
    _enterApp();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    final phone = AppState.normalizePhone(_phone.text);
    setState(() {
      _phoneError = phone.length != 10 ? 'Enter your 10-digit mobile number' : null;
      _passwordError = _password.text.isEmpty ? 'Enter your password' : null;
    });
    if (_phoneError != null || _passwordError != null) return;

    if (!state.accountExists(phone)) {
      final create = await confirmDialog(
        context,
        'No account found',
        'There\'s no Reserve account for ${_pretty(phone)} on this device yet. '
            'Create one to start ordering.',
        confirm: 'Create Account',
      );
      if (create && mounted) _openCreate(phone);
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final err = state.signIn(phone, _password.text);
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _passwordError = err);
      return;
    }
    TextInput.finishAutofillContext();
    showToast(context, 'Welcome back, ${state.user?.firstName ?? ''}');
    _enterApp();
  }

  Future<void> _openCreate([String? phone]) async {
    final digits = AppState.normalizePhone(phone ?? _phone.text);
    final back = await push<Object>(
      context,
      CreateAccountScreen(
        initialPhone: digits.length == 10 ? digits : null,
        returnToSignIn: true,
        returnOnSuccess: widget.returnOnSuccess,
      ),
    );
    if (!mounted) return;
    // Account created (only reported back in returnOnSuccess mode).
    if (back == true) {
      _enterApp();
      return;
    }
    // Came back via "Sign in instead" with the number to use.
    if (back is String) {
      setState(() {
        if (back.isNotEmpty) _phone.text = back;
        _password.clear();
        _phoneError = null;
        _passwordError = null;
      });
    }
  }

  Future<void> _social(String provider) async {
    final create = await confirmDialog(
      context,
      '$provider sign-in unavailable',
      'Signing in with $provider needs an online account server, which this offline build of '
          'Reserve doesn\'t have. You can create a Reserve account with your mobile number instead '
          '— it takes less than a minute.',
      confirm: 'Create Account',
    );
    if (create && mounted) _openCreate();
  }

  Future<void> _forgot() async {
    FocusScope.of(context).unfocus();
    final phone = await showAppSheet<String>(
      context,
      title: 'Reset Password',
      child: _ForgotPasswordSheet(initialPhone: AppState.normalizePhone(_phone.text)),
    );
    if (phone == null || !mounted) return;
    setState(() {
      _phone.text = phone;
      _password.clear();
      _phoneError = null;
      _passwordError = null;
    });
    showToast(context, 'Password updated. Sign in with your new password.');
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: Column(
        children: [
          AuthTopBar(
            // From a "Sign in required" prompt the back arrow already returns
            // to browsing as a guest.
            trailing: widget.returnOnSuccess
                ? null
                : TextButton(onPressed: _skip, child: Text('Skip', style: T.sans(18, color: AppColors.gold))),
          ),
          const ReserveLogo(size: 34),
          const SizedBox(height: 36),
          FadeIn(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Welcome ', style: T.serif(44, color: Colors.white)),
                TextSpan(text: 'Back', style: T.serif(44, color: AppColors.gold, italic: true)),
              ]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Text('Sign in to continue your journey\nwith India\'s curated liquor collection.',
              textAlign: TextAlign.center,
              style: T.sans(16, color: Colors.white.withValues(alpha: 0.85), height: 1.45)),
          const SizedBox(height: 28),
          AutofillGroup(
            child: Column(children: [
              AuthInput(
                icon: Icons.phone_iphone,
                hint: 'Mobile number',
                controller: _phone,
                prefix: Text('+91', style: T.sans(17, color: AppColors.gold)),
                keyboard: TextInputType.phone,
                formatters: const [PhoneInputFormatter()],
                action: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                error: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
              ),
              const SizedBox(height: 18),
              AuthInput(
                icon: Icons.lock_outline,
                hint: 'Enter your password',
                controller: _password,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                action: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _signIn(),
                error: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
              ),
            ]),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgot,
              child: Text('Forgot Password?', style: T.sans(16, color: AppColors.gold)),
            ),
          ),
          const SizedBox(height: 4),
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
                    label: 'Sign In',
                    height: 62,
                    fontSize: 24,
                    color: const Color(0xFF6E1822),
                    onTap: _signIn,
                  ),
          ),
          const SizedBox(height: 26),
          Row(children: [
            Expanded(child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.35))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('OR CONTINUE WITH',
                  style: T.sans(13, color: Colors.white70, spacing: 2, weight: FontWeight.w600)),
            ),
            Expanded(child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.35))),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _SocialBtn(label: 'Google', onTap: () => _social('Google'), child: const _GoogleG()),
            const SizedBox(width: 12),
            _SocialBtn(
                label: 'Apple',
                onTap: () => _social('Apple'),
                child: const Icon(Icons.apple, color: Colors.white, size: 34)),
            const SizedBox(width: 12),
            _SocialBtn(
                label: 'Email',
                onTap: () => _openCreate(),
                child: const Icon(Icons.mail, color: Colors.white, size: 30)),
          ]),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Don\'t have an account?  ', style: T.sans(16, color: Colors.white70)),
              GestureDetector(
                onTap: () => _openCreate(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Create Account', style: T.sans(17, color: AppColors.gold, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot password: phone -> OTP + new password
// ---------------------------------------------------------------------------

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialPhone;
  const _ForgotPasswordSheet({required this.initialPhone});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final state = context.read<AppState>();
    final phone = AppState.normalizePhone(_phone.text);
    if (phone.length != 10) {
      setState(() => _error = 'Enter your 10-digit mobile number');
      return;
    }
    if (!state.accountExists(phone)) {
      setState(() => _error = 'No account found for ${_pretty(phone)}. Check the number or create an account.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _codeSent = true;
    });
  }

  void _reset() {
    final state = context.read<AppState>();
    final phone = AppState.normalizePhone(_phone.text);
    String? err;
    if (_otp.text.trim() != demoOtp) {
      err = 'That code isn\'t right. Check it and try again.';
    } else if (_pass.text.length < AppState.minPasswordLength) {
      err = 'Password must be at least ${AppState.minPasswordLength} characters';
    } else if (_pass.text != _confirm.text) {
      err = 'Passwords don\'t match';
    } else {
      err = state.resetPassword(phone, _pass.text);
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, phone);
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix, String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: T.sans(13, color: AppColors.goldText),
        labelStyle: T.sans(14, color: AppColors.grey),
        prefixIcon: Icon(icon, color: AppColors.grey),
        suffixIcon: suffix,
        counterText: '',
        filled: true,
        fillColor: AppColors.creamLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.maroon, width: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    final phone = AppState.normalizePhone(_phone.text);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_codeSent) ...[
          Text('Enter the mobile number you registered with and we\'ll send you a one-time code.',
              style: T.sans(15, color: AppColors.grey, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: const [PhoneInputFormatter()],
            style: T.sans(16),
            onSubmitted: (_) => _sendOtp(),
            decoration: _dec('Mobile number', Icons.phone_iphone).copyWith(prefixText: '+91  '),
          ),
        ] else ...[
          Text('Enter the 6-digit code sent to ${_pretty(phone)} and choose a new password.',
              style: T.sans(15, color: AppColors.grey, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            style: T.sans(16, spacing: 4),
            decoration: _dec('One-time code', Icons.sms_outlined,
                helper: 'Demo build: no SMS is sent. Use code $demoOtp.'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            style: T.sans(16),
            decoration: _dec('New password', Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.grey),
                )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            style: T.sans(16),
            onSubmitted: (_) => _reset(),
            decoration: _dec('Confirm new password', Icons.lock_outline),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: T.sans(14, color: AppColors.maroon, height: 1.35)),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: _codeSent ? 'Reset Password' : 'Send OTP',
          arrow: false,
          onTap: _codeSent ? _reset : _sendOtp,
        ),
        if (_codeSent)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(alignment: WrapAlignment.spaceBetween, children: [
              TextButton(
                onPressed: () => setState(() {
                  _codeSent = false;
                  _error = null;
                  _otp.clear();
                }),
                child: Text('Change number', style: T.sans(15, color: AppColors.goldText)),
              ),
              TextButton(
                onPressed: () => showToast(context, 'Code resent. Demo build: use $demoOtp.'),
                child: Text('Resend code', style: T.sans(15, color: AppColors.goldText)),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces for the dark auth screens (sign in / create account)
// ---------------------------------------------------------------------------

/// Dark radial backdrop with the whisky photo fading in at the bottom.
class AuthBackdrop extends StatelessWidget {
  final Widget child;
  const AuthBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.6),
                  radius: 1.2,
                  colors: [Color(0xFF2A1A10), AppColors.dark],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: w * 0.62,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, 0.35],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Image.asset('${img}signin_bottom.jpg', fit: BoxFit.cover),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(children: [
                  const SizedBox(height: 8),
                  child,
                  SizedBox(height: w * 0.5),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back arrow (only when there is somewhere to go back to) + optional action.
class AuthTopBar extends StatelessWidget {
  final Widget? trailing;
  const AuthTopBar({super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        if (Navigator.of(context).canPop())
          CircleIconButton(icon: Icons.arrow_back, color: Colors.white, onTap: () => Navigator.maybePop(context)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Gold-outlined dark text field with an inline error line underneath.
class AuthInput extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Widget? prefix;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  final String? error;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextCapitalization capitalization;

  /// Hint line under the field, replaced by [error] when there is one.
  final String? helper;

  const AuthInput({
    super.key,
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboard,
    this.obscure = false,
    this.onToggleObscure,
    this.prefix,
    this.maxLength,
    this.formatters,
    this.error,
    this.action,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.capitalization = TextCapitalization.none,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: error != null ? authErrorColor.withValues(alpha: 0.8) : AppColors.gold.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(width: prefix == null ? 18 : 12),
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 10),
            Container(width: 1, height: 30, color: Colors.white24),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              maxLength: maxLength,
              inputFormatters: formatters,
              textInputAction: action,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              autofillHints: autofillHints,
              textCapitalization: capitalization,
              style: T.sans(17, color: Colors.white),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                counterText: '',
                hintStyle: T.sans(16, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              tooltip: obscure ? 'Show password' : 'Hide password',
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70),
            ),
        ]),
      ),
      if (error != null || helper != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(error ?? helper!,
              style: T.sans(14, color: error != null ? authErrorColor : Colors.white60, height: 1.3)),
        ),
    ]);
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const _SocialBtn({required this.label, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(height: 36, child: Center(child: child)),
            const SizedBox(height: 4),
            Text(label, style: T.sans(15, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// Four-colour "G" drawn with text so no brand asset is required.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const SweepGradient(
        colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)],
        stops: [0.0, 0.3, 0.5, 0.75, 1],
      ).createShader(r),
      child: Text('G', style: T.sans(34, color: Colors.white, weight: FontWeight.w800)),
    );
  }
}
