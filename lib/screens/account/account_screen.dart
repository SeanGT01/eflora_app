import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
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

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('My Account'),
        ),
        body: auth.isLoggedIn ? _LoggedInView(user: auth.user!) : _GuestView(),
      ),
    );
  }
}

// ── Guest view ────────────────────────────────────────────────────────────────
class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.dustyRose.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.dustyRose.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.person_outline,
                  size: 38, color: AppColors.dustyRose),
            ),
            const SizedBox(height: 20),
            Text('Sign in to your account',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Access your orders, wishlist, and account settings',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            RoseButton(
              label: 'Sign In',
              onPressed: () => pushLoginScreen(context),
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => pushRegisterScreen(context),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logged-in view ────────────────────────────────────────────────────────────
class _LoggedInView extends StatelessWidget {
  final dynamic user;
  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context) {
    // Prefer live AuthProvider user so avatar updates after login refresh
    final liveUser = context.watch<AuthProvider>().user ?? user;
    return RefreshIndicator(
      color: AppColors.deepRose,
      onRefresh: () => context.read<AuthProvider>().refreshUser(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildProfileCard(context, liveUser),
          const SizedBox(height: 20),
          _buildMenuSection(context, 'Shopping', [
            _MenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'My Orders',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()))),
            _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()))),
            _MenuItem(
                icon: Icons.shopping_bag_outlined,
                label: 'My Cart',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CartScreen()))),
          ]),
          const SizedBox(height: 12),
          _buildMenuSection(context, 'Account', [
            _MenuItem(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()))),
            _MenuItem(
                icon: Icons.location_on_outlined,
                label: 'My Addresses',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddressListScreen()))),
            _MenuItem(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen()))),
            if (liveUser.role == 'seller')
              _MenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Seller Dashboard',
                  color: AppColors.sage,
                  onTap: () async {
                    final url = Uri.parse(
                        'https://eflora-system-production.up.railway.app/login');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  }),
          ]),
          const SizedBox(height: 12),
          _buildMenuSection(context, 'More', [
            _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()))),
            _MenuItem(
                icon: Icons.help_outline,
                label: 'Help E-FLORA',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpEfloraScreen()))),
            _MenuItem(
                icon: Icons.info_outline,
                label: 'About E-FLORA',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutEfloraScreen()))),
            _MenuItem(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              color: const Color(0xFFc0392b),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Color(0xFFc0392b))),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  context.read<AuthProvider>().logout();
                  context.read<CartProvider>().reset();
                  context.read<WishlistProvider>().reset();
                }
              },
            ),
          ]),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'E-FLORA v1.0.0',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic user) {
    final avatarUrl = user.avatarUrl;
    return GlassCard(
      tinted: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.blushGradient,
              border: Border.all(color: AppColors.glassBorder, width: 1.5),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultProfileAvatar(),
                    )
                  : _defaultProfileAvatar(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultProfileAvatar() {
    return const CustomerDefaultAvatar(size: 64);
  }

  Widget _buildMenuSection(
      BuildContext context, String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.dmSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                letterSpacing: 0.15),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.lg,
          child: Column(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 52),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: item.color == null
                            ? LinearGradient(
                                colors: [
                                  AppColors.roseCta.withValues(alpha: 0.18),
                                  AppColors.purpleEnd.withValues(alpha: 0.12),
                                ],
                              )
                            : null,
                        color: item.color?.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(item.icon,
                          size: 18, color: item.color ?? AppColors.roseCta),
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.color ?? AppColors.charcoal,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.muted),
                    onTap: item.onTap,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
}
