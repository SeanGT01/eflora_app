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
      blur: 0,
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
                  _buildImage(context),
                  if (product.discountPct != null && product.hasAnySellableStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.badgeGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${product.discountPct}% OFF',
                          style: GoogleFonts.dmSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
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
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AutoFitProductName(
                  name: product.name,
                  maxHeight: context.sp(30),
                  maxLines: 2,
                  baseStyle: GoogleFonts.cormorantGaramond(
                    fontSize: context.sp(14.0).clamp(13.0, 15.5),
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                    height: 1.15,
                  ),
                ),
                if (product.storeName != null && product.storeName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Center(
                    child: Text(
                      product.storeName!.trim().toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: context.sp(8.5).clamp(8.0, 9.5),
                        fontWeight: FontWeight.w700,
                        color: AppColors.labelPink,
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₱${product.effectivePrice.toStringAsFixed(2)}',
                              style: GoogleFonts.dmSans(
                                fontSize: context.sp(16.5).clamp(15.0, 18.0),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8B1832),
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (product.discountPct != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: GoogleFonts.dmSans(
                                  fontSize: context.sp(11.0).clamp(10.0, 12.0),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                  decoration: TextDecoration.lineThrough,
                                  decorationThickness: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _buildImage(BuildContext context) {
    final url = product.primaryImageUrl;

    if (url == null || url.isEmpty) {
      return _placeholder();
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (180 * dpr).round().clamp(280, 600);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        alignment: const Alignment(0.0, -0.2),
        filterQuality: FilterQuality.high,
        memCacheWidth: cachePx,
        maxWidthDiskCache: cachePx,
        cacheKey: 'product_${product.id}_card_orig',
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

/// Dynamically scales and wraps product names so they are not cut off by ellipsis,
/// center-aligns the text across up to 3 lines, and keeps an exact fixed height slot
/// so all product cards stay perfectly uniform.
class _AutoFitProductName extends StatelessWidget {
  final String name;
  final TextStyle baseStyle;
  final double maxHeight;
  final int maxLines;

  const _AutoFitProductName({
    required this.name,
    required this.baseStyle,
    required this.maxHeight,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0) return SizedBox(height: maxHeight);

        final startSize = baseStyle.fontSize ?? 14.0;
        const minSize = 10.0;

        double bestSize = minSize;
        for (double size = startSize; size >= minSize; size -= 0.5) {
          final tp = TextPainter(
            text: TextSpan(
              text: name,
              style: baseStyle.copyWith(fontSize: size),
            ),
            maxLines: maxLines,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);

          if (!tp.didExceedMaxLines && tp.height <= maxHeight) {
            bestSize = size;
            break;
          }
        }

        return SizedBox(
          height: maxHeight,
          width: maxWidth,
          child: Center(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(
                fontSize: bestSize,
                height: 1.15,
              ),
              maxLines: maxLines,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

