import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/checkout_provider.dart';
import '../../models/checkout.dart';
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
  // Per-store payment method: storeId -> "gcash" | "cod"
  final Map<int, String> _storePaymentMethods = {};
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
  final Map<int, String?> _storeSlotBlockReason = {};

  // Duplicate submission prevention
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Pre-select delivery date/time from product detail screen
    if (widget.initialStoreId != null && widget.initialDeliveryDate != null) {
      final date = DateTime.tryParse(widget.initialDeliveryDate!);
      if (date != null) {
        final normalized = CheckoutService.normalizeToPhDate(date);
        _storeDates[widget.initialStoreId!] = normalized;
        if (widget.initialDeliveryTime != null) {
          _storeTimeSlots[widget.initialStoreId!] = widget.initialDeliveryTime;
        }
        _fetchTimeSlotsForStore(widget.initialStoreId!, normalized);
      }
    }
  }

  String _paymentMethodFor(StoreOrderTotal storeOrder) {
    if (storeOrder.allowCod && _storePaymentMethods[storeOrder.storeId] == 'cod') {
      return 'cod';
    }
    return 'gcash';
  }

  bool _isCod(StoreOrderTotal storeOrder) => _paymentMethodFor(storeOrder) == 'cod';

  bool _storeIsReady(StoreOrderTotal storeOrder) {
    final hasDelivery = _storeDates.containsKey(storeOrder.storeId) &&
        _storeTimeSlots[storeOrder.storeId] != null;
    if (!hasDelivery) return false;
    if (_isCod(storeOrder)) return true;
    return _storeImages.containsKey(storeOrder.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckoutProvider>(
      builder: (context, checkoutProvider, _) {
        final storeTotals = checkoutProvider.validationResponse?.storeOrderTotals ?? [];
        final allStoresReady = storeTotals.every(_storeIsReady);
        final allCod = storeTotals.isNotEmpty && storeTotals.every(_isCod);

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
                      CheckoutService.humanizeDeliverySlotError(
                        checkoutProvider.error,
                      ),
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
                          allCod
                              ? (storeTotals.length > 1
                                  ? 'You are ordering from ${storeTotals.length} stores with Cash on Delivery. Prepare the exact amount for each store upon delivery.'
                                  : 'Cash on Delivery selected. Prepare the exact amount upon delivery.\n\nDo not close this window until you see the confirmation message.')
                              : storeTotals.length > 1
                                  ? 'You are ordering from ${storeTotals.length} stores. Choose GCash or Cash on Delivery for each store. GCash orders need a payment screenshot. '
                                    'Sellers will verify payment within 24 hours.'
                                  : 'For GCash, submit your proof so the seller can verify payment within 24 hours.\n\n'
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
  Widget _buildStorePaymentSection(BuildContext context, StoreOrderTotal storeOrder) {
    final storeId = storeOrder.storeId;
    final storeName = storeOrder.storeName;
    final total = storeOrder.total;
    final isCod = _isCod(storeOrder);
    final hasImage = _storeImages.containsKey(storeId);
    final hasDelivery = _storeDates.containsKey(storeId) && _storeTimeSlots[storeId] != null;
    final isReady = _storeIsReady(storeOrder);
    final inProgress = hasDelivery || (!isCod && hasImage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.sage.withOpacity(0.07)
            : inProgress
                ? AppColors.roseCta.withOpacity(0.07)
                : AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glass,
        border: Border.all(
          color: isReady
              ? AppColors.sage
              : inProgress
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
          // Per-store delivery date + time (web-style grid)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _buildStoreDeliveryCard(context, storeId),
          ),
          const Divider(height: 24, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _buildPaymentMethodSelector(context, storeOrder),
          ),
          if (isCod)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _buildCodInfoCard(),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildStoreQrSection(context, storeOrder),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildStoreProofUpload(context, storeId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector(BuildContext context, StoreOrderTotal storeOrder) {
    final method = _paymentMethodFor(storeOrder);
    final codEnabled = storeOrder.allowCod;

    Widget chip({
      required String value,
      required String label,
      required bool enabled,
    }) {
      final selected = method == value;
      return GestureDetector(
        onTap: !enabled
            ? null
            : () => setState(() => _storePaymentMethods[storeOrder.storeId] = value),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.dustyRose.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.dustyRose.withOpacity(0.45) : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 16,
                  color: selected ? AppColors.deepRose : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            chip(value: 'gcash', label: 'GCash', enabled: true),
            chip(value: 'cod', label: 'Cash on Delivery', enabled: codEnabled),
          ],
        ),
        if (!codEnabled) ...[
          const SizedBox(height: 8),
          Text(
            'Cash on Delivery is currently disabled by this store.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _buildCodInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: AppColors.charcoal),
              const SizedBox(width: 8),
              Text(
                'Cash on Delivery selected',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'No payment receipt required. Please prepare the exact amount upon delivery.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreQrSection(BuildContext context, StoreOrderTotal storeOrder) {
    final qrImages = (storeOrder.qrImages as List?)?.cast<String>() ?? const <String>[];
    final rawInstructions = (storeOrder.instructions as String?)?.trim();
    final instructions = (rawInstructions != null && rawInstructions.isNotEmpty)
        ? rawInstructions
        : 'Scan the GCash QR code, pay the exact amount due, then upload a screenshot of your receipt.';
    final hasQr = qrImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Instructions',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                instructions,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.charcoal,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'GCash QR Code',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: hasQr
              ? Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(
                      qrImages.first,
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _qrUnavailable(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.deepRose,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : _qrUnavailable(),
        ),
      ],
    );
  }

  Widget _qrUnavailable() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 48, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(
            'No QR code available',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreProofUpload(BuildContext context, int storeId) {
    final image = _storeImages[storeId];
    final hasImage = image != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload Payment Receipt',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      image,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _storeImages.remove(storeId);
                        _storeProofs.remove(storeId);
                      }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.border),
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Remove Image'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.blush.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: AppColors.deepRose,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showImagePickerOptions(context, storeId),
                    icon: const Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: AppColors.charcoal,
                    ),
                    label: Text(hasImage ? 'Replace Image' : 'Choose Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.charcoal,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select screenshot or photo of your GCash payment',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      // Upload GCash proofs only; COD orders skip receipt upload
      for (final storeOrder in storeTotals) {
        if (_isCod(storeOrder)) continue;

        final storeId = storeOrder.storeId;
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
      final storePaymentMethods = {
        for (final storeOrder in storeTotals)
          storeOrder.storeId: _paymentMethodFor(storeOrder),
      };
      final success = await provider.createOrders(
        storePaymentProofs: _storeProofs,
        storeDeliveryDates: _storeDates,
        storeDeliveryTimes: _storeTimeSlots.map((k, v) => MapEntry(k, v!)),
        storePaymentMethods: storePaymentMethods,
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
      _storeSlotBlockReason[storeId] = null;
    });

    final result = await CheckoutService.fetchStoreTimeSlots(storeId, dateStr);

    if (!mounted) return;

    setState(() {
      _storeTimeSlotsLoading[storeId] = false;
      if (result['success'] == true) {
        final rawSlots = List<String>.from(result['slots'] ?? []);
        _storeTimeSlotLabels[storeId] = Map<String, String>.from(result['labels'] ?? {});
        final isOpen = result['is_open'] == true;
        final hasSchedule = result['has_schedule'] == true;
        final isToday = DateFormat('yyyy-MM-dd').format(normalizedDate) ==
            DateFormat('yyyy-MM-dd').format(
              CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime()),
            );
        final filteredSlots = rawSlots.where((slot) {
          return !(isToday && CheckoutService.isTimeSlotPassed(slot));
        }).toList();
        final reason = CheckoutService.resolveSlotBlockReason(
          apiReason: result['block_reason'],
          isToday: isToday,
          isOpen: isOpen,
          hasSchedule: hasSchedule,
          hasBookableSlots: filteredSlots.isNotEmpty,
          orderCutoff: result['order_cutoff'],
          openDays: List<String>.from(result['open_days'] ?? const <String>[]),
          date: normalizedDate,
        );
        _storeClosedOnDate[storeId] = reason == 'closed';
        _storeSlotBlockReason[storeId] = reason;
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
        _storeSlotBlockReason[storeId] = 'no_schedule';
        _storeTimeSlots[storeId] = null;
      }
    });
  }

  Widget _buildStoreDeliveryCard(BuildContext context, int storeId) {
    final selectedDate = _storeDates[storeId];
    final dateLabel = selectedDate == null
        ? 'Select date'
        : DateFormat('MMM d, yyyy').format(
            CheckoutService.normalizeToPhDate(selectedDate),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requested Delivery',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          if ((_storeAvailableTimeSlots[storeId] ?? const <String>[]).isEmpty &&
              _storeSlotBlockReason[storeId] != null &&
              _storeTimeSlotsLoading[storeId] != true &&
              selectedDate != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFc0392b).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: const Color(0xFFc0392b).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFFc0392b), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CheckoutService.slotBlockMessage(
                        _storeSlotBlockReason[storeId],
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFc0392b),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _pickStoreDeliveryDate(context, storeId),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dateLabel,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: selectedDate == null
                                      ? AppColors.muted
                                      : AppColors.charcoal,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppColors.deepRose,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Slot',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStoreTimeSlotDropdown(context, storeId),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Closed days, past dates, and past hours are locked based on this store\'s open schedule.',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStoreDeliveryDate(BuildContext context, int storeId) async {
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final maxDate = phToday.add(const Duration(days: 14));
    final current = _storeDates[storeId];
    var initialDate = current != null
        ? CheckoutService.normalizeToPhDate(current)
        : phToday;
    if (initialDate.isBefore(phToday)) initialDate = phToday;
    if (initialDate.isAfter(maxDate)) initialDate = maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: phToday,
      lastDate: maxDate,
      helpText: 'SELECT DELIVERY DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.roseCta,
              onPrimary: Colors.white,
              onSurface: AppColors.charcoal,
              surface: AppColors.warmWhite,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.warmWhite,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.roseCta,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              todayBorder: const BorderSide(color: AppColors.pinkMid, width: 1.5),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.muted.withValues(alpha: 0.45);
                }
                if (states.contains(WidgetState.selected)) return Colors.white;
                return AppColors.charcoal;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.roseCta;
                return null;
              }),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    final normalized = CheckoutService.normalizeToPhDate(picked);
    setState(() {
      _storeDates[storeId] = normalized;
      _storeTimeSlots[storeId] = null;
      _storeClosedOnDate[storeId] = false;
    });
    await _fetchTimeSlotsForStore(storeId, normalized);
  }

  Widget _buildStoreTimeSlotDropdown(BuildContext context, int storeId) {
    final selectedDate = _storeDates[storeId];

    Widget fieldShell({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
    }

    if (selectedDate == null) {
      return fieldShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Select date first',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }

    if (_storeTimeSlotsLoading[storeId] == true) {
      return fieldShell(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
            ),
          ),
        ),
      );
    }

    if (_storeClosedOnDate[storeId] == true ||
        (_storeAvailableTimeSlots[storeId] ?? const <String>[]).isEmpty) {
      final reason = _storeSlotBlockReason[storeId];
      final placeholder = reason == 'no_schedule'
          ? 'Hours not set'
          : reason == 'closed'
              ? '— Closed —'
              : 'No slots';
      return fieldShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            placeholder,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }

    final slots = _storeAvailableTimeSlots[storeId] ?? <String>[];
    final labels = _storeTimeSlotLabels[storeId] ?? {};

    return fieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _storeTimeSlots[storeId],
          hint: Text(
            'Select a time slot',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.charcoal),
          items: slots.map((slot) {
            final formattedSlot = labels[slot] ?? CheckoutService.formatTimeSlot(slot);
            return DropdownMenuItem<String>(
              value: slot,
              child: Text(formattedSlot, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (selected) {
            if (selected != null) {
              setState(() => _storeTimeSlots[storeId] = selected);
            }
          },
        ),
      ),
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
                      ? 'Choose delivery schedule and payment method for each store ($storeCount stores).'
                      : 'Choose your delivery schedule and payment method.',
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
                  '2. Choose GCash or Cash on Delivery for each store\n'
                  '3. For GCash, pay that store and upload the screenshot\n'
                  '4. For Cash on Delivery, no receipt is needed\n'
                  '5. Each seller will confirm the order within 24 hours'
                : '1. Select your preferred delivery date & time\n'
                  '2. Choose GCash or Cash on Delivery\n'
                  '3. For GCash, upload a screenshot of your transfer\n'
                  '4. For Cash on Delivery, prepare the exact amount on delivery\n'
                  '5. The seller will confirm your order within 24 hours',
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
