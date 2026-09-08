import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _currCtrl.addListener(() => setState(() {}));
    _newCtrl.addListener(() => setState(() {}));
    _confCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  // Password requirement checks
  bool get _hasMinLength => _newCtrl.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newCtrl.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_newCtrl.text);
  bool get _hasSpecialChar => RegExp(r'[^A-Za-z0-9]').hasMatch(_newCtrl.text);
  bool get _isDifferentFromCurrent =>
      _currCtrl.text.isEmpty || _newCtrl.text != _currCtrl.text;
  bool get _passwordsMatch =>
      _newCtrl.text.isNotEmpty && _newCtrl.text == _confCtrl.text;

  int get _strengthScore {
    if (_newCtrl.text.isEmpty) return 0;
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase && _hasLowercase) score++;
    if (_hasSpecialChar) score++;
    if (_newCtrl.text.length >= 12 || (_hasSpecialChar && _hasMinLength && _hasUppercase && _hasLowercase)) score++;
    return score;
  }

  (String, Color) get _strengthDetails {
    switch (_strengthScore) {
      case 1:
        return ('Weak', const Color(0xFFE74C3C));
      case 2:
        return ('Fair', const Color(0xFFE67E22));
      case 3:
        return ('Good', const Color(0xFFF39C12));
      case 4:
        return ('Strong', AppColors.sage);
      default:
        return ('Too short', AppColors.muted);
    }
  }

  bool get _canSubmit =>
      _currCtrl.text.isNotEmpty &&
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasSpecialChar &&
      _isDifferentFromCurrent &&
      _passwordsMatch &&
      !_saving;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    final result = await ApiService.changePassword(
      currentPassword: _currCtrl.text,
      newPassword: _newCtrl.text,
      confirmPassword: _confCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      showToast(context, 'Password changed successfully!');
      Navigator.pop(context);
    } else {
      showToast(
        context,
        result.errorMessage ?? 'Failed to change password',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.charcoal),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Change Password',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildFormCard(),
                  const SizedBox(height: 18),
                  _buildSecurityTip(),
                  const SizedBox(height: 24),
                  RoseButton(
                    label: 'Update Password',
                    icon: Icons.check_circle_outline,
                    loading: _saving,
                    onPressed: _canSubmit ? _submit : null,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.deepRose.withValues(alpha: 0.12),
                AppColors.roseCta.withValues(alpha: 0.05),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
            boxShadow: AppShadows.petal,
          ),
          child: const Center(
            child: Icon(
              Icons.lock_reset_rounded,
              size: 32,
              color: AppColors.deepRose,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Protect Your Account',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a strong, unique password to ensure your orders, addresses, and account details remain secure.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current password
          _buildFieldLabel('CURRENT PASSWORD'),
          const SizedBox(height: 6),
          _buildPasswordField(
            controller: _currCtrl,
            hint: 'Enter your current password',
            obscureText: _obscureCurrent,
            onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
            prefixIcon: Icons.key_outlined,
          ),
          const SizedBox(height: 18),

          // Divider
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 18),

          // New password
          _buildFieldLabel('NEW PASSWORD'),
          const SizedBox(height: 6),
          _buildPasswordField(
            controller: _newCtrl,
            hint: 'Create a new password',
            obscureText: _obscureNew,
            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
            prefixIcon: Icons.lock_outline_rounded,
          ),

          if (_newCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStrengthMeter(),
            const SizedBox(height: 14),
            _buildChecklist(),
          ],

          const SizedBox(height: 18),

          // Confirm password
          _buildFieldLabel('CONFIRM NEW PASSWORD'),
          const SizedBox(height: 6),
          _buildPasswordField(
            controller: _confCtrl,
            hint: 'Re-enter your new password',
            obscureText: _obscureConfirm,
            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            prefixIcon: Icons.verified_user_outlined,
            suffixMatch: _confCtrl.text.isNotEmpty && _passwordsMatch,
          ),
          if (_confCtrl.text.isNotEmpty && !_passwordsMatch) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Passwords do not match',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.dustyRose,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required IconData prefixIcon,
    bool suffixMatch = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.dustyRose),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suffixMatch)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.sage),
                ),
              IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                onPressed: onToggleObscure,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthMeter() {
    final (label, color) = _strengthDetails;
    final score = _strengthScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            final active = index < score;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: active ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pageCream.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          _buildCheckItem('At least 8 characters', _hasMinLength),
          const SizedBox(height: 6),
          _buildCheckItem('At least one uppercase letter (A-Z)', _hasUppercase),
          const SizedBox(height: 6),
          _buildCheckItem('At least one lowercase letter (a-z)', _hasLowercase),
          const SizedBox(height: 6),
          _buildCheckItem('At least one special character (!@#\$...)', _hasSpecialChar),
          if (_currCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildCheckItem('Different from current password', _isDifferentFromCurrent),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: passed ? AppColors.sage : AppColors.muted.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: passed ? AppColors.charcoal : AppColors.muted,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: AppColors.dustyRose,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security Tip: Avoid using the same password across multiple services. E-FLORA staff will never ask for your password.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
