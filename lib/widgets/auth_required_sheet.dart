import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../theme/app_theme.dart';
import 'adaptive_blur.dart';
import 'glass.dart';

/// Shows the shared Sign In / Create Account bottom sheet used when a guest
/// tries an action that requires an account (add to cart, buy now, etc.).
Future<void> showAuthRequiredSheet(
  BuildContext context, {
  String message =
      'Create an account or sign in to add items to your cart',
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _AuthRequiredSheet(
      message: message,
      onLogin: () {
        Navigator.pop(sheetContext);
        _pushLogin(context);
      },
      onRegister: () {
        Navigator.pop(sheetContext);
        pushRegisterScreen(context);
      },
    ),
  );
}

void pushLoginScreen(
  BuildContext context, {
  bool replace = false,
  String? initialEmail,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => LoginScreen(
      initialEmail: initialEmail,
      onRegisterTap: () => pushRegisterScreen(context, replace: true),
    ),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

void pushRegisterScreen(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => RegisterScreen(
      onLoginTap: () => pushLoginScreen(context, replace: true),
    ),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

void _pushLogin(BuildContext context) => pushLoginScreen(context);

class _AuthRequiredSheet extends StatelessWidget {
  const _AuthRequiredSheet({
    required this.message,
    required this.onLogin,
    required this.onRegister,
  });

  final String message;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: AdaptiveBlur(
        sigma: 18,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.pageCream.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              14,
              24,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradientH,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: AppColors.imageWash,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_florist,
                    size: 30,
                    color: AppColors.deepRose,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sign in to continue',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(label: 'Sign In', onPressed: onLogin),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onRegister,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
