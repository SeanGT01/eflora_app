// lib/screens/seller/payment_verification_screen.dart
// Seller dashboard for verifying customer GCash payment proofs

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() => _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  String filterStatus = 'pending_verification'; // pending, verified, pending_verification
  bool isLoading = false;
  List<Map<String, dynamic>> payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => isLoading = true);
    // TODO: Call API endpoint to load payments
    // final result = await ApiService.getSellerPaymentProofs(filterStatus);
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Payment Verification'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _filterChip('Pending', 'pending_verification'),
                const SizedBox(width: 12),
                _filterChip('Verified', 'verified'),
              ],
            ),
          ),
          // Payments list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.deepRose))
                : payments.isEmpty
                    ? _buildEmpty(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        itemBuilder: (_, i) => _PaymentProofCard(
                          payment: payments[i],
                          onVerify: () => _handleVerify(payments[i]),
                          onReject: () => _handleReject(payments[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String status) {
    final isActive = filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (value) {
        if (value) {
          setState(() => filterStatus = status);
          _loadPayments();
        }
      },
      backgroundColor: AppColors.warmWhite,
      selectedColor: AppColors.deepRose.withOpacity(0.2),
      labelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        color: isActive ? AppColors.deepRose : AppColors.charcoal,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.muted.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No pending payments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            'Verified payments will appear here',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerify(Map<String, dynamic> payment) async {
    // TODO: Call API to verify payment
    showToast(context, 'Payment verified!');
    _loadPayments();
  }

  Future<void> _handleReject(Map<String, dynamic> payment) async {
    // Show rejection reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectionReasonDialog(),
    );
    if (reason != null) {
      // TODO: Call API to reject with reason
      showToast(context, 'Payment rejected');
      _loadPayments();
    }
  }
}

// ── Payment Proof Card ────────────────────────────────────────────────────
class _PaymentProofCard extends StatefulWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const _PaymentProofCard({
    required this.payment,
    required this.onVerify,
    required this.onReject,
  });

  @override
  State<_PaymentProofCard> createState() => _PaymentProofCardState();
}

class _PaymentProofCardState extends State<_PaymentProofCard> {
  bool _expandedItems = false;

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final customer = payment['customer_name'] ?? 'Unknown';
    final amount = payment['amount'] ?? 0.0;
    final itemsCount = payment['items_count'] ?? 0;
    final proofUrl = payment['payment_proof_url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with customer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, color: AppColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${payment['order_id']}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        customer,
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Order items summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$itemsCount Item${itemsCount != 1 ? 's' : ''}',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _expandedItems = !_expandedItems),
                      child: Icon(
                        _expandedItems ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (_expandedItems && payment['items'] != null) ...[
                  const SizedBox(height: 12),
                  ...(payment['items'] as List).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['product_name'] ?? 'Product',
                                  style: GoogleFonts.dmSans(fontSize: 11),
                                ),
                                if (item['variant_name'] != null)
                                  Text(
                                    item['variant_name'],
                                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                                  ),
                                if ((item['addons'] as List?)?.isNotEmpty == true)
                                  ...((item['addons'] as List).map((raw) {
                                    final a = raw is Map
                                        ? Map<String, dynamic>.from(raw)
                                        : <String, dynamic>{};
                                    final name = (a['name'] ?? 'Add-on').toString();
                                    final q = (a['quantity'] as num?)?.toInt() ?? 1;
                                    return Text(
                                      '+ $name${q > 1 ? ' ×$q' : ''}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    );
                                  })),
                              ],
                            ),
                          ),
                          Text(
                            '×${item['quantity']} ₱${((item['subtotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Payment proof image
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Proof',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: proofUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: proofUrl,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.border,
                              child: const Icon(Icons.image_not_supported, color: AppColors.muted),
                            ),
                          ),
                        )
                      : const Icon(Icons.image_outlined, color: AppColors.muted, size: 48),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.dmSans(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                    ),
                    onPressed: widget.onVerify,
                    child: Text(
                      'Verify Payment',
                      style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rejection Reason Dialog ────────────────────────────────────────────────
class _RejectionReasonDialog extends StatefulWidget {
  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reason for rejection:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'E.g., Amount does not match, blurry image, etc.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Reject', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Payment Dashboard Widget ────────────────────────────────────────────────
class PaymentSummaryCard extends StatelessWidget {
  final int pendingCount;
  final int verifiedCount;
  final double totalVerifiedAmount;

  const PaymentSummaryCard({
    super.key,
    required this.pendingCount,
    required this.verifiedCount,
    required this.totalVerifiedAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCard(
            label: 'Pending',
            value: '$pendingCount',
            color: Colors.orange,
          ),
          _StatCard(
            label: 'Verified',
            value: '$verifiedCount',
            color: Colors.green,
          ),
          _StatCard(
            label: 'Total',
            value: '₱${totalVerifiedAmount.toStringAsFixed(0)}',
            color: AppColors.deepRose,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
