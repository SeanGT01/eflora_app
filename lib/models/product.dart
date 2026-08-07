import '../services/cloudinary_service.dart';
import 'package:flutter/foundation.dart';

bool? _parseOptionalBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}

class ProductImage {
  final int id;
  final String filename; // This should be the Cloudinary URL
  final bool isPrimary;
  final int sortOrder;

  const ProductImage({
    required this.id,
    required this.filename,
    required this.isPrimary,
    required this.sortOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> j) {
    // Try to get image_url first, fallback to filename
    String imageUrl = j['image_url'] ?? j['filename'] ?? '';
    
    // If it's a cloudinary filename without full URL, construct it
    if (imageUrl.contains('cloudinary') && !imageUrl.startsWith('http')) {
      // This is a malformed URL from the backend
      // We'll handle it in the optimizedImageUrl getter
    }
    
    return ProductImage(
      id: j['id'] ?? 0,
      filename: imageUrl,
      isPrimary: j['is_primary'] ?? false,
      sortOrder: j['sort_order'] ?? 0,
    );
  }
}

class ProductVariant {
  final int id;
  final int productId;
  final String name;
  final double price;
  final double? specialPrice;
  final int stockQuantity;
  final String? sku;
  final String? imageUrl;
  final String? imageThumbnail;
  final Map<String, dynamic>? attributes;
  final int sortOrder;
  final bool isAvailable;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.specialPrice,
    required this.stockQuantity,
    this.sku,
    this.imageUrl,
    this.imageThumbnail,
    this.attributes,
    required this.sortOrder,
    required this.isAvailable,
  });

  /// The price customers actually pay.
  double get effectivePrice {
    if (specialPrice != null && specialPrice! > 0 && specialPrice! < price) {
      return specialPrice!;
    }
    return price;
  }

  /// Integer % saved, or null when no sale is active.
  int? get discountPct {
    if (specialPrice != null && specialPrice! > 0 && specialPrice! < price && price > 0) {
      return ((1 - specialPrice! / price) * 100).round();
    }
    return null;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    return ProductVariant(
      id: j['id'] ?? 0,
      productId: j['product_id'] ?? 0,
      name: j['name'] ?? '',
      price: (j['price'] is int)
          ? (j['price'] as int).toDouble()
          : (j['price'] ?? 0.0).toDouble(),
      specialPrice: j['special_price'] != null
          ? (j['special_price'] is int
              ? (j['special_price'] as int).toDouble()
              : (j['special_price'] as num).toDouble())
          : null,
      stockQuantity: j['stock_quantity'] ?? 0,
      sku: j['sku'],
      imageUrl: j['image_url'],
      imageThumbnail: j['image_thumbnail'],
      attributes: j['attributes'],
      sortOrder: j['sort_order'] ?? 0,
      isAvailable: j['is_available'] ?? true,
    );
  }

  /// Get optimized Cloudinary URL for different sizes
  String? getOptimizedUrl({int width = 300, int height = 300}) {
    if (imageUrl == null) return null;
    if (!imageUrl!.contains('cloudinary.com')) return imageUrl;
    return CloudinaryService.getOptimizedUrl(imageUrl!, width: width, height: height);
  }

  /// Get thumbnail URL
  String? get thumbnailUrl {
    return getOptimizedUrl(width: 150, height: 150);
  }
}

class Product {
  final int id;
  final int storeId;
  final String name;
  final String? description;
  final double price;
  final double? specialPrice;
  final int stockQuantity;
  
  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORY FIELDS - Aligned with web app structure
  // ════════════════════════════════════════════════════════════════════════════
  final int? mainCategoryId;        // Foreign key to main category (required in web)
  final String? mainCategoryName;   // Main category name (e.g., "Bouquets")
  final String? mainCategorySlug;   // Main category slug (e.g., "bouquets")
  final String? mainCategoryIcon;   // Category icon class
  
  final int? storeCategoryId;       // Foreign key to store subcategory (optional in web)
  final String? storeCategoryName;  // Store subcategory name (e.g., "Crochet Bouquets")
  final String? storeCategorySlug;  // Store subcategory slug
  
  final String? categoryPath;       // Full path: "Bouquets > Crochet Bouquets"
  final String? categoryDisplay;    // Display name: "Bouquets / Crochet Bouquets"
  
  // Legacy field for backwards compatibility
  final String? category;           // DEPRECATED: Use category fields above
  
  // ════════════════════════════════════════════════════════════════════════════
  
  final bool isAvailable;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final String? storeName;
  final DateTime? createdAt;
  final bool hasVariants;
  final bool? canDeliverToCustomer;
  final String? deliveryReason;

  /// The price customers actually pay.
  double get effectivePrice {
    if (specialPrice != null && specialPrice! > 0 && specialPrice! < price) {
      return specialPrice!;
    }
    return price;
  }

  /// Integer % saved, or null when no sale is active.
  int? get discountPct {
    if (specialPrice != null && specialPrice! > 0 && specialPrice! < price && price > 0) {
      return ((1 - specialPrice! / price) * 100).round();
    }
    return null;
  }

  const Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.specialPrice,
    required this.stockQuantity,
    this.mainCategoryId,
    this.mainCategoryName,
    this.mainCategorySlug,
    this.mainCategoryIcon,
    this.storeCategoryId,
    this.storeCategoryName,
    this.storeCategorySlug,
    this.categoryPath,
    this.categoryDisplay,
    this.category, // Legacy
    required this.isAvailable,
    required this.images,
    required this.variants,
    this.storeName,
    this.createdAt,
    required this.hasVariants,
    this.canDeliverToCustomer,
    this.deliveryReason,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    debugPrint('📦 Product.fromJson - Parsing product data');
    
    final imgs = (j['images'] as List? ?? [])
        .map((i) {
          debugPrint('   📸 Image data: $i');
          return ProductImage.fromJson(i as Map<String, dynamic>);
        })
        .toList();
    
    final variants = (j['variants'] as List? ?? [])
        .map((v) {
          debugPrint('   🎯 Variant data: $v');
          return ProductVariant.fromJson(v as Map<String, dynamic>);
        })
        .toList();
    
    debugPrint('   Found ${imgs.length} images and ${variants.length} variants for product ${j['name']}');
    
    return Product(
      id: j['id'] ?? 0,
      storeId: j['store_id'] ?? 0,
      name: j['name'] ?? '',
      description: j['description'],
      price: (j['price'] is int)
          ? (j['price'] as int).toDouble()
          : (j['price'] ?? 0.0).toDouble(),
      specialPrice: j['special_price'] != null
          ? (j['special_price'] is int
              ? (j['special_price'] as int).toDouble()
              : (j['special_price'] as num).toDouble())
          : null,
      stockQuantity: j['stock_quantity'] ?? 0,
      // ════════════════════════════════════════════════════════════════════════════
      // CATEGORY FIELDS - Map from API response
      // ════════════════════════════════════════════════════════════════════════════
      mainCategoryId: j['main_category_id'] as int?,
      mainCategoryName: j['main_category_name'] as String?,
      mainCategorySlug: j['main_category_slug'] as String?,
      mainCategoryIcon: j['main_category_icon'] as String?,
      storeCategoryId: j['store_category_id'] as int?,
      storeCategoryName: j['store_category_name'] as String?,
      storeCategorySlug: j['store_category_slug'] as String?,
      categoryPath: j['category_path'] as String?,                 // "Bouquets > Crochet Bouquets"
      categoryDisplay: j['category_display'] as String?,           // "Bouquets / Crochet Bouquets"
      // ════════════════════════════════════════════════════════════════════════════
      category: j['category'],  // Legacy field
      isAvailable: j['is_available'] ?? true,
      images: imgs,
      variants: variants,
      storeName: j['store_name'],
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'])
          : null,
      hasVariants: j['has_variants'] ?? false,
      canDeliverToCustomer: _parseOptionalBool(j['can_deliver_to_customer']),
      deliveryReason: j['delivery_reason'] as String?,
    );
  }

  /// Get optimized primary image URL for home screen (thumbnail)
  String? get primaryImageUrl {
    if (images.isEmpty) {
      debugPrint('⚠️ No images for product $id ($name)');
      return null;
    }
    
    final primary = images.where((i) => i.isPrimary).firstOrNull ?? images.first;
    
    // If it's already a Cloudinary URL, optimize it
    if (primary.filename.contains('cloudinary.com')) {
      return CloudinaryService.getOptimizedUrl(primary.filename, width: 300, height: 300);
    }
    
    return primary.filename;
  }

  /// For cart thumbnails (150x150)
  String? get cartImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).firstOrNull ?? images.first;
    
    if (primary.filename.contains('cloudinary.com')) {
      return CloudinaryService.getThumbnailUrl(primary.filename, size: 150);
    }
    
    return primary.filename;
  }

  /// For medium size images in detail view
  String? get mediumImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).firstOrNull ?? images.first;
    
    if (primary.filename.contains('cloudinary.com')) {
      return CloudinaryService.getMediumUrl(primary.filename, size: 400);
    }
    
    return primary.filename;
  }

  /// For full-size images in detail view
  String? get fullSizeImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).firstOrNull ?? images.first;
    return primary.filename;
  }

  /// Get image URL for a specific index (for thumbnails carousel)
  String getImageUrl(int index, {int width = 60, int height = 60}) {
    if (images.isEmpty) return '';
    if (index >= images.length) index = 0;
    
    final image = images[index];
    if (image.filename.contains('cloudinary.com')) {
      return CloudinaryService.getOptimizedUrl(image.filename, width: width, height: height);
    }
    
    return image.filename;
  }

  /// Get all image URLs for preloading
  List<String> getAllImageUrls() {
    return images.map((img) {
      if (img.filename.contains('cloudinary.com')) {
        return CloudinaryService.getThumbnailUrl(img.filename, size: 200);
      }
      return img.filename;
    }).toList();
  }

  bool get inStock => stockQuantity > 0 && isAvailable;

  /// Check if product has ANY sellable stock (main product OR variants)
  /// This matches the web logic: product.is_available and (product.stock_quantity > 0 or has_variant_stock)
  bool get hasAnySellableStock {
    if (!isAvailable) return false;
    
    // Check main product stock
    if (stockQuantity > 0) return true;
    
    // Check if any variant has available stock
    if (variants.isNotEmpty) {
      final hasVariantStock = variants.any((v) => v.isAvailable && v.stockQuantity > 0);
      if (hasVariantStock) return true;
    }
    
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CATEGORY HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get main category display name for UI
  String get displayCategoryName {
    return categoryDisplay ?? mainCategoryName ?? category ?? 'Uncategorized';
  }

  /// Get main category name for filtering
  String? get mainCategory {
    return mainCategoryName;
  }

  /// Get subcategory name (if available)
  String? get subCategory {
    return storeCategoryName;
  }

  /// Get full category path for breadcrumbs
  String? get fullCategoryPath {
    return categoryPath ?? categoryDisplay;
  }

  /// Check if product belongs to a specific main category
  bool belongsToMainCategory(String slug) {
    return mainCategorySlug == slug;
  }

  /// Check if product belongs to a specific store subcategory
  bool belongsToStoreCategory(String slug) {
    return storeCategorySlug == slug;
  }
}