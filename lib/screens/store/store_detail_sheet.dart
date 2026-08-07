import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
                      // ── Stats Row ──
                      _buildStatsRow(),
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
    final isOpen = store.status == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _storeHeroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D6E2A4C),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
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
                              : Colors.white.withValues(alpha: 0.6),
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
                          letterSpacing: 0.3,
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
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
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
          _statCell(
              Icons.rate_review_outlined, '${store.reviewCount ?? 0}', 'Reviews'),
        ],
      ),
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
