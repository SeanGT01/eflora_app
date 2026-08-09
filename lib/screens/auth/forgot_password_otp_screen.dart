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
import 'forgot_password_reset_screen.dart';

/// OTP verification for forgot-password (email or SMS code → set new password).
class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  /// What the user signs in with (phone for SMS accounts — never the internal email).
  final String? loginId;
  final String otpChannel;
  final String? destinationMasked;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    this.loginId,
    this.otpChannel = 'email',
    this.destinationMasked,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  static const int _otpLength = 6;
  static const int _resendCooldown = 60; // seconds — mirrors backend default

  String get _emailNormalized => widget.email.trim().toLowerCase();

  // One controller + focusNode per digit cell.
  final List<TextEditingController> _ctrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _verifying = false;
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
    final errorData = await auth.verifyForgotPasswordOtp(
      email: _emailNormalized,
      otpCode: code,
    );

    if (!mounted) return;
    setState(() => _verifying = false);

    if (errorData == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ForgotPasswordResetScreen(
            email: _emailNormalized,
            loginId: widget.loginId,
          ),
        ),
      );
    } else {
      final expired = errorData['expired'] == true;
      final locked  = errorData['locked']  == true;
      final remaining = errorData['attempts_remaining'] as int?;

      String msg = errorData['error'] as String? ?? 'Invalid code. Please try again.';
      if (remaining != null && !expired && !locked) {
        msg = '$msg ($remaining attempt${remaining == 1 ? '' : 's'} left)';
      }
      setState(() => _errorMsg = msg);

      if (!expired && !locked) {
        for (final c in _ctrls) c.clear();
        _focusNodes[0].requestFocus();
      }
    }
  }

  // ── Resend ────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_resendSecondsLeft > 0 || _resending) return;

    setState(() { _resending = true; _errorMsg = null; });

    final auth = context.read<AuthProvider>();
    final errorData = await auth.resendForgotPasswordOtp(email: _emailNormalized);

    if (!mounted) return;
    setState(() => _resending = false);

    if (errorData == null) {
      for (final c in _ctrls) c.clear();
      _focusNodes[0].requestFocus();
      _startResendCountdown();
      showToast(
        context,
        'A new code has been sent to ${widget.destinationMasked?.trim().isNotEmpty == true ? widget.destinationMasked!.trim() : _emailNormalized}',
      );
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
    final busy = _verifying || auth.loading;

    return AuthScaffold(
      leadingIcon: Icons.arrow_back_rounded,
      onLeadingTap: busy ? null : () => Navigator.of(context).pop(),
      children: [
        const SizedBox(height: 8),
        AuthBrandMark(
          icon: widget.otpChannel == 'sms'
              ? Icons.sms_outlined
              : Icons.lock_reset_rounded,
        ),
        const SizedBox(height: 26),
        AuthHeading(
          title: widget.otpChannel == 'sms'
              ? 'Check your messages'
              : 'Check your inbox',
          subtitle: 'We sent a 6-digit reset code to',
        ),
        const SizedBox(height: 6),
        Text(
          widget.destinationMasked?.trim().isNotEmpty == true
              ? widget.destinationMasked!.trim()
              : _emailNormalized,
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
              _OtpInputRow(
                controllers: _ctrls,
                focusNodes: _focusNodes,
                onChanged: _onDigitChanged,
                onKeyEvent: _onKeyEvent,
                hasError: _errorMsg != null,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
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
              GradientButton(
                label: 'Verify code',
                onPressed: busy ? null : _verify,
                loading: busy,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 20),
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
