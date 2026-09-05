import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/rider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'rider_status_style.dart';

/// Shared visual tokens for the rider module revamp.
class RiderUi {
  RiderUi._();

  static BoxDecoration get card => BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F502846),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration get softPanel => BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.md),
      );

  static TextStyle get title => GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      );

  static TextStyle get section => GoogleFonts.cormorantGaramond(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.charcoal,
      );
}

class RiderPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const RiderPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.centerTitle = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      title: subtitle == null
          ? Text(title, style: RiderUi.title.copyWith(fontSize: 20))
          : Align(
              alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment:
                    centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: RiderUi.title.copyWith(fontSize: 20)),
                  Text(
                    subtitle!,
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
      actions: actions,
    );
  }
}

/// Circular store logo for rider headers and profile.
class RiderStoreLogoAvatar extends StatelessWidget {
  const RiderStoreLogoAvatar({
    super.key,
    this.logoUrl,
    this.size = 36,
  });

  final String? logoUrl;
  final double size;

  String? get _resolvedUrl {
    final raw = logoUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return ApiService.assetUrl('/static/uploads/seller_logos/$raw');
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cream,
        border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              placeholder: (_, __) => Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.deepRose,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.cream,
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_rounded,
        size: size * 0.48,
        color: AppColors.dustyRose,
      ),
    );
  }
}

class RiderStatTile extends StatelessWidget {
  const RiderStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: RiderUi.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderGradientButton extends StatelessWidget {
  const RiderGradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadius.pill);
    final disabled = onTap == null && !loading;
    final gradient = disabled
        ? LinearGradient(
            colors: [
              AppColors.muted.withValues(alpha: 0.35),
              AppColors.muted.withValues(alpha: 0.25),
            ],
          )
        : AppColors.brandGradient;

    Widget button = ClipRRect(
      borderRadius: borderRadius,
      child: Material(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          splashColor: Colors.white.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(gradient: gradient),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (!disabled) {
      button = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.roseCta.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: button,
      );
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class RiderOutlineButton extends StatelessWidget {
  const RiderOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.arrow_forward, size: 16, color: AppColors.charcoal),
      label: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class RiderOrderThumbnail extends StatelessWidget {
  const RiderOrderThumbnail({super.key, required this.order, this.size = 56});

  final RiderOrder order;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = order.items
        .map((i) => i.imageUrl)
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF8D0DC),
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : const Icon(Icons.local_florist, color: AppColors.dustyRose),
      ),
    );
  }
}

class RiderDeliveryTimeline extends StatelessWidget {
  const RiderDeliveryTimeline({super.key, required this.status});

  final String status;

  int get _step {
    switch (status) {
      case 'on_delivery':
      case 'picked_up':
        return 2;
      case 'delivered':
      case 'completed':
        return 3;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _TimelineNode(label: 'Store', active: _step >= 1, done: _step > 1),
          Expanded(child: _TimelineLine(filled: _step > 1)),
          _TimelineNode(label: 'Rider', active: _step >= 2, done: _step > 2),
          Expanded(child: _TimelineLine(filled: _step > 2)),
          _TimelineNode(label: 'Customer', active: _step >= 3, done: false),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.successGreen
        : active
            ? AppColors.roseCta
            : AppColors.muted.withValues(alpha: 0.35);
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.charcoal : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: filled
            ? AppColors.brandGradientH
            : LinearGradient(
                colors: [
                  AppColors.muted.withValues(alpha: 0.15),
                  AppColors.muted.withValues(alpha: 0.15),
                ],
              ),
      ),
    );
  }
}

class RiderEmptyState extends StatelessWidget {
  const RiderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted.withValues(alpha: 0.28)),
            const SizedBox(height: 16),
            Text(title, style: RiderUi.title.copyWith(color: AppColors.muted)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.muted.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderSegmentedTabs extends StatelessWidget {
  const RiderSegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.warmWhite.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class RiderStatusChip extends StatelessWidget {
  const RiderStatusChip({super.key, required this.order});

  final RiderOrder order;

  @override
  Widget build(BuildContext context) {
    return RiderStatusBadge(
      label: order.statusLabel,
      style: RiderStatusStyle.of(order.status),
    );
  }
}

class RiderInfoLine extends StatelessWidget {
  const RiderInfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.maxLines = 2,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.muted.withValues(alpha: 0.65)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.charcoal),
          ),
        ),
      ],
    );
  }
}

class RiderGradientStatusBanner extends StatelessWidget {
  const RiderGradientStatusBanner({
    super.key,
    required this.order,
    this.subtitle,
  });

  final RiderOrder order;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseCta.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.status == 'on_delivery'
                  ? Icons.delivery_dining_rounded
                  : order.status == 'delivered'
                      ? Icons.check_circle_rounded
                      : Icons.local_florist_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusLabel.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
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

/// Full-screen pinch-to-zoom viewer for fulfillment / proof photos.
class RiderPhotoZoom {
  RiderPhotoZoom._();

  static void show(BuildContext context, String imageUrl, {String? caption}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = size.width - 40;
        final maxH = size.height * 0.78;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Material(
                      color: AppColors.charcoal,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          width: maxW,
                          placeholder: (_, __) => SizedBox(
                            width: maxW,
                            height: maxH * 0.5,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                          errorWidget: (_, __, ___) => SizedBox(
                            width: maxW,
                            height: 200,
                            child: Center(
                              child: Text(
                                'Unable to load image',
                                style: GoogleFonts.dmSans(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Close',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Seller + rider fulfillment photos with a consistent gallery layout.
class RiderFulfillmentPhotosSection extends StatelessWidget {
  const RiderFulfillmentPhotosSection({
    super.key,
    this.sellerProofUrl,
    this.deliveryProofUrl,
    this.deliveryProof2Url,
    required this.onPhotoTap,
  });

  final String? sellerProofUrl;
  final String? deliveryProofUrl;
  final String? deliveryProof2Url;
  final ValueChanged<String> onPhotoTap;

  bool get _hasSeller =>
      sellerProofUrl != null && sellerProofUrl!.trim().isNotEmpty;

  bool get _hasRider =>
      (deliveryProofUrl != null && deliveryProofUrl!.trim().isNotEmpty) ||
      (deliveryProof2Url != null && deliveryProof2Url!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasSeller && !_hasRider) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fulfillment Photos', style: RiderUi.section),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: RiderUi.card,
          child: Column(
            children: [
              if (_hasSeller) ...[
                _FulfillmentGroupHeader(
                  icon: Icons.storefront_outlined,
                  tint: AppColors.sage,
                  title: 'Store preparation',
                  subtitle: 'Finished product photo from the seller',
                ),
                const SizedBox(height: 12),
                _FulfillmentPhotoTile(
                  imageUrl: sellerProofUrl!,
                  label: 'Seller photo',
                  tall: true,
                  onTap: () => onPhotoTap(sellerProofUrl!),
                ),
              ],
              if (_hasSeller && _hasRider) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.border),
                ),
              ],
              if (_hasRider) ...[
                _FulfillmentGroupHeader(
                  icon: Icons.delivery_dining_outlined,
                  tint: AppColors.deepRose,
                  title: 'Delivery proof',
                  subtitle: 'Photos captured when marking delivered',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (deliveryProofUrl != null &&
                        deliveryProofUrl!.trim().isNotEmpty) ...[
                      Expanded(
                        child: _FulfillmentPhotoTile(
                          imageUrl: deliveryProofUrl!,
                          label: 'Proof 1',
                          onTap: () => onPhotoTap(deliveryProofUrl!),
                        ),
                      ),
                      if (deliveryProof2Url != null &&
                          deliveryProof2Url!.trim().isNotEmpty)
                        const SizedBox(width: 10),
                    ],
                    if (deliveryProof2Url != null &&
                        deliveryProof2Url!.trim().isNotEmpty)
                      Expanded(
                        child: _FulfillmentPhotoTile(
                          imageUrl: deliveryProof2Url!,
                          label: 'Proof 2',
                          onTap: () => onPhotoTap(deliveryProof2Url!),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FulfillmentGroupHeader extends StatelessWidget {
  const _FulfillmentGroupHeader({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FulfillmentPhotoTile extends StatelessWidget {
  const _FulfillmentPhotoTile({
    required this.imageUrl,
    required this.label,
    required this.onTap,
    this.tall = false,
  });

  final String imageUrl;
  final String label;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A502846),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
              aspectRatio: tall ? 16 / 9 : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.cream,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.deepRose,
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: tall ? 32 : 24,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
