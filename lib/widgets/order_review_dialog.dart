import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Shows the two-step review modal (Store Experience first, then Product Ratings)
/// matching the web E-FLORA review popup dialog on My Orders.
Future<bool?> showOrderReviewModal(
  BuildContext context, {
  required Order order,
  Map<int, int>? initialExistingRatings,
  bool? initialStoreRated,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => OrderReviewDialog(
      order: order,
      initialExistingRatings: initialExistingRatings,
      initialStoreRated: initialStoreRated,
    ),
  );
}

class OrderReviewDialog extends StatefulWidget {
  final Order order;
  final Map<int, int>? initialExistingRatings;
  final bool? initialStoreRated;

  const OrderReviewDialog({
    super.key,
    required this.order,
    this.initialExistingRatings,
    this.initialStoreRated,
  });

  @override
  State<OrderReviewDialog> createState() => _OrderReviewDialogState();
}

class _OrderReviewDialogState extends State<OrderReviewDialog> {
  bool _loading = true;
  int _step = 0; // 0 = store, 1 = products
  Map<int, int> _existingRatings = {};
  bool _storeRated = false;
  List<OrderItem> _unratedItems = [];

  // Store review state
  int _storeStars = 0;
  final TextEditingController _storeComment = TextEditingController();

  // Product reviews state: itemId -> rating
  final Map<int, int> _ratings = {};
  final Map<int, TextEditingController> _commentControllers = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialExistingRatings != null && widget.initialStoreRated != null) {
      _existingRatings = Map<int, int>.from(widget.initialExistingRatings!);
      _storeRated = widget.initialStoreRated!;
      _initSteps();
      _loading = false;
    } else {
      _fetchExistingRatings();
    }
  }

  Future<void> _fetchExistingRatings() async {
    try {
      final res = await ApiService.getOrderRatings(widget.order.id);
      if (!mounted) return;
      if (res.statusCode == 200 && res.data?['success'] == true) {
        final map = res.data!['ratings'] as Map<String, dynamic>? ?? {};
        final store = res.data!['store_rating'];
        _existingRatings = map.map(
          (k, v) => MapEntry(int.parse(k), (v['rating'] as num).toInt()),
        );
        _storeRated = store != null;
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() {
          _initSteps();
          _loading = false;
        });
      }
    }
  }

  void _initSteps() {
    _unratedItems = widget.order.items
        .where((item) => !_existingRatings.containsKey(item.id))
        .toList();

    for (final item in _unratedItems) {
      _commentControllers[item.id] = TextEditingController();
    }

    if (_storeRated) {
      _step = 1;
    } else {
      _step = 0;
    }
  }

  @override
  void dispose() {
    _storeComment.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasProductRating => _ratings.values.any((r) => r > 0);

  Future<void> _submitStore() async {
    if (_storeStars < 1) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'rating': _storeStars,
      if (_storeComment.text.trim().isNotEmpty)
        'comment': _storeComment.text.trim(),
    };
    final res = await ApiService.submitOrderRatings(
      widget.order.id,
      storeRating: body,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.statusCode == 200 && res.data?['success'] == true) {
      setState(() => _storeRated = true);
      if (_unratedItems.isEmpty) {
        Navigator.of(context).pop(true);
        AppToastHost.show('Thank you for rating this shop!');
      } else {
        setState(() => _step = 1);
      }
    } else {
      AppToastHost.show(
        (res.data?['error'] ?? 'Failed to save store rating').toString(),
        isError: true,
      );
    }
  }

  void _skipStore() {
    if (_unratedItems.isEmpty) {
      Navigator.of(context).pop(false);
      AppToastHost.show('You can rate the shop later from this order.');
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submitProducts() async {
    if (!_hasProductRating) return;
    setState(() => _submitting = true);

    final ratings = _ratings.entries.where((e) => e.value > 0).map((e) {
      final comment = _commentControllers[e.key]?.text.trim();
      return <String, dynamic>{
        'order_item_id': e.key,
        'rating': e.value,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };
    }).toList();

    final res = await ApiService.submitOrderRatings(
      widget.order.id,
      ratings: ratings,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.statusCode == 200 && res.data?['success'] == true) {
      Navigator.of(context).pop(true);
      AppToastHost.show('Thank you for your rating!');
    } else {
      AppToastHost.show(
        (res.data?['error'] ?? 'Failed to submit rating').toString(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = (screenWidth - 32).clamp(280.0, 480.0);
      return Dialog(
        backgroundColor: AppColors.warmWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: dialogWidth,
          height: 160,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.deepRose),
          ),
        ),
      );
    }

    final needStore = !_storeRated;
    final needProducts = _unratedItems.isNotEmpty;

    if (!needStore && !needProducts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 480.0);

    final title = _step == 0 ? 'Rate Your Experience' : 'Rate Products';

    return Dialog(
      backgroundColor: AppColors.warmWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
            maxWidth: 480,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted, size: 22),
                    onPressed: () => Navigator.of(context).pop(false),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Modal Body
            Flexible(
              child: _step == 0 ? _buildStoreRatingStep() : _buildProductRatingStep(),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.warmWhite,
                border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: _step == 0 ? _buildStoreFooter() : _buildProductFooter(),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStoreRatingStep() {
    final storeName = widget.order.storeName ?? 'Store';
    final storeLogo = widget.order.storeLogo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your overall experience with this shop? Stars are required to continue; you can add an optional comment.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (storeLogo != null && storeLogo.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: storeLogo,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _defaultStoreAvatar(),
                        ),
                      )
                    else
                      _defaultStoreAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order #ORD-${widget.order.id.toString().padLeft(5, '0')}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (si) {
                      final star = si + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _storeStars = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            star <= _storeStars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 36,
                            color: star <= _storeStars
                                ? const Color(0xFFF0B429)
                                : AppColors.borderStrong,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _storeComment,
                  maxLines: 3,
                  maxLength: 500,
                  style: GoogleFonts.dmSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional feedback about packaging, communication, or service',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.deepRose),
                    ),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultStoreAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 24,
        color: AppColors.deepRose,
      ),
    );
  }

  Widget _buildStoreFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_unratedItems.isNotEmpty) ...[
          TextButton(
            onPressed: _submitting ? null : _skipStore,
            child: Text(
              'Skip, rate products only',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        ElevatedButton(
          onPressed: (_storeStars > 0 && !_submitting) ? _submitStore : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepRose,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildProductRatingStep() {
    if (_unratedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No products left to rate.',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _unratedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final item = _unratedItems[i];
        final rating = _ratings[item.id] ?? 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildItemThumb(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${item.quantity}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (si) {
                    final star = si + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _ratings[item.id] = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 34,
                          color: star <= rating
                              ? const Color(0xFFF0B429)
                              : AppColors.borderStrong,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _commentControllers[item.id],
                maxLines: 2,
                maxLength: 500,
                style: GoogleFonts.dmSans(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts about this product (optional)',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                  contentPadding: const EdgeInsets.all(10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.deepRose),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _hasProductRating && !_submitting ? _submitProducts : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepRose,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit ratings'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                  AppToastHost.show('You can rate the products later from this order.');
                },
          child: Text(
            'Skip, rate later',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemThumb(OrderItem item) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(Icons.local_florist, size: 22, color: Color(0x33B5445A)),
        ),
      );
    }
    final url = CloudinaryService.isCloudinaryUrl(item.imageUrl!)
        ? CloudinaryService.getThumbnailUrl(item.imageUrl!, size: 48)
        : item.imageUrl!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: AppColors.warmWhite,
          child: const Icon(Icons.broken_image_outlined, size: 20, color: AppColors.muted),
        ),
      ),
    );
  }
}
