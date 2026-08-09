
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
  final _nameCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must include lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must include uppercase letter';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Must include special character';
    }
    return null;
  }

  String? _normalizePhMobile(String? raw) {
    var compact = (raw ?? '').trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (compact.isEmpty) return null;
    if (compact.startsWith('+63')) {
      compact = '0${compact.substring(3)}';
    } else if (compact.startsWith('63') && compact.length == 12) {
      compact = '0${compact.substring(2)}';
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(compact)) return null;
    return compact;
  }

  String? _validateIdentifier(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Email or phone is required';
    if (raw.contains('@')) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(raw.toLowerCase())) {
        return 'Enter a valid email';
      }
      return null;
    }
    if (_normalizePhMobile(raw) == null) {
      return 'Enter a valid email or PH mobile (09XXXXXXXXX)';
    }
    return null;
  }

  void _goToLogin({String? loginId}) {
    if (!mounted) return;

    if (widget.onLoginTap != null) {
      widget.onLoginTap!();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          initialEmail: loginId ?? _identifierCtrl.text.trim(),
        ),
      ),
    );
  }

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    var identifier = _identifierCtrl.text.trim();
    if (identifier.contains('@')) {
      identifier = identifier.toLowerCase();
    }

    final error = await auth.sendOtp(
      fullName: _nameCtrl.text.trim(),
      identifier: identifier,
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

    final meta = auth.lastSendOtpMeta;
    final accountEmail = (meta?['email'] as String?)?.trim().toLowerCase() ?? '';
    final channel = (meta?['otp_channel'] as String?) ??
        (identifier.contains('@') ? 'email' : 'sms');
    final dest = (meta?['destination_masked'] as String?) ?? identifier;
    final loginId =
        (meta?['login_id'] as String?)?.trim() ?? identifier;

    if (accountEmail.isEmpty) {
      showToast(context, 'Could not start verification. Try again.', isError: true);
      return;
    }

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: accountEmail,
          otpChannel: channel,
          destinationMasked: dest,
        ),
      ),
    );

    if (!mounted) return;
    if (verified == true) _goToLogin(loginId: loginId);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                ),
                const SizedBox(height: 18),
                const AuthFieldLabel('Email or mobile number'),
                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [LowercaseEmailInputFormatter()],
                  style: fieldStyle,
                  decoration: authInputDecoration(
                    hint: 'you@example.com or 09171234567',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: _validateIdentifier,
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
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePassword,
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
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
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
                  'Use one contact — email gets a Gmail code, mobile gets an SMS code. That same value is your login.',
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
                    onTap: () => _goToLogin(),
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
