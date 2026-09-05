import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checkout.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/delivery_unavailable_dialog.dart';
import '../../widgets/active_order_limit_dialog.dart';
import '../address/address_list_screen.dart';

class CheckoutStep1 extends StatefulWidget {
  final VoidCallback onNext;

  const CheckoutStep1({
    super.key,
    required this.onNext,
  });

  @override
  State<CheckoutStep1> createState() => _CheckoutStep1State();
}

class _CheckoutStep1State extends State<CheckoutStep1> {
  final TextEditingController _notesController = TextEditingController();
  bool _didRequestAddresses = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final addressProvider = context.read<AddressProvider>();
      if (!_didRequestAddresses &&
          addressProvider.addresses.isEmpty &&
          !addressProvider.isLoading) {
        _didRequestAddresses = true;
        addressProvider.loadAddresses();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// DropdownButton requires the value to be an instance from [items].
  Address? _resolveDropdownAddress(
    CheckoutProvider checkoutProvider,
    AddressProvider addressProvider,
  ) {
    final preferred =
        checkoutProvider.selectedAddress ?? addressProvider.selectedAddress;
    if (preferred == null || addressProvider.addresses.isEmpty) return null;

    for (final address in addressProvider.addresses) {
      if (preferred.id != null && address.id == preferred.id) return address;
      if (identical(address, preferred)) return address;
    }
    return null;
  }

  void _syncCheckoutAddress(
    CheckoutProvider checkoutProvider,
    AddressProvider addressProvider,
  ) {
    if (addressProvider.isLoading || addressProvider.addresses.isEmpty) return;

    final resolved = _resolveDropdownAddress(checkoutProvider, addressProvider);
    if (resolved != null) {
      if (checkoutProvider.selectedAddress == null) {
        checkoutProvider.initializeSelectedAddress(resolved);
      }
      return;
    }

    // Selected address is missing from the list (stale after reload).
    final fallback =
        addressProvider.selectedAddress ?? addressProvider.addresses.first;
    checkoutProvider.setSelectedAddress(fallback);
  }

  @override
  Widget build(BuildContext context) {
    final addressProvider = context.watch<AddressProvider>();

    return Consumer<CheckoutProvider>(
      builder: (context, checkoutProvider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncCheckoutAddress(checkoutProvider, addressProvider);
        });

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
                          checkoutProvider.error!,
                          icon: Icons.warning_amber_rounded,
                          tint: AppColors.error,
                        ),
                      ),
                    _buildAddressSection(context, checkoutProvider, addressProvider),
                    const SizedBox(height: 16),
                    _buildNotesSection(context, checkoutProvider),
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: 'Continue',
                        loading: checkoutProvider.isProcessing,
                        onPressed: checkoutProvider.isProcessing
                            ? null
                            : () => _proceedToStep2(context, checkoutProvider),
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

  Widget _buildAddressSection(
    BuildContext context,
    CheckoutProvider provider,
    AddressProvider addressProvider,
  ) {
    return _buildSectionCard(
      context,
      title: 'Address',
      trailing: TextButton(
        onPressed: () => _openAddressPicker(context, provider),
        child: const Text('Change'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addressProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.roseCta),
              ),
            )
          else if (addressProvider.error != null &&
              addressProvider.addresses.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageCard(
                  context,
                  'Error loading addresses: ${addressProvider.error}',
                  icon: Icons.error_outline,
                  tint: AppColors.error,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  height: 46,
                  onPressed: () => addressProvider.loadAddresses(),
                ),
              ],
            )
          else if (addressProvider.addresses.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No addresses available yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Add address',
                  icon: Icons.add_location_alt_outlined,
                  height: 46,
                  onPressed: () => _openAddressPicker(context, provider),
                ),
              ],
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.glassBorder, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Address>(
                  isExpanded: true,
                  value: _resolveDropdownAddress(provider, addressProvider),
                  hint: Text(
                    'Select delivery address',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: addressProvider.addresses.map((address) {
                    return DropdownMenuItem<Address>(
                      value: address,
                      child: Text(
                        '${address.addressLabel} - ${address.barangay}, ${address.municipality}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    );
                  }).toList(),
                  onChanged: (address) {
                    if (address != null) {
                      provider.setSelectedAddress(address);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_resolveDropdownAddress(provider, addressProvider) != null)
              _buildAddressPreview(
                context,
                _resolveDropdownAddress(provider, addressProvider)!,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, CheckoutProvider provider) {
    return _buildSectionCard(
      context,
      title: 'Notes',
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'Optional — gate code, landmark…',
        ),
        onChanged: (value) => provider.setDeliveryNotes(value),
      ),
    );
  }

  Future<void> _openAddressPicker(
    BuildContext context,
    CheckoutProvider provider,
  ) async {
    final result = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (context) => const AddressListScreen(
          isCheckoutSelection: true,
        ),
      ),
    );

    if (result != null) {
      provider.setSelectedAddress(result);
    }
  }

  void _proceedToStep2(BuildContext context, CheckoutProvider provider) async {
    final selectedItems = context.read<CartProvider>().selectedItems;
    final success = await provider.validateCheckout(
      items: selectedItems
          .map((item) => {
                'item_id': item.id,
                'quantity': item.quantity,
              })
          .toList(),
    );
    if (!context.mounted) return;
    if (success) {
      widget.onNext();
      return;
    }

    final error = provider.error ?? 'Validation failed';
    final warnings = provider.validationResponse?.warnings;
    if (isActiveOrderLimitResult(
      message: error,
      data: provider.validationResponse,
    )) {
      await showActiveOrderLimitDialogFromPayload(
        context,
        data: provider.validationResponse,
      );
    } else if (isDeliveryUnavailableError(error) ||
        (warnings != null && warnings.isNotEmpty)) {
      await showCheckoutDeliveryUnavailableDialog(
        context,
        reason: error,
        storeDetails: warnings,
      );
    } else {
      showToast(context, error, isError: true);
    }
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
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
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
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

  Widget _buildAddressPreview(BuildContext context, Address address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.roseCta.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorderActive, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address.addressLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppColors.badgeGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Default',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(address.addressLine, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
