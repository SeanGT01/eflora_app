import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/checkout.dart';
import '../../providers/address_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import 'add_edit_address_screen.dart';

class AddressListScreen extends StatelessWidget {
  final bool isCheckoutSelection;
  final Function(Address)? onAddressSelected;

  const AddressListScreen({
    super.key,
    this.isCheckoutSelection = false,
    this.onAddressSelected,
  });

  Future<void> _openAdd(BuildContext context) async {
    final result = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => const AddEditAddressScreen()),
    );
    if (result != null && isCheckoutSelection && onAddressSelected != null) {
      onAddressSelected!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AppBackground(
      showFlowers: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            isCheckoutSelection ? 'Select Address' : 'My Addresses',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        body: Consumer<AddressProvider>(
          builder: (context, addressProvider, _) {
            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.deepRose,
                    backgroundColor: AppColors.warmWhite,
                    onRefresh: () => addressProvider.loadAddresses(),
                    child: addressProvider.isLoading
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 180),
                              Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.deepRose,
                                ),
                              ),
                            ],
                          )
                        : addressProvider.error != null
                            ? _ErrorState(
                                message: addressProvider.error!,
                                onRetry: () => addressProvider.loadAddresses(),
                              )
                            : addressProvider.addresses.isEmpty
                                ? _EmptyState(onAdd: () => _openAdd(context))
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    itemCount: addressProvider.addresses.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final address =
                                          addressProvider.addresses[index];
                                      return _AddressCard(
                                        address: address,
                                        isCheckoutSelection:
                                            isCheckoutSelection,
                                        onSelect: isCheckoutSelection
                                            ? () {
                                                addressProvider
                                                    .selectAddress(address);
                                                onAddressSelected
                                                    ?.call(address);
                                                Navigator.of(context)
                                                    .pop(address);
                                              }
                                            : null,
                                        onEdit: () async {
                                          await Navigator.of(context)
                                              .push<Address>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AddEditAddressScreen(
                                                address: address,
                                              ),
                                            ),
                                          );
                                        },
                                        onSetDefault: address.isDefault
                                            ? null
                                            : () async {
                                                await addressProvider
                                                    .setDefaultAddress(
                                                        address.id!);
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                        'Default address updated'),
                                                    backgroundColor:
                                                        AppColors.successGreen,
                                                  ),
                                                );
                                              },
                                        onDelete: () => _confirmDelete(
                                          context,
                                          addressProvider,
                                          address,
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ),
                _BottomAddBar(
                  bottomInset: bottomInset,
                  label: isCheckoutSelection
                      ? 'Add new address'
                      : 'Add address',
                  onPressed: () => _openAdd(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AddressProvider addressProvider,
    Address address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Delete address?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        content: Text(
          'This delivery address will be removed from your account.',
          style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await addressProvider.deleteAddress(address.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address deleted'),
        backgroundColor: AppColors.charcoal,
      ),
    );
  }
}

class _BottomAddBar extends StatelessWidget {
  const _BottomAddBar({
    required this.bottomInset,
    required this.label,
    required this.onPressed,
  });

  final double bottomInset;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.warmWhite.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: GradientButton(
        label: label,
        icon: Icons.add_location_alt_rounded,
        onPressed: onPressed,
        radius: AppRadius.md,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.blushGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppShadows.petal,
                    ),
                    child: const Icon(
                      Icons.place_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'No addresses yet',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save a delivery pin so checkout\nis faster next time.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: AppColors.muted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 200,
                    child: GradientButton(
                      label: 'Add address',
                      icon: Icons.add_rounded,
                      onPressed: onAdd,
                      radius: AppRadius.md,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.deepRose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 34,
                      color: AppColors.deepRose,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Something went wrong',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    child: GradientButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                      radius: AppRadius.md,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isCheckoutSelection,
    required this.onEdit,
    required this.onDelete,
    this.onSelect,
    this.onSetDefault,
  });

  final Address address;
  final bool isCheckoutSelection;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  IconData get _labelIcon {
    switch (address.addressLabel) {
      case 'Home':
        return Icons.home_rounded;
      case 'Work':
        return Icons.work_rounded;
      default:
        return Icons.bookmark_rounded;
    }
  }

  String get _primaryLine {
    final parts = <String>[];
    if ((address.buildingDetails ?? '').trim().isNotEmpty) {
      parts.add(address.buildingDetails!.trim());
    }
    if ((address.street ?? '').trim().isNotEmpty) {
      parts.add(address.street!.trim());
    }
    if (parts.isEmpty && address.addressLine.trim().isNotEmpty) {
      return address.addressLine.trim();
    }
    return parts.join(', ');
  }

  String get _areaLine =>
      'Brgy. ${address.barangay}, ${address.municipality}, Laguna';

  @override
  Widget build(BuildContext context) {
    final isDefault = address.isDefault;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          tinted: isDefault,
          radius: AppRadius.lg,
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          borderColor: isDefault
              ? AppColors.glassBorderActive
              : AppColors.glassBorder,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isDefault ? AppColors.brandGradient : null,
                  color: isDefault
                      ? null
                      : AppColors.deepRose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _labelIcon,
                  size: 22,
                  color: isDefault ? Colors.white : AppColors.deepRose,
                ),
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
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.badgeGradient,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: GoogleFonts.dmSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _primaryLine.isNotEmpty
                          ? _primaryLine
                          : 'No street details',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _areaLine,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    if (isCheckoutSelection) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Tap to deliver here',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepRose,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCheckoutSelection)
                const Padding(
                  padding: EdgeInsets.only(top: 10, right: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  color: AppColors.warmWhite,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'default':
                        onSetDefault?.call();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: _menuRow(Icons.edit_rounded, 'Edit', AppColors.charcoal),
                    ),
                    if (onSetDefault != null)
                      PopupMenuItem(
                        value: 'default',
                        child: _menuRow(
                          Icons.check_circle_outline_rounded,
                          'Set as default',
                          AppColors.sage,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _menuRow(
                        Icons.delete_outline_rounded,
                        'Delete',
                        AppColors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
