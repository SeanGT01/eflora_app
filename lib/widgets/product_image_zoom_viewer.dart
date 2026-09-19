import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Fullscreen interactive photo viewer that allows pinch-to-zoom (up to 5x),
/// double-tap zoom toggle, panning, and multi-image gallery navigation.
class ProductImageZoomViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String productName;

  const ProductImageZoomViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.productName,
  });

  @override
  State<ProductImageZoomViewer> createState() => _ProductImageZoomViewerState();
}

class _ProductImageZoomViewerState extends State<ProductImageZoomViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers = {};
  bool _isCurrentPageZoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    for (int i = 0; i < widget.imageUrls.length; i++) {
      _controllers[i] = TransformationController();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _getController(int index) {
    return _controllers.putIfAbsent(index, () => TransformationController());
  }

  void _onInteractionEnd(int index) {
    final tc = _getController(index);
    final scale = tc.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isCurrentPageZoomed) {
      setState(() => _isCurrentPageZoomed = zoomed);
    }
  }

  void _handleDoubleTap(int index) {
    final tc = _getController(index);
    final currentScale = tc.value.getMaxScaleOnAxis();

    if (currentScale > 1.1) {
      // Reset back to 1.0
      tc.value = Matrix4.identity();
      if (_isCurrentPageZoomed) {
        setState(() => _isCurrentPageZoomed = false);
      }
    } else {
      // Zoom in to 2.8x centered at tap
      final pos = _doubleTapDetails?.localPosition ?? const Offset(200, 300);
      final zoomed = Matrix4.identity()
        ..setEntry(0, 0, 2.8)
        ..setEntry(1, 1, 2.8)
        ..setEntry(0, 3, -pos.dx * 1.8)
        ..setEntry(1, 3, -pos.dy * 1.8);
      tc.value = zoomed;
      if (!_isCurrentPageZoomed) {
        setState(() => _isCurrentPageZoomed = true);
      }
    }
  }

  void _toggleZoomCurrent() {
    final tc = _getController(_currentIndex);
    if (_isCurrentPageZoomed) {
      tc.value = Matrix4.identity();
      setState(() => _isCurrentPageZoomed = false);
    } else {
      tc.value = Matrix4.identity()
        ..setEntry(0, 0, 2.5)
        ..setEntry(1, 1, 2.5);
      setState(() => _isCurrentPageZoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            physics: _isCurrentPageZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (idx) {
              // Reset previous page's zoom
              _controllers[_currentIndex]?.value = Matrix4.identity();
              setState(() {
                _currentIndex = idx;
                _isCurrentPageZoomed = false;
              });
            },
            itemBuilder: (context, idx) {
              final tc = _getController(idx);
              final url = widget.imageUrls[idx];

              return GestureDetector(
                onDoubleTapDown: (d) => _doubleTapDetails = d,
                onDoubleTap: () => _handleDoubleTap(idx),
                child: InteractiveViewer(
                  transformationController: tc,
                  minScale: 1.0,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  panEnabled: true,
                  scaleEnabled: true,
                  onInteractionEnd: (_) => _onInteractionEnd(idx),
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      memCacheWidth: 1600,
                      memCacheHeight: 1600,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 6,
                bottom: 12,
                left: 12,
                right: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (widget.imageUrls.length > 1)
                          Text(
                            '${_currentIndex + 1} of ${widget.imageUrls.length}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isCurrentPageZoomed
                            ? AppColors.deepRose.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isCurrentPageZoomed
                            ? Icons.zoom_out_map_rounded
                            : Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    tooltip: _isCurrentPageZoomed ? 'Reset zoom' : 'Zoom in',
                    onPressed: _toggleZoomCurrent,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Hint & Thumbnails
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 14,
                top: 14,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pinch to zoom in/out • Double tap to toggle zoom',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (widget.imageUrls.length > 1) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.imageUrls.length, (idx) {
                          final isSel = idx == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSel ? 44 : 36,
                              height: isSel ? 44 : 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.pinkMid
                                      : Colors.white.withValues(alpha: 0.25),
                                  width: isSel ? 2.2 : 1,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: AppColors.pinkMid
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6.5),
                                child: CachedNetworkImage(
                                  imageUrl: widget.imageUrls[idx],
                                  fit: BoxFit.cover,
                                  memCacheWidth: 100,
                                  memCacheHeight: 100,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
