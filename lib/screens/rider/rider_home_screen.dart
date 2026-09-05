import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../utils/datetime_ph.dart';
import '../../theme/app_theme.dart';
import 'delivery_tracking_screen.dart';
import 'order_detail_screen.dart';
import 'rider_layout.dart';
import 'rider_ui.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});
  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderProvider>().loadDashboard();
    });
  }

  Future<void> _refresh() async {
    await context.read<RiderProvider>().loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderProvider>();
    final dash = provider.dashboard;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: RiderPageHeader(
        title: 'Rider Dashboard',
        subtitle: dash?.rider.storeName,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: RiderStoreLogoAvatar(
              logoUrl: dash?.rider.storeLogoUrl,
              size: 34,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.deepRose,
        onRefresh: _refresh,
        child: provider.loading && dash == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.deepRose),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: riderShellBottomInset(context)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        RiderStatTile(
                          icon: Icons.receipt_long_rounded,
                          label: "Today's Orders",
                          value: '${dash?.todayOrders ?? 0}',
                          accent: AppColors.roseCta,
                        ),
                        const SizedBox(width: 12),
                        RiderStatTile(
                          icon: Icons.check_circle_rounded,
                          label: 'Delivered',
                          value: '${dash?.todayDelivered ?? 0}',
                          accent: AppColors.successGreen,
                        ),
                      ],
                    ),
                  ),
                  if (dash?.currentOrder != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _CurrentDeliveryCard(order: dash!.currentOrder!),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    child: Text('Recent Orders', style: RiderUi.section),
                  ),
                  if (dash != null && dash.recentOrders.isNotEmpty)
                    ...dash.recentOrders.map((order) => _RecentOrderTile(order: order))
                  else
                    const RiderEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No recent orders',
                      subtitle: 'Completed and active orders will appear here',
                    ),
                ],
              ),
      ),
    );
  }
}

class _CurrentDeliveryCard extends StatelessWidget {
  final RiderOrder order;
  const _CurrentDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DeliveryTrackingScreen(order: order)),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.roseCta.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Delivery',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    order.statusLabel.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Order #${order.id}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 15, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customerName ?? 'Customer',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.deliveryAddress ?? 'No address',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Track Delivery',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepRose,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final RiderOrder order;
  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateStr = formatPhilippineDateTime(order.createdAt, 'MMM dd, h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
          ),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: RiderUi.card,
            child: Row(
              children: [
                RiderOrderThumbnail(order: order),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerName ?? 'Customer',
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      RiderStatusChip(order: order),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
