import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/wishlist.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../utils/responsive.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../product/product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<WishlistProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Wishlist',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.charcoal,
              letterSpacing: 0.3,
            ),
          ),
        ),
        body: !auth.isLoggedIn
            ? const Center(child: Text('Sign in to view your wishlist'))
            : RefreshIndicator(
                color: AppColors.deepRose,
                onRefresh: () => context.read<WishlistProvider>().load(),
                child: wishlist.loading && wishlist.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: CircularProgressIndicator(
                              color: AppColors.deepRose,
                            ),
                          ),
                        ],
                      )
                    : wishlist.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            children: [
                              const SizedBox(height: 48),
                              Icon(Icons.favorite_border_rounded,
                                  size: 56,
                                  color: AppColors.deepRose.withValues(alpha: 0.45)),
                              const SizedBox(height: 16),
                              Text(
                                'No saved items yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the heart on a product to save it here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  context.responsive.productCrossAxisCount,
                              mainAxisSpacing:
                                  context.responsive.productMainSpacing,
                              crossAxisSpacing:
                                  context.responsive.productCrossSpacing,
                              childAspectRatio:
                                  context.responsive.productAspectRatio,
                            ),
                            itemCount: wishlist.items.length,
                            itemBuilder: (_, i) =>
                                _WishlistCard(item: wishlist.items[i]),
                          ),
              ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final WishlistItem item;
  const _WishlistCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(productId: item.productId),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.warmWhite,
                                child: const Icon(Icons.local_florist,
                                    color: Color(0x33B5445A), size: 40),
                              ),
                            )
                          : Container(
                              color: AppColors.warmWhite,
                              child: const Icon(Icons.local_florist,
                                  color: Color(0x33B5445A), size: 40),
                            ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 10.5,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 36,
                            child: Text(
                              item.productName ?? item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.charcoal,
                                height: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 16,
                            child: Text(
                              (item.variantName != null &&
                                      item.variantName!.isNotEmpty)
                                  ? item.variantName!
                                  : ' ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppColors.deepRose,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₱${item.price.toStringAsFixed(2)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 1,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final err = await context
                        .read<WishlistProvider>()
                        .removeItem(item.id);
                    if (!context.mounted) return;
                    if (err != null) {
                      showToast(context, err, isError: true);
                    } else {
                      showToast(context, 'Removed from wishlist');
                    }
                  },
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 13,
                      color: Color(0xFFC0392B),
                    ),
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
