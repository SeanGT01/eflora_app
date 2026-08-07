import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
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

  // Delivery date/time selection
  DateTime? _selectedDeliveryDate;
  String? _selectedTimeSlot;
  List<Map<String, String>> _availableDates = [];
  List<Map<String, String>> _timeSlots = [];
  bool _timeSlotsLoading = false;
  bool _storeClosedOnDate = false;

  /// Weekday names the store trades on, taken from `store_schedule.schedules[].days`
  /// exactly like the web `isStoreOpenOnDate()`. Empty means "no schedule set",
  /// which the website treats as open every day.
  Set<String> _openDays = {};

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
      setState(() {
        _product = Product.fromJson(result.data as Map<String, dynamic>);
        _loading = false;
      });
      
      // Load the trading days first so closed dates are locked immediately.
      await _loadStoreSchedule();
      _buildAvailableDates();
      _selectFirstOpenDate();
      
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
    final result = await ApiService.getStore(_product!.storeId);
    if (!mounted || !result.isSuccess || result.data is! Map) return;

    final store = Store.fromJson(result.data as Map<String, dynamic>);
    final schedules = store.storeSchedule?['schedules'];
    if (schedules is! List) return;

    final days = <String>{};
    for (final entry in schedules) {
      if (entry is Map && entry['days'] is List) {
        for (final day in entry['days'] as List) {
          days.add(day.toString().toLowerCase());
        }
      }
    }
    setState(() => _openDays = days);
  }

  /// Mirrors the web `isStoreOpenOnDate()` — no schedule means every day is open.
  bool _isStoreOpenOn(DateTime date) {
    if (_openDays.isEmpty) return true;
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
      _timeSlots = [];
    });

    if (!closed) _fetchTimeSlots(dateStr);
  }

  Future<void> _fetchTimeSlots(String dateStr) async {
    if (_product == null) return;
    final result = await CheckoutService.fetchStoreTimeSlots(_product!.storeId, dateStr);
    if (!mounted) return;

    final isOpen = result['is_open'] as bool? ?? true;

    if (!isOpen && (result['has_schedule'] as bool? ?? false)) {
      setState(() {
        _storeClosedOnDate = true;
        _timeSlotsLoading = false;
        _timeSlots = [];
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
      _selectedTimeSlot = firstAvailable;
    });
  }

  /// Calendar mirroring the web flatpickr: today → +14 days, closed weekdays
  /// locked out entirely.
  void _showCalendarPicker() {
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

  void _selectVariant(ProductVariant variant) {
    setState(() {
      _selectedVariant = variant;
      _selectedVariantId = variant.id;
      _selectedIsMainProduct = false; // Deselect main product
      _qty = 1; // Reset quantity when variant changes
    });
    debugPrint('✅ Selected variant: ${variant.name} (ID: ${variant.id}) - ₱${variant.price}');
  }

  void _selectMainProduct() {
    setState(() {
      _selectedVariant = null;
      _selectedVariantId = null;
      _selectedIsMainProduct = true; // Select main product
      _qty = 1; // Reset quantity when selection changes
    });
    debugPrint('✅ Selected main product: ${_product!.name} - ₱${_product!.price}');
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
    if (_selectedVariant != null) {
      // Add variant to cart
      debugPrint('🛒 Adding VARIANT to cart: ${_selectedVariant!.name} x$_qty');
      error = await context.read<CartProvider>().addItem(
        _product!.id, 
        qty: _qty, 
        variantId: _selectedVariant!.id
      );
    } else if (_selectedIsMainProduct || !_product!.hasVariants) {
      // Add main product to cart
      debugPrint('🛒 Adding MAIN PRODUCT to cart: ${_product!.name} x$_qty');
      error = await context.read<CartProvider>().addItem(
        _product!.id, 
        qty: _qty
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
      initialDeliveryDate: _selectedDeliveryDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate!)
          : null,
      initialDeliveryTime: _selectedTimeSlot,
      initialStoreId: _product!.storeId,
    );
  }

  // Get current effective price (sale price if set)
  double get _currentPrice {
    if (_selectedVariant != null) {
      return _selectedVariant!.effectivePrice;
    }
    return _product!.effectivePrice;
  }

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
    if (_selectedVariant != null && _selectedVariant!.imageUrl != null) {
      return CloudinaryService.getMediumUrl(_selectedVariant!.imageUrl!, size: 400);
    }
    if (_product != null && _product!.images.isNotEmpty) {
      return CloudinaryService.getOptimizedUrl(
        _product!.images[_selectedImageIdx].filename,
        width: 400,
        height: 400,
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
                  
                  // Store name
                  if (p.storeName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.storeName!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5, 
                              color: AppColors.muted, 
                              fontWeight: FontWeight.w500
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Variants section
                  if (p.hasVariants) _buildVariants(p),
                  
                  const _RoseDivider(),

                  // Description
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    GlassCard(
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
                    const SizedBox(height: 24),
                  ],
                  
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
                    else if (_storeClosedOnDate)
                      _noticeCard(
                        icon: Icons.storefront_outlined,
                        text: 'Store is closed on this day. Pick another date.',
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
                  memCacheWidth: 400,
                  memCacheHeight: 400,
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
                      final fallbackUrl = CloudinaryService.getOptimizedUrl(
                        p.images[0].filename,
                        width: 400,
                        height: 400,
                      );
                      return CachedNetworkImage(
                        imageUrl: fallbackUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
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
    final totalPrice = _currentPrice * _qty;
    final canAddToCart = _currentStock > 0 && _product!.isAvailable;
    final isSelectOption = _product!.hasVariants && _selectedVariant == null && !_selectedIsMainProduct;
    final isOutOfStock = !canAddToCart && !isSelectOption;
    final isStoreClosed = _storeClosedOnDate;
    final allSlotsPassed = !_storeClosedOnDate && _selectedDeliveryDate != null && _timeSlots.isNotEmpty && _timeSlots.every((s) => s['passed'] == 'true');
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
                    : (isStoreClosed || allSlotsPassed)
                        ? RoseButton(
                            label: isStoreClosed ? 'Store Closed' : 'No Slots Available',
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