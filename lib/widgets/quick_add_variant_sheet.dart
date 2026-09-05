import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'delivery_unavailable_dialog.dart';

class _QuickAddOption {
  final String key;
  final int? variantId;
  final String name;
  final double price;
  final double regularPrice;
  final int stock;
  final String? imageUrl;
  final bool inStock;

  const _QuickAddOption({
    required this.key,
    required this.variantId,
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.stock,
    required this.imageUrl,
    required this.inStock,
  });
}

class _AddonRow {
  final int id;
  final String name;
  final double price;
  final int stock;
  final String? imageUrl;
  final String groupName;

  const _AddonRow({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.groupName,
  });
}

/// Opens a themed bottom sheet matching the web quick-add modal.
Future<void> showQuickAddVariantSheet(
  BuildContext context, {
  required Product product,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _QuickAddVariantSheet(product: product);
    },
  );
}

class _QuickAddVariantSheet extends StatefulWidget {
  final Product product;
  const _QuickAddVariantSheet({required this.product});

  @override
  State<_QuickAddVariantSheet> createState() => _QuickAddVariantSheetState();
}

class _QuickAddVariantSheetState extends State<_QuickAddVariantSheet> {
  late Product _product;
  late List<_QuickAddOption> _options;
  final Map<String, int> _optionQty = {};
  final Map<int, int> _addonQty = {};
  bool _adding = false;
  bool _loadingExtras = false;

  final _peso = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _options = _buildOptions(_product);
    _enrichProduct();
  }

  Future<void> _enrichProduct() async {
    final needsExtras = _product.addonGroups.isEmpty ||
        _product.ymalAddonOptions.isEmpty ||
        _product.variantRatings.isEmpty;
    if (!needsExtras) return;

    setState(() => _loadingExtras = true);
    final result = await ApiService.getProduct(_product.id);
    if (!mounted) return;
    setState(() => _loadingExtras = false);

    if (!result.isSuccess || result.data is! Map) return;
    final raw = Map<String, dynamic>.from(result.data as Map);
    final enriched = Product.fromJson(raw);
    setState(() {
      _product = enriched;
      _options = _buildOptions(enriched);
      // Drop qty for options that disappeared
      _optionQty.removeWhere(
        (k, _) => !_options.any((o) => o.key == k),
      );
    });
  }

  List<_QuickAddOption> _buildOptions(Product product) {
    final options = <_QuickAddOption>[
      _QuickAddOption(
        key: 'main',
        variantId: null,
        name: 'Standard',
        price: product.effectivePrice,
        regularPrice: product.price,
        stock: product.stockQuantity,
        imageUrl: product.primaryImageUrl,
        inStock: product.isAvailable && product.stockQuantity > 0,
      ),
    ];

    for (final v in product.variants) {
      if (!v.isAvailable) continue;
      options.add(
        _QuickAddOption(
          key: 'v-${v.id}',
          variantId: v.id,
          name: v.name,
          price: v.effectivePrice,
          regularPrice: v.price,
          stock: v.stockQuantity,
          imageUrl: v.imageUrl ?? product.primaryImageUrl,
          inStock: v.stockQuantity > 0,
        ),
      );
    }
    return options;
  }

  List<_AddonRow> get _productAddons {
    final out = <_AddonRow>[];
    for (final g in _product.addonGroups) {
      if (!g.isActive) continue;
      for (final o in g.options) {
        if (!o.isAvailable) continue;
        out.add(_AddonRow(
          id: o.id,
          name: o.name,
          price: o.price,
          stock: o.stockQuantity,
          imageUrl: o.imageUrl,
          groupName: g.name,
        ));
      }
    }
    return out;
  }

  List<_AddonRow> get _ymalAddons {
    final productIds = _productAddons.map((a) => a.id).toSet();
    return _product.ymalAddonOptions
        .where((o) => o.isAvailable && !productIds.contains(o.id))
        .map(
          (o) => _AddonRow(
            id: o.id,
            name: o.name,
            price: o.price,
            stock: o.stockQuantity,
            imageUrl: o.imageUrl,
            groupName: o.groupName ?? 'Add-on',
          ),
        )
        .toList();
  }

  ({double avg, int count}) _ratingForKey(String key) {
    final map = _product.variantRatings;
    Map<String, dynamic>? bucket;
    if (key == 'main') {
      bucket = map['main'];
    } else if (key.startsWith('v-')) {
      bucket = map[key.substring(2)];
    }
    if (bucket != null) {
      return (
        avg: (bucket['avg'] as num?)?.toDouble() ?? 0,
        count: (bucket['count'] as num?)?.toInt() ?? 0,
      );
    }
    if (key == 'main') {
      return (avg: _product.avgRating, count: _product.reviewCount);
    }
    return (avg: 0, count: 0);
  }

  int get _unitCount {
    var n = 0;
    for (final q in _optionQty.values) {
      n += q;
    }
    for (final q in _addonQty.values) {
      n += q;
    }
    return n;
  }

  double get _total {
    var t = 0.0;
    for (final opt in _options) {
      final q = _optionQty[opt.key] ?? 0;
      if (q > 0) t += opt.price * q;
    }
    for (final a in [..._productAddons, ..._ymalAddons]) {
      final q = _addonQty[a.id] ?? 0;
      if (q > 0) t += a.price * q;
    }
    return t;
  }

  void _toggleOption(String key) {
    if (_adding) return;
    _QuickAddOption? opt;
    for (final o in _options) {
      if (o.key == key) {
        opt = o;
        break;
      }
    }
    if (opt == null || !opt.inStock) return;
    setState(() {
      final cur = _optionQty[key] ?? 0;
      if (cur > 0) {
        _optionQty.remove(key);
      } else {
        _optionQty[key] = 1;
      }
    });
  }

  void _changeOptionQty(String key, int delta) {
    if (_adding) return;
    _QuickAddOption? opt;
    for (final o in _options) {
      if (o.key == key) {
        opt = o;
        break;
      }
    }
    if (opt == null || !opt.inStock) return;
    setState(() {
      final next = ((_optionQty[key] ?? 0) + delta).clamp(0, opt!.stock);
      if (next <= 0) {
        _optionQty.remove(key);
      } else {
        _optionQty[key] = next;
      }
    });
  }

  void _toggleAddon(int id, int stock) {
    if (_adding || stock <= 0) return;
    setState(() {
      if ((_addonQty[id] ?? 0) > 0) {
        _addonQty.remove(id);
      } else {
        _addonQty[id] = 1;
      }
    });
  }

  void _changeAddonQty(int id, int delta, int stock) {
    if (_adding) return;
    setState(() {
      final next = ((_addonQty[id] ?? 0) + delta).clamp(0, stock);
      if (next <= 0) {
        _addonQty.remove(id);
      } else {
        _addonQty[id] = next;
      }
    });
  }

  List<int> get _expandedAddonIds {
    final ids = <int>[];
    for (final e in _addonQty.entries) {
      for (var i = 0; i < e.value; i++) {
        ids.add(e.key);
      }
    }
    return ids;
  }

  Future<void> _confirm() async {
    if (_adding) return;
    final selected = _options
        .where((o) => (_optionQty[o.key] ?? 0) > 0 && o.inStock)
        .toList();
    final addonIds = _expandedAddonIds;

    if (selected.isEmpty && addonIds.isEmpty) {
      showToast(context, 'Please select at least one option', isError: true);
      return;
    }
    if (selected.isEmpty && addonIds.isNotEmpty) {
      showToast(
        context,
        'Select a Standard or variant to attach add-ons',
        isError: true,
      );
      return;
    }

    setState(() => _adding = true);
    final cart = context.read<CartProvider>();
    final units = _unitCount;

    for (var i = 0; i < selected.length; i++) {
      final opt = selected[i];
      final qty = (_optionQty[opt.key] ?? 1).clamp(1, opt.stock);
      final error = await cart.addItem(
        _product.id,
        qty: qty,
        variantId: opt.variantId,
        addonOptionIds: i == 0 && addonIds.isNotEmpty ? addonIds : null,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() => _adding = false);
        showCartActionError(context, error);
        return;
      }
    }

    setState(() => _adding = false);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(
      context,
      units > 1
          ? '$units items added to basket'
          : '${selected.first.variantId != null ? '${_product.name} — ${selected.first.name}' : _product.name} added to basket',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final hasSelection = _unitCount > 0;
    final focusKey = _optionQty.keys.isNotEmpty
        ? _optionQty.keys.first
        : (_options.isNotEmpty ? _options.first.key : 'main');
    final headerRating = _ratingForKey(focusKey);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(url: _product.primaryImageUrl, size: 64, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_product.storeName ?? 'Flower Shop').toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.dustyRose,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _RatingChip(
                        avg: headerRating.avg,
                        count: headerRating.count,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              shrinkWrap: true,
              children: [
                Text(
                  'SELECT OPTIONS',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                ..._options.map(_buildOptionCard),
                if (_loadingExtras)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                if (_productAddons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'ADD-ONS',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _extrasGrid(
                    _productAddons.map((a) => _buildAddonCard(a, 'Add-on')).toList(),
                  ),
                ],
                if (_ymalAddons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'YOU MAY ALSO LIKE',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _extrasGrid(
                    _ymalAddons.map((a) => _buildAddonCard(a, 'YMAL')).toList(),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + bottom),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
              color: AppColors.warmWhite,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: hasSelection ? 1 : 0.45,
                    child: Row(
                      children: [
                        Text(
                          _unitCount == 1 ? '1 item' : '$_unitCount items',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '₱${_peso.format(_total)}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: ElevatedButton(
                    onPressed: hasSelection && !_adding ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.roseCta,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderStrong,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    child: _adding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Add to basket',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _extrasGrid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 4;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _buildOptionCard(_QuickAddOption opt) {
    final qty = _optionQty[opt.key] ?? 0;
    final selected = qty > 0;
    final onSale = opt.regularPrice > opt.price;
    final rating = _ratingForKey(opt.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: opt.inStock ? 1 : 0.48,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.dustyRose.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.roseCta
                  : AppColors.blush.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: opt.inStock ? () => _toggleOption(opt.key) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        _Thumb(
                          url: opt.imageUrl,
                          size: 52,
                          radius: 10,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.name,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.inStock
                                    ? '${opt.stock} available'
                                    : 'Out of stock',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  color: opt.inStock
                                      ? AppColors.muted
                                      : AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _RatingChip(avg: rating.avg, count: rating.count),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (onSale)
                        Text(
                          '₱${_peso.format(opt.regularPrice)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        '₱${_peso.format(opt.price)}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepRose,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Visibility(
                        visible: selected,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _InlineQty(
                            qty: qty,
                            max: opt.stock,
                            compact: true,
                            onMinus: () => _changeOptionQty(opt.key, -1),
                            onPlus: () => _changeOptionQty(opt.key, 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddonCard(_AddonRow a, String section) {
    final qty = _addonQty[a.id] ?? 0;
    final selected = qty > 0;
    final ok = a.stock > 0;

    return Opacity(
      opacity: ok ? 1 : 0.48,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.roseCta
                : AppColors.blush.withValues(alpha: 0.55),
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: ok ? () => _toggleAddon(a.id, a.stock) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 4, 3, 2),
                child: Column(
                  children: [
                    SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: _Thumb(
                        url: a.imageUrl,
                        size: 46,
                        radius: 7,
                        fit: BoxFit.contain,
                        expand: true,
                        background: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 20,
                      child: Text(
                        a.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    Text(
                      ok ? '${a.stock} left' : 'Out of stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 8.5,
                        height: 1.15,
                        color: ok ? AppColors.muted : AppColors.error,
                      ),
                    ),
                    Text(
                      '₱${_peso.format(a.price)}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Always reserve qty height (web: visibility hidden until selected).
            Visibility(
              visible: selected,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _InlineQty(
                qty: qty,
                max: a.stock,
                compact: true,
                onMinus: () => _changeAddonQty(a.id, -1, a.stock),
                onPlus: () => _changeAddonQty(a.id, 1, a.stock),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final double avg;
  final int count;
  const _RatingChip({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: 14,
          color: empty ? AppColors.muted : const Color(0xFFF0B429),
        ),
        const SizedBox(width: 3),
        Text(
          empty ? '0' : avg.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: empty ? AppColors.muted : AppColors.charcoal,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '($count)',
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// YMAL-style − qty + under a selected card.
class _InlineQty extends StatelessWidget {
  final int qty;
  final int max;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  const _InlineQty({
    required this.qty,
    required this.max,
    required this.onMinus,
    required this.onPlus,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InlineQtyBtn(
          label: '−',
          onTap: qty > 0 ? onMinus : null,
          size: compact ? 20 : 28,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 14),
          child: Text(
            '$qty',
            style: GoogleFonts.dmSans(
              fontSize: compact ? 11 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.deepRose,
            ),
          ),
        ),
        _InlineQtyBtn(
          label: '+',
          onTap: qty < max ? onPlus : null,
          size: compact ? 20 : 28,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? 0 : 10,
        left: compact ? 0 : 2,
        right: compact ? 0 : 2,
      ),
      child: row,
    );
  }
}

class _InlineQtyBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double size;
  const _InlineQtyBtn({
    required this.label,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size > 24 ? 18 : 15,
                height: 1,
                color: enabled
                    ? AppColors.deepRose
                    : AppColors.deepRose.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final BoxFit fit;
  final bool expand;
  final Color background;
  const _Thumb({
    required this.url,
    required this.size,
    required this.radius,
    this.fit = BoxFit.contain,
    this.expand = false,
    this.background = const Color(0xFFF5EDE6),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: expand ? double.infinity : size,
        height: size,
        color: background,
        alignment: Alignment.center,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: fit,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.local_florist_outlined,
                  color: AppColors.muted,
                ),
              )
            : const Icon(
                Icons.local_florist_outlined,
                color: AppColors.muted,
              ),
      ),
    );
  }
}
