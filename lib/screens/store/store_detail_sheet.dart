import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import '../../config/mapbox_config.dart';
import '../../models/store.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_blur.dart';
import '../../widgets/glass.dart';

/// Store hero gradient, mirroring the website's store banner panel.
const LinearGradient _storeHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.roseCta, AppColors.pinkMid, Color(0xFFB888D0)],
  stops: [0.0, 0.45, 1.0],
);

/// TikTok-shop style store details bottom sheet
class StoreDetailSheet extends StatelessWidget {
  final Store store;
  final VoidCallback? onMessage;
  const StoreDetailSheet({super.key, required this.store, this.onMessage});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: AdaptiveBlur(
          sigma: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.pageCream.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: const Border(
                top: BorderSide(color: AppColors.glassBorder, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradientH,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE SHOP',
                              style: GoogleFonts.dmSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dustyRose,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Store Details',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 22, color: AppColors.muted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // ── Store Logo + Name ──
                      _buildHeader(),
                      const SizedBox(height: 20),
                      // ── Delivery Map ──
                      if (store.latitude != null && store.longitude != null) ...[
                        _sectionLabel('Location & Delivery Coverage'),
                        const SizedBox(height: 10),
                        _StoreDeliveryMapPreview(store: store),
                        const SizedBox(height: 20),
                      ],
                      // ── Description ──
                      if (store.description != null &&
                          store.description!.isNotEmpty) ...[
                        _sectionLabel('About'),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            store.description!,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.charcoal,
                                height: 1.55),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // ── Stats Row (Reviews cell opens modal) ──
                      _buildStatsRow(context),
                      const SizedBox(height: 20),
                      // ── Info Cards ──
                      _sectionLabel('Store Information'),
                      const SizedBox(height: 10),
                      _infoRow(
                          Icons.location_on_outlined,
                          'Address',
                          store.formattedAddress ??
                              store.address ??
                              _buildAddress()),
                      if (store.contactNumber != null &&
                          store.contactNumber!.isNotEmpty)
                        _infoRow(
                            Icons.phone_outlined, 'Contact', store.contactNumber!),
                      if (store.deliveryRadiusKm != null)
                        _infoRow(Icons.delivery_dining_outlined, 'Delivery Area',
                            '${store.deliveryRadiusKm!.toStringAsFixed(0)} km radius'),
                      if (store.baseDeliveryFee != null)
                        _infoRow(Icons.payments_outlined, 'Base Delivery Fee',
                            '₱${store.baseDeliveryFee!.toStringAsFixed(2)}'),
                      ..._scheduleRuleRows(),
                      const SizedBox(height: 20),
                      // ── Schedule ──
                      if (store.storeSchedule != null) ...[
                        _sectionLabel('Store Hours'),
                        const SizedBox(height: 10),
                        _buildSchedule(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isOpen = _isStoreOpenNow();
    final bannerUrl = store.bannerUrl;
    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;
    final resolvedBannerUrl = hasBanner
        ? (bannerUrl.startsWith('http')
            ? bannerUrl
            : ApiService.assetUrl(bannerUrl))
        : ApiService.assetUrl('/static/images/store-hero-florals.jpg');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: hasBanner ? null : _storeHeroGradient,
        image: DecorationImage(
          image: CachedNetworkImageProvider(resolvedBannerUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D6E2A4C),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x331C1620), Color(0xC9161218)],
                ),
              ),
            ),
          ),
          Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: _buildLogo(64),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.name,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.15,
                    )),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? const Color(0x3348BB78)
                        : const Color(0x33E05353),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isOpen
                          ? const Color(0x9948BB78)
                          : const Color(0x99E05353),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOpen
                              ? const Color(0xFFB6F0C4)
                              : const Color(0xFFFFB4B4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOpen ? 'Open Now' : 'Closed',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onMessage != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onMessage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E4A1A34),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 14, color: AppColors.roseCta),
                    const SizedBox(width: 5),
                    Text(
                      'Message',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.roseCta,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          _statCell(Icons.shopping_bag_outlined, '${store.productCount ?? 0}',
              'Products'),
          _statDivider(),
          _statCell(
              Icons.star_rounded,
              store.avgRating != null && store.avgRating! > 0
                  ? store.avgRating!.toStringAsFixed(1)
                  : '—',
              'Rating'),
          _statDivider(),
          _statCell(
              Icons.delivery_dining_outlined,
              store.deliveryRadiusKm != null
                  ? '${store.deliveryRadiusKm!.toStringAsFixed(0)}km'
                  : '—',
              'Delivery'),
          _statDivider(),
          _reviewsStatCell(context),
        ],
      ),
    );
  }

  Widget _reviewsStatCell(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => _openReviewsModal(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            const Icon(Icons.rate_review_outlined, size: 19, color: AppColors.deepRose),
            const SizedBox(height: 5),
            Text(
              '${store.reviewCount ?? 0}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRose,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REVIEWS',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepRose,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: 11, color: AppColors.deepRose),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openReviewsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewsModal(store: store),
    );
  }

  Widget _statCell(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 19, color: AppColors.labelPink),
          const SizedBox(height: 5),
          Text(value,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.deepRose,
              )),
          Text(label.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.glassBorderActive.withValues(alpha: 0.4),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.labelPink,
        letterSpacing: 1.2,
      ),
    );
  }

  List<Widget> _scheduleRuleRows() {
    final schedule = store.storeSchedule;
    if (schedule == null) return const [];

    final rows = <Widget>[];
    final start = schedule['delivery_start']?.toString();
    final end = schedule['delivery_cutoff']?.toString();
    if (start != null &&
        start.isNotEmpty &&
        end != null &&
        end.isNotEmpty) {
      rows.add(_infoRow(
        Icons.local_shipping_outlined,
        'Delivery Window',
        '${_to12HrWeb(start)} – ${_to12HrWeb(end)}',
      ));
    }

    final orderCutoff = schedule['order_cutoff']?.toString();
    if (orderCutoff != null && orderCutoff.isNotEmpty) {
      rows.add(_infoRow(
        Icons.alarm_outlined,
        'Same-day Order Cutoff',
        'Order by ${_to12HrWeb(orderCutoff)} for same-day',
      ));
    }

    return rows;
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.imageWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppColors.deepRose),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPink,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 3),
                  Text(value,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.charcoal,
                        height: 1.4,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedule() {
    final schedule = store.storeSchedule;
    if (schedule == null) return const SizedBox();

    final schedules = schedule['schedules'] as List<dynamic>? ?? [];
    if (schedules.isEmpty) {
      return Text('No schedule set',
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted));
    }

    // Build a week map: day name => list of time ranges
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final dayMap = <String, List<Map<String, String>>>{};

    for (final day in daysOfWeek) {
      dayMap[day] = [];
    }

    // Populate the day map from schedules
    for (final entry in schedules) {
      final days = entry['days'] as List<dynamic>? ?? [];
      final open = entry['open']?.toString() ?? '';
      final close = entry['close']?.toString() ?? '';

      for (final day in days) {
        final dayStr = day.toString();
        // Find matching day in daysOfWeek (case-insensitive)
        final matchDay = daysOfWeek.firstWhere(
          (d) => d.toLowerCase() == dayStr.toLowerCase(),
          orElse: () => '',
        );
        if (matchDay.isNotEmpty) {
          dayMap[matchDay]!.add({'open': open, 'close': close});
        }
      }
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: List.generate(daysOfWeek.length, (idx) {
          final dayName = daysOfWeek[idx];
          final times = dayMap[dayName] ?? [];

          // Format time slots
          String timeStr = 'Closed';
          Color timeColor = AppColors.muted;
          FontWeight timeWeight = FontWeight.w400;

          if (times.isNotEmpty) {
            timeColor = AppColors.deepSage; // Green for open
            timeWeight = FontWeight.w600;
            final timeSlots = times.map((t) {
              final open = _to12HrWeb(t['open'] ?? '');
              final close = _to12HrWeb(t['close'] ?? '');
              return '$open-$close'; // No space before dash
            });
            timeStr =
                timeSlots.join(' / '); // Separate multiple shifts with ' / '
          }

          return Column(
            children: [
              if (idx > 0)
                Divider(
                  height: 1,
                  color: AppColors.glassBorderActive.withValues(alpha: 0.35),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      dayName.substring(0, 3).toUpperCase(), // Mon, Tue, etc.
                      style: GoogleFonts.dmSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        timeStr,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: timeWeight,
                          color: timeColor,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Whether the store is currently open based on PH local time + schedule.
  /// Mirrors website `checkStoreStatus()` — not account `status` (active/inactive).
  bool _isStoreOpenNow() {
    final schedule = store.storeSchedule;
    final schedules = schedule?['schedules'] as List<dynamic>?;
    if (schedules == null || schedules.isEmpty) return false;

    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final dayName = days[now.weekday - 1];
    final currentMinutes = now.hour * 60 + now.minute;

    for (final entry in schedules) {
      if (entry is! Map) continue;
      final daysList = entry['days'] as List<dynamic>? ?? const [];
      final matchesToday = daysList.any(
        (d) => d.toString().toLowerCase() == dayName,
      );
      if (!matchesToday) continue;

      final open = entry['open']?.toString() ?? '';
      final close = entry['close']?.toString() ?? '';
      final openParts = open.split(':');
      final closeParts = close.split(':');
      if (openParts.length < 2 || closeParts.length < 2) continue;

      final oh = int.tryParse(openParts[0]) ?? 0;
      final om = int.tryParse(openParts[1]) ?? 0;
      final ch = int.tryParse(closeParts[0]) ?? 0;
      final cm = int.tryParse(closeParts[1]) ?? 0;
      final openMinutes = oh * 60 + om;
      final closeMinutes = ch * 60 + cm;
      if (currentMinutes >= openMinutes && currentMinutes < closeMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Convert "08:00" or "17:30" to "8:00 AM" or "5:30 PM" (matches web formatTime12Hour)
  String _to12HrWeb(String time24) {
    if (time24.isEmpty) return '';
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int hour = int.tryParse(parts[0]) ?? 0;
    final min = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$min $suffix';
  }

  String _buildAddress() {
    final parts = <String>[];
    if (store.street != null && store.street!.isNotEmpty) {
      parts.add(store.street!);
    }
    if (store.barangay != null && store.barangay!.isNotEmpty) {
      parts.add(store.barangay!);
    }
    if (store.municipality != null && store.municipality!.isNotEmpty) {
      parts.add(store.municipality!);
    }
    return parts.isEmpty ? 'Address not available' : parts.join(', ');
  }

  Widget _buildLogo(double size) {
    final url = store.effectiveLogoUrl;
    if (url != null && url.isNotEmpty) {
      final imageUrl = url.startsWith('http') ? url : ApiService.assetUrl(url);
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorWidget: (_, __, ___) => _logoFallback(size),
      );
    }
    return _logoFallback(size);
  }

  Widget _logoFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Text(
          store.name.isNotEmpty ? store.name[0].toUpperCase() : 'S',
          style: GoogleFonts.cormorantGaramond(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
            color: AppColors.deepRose,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Delivery map (web-parity: expandable sheet, store avatar pin, customer pin)
// ═══════════════════════════════════════════════════════════════════════════

class _StoreDeliveryMapPreview extends StatefulWidget {
  const _StoreDeliveryMapPreview({required this.store});

  final Store store;

  @override
  State<_StoreDeliveryMapPreview> createState() =>
      _StoreDeliveryMapPreviewState();
}

class _StoreDeliveryMapPreviewState extends State<_StoreDeliveryMapPreview> {
  late final Future<String> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = MapboxConfig.publicToken();
  }

  void _openExpandedMap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreDeliveryMapSheet(store: widget.store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return FutureBuilder<String>(
      future: _tokenFuture,
      builder: (context, snap) {
        final token = snap.data ?? '';
        if (token.isEmpty) {
          return GestureDetector(
            onTap: () => _openExpandedMap(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: snap.connectionState == ConnectionState.waiting
                    ? const ColoredBox(
                        color: Color(0xFFF0EBE6),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.deepRose,
                            ),
                          ),
                        ),
                      )
                    : _StaticMapFallback(store: store),
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openExpandedMap(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth.round().clamp(280, 640);
                  const h = 190;
                  final url = _storeStaticMapUrl(
                    store,
                    token: token,
                    width: w,
                    height: h,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFFF0EBE6),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          fadeInDuration: const Duration(milliseconds: 180),
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.deepRose,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              _StaticMapFallback(store: store),
                        ),
                      ),
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -10),
                          child: _StoreMapPin(store: store, size: 40),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.warmWhite.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined,
                                  size: 13, color: AppColors.deepRose),
                              const SizedBox(width: 5),
                              Text(
                                'View delivery map',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fallback when the static map CDN fails.
class _StaticMapFallback extends StatelessWidget {
  const _StaticMapFallback({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7E8EE), Color(0xFFE8F0EA), Color(0xFFF0EBE6)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoreMapPin(store: store, size: 44),
            const SizedBox(height: 8),
            Text(
              'Tap to open delivery map',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mapbox Static Images API — same endpoint as web store detail preview.
String _storeStaticMapUrl(
  Store store, {
  required String token,
  required int width,
  required int height,
}) {
  final lat = store.latitude!;
  final lng = store.longitude!;
  const zoom = 12;
  return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/'
      '$lng,$lat,$zoom/${width}x$height@2x'
      '?access_token=$token';
}

class _StoreDeliveryMapSheet extends StatefulWidget {
  const _StoreDeliveryMapSheet({required this.store});

  final Store store;

  @override
  State<_StoreDeliveryMapSheet> createState() => _StoreDeliveryMapSheetState();
}

class _StoreDeliveryMapSheetState extends State<_StoreDeliveryMapSheet> {
  /// Delay FlutterMap until the sheet animation finishes — mounting during
  /// the slide cancels in-flight tiles ("Connection closed while receiving data").
  bool _mapReadyToMount = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _mapReadyToMount = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Material(
          color: const Color(0xFFFFFDF9),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery map',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _coverageDescription(store),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.deepRose),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x296B4C3B)),
              Expanded(
                child: _mapReadyToMount
                    ? _StoreDeliveryMapBody(
                        store: store,
                        interactive: true,
                        compact: false,
                      )
                    : const ColoredBox(
                        color: Color(0xFFF0EBE6),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.deepRose,
                            ),
                          ),
                        ),
                      ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x296B4C3B))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeliveryStatusRow(store: store),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _legendDot(const Color(0xFFB5445A), 'Store'),
                        if (store.customerMapLocation != null)
                          _legendDot(
                            const Color(0xFF276749),
                            'Your default address',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _DeliveryStatusRow extends StatelessWidget {
  const _DeliveryStatusRow({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final info = _deliveryStatus(store);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(info.icon, size: 18, color: info.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            info.message,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: info.color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusInfo {
  const _StatusInfo(this.message, this.color, this.icon);
  final String message;
  final Color color;
  final IconData icon;
}

_StatusInfo _deliveryStatus(Store store) {
  if (!store.isCustomer) {
    return const _StatusInfo(
      'Sign in and set a default address to check delivery coverage.',
      AppColors.muted,
      Icons.info_outline,
    );
  }
  if (store.canDeliverToCustomer == true) {
    return const _StatusInfo(
      'This store delivers to your default address.',
      AppColors.deepSage,
      Icons.check_circle_outline,
    );
  }
  final reason =
      store.deliveryReason ?? 'Delivery coverage could not be checked.';
  final needsSetup = RegExp(
    r'set your default|missing map coordinates|missing a municipality',
    caseSensitive: false,
  ).hasMatch(reason);
  return _StatusInfo(
    reason,
    needsSetup ? AppColors.muted : const Color(0xFFB65343),
    needsSetup ? Icons.info_outline : Icons.cancel_outlined,
  );
}

String _coverageDescription(Store store) {
  switch (store.deliveryMethod) {
    case 'zone':
      return 'Custom delivery zone';
    case 'municipality':
      final areas = store.selectedMunicipalities;
      return areas.isEmpty
          ? 'Municipality delivery area'
          : 'Delivers to: ${areas.join(', ')}';
    default:
      final radius = store.deliveryRadiusKm;
      return radius == null
          ? 'Store location and delivery coverage'
          : '${radius.toStringAsFixed(0)} km delivery radius';
  }
}

class _StoreDeliveryMapBody extends StatefulWidget {
  const _StoreDeliveryMapBody({
    required this.store,
    required this.interactive,
    required this.compact,
  });

  final Store store;
  final bool interactive;
  final bool compact;

  @override
  State<_StoreDeliveryMapBody> createState() => _StoreDeliveryMapBodyState();
}

class _StoreDeliveryMapBodyState extends State<_StoreDeliveryMapBody> {
  late final MapController _mapController;
  late final _DeferredCloseNetworkTileProvider _tileProvider;
  bool _didFit = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tileProvider = _DeferredCloseNetworkTileProvider();
  }

  @override
  void didUpdateWidget(covariant _StoreDeliveryMapBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.id != widget.store.id ||
        oldWidget.store.currentDeliveryGeojson !=
            widget.store.currentDeliveryGeojson ||
        oldWidget.store.deliveryRadiusKm != widget.store.deliveryRadiusKm ||
        oldWidget.store.customerMapLocation?.latitude !=
            widget.store.customerMapLocation?.latitude ||
        oldWidget.store.customerMapLocation?.longitude !=
            widget.store.customerMapLocation?.longitude) {
      _didFit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitBounds();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    // TileLayer also disposes the provider — keep close idempotent there.
    super.dispose();
  }

  LatLng get _storePoint =>
      LatLng(widget.store.latitude!, widget.store.longitude!);

  LatLng _offsetByKm(LatLng origin, double kmNorth, double kmEast) {
    const earthKm = 6371.0;
    final lat = origin.latitude + (kmNorth / earthKm) * (180 / math.pi);
    final lng = origin.longitude +
        (kmEast / earthKm) *
            (180 / math.pi) /
            math.cos(origin.latitude * math.pi / 180);
    return LatLng(lat, lng);
  }

  List<LatLng> get _points {
    final points = <LatLng>[_storePoint];
    final customer = widget.store.customerMapLocation;
    if (customer != null) {
      points.add(LatLng(customer.latitude, customer.longitude));
    }
    for (final polygon in _deliveryPolygons(widget.store)) {
      points.addAll(polygon.points);
    }
    final isRadius = widget.store.deliveryMethod == 'radius' ||
        (widget.store.deliveryMethod == null &&
            (widget.store.deliveryRadiusKm ?? 0) > 0);
    final radiusKm = widget.store.deliveryRadiusKm ?? 0;
    if (isRadius && radiusKm > 0) {
      points.addAll([
        _offsetByKm(_storePoint, radiusKm, 0),
        _offsetByKm(_storePoint, -radiusKm, 0),
        _offsetByKm(_storePoint, 0, radiusKm),
        _offsetByKm(_storePoint, 0, -radiusKm),
      ]);
    }
    return points;
  }

  void _fitBounds() {
    if (_didFit) return;
    final points = _points;
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, widget.compact ? 13.2 : 14);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.all(widget.compact ? 28 : 56),
            maxZoom: 14,
          ),
        );
      }
      _didFit = true;
    } catch (_) {
      // Map may not be ready yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final customer = store.customerMapLocation;
    final polygons = _deliveryPolygons(store);
    final isRadius = store.deliveryMethod == 'radius' ||
        (store.deliveryMethod == null && (store.deliveryRadiusKm ?? 0) > 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 8 || constraints.maxHeight < 8) {
          return const ColoredBox(color: Color(0xFFF0EBE6));
        }
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _storePoint,
            initialZoom: 13,
            backgroundColor: const Color(0xFFF0EBE6),
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onMapReady: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fitBounds();
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.seanlazala.eflora',
              maxZoom: 19,
              keepBuffer: 2,
              panBuffer: 1,
              tileProvider: _tileProvider,
              // Cancelled downloads on close/zoom are normal — don't dump stacks.
              errorTileCallback: (tile, error, stackTrace) {},
            ),
            if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
            if (isRadius && (store.deliveryRadiusKm ?? 0) > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _storePoint,
                    radius: store.deliveryRadiusKm! * 1000,
                    useRadiusInMeter: true,
                    color: const Color(0xFFB5445A).withValues(alpha: 0.16),
                    borderColor:
                        const Color(0xFFB5445A).withValues(alpha: 0.85),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _storePoint,
                  width: widget.compact ? 46 : 52,
                  height: widget.compact ? 56 : 62,
                  alignment: Alignment.topCenter,
                  child: _StoreMapPin(
                    store: store,
                    size: widget.compact ? 38 : 46,
                  ),
                ),
                if (customer != null)
                  Marker(
                    point: LatLng(customer.latitude, customer.longitude),
                    width: 22,
                    height: 22,
                    child: const _CustomerMapPin(),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Closes the HTTP client after a short delay so in-flight tile requests
/// aren't aborted with noisy "Connection closed while receiving data" errors
/// when the map sheet is dismissed.
class _DeferredCloseNetworkTileProvider extends NetworkTileProvider {
  _DeferredCloseNetworkTileProvider()
      : super(httpClient: RetryClient(http.Client()));

  bool _disposeScheduled = false;

  @override
  void dispose() {
    if (_disposeScheduled) return;
    _disposeScheduled = true;
    final client = httpClient;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      try {
        client.close();
      } catch (_) {}
    });
  }
}

List<Polygon> _deliveryPolygons(Store store) {
  final rawGeoJson = store.currentDeliveryGeojson;
  if (rawGeoJson == null || rawGeoJson.isEmpty) return const [];
  try {
    final geometry = jsonDecode(rawGeoJson) as Map<String, dynamic>;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return const [];
    final rings = geometry['type'] == 'MultiPolygon'
        ? coordinates.expand((polygon) => polygon as List).toList()
        : coordinates;
    return rings
        .whereType<List>()
        .map((ring) => Polygon(
              points: ring
                  .whereType<List>()
                  .where((point) => point.length >= 2)
                  .map((point) => LatLng(
                        (point[1] as num).toDouble(),
                        (point[0] as num).toDouble(),
                      ))
                  .toList(),
              color: const Color(0xFFB5445A).withValues(alpha: 0.16),
              borderColor: const Color(0xFFB5445A).withValues(alpha: 0.85),
              borderStrokeWidth: 2,
              isFilled: true,
            ))
        .where((polygon) => polygon.points.length >= 3)
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Matches web `.store-map-marker` — circular logo avatar + white tip.
class _StoreMapPin extends StatelessWidget {
  const _StoreMapPin({required this.store, required this.size});

  final Store store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tip = size * 0.28;
    final url = store.effectiveLogoUrl;
    final imageUrl = (url != null && url.isNotEmpty)
        ? (url.startsWith('http') ? url : ApiService.assetUrl(url))
        : null;
    final initial =
        store.name.isNotEmpty ? store.name[0].toUpperCase() : 'S';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3F4F44),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59331C28),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x59B5445A),
                blurRadius: 0,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl == null
              ? Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
        Transform.translate(
          offset: Offset(0, -tip * 0.45),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: tip,
              height: tip,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1FB5445A),
                    offset: Offset(2, 2),
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

// ═══════════════════════════════════════════════════════════════════════════
// Reviews modal — mirrors web store_detail.html / product ratings modal
// ═══════════════════════════════════════════════════════════════════════════

class _ReviewsModal extends StatelessWidget {
  const _ReviewsModal({required this.store});
  final Store store;

  Map<String, int> get _distribution {
    final dist = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
    for (final r in store.reviews) {
      final key = '${r.rating.clamp(1, 5)}';
      dist[key] = (dist[key] ?? 0) + 1;
    }
    return dist;
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final reviews = store.reviews;
    final avg = store.avgRating ?? 0.0;
    final count = store.reviewCount ?? reviews.length;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Store Ratings',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.charcoal.withValues(alpha: 0.06),
                    foregroundColor: AppColors.charcoal,
                    hoverColor: AppColors.charcoal.withValues(alpha: 0.1),
                    minimumSize: const Size(32, 32),
                    maximumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: 'Reviews for ',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                  children: [
                    TextSpan(
                      text: store.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                _overview(
                  avg: avg,
                  count: count,
                  // Bars are derived from the loaded list only.
                  barTotal: reviews.isEmpty ? 1 : reviews.length,
                ),
                const SizedBox(height: 16),
                if (reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 36,
                            color: AppColors.muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'No reviews yet for this store.',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ),
                  )
                else
                  ...reviews.map(_reviewRow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview({
    required double avg,
    required int count,
    required int barTotal,
  }) {
    final total = barTotal <= 0 ? 1 : barTotal;
    final dist = _distribution;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average user rating',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: count == 0 ? '0' : avg.toStringAsFixed(1),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                    children: [
                      TextSpan(
                        text: ' / 5',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < avg.round();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF0B429),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating breakdown',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 8),
                for (final star in [5, 4, 3, 2, 1])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: AppColors.muted)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (dist['$star'] ?? 0) / total,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFEDE3D8),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFF0B429)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(StoreReview review) {
    final name = review.customerName.trim().isNotEmpty
        ? review.customerName.trim()
        : 'Anonymous';
    final comment = (review.comment?.trim().isNotEmpty == true)
        ? review.comment!.trim()
        : 'No written comment.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 14,
                color: const Color(0xFFF0B429),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(comment,
              style: GoogleFonts.dmSans(
                  fontSize: 13, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(
            '— Reviewed by $name',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches web `.customer-map-marker` — green pin for default address.
class _CustomerMapPin extends StatelessWidget {
  const _CustomerMapPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF276749),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x593C281E),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x40276749),
            blurRadius: 0,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
