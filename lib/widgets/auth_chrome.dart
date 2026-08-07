import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_background.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

/// Layered shadow stack used by the website's auth card.
const List<BoxShadow> authCardShadows = [
  BoxShadow(color: Color(0x14B5445A), blurRadius: 28, offset: Offset(0, 10)),
  BoxShadow(color: Color(0x0F8C64B4), blurRadius: 64, offset: Offset(0, 28)),
];

const Color _authCardFill = Color(0xB3FFFFFF); // rgba(255,255,255,0.7)
const Color _authCardBorder = Color(0xD9FFFFFF); // rgba(255,255,255,0.85)

/// 11px uppercase DM Sans form label, as used on the web auth forms.
TextStyle authLabelStyle() => GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: AppColors.muted,
    );

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text(text.toUpperCase(), style: authLabelStyle()),
    );
  }
}

OutlineInputBorder _authBorder(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

/// Rounded glass input with a pink focus ring.
InputDecoration authInputDecoration({
  String? hint,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(
      fontSize: 13.5,
      color: AppColors.muted.withValues(alpha: 0.7),
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 19, color: AppColors.muted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.62),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    isDense: true,
    border: _authBorder(Colors.white.withValues(alpha: 0.85), 1.2),
    enabledBorder: _authBorder(Colors.white.withValues(alpha: 0.85), 1.2),
    focusedBorder: _authBorder(AppColors.pinkMid.withValues(alpha: 0.85), 1.8),
    errorBorder: _authBorder(AppColors.error.withValues(alpha: 0.6), 1.2),
    focusedErrorBorder: _authBorder(AppColors.error.withValues(alpha: 0.85), 1.8),
    errorStyle: GoogleFonts.dmSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: AppColors.error,
    ),
  );
}

/// Stronger glass panel used for auth forms, topped by a brand gradient band.
class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      blur: 18,
      fill: _authCardFill,
      borderColor: _authCardBorder,
      shadows: authCardShadows,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.brandGradientH),
            child: SizedBox(height: 4, width: double.infinity),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// E-FLORA wordmark plus tagline, optionally preceded by the app logo mark.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({
    super.key,
    this.tagline = 'Fresh blooms, delivered',
    this.showLogo = true,
    this.icon,
  });

  final String tagline;
  final bool showLogo;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showLogo) ...[
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              boxShadow: AppShadows.roseButton,
            ),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 32)
                : ClipOval(
                    child: Container(
                      color: Colors.white,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'E-FLORA',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: 6,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tagline.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Shared page chrome for the auth flow: cream atmosphere, drifting flowers,
/// a glass back/close affordance and a centred, width-capped column.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.leadingIcon = Icons.close_rounded,
    this.onLeadingTap,
    this.padding = const EdgeInsets.fromLTRB(22, 8, 22, 36),
  });

  final List<Widget> children;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: _GlassIconButton(icon: leadingIcon, onTap: onLeadingTap),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: AppShadows.glass,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, size: 19, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }
}

/// Auth page heading: Cormorant title over a muted DM Sans subtitle.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            height: 1.15,
            color: AppColors.charcoal,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Hairline divider with a centred uppercase label.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1,
      color: AppColors.charcoal.withValues(alpha: 0.08),
    );
    return Row(
      children: [
        Expanded(child: line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.muted,
            ),
          ),
        ),
        Expanded(child: line),
      ],
    );
  }
}

/// Underlined pink text link used for the auth cross-links.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: AppColors.roseCta,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.roseCta.withValues(alpha: 0.5),
    );
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.roseCta),
            const SizedBox(width: 6),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}
