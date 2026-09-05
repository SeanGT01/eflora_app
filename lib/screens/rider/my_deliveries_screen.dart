import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';
import '../../utils/datetime_ph.dart';
import '../../theme/app_theme.dart';
import 'delivery_tracking_screen.dart';
import 'order_detail_screen.dart';
import 'rider_layout.dart';
import 'rider_ui.dart';

class MyDeliveriesScreen extends StatefulWidget {
  const MyDeliveriesScreen({super.key});
  @override
  State<MyDeliveriesScreen> createState() => _MyDeliveriesScreenState();
}

class _MyDeliveriesScreenState extends State<MyDeliveriesScreen> {
  int _tab = 0;
  List<RiderOrder> _completed = [];
  bool _loadingCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderProvider>().loadActiveDeliveries();
      _loadCompleted();
    });
  }

  Future<void> _loadCompleted() async {
    setState(() => _loadingCompleted = true);
    final result = await RiderService.getAssignedOrders(status: 'delivered');
    if (!mounted) return;
    setState(() {
      _loadingCompleted = false;
      if (result.isSuccess && result.data is Map) {
        final data = result.data as Map<String, dynamic>;
        _completed = (data['orders'] as List? ?? [])
            .map((o) => RiderOrder.fromJson(o as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<RiderProvider>().loadActiveDeliveries();
    await _loadCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RiderProvider>();
    final active = provider.activeDeliveries;
    final list = _tab == 0 ? active : _completed;
    final loading = _tab == 0
        ? provider.loading && active.isEmpty
        : _loadingCompleted && _completed.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: RiderPageHeader(
        title: 'My Deliveries',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: RiderSegmentedTabs(
              labels: const ['Active', 'Completed'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.deepRose,
              onRefresh: _refresh,
              child: loading
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.deepRose),
                        ),
                      ],
                    )
                  : list.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                            RiderEmptyState(
                              icon: Icons.delivery_dining_outlined,
                              title: _tab == 0
                                  ? 'No active deliveries'
                                  : 'No completed deliveries',
                              subtitle: _tab == 0
                                  ? 'Accept an order to start delivering'
                                  : 'Finished deliveries will show here',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            riderShellBottomInset(context),
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, index) =>
                              _DeliveryCard(order: list[index], isActive: _tab == 0),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final RiderOrder order;
  final bool isActive;
  const _DeliveryCard({required this.order, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final dateStr = formatPhilippineDateTime(order.createdAt, 'MMM dd, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: RiderUi.card,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.muted.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RiderStatusChip(order: order),
                    ],
                  ),
                ),
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                RiderInfoLine(
                  icon: Icons.person_outline,
                  text: order.customerName ?? 'Customer',
                ),
                const SizedBox(height: 6),
                RiderInfoLine(
                  icon: Icons.location_on_outlined,
                  text: order.deliveryAddress ?? 'No address',
                ),
                if (isActive) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: RiderOutlineButton(
                          label: 'Details',
                          icon: Icons.article_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(order: order),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RiderGradientButton(
                          label: 'Navigate',
                          icon: Icons.navigation_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryTrackingScreen(order: order),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  RiderOutlineButton(
                    label: 'View Details',
                    icon: Icons.article_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: order),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
