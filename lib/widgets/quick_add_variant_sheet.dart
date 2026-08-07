import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
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

/// Opens a themed bottom sheet to pick Standard / variant before adding to cart.
Future<void> showQuickAddVariantSheet(
  BuildContext context, {
  required Product product,
}) async {
  if (!product.hasAnySellableStock) {
    showToast(context, 'This item is out of stock', isError: true);
    return;
  }

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
  late final List<_QuickAddOption> _options;
  late String _selectedKey;
  int _qty = 1;
  bool _adding = false;

  final _peso = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _options = _buildOptions(widget.product);
    final firstInStock = _options.where((o) => o.inStock).toList();
    _selectedKey =
        firstInStock.isNotEmpty ? firstInStock.first.key : _options.first.key;
    _qty = 1;
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

  _QuickAddOption get _selected =>
      _options.firstWhere((o) => o.key == _selectedKey, orElse: () => _options.first);

  int get _maxQty {
    final selected = _selected;
    if (!selected.inStock) return 1;
    return selected.stock < 1 ? 1 : selected.stock;
  }

  void _selectOption(String key) {
    setState(() {
      _selectedKey = key;
      _qty = 1;
    });
  }

  void _changeQty(int delta) {
    if (!_selected.inStock || _adding) return;
    final next = (_qty + delta).clamp(1, _maxQty);
    if (next == _qty) return;
    setState(() => _qty = next);
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (!selected.inStock || _adding) return;

    final quantity = _qty.clamp(1, _maxQty);
    setState(() => _adding = true);
    final cart = context.read<CartProvider>();
    final displayName = selected.variantId != null
        ? '${widget.product.name} — ${selected.name}'
        : widget.product.name;

    final error = await cart.addItem(
      widget.product.id,
      qty: quantity,
      variantId: selected.variantId,
    );
    if (!mounted) return;
    setState(() => _adding = false);

    if (error != null) {
      showCartActionError(context, error);
      return;
    }

    Navigator.pop(context);
    showToast(
      context,
      quantity > 1
          ? '$displayName ×$quantity added to basket'
          : '$displayName added to basket',
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final selected = _selected;
    final canAdd = selected.inStock && !_adding;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
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
                _Thumb(url: product.primaryImageUrl, size: 64, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (product.storeName ?? 'Flower Shop').toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.dustyRose,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: AppColors.charcoal,
                        ),
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
                  'SELECT OPTION',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                ..._options.map(_buildOptionTile),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 14 + bottom),
            child: Row(
              children: [
                _QtyControl(
                  qty: _qty,
                  max: _maxQty,
                  enabled: selected.inStock && !_adding,
                  onMinus: () => _changeQty(-1),
                  onPlus: () => _changeQty(1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAdd ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.roseCta,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderStrong,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _qty > 1
                                      ? 'Add $_qty to basket'
                                      : 'Add to basket',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
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

  Widget _buildOptionTile(_QuickAddOption opt) {
    final selected = opt.key == _selectedKey;
    final onSale = opt.regularPrice > opt.price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: opt.inStock ? () => _selectOption(opt.key) : null,
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: opt.inStock ? 1 : 0.48,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.dustyRose.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.roseCta
                      : AppColors.blush.withValues(alpha: 0.55),
                  width: selected ? 1.6 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  _Thumb(url: opt.imageUrl, size: 44, radius: 10),
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
                      ],
                    ),
                  ),
                  Column(
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
                    ],
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

class _QtyControl extends StatelessWidget {
  final int qty;
  final int max;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyControl({
    required this.qty,
    required this.max,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0x73E6AAC3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(
            icon: Icons.remove,
            onTap: enabled && qty > 1 ? onMinus : null,
          ),
          Container(
            width: 36,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x4DE6AAC3), width: 1.5),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
          _QtyBtn(
            icon: Icons.add,
            onTap: enabled && qty < max ? onPlus : null,
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.charcoal : AppColors.borderStrong,
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
  const _Thumb({required this.url, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF5EDE6),
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
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
