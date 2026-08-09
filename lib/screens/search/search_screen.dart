
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
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String q, {String? categorySlug}) async {
    if (q.trim().isEmpty && (categorySlug == null || categorySlug.isEmpty)) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() { _loading = true; _searched = true; });
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final result = await ApiService.getProducts(
      search: categorySlug == null || categorySlug.isEmpty ? q.trim() : null,
      category: categorySlug,
      // Match home: filter to default-address coverage when signed in
      includeOutsideLocation: isLoggedIn ? false : true,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      List<dynamic> list = data is List ? data : (data is Map ? (data['products'] ?? []) : []);
      setState(() {
        _results = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        flowerCount: 10,
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
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
                                      context.s(4),
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
                      autofocus: true,
                      onChanged: (v) { if (v.isEmpty) setState(() { _results = []; _searched = false; }); },
                      onSubmitted: _search,
                      cursorColor: AppColors.roseCta,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search flowers, plants, categories…',
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
                      onPressed: () => _search(_ctrl.text),
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
                    _ctrl.text = cat.name;
                    _search(cat.name, categorySlug: cat.slug);
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
                'No results found',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try a different search term',
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
