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

const _kHeader = AppColors.deepRose;
const _kText = AppColors.charcoal;
const _kMuted = AppColors.muted;
const _kDivider = AppColors.border;

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
          body: auth.isLoggedIn ? _LoggedInView(user: auth.user!) : const _GuestView(),
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
        const _AccountTitleBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomerDefaultAvatar(size: 80),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in to your account',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Access your orders, wishlist, and account settings',
                    style: GoogleFonts.dmSans(fontSize: 13, color: _kMuted),
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
                      minimumSize: const Size(double.infinity, 50),
                      foregroundColor: _kHeader,
                      side: const BorderSide(color: _kHeader),
                    ),
                    child: const Text('Create Account'),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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
    final bottomPad = floatingNavScrollClearance(context);

    return RefreshIndicator(
      color: _kHeader,
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
              children: [
                const _AccountTitleBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ProfileHeader(user: liveUser),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EditBar(
                    onEdit: () => _open(context, const EditProfileScreen()),
                    onSignOut: () => _signOut(context),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ShortcutGrid(
                  cartCount: cartCount,
                  notificationCount: notifCount,
                  onOrders: () => _open(context, const OrdersScreen()),
                  onWishlist: () => _open(context, const WishlistScreen()),
                  onCart: () => _open(context, const CartScreen()),
                  onAddresses: () => _open(context, const AddressListScreen()),
                  onPassword: () => _open(context, const ChangePasswordScreen()),
                  onNotifications: () => _open(context, const NotificationsScreen()),
                ),
                const SizedBox(height: 14),
                _SettingsGroup(
                  tiles: [
                    _TileData(
                      icon: Icons.help_outline,
                      label: 'Help E-FLORA',
                      onTap: () => _open(context, const HelpEfloraScreen()),
                    ),
                    _TileData(
                      icon: Icons.info_outline,
                      label: 'About E-FLORA',
                      onTap: () => _open(context, const AboutEfloraScreen()),
                    ),
                    if (liveUser.role == 'seller')
                      _TileData(
                        icon: Icons.storefront_rounded,
                        label: 'Seller Dashboard',
                        onTap: () async {
                          final url = Uri.parse(
                            'https://eflora-system-production.up.railway.app/login',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                  ],
                ),
                if (liveUser.role == 'customer') ...[
                  const SizedBox(height: 14),
                  _DeleteBar(onTap: () => _openDeleteAccount(context)),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'E-FLORA v1.0.0',
                    style: GoogleFonts.dmSans(fontSize: 11, color: _kMuted),
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

class _AccountTitleBar extends StatelessWidget {
  const _AccountTitleBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'My Account',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.charcoal,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _IosGlyph extends StatelessWidget {
  const _IosGlyph({required this.icon, this.size = 28, this.iconSize = 15});
  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.blush.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: iconSize, color: AppColors.deepRose),
    );
  }
}

BoxDecoration _groupedCard() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final dynamic user;

  String get _roleLabel {
    final role = (user.role ?? 'customer').toString();
    if (role.isEmpty) return 'Customer';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl as String?;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      decoration: _groupedCard(),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          if (hasPhoto)
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _PlaceholderAvatar(),
                ),
              ),
            )
          else
            const _PlaceholderAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: _kMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.blush.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _roleLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepRose,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar();

  @override
  Widget build(BuildContext context) {
    return const CustomerDefaultAvatar(size: 56);
  }
}

class _EditBar extends StatelessWidget {
  const _EditBar({required this.onEdit, required this.onSignOut});
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _groupedCard(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _IosGlyph(icon: Icons.edit_outlined, size: 26, iconSize: 14),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Edit Profile',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _kText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 0.5, color: _kDivider),
            Expanded(
              child: InkWell(
                onTap: onSignOut,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _IosGlyph(icon: Icons.logout, size: 26, iconSize: 14),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sign Out',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _kText,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: _kMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({
    required this.cartCount,
    this.notificationCount = 0,
    required this.onOrders,
    required this.onWishlist,
    required this.onCart,
    required this.onAddresses,
    required this.onPassword,
    required this.onNotifications,
  });

  final int cartCount;
  final int notificationCount;
  final VoidCallback onOrders;
  final VoidCallback onWishlist;
  final VoidCallback onCart;
  final VoidCallback onAddresses;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final items = [
      _GridItem(icon: Icons.receipt_long_outlined, label: 'My Orders', onTap: onOrders),
      _GridItem(icon: Icons.favorite_border, label: 'Wishlist', onTap: onWishlist),
      _GridItem(icon: Icons.shopping_bag_outlined, label: 'My Cart', onTap: onCart, badge: cartCount),
      _GridItem(icon: Icons.location_on_outlined, label: 'My Addresses', onTap: onAddresses),
      _GridItem(icon: Icons.lock_outline, label: 'Change Password', onTap: onPassword),
      _GridItem(icon: Icons.notifications_none, label: 'Notifications', onTap: onNotifications, badge: notificationCount),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cols = constraints.maxWidth < 330 ? 2 : 3;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: w, height: 82, child: item),
          ],
        );
      },
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _IosGlyph(icon: icon),
                  if (badge > 0)
                    Positioned(
                      top: -5,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: AppColors.dustyRose,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: GoogleFonts.dmSans(
                              fontSize: 8.5,
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
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _kText,
                  height: 1.2,
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
  const _SettingsGroup({required this.tiles});
  final List<_TileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _groupedCard(),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 0.5, color: _kDivider, indent: 48),
            _SettingsTile(data: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.blush.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.icon, size: 15, color: AppColors.deepRose),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kText,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kMuted),
          ],
        ),
      ),
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _groupedCard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Delete Account',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
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
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This cannot be undone. You will be signed out and will not be able to log in again.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '• Your name, email, phone, photo, addresses, cart, wishlist, and notifications will be removed.\n'
              '• Completed, cancelled, and refunded orders stay in shop records with your delivery details removed.\n'
              '• Ratings you already submitted stay, shown as a deleted customer.\n'
              '• You cannot delete while an order is still being prepared or delivered.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              enabled: !_submitting,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _ready ? _submit : null,
          child: Text(
            _submitting ? 'Deleting…' : 'Delete account',
            style: TextStyle(
              color: _ready ? AppColors.error : AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}
