import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/app_quality.dart';
import '../navigation/floating_nav_metrics.dart';
import '../theme/app_theme.dart';
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
  static void switchTab(BuildContext context, int index, {String? targetOrderStatus, int? targetOrderId}) {
    context.findAncestorStateOfType<MainShellState>()?.switchToTab(index, targetOrderStatus: targetOrderStatus, targetOrderId: targetOrderId);
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

  void switchToTab(int index, {String? targetOrderStatus, int? targetOrderId}) {
    setState(() {
      _idx = index;
      _chatOpen = false;
      _chatOpenStoreId = null;
    });
    if (index == 3) {
      OrdersScreen.reload(targetStatus: targetOrderStatus, targetOrderId: targetOrderId);
    }
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
    final showChatFab = !_chatOpen &&
        _idx != 2 &&
        (ModalRoute.of(context)?.isCurrent ?? true);

    // FAB sits in a screen-level Stack so bottom inset is measured against the
    // full scaffold (nav + home indicator), not the body slot alone.
    return Stack(
      children: [
        Scaffold(
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
            ],
          ),
        ),
        _FloatingNavBar(
          selectedIndex: _idx,
          cartCount: cartCount,
          onSelect: (i) => switchToTab(i),
        ),
        // Keep the drawer above the floating navbar while it is open.
        if (_chatOpen)
          Material(
            type: MaterialType.transparency,
            child: ChatDrawer(
              onClose: () => setState(() {
                _chatOpen = false;
                _chatOpenStoreId = null;
              }),
              openStoreId: _chatOpenStoreId,
            ),
          ),
        // Floating chat button — same role as website `#chat-fab`.
        // Hidden on Cart (checkout bar) and while a modal route is on top.
        if (showChatFab)
          FloatingChatButton(
            onTap: openChat,
            bottomNavClearance: kFloatingNavBottomGap + kFloatingNavBarHeight + 8,
          ),
      ],
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.cartCount,
    required this.onSelect,
  });

  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelect;

  static const _radius = 26.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom + kFloatingNavBottomGap;
    return Positioned(
      left: kFloatingNavHorizontalInset,
      right: kFloatingNavHorizontalInset,
      bottom: bottom,
      child: Material(
        color: Colors.white,
        elevation: 12,
        shadowColor: const Color(0x40000000),
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: kFloatingNavBarHeight,
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
                isFirst: true,
              ),
              _NavItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: 'Search',
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Cart',
                selected: selectedIndex == 2,
                badge: cartCount,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Orders',
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Account',
                selected: selectedIndex == 4,
                onTap: () => onSelect(4),
                isLast: true,
              ),
            ],
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
  final int badge;
  final bool isFirst;
  final bool isLast;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.isFirst = false,
    this.isLast = false,
  });

  static const _inactive = Color(0xFF757575);
  static const _pill = Color(0xFFF8D5DE);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.roseCta : _inactive;
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotW = constraints.maxWidth;
          final pillW = selected
              ? (isFirst || isLast ? slotW - 3 : slotW - 6).clamp(44.0, 72.0)
              : 0.0;
          return InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: isFirst
                      ? Alignment.centerLeft
                      : isLast
                          ? Alignment.centerRight
                          : Alignment.center,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    opacity: selected ? 1.0 : 0.0,
                    child: Container(
                      width: pillW,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: _pill,
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Icon(
                            selected ? activeIcon : icon,
                            size: 20,
                            color: color,
                          ),
                        ),
                        if (badge > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: const BoxDecoration(
                                color: AppColors.roseCta,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  badge > 9 ? '9+' : '$badge',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
