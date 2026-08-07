import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/checkout_provider.dart';
import '../../services/checkout_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

class CheckoutStep3 extends StatefulWidget {
  final VoidCallback onPrevious;
  final VoidCallback onSuccess;
  final String? initialDeliveryDate;
  final String? initialDeliveryTime;
  final int? initialStoreId;

  const CheckoutStep3({
    super.key,
    required this.onPrevious,
    required this.onSuccess,
    this.initialDeliveryDate,
    this.initialDeliveryTime,
    this.initialStoreId,
  });

  @override
  State<CheckoutStep3> createState() => _CheckoutStep3State();
}

class _CheckoutStep3State extends State<CheckoutStep3> {
  // Per-store payment proof images: storeId -> File
  final Map<int, File> _storeImages = {};
  // Per-store uploaded proof URLs: storeId -> {url, public_id}
  final Map<int, Map<String, String>> _storeProofs = {};
  // Track which store is currently uploading
  int? _uploadingStoreId;
  double _uploadProgress = 0.0;
  final ImagePicker _imagePicker = ImagePicker();

  // Per-store delivery preferences
  final Map<int, DateTime> _storeDates = {};
  final Map<int, String?> _storeTimeSlots = {};
  final Map<int, List<String>> _storeAvailableTimeSlots = {};
  final Map<int, Map<String, String>> _storeTimeSlotLabels = {};
  final Map<int, bool> _storeTimeSlotsLoading = {};
  final Map<int, bool> _storeClosedOnDate = {};
  late final List<DateTime> _availableDates;

  // Duplicate submission prevention
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _availableDates = CheckoutService.getAvailableDeliveryDateRange(days: 14);
    
    // Pre-select delivery date/time from product detail screen
    if (widget.initialStoreId != null && widget.initialDeliveryDate != null) {
      final date = DateTime.tryParse(widget.initialDeliveryDate!);
      if (date != null) {
        _storeDates[widget.initialStoreId!] = date;
        if (widget.initialDeliveryTime != null) {
          _storeTimeSlots[widget.initialStoreId!] = widget.initialDeliveryTime;
        }
        
        // Add calendar-selected date to available dates list if not already there
        final normalized = CheckoutService.normalizeToPhDate(date);
        final alreadyInRange = _availableDates.any((d) =>
            CheckoutService.normalizeToPhDate(d) == normalized);
        if (!alreadyInRange) {
          _availableDates.add(normalized);
        }
        
        _fetchTimeSlotsForStore(widget.initialStoreId!, date);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, checkoutProvider, _) {
        final storeTotals = checkoutProvider.validationResponse?.storeOrderTotals ?? [];
        final allStoresHaveProof = storeTotals.every((s) => _storeImages.containsKey(s.storeId));
        final allStoresHaveDelivery = storeTotals.every((s) =>
            _storeDates.containsKey(s.storeId) &&
            _storeTimeSlots[s.storeId] != null);
        final allStoresReady = allStoresHaveProof && allStoresHaveDelivery;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepHeader(context, storeTotals.length),
                const SizedBox(height: 24),
                if (checkoutProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildMessageCard(
                      context,
                      checkoutProvider.error!,
                      icon: Icons.warning_amber_rounded,
                      tint: const Color(0xFFc0392b),
                    ),
                  ),
                _buildInstructionsCard(context, storeTotals.length),
                const SizedBox(height: 24),
                // Per-store payment proof upload sections
                ...storeTotals.map((storeOrder) =>
                    _buildStorePaymentSection(context, storeOrder)),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.dustyRose, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          storeTotals.length > 1
                              ? 'You are ordering from ${storeTotals.length} stores. Each store requires its own delivery schedule and payment proof. '
                                'Sellers will verify payment within 24 hours.'
                              : 'By submitting your proof, you acknowledge that the payment was made and the seller has 24 hours to verify.\n\n'
                                'Do not close this window until you see the confirmation message.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (checkoutProvider.isProcessing)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.glassFill,
                                border: Border.all(color: AppColors.glassBorder),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _uploadProgress.clamp(0.0, 1.0),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.brandGradientH,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadingStoreId != null
                            ? 'Uploading proof for store... ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                            : 'Creating orders... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: checkoutProvider.isProcessing ? null : widget.onPrevious,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSubmitButton(
                        context,
                        label: allStoresReady
                            ? 'Confirm & Create Order${storeTotals.length > 1 ? 's' : ''}'
                            : 'Complete all fields to continue',
                        loading: checkoutProvider.isProcessing || _isSubmitting,
                        onPressed: !allStoresReady || checkoutProvider.isProcessing || _isSubmitting
                            ? null
                            : () => _submitAllPaymentProofs(context, checkoutProvider),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(
    BuildContext context, {
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: enabled ? AppShadows.roseButton : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Per-store delivery & payment section ────────────────────────────────────
  Widget _buildStorePaymentSection(BuildContext context, dynamic storeOrder) {
    final storeId = storeOrder.storeId as int;
    final storeName = storeOrder.storeName as String;
    final total = storeOrder.total as double;
    final hasImage = _storeImages.containsKey(storeId);
    final hasDelivery = _storeDates.containsKey(storeId) && _storeTimeSlots[storeId] != null;
    final isReady = hasImage && hasDelivery;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.sage.withOpacity(0.07)
            : (hasImage || hasDelivery)
                ? AppColors.roseCta.withOpacity(0.07)
                : AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glass,
        border: Border.all(
          color: isReady
              ? AppColors.sage
              : (hasImage || hasDelivery)
                  ? AppColors.roseCta
                  : AppColors.glassBorder,
          width: isReady ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 18, color: AppColors.labelPink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    storeName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPink,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose,
                  ),
                ),
                if (isReady) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: AppColors.deepSage, size: 20),
                ],
              ],
            ),
          ),
          if (storeOrder.items != null && (storeOrder.items as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: (storeOrder.items as List).map<Widget>((rawItem) {
                    final item = rawItem as Map<String, dynamic>;
                    final productId = item['product_id'];
                    final variantId = item['variant_id'];
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    final unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final origPrice = (item['original_price'] as num?)?.toDouble();
                    final discPct = item['discount_pct'] as int?;
                    final lineTotal = unitPrice * qty;
                    final itemLabel = variantId != null
                        ? 'Product #$productId (Variant #$variantId)'
                        : 'Product #$productId';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemLabel,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Qty: $qty x ₱${unitPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                                    ),
                                    if (origPrice != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '₱${origPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                    if (discPct != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.deepRose,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$discPct% off',
                                          style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${lineTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          // Per-store delivery date
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _buildStoreDateSection(context, storeId),
          ),
          // Per-store delivery time slot
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _buildStoreTimeSlotSection(context, storeId),
          ),
          const Divider(height: 24, indent: 14, endIndent: 14),
          // QR code display if available
          if (storeOrder.qrImages != null && (storeOrder.qrImages as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send payment to:',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    storeOrder.instructions ?? 'Pay via GCash',
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          // Image picker/preview
          Padding(
            padding: const EdgeInsets.all(14),
            child: hasImage
                ? _buildStoreImagePreview(context, storeId)
                : _buildStoreImagePicker(context, storeId),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreImagePicker(BuildContext context, int storeId) {
    return GestureDetector(
      onTap: () => _showImagePickerOptions(context, storeId),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cream,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.dustyRose),
            const SizedBox(height: 8),
            Text('Upload payment screenshot', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreImagePreview(BuildContext context, int storeId) {
    final image = _storeImages[storeId]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cream,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _storeImages.remove(storeId);
                _storeProofs.remove(storeId);
              }),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCE9E7),
                foregroundColor: const Color(0xFFc0392b),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: GoogleFonts.dmSans(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _showImagePickerOptions(context, storeId),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Change'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: GoogleFonts.dmSans(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showImagePickerOptions(BuildContext context, int storeId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, storeId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, storeId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, int storeId) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _storeImages[storeId] = File(pickedFile.path);
          _storeProofs.remove(storeId); // Clear old upload if re-picking
        });
      }
    } catch (e) {
      if (mounted) showToast(context, 'Error picking image: $e', isError: true);
    }
  }

  // ── Upload all proofs then create orders ───────────────────────────────────
  Future<void> _submitAllPaymentProofs(BuildContext context, CheckoutProvider provider) async {
    // Prevent duplicate submissions
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final storeTotals = provider.validationResponse?.storeOrderTotals ?? [];

    try {
      // Upload each store's proof
      for (final storeOrder in storeTotals) {
        final storeId = storeOrder.storeId as int;
        final image = _storeImages[storeId];
        if (image == null) {
          if (mounted) showToast(context, 'Missing proof for ${storeOrder.storeName}', isError: true);
          setState(() => _isSubmitting = false);
          return;
        }

        // Skip if already uploaded
        if (_storeProofs.containsKey(storeId)) continue;

        setState(() {
          _uploadingStoreId = storeId;
          _uploadProgress = 0.0;
        });

        final uploadResponse = await CheckoutService.uploadPaymentProof(
          imagePath: image.path,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );

        if (!uploadResponse.isSuccess) {
          provider.clearError();
          if (!mounted) return;
          showToast(
            context,
            'Failed to upload proof for ${storeOrder.storeName}: ${uploadResponse.errorMessage}',
            isError: true,
          );
          setState(() {
            _uploadingStoreId = null;
            _isSubmitting = false;
          });
          return;
        }

        final proofUrl = uploadResponse.data['secure_url'] as String?;
        final publicId = uploadResponse.data['public_id'] as String?;

        if (proofUrl == null || publicId == null) {
          if (!mounted) return;
          showToast(context, 'Invalid upload response for ${storeOrder.storeName}', isError: true);
          setState(() {
            _uploadingStoreId = null;
            _isSubmitting = false;
          });
          return;
        }

        _storeProofs[storeId] = {'url': proofUrl, 'public_id': publicId};
      }

      setState(() => _uploadingStoreId = null);

      // All proofs uploaded - create orders with per-store proofs and delivery preferences
      final success = await provider.createOrders(
        storePaymentProofs: _storeProofs,
        storeDeliveryDates: _storeDates,
        storeDeliveryTimes: _storeTimeSlots.map((k, v) => MapEntry(k, v!)),
      );

      if (success && mounted) {
        widget.onSuccess();
      } else {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } catch (e) {
      setState(() {
        _uploadingStoreId = null;
        _isSubmitting = false;
      });
      if (!mounted) return;
      showToast(context, 'Error: $e', isError: true);
    }
  }

  // ── Per-store delivery date/time ───────────────────────────────────────────

  Future<void> _fetchTimeSlotsForStore(int storeId, DateTime date) async {
    final normalizedDate = CheckoutService.normalizeToPhDate(date);
    final dateStr = DateFormat('yyyy-MM-dd').format(normalizedDate);

    setState(() {
      _storeTimeSlotsLoading[storeId] = true;
      _storeClosedOnDate[storeId] = false;
    });

    final result = await CheckoutService.fetchStoreTimeSlots(storeId, dateStr);

    if (!mounted) return;

    setState(() {
      _storeTimeSlotsLoading[storeId] = false;
      if (result['success'] == true) {
        final rawSlots = List<String>.from(result['slots'] ?? []);
        _storeTimeSlotLabels[storeId] = Map<String, String>.from(result['labels'] ?? {});
        _storeClosedOnDate[storeId] = result['is_open'] == false;
        final isToday = DateFormat('yyyy-MM-dd').format(normalizedDate) ==
            DateFormat('yyyy-MM-dd').format(
              CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime()),
            );
        final filteredSlots = rawSlots.where((slot) {
          return !(isToday && CheckoutService.isTimeSlotPassed(slot));
        }).toList();
        _storeAvailableTimeSlots[storeId] = filteredSlots;
        final existing = _storeTimeSlots[storeId];
        if (existing != null && !filteredSlots.contains(existing)) {
          _storeTimeSlots[storeId] = null;
        }
        if (_storeTimeSlots[storeId] == null && filteredSlots.isNotEmpty) {
          _storeTimeSlots[storeId] = filteredSlots.first;
        }
      } else {
        _storeAvailableTimeSlots[storeId] = List<String>.from(result['slots'] ?? <String>[]);
        _storeClosedOnDate[storeId] = false;
        _storeTimeSlots[storeId] = null;
      }
    });
  }

  Widget _buildStoreDateSection(BuildContext context, int storeId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Date',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _availableDates.map((dateValue) {
              final selectedDate = _storeDates[storeId];
              final normalizedOption = CheckoutService.normalizeToPhDate(dateValue);
              final isSelected = selectedDate != null &&
                  CheckoutService.normalizeToPhDate(selectedDate) == normalizedOption;
              final month = CheckoutService.formatDeliveryMonth(normalizedOption);
              final day = CheckoutService.formatDeliveryDay(normalizedOption);
              final label = CheckoutService.formatDeliveryDateLabel(normalizedOption);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        month,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        day,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.deepRose,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _storeDates[storeId] = normalizedOption;
                        _storeTimeSlots[storeId] = null;
                        _storeClosedOnDate[storeId] = false;
                      });
                      _fetchTimeSlotsForStore(storeId, normalizedOption);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreTimeSlotSection(BuildContext context, int storeId) {
    final selectedDate = _storeDates[storeId];

    if (selectedDate == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Select a delivery date first.',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
        ),
      );
    }

    if (_storeTimeSlotsLoading[storeId] == true) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose))),
      );
    }

    if (_storeClosedOnDate[storeId] == true) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFc0392b).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFc0392b).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.store_outlined, color: Color(0xFFc0392b), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Store is closed on this day.',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFc0392b)),
              ),
            ),
          ],
        ),
      );
    }

    final slots = _storeAvailableTimeSlots[storeId] ?? <String>[];
    final labels = _storeTimeSlotLabels[storeId] ?? {};
    final availableSlots = slots;

    if (availableSlots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'No time slots available for this date.',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Time Slot',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _storeTimeSlots[storeId],
              hint: Text(
                'Select a time slot',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
              ),
              items: availableSlots.map((slot) {
                final formattedSlot = labels[slot] ?? CheckoutService.formatTimeSlot(slot);
                return DropdownMenuItem<String>(
                  value: slot,
                  child: Text(formattedSlot, style: GoogleFonts.dmSans(fontSize: 13)),
                );
              }).toList(),
              onChanged: (selected) {
                if (selected != null) {
                  setState(() => _storeTimeSlots[storeId] = selected);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(BuildContext context, int storeCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.roseGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '3',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery & Payment', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  storeCount > 1
                      ? 'Choose delivery schedule and upload payment proof for each store ($storeCount stores).'
                      : 'Choose your delivery schedule and upload your GCash screenshot.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(BuildContext context, int storeCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instructions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            storeCount > 1
                ? '1. Select delivery date & time for each store\n'
                  '2. Pay each store separately via GCash\n'
                  '3. Take a screenshot for each payment\n'
                  '4. Upload the corresponding screenshot for each store below\n'
                  '5. Each seller will verify their payment within 24 hours'
                : '1. Select your preferred delivery date & time\n'
                  '2. Take a screenshot or photo of your GCash transfer\n'
                  '3. Make sure the transaction reference number is visible\n'
                  '4. Upload the image below\n'
                  '5. Seller will verify the payment within 24 hours',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tint),
            ),
          ),
        ],
      ),
    );
  }
}
