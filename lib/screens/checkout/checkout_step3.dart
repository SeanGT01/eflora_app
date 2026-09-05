import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../models/cart.dart';
import '../../models/checkout.dart';
import '../../services/checkout_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checkout_summary_line.dart';
import '../../widgets/common.dart';
import '../../widgets/active_order_limit_dialog.dart';

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
  final Map<int, bool> _storeTimeSlotsLoading = {};
  final Map<int, bool> _storeClosedOnDate = {};
  final Map<int, String?> _storeSlotBlockReason = {};
  /// Weekday names the store is open (`monday`…), from time-slot / schedule API.
  final Map<int, Set<String>> _storeOpenDays = {};
  final Map<int, bool> _storeHasSchedule = {};

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
    final selected = _storePaymentMethods[storeOrder.storeId];
    if (storeOrder.allowCod && selected == 'cod') return 'cod';
    if (storeOrder.allowGcash && selected != 'cod') return 'gcash';
    if (storeOrder.allowGcash) return 'gcash';
    if (storeOrder.allowCod) return 'cod';
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
        final cartItems = context.watch<CartProvider>().items;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    ...storeTotals.map((storeOrder) =>
                        _buildStorePaymentSection(context, storeOrder, cartItems)),
                    if (checkoutProvider.isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
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
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.pageCream.withValues(alpha: 0.92),
                  border: const Border(
                    top: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                child: Row(
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
                            ? 'Place order'
                            : 'Complete details',
                        loading: checkoutProvider.isProcessing || _isSubmitting,
                        onPressed: !allStoresReady || checkoutProvider.isProcessing || _isSubmitting
                            ? null
                            : () => _submitAllPaymentProofs(context, checkoutProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  Widget _buildStorePaymentSection(
    BuildContext context,
    StoreOrderTotal storeOrder,
    List<CartItem> cartItems,
  ) {
    final storeId = storeOrder.storeId;
    final storeName = storeOrder.storeName;
    final total = storeOrder.total;
    final isCod = _isCod(storeOrder);
    final isReady = _storeIsReady(storeOrder);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glass,
        border: Border.all(
          color: isReady ? AppColors.sage.withValues(alpha: 0.55) : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
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
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, color: AppColors.deepSage, size: 18),
                ],
              ],
            ),
          ),
          if (storeOrder.items != null && (storeOrder.items as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  ...(storeOrder.items as List).map((rawItem) {
                    return CheckoutSummaryLine.fromCheckoutItem(
                      item: Map<String, dynamic>.from(rawItem as Map),
                      cartItems: cartItems,
                    );
                  }),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _buildStoreDeliveryCard(context, storeId),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _buildPaymentMethodSelector(context, storeOrder),
          ),
          if (isCod)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _buildCodInfoCard(),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildStoreQrSection(context, storeOrder),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _buildStoreProofUpload(context, storeId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector(BuildContext context, StoreOrderTotal storeOrder) {
    final method = _paymentMethodFor(storeOrder);
    final gcashEnabled = storeOrder.allowGcash;
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
          'Pay with',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(value: 'gcash', label: 'GCash', enabled: gcashEnabled),
            chip(value: 'cod', label: 'Cash on delivery', enabled: codEnabled),
          ],
        ),
        if (!gcashEnabled) ...[
          const SizedBox(height: 6),
          Text(
            'GCash is disabled by this store.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ],
        if (!codEnabled) ...[
          const SizedBox(height: 6),
          Text(
            'Cash on delivery is disabled by this store.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _buildCodInfoCard() {
    return Text(
      'Pay the rider in cash. No receipt needed.',
      style: GoogleFonts.dmSans(
        fontSize: 12.5,
        color: AppColors.muted,
        height: 1.4,
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
        Text(
          instructions,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: hasQr
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    qrImages.first,
                    width: 168,
                    height: 168,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _qrUnavailable(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 168,
                        width: 168,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.deepRose,
                            ),
                          ),
                        ),
                      );
                    },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Receipt',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.file(
              image,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _storeImages.remove(storeId);
                  _storeProofs.remove(storeId);
                }),
                child: Text(
                  'Remove',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showImagePickerOptions(context, storeId),
                child: Text(
                  'Replace',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose,
                  ),
                ),
              ),
            ],
          ),
        ] else
          OutlinedButton.icon(
            onPressed: () => _showImagePickerOptions(context, storeId),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Upload GCash screenshot'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        if (mounted) {
          setState(() => _isSubmitting = false);
          if (isActiveOrderLimitError(provider.error)) {
            await showActiveOrderLimitDialog(context);
          }
        }
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
        final openDays = (result['open_days'] as List? ?? const [])
            .map((d) => d.toString().toLowerCase())
            .toSet();
        _storeOpenDays[storeId] = openDays;
        _storeHasSchedule[storeId] = hasSchedule;
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
        _storeHasSchedule[storeId] = false;
        _storeOpenDays[storeId] = {};
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        if ((_storeAvailableTimeSlots[storeId] ?? const <String>[]).isEmpty &&
            _storeSlotBlockReason[storeId] != null &&
            _storeTimeSlotsLoading[storeId] != true &&
            selectedDate != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 360;
            final dateField = _deliveryPickerField(
              label: 'Date',
              value: dateLabel,
              icon: Icons.calendar_today_rounded,
              isPlaceholder: selectedDate == null,
              onTap: () => _pickStoreDeliveryDate(context, storeId),
            );
            final hoursField = _deliveryPickerField(
              label: 'Hours',
              value: _hoursFieldLabel(storeId),
              icon: Icons.schedule_rounded,
              isPlaceholder: _storeTimeSlots[storeId] == null,
              onTap: selectedDate == null ||
                      _storeTimeSlotsLoading[storeId] == true
                  ? null
                  : () => _pickStoreTimeSlot(context, storeId),
            );
            if (stacked) {
              return Column(
                children: [
                  dateField,
                  const SizedBox(height: 8),
                  hoursField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: dateField),
                const SizedBox(width: 8),
                Expanded(flex: 6, child: hoursField),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _deliveryPickerField({
    required String label,
    required String value,
    required IconData icon,
    required bool isPlaceholder,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          suffixIcon: Icon(icon, size: 15, color: AppColors.deepRose),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            height: 1.2,
            color: isPlaceholder ? AppColors.muted : AppColors.charcoal,
          ),
        ),
      ),
    );
  }

  bool _isStoreOpenOn(int storeId, DateTime date) {
    final hasSchedule = _storeHasSchedule[storeId] == true;
    final openDays = _storeOpenDays[storeId] ?? {};
    if (!hasSchedule || openDays.isEmpty) return false;
    const names = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    ];
    return openDays.contains(names[date.weekday - 1]);
  }

  /// Ensure open-day set is loaded before the calendar (matches web flatpickr disable).
  Future<bool> _ensureStoreOpenDays(int storeId) async {
    if (_storeOpenDays.containsKey(storeId) &&
        (_storeHasSchedule[storeId] == true) &&
        (_storeOpenDays[storeId]?.isNotEmpty ?? false)) {
      return true;
    }
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final dateStr = DateFormat('yyyy-MM-dd').format(phToday);
    final result = await CheckoutService.fetchStoreTimeSlots(storeId, dateStr);
    if (!mounted) return false;
    if (result['success'] != true) {
      setState(() {
        _storeHasSchedule[storeId] = false;
        _storeOpenDays[storeId] = {};
      });
      return false;
    }
    final openDays = (result['open_days'] as List? ?? const [])
        .map((d) => d.toString().toLowerCase())
        .toSet();
    final hasSchedule = result['has_schedule'] == true;
    setState(() {
      _storeOpenDays[storeId] = openDays;
      _storeHasSchedule[storeId] = hasSchedule;
    });
    return hasSchedule && openDays.isNotEmpty;
  }

  Future<void> _pickStoreDeliveryDate(BuildContext context, int storeId) async {
    final ready = await _ensureStoreOpenDays(storeId);
    if (!mounted) return;
    if (!ready) {
      showToast(
        context,
        'This store has not set delivery hours yet.',
        isError: true,
      );
      return;
    }

    final openDates = _openDeliveryDates(storeId);
    if (openDates.isEmpty) {
      showToast(
        context,
        'No open delivery days in the next 2 weeks.',
        isError: true,
      );
      return;
    }

    final current = _storeDates[storeId];
    var initialIndex = 0;
    if (current != null) {
      final normalized = CheckoutService.normalizeToPhDate(current);
      final match = openDates.indexWhere((d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day);
      if (match >= 0) initialIndex = match;
    }

    final picked = await _showCupertinoWheelPicker<DateTime>(
      title: 'Delivery date',
      itemCount: openDates.length,
      initialIndex: initialIndex,
      itemBuilder: (index) => Center(
        child: Text(
          DateFormat('EEE, MMM d').format(openDates[index]),
          style: GoogleFonts.dmSans(fontSize: 20, color: AppColors.charcoal),
        ),
      ),
      valueOf: (index) => openDates[index],
    );

    if (picked == null || !mounted) return;
    final normalized = CheckoutService.normalizeToPhDate(picked);
    if (!_isStoreOpenOn(storeId, normalized)) {
      showToast(context, 'Store is closed on this day. Pick another date.', isError: true);
      return;
    }
    setState(() {
      _storeDates[storeId] = normalized;
      _storeTimeSlots[storeId] = null;
      _storeClosedOnDate[storeId] = false;
    });
    await _fetchTimeSlotsForStore(storeId, normalized);
  }

  List<DateTime> _openDeliveryDates(int storeId) {
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final maxDate = phToday.add(const Duration(days: 14));
    final dates = <DateTime>[];
    for (var d = phToday; !d.isAfter(maxDate); d = d.add(const Duration(days: 1))) {
      if (_isStoreOpenOn(storeId, d)) dates.add(d);
    }
    return dates;
  }

  String _hoursFieldLabel(int storeId) {
    final selected = _storeTimeSlots[storeId];
    if (selected != null) return CheckoutService.formatTimeSlot(selected);
    if (_storeDates[storeId] == null) return 'Select date first';
    if (_storeTimeSlotsLoading[storeId] == true) return 'Loading…';
    final reason = _storeSlotBlockReason[storeId];
    if (_storeClosedOnDate[storeId] == true ||
        (_storeAvailableTimeSlots[storeId] ?? const <String>[]).isEmpty) {
      if (reason == 'no_schedule') return 'Hours not set';
      if (reason == 'closed') return 'Closed';
      return 'No slots';
    }
    return 'Select hours';
  }

  Future<void> _pickStoreTimeSlot(BuildContext context, int storeId) async {
    final slots = _storeAvailableTimeSlots[storeId] ?? const <String>[];
    if (slots.isEmpty) {
      showToast(context, 'No delivery hours for this date.', isError: true);
      return;
    }
    final current = _storeTimeSlots[storeId];
    var initialIndex = current == null ? 0 : slots.indexOf(current);
    if (initialIndex < 0) initialIndex = 0;

    final picked = await _showCupertinoWheelPicker<String>(
      title: 'Delivery hours',
      itemCount: slots.length,
      initialIndex: initialIndex,
      itemBuilder: (index) => Center(
        child: Text(
          CheckoutService.formatTimeSlot(slots[index]),
          style: GoogleFonts.dmSans(fontSize: 20, color: AppColors.charcoal),
        ),
      ),
      valueOf: (index) => slots[index],
    );
    if (picked == null || !mounted) return;
    setState(() => _storeTimeSlots[storeId] = picked);
  }

  Future<T?> _showCupertinoWheelPicker<T>({
    required String title,
    required int itemCount,
    required int initialIndex,
    required Widget Function(int index) itemBuilder,
    required T Function(int index) valueOf,
  }) {
    var selected = initialIndex.clamp(0, itemCount - 1);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(ctx, valueOf(selected)),
                        child: Text(
                          'Done',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: selected),
                    onSelectedItemChanged: (index) => selected = index,
                    children: List.generate(itemCount, itemBuilder),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
