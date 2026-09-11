import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../config/phone_bind_flags.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../utils/person_name.dart';
import '../../widgets/birthday_picker.dart';
import '../../widgets/customer_default_avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _loginIdCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phoneOtpCtrl;
  DateTime? _birthday;
  DateTime? _initialBirthday;
  bool _saving = false;
  bool _phoneOtpSent = false;
  bool _savingPhone = false;
  File? _selectedImage;
  bool _uploadingAvatar = false;
  late String _initialFirstName;
  late String _initialLastName;
  late String _initialPhone;

  static const _fieldGap = 12.0;
  static const _sectionGap = 28.0;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final fullName = (user?.fullName ?? '').trim();
    final lastSpace = fullName.lastIndexOf(' ');
    _firstNameCtrl = TextEditingController(
        text: lastSpace > 0 ? fullName.substring(0, lastSpace) : fullName);
    _lastNameCtrl = TextEditingController(
        text: lastSpace > 0 ? fullName.substring(lastSpace + 1) : '');
    _loginIdCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _phoneOtpCtrl = TextEditingController();
    _birthday = _parseBirthday(user?.birthday);
    _initialBirthday = _birthday;
    _birthdayCtrl = TextEditingController(
      text: _birthday == null ? '' : formatBirthdayDisplay(_birthday!),
    );
    _initialFirstName = _firstNameCtrl.text.trim();
    _initialLastName = _lastNameCtrl.text.trim();
    _initialPhone = _phoneCtrl.text.trim();

    for (final ctrl in [_firstNameCtrl, _lastNameCtrl, _birthdayCtrl, _phoneCtrl, _phoneOtpCtrl]) {
      ctrl.addListener(_onFormChanged);
    }
    refreshPhoneBindFlags().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-()]'), '').trim();

  bool get _isProfileDirty =>
      _firstNameCtrl.text.trim() != _initialFirstName ||
      _lastNameCtrl.text.trim() != _initialLastName ||
      _formatBirthdayApi(_birthday) != _formatBirthdayApi(_initialBirthday) ||
      _selectedImage != null;

  bool get _isPhoneDirty =>
      _normalizePhone(_phoneCtrl.text) != _normalizePhone(_initialPhone);

  bool get _canSendPhoneCode =>
      _isPhoneDirty && _phoneCtrl.text.trim().isNotEmpty && !_savingPhone;

  bool get _canVerifyPhone =>
      _phoneOtpCtrl.text.trim().length == 6 && !_savingPhone;

  void _captureProfileBaseline() {
    _initialFirstName = _firstNameCtrl.text.trim();
    _initialLastName = _lastNameCtrl.text.trim();
    _initialBirthday = _birthday;
    setState(() => _selectedImage = null);
  }

  void _discardChanges() {
    setState(() {
      _firstNameCtrl.text = _initialFirstName;
      _lastNameCtrl.text = _initialLastName;
      _birthday = _initialBirthday;
      _birthdayCtrl.text =
          _birthday == null ? '' : formatBirthdayDisplay(_birthday!);
      _phoneCtrl.text = _initialPhone;
      _phoneOtpSent = false;
      _phoneOtpCtrl.clear();
      _selectedImage = null;
    });
    showToast(context, 'Changes discarded');
  }

  DateTime? _parseBirthday(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  String? _formatBirthdayApi(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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

  Future<void> _pickBirthday() async {
    final picked = await showBirthdayWheelPicker(
      context,
      selected: _birthday,
    );
    if (picked == null) return;
    setState(() {
      _birthday = DateTime(picked.year, picked.month, picked.day);
      _birthdayCtrl.text = formatBirthdayDisplay(_birthday!);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change photo',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 16),
              _PhotoSourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take a photo',
                subtitle: 'Use your camera',
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.camera),
                  );
                },
              ),
              const SizedBox(height: 8),
              _PhotoSourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from gallery',
                subtitle: 'Pick an existing picture',
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.gallery),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _uploadAvatarAndSave() async {
    if (_selectedImage != null) {
      setState(() => _uploadingAvatar = true);
      final result = await ApiService.uploadAvatar(_selectedImage!);
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      if (!result.isSuccess) {
        showToast(context, result.errorMessage ?? 'Failed to upload avatar',
            isError: true);
        return;
      }
      setState(() => _selectedImage = null);
      await context.read<AuthProvider>().refreshUser();
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      showToast(context, 'Enter a valid Philippine mobile number', isError: true);
      return;
    }
    setState(() => _savingPhone = true);
    final res = await ApiService.sendProfilePhoneOtp(phone: phone);
    if (!mounted) return;
    setState(() => _savingPhone = false);
    if (!res.isSuccess) {
      showToast(context, res.errorMessage ?? 'Could not send code', isError: true);
      return;
    }
    if (!kRequirePhoneBindOtp) {
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      setState(() {
        _phoneOtpSent = false;
        _phoneOtpCtrl.clear();
        final phoneSaved = res.data is Map ? res.data['phone'] : null;
        if (phoneSaved != null) {
          _phoneCtrl.text = phoneSaved.toString();
          _initialPhone = phoneSaved.toString().trim();
        }
      });
      showToast(context, (res.data is Map ? res.data['message'] : null)?.toString() ?? 'Phone number saved');
      return;
    }
    setState(() => _phoneOtpSent = true);
    showToast(context, (res.data is Map ? res.data['message'] : null)?.toString() ?? 'Code sent');
  }

  Future<void> _verifyPhoneOtp() async {
    final otp = _phoneOtpCtrl.text.trim();
    if (otp.length != 6) {
      showToast(context, 'Enter the 6-digit SMS code', isError: true);
      return;
    }
    setState(() => _savingPhone = true);
    final res = await ApiService.verifyProfilePhoneOtp(otpCode: otp);
    if (!mounted) return;
    setState(() => _savingPhone = false);
    if (!res.isSuccess) {
      showToast(context, res.errorMessage ?? 'Verification failed', isError: true);
      return;
    }
    await context.read<AuthProvider>().refreshUser();
    if (!mounted) return;
    setState(() {
      _phoneOtpSent = false;
      _phoneOtpCtrl.clear();
      final phone = res.data is Map ? res.data['phone'] : null;
      if (phone != null) {
        _phoneCtrl.text = phone.toString();
        _initialPhone = phone.toString().trim();
      }
    });
    showToast(context, 'Phone number saved');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthday != null) {
      final today = DateTime.now();
      final bday = DateTime(_birthday!.year, _birthday!.month, _birthday!.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      if (bday.isAfter(todayDate)) {
        showToast(context, 'Birthday cannot be in the future', isError: true);
        return;
      }
      final age = _ageYears(bday);
      if (age < 13) {
        showToast(context, 'You must be at least 13 years old', isError: true);
        return;
      }
      if (age > 120) {
        showToast(context, 'Please enter a valid birthday', isError: true);
        return;
      }
    }

    if (_selectedImage != null) {
      await _uploadAvatarAndSave();
      if (!mounted) return;
    }

    setState(() => _saving = true);
    final result = await ApiService.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      birthday: _formatBirthdayApi(_birthday),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      await context.read<AuthProvider>().refreshUser();
      if (mounted) {
        _captureProfileBaseline();
        showToast(context, 'Profile updated successfully!');
        Navigator.pop(context);
      }
    } else {
      showToast(context, result.errorMessage ?? 'Failed to update profile',
          isError: true);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [_firstNameCtrl, _lastNameCtrl, _loginIdCtrl, _birthdayCtrl, _phoneCtrl, _phoneOtpCtrl]) {
      ctrl.removeListener(_onFormChanged);
    }
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _loginIdCtrl.dispose();
    _birthdayCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneOtpCtrl.dispose();
    super.dispose();
  }

  Widget _sectionLabel(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.muted,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      counterText: counterText,
    );
  }

  Widget _profileOutlineButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    final enabled = onPressed != null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? AppColors.charcoal : const Color(0xFF808080),
        disabledForegroundColor: const Color(0xFF808080),
        backgroundColor: enabled ? Colors.white.withValues(alpha: 0.7) : const Color(0xFFECECEC),
        disabledBackgroundColor: const Color(0xFFECECEC),
        side: BorderSide(
          color: enabled
              ? AppColors.deepRose.withValues(alpha: 0.28)
              : const Color(0xFFD0D0D0),
        ),
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPhoneSection(bool isPhoneLogin) {
    if (isPhoneLogin) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionGap),
        _sectionLabel(
          'DELIVERY PHONE',
          subtitle: 'Riders and shops use this number for deliveries.',
        ),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            children: [
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration(
                  labelText: 'Mobile number',
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                ),
              ),
              if (kRequirePhoneBindOtp && _phoneOtpSent) ...[
                const SizedBox(height: _fieldGap),
                TextFormField(
                  controller: _phoneOtpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: _fieldDecoration(
                    labelText: '6-digit SMS code',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (!kRequirePhoneBindOtp)
                RoseButton(
                  label: 'Save number',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _canSendPhoneCode ? _sendPhoneOtp : null,
                  loading: _savingPhone,
                  width: double.infinity,
                )
              else if (!_phoneOtpSent)
                RoseButton(
                  label: 'Send code',
                  icon: Icons.send_rounded,
                  onPressed: _canSendPhoneCode ? _sendPhoneOtp : null,
                  loading: _savingPhone,
                  width: double.infinity,
                )
              else
                Row(
                  children: [
                    _profileOutlineButton(
                      label: 'Resend',
                      icon: Icons.refresh_rounded,
                      onPressed: _canSendPhoneCode ? _sendPhoneOtp : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RoseButton(
                        label: 'Verify',
                        icon: Icons.verified_rounded,
                        onPressed: _canVerifyPhone ? _verifyPhoneOtp : null,
                        loading: _savingPhone,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isPhoneLogin = user?.isPhoneLogin == true ||
        !(user?.email ?? '').contains('@');
    final displayName = [
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Edit Profile',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                              boxShadow: AppShadows.petal,
                            ),
                            child: _selectedImage != null
                                ? ClipOval(
                                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                                  )
                                : Consumer<AuthProvider>(
                                    builder: (_, auth, __) {
                                      final url = auth.user?.avatarUrl;
                                      if (url == null || url.isEmpty) {
                                        return const CustomerDefaultAvatar(
                                          size: 106,
                                          showRing: false,
                                        );
                                      }
                                      return ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const CustomerDefaultAvatar(
                                                size: 106,
                                                showRing: false,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: AppShadows.roseButton,
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName.isEmpty ? 'Your profile' : displayName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the photo to update it',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedImage = null),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: Text(
                          'Remove photo',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: _sectionGap),
              _sectionLabel('PERSONAL INFORMATION'),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameCtrl,
                      decoration: _fieldDecoration(
                        labelText: 'First name',
                        prefixIcon: const Icon(Icons.person_rounded, size: 20),
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: kFirstNameMax,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: const [
                        PersonNameInputFormatter(),
                      ],
                      validator: (v) =>
                          validatePersonName(v, field: 'First name'),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextFormField(
                      controller: _lastNameCtrl,
                      decoration: _fieldDecoration(
                        labelText: 'Last name',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: kLastNameMax,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: const [
                        PersonNameInputFormatter(maxLength: kLastNameMax),
                      ],
                      validator: (v) => validatePersonName(
                        v,
                        field: 'Last name',
                        maxLen: kLastNameMax,
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextFormField(
                      controller: _loginIdCtrl,
                      readOnly: true,
                      decoration: _fieldDecoration(
                        labelText: 'Email or mobile number',
                        helperText: 'Login identity — cannot be changed',
                        prefixIcon: Icon(
                          _loginIdCtrl.text.contains('@')
                              ? Icons.alternate_email_rounded
                              : Icons.phone_iphone_rounded,
                          size: 20,
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextFormField(
                      controller: _birthdayCtrl,
                      readOnly: true,
                      onTap: _pickBirthday,
                      decoration: _fieldDecoration(
                        labelText: 'Birthday',
                        prefixIcon: const Icon(
                          Icons.cake_rounded,
                          size: 20,
                          color: AppColors.dustyRose,
                        ),
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.deepRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildPhoneSection(isPhoneLogin),
            ],
          ),
        ),
        bottomNavigationBar: Material(
          color: AppColors.warmWhite.withValues(alpha: 0.92),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _profileOutlineButton(
                      label: 'Discard',
                      icon: Icons.undo_rounded,
                      onPressed:
                          _isProfileDirty && !_saving ? _discardChanges : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: RoseButton(
                      label: 'Save Changes',
                      icon: Icons.check_circle_rounded,
                      onPressed: _isProfileDirty && !_saving ? _save : null,
                      loading: _saving,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            color: AppColors.cream.withValues(alpha: 0.55),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.blushGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
