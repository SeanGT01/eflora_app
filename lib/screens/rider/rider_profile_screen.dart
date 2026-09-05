import 'package:flutter/material.dart';import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/rider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../account/change_password_screen.dart';
import '../../theme/app_theme.dart';
import 'rider_layout.dart';
import 'rider_ui.dart';

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
      appBar: RiderPageHeader(title: 'Profile'),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, riderShellBottomInset(context)),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: RiderUi.card,
              child: Column(
                children: [
                  _RiderAvatar(profile: profile),
                  const SizedBox(height: 14),
                  Text(
                    profile?.fullName ?? 'Rider',
                    style: RiderUi.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.sage.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      (profile?.isActive ?? false) ? 'Active Rider' : 'Inactive',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _HeroStat(
                  value: '${stats?.totalDeliveries ?? 0}',
                  label: 'Total Deliveries',
                  color: AppColors.deepRose,
                ),
                const SizedBox(width: 10),
                _HeroStat(
                  value: '${stats?.weeklyDeliveries ?? 0}',
                  label: 'This Week',
                  color: AppColors.roseCta,
                ),
                const SizedBox(width: 10),
                _HeroStat(
                  value: (stats?.avgDeliveryTimeMinutes ?? 0) > 0
                      ? '${stats!.avgDeliveryTimeMinutes.round()}m'
                      : '—',
                  label: 'Avg Time',
                  color: AppColors.sage,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              title: 'Vehicle',
              children: [
                _SettingsTile(
                  icon: Icons.two_wheeler_rounded,
                  label: 'Vehicle Type',
                  value: profile?.vehicleType ?? 'Not set',
                ),
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  label: 'License Plate',
                  value: profile?.licensePlate ?? 'Not set',
                ),
                _SettingsTile(
                  icon: Icons.storefront_outlined,
                  label: 'Store',
                  value: profile?.storeName ?? 'Not set',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingsGroup(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  labelColor: const Color(0xFFe74c3c),
                  onTap: () async {
                    context.read<RiderProvider>().clear();
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HeroStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: RiderUi.card,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: RiderUi.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title, style: RiderUi.section.copyWith(fontSize: 16)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: labelColor ?? AppColors.deepRose),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? AppColors.charcoal,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Store logo on profile hero; falls back to storefront icon when missing.
class _RiderAvatar extends StatelessWidget {
  static const double _size = 72;

  final RiderProfile? profile;

  const _RiderAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return RiderStoreLogoAvatar(
      logoUrl: profile?.storeLogoUrl,
      size: _size,
    );
  }
}
