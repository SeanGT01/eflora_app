import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/checkout.dart';
import '../../providers/address_provider.dart';
import '../../theme/app_theme.dart';
import 'add_edit_address_screen.dart';

class AddressListScreen extends StatelessWidget {
  final bool isCheckoutSelection;
  final Function(Address)? onAddressSelected;

  const AddressListScreen({
    super.key,
    this.isCheckoutSelection = false,
    this.onAddressSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: Consumer<AddressProvider>(
        builder: (context, addressProvider, _) {
          return RefreshIndicator(
            color: AppColors.deepRose,
            onRefresh: () => addressProvider.loadAddresses(),
            child: addressProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.deepRose),
                  )
                : addressProvider.error != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64, height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.deepRose.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.deepRose),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Something went wrong',
                                      style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      addressProvider.error!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => addressProvider.loadAddresses(),
                                      icon: const Icon(Icons.refresh_rounded, size: 18),
                                      label: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : addressProvider.addresses.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: _buildEmptyState(context),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: addressProvider.addresses.length,
                            itemBuilder: (context, index) {
                              final address = addressProvider.addresses[index];
                              return _buildAddressCard(
                                context,
                                addressProvider,
                                address,
                                isCheckoutSelection,
                                onAddressSelected,
                              );
                            },
                          ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<Address>(
            MaterialPageRoute(
              builder: (context) => const AddEditAddressScreen(),
            ),
          );
          if (result != null && onAddressSelected != null && isCheckoutSelection) {
            onAddressSelected!(result);
          }
        },
        backgroundColor: AppColors.deepRose,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.deepRose.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.location_off_rounded, size: 40, color: AppColors.dustyRose),
            ),
            const SizedBox(height: 20),
            Text(
              'No addresses yet',
              style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.charcoal),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first delivery address\nto get started',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<Address>(
                  MaterialPageRoute(
                    builder: (context) => const AddEditAddressScreen(),
                  ),
                );
                if (result != null && onAddressSelected != null && isCheckoutSelection) {
                  onAddressSelected!(result);
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Address'),
            ),
          ],
        ),
      ),
    );
  }

  Color _labelColor(String label) {
    switch (label) {
      case 'Home': return AppColors.deepRose;
      case 'Work': return AppColors.sage;
      default: return AppColors.muted;
    }
  }

  IconData _labelIcon(String label) {
    switch (label) {
      case 'Home': return Icons.home_rounded;
      case 'Work': return Icons.work_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  Widget _buildAddressCard(
    BuildContext context,
    AddressProvider addressProvider,
    Address address,
    bool isCheckoutSelection,
    Function(Address)? onAddressSelected,
  ) {
    final color = _labelColor(address.addressLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isCheckoutSelection
            ? () {
                addressProvider.selectAddress(address);
                onAddressSelected?.call(address);
                Navigator.of(context).pop(address);
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: address.isDefault ? AppColors.deepRose.withOpacity(0.3) : AppColors.border,
              width: address.isDefault ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_labelIcon(address.addressLabel), size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            address.addressLabel,
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 11.5, color: color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Default',
                          style: GoogleFonts.dmSans(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.muted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, size: 18, color: AppColors.charcoal),
                              const SizedBox(width: 10),
                              Text('Edit', style: GoogleFonts.dmSans(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (!address.isDefault)
                          PopupMenuItem(
                            value: 'setDefault',
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.sage),
                                const SizedBox(width: 10),
                                Text('Set as Default', style: GoogleFonts.dmSans(fontSize: 13)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                              const SizedBox(width: 10),
                              Text('Delete', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red.shade400)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await Navigator.of(context).push<Address>(
                              MaterialPageRoute(
                                builder: (context) => AddEditAddressScreen(address: address),
                              ),
                            );
                            break;
                          case 'setDefault':
                            await addressProvider.setDefaultAddress(address.id!);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Default address updated')),
                            );
                            break;
                          case 'delete':
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text('Delete Address',
                                    style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w600)),
                                content: Text('Are you sure you want to delete this address?',
                                    style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.muted)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancel', style: GoogleFonts.dmSans(color: AppColors.muted)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await addressProvider.deleteAddress(address.id!);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Address deleted')),
                                      );
                                    },
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: Text('Delete', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            );
                            break;
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  address.addressLine,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.charcoal),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address.municipality}, ${address.barangay}',
                  style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12.5),
                ),
                if (address.street != null && address.street!.isNotEmpty)
                  Text(
                    address.street!,
                    style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12.5),
                  ),
                if (address.buildingDetails != null && address.buildingDetails!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address.buildingDetails!,
                    style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
