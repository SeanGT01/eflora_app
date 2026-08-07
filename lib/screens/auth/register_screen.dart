
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../utils/lowercase_email_formatter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_chrome.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'otp_verification_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onLoginTap;
  const RegisterScreen({super.key, this.onLoginTap});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must include lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must include uppercase letter';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Must include special character';
    return null;
  }

  void _goToLogin() {
    if (!mounted) return;

    if (widget.onLoginTap != null) {
      widget.onLoginTap!();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          initialEmail: _emailCtrl.text.trim().toLowerCase(),
        ),
      ),
    );
  }

  /// Sends the OTP to the user's email, then navigates to the OTP verification
  /// screen. Account creation happens there after the code is confirmed.
  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim().toLowerCase();

    final error = await auth.sendOtp(
      fullName: _nameCtrl.text.trim(),
      email: email,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (error != null) {
      if (isEmailServiceUnavailableError(error, errorCode: auth.lastErrorCode)) {
        await showEmailServiceUnavailableDialog(context);
      } else {
        showToast(context, error, isError: true);
      }
      return;
    }

    // OTP sent — push the verification screen.
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: email,
        ),
      ),
    );

    if (!mounted) return;
    if (verified == true) _goToLogin();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fieldStyle = GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal);

    return AuthScaffold(
      onLeadingTap: () => Navigator.pop(context),
      children: [
        const SizedBox(height: 4),
        const AuthBrandMark(),
        const SizedBox(height: 24),
        const AuthHeading(
          title: 'Create your account',
          subtitle: 'Join E-FLORA and start sending blooms',
        ),
        const SizedBox(height: 22),
        AuthGlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthFieldLabel('Full name'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: 'Juana Dela Cruz',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Email address'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [LowercaseEmailInputFormatter()],
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    return _validatePassword(v);
                  },
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Confirm password'),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtpAndContinue(),
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Continue',
                  onPressed: _sendOtpAndContinue,
                  loading: auth.loading,
                  icon: Icons.arrow_forward,
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'ll send a verification code to your email.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthDivider(label: 'already have an account?'),
                const SizedBox(height: 8),
                Center(
                  child: AuthTextLink(
                    label: 'Sign in instead',
                    onTap: _goToLogin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
