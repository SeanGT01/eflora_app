import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Branded florist default when a customer has no profile photo.
class CustomerDefaultAvatar extends StatelessWidget {
  final double size;

  const CustomerDefaultAvatar({super.key, required this.size});

  static const assetPath = 'assets/images/default_customer_avatar.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: SvgPicture.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
