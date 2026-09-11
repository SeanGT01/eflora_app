import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog allowing a florist / seller to create and send a bespoke
/// Custom Arrangement Request Ticket inside a customer chat conversation.
class CustomQuoteCreateDialog extends StatefulWidget {
  final int conversationId;
  final Function(ChatMessage createdMessage)? onTicketCreated;

  const CustomQuoteCreateDialog({
    super.key,
    required this.conversationId,
    this.onTicketCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required int conversationId,
    Function(ChatMessage createdMessage)? onTicketCreated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CustomQuoteCreateDialog(
        conversationId: conversationId,
        onTicketCreated: onTicketCreated,
      ),
    );
  }

  @override
  State<CustomQuoteCreateDialog> createState() => _CustomQuoteCreateDialogState();
}

class _CustomQuoteCreateDialogState extends State<CustomQuoteCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _inclusionsCtrl = TextEditingController();

  String _selectedCategory = 'bouquets';
  File? _imageFile;
  bool _allowDedicationCard = false;
  bool _submitting = false;

  final List<Map<String, String>> _categories = const [
    {'value': 'bouquets', 'label': 'Bouquet'},
    {'value': 'fresh_flowers', 'label': 'Fresh Flowers'},
    {'value': 'potted_plants', 'label': 'Potted Plants'},
    {'value': 'succulents', 'label': 'Succulents'},
    {'value': 'dried_flowers', 'label': 'Dried Flowers'},
    {'value': 'stands', 'label': 'Flower Stand'},
    {'value': 'vases', 'label': 'Vase Arrangement'},
    {'value': 'custom', 'label': 'Special Custom'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _inclusionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid base price greater than 0.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final res = await ChatService.createCustomTicket(
      conversationId: widget.conversationId,
      title: _titleCtrl.text.trim(),
      category: _selectedCategory,
      basePrice: price,
      inclusions: _inclusionsCtrl.text.trim().isNotEmpty ? _inclusionsCtrl.text.trim() : null,
      imageFile: _imageFile,
      allowDedicationCard: _allowDedicationCard,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      Navigator.of(context).pop();
      if (res['message'] is ChatMessage && widget.onTicketCreated != null) {
        widget.onTicketCreated!(res['message'] as ChatMessage);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          content: Text('Custom arrangement quote sent to customer (valid for 4 hours).'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[700],
          content: Text(res['error'] ?? 'Failed to send quote ticket'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.deepRose, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Custom Arrangement Quote',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          'Valid for 4 hours upon sending',
                          style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Arrangement Title
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: _inputDeco(
                          label: 'Arrangement Title / Name *',
                          hint: 'e.g. 2 Dozen Red Roses with Gypsophila',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: _inputDeco(
                          label: 'Arrangement Category *',
                          hint: 'Select category',
                        ),
                        items: _categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['value'],
                            child: Text(c['label']!, style: GoogleFonts.dmSans(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Base Price
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDeco(
                          label: 'Base Quote Price (₱) *',
                          hint: '0.00',
                          prefixText: '₱ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Base price is required';
                          final n = double.tryParse(v.replaceAll(',', '').trim());
                          if (n == null || n <= 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Inclusions & Arrangement Specs
                      TextFormField(
                        controller: _inclusionsCtrl,
                        maxLines: 3,
                        decoration: _inputDeco(
                          label: 'Inclusions & Bouquet Specs',
                          hint: 'e.g. 24 red Ecuadorian roses, white eucalyptus wrap, customized satin ribbon',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sample / Inspiration Photo
                      Text(
                        'Inspiration / Sample Photo',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFBF7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.8),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _imageFile != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.file(
                                        _imageFile!,
                                        width: double.infinity,
                                        height: 110,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.black.withOpacity(0.6),
                                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.muted),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Upload arrangement photo / sample',
                                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dedication Card Message Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDFBF7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _allowDedicationCard
                                ? AppColors.deepRose.withValues(alpha: 0.35)
                                : AppColors.border.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.card_giftcard_rounded, size: 20, color: AppColors.deepRose),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dedication Card Message',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  Text(
                                    'Allow customer to add a free card message',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _allowDedicationCard,
                              activeThumbColor: AppColors.deepRose,
                              onChanged: (val) {
                                setState(() => _allowDedicationCard = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Send Quote Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepRose,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Send Custom Quote Ticket',
                                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.charcoal),
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFFDFBF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.deepRose, width: 1.5),
      ),
    );
  }
}
