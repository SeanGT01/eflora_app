import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/chat_drawer.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'delivery_tracking_screen.dart' show DeliveryTrackingScreen, DeliveryProofDialog;

class OrderDetailScreen extends StatelessWidget {
  final RiderOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = order.createdAt != null
        ? DateFormat('MMMM d, yyyy  h:mm a').format(order.createdAt!)
        : '';
    final itemsSubtotal = order.items.fold<double>(0, (s, i) => s + i.lineTotal);
    final hasAddons = order.items.any((i) => i.addons.isNotEmpty || i.addonsTotal > 0);
    final subtotalToUse = (hasAddons && itemsSubtotal > 0)
        ? itemsSubtotal
        : (itemsSubtotal > order.subtotalAmount + 0.009
            ? itemsSubtotal
            : order.subtotalAmount);
    final computedTotal = subtotalToUse + order.deliveryFee;
    final totalToShow = (hasAddons || order.totalAmount <= 0 ||
            (order.totalAmount - computedTotal).abs() > 0.05)
        ? computedTotal
        : order.totalAmount;
    
    // Format requested delivery date and time
    final requestedDeliveryStr = _formatRequestedDelivery(
      order.requestedDeliveryDate,
      order.requestedDeliveryTime,
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: order.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: order.statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    order.status == 'accepted' || order.status == 'done_preparing'
                        ? Icons.local_florist
                        : order.status == 'on_delivery'
                            ? Icons.delivery_dining
                            : Icons.check_circle,
                    color: order.statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.statusLabel,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: order.statusColor,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Customer Info ──
            const _SectionTitle(title: 'Customer'),
            const SizedBox(height: 8),
            _DetailCard(children: [
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Name',
                value: order.customerName ?? 'N/A',
              ),
              if ((order.customerContact ?? order.customerPhone) != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DetailRow(
                        icon: Icons.phone_outlined,
                        label: order.customerTel != null ? 'Phone' : 'Contact',
                        value: order.customerPhone ?? order.customerContact ?? '',
                      ),
                    ),
                    if (order.customerTel != null ||
                        (order.customerPhone ?? '').startsWith('09'))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Material(
                          color: AppColors.deepRose,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _callCustomer(context, order),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.phone, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openOrderChat(context),
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text('Message Customer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepRose,
                      side: BorderSide(
                        color: AppColors.deepRose.withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Delivery Info ──
            const _SectionTitle(title: 'Delivery'),
            const SizedBox(height: 8),
            _DetailCard(children: [
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: order.deliveryAddress ?? 'Not provided',
              ),
              if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty) ...[
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.note_outlined,
                  label: 'Notes',
                  value: order.deliveryNotes!,
                ),
              ],
              if (order.requestedDeliveryDate != null) ...[
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Requested Delivery',
                  value: requestedDeliveryStr.isNotEmpty 
                      ? requestedDeliveryStr 
                      : order.requestedDeliveryDate!,
                ),
              ],
              if (order.requestedDeliveryTime != null && order.requestedDeliveryDate == null) ...[
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Requested Time',
                  value: _formatTimeRange(order.requestedDeliveryTime!),
                ),
              ],
              if (order.distanceFromStoreKm != null) ...[
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${order.distanceFromStoreKm!.toStringAsFixed(1)} km',
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Order Items ──
            _SectionTitle(title: 'Items (${order.items.length})'),
            const SizedBox(height: 8),
            _DetailCard(
              children: [
                ...order.items.map((item) => _OrderItemRow(item: item)),
                const Divider(height: 20),
                _PriceRow(label: 'Subtotal', amount: subtotalToUse),
                const SizedBox(height: 4),
                _PriceRow(label: 'Delivery Fee', amount: order.deliveryFee),
                const Divider(height: 16),
                _PriceRow(
                  label: 'Total',
                  amount: totalToShow,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Payment ──
            const _SectionTitle(title: 'Payment'),
            const SizedBox(height: 8),
            _DetailCard(children: [
              _DetailRow(
                icon: Icons.payment,
                label: 'Method',
                value: (order.paymentMethod ?? 'N/A').toUpperCase(),
              ),
              const Divider(height: 20),
              _DetailRow(
                icon: Icons.info_outline,
                label: 'Status',
                value: (order.paymentStatus ?? 'pending').toUpperCase(),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Seller fulfillment photo (when seller marked ready) ──
            if (order.donePreparingProofUrl != null &&
                order.donePreparingProofUrl!.isNotEmpty) ...[
              const _SectionTitle(title: 'Seller fulfillment'),
              const SizedBox(height: 8),
              _DetailCard(children: [
                Text(
                  'Finished product photo / Plant photo',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showDeliveryProofZoom(context, order.donePreparingProofUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: AppColors.cream,
                      child: CachedNetworkImage(
                        imageUrl: order.donePreparingProofUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.deepRose,
                          ),
                        ),
                        errorWidget: (_, url, error) => Container(
                          color: AppColors.warmWhite,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 32,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
            ],

            // ── Delivery Proof (if delivered) ──
            if (order.status == 'delivered' && 
                (order.deliveryProofUrl != null || order.deliveryProof2Url != null)) ...[
              const _SectionTitle(title: 'Delivery Proof'),
              const SizedBox(height: 8),
              _DetailCard(children: [
                Row(
                  children: [
                    if (order.deliveryProofUrl != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showDeliveryProofZoom(context, order.deliveryProofUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 100,
                              color: AppColors.cream,
                              child: CachedNetworkImage(
                                imageUrl: order.deliveryProofUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.deepRose,
                                  ),
                                ),
                                errorWidget: (_, url, error) => Container(
                                  color: AppColors.warmWhite,
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported_outlined, 
                                      size: 24, color: AppColors.muted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (order.deliveryProofUrl != null && order.deliveryProof2Url != null)
                      const SizedBox(width: 8),
                    if (order.deliveryProof2Url != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showDeliveryProofZoom(context, order.deliveryProof2Url!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 100,
                              color: AppColors.cream,
                              child: CachedNetworkImage(
                                imageUrl: order.deliveryProof2Url!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.deepRose,
                                  ),
                                ),
                                errorWidget: (_, url, error) => Container(
                                  color: AppColors.warmWhite,
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported_outlined, 
                                      size: 24, color: AppColors.muted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
            ],

            // ── Action Buttons ──
            if (order.status == 'accepted' || order.status == 'done_preparing')
              _AcceptButton(orderId: order.id),
            if (order.status == 'on_delivery') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryTrackingScreen(order: order),
                    ),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Track on Map'),
                ),
              ),
              const SizedBox(height: 12),
              _DeliveredButton(orderId: order.id),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Format time range from 24-hour format (e.g., "08:00-12:00") to 12-hour format (e.g., "8:00am-12:00pm")
  String _formatTimeRange(String timeStr) {
    try {
      final parts = timeStr.split('-');
      if (parts.length != 2) return timeStr;
      
      final startTime = DateFormat('H:mm').parse(parts[0].trim());
      final endTime = DateFormat('H:mm').parse(parts[1].trim());
      
      final startFormatted = DateFormat('h:mma').format(startTime).toLowerCase();
      final endFormatted = DateFormat('h:mma').format(endTime).toLowerCase();
      
      return '$startFormatted-$endFormatted';
    } catch (e) {
      return timeStr;
    }
  }

  /// Format requested delivery date and time together
  /// Returns format like: "Apr 02,2026, 6:00am-8:00am"
  String _formatRequestedDelivery(String? date, String? time) {
    if (date == null || date.isEmpty) return '';
    
    try {
      // Parse date (expected format: YYYY-MM-DD)
      final deliveryDate = DateFormat('yyyy-MM-dd').parse(date);
      final dateFormatted = DateFormat('MMM dd,yyyy').format(deliveryDate);
      
      // Format time
      final timeFormatted = time != null && time.isNotEmpty 
          ? _formatTimeRange(time) 
          : '';
      
      return timeFormatted.isNotEmpty 
          ? '$dateFormatted, $timeFormatted' 
          : dateFormatted;
    } catch (e) {
      return date;
    }
  }

  void _showDeliveryProofZoom(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = size.width - 48;
        final maxH = size.height * 0.82;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxW,
                          maxHeight: maxH,
                        ),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox(
                              width: 120,
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.deepRose,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 200,
                              padding: const EdgeInsets.all(24),
                              color: Colors.black26,
                              child: Text(
                                'Unable to load image',
                                style: GoogleFonts.dmSans(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(ctx),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.close_rounded, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _callCustomer(BuildContext context, RiderOrder order) async {
    final tel = order.customerTel ??
        (order.customerPhone != null && order.customerPhone!.startsWith('09')
            ? 'tel:+63${order.customerPhone!.substring(1)}'
            : null);
    if (tel == null) return;
    final uri = Uri.parse(tel);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      showToast(context, 'Could not start a phone call', isError: true);
    }
  }

  Future<void> _openOrderChat(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => Material(
          color: Colors.transparent,
          child: ChatDrawer(
            onClose: () => Navigator.of(ctx).pop(),
            openStoreId: order.storeId,
            openCustomerId: order.customerId,
            openOrderId: order.id,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted.withOpacity(0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final RiderOrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              color: AppColors.cream,
              child: item.imageUrl != null
                  ? Image.network(
                      ApiService.assetUrl(item.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.local_florist, color: AppColors.dustyRose),
                    )
                  : const Icon(Icons.local_florist, color: AppColors.dustyRose),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                if (item.addons.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...item.addons.map((a) {
                    final name = (a['name'] ?? 'Add-on').toString();
                    final q = (a['quantity'] as num?)?.toInt() ?? 1;
                    final rawImg = (a['image_url'] ?? a['image'] ?? '').toString().trim();
                    final imgUrl = rawImg.isEmpty ? null : ApiService.assetUrl(rawImg);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              width: 22,
                              height: 22,
                              color: AppColors.cream,
                              child: imgUrl != null
                                  ? Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.local_florist,
                                        size: 12,
                                        color: AppColors.dustyRose,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.local_florist,
                                      size: 12,
                                      color: AppColors.dustyRose,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '+ $name${q > 1 ? ' ×$q' : ''}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '×${item.quantity}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Text(
                '₱${item.lineTotal.toStringAsFixed(2)}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _PriceRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: bold ? 14 : 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppColors.charcoal : AppColors.muted,
          ),
        ),
        Text(
          '₱${amount.toStringAsFixed(2)}',
          style: GoogleFonts.dmSans(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

class _AcceptButton extends StatefulWidget {
  final int orderId;
  const _AcceptButton({required this.orderId});
  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    final ok = await context.read<RiderProvider>().acceptOrder(widget.orderId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      showToast(context, 'Order accepted! Starting delivery.');
      Navigator.pop(context);
    } else {
      showToast(context, 'Failed to accept order', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _accept,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(_loading ? 'Accepting...' : 'Accept & Start Delivery'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _DeliveredButton extends StatefulWidget {
  final int orderId;
  const _DeliveredButton({required this.orderId});
  @override
  State<_DeliveredButton> createState() => _DeliveredButtonState();
}

class _DeliveredButtonState extends State<_DeliveredButton> {
  bool _loading = false;

  Future<void> _markDelivered() async {
    // Show the delivery proof modal
    final imagePaths = await showDialog<Map<int, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryProofDialog(orderId: widget.orderId),
    );

    if (imagePaths == null || !mounted) return;

    // Both images captured, show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delivery',
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Proofs captured successfully!', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Mark this order as delivered?', style: GoogleFonts.dmSans()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final ok = await context.read<RiderProvider>().markDelivered(
      widget.orderId,
      deliveryProofPath1: imagePaths[1],
      deliveryProofPath2: imagePaths[2],
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      showToast(context, 'Order marked as delivered!');
      Navigator.pop(context);
    } else {
      showToast(context, 'Failed to update status', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _markDelivered,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(_loading ? 'Uploading proofs...' : 'Mark as Delivered'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.successGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

