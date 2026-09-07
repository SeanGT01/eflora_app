import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Branded default when a user has no profile photo.
/// Square artwork sits inside a circular blush ring — the photo is not clipped.
class CustomerDefaultAvatar extends StatelessWidget {
  final double size;
  final bool showRing;

  const CustomerDefaultAvatar({
    super.key,
    required this.size,
    this.showRing = true,
  });

  static const assetPath = 'assets/images/default_customer_avatar.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: showRing
            ? Border.all(color: AppColors.blush, width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
