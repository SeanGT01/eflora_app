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
import '../../widgets/product_card.dart';
import '../../widgets/common.dart';
import '../product/product_detail_screen.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/quick_add_variant_sheet.dart';
import '../../utils/responsive.dart';
import '../../navigation/floating_nav_metrics.dart';

const _kDeepRose = Color(0xFFB5445A);
const _kDustyRose = Color(0xFFD4788A);
const _kSoftBlush = Color(0xFFFBE9EE);
const _kTextCharcoal = Color(0xFF2C2520);
const _kMuted = Color(0xFF8F7D79);
const _kBorder = Color(0xFFF0DDE2);

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
        child: Column(
          children: [
            EfloraTopBar(
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: _kTextCharcoal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
            ),
            _buildSearchBar(),
            if (_hasCategory) _buildCategoryContext(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kDeepRose),
                    )
                  : !_searched
                      ? _buildSuggestions()
                      : _results.isEmpty
                          ? _buildNoResults()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_hasCategory)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      context.pageGutter,
                                      2,
                                      context.pageGutter,
                                      8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_results.length} bloom${_results.length != 1 ? 's' : ''} found',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _kMuted,
                                          ),
                                        ),
                                        if (_ctrl.text.isNotEmpty)
                                          Text(
                                            '"${_ctrl.text}"',
                                            style: GoogleFonts.cormorantGaramond(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: _kDeepRose,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final r = context.responsive;
                                      return GridView.builder(
                                        padding: EdgeInsets.fromLTRB(
                                          context.pageGutter,
                                          0,
                                          context.pageGutter,
                                          floatingNavScrollClearance(context),
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount:
                                              r.productCrossAxisCount,
                                          crossAxisSpacing:
                                              r.productCrossSpacing,
                                          mainAxisSpacing:
                                              r.productMainSpacing,
                                          childAspectRatio:
                                              r.productAspectRatio,
                                        ),
                                        itemCount: _results.length,
                                        itemBuilder: (_, i) => ProductCard(
                                          product: _results[i],
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailScreen(
                                                productId: _results[i].id,
                                              ),
                                            ),
                                          ),
                                          onAddToCart: () =>
                                              _addToCart(_results[i]),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContext() {
    final label = _categoryName ?? 'Category';
    final countText = _loading || !_searched
        ? 'Searching blooms…'
        : '${_results.length} bloom${_results.length != 1 ? 's' : ''} found';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countText,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kDustyRose,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _kTextCharcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() {
                _categorySlug = null;
                _categoryName = null;
              });
              _runSearch();
            },
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kSoftBlush,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: _kBorder, width: 0.9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clear Filter',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kDeepRose,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.close_rounded, size: 13, color: _kDeepRose),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Refined pill-shaped search field matching E-FLORA design language.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: _kBorder, width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A502846),
              blurRadius: 14,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: _kDustyRose),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: !_hasCategory,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _runSearch(),
                cursorColor: _kDeepRose,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _hasCategory
                      ? 'Search in ${_categoryName ?? 'this category'}…'
                      : 'Search flowers, bouquets, plants…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: _kMuted.withValues(alpha: 0.75),
                  ),
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  color: _kTextCharcoal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_ctrl.text.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  _onQueryChanged('');
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: _kSoftBlush,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: _kDeepRose),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _runSearch,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: _kDeepRose,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 15, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Consumer<CategoryProvider>(
      builder: (_, categoryProvider, __) {
        final categories = categoryProvider.mainCategories
            .where((cat) => cat.slug != 'all')
            .take(6)
            .toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, floatingNavScrollClearance(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DISCOVER',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _kDustyRose,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Popular Categories',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _kTextCharcoal,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categories.map((cat) => Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    side: const BorderSide(color: _kBorder, width: 1.1),
                  ),
                  elevation: 0.8,
                  shadowColor: const Color(0x0A502846),
                  child: InkWell(
                    onTap: () {
                      _ctrl.clear();
                      setState(() {
                        _categorySlug = cat.slug;
                        _categoryName = cat.name;
                      });
                      _runSearch();
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        cat.name,
                        style: GoogleFonts.dmSans(
                          color: _kTextCharcoal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C502846),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kSoftBlush,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder, width: 1.2),
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 34, color: _kDeepRose),
              ),
              const SizedBox(height: 18),
              Text(
                _hasCategory
                    ? 'No products in ${_categoryName ?? 'this category'}'
                    : 'No blooms found',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _kTextCharcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _hasCategory
                    ? 'Try another category or search for all floral arrangements.'
                    : 'Try a different keyword or explore our popular categories.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _kMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_hasCategory || _ctrl.text.isNotEmpty)
                RoseButton(
                  label: 'Browse All Flowers',
                  onPressed: () {
                    _ctrl.clear();
                    setState(() {
                      _categorySlug = null;
                      _categoryName = null;
                    });
                    _runSearch();
                  },
                  width: double.infinity,
                  icon: Icons.local_florist_rounded,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
