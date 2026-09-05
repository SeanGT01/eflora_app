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
                  color: AppQuality.instance.useBlur
                      ? AppColors.warmWhite.withValues(alpha: 0.92)
                      : AppColors.warmWhite,
                  gradient: AppQuality.instance.useBlur
                      ? AppColors.headerGlass
                      : null,
                  border: const Border(
                    top: BorderSide(color: Color(0x66E6AAC3), width: 1),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14502846),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: kRiderNavBarHeight,
                    child: Row(
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard_rounded,
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
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 14 : 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 21,
                color: selected ? Colors.white : AppColors.muted.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.deepRose : AppColors.muted.withValues(alpha: 0.55),
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
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 14 : 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.brandGradient : null,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 21,
                    color: selected ? Colors.white : AppColors.muted.withValues(alpha: 0.55),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.deepRose,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: GoogleFonts.dmSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.deepRose : AppColors.muted.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
