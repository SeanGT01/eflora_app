
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
  bool _saving = false;
  File? _selectedImage;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final fullName = (user?.fullName ?? '').trim();
    final lastSpace = fullName.lastIndexOf(' ');
    _firstNameCtrl = TextEditingController(text: lastSpace > 0 ? fullName.substring(0, lastSpace) : fullName);
    _lastNameCtrl  = TextEditingController(text: lastSpace > 0 ? fullName.substring(lastSpace + 1) : '');
    _loginIdCtrl   = TextEditingController(text: user?.email ?? '');
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
                    Navigator.pop(context, await picker.pickImage(source: ImageSource.camera));
                  },
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: AppColors.deepRose.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.camera_alt, color: AppColors.deepRose, size: 28),
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
                    Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery));
                  },
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: AppColors.sage.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image, color: AppColors.sage, size: 28),
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
        showToast(context, result.errorMessage ?? 'Failed to upload avatar', isError: true);
        return;
      }
      setState(() => _selectedImage = null);
      await context.read<AuthProvider>().refreshUser();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Upload avatar first if selected
    if (_selectedImage != null) {
      await _uploadAvatarAndSave();
      if (!mounted) return;
    }
    
    setState(() => _saving = true);
    final result = await ApiService.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName:  _lastNameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      await context.read<AuthProvider>().refreshUser();
      if (mounted) {
        showToast(context, 'Profile updated successfully!');
        Navigator.pop(context);
      }
    } else {
      showToast(context, result.errorMessage ?? 'Failed to update profile', isError: true);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _loginIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageCream,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar Section ──
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.warmWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderStrong, width: 2),
                            ),
                            child: _selectedImage != null
                                ? ClipOval(child: Image.file(_selectedImage!, fit: BoxFit.cover))
                                : Consumer<AuthProvider>(
                                    builder: (_, auth, __) {
                                      return auth.user?.avatarUrl != null
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: auth.user!.avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => _defaultProfileAvatar(),
                                              ),
                                            )
                                          : _defaultProfileAvatar();
                                    },
                                  ),
                          ),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.deepRose, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: AppColors.deepRose),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage != null)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _selectedImage = null),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Remove Image'),
                        ),
                      if (_uploadingAvatar)
                        const Padding(padding: EdgeInsets.only(top: 8), child: CircularProgressIndicator(color: AppColors.deepRose)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('Personal Information', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _loginIdCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email or mobile number',
                    helperText: 'Login identity — cannot be changed',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 28),
                RoseButton(label: 'Save Changes', onPressed: _save, loading: _saving, width: double.infinity),
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
