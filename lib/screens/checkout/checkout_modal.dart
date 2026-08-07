import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/checkout.dart';
import '../../models/cart.dart';
import '../../providers/checkout_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import 'checkout_step1.dart';
import 'checkout_step2.dart';
import 'checkout_step3.dart';
import 'checkout_success.dart';

class CheckoutModal extends StatefulWidget {
  final List<Address>? addresses;
  final List<CartItem>? selectedItems;
  final VoidCallback? onClose;
  final int? buyNowProductId;
  final int? buyNowVariantId;
  final int buyNowQuantity;
  final String? initialDeliveryDate;
  final String? initialDeliveryTime;
  final int? initialStoreId;

  const CheckoutModal({
    super.key,
    this.addresses,
    this.selectedItems,
    this.onClose,
    this.buyNowProductId,
    this.buyNowVariantId,
    this.buyNowQuantity = 1,
    this.initialDeliveryDate,
    this.initialDeliveryTime,
    this.initialStoreId,
  });

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  late CheckoutProvider _checkoutProvider;

  @override
  void initState() {
    super.initState();
    _checkoutProvider = CheckoutProvider();
    if (widget.buyNowProductId != null) {
      _checkoutProvider.setBuyNowItem(
        productId: widget.buyNowProductId!,
        variantId: widget.buyNowVariantId,
        quantity: widget.buyNowQuantity,
      );
    }
  }

  @override
  void dispose() {
    _checkoutProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CheckoutProvider>.value(
      value: _checkoutProvider,
      child: Consumer<CheckoutProvider>(
        builder: (context, checkoutProvider, _) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.glassBorder, width: 1.5),
                  boxShadow: AppShadows.deep,
                ),
                clipBehavior: Clip.antiAlias,
                child: AppBackground(
                  showFlowers: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppShadows.roseButton,
                              ),
                              child: const Icon(
                                Icons.local_florist,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Checkout',
                                    style: Theme.of(context).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Secure your order in three simple steps',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _handleClose,
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.glassFill,
                                foregroundColor: AppColors.charcoal,
                                side: const BorderSide(color: AppColors.glassBorder, width: 1.5),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: _StepIndicator(currentStep: checkoutProvider.currentStep),
                      ),
                      Container(height: 1, color: AppColors.glassBorder),
                      Expanded(
                        child: _buildCurrentStep(context, checkoutProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, CheckoutProvider provider) {
    switch (provider.currentStep) {
      case 0:
        return CheckoutStep1(
          onNext: () => provider.nextStep(),
        );

      case 1:
        return CheckoutStep2(
          onNext: () => provider.nextStep(),
          onPrevious: () => provider.previousStep(),
        );

      case 2:
        return CheckoutStep3(
          onPrevious: () => provider.previousStep(),
          onSuccess: () => _handleCheckoutSuccess(context, provider),
          initialDeliveryDate: widget.initialDeliveryDate,
          initialDeliveryTime: widget.initialDeliveryTime,
          initialStoreId: widget.initialStoreId,
        );

      case 3:
        return CheckoutSuccess(
          orders: provider.createdOrders ?? [],
          grandTotal: provider.validationResponse?.grandTotal ?? 0.0,
          onClose: _handleCheckoutComplete,
        );

      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  void _handleCheckoutSuccess(BuildContext context, CheckoutProvider provider) {
    // Keep dialog open to show success screen
    // No action needed - CheckoutSuccess will be displayed by nextStep
    provider.nextStep();
  }

  void _handleClose() {
    // Close modal WITHOUT calling onComplete (user cancelled checkout)
    Navigator.pop(context);
  }

  void _handleCheckoutComplete() {
    // Close modal AND call onComplete callback (checkout was successful)
    Navigator.pop(context);
    widget.onClose?.call();
  }
}

/// Three-segment progress rail: completed segments carry the brand gradient,
/// pending ones stay a translucent white pill.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Delivery', 'Review', 'Payment'];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.curve,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: i <= currentStep ? AppColors.brandGradientH : null,
                    color: i <= currentStep ? null : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i].toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: i <= currentStep ? AppColors.dustyRose : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Show checkout dialog as modal
void showCheckoutModal(
  BuildContext context, {
  List<Address>? addresses,
  List<CartItem>? selectedItems,
  VoidCallback? onComplete,
  int? buyNowProductId,
  int? buyNowVariantId,
  int buyNowQuantity = 1,
  String? initialDeliveryDate,
  String? initialDeliveryTime,
  int? initialStoreId,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => CheckoutModal(
      addresses: addresses,
      selectedItems: selectedItems,
      onClose: onComplete,
      buyNowProductId: buyNowProductId,
      buyNowVariantId: buyNowVariantId,
      buyNowQuantity: buyNowQuantity,
      initialDeliveryDate: initialDeliveryDate,
      initialDeliveryTime: initialDeliveryTime,
      initialStoreId: initialStoreId,
    ),
  );
}
