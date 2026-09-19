import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Branded cute flower avatar when a user has no custom profile photo.
/// Deterministically selects 1 of 6 cute pastel flower colors based on userId / name / seed.
class CustomerDefaultAvatar extends StatelessWidget {
  final double size;
  final bool showRing;
  final dynamic seed; // int userId or String name/id

  const CustomerDefaultAvatar({
    super.key,
    required this.size,
    this.showRing = true,
    this.seed,
  });

  static const List<String> _colorKeys = [
    'pink',
    'lavender',
    'peach',
    'yellow',
    'blue',
    'mint',
  ];

  static const List<Color> _ringColors = [
    Color(0xFFF8BBD0), // Blossom Pink
    Color(0xFFD1C4E9), // Lavender Purple
    Color(0xFFFFCCBC), // Peach Coral
    Color(0xFFFFF59D), // Buttercup Yellow
    Color(0xFFB3E5FC), // Sky Blue
    Color(0xFFC8E6C9), // Sage Mint
  ];

  static int resolveIndex(dynamic seed) {
    if (seed == null) return 0;
    if (seed is int) return seed.abs() % _colorKeys.length;
    final str = seed.toString().trim();
    if (str.isEmpty) return 0;
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = (hash * 31 + str.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash % _colorKeys.length;
  }

  static String getAssetFor(dynamic seed) {
    final idx = resolveIndex(seed);
    return 'assets/images/default_customer_avatar_${_colorKeys[idx]}.svg';
  }

  @override
  Widget build(BuildContext context) {
    final idx = resolveIndex(seed);
    final asset = 'assets/images/default_customer_avatar_${_colorKeys[idx]}.svg';
    final ringColor = _ringColors[idx];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showRing
            ? Border.all(color: ringColor, width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

