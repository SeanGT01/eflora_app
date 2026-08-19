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

    final addresses = context.read<AddressProvider>();
    if (addresses.addresses.isEmpty) {
      await addresses.loadAddresses();
    }
    if (!context.mounted) return;
    final needsAddress = addresses.addresses.isEmpty;

    if (!needsGender && !needsBirthday && !needsAddress) return;

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

    if (!context.mounted) return;
    if (addresses.addresses.isEmpty) {
      await addresses.loadAddresses();
    }
    if (!context.mounted) return;
    if (addresses.addresses.isEmpty) {
      showToast(context, 'Please add your delivery address to continue.');
      await Navigator.of(context).push(
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
  String? selected;
  final otherCtrl = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
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
                    'Step 1 of 2 — required to continue.',
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
                      groupValue: selected,
                      onChanged: (v) => setLocal(() => selected = v),
                    ),
                  if (selected == 'other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherCtrl,
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
                  onPressed: () async {
                    if (selected == null) {
                      showToast(ctx, 'Please select your gender', isError: true);
                      return;
                    }
                    var gender = selected!;
                    if (gender == 'other') {
                      final other = otherCtrl.text.trim();
                      if (other.isEmpty) {
                        showToast(ctx, 'Please specify your gender', isError: true);
                        return;
                      }
                      gender = other;
                    }
                    final res = await ApiService.updateProfile(
                      firstName: _splitName(ctx).$1,
                      lastName: _splitName(ctx).$2,
                      gender: gender,
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
  otherCtrl.dispose();
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
                    'Step 2 of 2 — required to continue.',
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
                        firstDate: DateTime(now.year - 100),
                        lastDate: now,
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
