import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/customer_default_avatar.dart';
import '../../widgets/common.dart';

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
  bool _saving = false;
  bool _phoneOtpSent = false;
  bool _savingPhone = false;
  File? _selectedImage;
  bool _uploadingAvatar = false;
  late String _initialFirstName;
  late String _initialLastName;
  late String _initialBirthdayText;
  late String _initialPhone;

  static const _fieldGap = 12.0;
  static const _sectionGap = 28.0;
  static const _sectionTitleGap = 12.0;

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
    _birthdayCtrl = TextEditingController(
      text: _birthday == null ? '' : _formatBirthday(_birthday!),
    );
    _initialFirstName = _firstNameCtrl.text.trim();
    _initialLastName = _lastNameCtrl.text.trim();
    _initialBirthdayText = _birthdayCtrl.text.trim();
    _initialPhone = _phoneCtrl.text.trim();

    for (final ctrl in [_firstNameCtrl, _lastNameCtrl, _birthdayCtrl, _phoneCtrl, _phoneOtpCtrl]) {
      ctrl.addListener(_onFormChanged);
    }
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-()]'), '').trim();

  bool get _isProfileDirty =>
      _firstNameCtrl.text.trim() != _initialFirstName ||
      _lastNameCtrl.text.trim() != _initialLastName ||
      _birthdayCtrl.text.trim() != _initialBirthdayText ||
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
    _initialBirthdayText = _birthdayCtrl.text.trim();
    setState(() => _selectedImage = null);
  }

  void _discardChanges() {
    setState(() {
      _firstNameCtrl.text = _initialFirstName;
      _lastNameCtrl.text = _initialLastName;
      _birthdayCtrl.text = _initialBirthdayText;
      _birthday = _initialBirthdayText.isEmpty
          ? null
          : _parseBirthday(_initialBirthdayText);
      _phoneCtrl.text = _initialPhone;
      _phoneOtpSent = false;
      _phoneOtpCtrl.clear();
      _selectedImage = null;
    });
    showToast(context, 'Changes discarded');
  }

  static DateTime get _minBirthday {
    final now = DateTime.now();
    return DateTime(now.year - 120, now.month, now.day);
  }

  static DateTime get _maxBirthday {
    final now = DateTime.now();
    return DateTime(now.year - 13, now.month, now.day);
  }

  DateTime? _parseBirthday(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  String _formatBirthday(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
    final initial = _birthday ?? _maxBirthday;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(_maxBirthday)
          ? _maxBirthday
          : (initial.isBefore(_minBirthday) ? _minBirthday : initial),
      firstDate: _minBirthday,
      lastDate: _maxBirthday,
      helpText: 'Select birthday',
    );
    if (picked == null) return;
    setState(() {
      _birthday = picked;
      _birthdayCtrl.text = _formatBirthday(picked);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context,
                        await picker.pickImage(source: ImageSource.camera));
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: AppColors.deepRose.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.camera_alt,
                        color: AppColors.deepRose, size: 28),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Camera', style: TextStyle(fontSize: 12)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context,
                        await picker.pickImage(source: ImageSource.gallery));
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: AppColors.sage.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image,
                        color: AppColors.sage, size: 28),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Gallery', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
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
      birthday: _birthday == null ? null : _formatBirthday(_birthday!),
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  Widget _profileOutlineButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? AppColors.charcoal : const Color(0xFF808080),
        disabledForegroundColor: const Color(0xFF808080),
        backgroundColor: enabled ? null : const Color(0xFFECECEC),
        disabledBackgroundColor: const Color(0xFFECECEC),
        side: BorderSide(
          color: enabled
              ? AppColors.deepRose.withValues(alpha: 0.28)
              : const Color(0xFFD0D0D0),
        ),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }

  Widget _buildPhoneSection(bool isPhoneLogin) {
    if (isPhoneLogin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _sectionGap),
          _sectionTitle(context, 'Login mobile number'),
          const SizedBox(height: _sectionTitleGap),
          TextFormField(
            controller: _phoneCtrl,
            readOnly: true,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration(
              labelText: 'Mobile number',
              helperText: 'Cannot be changed.',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionGap),
        _sectionTitle(context, 'Delivery phone number'),
        const SizedBox(height: _sectionTitleGap),
        Text(
          'Riders and shops use this number for deliveries. Changing it requires a 6-digit SMS code.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
        ),
        const SizedBox(height: _fieldGap),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: _fieldDecoration(
            labelText: 'Mobile number',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        if (_phoneOtpSent) ...[
          const SizedBox(height: _fieldGap),
          TextFormField(
            controller: _phoneOtpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: _fieldDecoration(
              labelText: '6-digit SMS code',
              prefixIcon: const Icon(Icons.sms_outlined, size: 20),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (!_phoneOtpSent)
          RoseButton(
            label: 'Send code',
            icon: Icons.sms_outlined,
            onPressed: _canSendPhoneCode ? _sendPhoneOtp : null,
            loading: _savingPhone,
            width: double.infinity,
          )
        else
          Row(
            children: [
              _profileOutlineButton(
                label: 'Resend',
                onPressed: _canSendPhoneCode ? _sendPhoneOtp : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RoseButton(
                  label: 'Verify',
                  onPressed: _canVerifyPhone ? _verifyPhoneOtp : null,
                  loading: _savingPhone,
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isPhoneLogin = user?.isPhoneLogin ?? false;

    return Scaffold(
      backgroundColor: AppColors.pageCream,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.warmWhite,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.borderStrong, width: 2),
                            ),
                            child: _selectedImage != null
                                ? ClipOval(
                                    child: Image.file(_selectedImage!,
                                        fit: BoxFit.cover))
                                : Consumer<AuthProvider>(
                                    builder: (_, auth, __) {
                                      return auth.user?.avatarUrl != null
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    auth.user!.avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _defaultProfileAvatar(),
                                              ),
                                            )
                                          : _defaultProfileAvatar();
                                    },
                                  ),
                          ),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.deepRose, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8)
                                ],
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: AppColors.deepRose),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage != null)
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _selectedImage = null),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Remove Image'),
                        ),
                      if (_uploadingAvatar)
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: CircularProgressIndicator(
                                color: AppColors.deepRose)),
                    ],
                  ),
                ),
                const SizedBox(height: _sectionGap),
                _sectionTitle(context, 'Personal Information'),
                const SizedBox(height: _sectionTitleGap),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: _fieldDecoration(
                    labelText: 'First name',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'First name is required'
                      : null,
                ),
                const SizedBox(height: _fieldGap),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: _fieldDecoration(
                    labelText: 'Last name',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Last name is required'
                      : null,
                ),
                const SizedBox(height: _fieldGap),
                TextFormField(
                  controller: _loginIdCtrl,
                  readOnly: true,
                  decoration: _fieldDecoration(
                    labelText: 'Email or mobile number',
                    helperText: 'Login identity — cannot be changed',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: _fieldGap),
                TextFormField(
                  controller: _birthdayCtrl,
                  readOnly: true,
                  onTap: _pickBirthday,
                  decoration: _fieldDecoration(
                    labelText: 'Birthday',
                    prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                    suffixIcon:
                        const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
                _buildPhoneSection(isPhoneLogin),
                const SizedBox(height: _sectionGap),
                Row(
                  children: [
                    Expanded(
                      child: _profileOutlineButton(
                        label: 'Discard',
                        onPressed: _isProfileDirty && !_saving ? _discardChanges : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: RoseButton(
                        label: 'Save Changes',
                        onPressed: _isProfileDirty && !_saving ? _save : null,
                        loading: _saving,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultProfileAvatar() {
    return const CustomerDefaultAvatar(size: 100);
  }
}
