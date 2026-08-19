import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../models/category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/product_card.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/quick_add_variant_sheet.dart';
import '../product/product_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../../widgets/chat_drawer.dart';
import 'store_detail_sheet.dart';
import '../../utils/responsive.dart';

class StorePage extends StatefulWidget {
  final int storeId;
  final Store? initialStore; // pass from homepage for instant header

  const StorePage({super.key, required this.storeId, this.initialStore});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Store? _store;
  List<Product> _products = [];
  List<StoreCategory> _categories = [];
  bool _loadingStore = true;
  bool _loadingProducts = true;
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _store = widget.initialStore;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadStore(), _loadProducts(), _loadCategories()]);
  }

  Future<void> _loadStore() async {
    final result = await ApiService.getStore(widget.storeId);
    if (!mounted) return;
    if (result.isSuccess && result.data is Map) {
      setState(() {
        _store = Store.fromJson(result.data as Map<String, dynamic>);
        _loadingStore = false;
      });
    } else {
      setState(() => _loadingStore = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final result = await ApiService.getProducts(storeId: widget.storeId);
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['products'] is List) {
        list = data['products'] as List;
      }
      setState(() {
        _products = list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingProducts = false;
      });
    } else {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.getStoreCategories(widget.storeId);
    if (!mounted) return;
    if (result.isSuccess && result.data is List) {
      setState(() {
        _categories = (result.data as List)
            .map((e) => StoreCategory.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingCategories = false;
      });
    } else {
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _addToCart(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(context);
      return;
    }
    await showQuickAddVariantSheet(context, product: product);
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id)),
    );
  }

  void _openStoreDetails() {
    if (_store == null) return;
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final storeId = _store!.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StoreDetailSheet(
        store: _store!,
        onMessage: () async {
          Navigator.pop(sheetCtx);
          if (!isLoggedIn) {
            showAuthRequiredSheet(
              context,
              message: 'Create an account or sign in to message this store',
            );
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (ctx, _, __) => Material(
                color: Colors.transparent,
                child: ChatDrawer(
                  onClose: () => Navigator.of(ctx).pop(),
                  openStoreId: storeId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCategoryProducts(StoreCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StoreCategoryProductsPage(
          storeId: widget.storeId,
          storeName: _store?.name ?? '',
          category: category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        flowerCount: 6,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── Top actions (always pinned) ──
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              toolbarHeight: 56,
              backgroundColor: AppColors.pageCream,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              forceElevated: false,
              forceMaterialTransparency: false,
              leadingWidth: 60,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _GlassCircleAction(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              actions: [
                _GlassCircleAction(icon: Icons.share_outlined, onTap: () {}),
                const SizedBox(width: 8),
                _CartBadge(),
                const SizedBox(width: 12),
              ],
            ),
            // ── Store identity (scrolls away with content) ──
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.pageCream,
                child: _buildStoreHeader(store),
              ),
            ),
            // ── Tabs stick under the app bar while scrolling ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _StoreTabBarDelegate(
                tabController: _tabController,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildHomeTab(),
              _buildProductsTab(),
              _buildCategoriesTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Store Header (logo + name + meta, sits above sticky tabs) ──
  Widget _buildStoreHeader(Store? store) {
    if (store == null && _loadingStore) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.roseCta,
          ),
        ),
      );
    }
    if (store == null) return const SizedBox(height: 16);

    final metaParts = <String>[];
    if (store.productCount != null) {
      metaParts.add('${store.productCount} products');
    }
    if (store.deliveryRadiusKm != null) {
      metaParts.add(
        '${store.deliveryRadiusKm!.toStringAsFixed(0)}km delivery',
      );
    }
    if (store.avgRating != null && store.avgRating! > 0) {
      metaParts.add('${store.avgRating!.toStringAsFixed(1)}★');
    }

    return GestureDetector(
      onTap: _openStoreDetails,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _buildLogo(store, 52),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          store.name,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: AppColors.charcoal,
                      ),
                    ],
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join(' • '),
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.muted,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildLogo(Store store, double size) {
    final url = store.effectiveLogoUrl;
    if (url != null && url.isNotEmpty) {
      final imageUrl = url.startsWith('http') ? url : ApiService.assetUrl(url);
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorWidget: (_, __, ___) => _logoFallback(store, size),
      );
    }
    return _logoFallback(store, size);
  }

  Widget _logoFallback(Store store, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.imageWash),
      child: Center(
        child: Text(
          store.name.isNotEmpty ? store.name[0].toUpperCase() : 'S',
          style: GoogleFonts.cormorantGaramond(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
            color: AppColors.deepRose,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — HOME (grid like homepage)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    if (_loadingProducts) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.roseCta));
    }
    if (_products.isEmpty) {
      return _emptyState(
          'No Products Yet', 'This store hasn\'t added any products.');
    }
    return RefreshIndicator(
      color: AppColors.roseCta,
      backgroundColor: AppColors.warmWhite,
      onRefresh: _loadProducts,
      child: Builder(
        builder: (context) {
          final r = context.responsive;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              context.pageGutter * 0.7,
              context.s(12),
              context.pageGutter * 0.7,
              context.s(24),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: r.productCrossAxisCount,
              mainAxisSpacing: r.productMainSpacing,
              crossAxisSpacing: r.productCrossSpacing,
              childAspectRatio: r.productAspectRatio,
            ),
            itemCount: _products.length,
            itemBuilder: (context, i) {
              final product = _products[i];
              return ProductCard(
                product: product,
                onTap: () => _openProduct(product),
                onAddToCart: () => _addToCart(product),
              );
            },
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — PRODUCTS (stacked / list view, TikTok shop style)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildProductsTab() {
    if (_loadingProducts) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.roseCta));
    }
    if (_products.isEmpty) {
      return _emptyState(
          'No Products Yet', 'This store hasn\'t added any products.');
    }
    return RefreshIndicator(
      color: AppColors.roseCta,
      backgroundColor: AppColors.warmWhite,
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: _products.length,
        itemBuilder: (context, i) => _ProductListTile(
          product: _products[i],
          onTap: () => _openProduct(_products[i]),
          onAddToCart: () => _addToCart(_products[i]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoriesTab() {
    if (_loadingCategories) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.roseCta));
    }
    final visibleCategories = _categories.where((category) {
      final localCount =
          _products.where((p) => p.storeCategoryId == category.id).length;
      final count = localCount > 0 ? localCount : category.productCount;
      return count > 0;
    }).toList();

    if (visibleCategories.isEmpty) {
      return _emptyState(
          'No Categories', 'This store hasn\'t set up categories yet.');
    }
    return RefreshIndicator(
      color: AppColors.roseCta,
      backgroundColor: AppColors.warmWhite,
      onRefresh: _loadCategories,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: visibleCategories.length,
        itemBuilder: (context, i) => _CategoryTile(
          category: visibleCategories[i],
          onTap: () => _openCategoryProducts(visibleCategories[i]),
        ),
      ),
    );
  }

  Widget _emptyState(String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: AppColors.imageWash,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined,
                    size: 30, color: Color(0x99B5445A)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                  )),
              const SizedBox(height: 5),
              Text(sub,
                  style: GoogleFonts.dmSans(
                      fontSize: 12.5, color: AppColors.muted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky Home / Products / Categories bar — sits flush under the store header,
/// then pins under the app bar once the header scrolls away.
class _StoreTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StoreTabBarDelegate({required this.tabController});

  final TabController tabController;

  static const double _height = 48;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.pageCream,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: tabController.animation ?? tabController,
        builder: (context, _) {
          return Container(
            height: _height,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x1A2C2520), width: 1),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: _StoreTabLabel(
                      label: const ['Home', 'Products', 'Categories'][i],
                      selected: tabController.index == i,
                      onTap: () => tabController.animateTo(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StoreTabBarDelegate oldDelegate) {
    return oldDelegate.tabController != tabController;
  }
}

class _StoreTabLabel extends StatelessWidget {
  const _StoreTabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.roseCta : AppColors.muted,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 2.5,
            width: selected ? 56 : 0,
            decoration: BoxDecoration(
              color: AppColors.roseCta,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round frosted action button used in the store app bar.
class _GlassCircleAction extends StatelessWidget {
  const _GlassCircleAction(
      {required this.icon, required this.onTap, this.child});

  final IconData icon;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppRadius.pill,
      padding: EdgeInsets.zero,
      width: 40,
      height: 40,
      onTap: onTap,
      child: Center(
        child: child ?? Icon(icon, size: 19, color: AppColors.charcoal),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Product List Tile — TikTok shop stacked style
// ══════════════════════════════════════════════════════════════════════════
class _ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductListTile({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.primaryImageUrl;
    final inStock = product.hasAnySellableStock;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.imageWash),
                  ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.roseCta),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.local_florist,
                            size: 28, color: Color(0x8CB5445A)),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.local_florist,
                          size: 28, color: Color(0x8CB5445A)),
                    ),
                  if (!inStock)
                    Container(
                      color: AppColors.charcoal.withValues(alpha: 0.72),
                      child: Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: GoogleFonts.dmSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: SizedBox(
              height: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top: name + category
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.category != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            product.category!.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.labelPink,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        product.name,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Bottom: price + actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₱${product.effectivePrice.toStringAsFixed(2)}',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepRose,
                            ),
                          ),
                          if (product.discountPct != null)
                            Row(
                              children: [
                                Text(
                                  '₱${product.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.badgeGradient,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '${product.discountPct}% off',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          // Add to cart
                          if (inStock)
                            GradientCircleButton(
                              icon: Icons.add_shopping_cart,
                              size: 32,
                              iconSize: 15,
                              onPressed: onAddToCart,
                            )
                          else
                            const _DisabledCircleButton(
                                icon: Icons.add_shopping_cart),
                          const SizedBox(width: 7),
                          // Buy button
                          GestureDetector(
                            onTap: inStock ? onTap : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient:
                                    inStock ? AppColors.brandGradient : null,
                                color: inStock ? null : AppColors.border,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                boxShadow:
                                    inStock ? AppShadows.roseButton : null,
                              ),
                              child: Text(
                                'Buy',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      inStock ? Colors.white : AppColors.muted,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted stand-in for [GradientCircleButton] when the action is unavailable.
class _DisabledCircleButton extends StatelessWidget {
  const _DisabledCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child:
          Icon(icon, size: 15, color: AppColors.muted.withValues(alpha: 0.5)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Category Tile
// ══════════════════════════════════════════════════════════════════════════
class _CategoryTile extends StatelessWidget {
  final StoreCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (category.mainCategoryName != null) ...[
                      Text(
                        category.mainCategoryName!.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.labelPink,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                    Text(
                      '${category.productCount} product${category.productCount == 1 ? '' : 's'}',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                if (category.description != null &&
                    category.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category.description!,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5,
                      color: AppColors.muted.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.dustyRose),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Cart Badge (reuse pattern)
// ══════════════════════════════════════════════════════════════════════════
class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().itemCount;
    return _GlassCircleAction(
      icon: Icons.shopping_bag_outlined,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined,
              size: 19, color: AppColors.charcoal),
          if (count > 0)
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  gradient: AppColors.badgeGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: GoogleFonts.dmSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Category Products Page (opened from Categories tab)
// ══════════════════════════════════════════════════════════════════════════
class _StoreCategoryProductsPage extends StatefulWidget {
  final int storeId;
  final String storeName;
  final StoreCategory category;

  const _StoreCategoryProductsPage({
    required this.storeId,
    required this.storeName,
    required this.category,
  });

  @override
  State<_StoreCategoryProductsPage> createState() =>
      _StoreCategoryProductsPageState();
}

class _StoreCategoryProductsPageState
    extends State<_StoreCategoryProductsPage> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiService.getProducts(storeId: widget.storeId);
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['products'] is List) {
        list = data['products'] as List;
      }
      final all =
          list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      // Filter by store subcategory
      setState(() {
        _products =
            all.where((p) => p.storeCategoryId == widget.category.id).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: product.id)),
    );
  }

  Future<void> _addToCart(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(context);
      return;
    }
    await showQuickAddVariantSheet(context, product: product);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      flowerCount: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 4,
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
            child: _GlassCircleAction(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.storeName.isNotEmpty)
                Text(
                  widget.storeName.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dustyRose,
                    letterSpacing: 1.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                widget.category.name,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.roseCta))
              : _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.imageWash,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.category_outlined,
                                    size: 28, color: Color(0x99B5445A)),
                              ),
                              const SizedBox(height: 14),
                              Text('No products in this category',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13, color: AppColors.muted),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 60, 12, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, i) {
                        final product = _products[i];
                        return ProductCard(
                          product: product,
                          onTap: () => _openProduct(product),
                          onAddToCart: () => _addToCart(product),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Tab Bar Delegate (pinned persistent header)
// ══════════════════════════════════════════════════════════════════════════
