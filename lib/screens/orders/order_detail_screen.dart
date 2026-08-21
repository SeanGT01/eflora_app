import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/chat_drawer.dart';
import '../../widgets/cancel_order_reason_sheet.dart';
import '../product/product_detail_screen.dart';

/// Pill badge using the web's per-status fill / text / border trio.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Rose bloom over the pink/lavender wash, matching the web's empty thumbnails.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.iconSize = 28});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Icon(Icons.local_florist,
            size: iconSize, color: const Color(0x33B5445A)),
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  Map<int, int> _existingRatings = {};
  bool _storeRated = false;
  bool _ratingsLoaded = false;
  bool _buyAgainBusy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadLatestOrder();
    final s = _order.status;
    if (s == 'delivered' || s == 'completed') _loadExistingRatings();
  }

  Future<void> _loadLatestOrder() async {
    final res = await ApiService.getOrder(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      setState(() {
        _order = Order.fromJson(res.data as Map<String, dynamic>);
      });
    }
  }

  Future<void> _loadExistingRatings() async {
    final res = await ApiService.getOrderRatings(widget.order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      final map = res.data!['ratings'] as Map<String, dynamic>? ?? {};
      final store = res.data!['store_rating'];
      setState(() {
        _existingRatings = map.map(
            (k, v) => MapEntry(int.parse(k), (v['rating'] as num).toInt()));
        _storeRated = store != null;
        _ratingsLoaded = true;
      });
    }
  }

  bool get _allRated =>
      _ratingsLoaded &&
      _storeRated &&
      _order.items.every((i) => _existingRatings.containsKey(i.id));

  Future<void> _buyAgain() async {
    if (_buyAgainBusy) return;
    setState(() => _buyAgainBusy = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Adding items to cart…')),
    );

    try {
      final res = await ApiService.getOrder(_order.id);
      if (!mounted) return;

      List<OrderItem> items = _order.items;
      if (res.isSuccess && res.data is Map) {
        final parsed =
            Order.fromJson(Map<String, dynamic>.from(res.data as Map));
        if (parsed.items.isNotEmpty) items = parsed.items;
      }

      if (items.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('No items found in this order.')),
        );
        return;
      }

      final cart = context.read<CartProvider>();
      var added = 0;
      var skipped = 0;

      for (final item in items) {
        if (item.productId <= 0) {
          skipped++;
          continue;
        }
        final err = await cart.addItem(
          item.productId,
          qty: 1,
          variantId: item.variantId,
          addonOptionIds: item.reorderAddonOptionIds.isEmpty
              ? null
              : item.reorderAddonOptionIds,
        );
        if (err == null) {
          added++;
        } else {
          skipped++;
        }
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (added > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$added item${added == 1 ? '' : 's'} added to cart'
              '${skipped > 0 ? ' ($skipped out of stock)' : ''}',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('All items are out of stock.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to reorder. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _buyAgainBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final dateStr = order.createdAt != null
        ? DateFormat('MMMM dd, yyyy · hh:mm a')
            .format(_toPhilippineTime(order.createdAt!))
        : '—';
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

    return AppBackground(
      flowerCount: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              GlassCard(
                radius: AppRadius.xl,
                tinted: true,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Order #${order.id.toString().padLeft(6, '0')}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: order.statusLabel,
                          background: order.statusBackgroundColor,
                          foreground: order.statusColor,
                          borderColor: order.statusBorderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: AppColors.muted),
                    ),
                    if (order.storeName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storefront_outlined,
                                size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.storeName!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.labelPink,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (order.status == 'cancelled' &&
                  (order.cancellationReason?.trim().isNotEmpty ?? false)) ...[
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  radius: AppRadius.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancellation reason',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.cancellationReason!,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Order Items
              const GlassSectionTitle(
                  eyebrow: 'Your bouquet', title: 'Order Items'),
              const SizedBox(height: 12),
              GlassCard(
                padding: EdgeInsets.zero,
                radius: AppRadius.xl,
                child: Column(
                  children: order.items.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                    productId: item.productId),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Product Image
                                _buildOrderItemImage(item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.charcoal,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.variantName != null &&
                                          item.variantName!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Variant: ${item.variantName}',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.deepRose,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 8),
                                      _OrderItemPriceBreakdown(item: item),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i < order.items.length - 1)
                          const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                              color: AppColors.glassBorder),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Order Summary
              GlassCard(
                padding: const EdgeInsets.all(18),
                radius: AppRadius.xl,
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Subtotal',
                      value: '₱${subtotalToUse.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Delivery Fee',
                      value: '₱${order.deliveryFee.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Discount',
                      value: '—',
                      valueColor: AppColors.muted,
                    ),
                    const Divider(height: 16, color: AppColors.glassBorder),
                    _SummaryRow(
                      label: 'Total Amount',
                      value: '₱${totalToShow.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Rider Info (if available)
              if (order.riderName != null) ...[
                const GlassSectionTitle(
                    eyebrow: 'On its way', title: 'Delivery'),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  radius: AppRadius.xl,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                order.riderName!.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rider',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11, color: AppColors.muted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order.riderName!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.directions_bike_outlined,
                              color: AppColors.sage, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openRiderChat(context, order),
                          icon: const Icon(Icons.message_outlined, size: 18),
                          label: const Text('Chat with rider'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepRose,
                            side: BorderSide(
                              color: AppColors.deepRose.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Status Timeline
              const GlassSectionTitle(
                  eyebrow: 'Track progress', title: 'Order Status'),
              const SizedBox(height: 10),
              _buildStatusTimeline(
                  order.status,
                  order.paymentProofUrl,
                  order.deliveryProofUrl,
                  order.deliveryProof2Url,
                  order.donePreparingProofUrl,
                  context),
              const SizedBox(height: 20),

              // Rate order (delivered or completed, hidden once store + products rated)
              if (order.status == 'delivered') ...[
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border:
                        Border.all(color: AppColors.glassBorder, width: 1.5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _markOrderAsCompleted,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 18, color: AppColors.deepSage),
                            const SizedBox(width: 8),
                            Text(
                              'Mark as completed',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ((order.status == 'delivered' ||
                      order.status == 'completed') &&
                  !_allRated) ...[
                GradientButton(
                  label: 'Rate order',
                  icon: Icons.star_border_rounded,
                  onPressed: () => _openRatingSheet(context),
                ),
                const SizedBox(height: 12),
              ],
              if (order.status == 'delivered' ||
                  order.status == 'completed') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _buyAgainBusy ? null : _buyAgain,
                    icon: _buyAgainBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Buy Again',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.charcoal,
                      side: const BorderSide(color: AppColors.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
              ],
              if (order.canCancel) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9B1C1C),
                      side: const BorderSide(color: Color(0x40C24E68)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      'Cancel order',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRiderChat(BuildContext context, Order order) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => Material(
          color: Colors.transparent,
          child: ChatDrawer(
            onClose: () => Navigator.of(ctx).pop(),
            openOrderId: order.id,
          ),
        ),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final reason = await showCancelOrderReasonSheet(context);
    if (reason == null || !mounted) return;

    final res = await ApiService.cancelOrder(
      _order.id,
      reasonCode: reason.reasonCode,
      reason: reason.reason,
    );
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Could not cancel order')),
    );
  }

  void _openRatingSheet(BuildContext context) {
    final order = _order;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RatingSheet(
        order: order,
        existingRatings: Map.from(_existingRatings),
        storeRatedAlready: _storeRated,
        onSubmitted: () {
          _loadExistingRatings();
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your rating!')),
          );
        },
      ),
    );
  }

  Future<void> _markOrderAsCompleted() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Complete order'),
            content: const Text('Mark this delivered order as completed?'),
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
        ) ??
        false;
    if (!ok) return;

    final res = await ApiService.completeOrder(_order.id);
    if (!mounted) return;
    if (res.statusCode == 200 && res.data?['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as completed.')),
      );
      await _loadLatestOrder();
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(res.data?['message'] ??
              res.data?['error'] ??
              'Failed to complete order')),
    );
  }

  Widget _buildOrderItemImage(OrderItem item) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: AppColors.imageWash,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Icon(Icons.local_florist,
              size: 32, color: AppColors.deepRose.withOpacity(0.16)),
        ),
      );
    }

    // Optimize Cloudinary URL if needed
    final optimizedUrl = CloudinaryService.isCloudinaryUrl(item.imageUrl!)
        ? CloudinaryService.getThumbnailUrl(item.imageUrl!, size: 70)
        : item.imageUrl!;

    debugPrint('📸 OrderItem image URL: $optimizedUrl');

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(gradient: AppColors.imageWash),
        child: CachedNetworkImage(
          imageUrl: optimizedUrl,
          fit: BoxFit.cover,
          memCacheWidth: 70,
          memCacheHeight: 70,
          placeholder: (_, __) => _imagePlaceholder(),
          errorWidget: (_, url, error) {
            debugPrint('❌ OrderItem image failed: $url - $error');
            return _imagePlaceholder();
          },
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Icon(Icons.local_florist,
            size: 24, color: AppColors.deepRose.withOpacity(0.16)),
      ),
    );
  }

  String _getStatusExplanation(String status) {
    switch (status) {
      case 'pending':
        return 'Your payment receipt has been submitted and is awaiting seller verification.';
      case 'accepted':
        return 'Your order has been confirmed and the seller is preparing your items.';
      case 'preparing':
        return 'Your items are being carefully prepared and packed for delivery.';
      case 'done_preparing':
        return 'Your order is ready and waiting for the rider to collect for delivery.';
      case 'confirmed':
        return 'Your order is on the way. Track your delivery in real-time.';
      case 'on_delivery':
        return 'Your order is on the way. Track your delivery in real-time.';
      case 'delivered':
        return 'Your order has been successfully delivered. Thank you for your purchase!';
      case 'completed':
        return 'Order completed. Thanks for confirming receipt!';
      default:
        return '';
    }
  }

  void _showImageZoom(BuildContext context, String imageUrl) {
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

  DateTime _toPhilippineTime(DateTime dateTime) {
    // Convert UTC DateTime to Philippine time (UTC+8)
    if (dateTime.isUtc) {
      return dateTime.add(const Duration(hours: 8));
    }
    // If already localized, assume it's in local time and needs conversion
    return dateTime.add(const Duration(hours: 8));
  }

  String? _getStatusTimestamp(String statusId) {
    final order = _order;
    DateTime? dateTime;

    switch (statusId) {
      case 'pending':
        dateTime = order.pendingAt;
        break;
      case 'accepted':
        dateTime = order.acceptedAt;
        break;
      case 'preparing':
        dateTime = order.preparingAt;
        break;
      case 'done_preparing':
        dateTime = order.donePreparingAt;
        break;
      case 'confirmed':
        dateTime = order.confirmedAt;
        break;
      case 'delivered':
        dateTime = order.deliveredAt;
        break;
    }

    if (dateTime == null) return null;
    return DateFormat('MMM dd, hh:mm a').format(_toPhilippineTime(dateTime));
  }

  Widget _buildStatusTimeline(
      String currentStatus,
      String? paymentProofUrl,
      String? deliveryProofUrl,
      String? deliveryProof2Url,
      String? donePreparingProofUrl,
      BuildContext context) {
    final statuses = [
      {'id': 'pending', 'label': 'Payment'},
      {'id': 'accepted', 'label': 'Confirmed'},
      {'id': 'preparing', 'label': 'Preparing'},
      {'id': 'done_preparing', 'label': 'Ready'},
      {'id': 'confirmed', 'label': 'In Transit'},
      {'id': 'delivered', 'label': 'Delivered'},
    ];

    final statusOrder = [
      'pending',
      'accepted',
      'preparing',
      'done_preparing',
      'confirmed',
      'delivered'
    ];
    // Map actual DB status to timeline status (on_delivery in DB maps to confirmed in timeline)
    final mappedStatus = currentStatus == 'on_delivery'
        ? 'confirmed'
        : (currentStatus == 'completed' ? 'delivered' : currentStatus);
    final currentIndex = statusOrder.indexOf(mappedStatus);

    return Column(
      children: statuses.asMap().entries.map((e) {
        final i = e.key;
        final status = e.value;
        final isCompleted = statusOrder.indexOf(status['id']!) <= currentIndex;
        final isCurrent = status['id'] == mappedStatus;
        final isPending = status['id'] == 'pending';
        final isDelivered = status['id'] == 'delivered';
        final isReady = status['id'] == 'done_preparing';
        final showPaymentProofButton =
            isPending && paymentProofUrl != null && paymentProofUrl.isNotEmpty;
        final hasProofs = isDelivered &&
            (deliveryProofUrl != null || deliveryProof2Url != null);
        final showFulfillmentProofButton = isReady &&
            donePreparingProofUrl != null &&
            donePreparingProofUrl.isNotEmpty;

        // Get timestamp for this status from the Order object
        final timestamp = _getStatusTimestamp(status['id']!);

        // Calculate dynamic line height based on content in this row (connectors below)
        double lineHeight = 60; // base content (label + explanation)
        if (isCurrent) lineHeight += 26; // "Current status" badge
        if (showPaymentProofButton) lineHeight += 40; // View Receipt + padding
        if (showFulfillmentProofButton)
          lineHeight += 40; // fulfillment button + padding
        if (hasProofs && isCurrent) lineHeight += 132; // images + padding

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              isCompleted ? AppColors.brandGradient : null,
                          color: isCompleted ? null : AppColors.glassFill,
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.roseCta
                                : (isCompleted
                                    ? Colors.transparent
                                    : AppColors.glassBorder),
                            width: isCurrent ? 3 : 2,
                          ),
                          boxShadow: isCompleted ? AppShadows.roseButton : null,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : Center(
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                      ),
                      // Connector only after this step was left (real progress), not into future steps
                      if (i < statuses.length - 1 && currentIndex > i)
                        SizedBox(
                          height: lineHeight,
                          child: Container(
                            width: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.roseCta,
                                  AppColors.pinkMid,
                                  AppColors.purpleEnd
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status['label']!,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isCurrent
                                    ? AppColors.roseCta
                                    : (isCompleted
                                        ? AppColors.charcoal
                                        : AppColors.muted),
                              ),
                            ),
                            if (isCompleted && timestamp != null)
                              Text(
                                timestamp,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusExplanation(status['id']!),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.roseCta.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                    color: AppColors.roseCta.withOpacity(0.25)),
                              ),
                              child: Text(
                                'CURRENT STATUS',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.labelPink,
                                ),
                              ),
                            ),
                          ),
                        // Payment proof — always when URL exists (not tied to current step)
                        if (showPaymentProofButton)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showImageZoom(context, paymentProofUrl),
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('View Receipt'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepRose,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Delivery Proofs under "Delivered" status
                        if (hasProofs && isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                if (deliveryProofUrl != null)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showImageZoom(
                                          context, deliveryProofUrl),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          height: 120,
                                          color: AppColors.cream,
                                          child: CachedNetworkImage(
                                            imageUrl: deliveryProofUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.deepRose,
                                              ),
                                            ),
                                            errorWidget: (_, url, error) =>
                                                Container(
                                              color: AppColors.warmWhite,
                                              child: const Center(
                                                child: Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    size: 24,
                                                    color: AppColors.muted),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (deliveryProofUrl != null &&
                                    deliveryProof2Url != null)
                                  const SizedBox(width: 8),
                                if (deliveryProof2Url != null)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showImageZoom(
                                          context, deliveryProof2Url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          height: 120,
                                          color: AppColors.cream,
                                          child: CachedNetworkImage(
                                            imageUrl: deliveryProof2Url,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.deepRose,
                                              ),
                                            ),
                                            errorWidget: (_, url, error) =>
                                                Container(
                                              color: AppColors.warmWhite,
                                              child: const Center(
                                                child: Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    size: 24,
                                                    color: AppColors.muted),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // Seller fulfillment photo — same pattern as receipt (button always when URL exists)
                        if (showFulfillmentProofButton)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                onPressed: () => _showImageZoom(
                                    context, donePreparingProofUrl),
                                icon: const Icon(Icons.local_florist_outlined,
                                    size: 16),
                                label: const Text('View finished product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepRose,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (i < statuses.length - 1) const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppColors.charcoal : AppColors.muted,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ??
                  (isBold ? AppColors.deepRose : AppColors.charcoal),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final Order order;
  final Map<int, int> existingRatings;
  final bool storeRatedAlready;
  final VoidCallback onSubmitted;

  const _RatingSheet({
    required this.order,
    required this.existingRatings,
    required this.storeRatedAlready,
    required this.onSubmitted,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  /// 0 = rate store, 1 = rate products
  late int _step;
  late Map<int, int> _ratings;
  late Map<int, TextEditingController> _commentControllers;
  late List<OrderItem> _unratedItems;
  final TextEditingController _storeComment = TextEditingController();
  int _storeStars = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _step = widget.storeRatedAlready ? 1 : 0;
    _unratedItems = widget.order.items
        .where((item) => !widget.existingRatings.containsKey(item.id))
        .toList();
    _ratings = {};
    _commentControllers = {
      for (final item in _unratedItems) item.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _storeComment.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasProductRating => _ratings.values.any((r) => r > 0);

  Future<void> _submitStore() async {
    if (_storeStars < 1) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'rating': _storeStars,
      if (_storeComment.text.trim().isNotEmpty)
        'comment': _storeComment.text.trim(),
    };
    final res =
        await ApiService.submitOrderRatings(widget.order.id, storeRating: body);
    setState(() => _submitting = false);
    if (res.statusCode == 200 && res.data?['success'] == true) {
      if (_unratedItems.isEmpty) {
        widget.onSubmitted();
      } else {
        setState(() => _step = 1);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res.data?['error'] ?? 'Failed to save store rating')),
      );
    }
  }

  void _skipStore() {
    if (_unratedItems.isEmpty) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You can rate the shop later from this order.')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submitProducts() async {
    if (!_hasProductRating) return;
    setState(() => _submitting = true);

    final ratings = _ratings.entries.where((e) => e.value > 0).map((e) {
      final comment = _commentControllers[e.key]?.text.trim();
      return <String, dynamic>{
        'order_item_id': e.key,
        'rating': e.value,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };
    }).toList();

    final res =
        await ApiService.submitOrderRatings(widget.order.id, ratings: ratings);
    setState(() => _submitting = false);

    if (res.statusCode == 200 && res.data?['success'] == true) {
      widget.onSubmitted();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res.data?['error'] ?? 'Failed to submit rating')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0 ? 'Rate your experience' : 'Rate your products';
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: _step == 0
                ? ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    children: [
                      Text(
                        'How was this shop overall? Stars are required to continue; comment is optional.',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined,
                              color: AppColors.deepRose, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.order.storeName ?? 'Store',
                              style: GoogleFonts.dmSans(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (si) {
                          final star = si + 1;
                          return GestureDetector(
                            onTap: () => setState(() => _storeStars = star),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                star <= _storeStars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 40,
                                color: star <= _storeStars
                                    ? const Color(0xFFf0b429)
                                    : AppColors.borderStrong,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _storeComment,
                        maxLines: 3,
                        maxLength: 500,
                        style: GoogleFonts.dmSans(fontSize: 12),
                        decoration: InputDecoration(
                          hintText:
                              'Optional feedback about packaging or service',
                          hintStyle: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.muted),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.deepRose)),
                          counterText: '',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: _unratedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) {
                      final item = _unratedItems[i];
                      final rating = _ratings[item.id] ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warmWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildItemThumb(item),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.displayName,
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text('Qty: ${item.quantity}',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (si) {
                                final star = si + 1;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _ratings[item.id] = star),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Icon(
                                      star <= rating
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 36,
                                      color: star <= rating
                                          ? const Color(0xFFf0b429)
                                          : AppColors.borderStrong,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _commentControllers[item.id],
                              maxLines: 2,
                              maxLength: 500,
                              style: GoogleFonts.dmSans(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts (optional)',
                                hintStyle: GoogleFonts.dmSans(
                                    fontSize: 12, color: AppColors.muted),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.deepRose)),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  TextButton(
                    onPressed: _submitting ? null : _skipStore,
                    child: Text('Skip, rate products only',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed:
                        (_storeStars > 0 && !_submitting) ? _submitStore : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Continue'),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: _hasProductRating && !_submitting
                        ? _submitProducts
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit ratings'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemThumb(OrderItem item) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.cream, borderRadius: BorderRadius.circular(8)),
        child: const Center(
            child:
                Icon(Icons.local_florist, size: 20, color: Color(0x22B5445A))),
      );
    }
    final url = CloudinaryService.isCloudinaryUrl(item.imageUrl!)
        ? CloudinaryService.getThumbnailUrl(item.imageUrl!, size: 44)
        : item.imageUrl!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
          imageUrl: url, width: 44, height: 44, fit: BoxFit.cover),
    );
  }
}

/// Per-line price rows: main product (± variant label) and each add-on.
class _OrderItemPriceBreakdown extends StatelessWidget {
  final OrderItem item;

  const _OrderItemPriceBreakdown({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity <= 0 ? 1 : item.quantity;
    final productSub = item.price * qty;
    final hasVariant =
        item.variantName != null && item.variantName!.trim().isNotEmpty;
    final mainLabel =
        hasVariant ? '${item.productName} · ${item.variantName}' : item.productName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0x1A2C2520), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bdRow(
            label: mainLabel,
            calc: '₱${item.price.toStringAsFixed(2)} × $qty',
            amount: '₱${productSub.toStringAsFixed(2)}',
            emphasize: true,
          ),
          ...item.addons.map((a) {
            final aQty = a.quantity <= 0 ? 1 : a.quantity;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _bdRow(
                label: '+ ${a.name}${aQty > 1 ? ' ×$aQty' : ''}',
                calc: '₱${a.price.toStringAsFixed(2)} × $aQty',
                amount: '₱${a.total.toStringAsFixed(2)}',
                imageUrl: a.imageUrl,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _bdRow({
    required String label,
    required String calc,
    required String amount,
    bool emphasize = false,
    String? imageUrl,
  }) {
    final labelStyle = GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: emphasize ? FontWeight.w500 : FontWeight.w400,
      color: emphasize ? AppColors.charcoal : AppColors.muted,
    );
    final metaStyle = GoogleFonts.dmSans(
      fontSize: 10,
      color: AppColors.muted,
    );
    final amtStyle = GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.charcoal,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          _AddonThumb(url: imageUrl),
          const SizedBox(width: 8),
        ] else if (!emphasize) ...[
          _AddonThumb(url: null),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: labelStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(calc, style: metaStyle),
        const SizedBox(width: 8),
        Text(amount, style: amtStyle),
      ],
    );
  }
}

class _AddonThumb extends StatelessWidget {
  final String? url;
  const _AddonThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.card_giftcard, size: 12, color: AppColors.muted),
      );
    }
    final thumb = CloudinaryService.isCloudinaryUrl(url!)
        ? CloudinaryService.getThumbnailUrl(url!, size: 44)
        : url!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: CachedNetworkImage(
        imageUrl: thumb,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 22,
          height: 22,
          color: AppColors.cream,
          child: const Icon(Icons.card_giftcard, size: 12, color: AppColors.muted),
        ),
      ),
    );
  }
}
