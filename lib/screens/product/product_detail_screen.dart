import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../screens/checkout/checkout_modal.dart';
import '../../services/api_service.dart';
import '../../services/app_quality.dart';
import '../../services/checkout_service.dart';
import '../../services/cloudinary_service.dart';

import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_blur.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';
import '../../widgets/auth_required_sheet.dart';
import '../../widgets/delivery_unavailable_dialog.dart';
import '../../widgets/stock_issue_dialog.dart';
import '../store/store_page.dart';

/// Web `.gallery-main` / `.gallery-thumb` fill: `linear-gradient(145deg,#f8eef2,#ebe4f4)`.
const LinearGradient _kImageFrameWash = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF8EEF2), Color(0xFFEBE4F4)],
);

/// Rose-tinted chip/field border used across the web product page.
const Color _kRoseBorder = Color(0x73E6AAC3); // rgba(230,170,195,0.45)

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  int _qty = 1;
  int _selectedImageIdx = 0;
  bool _addingToCart = false;
  
  // Variant selection
  int? _selectedVariantId;
  ProductVariant? _selectedVariant;
  bool _selectedIsMainProduct = false; // Track if main product is selected

  /// groupId -> selected optionId (null = Do not add)
  final Map<int, int?> _selectedAddonOptions = {};
  /// YMAL add-on option id -> quantity (absent = not selected)
  final Map<int, int> _ymalAddonQty = {};
  bool _wishlistBusy = false;

  // Delivery date/time selection
  DateTime? _selectedDeliveryDate;
  String? _selectedTimeSlot;
  List<Map<String, String>> _availableDates = [];
  List<Map<String, String>> _timeSlots = [];
  bool _timeSlotsLoading = false;
  bool _storeClosedOnDate = false;
  String? _slotBlockReason;
  bool _hasSchedule = false;

  /// Weekday names the store trades on, taken from `store_schedule.schedules[].days`.
  /// Empty with `_hasSchedule == false` means hours are not configured.
  Set<String> _openDays = {};

  Store? _storeDetail;
  double _avgRating = 0;
  int _totalRatings = 0;
  double _overallAvgRating = 0;
  int _overallTotalRatings = 0;
  /// Keys: `"main"` or variant id as string → `{avg, count}`
  Map<String, Map<String, num>> _variantRatings = {};
  List<Product> _relatedProducts = [];
  List<ProductAddonOption> _ymalAddons = [];
  String _ymalTab = 'addons'; // 'addons' | 'flowers'

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 ProductDetailScreen.initState for product ID: ${widget.productId}');
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    debugPrint('📡 Loading product ${widget.productId}...');
    final result = await ApiService.getProduct(widget.productId);
    
    if (!mounted) return;
    
    debugPrint('📡 Product load result - Status: ${result.statusCode}');
    debugPrint('📡 Success: ${result.isSuccess}');
    
    if (result.isSuccess && result.data is Map) {
      debugPrint('✅ Product data received, parsing...');
      final raw = Map<String, dynamic>.from(result.data as Map);
      final relatedRaw = (raw['related_products'] as List? ?? []);
      final ymalRaw = (raw['ymal_addon_options'] as List? ?? []);
      setState(() {
        _product = Product.fromJson(raw);
        _loading = false;
        _overallAvgRating = (raw['overall_avg_rating'] as num?)?.toDouble()
            ?? (raw['avg_rating'] as num?)?.toDouble()
            ?? 0;
        _overallTotalRatings = (raw['overall_total_ratings'] as num?)?.toInt()
            ?? (raw['total_ratings'] as num?)?.toInt()
            ?? 0;
        _variantRatings = {};
        final vr = raw['variant_ratings'];
        if (vr is Map) {
          for (final e in vr.entries) {
            final v = e.value;
            if (v is Map) {
              _variantRatings[e.key.toString()] = {
                'avg': (v['avg'] as num?) ?? 0,
                'count': (v['count'] as num?) ?? 0,
              };
            }
          }
        }
        _relatedProducts = relatedRaw
            .whereType<Map>()
            .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _ymalAddons = ymalRaw
            .whereType<Map>()
            .map((e) => ProductAddonOption.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _ymalAddonQty.clear();
        _ymalTab = _ymalAddons.isNotEmpty ? 'addons' : 'flowers';
        _selectedAddonOptions.clear();
        for (final g in _product!.addonGroups) {
          _selectedAddonOptions[g.id] = null;
        }
        if (raw['store'] is Map) {
          _storeDetail = Store.fromJson(Map<String, dynamic>.from(raw['store'] as Map));
        }
        _syncRatingDisplay();
      });
      
      // Load the trading days first so closed dates are locked immediately.
      await _loadStoreSchedule();
      _buildAvailableDates();
      _selectFirstOpenDate();
      _loadWishlistState();
      
      // Log product details after parsing
      debugPrint('\n📦 PRODUCT DETAILS:');
      debugPrint('   ID: ${_product?.id}');
      debugPrint('   Name: ${_product?.name}');
      debugPrint('   Has variants: ${_product?.hasVariants}');
      debugPrint('   Variants count: ${_product?.variants.length}');
      debugPrint('   Images count: ${_product?.images.length}');
      
      if (_product != null && _product!.images.isNotEmpty) {
        for (var i = 0; i < _product!.images.length; i++) {
          debugPrint('   Image $i: ${_product!.images[i].filename}');
        }
      }
      
      // Log variant details if any
      if (_product!.hasVariants) {
        for (var i = 0; i < _product!.variants.length; i++) {
          final v = _product!.variants[i];
          debugPrint('   Variant $i: ${v.name} - ₱${v.price} - Stock: ${v.stockQuantity}');
        }
      }
    } else {
      debugPrint('❌ Failed to load product: ${result.error}');
      setState(() => _loading = false);
    }
  }

  // ── Delivery date/time methods ──────────────────────────────────────────

  /// Pulls `store_schedule` once so the calendar can lock closed days without
  /// probing the time-slot endpoint day by day.
  Future<void> _loadStoreSchedule() async {
    if (_product == null) return;
    // Prefer store payload already on the product response.
    Store? store = _storeDetail;
    if (store == null || store.storeSchedule == null) {
      final result = await ApiService.getStore(_product!.storeId);
      if (!mounted || !result.isSuccess || result.data is! Map) return;
      store = Store.fromJson(result.data as Map<String, dynamic>);
    }

    final schedules = store.storeSchedule?['schedules'];
    final days = <String>{};
    if (schedules is List) {
      for (final entry in schedules) {
        if (entry is Map && entry['days'] is List) {
          for (final day in entry['days'] as List) {
            days.add(day.toString().toLowerCase());
          }
        }
      }
    }
    setState(() {
      _storeDetail = store;
      _openDays = days;
      _hasSchedule = days.isNotEmpty;
    });
  }

  /// Matches the website: no configured hours means the store is not bookable.
  bool _isStoreOpenOn(DateTime date) {
    if (!_hasSchedule || _openDays.isEmpty) return false;
    const names = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    ];
    return _openDays.contains(names[date.weekday - 1]);
  }

  void _buildAvailableDates() {
    final phTime = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final days = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    final dates = <Map<String, String>>[];

    for (int i = 0; i < 3; i++) {
      final d = phTime.add(Duration(days: i));
      final isOpen = _isStoreOpenOn(d);
      final label = i == 0 ? 'TODAY' : i == 1 ? 'TOMORROW' : days[d.weekday % 7];
      dates.add({
        'date': DateFormat('yyyy-MM-dd').format(d),
        'month': months[d.month - 1],
        'day': d.day.toString().padLeft(2, '0'),
        'label': isOpen ? label : 'CLOSED',
        'open': isOpen ? 'true' : 'false',
      });
    }
    setState(() => _availableDates = dates);
  }

  /// Auto-selects the nearest trading day within the 14-day booking window,
  /// same as the web quick-pick behaviour.
  void _selectFirstOpenDate() {
    if (!_hasSchedule) {
      setState(() {
        _selectedDeliveryDate = null;
        _selectedTimeSlot = null;
        _storeClosedOnDate = false;
        _slotBlockReason = 'no_schedule';
        _timeSlots = [];
        _timeSlotsLoading = false;
      });
      return;
    }
    final open = _availableDates.where((d) => d['open'] != 'false').toList();
    if (open.isNotEmpty) {
      _selectDate(open.first);
      return;
    }
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    for (int i = 3; i <= 14; i++) {
      final d = phToday.add(Duration(days: i));
      if (_isStoreOpenOn(d)) {
        _selectDate(_dateInfo(d));
        return;
      }
    }
  }

  Map<String, String> _dateInfo(DateTime date) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'month': months[date.month - 1],
      'day': date.day.toString().padLeft(2, '0'),
      'label': DateFormat('EEE').format(date).toUpperCase(),
      'open': _isStoreOpenOn(date) ? 'true' : 'false',
    };
  }

  void _selectDate(Map<String, String>? dateInfo) {
    if (dateInfo == null || _product == null) return;
    final dateStr = dateInfo['date']!;
    
    // Parse date directly from dateStr (always in yyyy-MM-dd format)
    final date = DateTime.parse(dateStr);

    final closed = !_isStoreOpenOn(date);
    setState(() {
      _selectedDeliveryDate = date;
      _selectedTimeSlot = null;
      _timeSlotsLoading = !closed;
      _storeClosedOnDate = closed;
      _slotBlockReason = closed
          ? (_hasSchedule ? 'closed' : 'no_schedule')
          : null;
      _timeSlots = [];
    });

    if (!closed) _fetchTimeSlots(dateStr);
  }

  Future<void> _fetchTimeSlots(String dateStr) async {
    if (_product == null) return;
    final result = await CheckoutService.fetchStoreTimeSlots(_product!.storeId, dateStr);
    if (!mounted) return;

    final isOpen = result['is_open'] as bool? ?? false;
    final hasSchedule = result['has_schedule'] as bool? ?? false;
    final blockReason = result['block_reason'] as String?;

    if (!hasSchedule) {
      setState(() {
        _hasSchedule = false;
        _storeClosedOnDate = false;
        _slotBlockReason = 'no_schedule';
        _timeSlotsLoading = false;
        _timeSlots = [];
        _selectedTimeSlot = null;
      });
      return;
    }

    if (!isOpen || blockReason == 'closed') {
      setState(() {
        _storeClosedOnDate = true;
        _slotBlockReason = 'closed';
        _timeSlotsLoading = false;
        _timeSlots = [];
        _selectedTimeSlot = null;
      });
      return;
    }

    final labels = result['labels'] as Map<String, String>? ?? {};
    final slots = (result['slots'] as List<String>? ?? []);
    
    // Check which slots are still valid (not passed for today)
    final phTime = CheckoutService.getPhilippineTime();
    final todayStr = DateFormat('yyyy-MM-dd').format(phTime);
    final isToday = dateStr == todayStr;

    final timeSlotList = <Map<String, String>>[];
    String? firstAvailable;

    for (final slot in slots) {
      bool isPast = false;
      if (isToday) {
        isPast = CheckoutService.isTimeSlotPassed(slot);
      }
      final label = labels[slot] ?? CheckoutService.formatTimeSlot(slot);
      timeSlotList.add({
        'value': slot,
        'label': label,
        'passed': isPast ? 'true' : 'false',
      });
      if (!isPast && firstAvailable == null) {
        firstAvailable = slot;
      }
    }

    setState(() {
      _timeSlots = timeSlotList;
      _timeSlotsLoading = false;
      _storeClosedOnDate = false;
      _slotBlockReason = timeSlotList.isEmpty ? (blockReason ?? 'slots_passed') : null;
      _selectedTimeSlot = firstAvailable;
    });
  }

  /// Calendar mirroring the web flatpickr: today → +14 days, closed weekdays
  /// locked out entirely.
  void _showCalendarPicker() {
    if (!_hasSchedule) return;
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final maxDate = phToday.add(const Duration(days: 14));

    var initialDate = CheckoutService.normalizeToPhDate(_selectedDeliveryDate ?? phToday);
    while (!_isStoreOpenOn(initialDate) && initialDate.isBefore(maxDate)) {
      initialDate = initialDate.add(const Duration(days: 1));
    }
    if (!_isStoreOpenOn(initialDate)) return;

    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: phToday,
      lastDate: maxDate,
      helpText: 'SELECT DELIVERY DATE',
      selectableDayPredicate: _isStoreOpenOn,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.roseCta,
              onPrimary: Colors.white,
              onSurface: AppColors.charcoal,
              surface: AppColors.warmWhite,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.warmWhite,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.roseCta,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              todayBorder: const BorderSide(color: AppColors.pinkMid, width: 1.5),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.muted.withValues(alpha: 0.45);
                }
                if (states.contains(WidgetState.selected)) return Colors.white;
                return AppColors.charcoal;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.roseCta;
                return null;
              }),
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) _selectDate(_dateInfo(selectedDate));
    });
  }

  void _syncRatingDisplay() {
    if (_selectedVariant != null) {
      final bucket = _variantRatings['${_selectedVariant!.id}'];
      _avgRating = (bucket?['avg'] ?? 0).toDouble();
      _totalRatings = (bucket?['count'] ?? 0).toInt();
      return;
    }

    // Standard / unset: only ratings for the main product (variant_id IS NULL).
    // Variant reviews are never mixed into Standard.
    final main = _variantRatings['main'];
    if (main != null) {
      _avgRating = (main['avg'] ?? 0).toDouble();
      _totalRatings = (main['count'] ?? 0).toInt();
      return;
    }

    // No dedicated main-bucket yet (e.g. product with no variants rated as overall)
    if (!(_product?.hasVariants ?? false)) {
      _avgRating = _overallAvgRating;
      _totalRatings = _overallTotalRatings;
    } else {
      _avgRating = 0;
      _totalRatings = 0;
    }
  }

  void _selectVariant(ProductVariant variant) {
    setState(() {
      _selectedVariant = variant;
      _selectedVariantId = variant.id;
      _selectedIsMainProduct = false; // Deselect main product
      _qty = 1; // Reset quantity when variant changes
      _syncRatingDisplay();
    });
    debugPrint('✅ Selected variant: ${variant.name} (ID: ${variant.id}) - ₱${variant.price}');
  }

  void _selectMainProduct() {
    setState(() {
      _selectedVariant = null;
      _selectedVariantId = null;
      _selectedIsMainProduct = true; // Select main product
      _qty = 1; // Reset quantity when selection changes
      _syncRatingDisplay();
    });
    debugPrint('✅ Selected main product: ${_product!.name} - ₱${_product!.price}');
  }

  Future<void> _loadWishlistState() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || _product == null) return;
    await context.read<WishlistProvider>().loadForProduct(_product!.id);
  }

  Future<void> _toggleWishlist() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(
        context,
        message: 'Sign in to save items to your wishlist',
      );
      return;
    }
    if (_product == null || _wishlistBusy) return;

    setState(() => _wishlistBusy = true);
    final variantId = _selectedVariant?.id;
    final err = await context.read<WishlistProvider>().toggle(
          _product!.id,
          variantId: variantId,
        );
    if (!mounted) return;
    setState(() => _wishlistBusy = false);
    if (err != null) {
      showToast(context, err, isError: true);
      return;
    }
    final wished = context.read<WishlistProvider>().isWished(
          _product!.id,
          variantId: variantId,
        );
    showToast(
      context,
      wished ? 'Added to wishlist' : 'Removed from wishlist',
    );
  }

  Future<void> _addToCart() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(
        context,
        message: 'Create an account or sign in to add items to your cart',
      );
      return;
    }

    if (_product?.canDeliverToCustomer == false) {
      await showDeliveryUnavailableDialog(
        context,
        reason: _product!.deliveryReason,
      );
      return;
    }
    
    // Check if selection is out of stock
    if (_currentStock <= 0) {
      showToast(context, 'This option is out of stock', isError: true);
      return;
    }
    
    setState(() => _addingToCart = true);
    
    String? error;
    final addonIds = _selectedAddonOptionIds;
    if (_selectedVariant != null) {
      // Add variant to cart
      debugPrint('🛒 Adding VARIANT to cart: ${_selectedVariant!.name} x$_qty');
      error = await context.read<CartProvider>().addItem(
        _product!.id, 
        qty: _qty, 
        variantId: _selectedVariant!.id,
        addonOptionIds: addonIds,
      );
    } else if (_selectedIsMainProduct || !_product!.hasVariants) {
      // Add main product to cart
      debugPrint('🛒 Adding MAIN PRODUCT to cart: ${_product!.name} x$_qty');
      error = await context.read<CartProvider>().addItem(
        _product!.id, 
        qty: _qty,
        addonOptionIds: addonIds,
      );
    } else if (_product!.hasVariants) {
      // Product has variants but none selected - show error
      setState(() => _addingToCart = false);
      showToast(context, 'Please select an option first', isError: true);
      return;
    }
    
    if (!mounted) return;
    setState(() => _addingToCart = false);
    
    if (error != null) {
      showCartActionError(context, error);
    } else {
      final itemName = _selectedVariant != null 
          ? '${_selectedVariant!.name} ${_product!.name}'
          : _product!.name;
      showToast(context, '$itemName added to cart!');
    }
  }

  Future<void> _buyNow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      showAuthRequiredSheet(
        context,
        message: 'Create an account or sign in to buy this product',
      );
      return;
    }

    if (_product?.canDeliverToCustomer == false) {
      showDeliveryUnavailableDialog(
        context,
        reason: _product!.deliveryReason,
      );
      return;
    }

    if (_currentStock <= 0) {
      showToast(context, 'This option is out of stock', isError: true);
      return;
    }

    if (_product!.hasVariants && _selectedVariant == null && !_selectedIsMainProduct) {
      showToast(context, 'Please select an option first', isError: true);
      return;
    }

    final stockResult = await CheckoutService.validateStock(
      mode: 'buy_now',
      productId: _product!.id,
      variantId: _selectedVariant?.id,
      quantity: _qty,
      addonOptionIds: _selectedAddonOptionIds,
    );
    if (!mounted) return;

    if (!stockResult.isSuccess) {
      final rawIssues = stockResult.data is Map
          ? (stockResult.data as Map)['stock_issues']
          : null;
      if (rawIssues is List && rawIssues.isNotEmpty) {
        await showStockIssueDialog(
          context,
          title: 'Unable to buy now',
          intro:
              'This option isn’t available in the quantity you selected. Adjust quantity or pick another option.',
          issues: rawIssues
              .whereType<Map>()
              .map((e) => StockIssue.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      } else {
        showToast(
          context,
          stockResult.errorMessage ?? 'This item is unavailable right now.',
          isError: true,
        );
      }
      return;
    }

    showCheckoutModal(
      context,
      buyNowProductId: _product!.id,
      buyNowVariantId: _selectedVariant?.id,
      buyNowQuantity: _qty,
      buyNowAddonOptionIds: _selectedAddonOptionIds,
      initialDeliveryDate: _selectedDeliveryDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate!)
          : null,
      initialDeliveryTime: _selectedTimeSlot,
      initialStoreId: _product!.storeId,
    );
  }

  List<int> get _selectedAddonOptionIds {
    final ids = <int>[
      ..._selectedAddonOptions.values.whereType<int>(),
    ];
    // Expand YMAL qty into repeated option ids (backend sums units).
    for (final e in _ymalAddonQty.entries) {
      for (var i = 0; i < e.value; i++) {
        ids.add(e.key);
      }
    }
    return ids;
  }

  double get _structuredAddonsUnitTotal {
    double sum = 0;
    final p = _product;
    if (p == null) return 0;
    for (final entry in _selectedAddonOptions.entries) {
      final optId = entry.value;
      if (optId == null) continue;
      for (final g in p.addonGroups) {
        for (final o in g.options) {
          if (o.id == optId) sum += o.price;
        }
      }
    }
    for (final opt in _ymalAddons) {
      final qty = _ymalAddonQty[opt.id];
      if (qty != null && qty > 0) sum += opt.price * qty;
    }
    return sum;
  }

  // Get current effective price (sale price if set)
  double get _currentPrice {
    if (_selectedVariant != null) {
      return _selectedVariant!.effectivePrice;
    }
    return _product!.effectivePrice;
  }

  // Matches web product page + buy-now (structured add-ons scale with qty).
  // Cart checkout keeps add-ons fixed when flower qty changes.
  double get _displayTotal =>
      (_currentPrice + _structuredAddonsUnitTotal) * _qty;

  // Get current original price (before any sale)
  double get _currentOriginalPrice {
    if (_selectedVariant != null) return _selectedVariant!.price;
    return _product!.price;
  }

  // Get current discount percentage
  int? get _currentDiscountPct {
    if (_selectedVariant != null) return _selectedVariant!.discountPct;
    return _product!.discountPct;
  }

  bool get _hasSalePrice => _currentDiscountPct != null;

  // Get current stock based on selection
  int get _currentStock {
    if (_selectedVariant != null) {
      return _selectedVariant!.stockQuantity;
    }
    return _product!.stockQuantity;
  }

  // Get current image URL based on selection (variant image takes precedence)
  String? _getCurrentImageUrl() {
    // Request a large transform so retina screens stay sharp
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final size = (900 * dpr).round().clamp(900, 1600);

    if (_selectedVariant != null && _selectedVariant!.imageUrl != null) {
      return CloudinaryService.getLargeUrl(_selectedVariant!.imageUrl!, size: size);
    }
    if (_product != null && _product!.images.isNotEmpty) {
      return CloudinaryService.getOptimizedUrl(
        _product!.images[_selectedImageIdx].filename,
        width: size,
        height: size,
        crop: 'limit',
        quality: 'auto:good',
      );
    }
    return null;
  }

  // Get thumbnail URL for a specific index
  String _getThumbnailUrl(int index) {
    if (_product == null || _product!.images.isEmpty) return '';
    return CloudinaryService.getThumbnailUrl(
      _product!.images[index].filename,
      size: 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppBackground(
        flowerCount: 8,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: AppColors.roseCta)),
        ),
      );
    }

    if (_product == null) {
      return AppBackground(
        flowerCount: 8,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: const Center(child: Text('Product not found')),
        ),
      );
    }

    final p = _product!;
    // Show UI if ANY option (main or variant) is in stock
    final hasAnySellableOption = p.hasAnySellableStock;
    // Check if CURRENTLY SELECTED option is in stock
    final inStock = _currentStock > 0 && p.isAvailable;
    
    // Ensure selected image index is valid
    if (p.images.isNotEmpty && _selectedImageIdx >= p.images.length) {
      debugPrint('⚠️ Resetting selected image index from $_selectedImageIdx to 0');
      _selectedImageIdx = 0;
    }
    
    debugPrint('\n🏗️ Building ProductDetailScreen for ${p.name}');
    debugPrint('   Selected variant: ${_selectedVariant?.name ?? 'none'}');
    debugPrint('   Current price: ₱$_currentPrice');
    debugPrint('   Current stock: $_currentStock');
    
    return AppBackground(
      flowerCount: 8,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(p),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image thumbnails (only show if no variant selected or variant has no image)
                  if (p.images.length > 1 && _selectedVariant?.imageUrl == null) 
                    _buildThumbnails(p),
                  if (p.images.length > 1 && _selectedVariant?.imageUrl == null) 
                    const SizedBox(height: 16),
                  
                  // Category eyebrow (web `.product-eyebrow` — dot + spaced caps)
                  if (p.category != null)
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.dustyRose,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            p.category!.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dustyRose,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedVariant != null 
                        ? '${_selectedVariant!.name} ${p.name}'
                        : p.name,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: AppColors.charcoal,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Price + stock
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '₱${_currentPrice.toStringAsFixed(2)}',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepRose,
                                  height: 1,
                                ),
                              ),
                              if (_hasSalePrice) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '₱${_currentOriginalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 20,
                                    color: AppColors.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.roseCta.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: const Color(0xFFE6AAC3).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    '${_currentDiscountPct}% OFF',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppColors.deepRose,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: inStock
                              ? AppColors.sage.withOpacity(0.12)
                              : const Color(0xFFc0392b).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: inStock
                                ? AppColors.sage.withOpacity(0.3)
                                : const Color(0xFFc0392b).withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          inStock ? '$_currentStock in stock' : 'Out of stock',
                          style: GoogleFonts.dmSans(
                            fontSize: 11, 
                            fontWeight: FontWeight.w700,
                            color: inStock ? AppColors.deepSage : const Color(0xFFc0392b),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Rating + clickable store
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final filled = i < _avgRating.floor();
                        final half = !filled &&
                            i == _avgRating.floor() &&
                            (_avgRating - _avgRating.floor()) >= 0.3;
                        return Icon(
                          half
                              ? Icons.star_half_rounded
                              : (filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded),
                          size: 16,
                          color: const Color(0xFFF0B429),
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '0',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _openReviewsModal,
                        child: Text(
                          '($_totalRatings review${_totalRatings == 1 ? '' : 's'})',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            color: AppColors.deepRose,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.deepRose.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      if (p.storeName != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('·',
                              style: GoogleFonts.dmSans(color: AppColors.muted)),
                        ),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openStorePage(p.storeId),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 14, color: AppColors.deepRose),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    p.storeName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      color: AppColors.deepRose,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Variants section
                  if (p.hasVariants) _buildVariants(p),

                  if (p.addonGroups.isNotEmpty) ...[
                    if (p.hasVariants) const SizedBox(height: 8),
                    _buildAddonGroups(p),
                  ],
                  
                  const _RoseDivider(),

                  // Description
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    GlassCard(
                      fill: const Color(0x66F5EDE6),
                      padding: const EdgeInsets.all(18),
                      radius: AppRadius.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('About this product'),
                          const SizedBox(height: 10),
                          Text(
                            p.description!,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              height: 1.8,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 6),
                  _buildInfoAccordion(
                    title: 'Delivery Information',
                    child: _buildDeliveryInfoContent(),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoAccordion(
                    title: 'About the Store',
                    child: _buildAboutStoreContent(),
                  ),

                  // Qty selector
                  if (inStock) ...[
                    _sectionLabel('Quantity'),
                    const SizedBox(height: 10),
                    _QtySelector(
                      qty: _qty,
                      max: _currentStock,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                  ],

                  if (_ymalAddons.isNotEmpty || _relatedProducts.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _sectionLabel('You might also like'),
                    const SizedBox(height: 10),
                    _buildYmalSection(),
                  ],

                  // ── Delivery Scheduling ──────────────────────────
                  if (inStock) ...[
                    const SizedBox(height: 22),
                    _sectionLabel('Delivery Schedule'),
                    const SizedBox(height: 5),
                    Text(
                      'Select your preferred delivery date & time',
                      style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),

                    // Date tiles
                    Row(
                      children: _availableDates
                          .asMap()
                          .entries
                          .map((entry) {
                            final i = entry.key;
                            final d = entry.value;
                            final isSelected = _selectedDeliveryDate != null &&
                                DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate!) == d['date'];
                            final isOpen = d['open'] != 'false';
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < _availableDates.length - 1 ? 10 : 0),
                                child: Opacity(
                                  opacity: isOpen ? 1 : 0.45,
                                  child: GestureDetector(
                                    onTap: isOpen ? () => _selectDate(d) : null,
                                    child: AnimatedContainer(
                                      duration: AppMotion.fast,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                      decoration: BoxDecoration(
                                        gradient: isSelected ? AppColors.brandGradient : null,
                                        color: isSelected ? null : AppColors.glassFill,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : const Color(0x73E6AAC3),
                                          width: 1.5,
                                        ),
                                        boxShadow: isSelected ? AppShadows.roseButton : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            d['month']!,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? Colors.white : AppColors.muted,
                                            ),
                                          ),
                                          Text(
                                            d['day']!,
                                            style: GoogleFonts.cormorantGaramond(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? Colors.white : AppColors.charcoal,
                                            ),
                                          ),
                                          Text(
                                            d['label']!,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.6,
                                              color: isSelected
                                                  ? Colors.white.withValues(alpha: 0.85)
                                                  : AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 14),

                    // Calendar button (glass, matching the web outline CTA)
                    GlassCard(
                      fill: const Color(0x66F5EDE6),
                      radius: AppRadius.md,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onTap: _showCalendarPicker,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 17, color: AppColors.deepRose),
                          const SizedBox(width: 8),
                          Text(
                            'Select from calendar',
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Time slots
                    if (_timeSlotsLoading)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ))
                    else if (!_hasSchedule || _slotBlockReason == 'no_schedule')
                      _noticeCard(
                        icon: Icons.schedule_rounded,
                        text: 'This store has not set delivery hours yet.',
                      )
                    else if (_storeClosedOnDate)
                      _noticeCard(
                        icon: Icons.storefront_outlined,
                        text: 'Store is closed on this day. Pick another date.',
                      )
                    else if (_slotBlockReason == 'order_cutoff')
                      _noticeCard(
                        icon: Icons.schedule_rounded,
                        text: 'Same-day ordering is closed. Please choose another open day.',
                      )
                    else if (_slotBlockReason == 'lead_time')
                      _noticeCard(
                        icon: Icons.hourglass_bottom_rounded,
                        text: 'Remaining slots are inside the prep window. Please choose a later slot or another date.',
                      )
                    else if (_timeSlots.isEmpty && _selectedDeliveryDate != null)
                      _noticeCard(
                        icon: Icons.schedule_rounded,
                        text: 'All delivery slots for this day have passed. Please select another date.',
                      )
                    else if (_timeSlots.isNotEmpty) ...[
                      _sectionLabel('Time Slot'),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 8.0;
                          const minTile = 132.0;
                          final cols = ((constraints.maxWidth + gap) / (minTile + gap))
                              .floor()
                              .clamp(1, 4);
                          final tileW =
                              (constraints.maxWidth - gap * (cols - 1)) / cols;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: _timeSlots.map((slot) {
                              final isPassed = slot['passed'] == 'true';
                              final isSelected = _selectedTimeSlot == slot['value'];
                              return SizedBox(
                                width: tileW,
                                child: Opacity(
                                  opacity: isPassed ? 0.4 : 1,
                                  child: GestureDetector(
                                    onTap: isPassed
                                        ? null
                                        : () => setState(
                                              () => _selectedTimeSlot = slot['value'],
                                            ),
                                    child: AnimatedContainer(
                                      duration: AppMotion.fast,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient:
                                            isSelected ? AppColors.brandGradient : null,
                                        color: isSelected ? null : AppColors.glassFill,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.md),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : const Color(0x73E6AAC3),
                                          width: 1.5,
                                        ),
                                        boxShadow:
                                            isSelected ? AppShadows.roseButton : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 15,
                                            color: isSelected
                                                ? const Color(0xFFFFE0EC)
                                                : AppColors.sage,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              slot['label']!,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.charcoal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildAddToCartBar(),
      ),
    );
  }

  void _openStorePage(int storeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorePage(
          storeId: storeId,
          initialStore: _storeDetail,
        ),
      ),
    );
  }

  Widget _buildInfoAccordion({required String title, required Widget child}) {
    return GlassCard(
      fill: const Color(0x66F5EDE6),
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoContent() {
    final store = _storeDetail;
    final sched = store?.storeSchedule;
    final deliveryStart = sched?['delivery_start']?.toString();
    final deliveryCutoff = sched?['delivery_cutoff']?.toString();
    final orderCutoff = sched?['order_cutoff']?.toString();
    final radius = store?.deliveryRadiusKm ?? 5;
    final openDays = _openDays.toList()
      ..sort((a, b) {
        const order = [
          'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
        ];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });
    final daysLabel = openDays
        .map((d) => d[0].toUpperCase() + d.substring(1))
        .join(', ');

    String sameDay;
    if (deliveryStart != null &&
        deliveryStart.isNotEmpty &&
        deliveryCutoff != null &&
        deliveryCutoff.isNotEmpty) {
      sameDay =
          'Same-day delivery is available from $deliveryStart to $deliveryCutoff'
          '${daysLabel.isNotEmpty ? ' on this store’s open days ($daysLabel)' : ''}, while delivery slots remain.'
          '${orderCutoff != null && orderCutoff.isNotEmpty ? ' Order by $orderCutoff for same-day.' : ''}';
    } else if (orderCutoff != null && orderCutoff.isNotEmpty) {
      sameDay =
          'Orders placed before $orderCutoff are eligible for same-day delivery within our service area, while delivery slots remain.';
    } else if (daysLabel.isNotEmpty) {
      sameDay =
          'Same-day delivery is available on this store’s open days ($daysLabel), based on remaining delivery time slots.';
    } else {
      sameDay =
          'Same-day delivery may be available depending on remaining delivery slots for today.';
    }

    final radiusText =
        'We deliver within a ${radius.toStringAsFixed(radius.truncateToDouble() == radius ? 0 : 1)}km radius from our partner store.'
        '${store?.address != null && store!.address!.isNotEmpty ? ' Located at ${store.address}.' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Same-Day Delivery',
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(sameDay,
            style: GoogleFonts.dmSans(
                fontSize: 13, height: 1.55, color: AppColors.muted)),
        const SizedBox(height: 12),
        Text('Delivery Radius',
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(radiusText,
            style: GoogleFonts.dmSans(
                fontSize: 13, height: 1.55, color: AppColors.muted)),
      ],
    );
  }

  Widget _buildAboutStoreContent() {
    final store = _storeDetail;
    if (store == null) {
      return Text('Store information not available.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted));
    }
    final desc = (store.description != null && store.description!.trim().isNotEmpty)
        ? store.description!.trim()
        : 'A trusted local florist on E-FLORA, committed to delivering fresh and beautiful arrangements with care.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openStorePage(store.id),
          child: Text(
            store.name,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRose,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(desc,
            style: GoogleFonts.dmSans(
                fontSize: 13, height: 1.55, color: AppColors.muted)),
        if (store.address != null && store.address!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Address',
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
          const SizedBox(height: 4),
          Text(store.address!,
              style: GoogleFonts.dmSans(
                  fontSize: 13, height: 1.55, color: AppColors.muted)),
        ],
        if (store.contactNumber != null && store.contactNumber!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Contact',
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
          const SizedBox(height: 4),
          Text(store.contactNumber!,
              style: GoogleFonts.dmSans(
                  fontSize: 13, height: 1.55, color: AppColors.muted)),
        ],
      ],
    );
  }

  Widget _buildYmalSection() {
    final hasAddons = _ymalAddons.isNotEmpty;
    final hasFlowers = _relatedProducts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAddons && hasFlowers)
          Row(
            children: [
              _ymalTabChip('Add-ons', 'addons'),
              const SizedBox(width: 8),
              _ymalTabChip('Flowers', 'flowers'),
            ],
          ),
        if (hasAddons && hasFlowers) const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: (_ymalTab == 'addons' && hasAddons)
                ? _ymalAddons.length
                : _relatedProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (_ymalTab == 'addons' && hasAddons) {
                return _buildYmalAddonCard(_ymalAddons[i]);
              }
              return _buildYmalFlowerCard(_relatedProducts[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _ymalTabChip(String label, String value) {
    final active = _ymalTab == value;
    return GestureDetector(
      onTap: () => setState(() => _ymalTab = value),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.brandGradient : null,
          color: active ? null : AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? Colors.transparent : _kRoseBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.charcoal,
          ),
        ),
      ),
    );
  }

  void _toggleYmalAddon(ProductAddonOption opt) {
    if (opt.isOos) return;
    setState(() {
      if (_ymalAddonQty.containsKey(opt.id)) {
        _ymalAddonQty.remove(opt.id);
      } else {
        _ymalAddonQty[opt.id] = 1;
      }
    });
  }

  void _changeYmalAddonQty(ProductAddonOption opt, int delta) {
    final current = _ymalAddonQty[opt.id];
    if (current == null) return;
    final next = current + delta;
    setState(() {
      if (next < 1) {
        _ymalAddonQty.remove(opt.id);
      } else {
        final maxStock = opt.stockQuantity > 0 ? opt.stockQuantity : 99;
        _ymalAddonQty[opt.id] = next.clamp(1, maxStock);
      }
    });
  }

  Widget _ymalCheckBadge() {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC24E68), Color(0xFFD878A0), Color(0xFFB070C8)],
        ),
      ),
      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
    );
  }

  Widget _ymalQtyRow({
    required int qty,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ymalQtyBtn('−', onMinus),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$qty',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepRose,
              ),
            ),
          ),
          _ymalQtyBtn('+', onPlus),
        ],
      ),
    );
  }

  Widget _ymalQtyBtn(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w500,
                color: AppColors.deepRose,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYmalAddonCard(ProductAddonOption opt) {
    final selected = _ymalAddonQty.containsKey(opt.id);
    final qty = _ymalAddonQty[opt.id] ?? 1;
    final oos = opt.isOos;
    return Opacity(
      opacity: oos ? 0.45 : 1,
      child: SizedBox(
        width: 118,
        child: Column(
          children: [
            GestureDetector(
              onTap: oos ? null : () => _toggleYmalAddon(opt),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: 118,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x2EFFBED2) // rgba(255,190,210,0.18)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFD878A0)
                        : Colors.white.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFC24E68).withValues(alpha: 0.25),
                            blurRadius: 0,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFF502846).withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadius.md - 2),
                          ),
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: _kImageFrameWash,
                            ),
                            child: opt.imageUrl != null && opt.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: opt.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.card_giftcard_outlined,
                                      color: AppColors.dustyRose,
                                    ),
                                  )
                                : const Icon(
                                    Icons.card_giftcard_outlined,
                                    color: AppColors.dustyRose,
                                  ),
                          ),
                        ),
                        if (oos)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Out of stock',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC0392B),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Text(
                            opt.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '₱${opt.price.toStringAsFixed(0)}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ],
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _ymalCheckBadge(),
                      ),
                  ],
                ),
              ),
            ),
            // Reserve qty row height so the carousel doesn't jump
            SizedBox(
              height: 32,
              child: selected
                  ? _ymalQtyRow(
                      qty: qty,
                      onMinus: () => _changeYmalAddonQty(opt, -1),
                      onPlus: () => _changeYmalAddonQty(opt, 1),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYmalFlowerCard(Product product) {
    final img = product.primaryImageUrl;
    final oos = product.stockQuantity <= 0;
    return Opacity(
      opacity: oos ? 0.45 : 1,
      child: SizedBox(
        width: 118,
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(productId: product.id),
                  ),
                );
              },
              child: Container(
                width: 118,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF502846).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.md - 2),
                      ),
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: _kImageFrameWash,
                        ),
                        child: img != null && img.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.local_florist,
                                  color: AppColors.dustyRose,
                                ),
                              )
                            : const Icon(
                                Icons.local_florist,
                                color: AppColors.dustyRose,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₱${product.effectivePrice.toStringAsFixed(0)}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepRose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openReviewsModal() async {
    // Standard → main only; variant → that variant only. Never mix.
    final Object? filterVariantId =
        _selectedVariant != null ? _selectedVariant!.id : 'main';
    final filterLabel = _selectedVariant?.name ?? 'Standard';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductReviewsSheet(
        productId: widget.productId,
        productName: _product?.name ?? 'Product',
        variantId: filterVariantId,
        variantName: filterLabel,
        initialAvg: _avgRating,
        initialCount: _totalRatings,
      ),
    );
  }

  /// Spaced-caps section heading, matching the web accordion / field labels.
  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: AppColors.charcoal,
        ),
      );

  Widget _noticeCard({required IconData icon, required String text}) {
    return GlassCard(
      fill: const Color(0x66F5EDE6),
      radius: AppRadius.md,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.deepRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Product p) {
    debugPrint('\n🏗️ Building SliverAppBar for product: ${p.id}');
    
    final imageUrl = _getCurrentImageUrl();
    debugPrint('   Main image URL: $imageUrl');
    
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.pageCream,
      iconTheme: const IconThemeData(color: AppColors.charcoal),
      actions: [
        Consumer<WishlistProvider>(
          builder: (context, wishlist, _) {
            final wished = wishlist.isWished(
              p.id,
              variantId: _selectedVariant?.id,
            );
            return IconButton(
              tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
              onPressed: _wishlistBusy ? null : _toggleWishlist,
              icon: Icon(
                wished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: wished ? const Color(0xFFC0392B) : AppColors.deepRose,
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                decoration: const BoxDecoration(gradient: _kImageFrameWash),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 1400,
                  memCacheHeight: 1400,
                  placeholder: (context, url) {
                    debugPrint('⏳ Main image loading: $url');
                    return Container(
                      color: AppColors.warmWhite,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.deepRose,
                        ),
                      ),
                    );
                  },
                  errorWidget: (context, url, error) {
                    debugPrint('❌ MAIN IMAGE ERROR: $url');
                    debugPrint('❌ Error details: $error');
                    
                    // Try fallback to product image if variant image fails
                    if (_selectedVariant != null && p.images.isNotEmpty) {
                      final fallbackUrl = CloudinaryService.getLargeUrl(
                        p.images[0].filename,
                        size: 1200,
                      );
                      return CachedNetworkImage(
                        imageUrl: fallbackUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 1400,
                        memCacheHeight: 1400,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.warmWhite,
                          child: const Center(
                            child: Icon(Icons.local_florist, size: 64, color: Color(0x22B5445A)),
                          ),
                        ),
                      );
                    }
                    
                    return Container(
                      color: AppColors.warmWhite,
                      child: const Center(
                        child: Icon(Icons.local_florist, size: 64, color: Color(0x22B5445A)),
                      ),
                    );
                  },
                  imageBuilder: (context, imageProvider) {
                    debugPrint('✅ Main image loaded successfully');
                    return Image(image: imageProvider, fit: BoxFit.cover);
                  },
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(gradient: _kImageFrameWash),
                child: const Center(
                  child: Icon(Icons.local_florist, size: 64, color: Color(0x22B5445A)),
                ),
              ),
            // Fade the photo into the page wash
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.pageCream.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnails(Product p) {
    debugPrint('\n🖼️ Building thumbnails for ${p.images.length} images');
    
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: p.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final thumbnailUrl = _getThumbnailUrl(i);
          debugPrint('🖼️ Thumbnail $i URL: $thumbnailUrl');
          
          return GestureDetector(
            onTap: () {
              debugPrint('👆 Tapped thumbnail $i');
              setState(() => _selectedImageIdx = i);
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _selectedImageIdx == i ? AppColors.pinkMid : AppColors.glassBorder,
                  width: 2,
                ),
                boxShadow: _selectedImageIdx == i
                    ? [
                        BoxShadow(
                          color: AppColors.roseCta.withValues(alpha: 0.18),
                          blurRadius: 0,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                child: Container(
                  decoration: const BoxDecoration(gradient: _kImageFrameWash),
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 60,
                    memCacheHeight: 60,
                    placeholder: (_, __) => Container(
                      color: AppColors.warmWhite,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, url, error) {
                      debugPrint('❌ Thumbnail $i failed: $url');
                      debugPrint('❌ Error: $error');
                      return Container(
                        color: AppColors.warmWhite,
                        child: const Icon(Icons.error, size: 20, color: Colors.red),
                      );
                    },
                    imageBuilder: (context, imageProvider) {
                      debugPrint('✅ Thumbnail $i loaded successfully');
                      return Image(image: imageProvider, fit: BoxFit.cover);
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddonGroups(Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Add-ons'),
        const SizedBox(height: 10),
        ...p.addonGroups.map((group) {
          final selectedId = _selectedAddonOptions[group.id];
          ProductAddonOption? selectedOpt;
          for (final o in group.options) {
            if (o.id == selectedId) {
              selectedOpt = o;
              break;
            }
          }
          final previewUrl = selectedOpt?.imageUrl;
          final closedLabel = selectedOpt == null
              ? 'Do not add'
              : (selectedOpt.isOos
                  ? '${selectedOpt.name} (+₱${selectedOpt.price.toStringAsFixed(2)}) — Out of stock'
                  : '${selectedOpt.name} (+₱${selectedOpt.price.toStringAsFixed(2)})');

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewSize = constraints.maxWidth < 360 ? 48.0 : 56.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (previewUrl != null && previewUrl.isNotEmpty)
                          ? () => _zoomAddonImage(
                                previewUrl,
                                selectedOpt?.name ?? group.name,
                              )
                          : null,
                      child: SizedBox(
                        width: previewSize,
                        height: previewSize,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8F6),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                    color:
                                        AppColors.deepRose.withOpacity(0.25)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: previewUrl != null && previewUrl.isNotEmpty
                                  ? Image.network(
                                      previewUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _noAddonPlaceholder(),
                                    )
                                  : _noAddonPlaceholder(),
                            ),
                            if (previewUrl != null && previewUrl.isNotEmpty)
                              Positioned(
                                right: 3,
                                bottom: 3,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.52),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.zoom_in_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                onTap: () => _openAddonOptionPicker(group),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color:
                                          AppColors.deepRose.withOpacity(0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 8, 6, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            closedLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              color: AppColors.charcoal,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: AppColors.deepRose
                                              .withOpacity(0.85),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _openAddonOptionPicker(ProductAddonGroup group) async {
    final currentId = _selectedAddonOptions[group.id];
    final result = await showModalBottomSheet<_AddonPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  group.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _addonPickerRow(
                        context: ctx,
                        label: 'Do not add',
                        imageUrl: null,
                        selected: currentId == null,
                        enabled: true,
                        onSelect: () =>
                            Navigator.pop(ctx, const _AddonPickResult(null)),
                      ),
                      ...group.options.map((opt) {
                        final label = opt.isOos
                            ? '${opt.name} (+₱${opt.price.toStringAsFixed(2)}) — Out of stock'
                            : '${opt.name} (+₱${opt.price.toStringAsFixed(2)})';
                        return _addonPickerRow(
                          context: ctx,
                          label: label,
                          imageUrl: opt.imageUrl,
                          imageName: opt.name,
                          selected: currentId == opt.id,
                          enabled: !opt.isOos,
                          onSelect: () =>
                              Navigator.pop(ctx, _AddonPickResult(opt.id)),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _selectedAddonOptions[group.id] = result.optionId);
  }

  Widget _addonPickerRow({
    required BuildContext context,
    required String label,
    required String? imageUrl,
    String? imageName,
    required bool selected,
    required bool enabled,
    required VoidCallback onSelect,
  }) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected
            ? AppColors.deepRose.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _buildAddonZoomThumb(
                size: 36,
                imageUrl: url,
                zoomTitle: hasImage ? (imageName ?? label) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: enabled ? onSelect : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: enabled ? AppColors.charcoal : AppColors.muted,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded,
                    size: 20, color: AppColors.deepRose),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonZoomThumb({
    required double size,
    required String? imageUrl,
    String? zoomTitle,
  }) {
    final url = imageUrl;
    final canZoom =
        zoomTitle != null && url != null && url.isNotEmpty;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: canZoom
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _noAddonPlaceholder(),
              )
            : _noAddonPlaceholder(),
      ),
    );

    if (!canZoom) return thumb;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _zoomAddonImage(url, zoomTitle),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          thumb,
          Positioned(
            right: 1,
            bottom: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.52),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Padding(
                padding: EdgeInsets.all(1.5),
                child: Icon(
                  Icons.zoom_in_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _zoomAddonImage(String imageUrl, String title) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxW = size.width - 48;
        final maxH = size.height * 0.82;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxW,
                          maxHeight: maxH,
                        ),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 200,
                              padding: const EdgeInsets.all(24),
                              color: Colors.black26,
                              child: Text(
                                'Unable to load image',
                                style: GoogleFonts.dmSans(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(ctx),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.close_rounded, size: 18),
                          ),
                        ),
                      ),
                    ),
                    if (title.isNotEmpty)
                      Positioned(
                        left: 8,
                        right: 40,
                        bottom: 8,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _noAddonPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/no_addon_placeholder.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: const Color(0xFFFFF8F6),
          child: Center(
            child: Icon(
              Icons.card_giftcard_outlined,
              size: 22,
              color: AppColors.deepRose.withOpacity(0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariants(Product p) {
    // Check if main product has stock (for visual indication only)
    final isMainProductInStock = p.stockQuantity > 0 && p.isAvailable;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Options'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Main product button (always first) - can click even if out of stock
            GestureDetector(
              onTap: () => _selectMainProduct(),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: _selectedIsMainProduct ? AppColors.brandGradient : null,
                  color: _selectedIsMainProduct
                      ? null
                      : AppColors.glassFill.withValues(alpha: isMainProductInStock ? 0.55 : 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: _selectedIsMainProduct ? Colors.transparent : _kRoseBorder,
                    width: 1.5,
                  ),
                  boxShadow: _selectedIsMainProduct ? AppShadows.roseButton : null,
                ),
                child: Text(
                  'Standard',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _selectedIsMainProduct
                        ? Colors.white
                        : (isMainProductInStock ? AppColors.charcoal : AppColors.muted),
                  ),
                ),
              ),
            ),
            // Variant buttons - can click even if out of stock
            ...p.variants.map((variant) {
            final isSelected = _selectedVariantId == variant.id;
            final isInStock = variant.stockQuantity > 0 && variant.isAvailable;
            
            return GestureDetector(
              onTap: () => _selectVariant(variant),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.brandGradient : null,
                  color: isSelected
                      ? null
                      : AppColors.glassFill.withValues(alpha: isInStock ? 0.55 : 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : _kRoseBorder,
                    width: 1.5,
                  ),
                  boxShadow: isSelected ? AppShadows.roseButton : null,
                ),
                child: Text(
                  variant.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isInStock ? AppColors.charcoal : AppColors.muted),
                  ),
                ),
              ),
            );
          }),
          ],
        ),
        if (_selectedVariant != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            fill: const Color(0x66F5EDE6),
            padding: const EdgeInsets.all(12),
            radius: AppRadius.md,
            child: Row(
              children: [
                if (_selectedVariant!.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CachedNetworkImage(
                        imageUrl: CloudinaryService.getThumbnailUrl(
                          _selectedVariant!.imageUrl!,
                          size: 40,
                        ),
                        fit: BoxFit.cover,
                        memCacheWidth: 40,
                        memCacheHeight: 40,
                        placeholder: (_, __) => Container(
                          color: AppColors.warmWhite,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.deepRose,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.warmWhite,
                          child: const Icon(Icons.error, size: 20, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                if (_selectedVariant!.imageUrl != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected: ${_selectedVariant!.name}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedVariant!.discountPct != null
                            ? '₱${_selectedVariant!.effectivePrice.toStringAsFixed(2)} (was ₱${_selectedVariant!.price.toStringAsFixed(2)}) · ${_selectedVariant!.stockQuantity} available'
                            : '₱${_selectedVariant!.effectivePrice.toStringAsFixed(2)} · ${_selectedVariant!.stockQuantity} available',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddToCartBar() {
    final totalPrice = _displayTotal;
    final canAddToCart = _currentStock > 0 && _product!.isAvailable;
    final isSelectOption = _product!.hasVariants && _selectedVariant == null && !_selectedIsMainProduct;
    final isOutOfStock = !canAddToCart && !isSelectOption;
    final isStoreClosed = _storeClosedOnDate;
    final hoursNotSet = !_hasSchedule || _slotBlockReason == 'no_schedule';
    final allSlotsPassed = !_storeClosedOnDate &&
        !_timeSlotsLoading &&
        _timeSlots.isEmpty &&
        (_selectedDeliveryDate != null || hoursNotSet);
    final noSlotSelected = _selectedDeliveryDate != null && !_storeClosedOnDate && _selectedTimeSlot == null && !_timeSlotsLoading;
    final outsideDelivery = _product!.canDeliverToCustomer == false;

    return ClipRect(
      child: AdaptiveBlur(
        sigma: 16,
        child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        gradient: AppQuality.instance.useBlur ? AppColors.headerGlass : null,
        color: AppQuality.instance.useBlur ? null : const Color(0xF5FFFAFC),
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              border: Border.all(color: _kRoseBorder, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  '₱${totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18, 
                    fontWeight: FontWeight.w600, 
                    color: AppColors.deepRose,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isOutOfStock
                ? RoseButton(
                    label: 'Out of Stock',
                    onPressed: null,
                    icon: Icons.shopping_bag_outlined,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.border,
                      foregroundColor: AppColors.muted,
                    ),
                  )
                : isSelectOption
                    ? RoseButton(
                        label: 'Select an option',
                        onPressed: null,
                        icon: Icons.shopping_bag_outlined,
                      )
                    : (hoursNotSet || isStoreClosed || allSlotsPassed)
                        ? RoseButton(
                            label: hoursNotSet
                                ? 'Hours Not Set'
                                : isStoreClosed
                                    ? 'Store Closed'
                                    : 'No Slots Available',
                            onPressed: null,
                            icon: Icons.close_rounded,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.border,
                              foregroundColor: AppColors.muted,
                            ),
                          )
                        : Row(
                        children: [
                          Expanded(
                            child: RoseButton(
                              label: 'Buy Now',
                              onPressed: (noSlotSelected || _timeSlotsLoading || outsideDelivery) ? null : _buyNow,
                              style: outsideDelivery
                                  ? ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.border,
                                      foregroundColor: AppColors.muted,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (_addingToCart || noSlotSelected || _timeSlotsLoading) ? null : _addToCart,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.deepRose,
                                backgroundColor: AppColors.glassFill,
                                side: const BorderSide(color: _kRoseBorder, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                              child: _addingToCart
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      'Add to Cart',
                                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// Hairline in the site's rose tint (web `.info-divider`).
class _RoseDivider extends StatelessWidget {
  const _RoseDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0x40E6AAC3));
}

// ── Quantity selector widget ──────────────────────────────────────────────────
class _QtySelector extends StatelessWidget {
  final int qty;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtySelector({required this.qty, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        border: Border.all(color: _kRoseBorder, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, qty > 1 ? () => onChanged(qty - 1) : null),
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x4DE6AAC3), width: 1.5),
              ),
            ),
            child: Center(
              child: Text(
                '$qty',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, 
                  fontWeight: FontWeight.w600, 
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ),
          _btn(Icons.add, qty < max ? () => onChanged(qty + 1) : null),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 44, height: 44,
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.charcoal : AppColors.borderStrong),
      ),
    );
  }
}

class _AddonPickResult {
  final int? optionId;
  const _AddonPickResult(this.optionId);
}

/// Product reviews bottom sheet — mirrors web Ratings modal overview + list.
class _ProductReviewsSheet extends StatefulWidget {
  final int productId;
  final String productName;
  /// `null` = all reviews; `'main'` = standard only; `int` = that variant
  final Object? variantId;
  final String? variantName;
  final double initialAvg;
  final int initialCount;

  const _ProductReviewsSheet({
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.initialAvg,
    required this.initialCount,
  });

  @override
  State<_ProductReviewsSheet> createState() => _ProductReviewsSheetState();
}

class _ProductReviewsSheetState extends State<_ProductReviewsSheet> {
  bool _loading = true;
  String? _error;
  double _avg = 0;
  int _count = 0;
  Map<String, int> _distribution = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    _avg = widget.initialAvg;
    _count = widget.initialCount;
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.getProductRatings(
      widget.productId,
      perPage: 50,
      variantId: widget.variantId,
    );
    if (!mounted) return;
    if (!res.isSuccess || res.data is! Map) {
      setState(() {
        _loading = false;
        _error = res.error ?? 'Unable to load reviews right now.';
      });
      return;
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    final ratings = (data['ratings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final distRaw = data['distribution'];
    final dist = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
    if (distRaw is Map) {
      for (final e in distRaw.entries) {
        dist[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    setState(() {
      _loading = false;
      _ratings = ratings;
      _avg = (data['avg_rating'] as num?)?.toDouble() ?? widget.initialAvg;
      _count = (data['total_ratings'] as num?)?.toInt() ?? widget.initialCount;
      _distribution = dist;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFFFBF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ratings',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.charcoal.withValues(alpha: 0.06),
                    foregroundColor: AppColors.charcoal,
                    hoverColor: AppColors.charcoal.withValues(alpha: 0.1),
                    minimumSize: const Size(32, 32),
                    maximumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          if (widget.variantId != null && widget.variantName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing reviews for ${widget.variantName}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.roseCta))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: GoogleFonts.dmSans(color: AppColors.muted)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        children: [
                          _overview(),
                          const SizedBox(height: 16),
                          if (_ratings.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded,
                                      size: 36,
                                      color: AppColors.muted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No reviews yet for this selection.',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._ratings.map(_reviewRow),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    final total = _count <= 0 ? 1 : _count;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average user rating',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: _count == 0 ? '0' : _avg.toStringAsFixed(1),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                    children: [
                      TextSpan(
                        text: ' / 5',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < _avg.round();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF0B429),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating breakdown',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 8),
                for (final star in [5, 4, 3, 2, 1])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: AppColors.muted)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (_distribution['$star'] ?? 0) / total,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFEDE3D8),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFF0B429)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(Map<String, dynamic> r) {
    final name = (r['customer_name'] ?? 'Anonymous').toString();
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    final comment = (r['comment']?.toString().trim().isNotEmpty == true)
        ? r['comment'].toString().trim()
        : 'No written comment.';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: const Color(0xFFF0B429),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(comment,
              style: GoogleFonts.dmSans(
                  fontSize: 13, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(
            '— Reviewed by $name',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}