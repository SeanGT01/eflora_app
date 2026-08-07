import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/rider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../account/change_password_screen.dart';
import '../../theme/app_theme.dart';
import 'rider_layout.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});
  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RiderProvider>();
      provider.loadProfile();
      provider.loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<RiderProvider>();
    final profile = rider.profile;
    final stats = rider.stats;
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, riderShellBottomInset(context)),
        child: Column(
          children: [
            // ── Avatar & Name ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _RiderAvatar(profile: profile),
                  const SizedBox(height: 14),
                  Text(
                    profile?.fullName ?? 'Rider',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      profile?.storeName ?? 'Store',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Vehicle Info ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Information',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileRow(
                    icon: Icons.two_wheeler,
                    label: 'Vehicle Type',
                    value: profile?.vehicleType ?? 'Not set',
                  ),
                  const Divider(height: 20),
                  _ProfileRow(
                    icon: Icons.badge_outlined,
                    label: 'License Plate',
                    value: profile?.licensePlate ?? 'Not set',
                  ),
                  const Divider(height: 20),
                  _ProfileRow(
                    icon: Icons.circle,
                    label: 'Status',
                    value: (profile?.isActive ?? false) ? 'Active' : 'Inactive',
                    valueColor: (profile?.isActive ?? false)
                        ? AppColors.successGreen
                        : const Color(0xFFe74c3c),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats (always visible; zeros until API loads) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Statistics',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'This Week',
                        value: '${stats?.weeklyDeliveries ?? 0}',
                        color: const Color(0xFF3498db),
                      ),
                      _MiniStat(
                        label: 'This Month',
                        value: '${stats?.monthlyDeliveries ?? 0}',
                        color: AppColors.sage,
                      ),
                      _MiniStat(
                        label: 'Total',
                        value: '${stats?.totalDeliveries ?? 0}',
                        color: AppColors.deepRose,
                      ),
                    ],
                  ),
                  if ((stats?.avgDeliveryTimeMinutes ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Text(
                            'Avg. delivery time: ${_formatAvgDeliveryTime(stats!.avgDeliveryTimeMinutes)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Account Security ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Security',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.deepRose,
                      ),
                      label: Text(
                        'Change Password',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        side: const BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Logout ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  context.read<RiderProvider>().clear();
                  await auth.logout();
                  if (!context.mounted) return;
                  // Pop all routes back to _AppRoot root.
                  // _buildHomeForRole watches AuthProvider and will
                  // show MainShell (guest) since user is logged out.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout, size: 18, color: Color(0xFFe74c3c)),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFe74c3c),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFe74c3c), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [totalMinutes] from API; show hours + minutes when an hour or more.
  static String _formatAvgDeliveryTime(double totalMinutes) {
    final rounded = totalMinutes.round();
    if (rounded <= 0) return '—';
    final h = rounded ~/ 60;
    final m = rounded % 60;
    if (h == 0) return '$m min';
    final hrLabel = h == 1 ? 'hr' : 'hrs';
    if (m == 0) return '$h $hrLabel';
    return '$h $hrLabel $m min';
  }
}

/// Network photo when [RiderProfile.avatarUrl] is set; otherwise delivery rider icon on brand gradient.
class _RiderAvatar extends StatelessWidget {
  static const double _size = 72;

  final RiderProfile? profile;

  const _RiderAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final raw = profile?.avatarUrl?.trim();
    final hasUrl = raw != null && raw.isNotEmpty;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong.withOpacity(0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: raw,
              fit: BoxFit.cover,
              width: _size,
              height: _size,
              placeholder: (_, __) => Container(
                color: AppColors.cream,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.deepRose,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const _DefaultRiderAvatarFill(),
            )
          : const _DefaultRiderAvatarFill(),
    );
  }
}

class _DefaultRiderAvatarFill extends StatelessWidget {
  const _DefaultRiderAvatarFill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _RiderAvatar._size,
      height: _RiderAvatar._size,
      decoration: const BoxDecoration(
        gradient: AppColors.roseGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.delivery_dining_rounded,
        size: 40,
        color: Colors.white.withOpacity(0.95),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted.withOpacity(0.6)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
            ),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.charcoal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
