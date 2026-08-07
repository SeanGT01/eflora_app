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
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onRegisterTap;
  final String? initialEmail;
  const LoginScreen({super.key, this.onRegisterTap, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text =
        (widget.initialEmail ?? '').trim().toLowerCase();
  }

  void _goToRegister() {
    if (!mounted) return;

    if (widget.onRegisterTap != null) {
      widget.onRegisterTap!();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final error = await auth.login(
      _emailCtrl.text.trim().toLowerCase(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      showToast(context, error, isError: true);
    } else {
      // Route based on user role
      if (auth.user?.role == 'rider') {
        // Pop login screen - _buildHomeForRole watches AuthProvider
        // and will automatically switch to RiderShell
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Pop login screen FIRST, then load cart in background
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Load cart in background (non-blocking)
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
    return AuthScaffold(
      onLeadingTap: () => Navigator.pop(context),
      children: [
        const SizedBox(height: 8),
        const AuthBrandMark(),
        const SizedBox(height: 26),
        const AuthHeading(
          title: 'Welcome back',
          subtitle: 'Sign in to your E-FLORA account',
        ),
        const SizedBox(height: 22),
        AuthGlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthFieldLabel('Email address'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [LowercaseEmailInputFormatter()],
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
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
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Sign In',
                  onPressed: _login,
                  loading: auth.loading,
                ),
                const SizedBox(height: 20),
                const AuthDivider(label: 'or'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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