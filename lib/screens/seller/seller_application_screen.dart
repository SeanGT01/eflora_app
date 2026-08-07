import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../services/api_service.dart';
import '../../models/seller_application.dart';

class SellerApplicationScreen extends StatefulWidget {
  /// If non-null, this is a resubmission for a rejected application.
  final SellerApplication? existingApplication;

  const SellerApplicationScreen({super.key, this.existingApplication});

  @override
  State<SellerApplicationScreen> createState() => _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _storeDescCtrl = TextEditingController();
  bool _agreeTerms = false;
  bool _submitting = false;

  // Image state
  File? _logoFile;
  String? _logoUrl;
  String? _logoPublicId;

  File? _govIdFile;
  String? _govIdUrl;
  String? _govIdPublicId;

  // Field-level errors from server
  Map<String, String> _fieldErrors = {};

  bool get _isResubmission => widget.existingApplication != null;
  SellerApplication? get _app => widget.existingApplication;

  @override
  void initState() {
    super.initState();
    if (_isResubmission) {
      _storeNameCtrl.text = _app!.storeName;
      _storeDescCtrl.text = _app!.storeDescription ?? '';
      _logoUrl = _app!.storeLogoUrl;
      _logoPublicId = _app!.storeLogoPublicId;
      _govIdUrl = _app!.governmentIdUrl;
      _govIdPublicId = _app!.governmentIdPublicId;
      _agreeTerms = true;
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storeDescCtrl.dispose();
    super.dispose();
  }

  bool _isFieldRejected(String field) =>
      _isResubmission && _app!.isFieldRejected(field);

  bool _isFieldEditable(String field) =>
      !_isResubmission || _isFieldRejected(field);

  Future<void> _pickImage(bool isLogo) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.deepRose),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.deepRose),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ]),
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      if (isLogo) {
        _logoFile = File(picked.path);
      } else {
        _govIdFile = File(picked.path);
      }
    });
  }

  Future<bool> _uploadImage(bool isLogo) async {
    final file = isLogo ? _logoFile : _govIdFile;
    if (file == null) return true; // Nothing new to upload

    final folder = isLogo ? 'e-flowers/seller_logos' : 'e-flowers/govt_ids';
    final result = await ApiService.uploadSellerDocument(file, folder);

    if (result.isSuccess && result.data is Map) {
      final d = result.data as Map<String, dynamic>;
      if (isLogo) {
        _logoUrl = d['url'];
        _logoPublicId = d['public_id'];
      } else {
        _govIdUrl = d['url'];
        _govIdPublicId = d['public_id'];
      }
      return true;
    }
    return false;
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});

    if (!_formKey.currentState!.validate()) return;

    // Validate images
    if (!_isResubmission || _isFieldRejected('store_logo')) {
      if (_logoFile == null && _logoUrl == null) {
        setState(() => _fieldErrors['store_logo'] = 'Please upload a store logo');
        return;
      }
    }
    if (!_isResubmission || _isFieldRejected('government_id')) {
      if (_govIdFile == null && _govIdUrl == null) {
        setState(() => _fieldErrors['government_id'] = 'Please upload a government ID');
        return;
      }
    }
    if (!_agreeTerms) {
      showToast(context, 'Please agree to the terms and conditions', isError: true);
      return;
    }

    setState(() => _submitting = true);

    // Upload images first
    final logoOk = await _uploadImage(true);
    if (!logoOk) {
      setState(() => _submitting = false);
      if (mounted) showToast(context, 'Failed to upload store logo', isError: true);
      return;
    }
    final govOk = await _uploadImage(false);
    if (!govOk) {
      setState(() => _submitting = false);
      if (mounted) showToast(context, 'Failed to upload government ID', isError: true);
      return;
    }

    ApiResult result;
    if (_isResubmission) {
      // Build map of only updated/rejected fields
      final updates = <String, dynamic>{};
      if (_isFieldRejected('store_name')) updates['store_name'] = _storeNameCtrl.text.trim();
      if (_isFieldRejected('store_description')) updates['store_description'] = _storeDescCtrl.text.trim();
      if (_isFieldRejected('store_logo') && _logoUrl != null) {
        updates['store_logo_url'] = _logoUrl;
        updates['store_logo_public_id'] = _logoPublicId;
      }
      if (_isFieldRejected('government_id') && _govIdUrl != null) {
        updates['government_id_url'] = _govIdUrl;
        updates['government_id_public_id'] = _govIdPublicId;
      }
      result = await ApiService.resubmitSellerApplication(updates);
    } else {
      result = await ApiService.submitSellerApplication(
        storeName: _storeNameCtrl.text.trim(),
        storeDescription: _storeDescCtrl.text.trim(),
        storeLogoUrl: _logoUrl!,
        storeLogoPublicId: _logoPublicId!,
        governmentIdUrl: _govIdUrl!,
        governmentIdPublicId: _govIdPublicId!,
      );
    }

    setState(() => _submitting = false);

    if (result.isSuccess) {
      if (mounted) {
        showToast(context, _isResubmission ? 'Application resubmitted!' : 'Application submitted!');
        Navigator.pop(context, true); // Return true to signal success
      }
    } else {
      final data = result.data;
      if (data is Map && data['field_errors'] != null) {
        setState(() {
          _fieldErrors = Map<String, String>.from(
            (data['field_errors'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        });
      } else {
        if (mounted) showToast(context, result.errorMessage ?? 'Submission failed', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(_isResubmission ? 'Update Application' : 'Become a Seller'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warmWhite, AppColors.cream],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.deepRose.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_outlined, color: AppColors.deepRose, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isResubmission ? 'Update Rejected Items' : 'Seller Application',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isResubmission
                              ? 'Please fix the highlighted items and resubmit'
                              : 'Fill in the details below to apply',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Store Name
              _buildFieldLabel('Store Name', required: true, rejected: _isFieldRejected('store_name')),
              if (_isFieldRejected('store_name'))
                _buildRejectionBanner(_app!.getRejectionReason('store_name')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _storeNameCtrl,
                enabled: _isFieldEditable('store_name'),
                decoration: _inputDecoration(
                  hint: 'Enter your store name',
                  error: _fieldErrors['store_name'],
                  rejected: _isFieldRejected('store_name'),
                ),
                validator: (v) => _isFieldEditable('store_name') && (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Store Description
              _buildFieldLabel('Store Description', required: true, rejected: _isFieldRejected('store_description')),
              if (_isFieldRejected('store_description'))
                _buildRejectionBanner(_app!.getRejectionReason('store_description')),
              const SizedBox(height: 6),
              TextFormField(
                controller: _storeDescCtrl,
                enabled: _isFieldEditable('store_description'),
                maxLines: 3,
                decoration: _inputDecoration(
                  hint: 'Describe your store and what you sell',
                  error: _fieldErrors['store_description'],
                  rejected: _isFieldRejected('store_description'),
                ),
                validator: (v) => _isFieldEditable('store_description') && (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Store Logo
              _buildFieldLabel('Store Logo', required: true, rejected: _isFieldRejected('store_logo')),
              if (_isFieldRejected('store_logo'))
                _buildRejectionBanner(_app!.getRejectionReason('store_logo')),
              if (_fieldErrors['store_logo'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(_fieldErrors['store_logo']!, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFc0392b))),
                ),
              const SizedBox(height: 6),
              _buildImagePicker(
                isLogo: true,
                file: _logoFile,
                url: _logoUrl,
                enabled: _isFieldEditable('store_logo'),
                rejected: _isFieldRejected('store_logo'),
              ),
              const SizedBox(height: 20),

              // Government ID
              _buildFieldLabel('Government ID', required: true, rejected: _isFieldRejected('government_id')),
              if (_isFieldRejected('government_id'))
                _buildRejectionBanner(_app!.getRejectionReason('government_id')),
              if (_fieldErrors['government_id'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(_fieldErrors['government_id']!, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFc0392b))),
                ),
              const SizedBox(height: 6),
              _buildImagePicker(
                isLogo: false,
                file: _govIdFile,
                url: _govIdUrl,
                enabled: _isFieldEditable('government_id'),
                rejected: _isFieldRejected('government_id'),
              ),
              const SizedBox(height: 24),

              // Terms checkbox
              if (!_isResubmission)
                Row(children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: _agreeTerms,
                      onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                      activeColor: AppColors.deepRose,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                      child: Text(
                        'I agree to the seller terms and conditions',
                        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.charcoal),
                      ),
                    ),
                  ),
                ]),
              const SizedBox(height: 28),

              // Submit button
              RoseButton(
                label: _isResubmission ? 'Resubmit Application' : 'Submit Application',
                icon: Icons.send_outlined,
                onPressed: _submit,
                loading: _submitting,
                width: double.infinity,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _buildFieldLabel(String label, {bool required = false, bool rejected = false}) {
    return Row(children: [
      Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: rejected ? const Color(0xFFc0392b) : AppColors.charcoal,
        ),
      ),
      if (required)
        Text(' *', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFc0392b))),
      if (rejected) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFc0392b).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('REJECTED', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFc0392b))),
        ),
      ],
    ]);
  }

  Widget _buildRejectionBanner(String? reason) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFc0392b).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFc0392b).withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 16, color: Color(0xFFc0392b)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reason ?? 'This field was rejected. Please update it.',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFc0392b)),
          ),
        ),
      ]),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? error, bool rejected = false}) {
    final borderColor = rejected ? const Color(0xFFc0392b) : AppColors.border;
    return InputDecoration(
      hintText: hint,
      errorText: error,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted.withOpacity(0.6)),
      filled: true,
      fillColor: AppColors.warmWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: rejected ? const Color(0xFFc0392b) : AppColors.deepRose, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFc0392b)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFc0392b), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildImagePicker({
    required bool isLogo,
    File? file,
    String? url,
    bool enabled = true,
    bool rejected = false,
  }) {
    final hasImage = file != null || (url != null && url.isNotEmpty);

    return GestureDetector(
      onTap: enabled ? () => _pickImage(isLogo) : null,
      child: Container(
        height: isLogo ? 160 : 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rejected
                ? const Color(0xFFc0392b)
                : (hasImage ? AppColors.sage : AppColors.border),
            width: rejected ? 1.5 : 1,
          ),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (file != null)
                      Image.file(file, fit: BoxFit.cover)
                    else
                      CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
                    // Change overlay
                    if (enabled)
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Change', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLogo ? Icons.add_photo_alternate_outlined : Icons.badge_outlined,
                    size: 36,
                    color: enabled ? AppColors.muted : AppColors.border,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogo ? 'Upload Store Logo' : 'Upload Government ID',
                    style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: enabled ? AppColors.muted : AppColors.border,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select an image',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted.withOpacity(0.6)),
                  ),
                ],
              ),
      ),
    );
  }
}
