import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/address/add_edit_address_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

const _kPromptOnboardingKey = 'prompt_profile_onboarding';

/// Call after a successful OTP registration so the next customer login
/// prioritizes the required-profile flow.
Future<void> markProfileOnboardingRequired() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPromptOnboardingKey, true);
}

Future<bool> _consumeOnboardingFlag() async {
  final p = await SharedPreferences.getInstance();
  final needed = p.getBool(_kPromptOnboardingKey) ?? false;
  if (needed) await p.setBool(_kPromptOnboardingKey, false);
  return needed;
}

bool _onboardingInFlight = false;

/// Gender → birthday → add address (if none).
///
/// Runs for newly registered customers (flag) and for any logged-in customer
/// whose profile is still incomplete. This avoids a race where Home checked
/// the flag before registration finished marking it.
Future<void> maybeRunProfileOnboarding(BuildContext context) async {
  if (_onboardingInFlight) return;

  final auth = context.read<AuthProvider>();
  if (!auth.isLoggedIn) return;
  if (auth.user?.role != 'customer') return;

  _onboardingInFlight = true;
  try {
    // Registration sets this; incomplete profiles also continue below.
    await _consumeOnboardingFlag();
    if (!context.mounted) return;

    // Pull latest gender/birthday from the server before deciding.
    await auth.refreshUser();
    if (!context.mounted) return;

    var user = auth.user;
    final needsGender = (user?.gender ?? '').trim().isEmpty;
    final needsBirthday = (user?.birthday ?? '').trim().isEmpty;
    final needsPhone = user?.needsPhone == true ||
        ((user?.phone ?? '').trim().isEmpty && (user?.email ?? '').contains('@'));

    final addresses = context.read<AddressProvider>();
    if (addresses.addresses.isEmpty) {
      await addresses.loadAddresses();
    }
    if (!context.mounted) return;
    final needsAddress = addresses.addresses.isEmpty;

    if (!needsGender && !needsBirthday && !needsPhone && !needsAddress) return;

    if (needsGender) {
      final ok = await _showGenderStep(context);
      if (!ok || !context.mounted) return;
      await auth.refreshUser();
      user = auth.user;
    }

    final birthdayStillMissing = (auth.user?.birthday ?? '').trim().isEmpty;
    if (birthdayStillMissing) {
      if (!context.mounted) return;
      final ok = await _showBirthdayStep(context);
      if (!ok || !context.mounted) return;
      await auth.refreshUser();
    }

    final phoneStillMissing = auth.user?.needsPhone == true ||
        ((auth.user?.phone ?? '').trim().isEmpty &&
            (auth.user?.email ?? '').contains('@'));
    if (phoneStillMissing) {
      if (!context.mounted) return;
      final ok = await _showPhoneStep(context);
      if (!ok || !context.mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!context.mounted) return;
      await auth.refreshUser();
    }

    if (!context.mounted) return;
    if (addresses.addresses.isEmpty) {
      await addresses.loadAddresses();
    }
    if (!context.mounted) return;
    if (addresses.addresses.isEmpty) {
      showToast(context, 'Please add your delivery address to continue.');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => const AddEditAddressScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  } finally {
    _onboardingInFlight = false;
  }
}

Future<bool> _showGenderStep(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const _GenderOnboardingDialog(),
  );
  return result == true;
}

Future<bool> _showBirthdayStep(BuildContext context) async {
  DateTime? picked;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final label = picked == null
              ? 'Tap to choose date'
              : '${picked!.year.toString().padLeft(4, '0')}-'
                  '${picked!.month.toString().padLeft(2, '0')}-'
                  '${picked!.day.toString().padLeft(2, '0')}';
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(
                'When’s your birthday?',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Step 2 of 4 — required to continue.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(now.year - 18, now.month, now.day),
                        firstDate: DateTime(now.year - 120),
                        lastDate: DateTime(now.year - 13, now.month, now.day),
                      );
                      if (date != null) setLocal(() => picked = date);
                    },
                    icon: const Icon(Icons.cake_outlined, size: 18),
                    label: Text(label),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (picked == null) {
                      showToast(ctx, 'Please enter your birthday', isError: true);
                      return;
                    }
                    final age = _ageYears(picked!);
                    if (age < 13) {
                      showToast(
                        ctx,
                        'You must be at least 13 years old',
                        isError: true,
                      );
                      return;
                    }
                    final bday =
                        '${picked!.year.toString().padLeft(4, '0')}-'
                        '${picked!.month.toString().padLeft(2, '0')}-'
                        '${picked!.day.toString().padLeft(2, '0')}';
                    final res = await ApiService.updateProfile(
                      firstName: _splitName(ctx).$1,
                      lastName: _splitName(ctx).$2,
                      birthday: bday,
                    );
                    if (!ctx.mounted) return;
                    if (!res.isSuccess) {
                      showToast(
                        ctx,
                        res.errorMessage ?? 'Failed to save',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.of(ctx, rootNavigator: true).pop(true);
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  return result == true;
}

Future<bool> _showPhoneStep(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const _PhoneOnboardingDialog(),
  );
  return result == true;
}

(String, String) _splitName(BuildContext context) {
  final full = (context.read<AuthProvider>().user?.fullName ?? '').trim();
  final i = full.lastIndexOf(' ');
  if (i <= 0) return (full, '');
  return (full.substring(0, i), full.substring(i + 1));
}

int _ageYears(DateTime birthday) {
  final now = DateTime.now();
  var age = now.year - birthday.year;
  if (now.month < birthday.month ||
      (now.month == birthday.month && now.day < birthday.day)) {
    age--;
  }
  return age;
}

class _GenderOnboardingDialog extends StatefulWidget {
  const _GenderOnboardingDialog();

  @override
  State<_GenderOnboardingDialog> createState() => _GenderOnboardingDialogState();
}

class _GenderOnboardingDialogState extends State<_GenderOnboardingDialog> {
  final _otherCtrl = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_selected == null) {
      showToast(context, 'Please select your gender', isError: true);
      return;
    }
    var gender = _selected!;
    if (gender == 'other') {
      final other = _otherCtrl.text.trim();
      if (other.isEmpty) {
        showToast(context, 'Please specify your gender', isError: true);
        return;
      }
      gender = other;
    }
    final res = await ApiService.updateProfile(
      firstName: _splitName(context).$1,
      lastName: _splitName(context).$2,
      gender: gender,
    );
    if (!mounted) return;
    if (!res.isSuccess) {
      showToast(context, res.errorMessage ?? 'Failed to save', isError: true);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          'What’s your gender?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 1 of 4 — required to continue.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            for (final opt in const [
              ('male', 'Male'),
              ('female', 'Female'),
              ('other', 'Other'),
            ])
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(opt.$2, style: GoogleFonts.dmSans(fontSize: 14)),
                value: opt.$1,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
              ),
            if (_selected == 'other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Please specify',
                  hintText: 'e.g., Non-binary',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _PhoneOnboardingDialog extends StatefulWidget {
  const _PhoneOnboardingDialog();

  @override
  State<_PhoneOnboardingDialog> createState() => _PhoneOnboardingDialogState();
}

class _PhoneOnboardingDialogState extends State<_PhoneOnboardingDialog> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  var _otpSent = false;
  var _hint = '';
  var _busy = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      showToast(context, 'Enter a valid mobile number', isError: true);
      return;
    }
    setState(() => _busy = true);
    final res = await ApiService.sendProfilePhoneOtp(phone: phone);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.isSuccess) {
      showToast(context, res.errorMessage ?? 'Could not send code', isError: true);
      return;
    }
    final msg = (res.data is Map ? res.data['message'] : null)?.toString();
    setState(() {
      _otpSent = true;
      _hint = msg ?? 'Enter the 6-digit SMS code.';
    });
    showToast(context, msg ?? 'Code sent');
  }

  Future<void> _verify() async {
    if (_busy) return;
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      showToast(context, 'Enter the 6-digit code', isError: true);
      return;
    }
    setState(() => _busy = true);
    final res = await ApiService.verifyProfilePhoneOtp(otpCode: otp);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.isSuccess) {
      showToast(context, res.errorMessage ?? 'Verification failed', isError: true);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          'Add your mobile number',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 3 of 4 — riders use this number for delivery. Enter the 6-digit SMS code here (not a separate screen).',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Philippine mobile number',
                  hintText: '09171234567',
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: '6-digit code',
                    helperText: _hint.isEmpty ? null : _hint,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _sendCode,
            child: Text(_otpSent ? 'Resend' : 'Send code'),
          ),
          if (_otpSent)
            TextButton(
              onPressed: _busy ? null : _verify,
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }
}
