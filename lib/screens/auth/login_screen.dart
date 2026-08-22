import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/lowercase_email_formatter.dart';
import '../../widgets/auth_chrome.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/auth_required_sheet.dart';
import '../main_shell.dart';
import 'forgot_password_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onRegisterTap;
  final String? initialEmail;
  const LoginScreen({super.key, this.onRegisterTap, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = (widget.initialEmail ?? '').trim().toLowerCase();
  }

  void _goToRegister() {
    if (!mounted) return;
    pushRegisterScreen(context, replace: true);
  }

  Future<void> _forgotPassword() async {
    var raw = _emailCtrl.text.trim();
    if (raw.isEmpty) {
      showToast(context, 'Enter your email or phone number first', isError: true);
      return;
    }

    final isEmail = raw.contains('@');
    if (isEmail) {
      raw = raw.toLowerCase();
    } else {
      var compact = raw.replaceAll(RegExp(r'[\s\-()]'), '');
      if (compact.startsWith('+63')) {
        compact = '0${compact.substring(3)}';
      } else if (compact.startsWith('63') && compact.length == 12) {
        compact = '0${compact.substring(2)}';
      }
      raw = compact;
    }

    final isPhone = RegExp(r'^09\d{9}$').hasMatch(raw);
    if (!isEmail && !isPhone) {
      showToast(
        context,
        'Enter a valid email or PH mobile number',
        isError: true,
      );
      return;
    }

    setState(() => _sendingReset = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.sendForgotPasswordOtp(identifier: raw);
    if (!mounted) return;
    setState(() => _sendingReset = false);

    if (error != null) {
      final code = auth.lastErrorCode;
      if (isEmailServiceUnavailableError(error, errorCode: code)) {
        await showEmailServiceUnavailableDialog(context);
      } else {
        showToast(context, error, isError: true);
      }
      return;
    }

    final meta = auth.lastForgotPasswordMeta;
    final accountEmail =
        (meta?['email'] as String?)?.trim().toLowerCase() ??
            (isEmail ? raw.toLowerCase() : '');
    final channel = (meta?['otp_channel'] as String?) ?? (isEmail ? 'email' : 'sms');
    final dest = (meta?['destination_masked'] as String?) ?? raw;
    final loginId = (meta?['login_id'] as String?)?.trim().isNotEmpty == true
        ? (meta!['login_id'] as String).trim()
        : raw;

    if (accountEmail.isEmpty) {
      showToast(context, 'Could not start password reset. Try again.', isError: true);
      return;
    }

    showToast(context, 'Verification code sent to $dest');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordOtpScreen(
          email: accountEmail,
          loginId: loginId,
          otpChannel: channel,
          destinationMasked: dest,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    var id = _emailCtrl.text.trim();
    if (id.contains('@')) {
      id = id.toLowerCase();
    } else {
      // Normalize PH mobile to 09XXXXXXXXX for SMS rider/customer accounts.
      var compact = id.replaceAll(RegExp(r'[\s\-()]'), '');
      if (compact.startsWith('+63')) {
        compact = '0${compact.substring(3)}';
      } else if (compact.startsWith('63') && compact.length == 12) {
        compact = '0${compact.substring(2)}';
      }
      id = compact;
    }
    final error = await auth.login(id, _passwordCtrl.text.trim());
    if (!mounted) return;
    if (error != null) {
      showToast(context, error, isError: true);
    } else {
      if (auth.user?.role == 'rider') {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Prefer Home so the required-info dialogs are visible after login.
        MainShell.switchTab(context, 0);
        if (mounted) {
          Navigator.of(context).pop();
        }

        try {
          await context.read<CartProvider>().load();
        } catch (e) {
          debugPrint('❌ Error loading cart: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = auth.loading || _sendingReset;
    final sheet = MediaQuery.sizeOf(context).width < 960;
    return AuthScaffold(
      onLeadingTap: () => Navigator.pop(context),
      hero: AuthHeroBanner(
        eyebrow: 'Welcome back',
        headline: TextSpan(
          children: [
            const TextSpan(text: 'Where every\nbloom '),
            TextSpan(
              text: 'finds\nits home',
              style: GoogleFonts.cormorantGaramond(
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
        description:
            'Sign in to browse handpicked flowers, track your orders, and support local florists near you.',
      ),
      children: [
        if (!sheet) ...[
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 0 : 8),
          const AuthBrandMark(),
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 12 : 26),
          const AuthHeading(
            title: 'Welcome back',
            subtitle: 'Sign in to your E-FLORA account',
          ),
          SizedBox(height: MediaQuery.sizeOf(context).height < 720 ? 12 : 22),
        ] else ...[
          const AuthHeading(
            title: 'Welcome back',
            subtitle: 'Enter your credentials to access your account.',
          ),
          const SizedBox(height: 16),
        ],
        AuthGlassCard(
          flat: sheet,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthFieldLabel('Email or mobile number'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [LowercaseEmailInputFormatter()],
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                  decoration: authInputDecoration(
                    hint: 'you@example.com or 09171234567',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return 'Email or phone is required';
                    if (raw.contains('@')) {
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(raw.toLowerCase())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    }
                    final compact = raw.replaceAll(RegExp(r'[\s\-()]'), '');
                    var n = compact;
                    if (n.startsWith('+63')) {
                      n = '0${n.substring(3)}';
                    } else if (n.startsWith('63') && n.length == 12) {
                      n = '0${n.substring(2)}';
                    }
                    if (!RegExp(r'^09\d{9}$').hasMatch(n)) {
                      return 'Enter a valid email or PH mobile';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : _forgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.roseCta,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _sendingReset ? 'Sending code…' : 'Forgot password?',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Text(
                  'Sign in with the same email or mobile you used to register.',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.muted.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Sign In',
                  onPressed: _login,
                  loading: auth.loading,
                ),
                const SizedBox(height: 20),
                const AuthDivider(label: 'or'),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    AuthTextLink(
                      label: 'Create account',
                      onTap: _goToRegister,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
