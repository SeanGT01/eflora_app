class WishlistItem {
  final int id;
  final int productId;
  final int? variantId;
  final int? storeId;
  final String storeName;
  final String name;
  final String? productName;
  final String? variantName;
  final String? imageUrl;
  final double price;
  final double? originalPrice;
  final int? discountPct;
  final int stockQuantity;

  WishlistItem({
    required this.id,
    required this.productId,
    this.variantId,
    this.storeId,
    required this.storeName,
    required this.name,
    this.productName,
    this.variantName,
    this.imageUrl,
    required this.price,
    this.originalPrice,
    this.discountPct,
    this.stockQuantity = 0,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> j) {
    return WishlistItem(
      id: j['id'] as int,
      productId: j['product_id'] as int,
      variantId: j['variant_id'] as int?,
      storeId: j['store_id'] as int?,
      storeName: (j['store_name'] as String?) ?? 'Store',
      name: (j['name'] as String?) ?? 'Product',
      productName: j['product_name'] as String?,
      variantName: j['variant_name'] as String?,
      imageUrl: j['image_url'] as String?,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (j['original_price'] as num?)?.toDouble(),
      discountPct: (j['discount_pct'] as num?)?.toInt(),
      stockQuantity: (j['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}
