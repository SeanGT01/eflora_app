
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/product_card.dart';
import '../product/product_detail_screen.dart';
import '../main_shell.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/quick_add_variant_sheet.dart';
import '../../utils/responsive.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategorySlug;
  final String? initialCategoryName;
  final String? initialQuery;
  final bool? includeOutsideLocation;

  const SearchScreen({
    super.key,
    this.initialCategorySlug,
    this.initialCategoryName,
    this.initialQuery,
    this.includeOutsideLocation,
  });
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _categorySlug;
  String? _categoryName;
  Timer? _debounce;
  int _searchGen = 0;

  bool get _hasCategory =>
      _categorySlug != null && _categorySlug!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery?.trim() ?? '';
    final slug = widget.initialCategorySlug?.trim() ?? '';
    _categorySlug = slug.isEmpty ? null : slug;
    final name = widget.initialCategoryName?.trim() ?? '';
    _categoryName = name.isEmpty ? null : name;
    if (query.isNotEmpty) _ctrl.text = query;
    if (_hasCategory || query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runSearch();
      });
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    setState(() {});
    if (v.trim().isEmpty && !_hasCategory) {
      _searchGen++;
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), _runSearch);
  }

  Future<void> _runSearch() async {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty && !_hasCategory) {
      _searchGen++;
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    final gen = ++_searchGen;
    setState(() {
      _loading = _results.isEmpty;
      _searched = true;
    });
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final includeOutside =
        widget.includeOutsideLocation ?? (isLoggedIn ? false : true);
    final result = await ApiService.getProducts(
      search: q.isEmpty ? null : q,
      category: _categorySlug,
      includeOutsideLocation: includeOutside,
      perPage: 48,
    );
    if (!mounted || gen != _searchGen) return;
    if (result.isSuccess) {
      final data = result.data;
      List<dynamic> list = data is List
          ? data
          : (data is Map ? (data['products'] ?? []) : []);
      setState(() {
        _results = list
            .whereType<Map>()
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _addToCart(Product p) async {
    if (!context.read<AuthProvider>().isLoggedIn) {
      showAuthRequiredSheet(
        context,
        message: 'Create an account or sign in to add items to your cart',
      );
      return;
    }
    await showQuickAddVariantSheet(context, product: p);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              if (_hasCategory) _buildCategoryContext(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.roseCta),
                      )
                    : !_searched
                        ? _buildSuggestions()
                        : _results.isEmpty
                            ? _buildNoResults()
                            : Builder(
                                builder: (context) {
                                  final r = context.responsive;
                                  return GridView.builder(
                                    padding: EdgeInsets.fromLTRB(
                                      context.pageGutter,
                                      0,
                                      context.pageGutter,
                                      context.s(24),
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: r.productCrossAxisCount,
                                      crossAxisSpacing: r.productCrossSpacing,
                                      mainAxisSpacing: r.productMainSpacing,
                                      childAspectRatio: r.productAspectRatio,
                                    ),
                                    itemCount: _results.length,
                                    itemBuilder: (_, i) => ProductCard(
                                      product: _results[i],
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailScreen(
                                            productId: _results[i].id,
                                          ),
                                        ),
                                      ),
                                      onAddToCart: () => _addToCart(_results[i]),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContext() {
    final label = _categoryName ?? 'Category';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  /// Pill-shaped frosted search field, matching the site's glass search input.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back,
            onTap: () {
              // Pushed from Home → pop. Search tab inside MainShell → go Home.
              // Popping the root route is what left a black screen.
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                MainShell.switchTab(context, 0);
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassCard(
              radius: AppRadius.pill,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.dustyRose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: !_hasCategory,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _runSearch(),
                      cursorColor: AppColors.roseCta,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _hasCategory
                            ? 'Search in ${_categoryName ?? 'this category'}…'
                            : 'Search flowers, plants, categories…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.muted.withValues(alpha: 0.7),
                        ),
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GradientCircleButton(
                      icon: Icons.arrow_forward,
                      size: 30,
                      iconSize: 15,
                      onPressed: _runSearch,
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

  Widget _buildSuggestions() {
    return Consumer<CategoryProvider>(
      builder: (_, categoryProvider, __) {
        final categories = categoryProvider.mainCategories
            .where((cat) => cat.slug != 'all')  // Exclude 'All' category
            .take(5)  // Take first 5 for display
            .toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassSectionTitle(
                eyebrow: 'Discover',
                title: 'Popular Categories',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: categories.map((cat) => GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() {
                      _categorySlug = cat.slug;
                      _categoryName = cat.name;
                    });
                    _runSearch();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.glassBorder, width: 1),
                      boxShadow: AppShadows.glass,
                    ),
                    child: Text(
                      cat.name,
                      style: GoogleFonts.dmSans(
                        color: AppColors.charcoal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoResults() {
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
                child: const Icon(Icons.search_off, size: 30, color: Color(0x99B5445A)),
              ),
              const SizedBox(height: 16),
              Text(
                _hasCategory
                    ? 'No products in ${_categoryName ?? 'this category'}'
                    : 'No results found',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _hasCategory
                    ? 'Try another category or browse outside location'
                    : 'Try a different search term',
                style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round frosted icon button used for the back affordance.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppRadius.pill,
      padding: EdgeInsets.zero,
      width: 42,
      height: 42,
      onTap: onTap,
      child: Center(child: Icon(icon, size: 19, color: AppColors.charcoal)),
    );
  }
}
