import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_chrome.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import 'login_screen.dart';

class ForgotPasswordResetScreen extends StatefulWidget {
  final String email;
  /// Phone or real email shown in UI / login prefill (not synthetic internal email).
  final String? loginId;

  const ForgotPasswordResetScreen({
    super.key,
    required this.email,
    this.loginId,
  });

  @override
  State<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends State<ForgotPasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _saving = false;

  String get _email => widget.email.trim().toLowerCase();

  String get _displayId {
    final id = (widget.loginId ?? '').trim();
    if (id.isNotEmpty && !id.endsWith('@sms.eflora.internal')) return id;
    if (_email.endsWith('@sms.eflora.internal')) {
      return _email.split('@').first;
    }
    return _email;
  }

  String? _validateNewPassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must include lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must include uppercase letter';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Must include special character';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.resetPasswordAfterOtp(
      email: _email,
      newPassword: _newCtrl.text,
      confirmPassword: _confCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      showToast(context, 'Password updated! Sign in with your new password.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(initialEmail: _displayId),
        ),
        (route) => route.isFirst,
      );
    } else {
      showToast(context, error, isError: true);
    }
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onLeadingTap: _saving ? null : () => Navigator.pop(context),
      children: [
        const SizedBox(height: 8),
        const AuthBrandMark(icon: Icons.password_rounded),
        const SizedBox(height: 26),
        const AuthHeading(
          title: 'Create a new password',
          subtitle: 'Choose a strong password for',
        ),
        const SizedBox(height: 6),
        Text(
          _displayId,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.roseCta,
          ),
        ),
        const SizedBox(height: 22),
        AuthGlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthFieldLabel('New password'),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _obscure1,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure1
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: _validateNewPassword,
                ),
                const SizedBox(height: 8),
                Text(
                  'At least 8 characters with uppercase, lowercase, and a special character.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                const AuthFieldLabel('Confirm password'),
                TextFormField(
                  controller: _confCtrl,
                  obscureText: _obscure2,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                  decoration: authInputDecoration(
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure2
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) =>
                      v != _newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Update password',
                  onPressed: _submit,
                  loading: _saving,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
