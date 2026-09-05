import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../theme/app_theme.dart';
import 'order_detail_screen.dart';
import 'rider_layout.dart';
import 'rider_ui.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});
  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderProvider>().loadAvailableOrders();
    });
  }

  Future<void> _refresh() async {
    await context.read<RiderProvider>().loadAvailableOrders();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderProvider>();
    final orders = provider.availableOrders;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: RiderPageHeader(
        title: 'Available Orders',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.deepRose,
        onRefresh: _refresh,
        child: provider.loading && orders.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.deepRose),
                  ),
                ],
              )
            : orders.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
                      const RiderEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No available orders',
                        subtitle: 'Orders ready for pickup will appear here',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, riderShellBottomInset(context)),
                    itemCount: orders.length,
                    itemBuilder: (context, index) =>
                        _AvailableOrderCard(order: orders[index]),
                  ),
      ),
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  final RiderOrder order;
  const _AvailableOrderCard({required this.order});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: RiderUi.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            onTap: () => _openDetail(context),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiderOrderThumbnail(order: order, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.storeName != null)
                          Text(
                            order.storeName!,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.dustyRose,
                            ),
                          ),
                        Text(
                          'Order #${order.id}',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RiderInfoLine(
                          icon: Icons.location_on_outlined,
                          text: order.deliveryAddress ?? 'No address provided',
                        ),
                        if (order.distanceFromStoreKm != null) ...[
                          const SizedBox(height: 4),
                          RiderInfoLine(
                            icon: Icons.straighten,
                            text:
                                '${order.distanceFromStoreKm!.toStringAsFixed(1)} km • $itemCount item${itemCount == 1 ? '' : 's'}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery fee',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                    ),
                    Text(
                      '₱${order.deliveryFee.toStringAsFixed(2)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                RiderStatusChip(order: order),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: RiderGradientButton(
              label: 'Accept Order',
              icon: Icons.check_rounded,
              onTap: () => _openDetail(context),
            ),
          ),
        ],
      ),
    );
  }
}
