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
    this.flat = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return child;
    }
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
    final compact = MediaQuery.sizeOf(context).height < 720 ||
        MediaQuery.sizeOf(context).width < 380;
    final markSize = compact ? 52.0 : 68.0;

    return Column(
      children: [
        if (showLogo) ...[
          Container(
            width: markSize,
            height: markSize,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              boxShadow: AppShadows.roseButton,
            ),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: compact ? 26 : 32)
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
          SizedBox(height: compact ? 10 : 16),
        ],
        Text(
          'E-FLORA',
          style: GoogleFonts.cormorantGaramond(
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w500,
            letterSpacing: compact ? 4 : 6,
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

const LinearGradient _authHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFC24E68),
    Color(0xFFD878A0),
    Color(0xFFB888D0),
  ],
  stops: [0.0, 0.45, 1.0],
);

/// Pink marketing header used at the top of the phone auth sheet.
class AuthHeroBanner extends StatelessWidget {
  const AuthHeroBanner({
    super.key,
    required this.eyebrow,
    required this.headline,
    this.description,
  });

  final String eyebrow;
  final InlineSpan headline;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB888D0).withValues(alpha: 0.35),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.paddingOf(context).top + 16,
              22,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-FLORA',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  eyebrow.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  headline,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    height: 1.08,
                    color: Colors.white,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
    );
  }
}

/// Shared page chrome for the auth flow: cream atmosphere, drifting flowers,
/// a glass back/close affordance and a centred, width-capped column.
/// On phone widths, this becomes a bottom sheet with an optional pink hero.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.hero,
    this.leadingIcon = Icons.close_rounded,
    this.onLeadingTap,
    this.padding = const EdgeInsets.fromLTRB(22, 8, 22, 36),
  });

  final List<Widget> children;
  final Widget? hero;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final EdgeInsetsGeometry padding;

  bool _sheetLayout(Size size) => size.width < 960 && hero != null;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_sheetLayout(size)) {
      return _buildSheet(context, size);
    }

    final compact = size.width < 400 || size.height < 720;
    final hPad = compact ? 16.0 : 22.0;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  compact ? 4 : 8,
                  hPad,
                  compact ? 20 : 36,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 24 : 44),
                    maxWidth: size.width >= 900 ? 480 : 440,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, Size size) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _authHeroGradient),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: hero!),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Material(
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: const Color(0x2E5A2850),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      28,
                      22,
                      24 + bottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: topInset + 8,
            right: 12,
            child: _GlassIconButton(
              icon: leadingIcon,
              onTap: onLeadingTap,
              light: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap, this.light = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: light
                ? Colors.white.withValues(alpha: 0.45)
                : AppColors.glassBorder,
          ),
          boxShadow: light ? null : AppShadows.glass,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              size: 19,
              color: light ? Colors.white : AppColors.charcoal,
            ),
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
            fontSize: MediaQuery.sizeOf(context).width < 380 ? 28 : 36,
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
