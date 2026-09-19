import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../navigation/floating_nav_metrics.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_confirm_dialog.dart';
import '../../widgets/customer_default_avatar.dart';
import '../../widgets/auth_required_sheet.dart';
import '../orders/orders_screen.dart';
import '../cart/cart_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'help_eflora_screen.dart';
import 'about_eflora_screen.dart';
import '../address/address_list_screen.dart';

const _kDeepRose = Color(0xFFB5445A);
const _kTextCharcoal = Color(0xFF2C2520);
const _kMuted = Color(0xFF9A8D85);
const _kSoftBlush = Color(0xFFFBE9EE);
const _kBorder = Color(0xFFF0DDE2);

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: auth.isLoggedIn
              ? _LoggedInView(user: auth.user!)
              : const _GuestView(),
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AccountHeader(user: null),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _kBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C502846),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CustomerDefaultAvatar(size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'Sign in to your account',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _kTextCharcoal,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access your orders, wishlist, and account settings',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: _kMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    RoseButton(
                      label: 'Sign In',
                      onPressed: () => pushLoginScreen(context),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => pushRegisterScreen(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: _kDeepRose,
                        side: const BorderSide(color: _kDeepRose, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedInView extends StatelessWidget {
  final dynamic user;
  const _LoggedInView({required this.user});

  Future<void> _openDeleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted == true && context.mounted) {
      context.read<AuthProvider>().logout();
      context.read<CartProvider>().reset();
      context.read<WishlistProvider>().reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await CustomConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      icon: Icons.logout_rounded,
      isDestructive: true,
    );
    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();
      context.read<CartProvider>().reset();
      context.read<WishlistProvider>().reset();
      context.read<NotificationProvider>().reset();
    }
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final liveUser = context.watch<AuthProvider>().user ?? user;
    final cartCount = context.watch<CartProvider>().itemCount;
    final notifCount = context.watch<NotificationProvider>().unreadCount;
    final bottomPad = floatingNavScrollClearance(context) + 24;

    return RefreshIndicator(
      color: _kDeepRose,
      onRefresh: () async {
        await Future.wait([
          context.read<AuthProvider>().refreshUser(),
          context.read<NotificationProvider>().load(silent: true),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountHeader(user: liveUser),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ProfileHero(user: liveUser),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: -32,
                      child: _ProfileCard(
                        user: liveUser,
                        onTap: () => _open(context, const EditProfileScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EditProfileButton(
                    onTap: () => _open(context, const EditProfileScreen()),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QuickAccessSection(
                  cartCount: cartCount,
                  notificationCount: notifCount,
                  onOrders: () => _open(context, const OrdersScreen()),
                  onWishlist: () => _open(context, const WishlistScreen()),
                  onCart: () => _open(context, const CartScreen()),
                  onAddresses: () => _open(context, const AddressListScreen()),
                  onPassword: () => _open(context, const ChangePasswordScreen()),
                  onNotifications: () => _open(context, const NotificationsScreen()),
                ),
                const SizedBox(height: 20),
                _SettingsGroup(
                  tiles: [
                    _TileData(
                      icon: Icons.help_outline_rounded,
                      label: 'Help E-FLORA',
                      onTap: () => _open(context, const HelpEfloraScreen()),
                    ),
                    _TileData(
                      icon: Icons.info_outline_rounded,
                      label: 'About E-FLORA',
                      onTap: () => _open(context, const AboutEfloraScreen()),
                    ),
                    if (liveUser.role == 'seller')
                      _TileData(
                        icon: Icons.storefront_rounded,
                        label: 'Seller Dashboard',
                        onTap: () async {
                          final url = Uri.parse(
                            '${ApiService.baseUrl}/login',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    _TileData(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
                if (liveUser.role == 'customer') ...[
                  const SizedBox(height: 18),
                  _DeleteBar(onTap: () => _openDeleteAccount(context)),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'E-FLORA v1.0.0',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final dynamic user;

  const _AccountHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return const EfloraTopBar();
  }
}

class _BannerWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at top-left edge
    path.moveTo(0, 22);
    // Smooth, continuous organic wave across top
    path.cubicTo(w * 0.35, 36, w * 0.70, 6, w, 6);
    // Down the right edge
    path.lineTo(w, h);
    // Straight across bottom so it sits cleanly behind the floating profile card
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ProfileHero extends StatelessWidget {
  final dynamic user;
  const _ProfileHero({required this.user});

  String get _firstName {
    final name = (user?.fullName ?? '').toString().trim();
    if (name.isEmpty) return 'Customer';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 360;

    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Pink Wave-Clipped Banner with Greeting Text and subtle line art
          Positioned.fill(
            child: ClipPath(
              clipper: _BannerWaveClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFB53852),
                      Color(0xFFCD5770),
                      Color(0xFFE58D8C),
                      Color(0xFFF2A79D),
                    ],
                    stops: [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/eflora_profile_line_art.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Positioned(
                      left: isSmallScreen ? 18 : 24,
                      top: 34,
                      right: isSmallScreen ? 140 : 170,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Good Day,',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: isSmallScreen ? 22 : 25,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_firstName!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: isSmallScreen ? 30 : 35,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Flowers make\neverything better 🌼',
                            style: GoogleFonts.dmSans(
                              fontSize: isSmallScreen ? 12.5 : 13.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 2. Flower Bouquet - placed above the banner, unclipped by the wave,
          // extending downward so that the lower foliage & blossoms cascade
          // behind the top-right of the user info card (which sits at bottom: -32)
          Positioned(
            right: isSmallScreen ? -8 : -6,
            top: 15,
            width: isSmallScreen ? 230 : 255,
            child: Image.asset(
              'assets/images/eflora_profile_header_bouquet_transparent.png',
              key: const ValueKey('profile_bouquet_transparent_v1'),
              fit: BoxFit.contain,
              alignment: Alignment.topRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onTap;

  const _ProfileCard({required this.user, required this.onTap});

  String get _roleLabel {
    final role = (user.role ?? 'customer').toString();
    if (role.isEmpty) return 'Customer';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl as String?;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmall = screenWidth < 360;
    final avatarSize = isSmall ? 52.0 : 60.0;

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF3E6EA), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 12 : 16,
            vertical: isSmall ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF502846).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF4C5CE),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _PlaceholderAvatar(size: avatarSize - 4),
                        )
                      : _PlaceholderAvatar(size: avatarSize - 4),
                ),
              ),
              SizedBox(width: isSmall ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ?? 'Customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: isSmall ? 18.5 : 20,
                        fontWeight: FontWeight.w700,
                        color: _kTextCharcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: isSmall ? 12 : 12.5,
                        color: _kMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kSoftBlush,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _roleLabel,
                        style: GoogleFonts.dmSans(
                          fontSize: isSmall ? 10.5 : 11,
                          fontWeight: FontWeight.w700,
                          color: _kDeepRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: _kDeepRose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  final double size;
  const _PlaceholderAvatar({this.size = 56});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return CustomerDefaultAvatar(size: size, seed: user?.id ?? user?.fullName);
  }
}

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSoftBlush,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: _kDeepRose,
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _kDeepRose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  final int cartCount;
  final int notificationCount;
  final VoidCallback onOrders;
  final VoidCallback onWishlist;
  final VoidCallback onCart;
  final VoidCallback onAddresses;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;

  const _QuickAccessSection({
    required this.cartCount,
    this.notificationCount = 0,
    required this.onOrders,
    required this.onWishlist,
    required this.onCart,
    required this.onAddresses,
    required this.onPassword,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickAccessItem(
        icon: Icons.receipt_long_outlined,
        label: 'My Orders',
        onTap: onOrders,
      ),
      _QuickAccessItem(
        icon: Icons.favorite_border_rounded,
        label: 'Wishlist',
        onTap: onWishlist,
      ),
      _QuickAccessItem(
        icon: Icons.shopping_bag_outlined,
        label: 'My Cart',
        onTap: onCart,
        badge: cartCount,
      ),
      _QuickAccessItem(
        icon: Icons.location_on_outlined,
        label: 'My Addresses',
        onTap: onAddresses,
      ),
      _QuickAccessItem(
        icon: Icons.lock_outline_rounded,
        label: 'Change Password',
        onTap: onPassword,
      ),
      _QuickAccessItem(
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        onTap: onNotifications,
        badge: notificationCount,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _kTextCharcoal,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 340;
            final gap = isSmall ? 8.0 : 10.0;
            const cols = 3;
            final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final h = isSmall ? 98.0 : 102.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(width: w, height: h, child: item),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF4E5E9), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08502846),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kSoftBlush,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: _kDeepRose,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC83757),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _kTextCharcoal,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileData {
  const _TileData({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SettingsGroup extends StatelessWidget {
  final List<_TileData> tiles;
  const _SettingsGroup({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _kBorder, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08502846),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: _kBorder,
                  indent: 52,
                ),
              _SettingsTile(data: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final _TileData data;
  const _SettingsTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _kSoftBlush,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, size: 17, color: _kDeepRose),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kTextCharcoal,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFD4788A),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteBar extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5A8A8), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Color(0xFFC94343),
              ),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC94343),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirmCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _ready =>
      _confirmCtrl.text.trim().toUpperCase() == 'DELETE' &&
      _passwordCtrl.text.isNotEmpty &&
      !_submitting;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ApiService.deleteAccount(
      password: _passwordCtrl.text,
      confirmation: _confirmCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.errorMessage ?? 'Could not delete the account.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDF9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Delete your account?',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _kTextCharcoal,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This cannot be undone. You will be signed out and will not be able to log in again.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _kTextCharcoal,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                '• Your name, email, phone, photo, addresses, cart, wishlist, and notifications will be removed.\n'
                '• Completed, cancelled, and refunded orders stay in shop records with your delivery details removed.\n'
                '• Ratings you already submitted stay, shown as a deleted customer.\n'
                '• You cannot delete while an order is still being prepared or delivered.',
                style: GoogleFonts.dmSans(fontSize: 11.5, color: _kMuted, height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmCtrl,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                labelStyle: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
                floatingLabelStyle: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              enabled: !_submitting,
              obscureText: true,
              style: GoogleFonts.dmSans(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: GoogleFonts.dmSans(fontSize: 12.5, color: _kMuted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kDeepRose),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: _ready ? _submit : null,
          child: Text(
            _submitting ? 'Deleting…' : 'Delete account',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _ready ? AppColors.error : _kMuted,
            ),
          ),
        ),
      ],
    );
  }
}

