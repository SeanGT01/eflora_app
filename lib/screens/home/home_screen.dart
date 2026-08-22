import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/api_service.dart';
import '../../services/app_quality.dart';
import '../../services/image_preloader.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_blur.dart';
import '../../widgets/glass.dart';
import '../../widgets/product_card.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/quick_add_variant_sheet.dart';
import '../product/product_detail_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
import '../store/store_page.dart';
import '../../widgets/profile_onboarding_flow.dart';
import '../../utils/responsive.dart';

/// Web hero slides use a 145° linear gradient; this diagonal reads the same in
/// Flutter's alignment space.
/// Web hero slides: `linear-gradient(145deg, …)` with stops at 0 / 55% / 82% / 100%.
LinearGradient _heroGradient(List<Color> colors) => LinearGradient(
      begin: const AlignmentDirectional(-1, -0.72),
      end: const AlignmentDirectional(1, 0.72),
      colors: colors,
      stops: const [0.0, 0.55, 0.82, 1.0],
    );

/// Radial recipes behind the web category tiles, keyed by category slug.
/// Matches web `.category-image-wrap.icon-*` radial stops.
const List<List<Color>> _kCategoryTileRamps = [
  [Color(0xFFF4A0B4), Color(0xFFF0C4A8), Color(0xFFF2B0C0)], // pink
  [Color(0xFF7ED4A0), Color(0xFFD4E888), Color(0xFF88D4A0)], // green
  [Color(0xFFF0B888), Color(0xFFF0A8BC), Color(0xFFF0B890)], // rose / peach
  [Color(0xFFB8A0E8), Color(0xFFA0B8F0), Color(0xFFB8A8E0)], // lavender
];

const Map<String, int> _kCategoryRampBySlug = {
  'fresh-flowers': 0,
  'potted-plants': 1,
  'bouquets': 2,
  'succulents': 3,
};

/// Same PNGs as the promotional banner / web category tiles.
const Map<String, String> _kCategoryImageBySlug = {
  'fresh-flowers': '/static/images/category_images/fresh_flowers.webp',
  'potted-plants': '/static/images/category_images/potted_plants.webp',
  'bouquets': '/static/images/category_images/bouquets.webp',
  'succulents': '/static/images/category_images/succulents.webp',
};

/// Mirrors the web `index.html` hero slides (gradients, copy, imagery).
class _LandingHeroSlide {
  final String eyebrow;
  final String titleUpper;
  final String titleItalic;
  final String subtitle;
  final String imageUrl;
  final LinearGradient gradient;

  const _LandingHeroSlide({
    required this.eyebrow,
    required this.titleUpper,
    required this.titleItalic,
    required this.subtitle,
    required this.imageUrl,
    required this.gradient,
  });
}

/// Per-slide image pose matching web `.hero-slide` prev / active / next / hidden.
class _HeroImagePose {
  final double opacity;
  final double tx;
  final double scale;
  final double blurSigma;
  final double rotY;

  const _HeroImagePose({
    required this.opacity,
    required this.tx,
    required this.scale,
    required this.blurSigma,
    required this.rotY,
  });

  static _HeroImagePose lerpPose(_HeroImagePose a, _HeroImagePose b, double t) {
    return _HeroImagePose(
      opacity: lerpDouble(a.opacity, b.opacity, t)!,
      tx: lerpDouble(a.tx, b.tx, t)!,
      scale: lerpDouble(a.scale, b.scale, t)!,
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      rotY: lerpDouble(a.rotY, b.rotY, t)!,
    );
  }
}

_HeroImagePose _heroPoseForSlide({
  required int slideIndex,
  required int centerIndex,
  required int n,
  required double halfWidth,
}) {
  final r = (slideIndex - centerIndex + n) % n;
  if (r == 0) {
    return _HeroImagePose(
      opacity: 1,
      tx: 0,
      scale: 1.18,
      blurSigma: 0,
      rotY: 0,
    );
  }
  if (r == 1) {
    return _HeroImagePose(
      opacity: 0.52,
      tx: 0.42 * halfWidth,
      scale: 0.66,
      blurSigma: 1.1,
      rotY: 0.09,
    );
  }
  if (r == n - 1) {
    return _HeroImagePose(
      opacity: 0.52,
      tx: -0.42 * halfWidth,
      scale: 0.66,
      blurSigma: 1.1,
      rotY: -0.09,
    );
  }
  return const _HeroImagePose(
    opacity: 0,
    tx: 0,
    scale: 0.5,
    blurSigma: 0,
    rotY: 0,
  );
}

const Curve _heroSlideCurve = Cubic(0.4, 0, 0.2, 1);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Horizontal inset for banner, categories, and main sections (aligned rhythm).
  /// Prefer [context.pageGutter] at build time; this is the design-token fallback.
  static const double _kHomeGutter = 20;
  static const double _kBannerTop = 10;
  static const double _kBannerToCategories = 14;

  List<Product> _products = [];
  List<Store> _stores = [];
  bool _loadingProducts = true;
  bool _loadingStores = true;
  /// Last customer id we already attempted onboarding for (null = guest).
  String? _onboardingForUserId;
  String _selectedCategorySlug = 'all'; // Using slug from CategoryProvider
  bool _browseOutsideLocation = false;
  bool _browseLimitationsDismissed =
      false; // Track if user dismissed the limitation modal
  /// Tracks auth identity so we re-fetch when the user signs in/out.
  String? _lastAuthUserId;
  bool _authIdentityTracked = false;
  late ScrollController _storesScrollController;
  late ScrollController _bodyScrollController;
  late AnimationController _heroProgressController;
  late AnimationController _heroSlideController;

  /// Committed hero slide (center / active).
  int _heroIndex = 0;
  int _heroAnimFrom = 0;
  int _heroAnimTo = 0;
  bool _heroSlideAnimating = false;
  late final List<_LandingHeroSlide> _heroSlides;

  @override
  void initState() {
    super.initState();
    _storesScrollController = ScrollController();
    _bodyScrollController = ScrollController();
    _heroSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )
      ..addListener(_onHeroSlideTick)
      ..addStatusListener(_onHeroSlideStatus);
    _heroProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )
      ..addStatusListener(_onHeroProgressStatus)
      ..addListener(_onHeroProgressTick);

    _heroSlides = [
      _LandingHeroSlide(
        eyebrow: 'Fresh Flowers',
        titleUpper: 'THE NEW',
        titleItalic: 'Must Haves',
        subtitle:
            'Roses, tulips, lilies & more — handpicked from local farms, delivered fresh to your door.',
        imageUrl: ApiService.assetUrl(
            '/static/images/category_images/fresh_flowers.png'),
        gradient: _heroGradient(
          [
            Color(0xFFC24E68),
            Color(0xFFE07890),
            Color(0xFFE8A090),
            Color(0xFFD46078)
          ],
        ),
      ),
      _LandingHeroSlide(
        eyebrow: 'Potted Plants',
        titleUpper: 'BRING LIFE',
        titleItalic: 'Indoors',
        subtitle:
            'Indoor & outdoor beauties that transform any space into a green sanctuary.',
        imageUrl: ApiService.assetUrl(
            '/static/images/category_images/potted_plants.png'),
        gradient: _heroGradient(
          [
            Color(0xFF3F8A5C),
            Color(0xFF5CB07A),
            Color(0xFF8CBC68),
            Color(0xFF4A9870)
          ],
        ),
      ),
      _LandingHeroSlide(
        eyebrow: 'Bouquets',
        titleUpper: 'PERFECT FOR',
        titleItalic: 'Every Moment',
        subtitle:
            'Curated arrangements for birthdays, anniversaries, and every occasion worth celebrating.',
        imageUrl:
            ApiService.assetUrl('/static/images/category_images/bouquets.png'),
        gradient: _heroGradient(
          [
            Color(0xFFD07850),
            Color(0xFFE09870),
            Color(0xFFE890A0),
            Color(0xFFD88860)
          ],
        ),
      ),
      _LandingHeroSlide(
        eyebrow: 'Succulents',
        titleUpper: 'LOW CARE',
        titleItalic: 'High Beauty',
        subtitle:
            'Resilient, stylish, and endlessly charming — perfect for busy plant lovers.',
        imageUrl: ApiService.assetUrl(
            '/static/images/category_images/succulents.png'),
        gradient: _heroGradient(
          [
            Color(0xFF7A68B8),
            Color(0xFF9880D0),
            Color(0xFF7890D8),
            Color(0xFF8878C4)
          ],
        ),
      ),
    ];
    _heroAnimFrom = 0;
    _heroAnimTo = 0;

    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppQuality.instance.useRichHero) _restartHeroProgress();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack keeps Home alive — re-fetch when login/logout changes
    // so location filtering matches the signed-in default address (like web).
    final auth = context.watch<AuthProvider>();
    final userId = auth.user?.id.toString();
    if (!_authIdentityTracked || userId != _lastAuthUserId) {
      final shouldReload = _authIdentityTracked;
      _authIdentityTracked = true;
      _lastAuthUserId = userId;
      if (shouldReload) {
        _browseOutsideLocation = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadData();
        });
      }
    }

    // Required gender / birthday / address prompts for customers.
    // Track per user id so a fresh login after registration always re-runs.
    if (auth.isLoggedIn && auth.user?.role == 'customer') {
      if (_onboardingForUserId != userId) {
        _onboardingForUserId = userId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) maybeRunProfileOnboarding(context);
        });
      }
    } else {
      _onboardingForUserId = null;
    }
  }

  void _onHeroProgressTick() {
    if (mounted) setState(() {});
  }

  void _onHeroSlideTick() {
    if (mounted) setState(() {});
  }

  void _onHeroSlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _heroIndex = _heroAnimTo;
      _heroAnimFrom = _heroIndex;
      _heroSlideAnimating = false;
    });
    _heroSlideController.reset();
    _restartHeroProgress();
  }

  void _onHeroProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_heroSlideAnimating) return;
    final next = (_heroIndex + 1) % _heroSlides.length;
    _beginHeroSlideAnimation(next);
  }

  void _restartHeroProgress() {
    if (!AppQuality.instance.useRichHero) return;
    _heroProgressController
      ..reset()
      ..forward();
  }

  double get _heroSlideT {
    if (!_heroSlideAnimating) return 0;
    return _heroSlideCurve.transform(_heroSlideController.value);
  }

  void _beginHeroSlideAnimation(int toIndex) {
    if (toIndex == _heroIndex || _heroSlideAnimating) return;
    _heroProgressController.stop();
    setState(() {
      _heroAnimFrom = _heroIndex;
      _heroAnimTo = toIndex;
      _heroSlideAnimating = true;
    });
    _heroSlideController.forward(from: 0);
  }

  void _heroGoTo(int index) {
    if (index == _heroIndex || _heroSlideAnimating) return;
    _beginHeroSlideAnimation(index);
  }

  void _heroPrev() {
    final prev = (_heroIndex - 1 + _heroSlides.length) % _heroSlides.length;
    _heroGoTo(prev);
  }

  void _heroNext() {
    final next = (_heroIndex + 1) % _heroSlides.length;
    _heroGoTo(next);
  }

  @override
  void dispose() {
    _heroSlideController
      ..removeStatusListener(_onHeroSlideStatus)
      ..removeListener(_onHeroSlideTick)
      ..dispose();
    _heroProgressController
      ..removeStatusListener(_onHeroProgressStatus)
      ..removeListener(_onHeroProgressTick)
      ..dispose();
    _bodyScrollController.dispose();
    _storesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final category =
        _selectedCategorySlug == 'all' ? null : _selectedCategorySlug;
    await Future.wait([_loadProducts(category: category), _loadStores()]);
  }

  // REMOVE THE DUPLICATE _loadProducts METHOD - KEEP ONLY THIS ONE
  Future<void> _loadProducts({String? category}) async {
    setState(() => _loadingProducts = true);
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    // Logged-in: only in-range shops/products unless "Browse outside" is on.
    // Guests: show everything (API has no address to filter on).
    final result = await ApiService.getProducts(
      category: (category == 'all' || category == null) ? null : category,
      includeOutsideLocation: isLoggedIn ? _browseOutsideLocation : true,
      page: 1,
    );
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

      // Preload images after products are loaded
      _preloadImages();
    } else {
      setState(() => _loadingProducts = false);
    }
  }

  // Add this new method for preloading
  Future<void> _preloadImages() async {
    if (!AppQuality.instance.preloadImages) return;
    if (_products.isNotEmpty) {
      await ImagePreloader().preloadProductImages(_products);
    }
  }

  Future<void> _loadStores() async {
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    final result = await ApiService.getStores(
      includeOutsideLocation: isLoggedIn ? _browseOutsideLocation : true,
    );
    if (!mounted) return;
    if (result.isSuccess && result.data is List) {
      setState(() {
        _stores = (result.data as List)
            .map((e) => Store.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingStores = false;
      });
    } else {
      setState(() => _loadingStores = false);
    }
  }

  Future<void> _addToCart(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _showAuthSheet();
      return;
    }
    await showQuickAddVariantSheet(context, product: product);
  }

  void _showAuthSheet() {
    showAuthRequiredSheet(context);
  }

  void _navigateToLogin() => pushLoginScreen(context);

  void _navigateToRegister() => pushRegisterScreen(context);

  Future<bool> _showBrowseLimitationsModal() async {
    bool dontShowAgain = false;

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Browse Outside Coverage Area'),
            content: StatefulBuilder(
              builder: (context, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You can browse products from stores outside your delivery area, but:',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    '• You cannot add items to cart from unavailable stores',
                    '• You cannot checkout unless you change your address to match store delivery coverage',
                  ].map((text) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          text,
                          style: GoogleFonts.dmSans(fontSize: 12, height: 1.4),
                        ),
                      )),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox.adaptive(
                        value: dontShowAgain,
                        onChanged: (v) =>
                            setDialogState(() => dontShowAgain = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Do not show again',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (dontShowAgain) {
                    setState(() => _browseLimitationsDismissed = true);
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Continue',
                    style: TextStyle(
                        color: AppColors.deepRose,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: RefreshIndicator(
          color: AppColors.roseCta,
          backgroundColor: AppColors.pageCream,
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _bodyScrollController,
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    context.s(_kBannerTop),
                    gutter,
                    0,
                  ),
                  child: _buildHero(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    context.s(_kBannerToCategories),
                    gutter,
                    0,
                  ),
                  child: _buildCategoryBar(),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildProductsSection(),
              ),
              SliverToBoxAdapter(
                child: _buildStoresSection(),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  // Clear bottom nav only — avoid a large empty scroll region.
                  height: MediaQuery.paddingOf(context).bottom + context.s(72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final auth = context.watch<AuthProvider>();
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: AdaptiveBlur(
          sigma: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient:
                  AppQuality.instance.useBlur ? AppColors.headerGlass : null,
              color:
                  AppQuality.instance.useBlur ? null : const Color(0xF5FFFAFC),
              border: const Border(
                bottom: BorderSide(color: Color(0x8CFFFFFF), width: 1),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0FB5445A),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      titleSpacing: _kHomeGutter - 4,
      title: Row(
        children: [
          // Flower logo (matching web SVG)
          SizedBox(
            width: 38,
            height: 38,
            child: CustomPaint(
              painter: _FlowerLogoPainter(),
            ),
          ),
          const SizedBox(width: 5),
          // Logo text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'E-FLORA',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                  height: 1.0,
                ),
              ),
              Text(
                'Blooming with Technology',
                style: GoogleFonts.dmSans(
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 0.18,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchScreen(),
              )),
        ),
        if (auth.isLoggedIn) ...[
          _CartIconButton(),
        ] else
          TextButton(
            onPressed: _navigateToLogin,
            child: Text(
              'Sign in',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.roseCta,
              ),
            ),
          ),
        SizedBox(width: _kHomeGutter / 2),
      ],
    );
  }

  Widget _buildHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        final screenH = MediaQuery.sizeOf(context).height;
        // Compact band ~25–27% of screen (matches reference app screenshot proportion).
        final heroHeight = (screenH * 0.26).clamp(168.0, 236.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.pageCream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E2A231E),
                blurRadius: 64,
                offset: Offset(0, 16),
              ),
              BoxShadow(
                color: Color(0x1F502846),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: heroHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: _buildHeroInterior(isWide: isWide),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: _heroProgressController.value,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroNavButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F502846), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroInterior({required bool isWide}) {
    final t = _heroSlideT;
    final from = _heroSlideAnimating ? _heroAnimFrom : _heroIndex;
    final to = _heroSlideAnimating ? _heroAnimTo : _heroIndex;
    final lerped = Gradient.lerp(
      _heroSlides[from].gradient,
      _heroSlides[to].gradient,
      t,
    );
    final gradient =
        lerped is LinearGradient ? lerped : _heroSlides[to].gradient;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 38,
                  child: _buildHeroTextCrossfade(
                    from: from,
                    to: to,
                    t: t,
                    isWide: isWide,
                    compact: true,
                  ),
                ),
                Expanded(
                  flex: 62,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: _buildHeroImageCarousel(
                              panelWidth: c.maxWidth,
                              panelHeight: c.maxHeight,
                              from: from,
                              to: to,
                              t: t,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _heroNavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: _heroPrev,
                ),
                const SizedBox(width: 6),
                _heroNavButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  onTap: _heroNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTextCrossfade({
    required int from,
    required int to,
    required double t,
    required bool isWide,
    bool compact = false,
  }) {
    if (from == to) {
      return _buildHeroTextBlock(
        _heroSlides[from],
        isWide: isWide,
        compact: compact,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: IgnorePointer(
            ignoring: t >= 0.5,
            child: _buildHeroTextBlock(
              _heroSlides[from],
              isWide: isWide,
              compact: compact,
            ),
          ),
        ),
        Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: IgnorePointer(
            ignoring: t < 0.5,
            child: _buildHeroTextBlock(
              _heroSlides[to],
              isWide: isWide,
              compact: compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImageCarousel({
    required double panelWidth,
    required double panelHeight,
    required int from,
    required int to,
    required double t,
  }) {
    final n = _heroSlides.length;
    final halfW = panelWidth * 0.5;
    final order = List<int>.generate(n, (i) => i);
    order.sort((a, b) {
      double opFor(int idx) {
        final pa = _heroPoseForSlide(
          slideIndex: idx,
          centerIndex: from,
          n: n,
          halfWidth: halfW,
        );
        final pb = _heroPoseForSlide(
          slideIndex: idx,
          centerIndex: to,
          n: n,
          halfWidth: halfW,
        );
        return _HeroImagePose.lerpPose(pa, pb, t).opacity;
      }

      final c = opFor(a).compareTo(opFor(b));
      return c != 0 ? c : a.compareTo(b);
    });

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        for (final i in order)
          _buildHeroImageLayer(
            slideIndex: i,
            from: from,
            to: to,
            halfWidth: halfW,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            t: t,
            n: n,
          ),
        _buildHeroImagePillCrossfade(from: from, to: to, t: t),
      ],
    );
  }

  Widget _buildHeroImageLayer({
    required int slideIndex,
    required int from,
    required int to,
    required double halfWidth,
    required double panelWidth,
    required double panelHeight,
    required double t,
    required int n,
  }) {
    final slide = _heroSlides[slideIndex];
    final pa = _heroPoseForSlide(
      slideIndex: slideIndex,
      centerIndex: from,
      n: n,
      halfWidth: halfWidth,
    );
    final pb = _heroPoseForSlide(
      slideIndex: slideIndex,
      centerIndex: to,
      n: n,
      halfWidth: halfWidth,
    );
    final p = _HeroImagePose.lerpPose(pa, pb, t);
    if (p.opacity < 0.02) return const SizedBox.shrink();

    final w = panelWidth * 1.02;
    final h = panelHeight * 1.02;

    Widget core = Opacity(
      opacity: p.opacity.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(p.rotY)
          ..translate(p.tx)
          ..scale(p.scale, p.scale),
        child: CachedNetworkImage(
          imageUrl: slide.imageUrl,
          width: w,
          height: h,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          placeholder: (_, __) => SizedBox(width: w, height: h * 0.45),
          errorWidget: (_, __, ___) => Icon(
            Icons.local_florist,
            size: 56,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );

    if (p.blurSigma > 0.15 && AppQuality.instance.useBlur) {
      core = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: p.blurSigma, sigmaY: p.blurSigma),
        child: core,
      );
    }

    return Positioned.fill(
      child: Center(child: core),
    );
  }

  Widget _buildHeroImagePillCrossfade({
    required int from,
    required int to,
    required double t,
  }) {
    if (from == to) {
      return Positioned(
        top: 4,
        right: 4,
        child: _heroCategoryPill(_heroSlides[from].eyebrow),
      );
    }
    return Positioned(
      top: 4,
      right: 4,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: _heroCategoryPill(_heroSlides[from].eyebrow),
            ),
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: _heroCategoryPill(_heroSlides[to].eyebrow),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCategoryPill(String eyebrow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        eyebrow.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeroTextBlock(
    _LandingHeroSlide slide, {
    required bool isWide,
    bool compact = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : (compact ? 180.0 : 260.0);

        // Scale type from banner height so copy fills the vacated button space.
        final titleSize =
            (maxH * 0.195).clamp(compact ? 20.0 : 24.0, isWide ? 36.0 : 30.0);
        final italicSize = titleSize * 0.78;
        final subtitleSize = (maxH * 0.078).clamp(11.5, 15.5);
        final eyebrowSize = (maxH * 0.058).clamp(9.0, 11.5);
        final gapEyebrow = (maxH * 0.04).clamp(4.0, 10.0);
        final gapBody = (maxH * 0.048).clamp(6.0, 14.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 0 : _kHomeGutter,
            compact ? 2 : 8,
            compact ? 4 : _kHomeGutter,
            compact ? 2 : 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 18 : 20,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Text(
                      slide.eyebrow.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: eyebrowSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapEyebrow),
              Text(
                slide.titleUpper.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: -0.45,
                  color: Colors.white,
                ),
              ),
              Text(
                slide.titleItalic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: italicSize,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  height: 1.12,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: gapBody),
              Text(
                slide.subtitle,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: subtitleSize,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return Consumer<CategoryProvider>(
      builder: (_, categoryProvider, __) {
        final categories = categoryProvider.mainCategories;
        if (categories.isEmpty) {
          return Center(
            child: Text(
              'Loading categories...',
              style:
                  GoogleFonts.dmSans(fontSize: 12, color: AppColors.dustyRose),
            ),
          );
        }
        return Column(
          children: [
            Builder(
              builder: (context) {
                final r = context.responsive;
                final scale = r.scale;
                final iconSize = (56 * scale).clamp(52.0, 64.0);
                final fontSize = (14.5 * scale).clamp(13.0, 16.5);
                final barHeight = iconSize + 8 + (fontSize * 2.4);
                return SizedBox(
                  height: barHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: (10 * scale).clamp(8.0, 14.0)),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      return _CategoryTile(
                        label: cat.name,
                        slug: cat.slug,
                        index: i,
                        selected: _selectedCategorySlug == cat.slug,
                        scale: scale,
                        onTap: () {
                          setState(() => _selectedCategorySlug = cat.slug);
                          final categoryParam =
                              cat.slug == 'all' ? null : cat.slug;
                          _loadProducts(category: categoryParam);
                        },
                      );
                    },
                  ),
                );
              },
            ),
            // Browse outside location — signed-in users only
            if (context.watch<AuthProvider>().isLoggedIn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassCard(
                  radius: AppRadius.pill,
                  padding: const EdgeInsets.fromLTRB(10, 4, 18, 4),
                  child: Row(
                    children: [
                      Switch.adaptive(
                        value: _browseOutsideLocation,
                        activeTrackColor: AppColors.roseCta,
                        activeThumbColor: Colors.white,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor:
                            AppColors.blush.withValues(alpha: 0.55),
                        trackOutlineColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? AppColors.roseCta
                              : AppColors.dustyRose.withValues(alpha: 0.45),
                        ),
                        onChanged: (v) async {
                          if (v && !_browseLimitationsDismissed) {
                            // Show limitations modal only when toggling ON and not dismissed before
                            final confirmed =
                                await _showBrowseLimitationsModal();
                            if (confirmed) {
                              setState(() => _browseOutsideLocation = v);
                              await _loadData();
                            }
                          } else if (!v) {
                            // Allow toggling OFF without showing modal
                            setState(() => _browseOutsideLocation = v);
                            await _loadData();
                          } else {
                            // Already dismissed, just toggle
                            setState(() => _browseOutsideLocation = v);
                            await _loadData();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Browse outside location',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProductsSection() {
    final r = context.responsive;
    final gutter = context.pageGutter;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: r.productCrossAxisCount,
      crossAxisSpacing: r.productCrossSpacing,
      mainAxisSpacing: r.productMainSpacing,
      childAspectRatio: r.productAspectRatio,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, context.s(14), gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassSectionTitle(
            eyebrow: 'Featured',
            title: 'Our Collection',
          ),
          SizedBox(height: context.s(2)),
          Text(
            'Handpicked blooms from local florists',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: context.s(8)),
          if (_loadingProducts)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: gridDelegate,
              itemCount: 6,
              itemBuilder: (_, __) => const _GlassProductShimmer(),
            )
          else if (_products.isEmpty)
            _buildEmptyState(
              'No products found',
              context.watch<AuthProvider>().isLoggedIn &&
                      !_browseOutsideLocation
                  ? 'No shops deliver to your default address yet.\nTry another category or browse outside location.'
                  : 'Try a different category',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: gridDelegate,
              itemCount: _products.length,
              itemBuilder: (_, i) => ProductCard(
                product: _products[i],
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailScreen(productId: _products[i].id),
                    )),
                onAddToCart: () => _addToCart(_products[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoresSection() {
    if (_stores.isEmpty) return const SizedBox();

    final gutter = context.pageGutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, context.s(12), gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassSectionTitle(eyebrow: 'Local Shops', title: 'Our Stores'),
          SizedBox(height: context.s(8)),
          SizedBox(
            height: context.s(112).clamp(100.0, 124.0),
            child: ListView.separated(
              controller: _storesScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _stores.length,
              separatorBuilder: (_, __) => SizedBox(width: context.s(12)),
              itemBuilder: (_, i) {
                return _StoreChip(store: _stores[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                gradient: AppColors.imageWash,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_florist_outlined,
                size: 34,
                color: AppColors.deepRose.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cart icon with badge ──────────────────────────────────────────────────────
class _CartIconButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().itemCount;
    return IconButton(
      onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined),
          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    gradient: AppColors.badgeGradient, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: GoogleFonts.dmSans(
                        fontSize: 8.5,
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

// ── Store chip ────────────────────────────────────────────────────────────────
class _StoreChip extends StatelessWidget {
  final Store store;
  const _StoreChip({required this.store});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: 140,
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StorePage(storeId: store.id, initialStore: store)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: AppColors.blushGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33B5445A),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: ClipOval(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.pageCream,
                    shape: BoxShape.circle,
                  ),
                  child: _buildLogo(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              store.name,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.15,
                color: AppColors.charcoal,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final effectiveUrl = store.effectiveLogoUrl;

    if (effectiveUrl == null || effectiveUrl.isEmpty) {
      return const Icon(Icons.storefront, color: AppColors.dustyRose, size: 22);
    }

    // If it's a Cloudinary URL (starts with http), use directly
    final imageUrl = effectiveUrl.startsWith('http')
        ? effectiveUrl
        : ApiService.assetUrl('/static/uploads/seller_logos/$effectiveUrl');

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            const Icon(Icons.storefront, color: AppColors.dustyRose, size: 22),
      ),
    );
  }
}

// ── Category tile (web gradient tiles) ───────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final String label;
  final String slug;
  final int index;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.slug,
    required this.index,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ramp = _kCategoryTileRamps[
        _kCategoryRampBySlug[slug] ?? index % _kCategoryTileRamps.length];
    final imagePath = _kCategoryImageBySlug[slug];
    final imageUrl = imagePath != null ? ApiService.assetUrl(imagePath) : null;

    final iconSize = (56 * scale).clamp(52.0, 64.0);
    // Wide enough for two-word labels like "Potted Plants" without ellipsis.
    final tileWidth = (92 * scale).clamp(84.0, 112.0);
    final fontSize = (14.5 * scale).clamp(13.0, 16.5);
    final labelHeight = fontSize * 2.35;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: RadialGradient(
                  center: const Alignment(-0.5, -0.6),
                  radius: 1.2,
                  colors: ramp,
                  stops: const [0, 0.55, 1],
                ),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ramp.first.withValues(alpha: selected ? 0.55 : 0.32),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                child: imageUrl != null
                    ? Padding(
                        padding: EdgeInsets.all(iconSize * 0.05),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => const SizedBox.expand(),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.local_florist_rounded,
                            size: iconSize * 0.42,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.grid_view_rounded,
                        size: iconSize * 0.42,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: labelHeight,
              width: tileWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: tileWidth,
                  child: Text(
                    label,
                    maxLines: 2,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: fontSize,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.15,
                      color: selected ? AppColors.deepRose : AppColors.charcoal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Frosted shimmer placeholder ──────────────────────────────────────────────
class _GlassProductShimmer extends StatelessWidget {
  const _GlassProductShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF6E7EE),
      highlightColor: AppColors.pageCream,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: AppShadows.glass,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg - 1)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 4),
                  ),
                  Container(
                    height: 8,
                    width: 80,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 6),
                  ),
                  Container(
                    height: 14,
                    width: 60,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for E-FLORA flower logo (matching web SVG design)
class _FlowerLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dustyRose = AppColors.dustyRose;
    const blush = AppColors.blush;

    // Draw 6 petals (ellipses rotated around center)
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * 3.14159 / 180; // Convert to radians
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // Draw petal (ellipse: width=5, height=8, positioned at top)
      final paint = Paint()
        ..color = (i % 2 == 0 ? dustyRose : blush)
            .withValues(alpha: (0.75 - i * 0.05).clamp(0.5, 1.0));

      // Ellipse positioned above center
      final petalRect = Rect.fromCenter(
        center: const Offset(0, -6),
        width: 5,
        height: 8,
      );
      canvas.drawOval(petalRect, paint);
      canvas.restore();
    }

    // Center circle (dusty rose)
    canvas.drawCircle(
      center,
      4,
      Paint()..color = dustyRose.withOpacity(0.9),
    );

    // Inner white circle
    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = const Color(0xFFFFFDF9),
    );

    // Gold center dot
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = const Color(0xFFffd700).withOpacity(0.8),
    );
  }

  @override
  bool shouldRepaint(_FlowerLogoPainter oldDelegate) => false;
}
