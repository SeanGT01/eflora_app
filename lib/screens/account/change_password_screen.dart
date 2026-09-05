
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _currCtrl = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure1 = true, _obscure2 = true, _obscure3 = true;

  bool get _hasPasswordInput =>
      _currCtrl.text.trim().isNotEmpty ||
      _newCtrl.text.trim().isNotEmpty ||
      _confCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_currCtrl, _newCtrl, _confCtrl]) {
      ctrl.addListener(() => setState(() {}));
    }
    _currCtrl.addListener(() {
      if (_newCtrl.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  String? _validateNewPassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Required';
    if (value == _currCtrl.text) {
      return 'New password must be different from current password';
    }
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must include lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must include uppercase letter';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Must include special character';
    return null;
  }

  Future<void> _change() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ApiService.changePassword(
      currentPassword: _currCtrl.text,
      newPassword:     _newCtrl.text,
      confirmPassword: _confCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      showToast(context, 'Password changed successfully!');
      Navigator.pop(context);
    } else {
      showToast(context, result.errorMessage ?? 'Failed to change password', isError: true);
    }
  }

  @override
  void dispose() { _currCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageCream,
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _pwField(_currCtrl, 'Current password', _obscure1, () => setState(() => _obscure1 = !_obscure1),
                    (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 14),
                _pwField(_newCtrl, 'New password', _obscure2, () => setState(() => _obscure2 = !_obscure2),
                    (v) => _validateNewPassword(v)),
                const SizedBox(height: 14),
                _pwField(_confCtrl, 'Confirm new password', _obscure3, () => setState(() => _obscure3 = !_obscure3),
                    (v) => v != _newCtrl.text ? 'Passwords do not match' : null),
                const SizedBox(height: 28),
                RoseButton(
                  label: 'Change Password',
                  onPressed: _hasPasswordInput && !_saving ? _change : null,
                  loading: _saving,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle, String? Function(String?)? validator) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }
}
