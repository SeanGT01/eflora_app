import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/app_quality.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_blur.dart';
import '../widgets/auth_required_sheet.dart';
import '../widgets/chat_drawer.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart';
import 'account/account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Switch the tab from anywhere in the widget tree.
  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<MainShellState>()?.switchToTab(index);
  }

  /// Open chat (optionally with a store) from anywhere under MainShell.
  static void openChat(BuildContext context, {int? storeId}) {
    context.findAncestorStateOfType<MainShellState>()?.openChatWithStoreOrInbox(storeId);
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _idx = 0;
  bool _chatOpen = false;
  int? _chatOpenStoreId;

  void switchToTab(int index) {
    setState(() => _idx = index);
  }

  void openChatWithStore(int storeId) {
    openChatWithStoreOrInbox(storeId);
  }

  void openChatWithStoreOrInbox(int? storeId) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(
        context,
        message: 'Create an account or sign in to use chat',
      );
      return;
    }
    setState(() {
      _chatOpen = true;
      _chatOpenStoreId = storeId;
    });
  }

  void openChat() {
    openChatWithStoreOrInbox(null);
  }

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    CartScreen(),
    OrdersScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    return Scaffold(
      backgroundColor: AppColors.pageCream,
      extendBody: true,
      body: Stack(
        children: [
          // Rich devices keep all tabs alive; lite remounts only the active tab.
          if (AppQuality.instance.keepTabsAlive)
            IndexedStack(index: _idx, children: _screens)
          else
            KeyedSubtree(
              key: ValueKey('tab_$_idx'),
              child: _screens[_idx],
            ),
          // Floating chat button — same role as website `#chat-fab`.
          // Hidden on the Cart tab so it doesn't cover the checkout bar
          // (mirrors web `#chat-fab.cart-open-hidden`), and while a dialog /
          // modal route is open on top of this shell.
          if (!_chatOpen &&
              _idx != 2 &&
              (ModalRoute.of(context)?.isCurrent ?? true))
            FloatingChatButton(onTap: openChat),
          // Chat drawer overlay
          if (_chatOpen)
            ChatDrawer(
              onClose: () => setState(() {
                _chatOpen = false;
                _chatOpenStoreId = null;
              }),
              openStoreId: _chatOpenStoreId,
            ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: AdaptiveBlur(
          sigma: 16,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppQuality.instance.useBlur ? AppColors.headerGlass : null,
              color: AppQuality.instance.useBlur
                  ? null
                  : const Color(0xF5FFFAFC),
              border: const Border(
                top: BorderSide(color: Color(0x8CFFFFFF), width: 1),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0FB5445A),
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home,              label: 'Home',    selected: _idx == 0, onTap: () => setState(() => _idx = 0)),
                _NavItem(icon: Icons.search_outlined,      activeIcon: Icons.search,             label: 'Search',  selected: _idx == 1, onTap: () => setState(() => _idx = 1)),
                _CartNavItem(count: cartCount,             selected: _idx == 2,                  onTap: () => setState(() => _idx = 2)),
                _NavItem(icon: Icons.receipt_long_outlined,activeIcon: Icons.receipt_long,       label: 'Orders',  selected: _idx == 3, onTap: () => setState(() => _idx = 3)),
                _NavItem(icon: Icons.person_outline,       activeIcon: Icons.person,             label: 'Account', selected: _idx == 4, onTap: () => setState(() => _idx = 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    required this.icon, required this.activeIcon,
    required this.label, required this.selected, required this.onTap,
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
            AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  size: 20,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.roseCta : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartNavItem extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CartNavItem({required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                    size: 20,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                  if (count > 0)
                    Positioned(
                      top: -5, right: -6,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : AppColors.roseCta,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: GoogleFonts.dmSans(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              color: selected ? AppColors.roseCta : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Cart',
              style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.roseCta : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
