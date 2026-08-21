import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';
import 'product.dart';
import '../theme/app_theme.dart';

class CartItemAddon {
  final int id;
  final int addonOptionId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? groupName;

  const CartItemAddon({
    required this.id,
    required this.addonOptionId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.groupName,
  });

  factory CartItemAddon.fromJson(Map<String, dynamic> j) {
    return CartItemAddon(
      id: j['id'] ?? 0,
      addonOptionId: j['addon_option_id'] ?? 0,
      name: j['name'] ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      quantity: j['quantity'] ?? 1,
      imageUrl: j['image_url'] as String?,
      groupName: j['group_name'] as String?,
    );
  }
}

class CartItem {
  final int id;
  final int productId;
  final int? variantId;
  final Product product;
  final ProductVariant? variant;
  final String name;
  final double price;           // effective (sale) price
  final double? originalPrice;  // regular price, non-null only when on sale
  final int? discountPct;
  final String? imageUrl;
  int quantity;
  final int stockQuantity;
  final String? storeName;
  final int? storeId;
  bool isSelected;
  final List<CartItemAddon> addons;
  final double addonsTotal;

  CartItem({
    required this.id,
    required this.productId,
    this.variantId,
    required this.product,
    this.variant,
    required this.name,
    required this.price,
    this.originalPrice,
    this.discountPct,
    this.imageUrl,
    required this.quantity,
    required this.stockQuantity,
    this.storeName,
    this.storeId,
    this.isSelected = true,
    this.addons = const [],
    this.addonsTotal = 0,
  });

  bool get isVariant => variantId != null;

  /// Add-on charge for this line (not scaled by flower/variant qty — matches backend).
  double get addonsUnitTotal {
    if (addons.isNotEmpty) {
      return addons.fold<double>(0, (s, a) => s + a.price * a.quantity);
    }
    return addonsTotal;
  }

  /// Product + structured add-ons (add-ons stay fixed when flower qty changes).
  double get subtotal => (price * quantity) + addonsUnitTotal;

/// Get optimized Cloudinary image URL for cart display
String? get optimizedImageUrl {
  if (imageUrl == null || imageUrl!.isEmpty) {
    debugPrint('⚠️ No imageUrl available for item: $name');
    return null;
  }

  // If it's already a full Cloudinary URL with version, use it directly
  if (imageUrl!.contains('cloudinary.com') && imageUrl!.contains('/v1/') == false) {
    return CloudinaryService.getThumbnailUrl(imageUrl!, size: 150);
  }

  // Handle the filename format: "cloudinary_e-flowers/products/xxx.jpg"
  if (imageUrl!.contains('cloudinary_e-flowers/')) {
    // Extract the public ID by removing the "cloudinary_" prefix
    // This converts "cloudinary_e-flowers/products/xxx.jpg" to "e-flowers/products/xxx.jpg"
    final cleanPath = imageUrl!.replaceFirst('cloudinary_', '');
    // Remove file extension
    final withoutExt = cleanPath.split('.').first;
    
    debugPrint('🔄 Converting filename to Cloudinary URL:');
    debugPrint('   Original: $imageUrl');
    debugPrint('   Clean path: $cleanPath');
    debugPrint('   Without ext: $withoutExt');
    
    // Construct proper Cloudinary URL
    final cloudinaryUrl = 'https://res.cloudinary.com/dgyq49vi2/image/upload/w_150,h_150,c_fill,q_auto,f_auto/$withoutExt';
    debugPrint('   Final URL: $cloudinaryUrl');
    return cloudinaryUrl;
  }

  // Handle malformed URLs with /v1/_e-flowers/
  if (imageUrl!.contains('/v1/_e-flowers/')) {
    final fixed = imageUrl!.replaceFirst('/v1/_e-flowers/', '/v1/e-flowers/');
    debugPrint('🔄 Fixed malformed URL: $fixed');
    return fixed;
  }

  debugPrint('⚠️ Could not optimize image URL: $imageUrl');
  return null;
}
factory CartItem.fromJson(Map<String, dynamic> j) {
  // Extract product data
  final productData = j['product'] as Map<String, dynamic>? ?? {};
  final variantData = j['variant'] as Map<String, dynamic>?;
  
  // Create product object
  final product = Product.fromJson(productData);
  
  // Create variant object if exists
  ProductVariant? variant;
  if (variantData != null) {
    variant = ProductVariant.fromJson(variantData);
  } else if (j['variant_id'] != null && product.variants.isNotEmpty) {
    try {
      variant = product.variants.firstWhere(
        (v) => v.id == j['variant_id'],
      );
    } catch (e) {
      debugPrint('⚠️ Variant ${j['variant_id']} not found in product variants');
    }
  }

  // Determine the final name (variant + product)
  final String displayName;
  if (variant != null) {
    displayName = '${variant.name} ${product.name}';
  } else {
    displayName = product.name;
  }

  // Determine the final effective price (uses sale price when set)
  final double finalPrice = (j['price'] as num?)?.toDouble() ??
                            (variant?.effectivePrice ?? product.effectivePrice);
  final double? originalPrice = (j['original_price'] as num?)?.toDouble();
  final int? discountPct = j['discount_pct'] as int?;

  // Determine the final image URL with multiple fallbacks
  String? imageUrl;
  
  // ✅ PRIORITY 1: Check if there's a top-level image_url in the cart item
  if (j.containsKey('image_url') && j['image_url'] != null && j['image_url'].toString().isNotEmpty) {
    imageUrl = j['image_url'] as String;
    debugPrint('📸 Using top-level image_url: $imageUrl');
  }
  // ✅ PRIORITY 2: Check variant image
  else if (variant?.imageUrl != null && variant!.imageUrl!.isNotEmpty) {
    imageUrl = variant.imageUrl;
    debugPrint('📸 Using variant image_url: $imageUrl');
  } 
  // ✅ PRIORITY 3: Check product's top-level image_url (if present in productData)
  else if (productData.containsKey('image_url') && productData['image_url'] != null) {
    imageUrl = productData['image_url'] as String;
    debugPrint('📸 Using product.image_url: $imageUrl');
  }
  // ✅ PRIORITY 4: Check product's images array for image_url
  else if (product.images.isNotEmpty) {
    // Look for an image with image_url field
    for (var img in product.images) {
      if (img.filename.contains('cloudinary.com')) {
        imageUrl = img.filename;
        debugPrint('📸 Using product image filename: $imageUrl');
        break;
      }
    }
    
    // If still no image, try to construct from the first image's filename
    if (imageUrl == null) {
      final firstImage = product.images.first;
      // Check if the filename itself is a Cloudinary path
      if (firstImage.filename.contains('cloudinary')) {
        // Extract the public ID and construct URL
        // This is a fallback and might not always work
        imageUrl = firstImage.filename;
        debugPrint('📸 Using raw filename as fallback: $imageUrl');
      }
    }
  }

  // Get store name - prioritize multiple sources to ensure it's always available
  final storeName = (j['store_name'] as String?) ?? 
                   (productData['store_name'] as String?) ??
                   product.storeName ??
                   'Unknown Store';
  debugPrint('🏪 Store name for item ${j['id']}: $storeName');

  // Get stock quantity
  final stockQty = variant?.stockQuantity ?? product.stockQuantity;

  // Final debug log
  if (imageUrl != null) {
    debugPrint('✅ Image URL found for item ${j['id']}: $imageUrl');
  } else {
    debugPrint('⚠️ No image URL found for item ${j['id']}');
  }

  final addons = (j['addons'] as List? ?? [])
      .whereType<Map>()
      .map((a) => CartItemAddon.fromJson(Map<String, dynamic>.from(a)))
      .toList();
  final addonsTotal = (j['addons_total'] as num?)?.toDouble() ??
      addons.fold<double>(0, (s, a) => s + (a.price * a.quantity));

  return CartItem(
    id: j['id'] as int,
    productId: product.id,
    variantId: j['variant_id'] as int?,
    product: product,
    variant: variant,
    name: displayName,
    price: finalPrice,
    originalPrice: originalPrice,
    discountPct: discountPct,
    imageUrl: imageUrl,
    quantity: j['quantity'] as int? ?? 1,
    stockQuantity: stockQty,
    storeName: storeName,
    storeId: j['store_id'] as int? ?? product.storeId,
    isSelected: j['is_selected'] as bool? ?? true,
    addons: addons,
    addonsTotal: addonsTotal,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'quantity': quantity,
      'stock_quantity': stockQuantity,
      'store_name': storeName,
      'store_id': storeId,
      'is_selected': isSelected,
    };
  }

  CartItem copyWith({
    int? id,
    int? productId,
    int? variantId,
    Product? product,
    ProductVariant? variant,
    String? name,
    double? price,
    double? originalPrice,
    int? discountPct,
    String? imageUrl,
    int? quantity,
    int? stockQuantity,
    String? storeName,
    int? storeId,
    bool? isSelected,
    List<CartItemAddon>? addons,
    double? addonsTotal,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      product: product ?? this.product,
      variant: variant ?? this.variant,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPct: discountPct ?? this.discountPct,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      storeName: storeName ?? this.storeName,
      storeId: storeId ?? this.storeId,
      isSelected: isSelected ?? this.isSelected,
      addons: addons ?? this.addons,
      addonsTotal: addonsTotal ?? this.addonsTotal,
    );
  }
}

/// A group of cart items belonging to the same store
class StoreCartGroup {
  final int storeId;
  final String storeName;
  final List<CartItem> items;

  StoreCartGroup({
    required this.storeId,
    required this.storeName,
    required this.items,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get selectedSubtotal =>
      items.where((i) => i.isSelected).fold(0.0, (sum, i) => sum + i.subtotal);
  bool get allSelected => items.every((i) => i.isSelected);
  bool get anySelected => items.any((i) => i.isSelected);
  /// Flower qty only (selected lines).
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  /// Web parity: each product line + each add-on row.
  int get displayLineCount =>
      items.fold(0, (sum, i) => sum + 1 + i.addons.length);
  int get selectedItemCount =>
      items.where((i) => i.isSelected).fold(0, (sum, i) => sum + i.quantity);
}

class Cart {
  final int id;
  final List<CartItem> items;

  const Cart({required this.id, required this.items});

  double get total => items.fold(0, (sum, i) => sum + i.subtotal);
  /// Web parity: product qty + add-on units (badge count).
  int get itemCount => items.fold(0, (sum, i) {
        final addonUnits = i.addons.fold<int>(
          0,
          (s, a) => s + (a.quantity <= 0 ? 1 : a.quantity),
        );
        // If addons list empty but addonsTotal set, still count product qty only
        // (units unknown); badge stays product-based in that edge case.
        return sum + i.quantity + addonUnits;
      });
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Only selected items
  List<CartItem> get selectedItems => items.where((i) => i.isSelected).toList();
  double get selectedTotal => selectedItems.fold(0.0, (sum, i) => sum + i.subtotal);
  /// Selected flower/variant units (checkout CTA) — not add-on units.
  int get selectedItemCount =>
      selectedItems.fold(0, (sum, i) => sum + i.quantity);

  /// Items grouped by store
  Map<int, StoreCartGroup> get storeGroups {
    final groups = <int, StoreCartGroup>{};
    for (final item in items) {
      final sid = item.storeId ?? 0;
      if (!groups.containsKey(sid)) {
        // Use the item's store name, safely handling null and empty cases
        final finalStoreName = (item.storeName?.isNotEmpty ?? false) 
          ? item.storeName! 
          : 'Unknown Store';
        groups[sid] = StoreCartGroup(
          storeId: sid,
          storeName: finalStoreName,
          items: [],
        );
      }
      groups[sid]!.items.add(item);
    }
    return groups;
  }

  factory Cart.fromJson(Map<String, dynamic> j) {
    final cartData = j['cart'] as Map<String, dynamic>? ?? j;
    
    final itemsData = cartData['items'] as List? ?? [];
    final items = itemsData
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList();
    
    debugPrint('🛒 Cart loaded with ${items.length} items');
    for (var item in items) {
      debugPrint('   • ${item.name} x${item.quantity} - ₱${item.price} ${item.isVariant ? '(variant)' : ''}');
      if (item.optimizedImageUrl != null) {
        debugPrint('     📸 Image: ${item.optimizedImageUrl}');
      } else {
        debugPrint('     ⚠️ No image URL');
      }
    }
    
    return Cart(
      id: cartData['id'] ?? 0,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((i) => i.toJson()).toList(),
      'total': total,
      'item_count': itemCount,
    };
  }
}

// Helper method to get a placeholder widget for cart images
Widget cartImagePlaceholder({double size = 60}) {
  return Container(
    width: size,
    height: size,
    color: AppColors.warmWhite,
    child: Center(
      child: Icon(
        Icons.local_florist,
        size: size * 0.5,
        color: const Color(0x22B5445A),
      ),
    ),
  );
}

// Helper method to get a loading widget for cart images
Widget cartImageLoading({double size = 60}) {
  return Container(
    width: size,
    height: size,
    color: AppColors.warmWhite,
    child: Center(
      child: SizedBox(
        width: size * 0.3,
        height: size * 0.3,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.deepRose,
        ),
      ),
    ),
  );
}

// Extension for CartItem to get full-size image
extension CartItemExtension on CartItem {
  String? get fullSizeImageUrl {
    if (imageUrl == null) return null;
    if (imageUrl!.contains('cloudinary.com')) {
      // Fix malformed URLs
      if (imageUrl!.contains('/v1/_e-flowers/')) {
        final uri = Uri.tryParse(imageUrl!);
        if (uri != null) {
          final path = uri.path;
          final parts = path.split('/_e-flowers/');
          if (parts.length > 1) {
            final publicId = 'e-flowers/${parts[1].split('.').first}';
            return 'https://res.cloudinary.com/dgyq49vi2/image/upload/$publicId';
          }
        }
      }
      return imageUrl;
    }
    return imageUrl;
  }
}