import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/checkout.dart';
import '../providers/address_provider.dart';
import '../screens/address/address_list_screen.dart';
import '../screens/main_shell.dart';
import '../screens/orders/orders_screen.dart';
import '../services/chat_service.dart';
import '../services/checkout_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Modal bottom sheet for customers to review and check out a Custom Arrangement Request Ticket.
/// Supports delivery address from saved customer addresses, store open-time delivery slots,
/// store-allowed COD/GCash payment methods (locked if disabled), optional dedication card,
/// optional YMAL add-ons selection, and switching to My Orders upon creation.
class CustomTicketCheckoutSheet extends StatefulWidget {
  final CustomQuoteTicketContext ticket;
  final VoidCallback onOrderPlaced;

  const CustomTicketCheckoutSheet({
    super.key,
    required this.ticket,
    required this.onOrderPlaced,
  });

  static Future<void> show(BuildContext context, {
    required CustomQuoteTicketContext ticket,
    required VoidCallback onOrderPlaced,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomTicketCheckoutSheet(
        ticket: ticket,
        onOrderPlaced: onOrderPlaced,
      ),
    );
  }

  @override
  State<CustomTicketCheckoutSheet> createState() => _CustomTicketCheckoutSheetState();
}

class _CustomTicketCheckoutSheetState extends State<CustomTicketCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _dedicationCtrl = TextEditingController();

  Address? _selectedAddress;
  bool _didRequestAddresses = false;

  // Delivery schedule & time slots
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  Map<String, String> _slotLabels = {};
  bool _timeSlotsLoading = false;
  bool _closedOnDate = false;
  String? _slotBlockReason;
  Set<String> _storeOpenDays = {};
  bool _storeHasSchedule = false;

  // Store delivery coverage validation
  bool _checkingCoverage = false;
  bool _canDeliver = true;
  String? _deliveryBlockReason;
  double _deliveryFee = 0.0;
  int? _lastCheckedAddressId;

  List<Map<String, dynamic>> _availableAddons = [];
  final Map<int, int> _selectedAddons = {}; // addon_option_id -> quantity
  bool _loadingAddons = true;

  late String _paymentMethod; // 'gcash' or 'cod'
  File? _receiptFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Default to an allowed payment method
    if (widget.ticket.storeAllowsGcash) {
      _paymentMethod = 'gcash';
    } else if (widget.ticket.storeAllowsCod) {
      _paymentMethod = 'cod';
    } else {
      _paymentMethod = 'gcash';
    }

    _loadStoreAddons();
    _loadStoreSchedule();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final addressProvider = context.read<AddressProvider>();
      if (!_didRequestAddresses && addressProvider.addresses.isEmpty && !addressProvider.isLoading) {
        _didRequestAddresses = true;
        addressProvider.loadAddresses();
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _dedicationCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAddressCoverage(Address? address) async {
    if (address == null || address.id == null) return;
    if (_lastCheckedAddressId == address.id) return;
    _lastCheckedAddressId = address.id;

    setState(() {
      _checkingCoverage = true;
    });

    final res = await ChatService.checkStoreDelivery(
      storeId: widget.ticket.storeId,
      addressId: address.id,
      subtotal: _grandTotal,
    );

    if (!mounted) return;
    setState(() {
      _checkingCoverage = false;
      _canDeliver = res['can_deliver'] == true;
      _deliveryBlockReason = res['reason']?.toString();
      _deliveryFee = double.tryParse(res['delivery_fee']?.toString() ?? '0') ?? 0.0;
    });
  }

  Future<void> _loadStoreAddons() async {
    setState(() => _loadingAddons = true);
    final addons = await ChatService.getStoreAddons(widget.ticket.storeId);
    if (!mounted) return;
    setState(() {
      _availableAddons = addons;
      _loadingAddons = false;
    });
  }

  Future<void> _loadStoreSchedule() async {
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final dateStr = DateFormat('yyyy-MM-dd').format(phToday);
    final result = await CheckoutService.fetchStoreTimeSlots(widget.ticket.storeId, dateStr);
    if (!mounted) return;
    if (result['success'] == true) {
      final openDays = (result['open_days'] as List? ?? const [])
          .map((d) => d.toString().toLowerCase())
          .toSet();
      final hasSchedule = result['has_schedule'] == true;
      setState(() {
        _storeOpenDays = openDays;
        _storeHasSchedule = hasSchedule;
      });

      if (hasSchedule && openDays.isNotEmpty) {
        final openDates = _openDeliveryDates();
        if (openDates.isNotEmpty) {
          final firstOpenDate = openDates.first;
          setState(() {
            _selectedDate = firstOpenDate;
          });
          await _fetchTimeSlots(firstOpenDate);

          // If today has 0 available slots (e.g. past cutoff or slots passed) but another open date exists,
          // automatically select the next open date so the user immediately gets available slots.
          if (_availableTimeSlots.isEmpty && openDates.length > 1) {
            final nextOpenDate = openDates[1];
            setState(() {
              _selectedDate = nextOpenDate;
            });
            await _fetchTimeSlots(nextOpenDate);
          }
        }
      }
    }
  }

  double get _addonsTotal {
    double sum = 0;
    for (final a in _availableAddons) {
      final id = a['id'] is int ? a['id'] as int : int.tryParse('${a['id']}') ?? 0;
      final qty = _selectedAddons[id] ?? 0;
      if (qty > 0) {
        final price = a['price'] is num ? (a['price'] as num).toDouble() : double.tryParse('${a['price']}') ?? 0;
        sum += price * qty;
      }
    }
    return sum;
  }

  double get _grandTotal => widget.ticket.basePrice + _addonsTotal + _deliveryFee;

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked != null) {
      setState(() => _receiptFile = File(picked.path));
    }
  }

  // ── Address Dropdown Helper ───────────────────────────────────────────────
  Address? _resolveDropdownAddress(AddressProvider addressProvider) {
    if (addressProvider.addresses.isEmpty) return null;
    if (_selectedAddress != null) {
      for (final a in addressProvider.addresses) {
        if (_selectedAddress!.id != null && a.id == _selectedAddress!.id) return a;
        if (identical(a, _selectedAddress)) return a;
      }
    }
    final fallback = addressProvider.selectedAddress ?? addressProvider.addresses.first;
    return fallback;
  }

  void _openAddressPicker() async {
    final result = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => AddressListScreen(
          isCheckoutSelection: true,
          onAddressSelected: (addr) {
            Navigator.of(context).pop(addr);
          },
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result;
      });
      _checkAddressCoverage(result);
    }
  }

  // ── Delivery Schedule & Time Slots Logic ──────────────────────────────────
  bool _isStoreOpenOn(DateTime date) {
    if (!_storeHasSchedule || _storeOpenDays.isEmpty) return false;
    const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return _storeOpenDays.contains(names[date.weekday - 1]);
  }

  Future<bool> _ensureStoreOpenDays() async {
    if (_storeHasSchedule && _storeOpenDays.isNotEmpty) return true;
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final dateStr = DateFormat('yyyy-MM-dd').format(phToday);
    final result = await CheckoutService.fetchStoreTimeSlots(widget.ticket.storeId, dateStr);
    if (!mounted) return false;
    if (result['success'] != true) {
      setState(() {
        _storeHasSchedule = false;
        _storeOpenDays = {};
      });
      return false;
    }
    final openDays = (result['open_days'] as List? ?? const [])
        .map((d) => d.toString().toLowerCase())
        .toSet();
    final hasSchedule = result['has_schedule'] == true;
    setState(() {
      _storeOpenDays = openDays;
      _storeHasSchedule = hasSchedule;
    });
    return hasSchedule && openDays.isNotEmpty;
  }

  List<DateTime> _openDeliveryDates() {
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final maxDate = phToday.add(const Duration(days: 14));
    final dates = <DateTime>[];
    for (var d = phToday; !d.isAfter(maxDate); d = d.add(const Duration(days: 1))) {
      if (_isStoreOpenOn(d)) dates.add(d);
    }
    return dates;
  }

  Future<void> _fetchTimeSlots(DateTime date) async {
    final normalizedDate = CheckoutService.normalizeToPhDate(date);
    final dateStr = DateFormat('yyyy-MM-dd').format(normalizedDate);

    setState(() {
      _timeSlotsLoading = true;
      _closedOnDate = false;
      _slotBlockReason = null;
    });

    final result = await CheckoutService.fetchStoreTimeSlots(widget.ticket.storeId, dateStr);
    if (!mounted) return;

    setState(() {
      _timeSlotsLoading = false;
      if (result['success'] == true) {
        final rawSlots = List<String>.from(result['slots'] ?? []);
        final rawLabels = Map<String, String>.from(result['labels'] ?? {});
        final isOpen = result['is_open'] == true;
        final hasSchedule = result['has_schedule'] == true;
        final isToday = DateFormat('yyyy-MM-dd').format(normalizedDate) ==
            DateFormat('yyyy-MM-dd').format(
              CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime()),
            );
        final filteredSlots = rawSlots.where((slot) {
          return !(isToday && CheckoutService.isTimeSlotPassed(slot));
        }).toList();
        final reason = CheckoutService.resolveSlotBlockReason(
          apiReason: result['block_reason'],
          isToday: isToday,
          isOpen: isOpen,
          hasSchedule: hasSchedule,
          hasBookableSlots: filteredSlots.isNotEmpty,
          orderCutoff: result['order_cutoff'],
          openDays: List<String>.from(result['open_days'] ?? const <String>[]),
          date: normalizedDate,
        );
        final openDays = (result['open_days'] as List? ?? const [])
            .map((d) => d.toString().toLowerCase())
            .toSet();
        _storeOpenDays = openDays;
        _storeHasSchedule = hasSchedule;
        _closedOnDate = reason == 'closed';
        _slotBlockReason = reason;
        _availableTimeSlots = filteredSlots;
        _slotLabels = rawLabels;
        if (_selectedTimeSlot != null && !filteredSlots.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
        if (_selectedTimeSlot == null && filteredSlots.isNotEmpty) {
          _selectedTimeSlot = filteredSlots.first;
        }
      } else {
        _availableTimeSlots = List<String>.from(result['slots'] ?? <String>[]);
        _closedOnDate = false;
        _slotBlockReason = 'no_schedule';
        _storeHasSchedule = false;
        _storeOpenDays = {};
        _selectedTimeSlot = null;
      }
    });
  }

  Future<void> _pickDeliveryDate() async {
    final ready = await _ensureStoreOpenDays();
    if (!mounted) return;
    if (!ready) {
      showToast(context, 'This store has not set delivery hours yet.', isError: true);
      return;
    }

    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final maxDate = phToday.add(const Duration(days: 14));

    var initialDate = CheckoutService.normalizeToPhDate(_selectedDate ?? phToday);
    while (!_isStoreOpenOn(initialDate) && initialDate.isBefore(maxDate)) {
      initialDate = initialDate.add(const Duration(days: 1));
    }
    if (!_isStoreOpenOn(initialDate)) {
      showToast(context, 'No open delivery days in the next 2 weeks.', isError: true);
      return;
    }

    final picked = await showDatePicker(
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
    );

    if (picked == null || !mounted) return;
    final normalized = CheckoutService.normalizeToPhDate(picked);
    if (!_isStoreOpenOn(normalized)) {
      showToast(context, 'Store is closed on this day. Pick another date.', isError: true);
      return;
    }
    setState(() {
      _selectedDate = normalized;
      _selectedTimeSlot = null;
      _closedOnDate = false;
    });
    await _fetchTimeSlots(normalized);
  }

  Future<void> _pickDeliveryTimeSlot() async {
    if (_availableTimeSlots.isEmpty) {
      showToast(context, 'No delivery hours available for this date.', isError: true);
      return;
    }
    var initialIndex = _selectedTimeSlot == null ? 0 : _availableTimeSlots.indexOf(_selectedTimeSlot!);
    if (initialIndex < 0) initialIndex = 0;

    final picked = await _showCupertinoWheelPicker<String>(
      title: 'Delivery hours',
      itemCount: _availableTimeSlots.length,
      initialIndex: initialIndex,
      itemBuilder: (index) {
        final slot = _availableTimeSlots[index];
        final label = _slotLabels[slot] ?? CheckoutService.formatTimeSlot(slot);
        return Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 20, color: AppColors.charcoal),
          ),
        );
      },
      valueOf: (index) => _availableTimeSlots[index],
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedTimeSlot = picked);
  }

  Future<T?> _showCupertinoWheelPicker<T>({
    required String title,
    required int itemCount,
    required int initialIndex,
    required Widget Function(int index) itemBuilder,
    required T Function(int index) valueOf,
  }) {
    var selected = initialIndex.clamp(0, itemCount - 1);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.pop(ctx, valueOf(selected)),
                        child: Text(
                          'Done',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: selected),
                    onSelectedItemChanged: (i) => selected = i,
                    children: List.generate(itemCount, itemBuilder),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formattedDateLabel(DateTime? date) {
    if (date == null) return 'Select date';
    final normalized = CheckoutService.normalizeToPhDate(date);
    final phToday = CheckoutService.normalizeToPhDate(CheckoutService.getPhilippineTime());
    final phTomorrow = phToday.add(const Duration(days: 1));

    if (normalized.year == phToday.year &&
        normalized.month == phToday.month &&
        normalized.day == phToday.day) {
      return 'Today · ${DateFormat('EEE, MMM d').format(normalized)}';
    } else if (normalized.year == phTomorrow.year &&
        normalized.month == phTomorrow.month &&
        normalized.day == phTomorrow.day) {
      return 'Tomorrow · ${DateFormat('EEE, MMM d').format(normalized)}';
    }
    return DateFormat('EEE, MMM d, yyyy').format(normalized);
  }

  String _hoursFieldLabel() {
    if (_selectedTimeSlot != null) {
      return _slotLabels[_selectedTimeSlot!] ?? CheckoutService.formatTimeSlot(_selectedTimeSlot!);
    }
    if (_selectedDate == null) return 'Select date first';
    if (_timeSlotsLoading) return 'Loading…';
    if (_closedOnDate || _availableTimeSlots.isEmpty) {
      if (_slotBlockReason == 'no_schedule') return 'Hours not set';
      if (_slotBlockReason == 'closed') return 'Closed';
      return 'No slots';
    }
    return 'Select hours';
  }

  // ── Confirm Order Modal ──────────────────────────────────────────────────
  Future<void> _showConfirmOrderModal(Address address) async {
    final t = widget.ticket;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: AppColors.deepRose, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Your Order',
                              style: GoogleFonts.dmSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                            Text(
                              'Please review your order before placing it',
                              style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 14),

                  // Order summary rows
                  _confirmRow(Icons.receipt_long_rounded, 'Arrangement', t.title),
                  const SizedBox(height: 8),
                  _confirmRow(
                    Icons.location_on_outlined,
                    'Deliver to',
                    '${address.addressLabel} · ${address.barangay}, ${address.municipality}',
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 8),
                    _confirmRow(
                      Icons.calendar_month_rounded,
                      'Schedule',
                      _selectedTimeSlot != null
                          ? '${_formattedDateLabel(_selectedDate)} · ${_slotLabels[_selectedTimeSlot!] ?? CheckoutService.formatTimeSlot(_selectedTimeSlot!)}'
                          : _formattedDateLabel(_selectedDate),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _confirmRow(
                    _paymentMethod == 'gcash' ? Icons.qr_code_2_rounded : Icons.payments_outlined,
                    'Payment',
                    _paymentMethod == 'gcash' ? 'GCash (receipt attached)' : 'Cash on Delivery (COD)',
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),

                  // Total amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        '₱${_grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepRose,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.charcoal,
                            side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Go Back',
                            style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepRose,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Place Order',
                            style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await _submitOrder(address);
    }
  }

  /// Small icon + label + value row used inside the confirm modal.
  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.deepRose),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.charcoal),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Submit Order ──────────────────────────────────────────────────────────
  Future<void> _submitOrder(Address? address) async {
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a delivery address.')),
      );
      return;
    }

    if (!_canDeliver) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[700],
          content: Text(_deliveryBlockReason ?? 'The store cannot deliver to the selected address.'),
        ),
      );
      return;
    }

    if (_paymentMethod == 'gcash' && !widget.ticket.storeAllowsGcash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GCash is disabled by this store. Please select Cash on Delivery.')),
      );
      return;
    }

    if (_paymentMethod == 'cod' && !widget.ticket.storeAllowsCod) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash on delivery is disabled by this store. Please select GCash.')),
      );
      return;
    }

    if (_paymentMethod == 'gcash' && _receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your GCash payment receipt to proceed.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // Prepare optional add-ons payload
    final addonsPayload = <Map<String, dynamic>>[];
    _selectedAddons.forEach((id, qty) {
      if (qty > 0) {
        addonsPayload.add({'addon_option_id': id, 'quantity': qty});
      }
    });

    final dateStr = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null;

    final res = await ChatService.checkoutCustomTicket(
      ticketId: widget.ticket.id,
      deliveryAddress: address.addressLine,
      deliveryAddressId: address.id,
      latitude: address.latitude,
      longitude: address.longitude,
      deliveryNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      requestedDate: dateStr,
      requestedTime: _selectedTimeSlot,
      dedicationCard: _dedicationCtrl.text.trim().isNotEmpty ? _dedicationCtrl.text.trim() : null,
      paymentMethod: _paymentMethod,
      receiptFile: _paymentMethod == 'gcash' ? _receiptFile : null,
      addons: addonsPayload,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      Navigator.of(context).pop();
      widget.onOrderPlaced();

      final createdOrderId = res['order_id'] is int
          ? res['order_id'] as int
          : (res['order_id'] != null ? int.tryParse('${res['order_id']}') : null);

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // Switch to My Orders tab, close drawer if open, and open the specific order detail screen
      MainShell.switchTab(context, 3, targetOrderStatus: 'pending', targetOrderId: createdOrderId);
      OrdersScreen.reload(targetStatus: 'pending', targetOrderId: createdOrderId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(res['message'] ?? 'Custom order placed successfully! Check My Orders.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[700],
          content: Text(res['error'] ?? 'Checkout failed'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final addressProvider = context.watch<AddressProvider>();
    final resolvedAddress = _resolveDropdownAddress(addressProvider);
    if (resolvedAddress != null && _lastCheckedAddressId != resolvedAddress.id && !_checkingCoverage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAddressCoverage(resolvedAddress);
      });
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header handle & title
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check Out Custom Quote',
                            style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                          Text(
                            '#${t.ticketNumber} · ${t.title}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary box
                    _buildArrangementSummary(),
                    const SizedBox(height: 20),

                    // Saved Address Selection Section
                    _buildAddressSection(context, addressProvider, resolvedAddress),
                    const SizedBox(height: 18),

                    // Delivery Schedule (Date & Time slots from store)
                    _buildDeliveryScheduleSection(),
                    const SizedBox(height: 14),

                    // Delivery notes
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: _inputDeco(
                        label: 'Delivery Notes (Optional)',
                        hint: 'Landmarks, gate instructions, etc.',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dedication card (Conditional on ticket.allowDedicationCard)
                    if (widget.ticket.allowDedicationCard) ...[
                      TextFormField(
                        controller: _dedicationCtrl,
                        maxLines: 2,
                        decoration: _inputDeco(
                          label: 'Dedication Card Message (Optional)',
                          hint: 'Write your greeting or message for the recipient…',
                          icon: Icons.card_giftcard_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 10),

                    // 100% Optional YMAL Add-ons Section
                    Row(
                      children: [
                        Text(
                          'Add-ons & Extras',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '100% Optional',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pair your bespoke arrangement with chocolates, toppers, or extra gifts.',
                      style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    _buildAddonsSection(),
                    const SizedBox(height: 24),

                    // Payment Method Section with Locking
                    Text(
                      'Payment Method',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentMethodSelector(),
                    const SizedBox(height: 24),

                    // Total Calculation & Submit Button
                    _buildTotalAndSubmit(resolvedAddress),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Address Section UI ────────────────────────────────────────────────────
  Widget _buildAddressSection(
    BuildContext context,
    AddressProvider addressProvider,
    Address? resolvedAddress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.deepRose),
                const SizedBox(width: 6),
                Text(
                  'Delivery Address',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _openAddressPicker,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Manage',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepRose,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (addressProvider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
              ),
            ),
          )
        else if (addressProvider.addresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFC0392B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No saved addresses found. Please add an address to proceed.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.charcoal),
                  ),
                ),
                TextButton(
                  onPressed: _openAddressPicker,
                  child: const Text('Add', style: TextStyle(color: AppColors.deepRose)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.8), width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Address>(
                isExpanded: true,
                value: resolvedAddress,
                hint: Text(
                  'Select delivery address',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.deepRose),
                items: addressProvider.addresses.map((address) {
                  return DropdownMenuItem<Address>(
                    value: address,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${address.addressLabel} · ${address.barangay}, ${address.municipality}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          address.addressLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (address) {
                  if (address != null) {
                    setState(() {
                      _selectedAddress = address;
                    });
                    _checkAddressCoverage(address);
                  }
                },
              ),
            ),
          ),
        if (_checkingCoverage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.deepRose)),
                const SizedBox(width: 6),
                Text('Verifying delivery coverage…', style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          )
        else if (!_canDeliver && _deliveryBlockReason != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _deliveryBlockReason!,
                    style: GoogleFonts.dmSans(fontSize: 11.5, color: const Color(0xFF991B1B), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Delivery Schedule Section ─────────────────────────────────────────────
  Widget _buildDeliveryScheduleSection() {
    final hasDate = _selectedDate != null;
    final hasTime = _selectedTimeSlot != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.deepRose),
            const SizedBox(width: 6),
            Text(
              'Delivery Schedule',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const Spacer(),
            if (hasDate && hasTime)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 11, color: AppColors.deepSage),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: GoogleFonts.dmSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepSage,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_availableTimeSlots.isEmpty && _slotBlockReason != null && !_timeSlotsLoading && hasDate)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC0392B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFC0392B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      CheckoutService.slotBlockMessage(_slotBlockReason),
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC0392B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _scheduleBox(
                label: 'Delivery Date',
                value: _formattedDateLabel(_selectedDate),
                icon: Icons.calendar_month_rounded,
                isPlaceholder: !hasDate,
                isEnabled: true,
                isLoading: false,
                onTap: _pickDeliveryDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _scheduleBox(
                label: 'Delivery Time',
                value: _hoursFieldLabel(),
                icon: Icons.access_time_filled_rounded,
                isPlaceholder: !hasTime,
                isEnabled: hasDate && !_timeSlotsLoading,
                isLoading: _timeSlotsLoading,
                onTap: !hasDate || _timeSlotsLoading ? null : _pickDeliveryTimeSlot,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scheduleBox({
    required String label,
    required String value,
    required IconData icon,
    required bool isPlaceholder,
    required bool isEnabled,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: isEnabled ? const Color(0xFFFDFBF7) : const Color(0xFFF7F4EF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: !isPlaceholder && isEnabled ? AppColors.deepRose.withValues(alpha: 0.35) : AppColors.border.withValues(alpha: 0.8),
          width: !isPlaceholder && isEnabled ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isEnabled ? AppColors.deepRose : AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w600,
                        color: isPlaceholder ? AppColors.muted : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isEnabled ? AppColors.deepRose : AppColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrangementSummary() {
    final t = widget.ticket;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t.imageUrl != null && t.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.imageUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 58, height: 58, color: AppColors.cream),
                    errorWidget: (_, __, ___) => Container(width: 58, height: 58, color: AppColors.cream),
                  )
                : Container(
                    width: 58,
                    height: 58,
                    color: AppColors.cream,
                    child: Icon(Icons.local_florist, size: 28, color: AppColors.deepRose.withValues(alpha: 0.4)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                Text(
                  'Category: ${t.categoryLabel}',
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
                ),
                if (t.inclusions != null && t.inclusions!.isNotEmpty)
                  Text(
                    t.inclusions!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.charcoal.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
          Text(
            '₱${t.basePrice.toStringAsFixed(2)}',
            style: GoogleFonts.dmSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.deepRose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsSection() {
    if (_loadingAddons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_availableAddons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No additional add-ons available for this store.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }

    return Column(
      children: _availableAddons.map((addon) {
        final id = addon['id'] is int ? addon['id'] as int : int.tryParse('${addon['id']}') ?? 0;
        final name = (addon['name'] ?? addon['product_name'] ?? 'Addon').toString();
        final price = addon['price'] is num ? (addon['price'] as num).toDouble() : double.tryParse('${addon['price']}') ?? 0;
        final rawStock = addon['stock_quantity'] ?? addon['stock'];
        final stock = rawStock is int ? rawStock : int.tryParse('$rawStock') ?? 0;
        final imgUrl = addon['image_url']?.toString();
        final selectedQty = _selectedAddons[id] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selectedQty > 0 ? const Color(0xFFFFF9FA) : Colors.white,
            border: Border.all(
              color: selectedQty > 0 ? AppColors.deepRose.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.6),
              width: selectedQty > 0 ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (imgUrl != null && imgUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox(width: 38, height: 38),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      '₱${price.toStringAsFixed(2)} · Stock: $stock',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              // Counter
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x73E6AAC3), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: selectedQty > 0
                          ? () {
                              setState(() {
                                final next = selectedQty - 1;
                                if (next <= 0) {
                                  _selectedAddons.remove(id);
                                } else {
                                  _selectedAddons[id] = next;
                                }
                              });
                            }
                          : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.remove,
                          size: 14,
                          color: selectedQty > 0 ? AppColors.charcoal : AppColors.borderStrong,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border.symmetric(
                          vertical: BorderSide(color: Color(0x4DE6AAC3), width: 1.2),
                        ),
                      ),
                      child: Text(
                        selectedQty > 0 ? '$selectedQty' : '0',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selectedQty > 0 ? AppColors.deepRose : AppColors.muted,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: (stock <= 0 || selectedQty >= stock)
                          ? null
                          : () {
                              setState(() {
                                _selectedAddons[id] = selectedQty + 1;
                              });
                            },
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: (stock > 0 && selectedQty < stock) ? AppColors.deepRose : AppColors.borderStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Payment Method Selector with Store Locking ────────────────────────────
  Widget _buildPaymentMethodSelector() {
    final codAllowed = widget.ticket.storeAllowsCod;
    final gcashAllowed = widget.ticket.storeAllowsGcash;

    return Column(
      children: [
        // Radio COD
        Opacity(
          opacity: codAllowed ? 1.0 : 0.45,
          child: InkWell(
            onTap: codAllowed ? () => setState(() => _paymentMethod = 'cod') : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _paymentMethod == 'cod' && codAllowed ? const Color(0xFFFBF8F5) : Colors.white,
                border: Border.all(
                  color: _paymentMethod == 'cod' && codAllowed ? AppColors.deepRose : AppColors.border,
                  width: _paymentMethod == 'cod' && codAllowed ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _paymentMethod == 'cod' && codAllowed ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _paymentMethod == 'cod' && codAllowed ? AppColors.deepRose : AppColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Cash on Delivery (COD)',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                            if (!codAllowed) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Disabled',
                                  style: GoogleFonts.dmSans(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          codAllowed
                              ? 'Pay the rider in cash when arrangement arrives'
                              : 'Cash on delivery is disabled by this store.',
                          style: GoogleFonts.dmSans(fontSize: 11.5, color: codAllowed ? AppColors.muted : Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Radio GCash
        Opacity(
          opacity: gcashAllowed ? 1.0 : 0.45,
          child: InkWell(
            onTap: gcashAllowed ? () => setState(() => _paymentMethod = 'gcash') : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _paymentMethod == 'gcash' && gcashAllowed ? const Color(0xFFFBF8F5) : Colors.white,
                border: Border.all(
                  color: _paymentMethod == 'gcash' && gcashAllowed ? AppColors.deepRose : AppColors.border,
                  width: _paymentMethod == 'gcash' && gcashAllowed ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _paymentMethod == 'gcash' && gcashAllowed ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _paymentMethod == 'gcash' && gcashAllowed ? AppColors.deepRose : AppColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'GCash Prepayment',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                            if (!gcashAllowed) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Disabled',
                                  style: GoogleFonts.dmSans(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          gcashAllowed
                              ? 'Transfer to store GCash and upload receipt screenshot'
                              : 'GCash is disabled by this store.',
                          style: GoogleFonts.dmSans(fontSize: 11.5, color: gcashAllowed ? AppColors.muted : Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // GCash receipt details
        if (gcashAllowed && _paymentMethod == 'gcash') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store GCash Details',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.ticket.storeGcashQrUrl != null && widget.ticket.storeGcashQrUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(20),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                                      ),
                                      child: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: CachedNetworkImage(
                                          imageUrl: widget.ticket.storeGcashQrUrl!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF93C5FD)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.ticket.storeGcashQrUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Please scan the QR code to proceed with payment.',
                            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.charcoal, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Receipt Upload Box
                InkWell(
                  onTap: _pickReceipt,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _receiptFile != null ? Icons.check_circle_outline : Icons.upload_file_rounded,
                          color: _receiptFile != null ? Colors.green : const Color(0xFF2563EB),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _receiptFile != null ? 'Receipt Attached (Tap to change)' : 'Upload GCash Receipt *',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _receiptFile != null ? Colors.green[800] : const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalAndSubmit(Address? address) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arrangement Base Price', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted)),
                  Text('₱${widget.ticket.basePrice.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              if (_addonsTotal > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Optional Add-ons', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted)),
                    Text('+ ₱${_addonsTotal.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.deepRose)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Delivery Fee', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.muted)),
                  Text('+ ₱${_deliveryFee.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
                  Text(
                    '₱${_grandTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.deepRose),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: (_submitting || !_canDeliver || _checkingCoverage || address == null)
                ? null
                : () => _showConfirmOrderModal(address),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepRose,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    !_canDeliver
                        ? 'Delivery Unavailable for Selected Address'
                        : 'Confirm & Place Order (₱${_grandTotal.toStringAsFixed(2)})',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco({required String label, required String hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.muted) : null,
      labelStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
      hintStyle: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFFDFBF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.deepRose, width: 1.5),
      ),
    );
  }
}

