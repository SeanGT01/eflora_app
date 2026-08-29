import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../services/app_quality.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_blur.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/chat_drawer.dart';
import 'rider_home_screen.dart';
import 'available_orders_screen.dart';
import 'my_deliveries_screen.dart';
import 'rider_layout.dart';
import 'rider_profile_screen.dart';

class RiderShell extends StatefulWidget {
  const RiderShell({super.key});
  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  int _idx = 0;
  bool _chatOpen = false;

  final _screens = const [
    RiderHomeScreen(),
    AvailableOrdersScreen(),
    MyDeliveriesScreen(),
    RiderProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rider = context.read<RiderProvider>();
      rider.loadDashboard();
      rider.loadAvailableOrders();
      rider.loadActiveDeliveries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = context.watch<RiderProvider>().activeDeliveries.length;
    final availableCount = context.watch<RiderProvider>().availableOrders.length;
    final showChatFab =
        !_chatOpen && (ModalRoute.of(context)?.isCurrent ?? true);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: AppBackground(
            child: Stack(
              children: [
                if (AppQuality.instance.keepTabsAlive)
                  IndexedStack(index: _idx, children: _screens)
                else
                  KeyedSubtree(
                    key: ValueKey('rider_tab_$_idx'),
                    child: _screens[_idx],
                  ),
                if (_chatOpen)
                  ChatDrawer(
                    onClose: () => setState(() => _chatOpen = false),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: ClipRect(
            child: AdaptiveBlur(
              sigma: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppQuality.instance.useBlur
                      ? AppColors.headerGlass
                      : null,
                  color: AppQuality.instance.useBlur
                      ? null
                      : const Color(0xF5FFFAFC),
                  border: const Border(
                    top: BorderSide(color: Color(0x8CFFFFFF), width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: kRiderNavBarHeight,
                    child: Row(
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Home',
                          selected: _idx == 0,
                          onTap: () => setState(() => _idx = 0),
                        ),
                        _BadgeNavItem(
                          icon: Icons.list_alt_outlined,
                          activeIcon: Icons.list_alt,
                          label: 'Available',
                          selected: _idx == 1,
                          count: availableCount,
                          onTap: () => setState(() => _idx = 1),
                        ),
                        _BadgeNavItem(
                          icon: Icons.delivery_dining_outlined,
                          activeIcon: Icons.delivery_dining,
                          label: 'Deliveries',
                          selected: _idx == 2,
                          count: activeCount,
                          onTap: () => setState(() => _idx = 2),
                        ),
                        _NavItem(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: 'Profile',
                          selected: _idx == 3,
                          onTap: () {
                            setState(() => _idx = 3);
                            // Refresh counts when opening profile.
                            context.read<RiderProvider>().loadStats();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showChatFab)
          FloatingChatButton(
            bottomNavClearance: kRiderNavBarHeight,
            onTap: () {
              final auth = context.read<AuthProvider>();
              if (!auth.isLoggedIn) {
                showAuthRequiredSheet(
                  context,
                  message: 'Create an account or sign in to use chat',
                );
                return;
              }
              setState(() => _chatOpen = true);
            },
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                size: 22,
                color: selected ? AppColors.deepRose : AppColors.muted.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.deepRose : AppColors.muted.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _BadgeNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected ? AppColors.deepRose : AppColors.muted.withOpacity(0.5),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.deepRose,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.deepRose : AppColors.muted.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
