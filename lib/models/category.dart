/// Global main category (e.g., "Bouquets", "Plants", "Flowers")
class Category {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Uncategorized',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Category(id=$id, name=$name, slug=$slug)';
}

/// Store-specific subcategory (e.g., "Crochet Bouquets" under "Bouquets" for Store X)
class StoreCategory {
  final int id;
  final int storeId;
  final int mainCategoryId;
  final String? mainCategoryName;
  final String? mainCategorySlug;
  final String? mainCategoryIcon;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final String? fullPath;
  final int productCount;
  final Map<String, dynamic>? customAttributes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Optional: Store the related main category for convenience
  final Category? mainCategory;

  const StoreCategory({
    required this.id,
    required this.storeId,
    required this.mainCategoryId,
    this.mainCategoryName,
    this.mainCategorySlug,
    this.mainCategoryIcon,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.fullPath,
    this.productCount = 0,
    this.customAttributes,
    this.createdAt,
    this.updatedAt,
    this.mainCategory,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id'] as int? ?? 0,
      storeId: json['store_id'] as int? ?? 0,
      mainCategoryId: json['main_category_id'] as int? ?? 0,
      mainCategoryName: json['main_category_name'] as String?,
      mainCategorySlug: json['main_category_slug'] as String?,
      mainCategoryIcon: json['main_category_icon'] as String?,
      name: json['name'] as String? ?? 'Uncategorized',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      fullPath: json['full_path'] as String?,
      productCount: json['product_count'] as int? ?? 0,
      customAttributes: json['custom_attributes'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      mainCategory: json['main_category'] != null
          ? Category.fromJson(json['main_category'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'main_category_id': mainCategoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'custom_attributes': customAttributes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'main_category': mainCategory?.toJson(),
    };
  }

  @override
  String toString() => 'StoreCategory(id=$id, name=$name, slug=$slug)';
}
