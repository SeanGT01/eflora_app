import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Interactive chat card for Custom Arrangement Request Tickets.
/// Follows the signature eFlowers luxury floral aesthetic with:
/// - Crisp, unbroken outer border and rounded corners
/// - Full-bleed arrangement image header with tap-to-zoom capability
/// - Clean header bar without image placeholder when no image is uploaded
/// - Floating / integrated status & live countdown badges
/// - Cormorant Garamond floral typography & base price strip
/// - Signature brand gradient CTA button.
class ChatCustomTicketCard extends StatefulWidget {
  final CustomQuoteTicketContext ticket;
  final bool isSent;
  final VoidCallback? onReviewPressed;
  final VoidCallback? onViewOrderPressed;
  final bool showViewOrder;

  const ChatCustomTicketCard({
    super.key,
    required this.ticket,
    required this.isSent,
    this.onReviewPressed,
    this.onViewOrderPressed,
    this.showViewOrder = true,
  });

  @override
  State<ChatCustomTicketCard> createState() => _ChatCustomTicketCardState();
}

class _ChatCustomTicketCardState extends State<ChatCustomTicketCard> {
  Timer? _timer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _calcRemainingSeconds();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant ChatCustomTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.expiresAt != widget.ticket.expiresAt ||
        oldWidget.ticket.status != widget.ticket.status) {
      _timer?.cancel();
      _secondsLeft = _calcRemainingSeconds();
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _calcRemainingSeconds() {
    if (widget.ticket.remainingSeconds != null && widget.ticket.remainingSeconds! >= 0) {
      return widget.ticket.remainingSeconds!;
    }
    if (widget.ticket.expiresAt == null) return 0;
    try {
      final exp = DateTime.parse(widget.ticket.expiresAt!).toUtc();
      final now = DateTime.now().toUtc();
      final diff = exp.difference(now).inSeconds;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  void _startCountdown() {
    if (widget.ticket.status != 'pending' || _secondsLeft <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        setState(() {
          _secondsLeft = 0;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  String _formatTimer(int sec) {
    if (sec <= 0) return 'Expired';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _openImageZoom(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (dialogCtx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Tap anywhere on background to dismiss
              GestureDetector(
                onTap: () => Navigator.of(dialogCtx).pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),

              // Interactive zoomable image
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  clipBehavior: Clip.none,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white60,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              // Top Bar with title and close button
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.black.withValues(alpha: 0.50),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(dialogCtx).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final isCustomer = context.read<AuthProvider>().user?.role == 'customer';
    final isPending = t.status == 'pending' && _secondsLeft > 0;
    final isAccepted = t.status == 'accepted';
    final isCancelled = t.status == 'cancelled';
    final isExpired = (t.status == 'expired') || (t.status == 'pending' && _secondsLeft <= 0);
    final hasImage = t.imageUrl != null && t.imageUrl!.trim().isNotEmpty;

    const double outerRadius = 18.0;
    const double innerRadius = outerRadius - 1.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(
          color: AppColors.borderStrong.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142A231E),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: Full-Bleed Image (Tap to Zoom) or Clean Bar if no picture ──
            if (hasImage)
              _buildFullImageHeader(context, isPending, isAccepted, isExpired, isCancelled)
            else
              _buildNoImageHeader(isPending, isAccepted, isExpired, isCancelled),

            // ── Card Body Details ──
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arrangement Title
                  Text(
                    t.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                      height: 1.2,
                    ),
                  ),

                  // Inclusions (if specified)
                  if (t.inclusions != null && t.inclusions!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 11.5,
                              color: AppColors.dustyRose,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              t.inclusions!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppColors.bark,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 9),

                  // Base Quote Price Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFBF9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Base Quote',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                'Custom Arrangement',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.5,
                                  color: AppColors.muted.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₱${t.basePrice.toStringAsFixed(2)}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRose,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Customer Action Buttons or Status Footer
                  if (isPending && isCustomer) ...[
                    const SizedBox(height: 10),
                    _buildGradientButton(
                      label: 'Review & Check Out',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: widget.onReviewPressed,
                    ),
                  ] else if (isPending && !isCustomer) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Waiting for Customer',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.bark,
                        ),
                      ),
                    ),
                  ] else if (isAccepted && widget.showViewOrder) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton(
                        onPressed: widget.onViewOrderPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.charcoal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'View Order',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (isExpired) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Quote Expired',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ] else if (isCancelled) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Quote Cancelled',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC0392B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-bleed image header at the top of the card with tap-to-zoom and floating overlay badges
  Widget _buildFullImageHeader(
    BuildContext context,
    bool isPending,
    bool isAccepted,
    bool isExpired,
    bool isCancelled,
  ) {
    final t = widget.ticket;

    return GestureDetector(
      onTap: () => _openImageZoom(context, t.imageUrl!, t.title),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Arrangement Image
            CachedNetworkImage(
              imageUrl: t.imageUrl!,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              placeholder: (_, __) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.imageWash),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.imageWash),
                child: Center(
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: 38,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),

            // Top gradient scrim for high badge readability
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom gradient scrim to soften edge towards card body
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Floating Top Badges (Category & Status / Countdown)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category Badge (AppColors.badgeGradient)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: AppColors.badgeGradient,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.categoryLabel.toUpperCase(),
                          maxLines: 1,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Live Timer / Status Badge
                  _buildStatusBadge(
                    isPending,
                    isAccepted,
                    isExpired,
                    isCancelled,
                    isLightMode: false,
                  ),
                ],
              ),
            ),

            // Floating Bottom-Left Ticket Code
            Positioned(
              bottom: 6,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.ticketNumber,
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // Floating Bottom-Right Tap to Zoom Hint Icon
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Clean top header bar for tickets without an image
  Widget _buildNoImageHeader(
    bool isPending,
    bool isAccepted,
    bool isExpired,
    bool isCancelled,
  ) {
    final t = widget.ticket;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF9),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      gradient: AppColors.badgeGradient,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.categoryLabel.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  t.ticketNumber,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.labelPink,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _buildStatusBadge(
            isPending,
            isAccepted,
            isExpired,
            isCancelled,
            isLightMode: true,
          ),
        ],
      ),
    );
  }

  /// Floating status badge with high-contrast glassmorphism or clean light colors
  Widget _buildStatusBadge(
    bool isPending,
    bool isAccepted,
    bool isExpired,
    bool isCancelled, {
    required bool isLightMode,
  }) {
    if (isPending) {
      if (isLightMode) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: const Color(0xFFFFEEBA),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 11.5,
                color: Color(0xFF856404),
              ),
              const SizedBox(width: 3.5),
              Text(
                _formatTimer(_secondsLeft),
                maxLines: 1,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF856404),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 11.5,
              color: Color(0xFFFFD54F),
            ),
            const SizedBox(width: 3.5),
            Text(
              _formatTimer(_secondsLeft),
              maxLines: 1,
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    if (isAccepted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isLightMode ? const Color(0xFFD4EDDA) : const Color(0xFF1E7E34),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isLightMode ? const Color(0xFFC3E6CB) : Colors.white.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 11.5,
              color: isLightMode ? const Color(0xFF155724) : Colors.white,
            ),
            const SizedBox(width: 3.5),
            Text(
              'Accepted',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isLightMode ? const Color(0xFF155724) : Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isLightMode ? const Color(0xFFF8D7DA) : const Color(0xFFC0392B).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cancel_rounded,
              size: 11,
              color: isLightMode ? const Color(0xFF721C24) : Colors.white,
            ),
            const SizedBox(width: 3.5),
            Text(
              'Cancelled',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isLightMode ? const Color(0xFF721C24) : Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isLightMode ? const Color(0xFFE2E3E5) : const Color(0xFF495057).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_disabled_rounded,
            size: 11,
            color: isLightMode ? const Color(0xFF383D41) : Colors.white70,
          ),
          const SizedBox(width: 3.5),
          Text(
            'Expired',
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isLightMode ? const Color(0xFF383D41) : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Branded primary gradient CTA button with glow shadow and pill shape
  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 38,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.roseButton,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.5, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
