import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_chrome.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

/// OTP verification screen shown after the user submits the registration form.
///
/// Receives the [email] that the OTP was sent to.
class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;
  static const int _resendCooldown = 60; // seconds — mirrors backend default

  String get _emailNormalized => widget.email.trim().toLowerCase();

  // One controller + focusNode per digit cell.
  final List<TextEditingController> _ctrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _verifying = false;
  bool _finalising = false;
  String? _errorMsg;

  // Resend countdown
  int _resendSecondsLeft = _resendCooldown;
  Timer? _resendTimer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Countdown helpers ─────────────────────────────────────────────────────

  void _startResendCountdown([int seconds = _resendCooldown]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSecondsLeft > 0) {
          _resendSecondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP digit input handling ───────────────────────────────────────────────

  String get _currentCode =>
      _ctrls.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _errorMsg = null);

    if (value.length > 1) {
      // Handle paste: distribute digits across cells.
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _ctrls[index + i <= _otpLength - 1 ? index + i : _otpLength - 1].text =
            digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, _otpLength - 1);
      _focusNodes[nextIndex].requestFocus();
      if (_currentCode.length == _otpLength) _verify();
      return;
    }

    if (value.isNotEmpty) {
      // Move focus forward.
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verify();
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _ctrls[index - 1].clear();
    }
  }

  // ── Verify ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    final code = _currentCode;
    if (code.length < _otpLength) {
      setState(() => _errorMsg = 'Please enter all 6 digits.');
      return;
    }
    setState(() { _verifying = true; _errorMsg = null; });

    final auth = context.read<AuthProvider>();
    final errorData = await auth.verifyOtp(
      email: _emailNormalized,
      otpCode: code,
    );

    if (!mounted) return;
    setState(() => _verifying = false);

    if (errorData == null) {
      // OTP correct → finalise registration
      await _finaliseRegistration();
    } else {
      final expired = errorData['expired'] == true;
      final locked  = errorData['locked']  == true;
      final remaining = errorData['attempts_remaining'] as int?;

      String msg = errorData['error'] as String? ?? 'Invalid code. Please try again.';
      if (remaining != null && !expired && !locked) {
        msg = '$msg ($remaining attempt${remaining == 1 ? '' : 's'} left)';
      }
      setState(() => _errorMsg = msg);

      // Clear cells on bad code so user can retype.
      if (!expired && !locked) {
        for (final c in _ctrls) c.clear();
        _focusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _finaliseRegistration() async {
    setState(() { _finalising = true; _errorMsg = null; });

    final auth = context.read<AuthProvider>();
    final error = await auth.registerAfterOtp(email: _emailNormalized);

    if (!mounted) return;
    setState(() => _finalising = false);

    if (error == null) {
      if (!mounted) return;
      final dialogFuture = _showSuccessDialog();
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialogFuture;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMsg = error);
    }
  }

  Future<void> _showSuccessDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.94),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.roseButton,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verification successful!',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your account is ready. Please sign in with your email and password.',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Resend ────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_resendSecondsLeft > 0 || _resending) return;

    setState(() { _resending = true; _errorMsg = null; });

    final auth = context.read<AuthProvider>();
    final errorData = await auth.resendOtp(email: _emailNormalized);

    if (!mounted) return;
    setState(() => _resending = false);

    if (errorData == null) {
      // Fresh OTP sent — reset cells and restart countdown.
      for (final c in _ctrls) c.clear();
      _focusNodes[0].requestFocus();
      _startResendCountdown();
      showToast(context, 'A new code has been sent to $_emailNormalized');
    } else {
      final retryAfter = errorData['retry_after_seconds'] as int?;
      final msg = errorData['error'] as String? ?? 'Failed to resend. Try again.';
      final code = errorData['error_code'] as String? ?? auth.lastErrorCode;
      if (isEmailServiceUnavailableError(msg, errorCode: code)) {
        await showEmailServiceUnavailableDialog(context);
      } else {
        setState(() => _errorMsg = msg);
      }
      if (retryAfter != null && retryAfter > 0) {
        _startResendCountdown(retryAfter);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _verifying || _finalising || auth.loading;

    return AuthScaffold(
      leadingIcon: Icons.arrow_back_rounded,
      onLeadingTap: busy ? null : () => Navigator.of(context).pop(),
      children: [
        const SizedBox(height: 8),
        const AuthBrandMark(icon: Icons.mark_email_unread_outlined),
        const SizedBox(height: 26),
        const AuthHeading(
          title: 'Check your inbox',
          subtitle: 'We sent a 6-digit code to',
        ),
        const SizedBox(height: 6),
        Text(
          _emailNormalized,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.roseCta,
          ),
        ),
        const SizedBox(height: 22),
        AuthGlassCard(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 6-cell OTP input ───────────────────────────────────────
              _OtpInputRow(
                controllers: _ctrls,
                focusNodes: _focusNodes,
                onChanged: _onDigitChanged,
                onKeyEvent: _onKeyEvent,
                hasError: _errorMsg != null,
                enabled: !busy,
              ),
              const SizedBox(height: 16),

              // ── Error message ─────────────────────────────────────────
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _errorMsg != null
                    ? Container(
                        key: const ValueKey('error'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.08),
                          border: Border.all(
                            color: const Color(0xFFE74C3C).withValues(alpha: 0.28),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-error')),
              ),
              const SizedBox(height: 22),

              // ── Verify button ─────────────────────────────────────────
              GradientButton(
                label: _finalising ? 'Creating account…' : 'Verify & Create Account',
                onPressed: busy ? null : _verify,
                loading: busy,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 20),

              // ── Resend ────────────────────────────────────────────────
              if (_resending)
                const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.roseCta,
                    ),
                  ),
                )
              else if (_resendSecondsLeft > 0)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                        fontSize: 12.5, color: AppColors.muted),
                    children: [
                      const TextSpan(text: "Didn't receive it? Resend in "),
                      TextSpan(
                        text: '${_resendSecondsLeft}s',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.roseCta),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: AuthTextLink(
                    label: 'Resend code',
                    icon: Icons.refresh,
                    onTap: _resend,
                  ),
                ),

              const SizedBox(height: 14),
              Text(
                'The code expires in 5 minutes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  color: AppColors.muted.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 6-cell OTP input row ────────────────────────────────────────────────────

class _OtpInputRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int index, String value) onChanged;
  final void Function(int index, KeyEvent event) onKeyEvent;
  final bool hasError;
  final bool enabled;

  const _OtpInputRow({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
    required this.onKeyEvent,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - gap * (controllers.length - 1);
        final cellWidth = (available / controllers.length).clamp(36.0, 50.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(controllers.length, (i) {
            final isLast = i == controllers.length - 1;
            return Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : gap),
              child: _OtpCell(
                width: cellWidth,
                controller: controllers[i],
                focusNode: focusNodes[i],
                hasError: hasError,
                enabled: enabled,
                onChanged: (v) => onChanged(i, v),
                onKeyEvent: (e) => onKeyEvent(i, e),
              ),
            );
          }),
        );
      },
    );
  }
}

class _OtpCell extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;
  final double width;
  final ValueChanged<String> onChanged;
  final void Function(KeyEvent) onKeyEvent;

  const _OtpCell({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
    this.hasError = false,
    this.enabled = true,
    this.width = 46,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.error.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.85);
    final focusColor = hasError
        ? AppColors.error
        : AppColors.pinkMid.withValues(alpha: 0.9);

    OutlineInputBorder cellBorder(Color color, double strokeWidth) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: strokeWidth),
        );

    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: width,
        height: 58,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2, // >1 to catch paste; handler clips to 1
          onChanged: onChanged,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: AppColors.roseCta,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: enabled ? 0.62 : 0.35),
            contentPadding: EdgeInsets.zero,
            enabledBorder: cellBorder(borderColor, 1.2),
            focusedBorder: cellBorder(focusColor, 1.8),
            disabledBorder:
                cellBorder(Colors.white.withValues(alpha: 0.5), 1.2),
            errorBorder: cellBorder(AppColors.error.withValues(alpha: 0.55), 1.2),
          ),
        ),
      ),
    );
  }
}
