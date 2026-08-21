import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'glass.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  if (product.category != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          product.category!.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.labelPink,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  if (!product.hasAnySellableStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.72),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.charcoal.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'OUT OF STOCK',
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                    height: 1.15,
                  ),
                  maxLines: context.responsive.isCompact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.storeName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.storeName!.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelPink,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${product.effectivePrice.toStringAsFixed(2)}',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: context.sp(17),
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepRose,
                              height: 1.1,
                            ),
                          ),
                          if (product.discountPct != null) ...[
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '₱${product.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.badgeGradient,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '${product.discountPct}% off',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildActionButton(context, product),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder({double iconSize = 40}) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.imageWash),
        child: Center(
          child: Icon(
            Icons.local_florist,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      );

  Widget _buildImage() {
    final url = product.primaryImageUrl;

    if (url == null || url.isEmpty) {
      return _placeholder();
    }

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        memCacheHeight: 200,
        maxWidthDiskCache: 200,
        maxHeightDiskCache: 200,
        cacheKey: 'product_${product.id}_home',
        placeholder: (context, url) => DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.imageWash),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('❌ Failed to load image: $url - Error: $error');

          return FutureBuilder<String?>(
            future: Future.value(product.cartImageUrl),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return DecoratedBox(
                  decoration: const BoxDecoration(gradient: AppColors.imageWash),
                  child: CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    fit: BoxFit.cover,
                    memCacheWidth: 150,
                    memCacheHeight: 150,
                    errorWidget: (_, __, ___) => _placeholder(iconSize: 36),
                  ),
                );
              }
              return _placeholder(iconSize: 36);
            },
          );
        },
      ),
    );
  }

  /// Always show quick-add (+) — modal lists OOS options as disabled.
  Widget _buildActionButton(BuildContext context, Product product) {
    final btn = context.s(28).clamp(26.0, 34.0);
    final icon = context.s(15).clamp(13.0, 18.0);

    return GradientCircleButton(
      icon: Icons.add,
      size: btn,
      iconSize: icon,
      onPressed: onAddToCart,
    );
  }
}
