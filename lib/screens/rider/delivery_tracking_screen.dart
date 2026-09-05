import 'dart:async';
import 'dart:math' as Math;
import 'dart:ui' as ui show Path;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rider_heading_marker.dart';
import '../../widgets/common.dart';
import '../../widgets/chat_drawer.dart';
import 'rider_status_style.dart';
import 'rider_ui.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final RiderOrder order;
  const DeliveryTrackingScreen({super.key, required this.order});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetInitialSize = 0.48;
  static const double _sheetMaxSize = 0.54;
  static const double _sheetCollapsedSize = 0.0;
  static const List<double> _sheetSnapSizes = [0.0, 0.48, 0.54];
  static const double _sheetExpandTriggerSize = 0.06;

  List<LatLng> _routePoints = [];
  LatLng? _riderPosition;
  LatLng? _previousRiderPosition;
  double? _riderHeading;
  bool _loadingRoute = false;
  bool _markingDelivered = false;
  int? _routeEtaMin;
  double? _routeDistanceKm;
  RiderProvider? _riderProvider;
  bool _fetchingRoute = false;
  double _sheetExtent = _sheetInitialSize;
  bool _handlingSheetCollapse = false;
  Timer? _sheetCollapseExpandTimer;

  LatLng? get _storeLocation {
    if (widget.order.storeLatitude != null &&
        widget.order.storeLongitude != null) {
      return LatLng(widget.order.storeLatitude!, widget.order.storeLongitude!);
    }
    return null;
  }

  LatLng? get _customerLocation {
    if (widget.order.customerLatitude != null &&
        widget.order.customerLongitude != null) {
      return LatLng(
          widget.order.customerLatitude!, widget.order.customerLongitude!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _riderProvider = context.read<RiderProvider>();
    _riderProvider!.addListener(_syncRiderFromProvider);
    _sheetController.addListener(_onSheetExtentChanged);
    _initTracking();
  }

  void _syncRiderFromProvider() {
    if (widget.order.status != 'on_delivery') return;
    final p = _riderProvider?.currentPosition;
    if (p == null || !mounted) return;

    final next = LatLng(p.latitude, p.longitude);
    _applyRiderFix(next, position: p);
  }

  Future<void> _initTracking() async {
    final provider = context.read<RiderProvider>();

    // Get current rider location
    final pos = await provider.getCurrentLocation();
    if (pos != null && mounted) {
      _applyRiderFix(LatLng(pos.latitude, pos.longitude), position: pos);
    }

    if (widget.order.status == 'on_delivery') {
      provider.startLocationTracking(widget.order.id);
    }

    if (_riderPosition == null) {
      await _fetchRoute();
    }
  }

  void _applyRiderFix(LatLng next, {Position? position}) {
    final movedMeters = _riderPosition == null
        ? double.infinity
        : _calculateDistance(_riderPosition!, next) * 1000;

    final heading = RiderHeadingMarker.resolveHeading(
      previous: _riderPosition ?? _previousRiderPosition,
      current: next,
      position: position,
      previousHeading: _riderHeading,
    );

    final headingChanged = _didHeadingChange(heading, _riderHeading);

    if (_riderPosition != null && movedMeters < 3 && !headingChanged) {
      return;
    }

    setState(() {
      if (_riderPosition == null || movedMeters >= 3) {
        _previousRiderPosition = _riderPosition;
        _riderPosition = next;
      }
      if (heading != null) _riderHeading = heading;
    });

    if (widget.order.status == 'on_delivery' && movedMeters >= 10) {
      _fetchRoute();
    }
  }

  bool _didHeadingChange(double? next, double? previous) {
    if (next == null) return false;
    if (previous == null) return true;
    final delta = ((next - previous + 540) % 360) - 180;
    return delta.abs() > 4;
  }

  LatLng? get _routeStart => _riderPosition ?? _storeLocation;

  Future<void> _fetchRoute() async {
    if (_fetchingRoute) return;
    final start = _routeStart;
    final end = _customerLocation;

    if (start == null || end == null) {
      if (mounted) setState(() => _loadingRoute = false);
      return;
    }

    _fetchingRoute = true;
    if (mounted) setState(() => _loadingRoute = true);
    try {
      final info = await RiderService.getRouteInfo(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      if (mounted) {
        setState(() {
          _loadingRoute = false;
          if (info != null) {
            _routePoints = info.points.map((p) => LatLng(p[0], p[1])).toList();
            _routeDistanceKm = info.distanceM != null
                ? info.distanceM! / 1000
                : null;
            _routeEtaMin = info.durationSec != null
                ? Math.max(1, (info.durationSec! / 60).round())
                : null;
          }
        });
      }
    } finally {
      _fetchingRoute = false;
      if (mounted && _loadingRoute) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  LatLng get _mapCenter {
    if (_riderPosition != null) return _riderPosition!;
    if (_storeLocation != null) return _storeLocation!;
    if (_customerLocation != null) return _customerLocation!;
    // Default to Laguna, Philippines
    return const LatLng(14.2691, 121.4113);
  }

  LatLngBounds? get _bounds {
    final points = <LatLng>[];
    if (_riderPosition != null) points.add(_riderPosition!);
    if (_storeLocation != null) points.add(_storeLocation!);
    if (_customerLocation != null) points.add(_customerLocation!);
    if (points.length < 2) return null;
    return LatLngBounds.fromPoints(points);
  }

  Future<void> _markDelivered() async {
    if (_markingDelivered) return;

    // Show image capture dialog
    final imagePaths = await showDialog<Map<int, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryProofDialog(orderId: widget.order.id),
    );

    if (imagePaths == null || !mounted) return;

    // Both images captured, show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delivery',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Proofs captured successfully!',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Mark this order as delivered?', style: GoogleFonts.dmSans()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Call markDelivered with image paths
    setState(() => _markingDelivered = true);
    final ok = await context.read<RiderProvider>().markDelivered(
          widget.order.id,
          deliveryProofPath1: imagePaths[1],
          deliveryProofPath2: imagePaths[2],
        );
    if (mounted) {
      setState(() => _markingDelivered = false);
    }

    if (!mounted) return;
    if (ok) {
      showToast(context, 'Order delivered successfully!');

      // Navigate back to rider dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showToast(context, 'Failed to update status', isError: true);
    }
  }

  Future<void> _openInMaps() async {
    final end = _customerLocation;

    if (end == null) {
      showToast(context, 'Customer location not available', isError: true);
      return;
    }

    final lat = end.latitude;
    final lng = end.longitude;
    final origin = _riderPosition;
    final originParam = origin != null
        ? '&origin=${origin.latitude},${origin.longitude}'
        : '';
    final candidates = [
      Uri.parse('google.navigation:q=$lat,$lng'),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent('Delivery')})'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1$originParam'
        '&destination=$lat,$lng&travelmode=driving',
      ),
      Uri.parse('https://maps.google.com/?daddr=$lat,$lng'),
    ];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } on PlatformException {
        continue;
      } catch (_) {
        continue;
      }
    }

    // No external maps app (common on emulators) — focus the in-app map instead.
    try {
      final start = _riderPosition ?? _storeLocation;
      if (start != null) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([start, end]),
            padding: const EdgeInsets.fromLTRB(48, 120, 48, 280),
          ),
        );
      } else {
        _mapController.move(end, 15);
      }
      if (mounted) {
        showToast(context, 'Route shown on map (install Google Maps to open externally)');
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Could not open maps', isError: true);
      }
    }
  }

  Future<void> _callCustomer() async {
    final order = widget.order;
    final tel = order.customerTel ??
        (order.customerPhone != null && order.customerPhone!.startsWith('09')
            ? 'tel:+63${order.customerPhone!.substring(1)}'
            : null);
    if (tel == null) {
      showToast(context, 'No phone number available', isError: true);
      return;
    }
    final ok = await launchUrl(Uri.parse(tel));
    if (!ok && mounted) {
      showToast(context, 'Could not start a phone call', isError: true);
    }
  }

  Future<void> _openOrderChat() async {
    final order = widget.order;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => Material(
          color: Colors.transparent,
          child: ChatDrawer(
            onClose: () => Navigator.of(ctx).pop(),
            openStoreId: order.storeId,
            openCustomerId: order.customerId,
            openOrderId: order.id,
          ),
        ),
      ),
    );
  }

  void _shareDeliveryDetails() {
    final order = widget.order;
    final lines = [
      'Order #${order.id}',
      if (order.customerName != null) 'Customer: ${order.customerName}',
      if (order.deliveryAddress != null) 'Address: ${order.deliveryAddress}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    showToast(context, 'Delivery details copied');
  }

  void _fitMapCamera({MapController? controller, EdgeInsets? padding}) {
    final map = controller ?? _mapController;
    final b = _bounds;
    if (b == null) {
      map.move(_mapCenter, 14);
      return;
    }
    try {
      map.fitCamera(
        CameraFit.bounds(
          bounds: b,
          padding: padding ??
              const EdgeInsets.fromLTRB(48, 100, 48, 200),
        ),
      );
    } catch (_) {}
  }

  void _zoomMap(double delta) {
    try {
      final cam = _mapController.camera;
      _mapController.move(
        cam.center,
        (cam.zoom + delta).clamp(3.0, 19.0),
      );
    } catch (_) {}
  }

  Future<void> _expandMap(double sheetHeight) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _ExpandedRiderTrackingPage(
          order: widget.order,
          initialRoutePoints: _routePoints,
          initialRiderPosition: _riderPosition,
          initialHeading: _riderHeading,
          initialEtaMin: _routeEtaMin,
          storeLocation: _storeLocation,
          customerLocation: _customerLocation,
          onChat: _openOrderChat,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) {
      _fitMapCamera(
        padding: EdgeInsets.fromLTRB(
          48,
          100,
          48,
          MediaQuery.sizeOf(context).height * _sheetExtent * 0.35,
        ),
      );
    }
  }

  void _onSheetExtentChanged() {
    if (!_sheetController.isAttached || !mounted) return;
    final size = _sheetController.size;
    if ((size - _sheetExtent).abs() > 0.004) {
      setState(() => _sheetExtent = size);
    }
    _scheduleExpandIfSheetCollapsed();
  }

  void _scheduleExpandIfSheetCollapsed() {
    _sheetCollapseExpandTimer?.cancel();
    if (_handlingSheetCollapse || !_sheetController.isAttached) return;
    if (_sheetController.size > _sheetExpandTriggerSize) return;

    _sheetCollapseExpandTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted || _handlingSheetCollapse || !_sheetController.isAttached) {
        return;
      }
      if (_sheetController.size <= _sheetExpandTriggerSize) {
        unawaited(_expandFromSheetCollapse());
      }
    });
  }

  void _onSheetPointerUp() {
    if (_handlingSheetCollapse || !_sheetController.isAttached) return;
    if (_sheetController.size <= _sheetExpandTriggerSize) {
      unawaited(_expandFromSheetCollapse());
      return;
    }
    _scheduleExpandIfSheetCollapsed();
  }

  Future<void> _expandFromSheetCollapse() async {
    if (_handlingSheetCollapse || !mounted) return;
    _handlingSheetCollapse = true;
    try {
      if (_sheetController.isAttached) {
        await _sheetController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
        );
      }
      if (!mounted) return;
      await _expandMap(MediaQuery.sizeOf(context).height * _sheetInitialSize);
    } finally {
      _handlingSheetCollapse = false;
      if (mounted && _sheetController.isAttached) {
        _sheetController.jumpTo(_sheetInitialSize);
        setState(() => _sheetExtent = _sheetInitialSize);
      }
    }
  }

  String? get _customerPhoneDisplay {
    final order = widget.order;
    if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
      return order.customerPhone;
    }
    return order.customerContact;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371.0; // km
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLng = _degreesToRadians(end.longitude - start.longitude);
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(start.latitude)) *
            Math.cos(_degreesToRadians(end.latitude)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    final c = 2 * Math.asin(Math.sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * Math.pi / 180;

  @override
  void dispose() {
    _sheetCollapseExpandTimer?.cancel();
    _sheetController.removeListener(_onSheetExtentChanged);
    _sheetController.dispose();
    _riderProvider?.removeListener(_syncRiderFromProvider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetPixelHeight = screenHeight * _sheetExtent;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _DeliveryTrackingMapView(
              mapController: _mapController,
              mapCenter: _mapCenter,
              routePoints: _routePoints,
              storeLocation: _storeLocation,
              customerLocation: _customerLocation,
              riderPosition: _riderPosition,
              riderHeading: _riderHeading,
              interactionFlags: InteractiveFlag.all,
              compactPins: false,
              onMapReady: () => _fitMapCamera(
                padding: EdgeInsets.fromLTRB(48, 100, 48, sheetPixelHeight * 0.35),
              ),
            ),
          ),
          if (_loadingRoute && _routePoints.isEmpty)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.deepRose,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Calculating shortest route…',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _TrackingIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: IgnorePointer(
                        child: Text(
                          'Live Delivery Tracking',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ),
                    _TrackingIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: _shareDeliveryDetails,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 52,
            right: 14,
            child: _ExpandedZoomControls(
              onZoomIn: () => _zoomMap(1),
              onZoomOut: () => _zoomMap(-1),
            ),
          ),
          if (_sheetExtent > 0.08)
            Positioned(
              right: 14,
              bottom: sheetPixelHeight + 12,
              child: _TrackingIconButton(
                icon: Icons.open_in_full_rounded,
                onTap: _expandFromSheetCollapse,
              ),
            ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _sheetInitialSize,
            minChildSize: _sheetCollapsedSize,
            maxChildSize: _sheetMaxSize,
            snap: true,
            snapSizes: _sheetSnapSizes,
            builder: (context, scrollController) {
              return Listener(
                onPointerUp: (_) => _onSheetPointerUp(),
                onPointerCancel: (_) => _onSheetPointerUp(),
                child: _TrackingDetailsSheet(
                  order: order,
                  scrollController: scrollController,
                  markingDelivered: _markingDelivered,
                  routeEtaMin: _routeEtaMin,
                  routeDistanceKm: _routeDistanceKm,
                  onNavigate: _openInMaps,
                  onDelivered: _markDelivered,
                  onCall: _callCustomer,
                  onChat: _openOrderChat,
                  customerPhone: _customerPhoneDisplay,
                  bottomInset: bottomInset,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeliveryTrackingMapView extends StatefulWidget {
  const _DeliveryTrackingMapView({
    required this.mapController,
    required this.mapCenter,
    required this.routePoints,
    required this.storeLocation,
    required this.customerLocation,
    required this.riderPosition,
    required this.riderHeading,
    required this.interactionFlags,
    required this.compactPins,
    this.onMapReady,
  });

  final MapController mapController;
  final LatLng mapCenter;
  final List<LatLng> routePoints;
  final LatLng? storeLocation;
  final LatLng? customerLocation;
  final LatLng? riderPosition;
  final double? riderHeading;
  final int interactionFlags;
  final bool compactPins;
  final VoidCallback? onMapReady;

  @override
  State<_DeliveryTrackingMapView> createState() =>
      _DeliveryTrackingMapViewState();
}

class _DeliveryTrackingMapViewState extends State<_DeliveryTrackingMapView> {
  late final LatLng _initialCenter;
  late final double _initialZoom;

  @override
  void initState() {
    super.initState();
    _initialCenter = widget.mapCenter;
    _initialZoom = 14;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        interactionOptions: InteractionOptions(
          flags: widget.interactionFlags,
          enableMultiFingerGestureRace: false,
        ),
        onMapReady: widget.onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.eflowers.app',
          maxZoom: 19,
        ),
        if (widget.routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints,
                color: AppColors.deepRose,
                strokeWidth: 5.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.storeLocation != null)
              Marker(
                point: widget.storeLocation!,
                width: widget.compactPins ? 44 : 40,
                height: widget.compactPins ? 44 : 48,
                alignment: widget.compactPins ? Alignment.center : Alignment.topCenter,
                child: widget.compactPins
                    ? const _CircleTrackingPin(
                        color: AppColors.deepRose,
                        icon: Icons.storefront_rounded,
                      )
                    : const _TeardropPin(
                        color: AppColors.sage,
                        icon: Icons.storefront_rounded,
                      ),
              ),
            if (widget.customerLocation != null)
              Marker(
                point: widget.customerLocation!,
                width: widget.compactPins ? 48 : 40,
                height: widget.compactPins ? 48 : 48,
                alignment: widget.compactPins ? Alignment.center : Alignment.topCenter,
                child: widget.compactPins
                    ? const _CircleTrackingPin(
                        color: AppColors.deepSage,
                        icon: Icons.home_rounded,
                      )
                    : const _TeardropPin(
                        color: AppColors.deepRose,
                        icon: Icons.location_on_rounded,
                      ),
              ),
            if (widget.riderPosition != null)
              Marker(
                point: widget.riderPosition!,
                width: 56,
                height: 56,
                child: widget.compactPins
                    ? const _CircleTrackingPin(
                        color: AppColors.deepRose,
                        icon: Icons.two_wheeler_rounded,
                      )
                    : _PulsingRiderMarker(headingDegrees: widget.riderHeading),
              ),
          ],
        ),
      ],
    );
  }
}

class _CircleTrackingPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _CircleTrackingPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _ExpandedRiderTrackingPage extends StatefulWidget {
  const _ExpandedRiderTrackingPage({
    required this.order,
    required this.initialRoutePoints,
    required this.initialRiderPosition,
    required this.initialHeading,
    required this.initialEtaMin,
    required this.storeLocation,
    required this.customerLocation,
    required this.onChat,
  });

  final RiderOrder order;
  final List<LatLng> initialRoutePoints;
  final LatLng? initialRiderPosition;
  final double? initialHeading;
  final int? initialEtaMin;
  final LatLng? storeLocation;
  final LatLng? customerLocation;
  final VoidCallback onChat;

  @override
  State<_ExpandedRiderTrackingPage> createState() =>
      _ExpandedRiderTrackingPageState();
}

class _ExpandedRiderTrackingPageState extends State<_ExpandedRiderTrackingPage> {
  final MapController _mapController = MapController();
  late List<LatLng> _routePoints;
  LatLng? _riderPosition;
  double? _riderHeading;
  int? _routeEtaMin;
  bool _mapReady = false;
  bool _fetchingRoute = false;
  RiderProvider? _provider;

  LatLng get _mapCenter =>
      _riderPosition ??
      widget.customerLocation ??
      widget.storeLocation ??
      const LatLng(14.2691, 121.4113);

  LatLngBounds? get _bounds {
    final points = <LatLng>[];
    if (_riderPosition != null) points.add(_riderPosition!);
    if (widget.storeLocation != null) points.add(widget.storeLocation!);
    if (widget.customerLocation != null) points.add(widget.customerLocation!);
    if (points.length < 2) return null;
    return LatLngBounds.fromPoints(points);
  }

  @override
  void initState() {
    super.initState();
    _routePoints = List<LatLng>.from(widget.initialRoutePoints);
    _riderPosition = widget.initialRiderPosition;
    _riderHeading = widget.initialHeading;
    _routeEtaMin = widget.initialEtaMin;
    _provider = context.read<RiderProvider>();
    _provider!.addListener(_syncFromProvider);
  }

  @override
  void dispose() {
    _provider?.removeListener(_syncFromProvider);
    super.dispose();
  }

  void _syncFromProvider() {
    if (widget.order.status != 'on_delivery') return;
    final p = _provider?.currentPosition;
    if (p == null || !mounted) return;
    _applyRiderFix(LatLng(p.latitude, p.longitude), position: p);
  }

  void _applyRiderFix(LatLng next, {Position? position}) {
    final movedMeters = _riderPosition == null
        ? double.infinity
        : _haversineKm(_riderPosition!, next) * 1000;

    final heading = RiderHeadingMarker.resolveHeading(
      previous: _riderPosition,
      current: next,
      position: position,
      previousHeading: _riderHeading,
    );

    if (_riderPosition != null && movedMeters < 3 && heading == _riderHeading) {
      return;
    }

    setState(() {
      _riderPosition = next;
      if (heading != null) _riderHeading = heading;
    });

    if (movedMeters >= 10) _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_fetchingRoute) return;
    final start = _riderPosition ?? widget.storeLocation;
    final end = widget.customerLocation;
    if (start == null || end == null) return;

    _fetchingRoute = true;
    try {
      final info = await RiderService.getRouteInfo(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      if (!mounted || info == null) return;
      setState(() {
        _routePoints = info.points.map((p) => LatLng(p[0], p[1])).toList();
        if (info.durationSec != null) {
          _routeEtaMin = Math.max(1, (info.durationSec! / 60).round());
        }
      });
    } finally {
      _fetchingRoute = false;
    }
  }

  void _fitMap() {
    if (!_mapReady) return;
    final b = _bounds;
    if (b == null) {
      _mapController.move(_mapCenter, 15);
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: b,
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 180),
        ),
      );
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapController.camera;
      _mapController.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
    } catch (_) {}
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * Math.pi / 180;
    final dLng = (b.longitude - a.longitude) * Math.pi / 180;
    final x = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(a.latitude * Math.pi / 180) *
            Math.cos(b.latitude * Math.pi / 180) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    return r * 2 * Math.asin(Math.sqrt(x));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final waiting = _riderPosition == null;
    final customerName =
        widget.order.customerName?.trim().isNotEmpty == true
            ? widget.order.customerName!.trim()
            : 'Customer';

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _DeliveryTrackingMapView(
            mapController: _mapController,
            mapCenter: _mapCenter,
            routePoints: _routePoints,
            storeLocation: widget.storeLocation,
            customerLocation: widget.customerLocation,
            riderPosition: _riderPosition,
            riderHeading: _riderHeading,
            interactionFlags: InteractiveFlag.all,
            compactPins: true,
            onMapReady: () {
              _mapReady = true;
              _fitMap();
            },
          ),
          Positioned(
            top: top + 8,
            left: 12,
            child: _ExpandedMapControl(
              icon: Icons.close_rounded,
              iconColor: AppColors.deepRose,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _LiveTrackingChip(waiting: waiting)),
            ),
          ),
          Positioned(
            top: top + 8,
            right: 12,
            child: Column(
              children: [
                _ExpandedMapControl(
                  icon: Icons.my_location_rounded,
                  onTap: _fitMap,
                ),
                const SizedBox(height: 8),
                _ExpandedZoomControls(onZoomIn: () => _zoomBy(1), onZoomOut: () => _zoomBy(-1)),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + bottom,
            child: _ExpandedTrackingEtaBar(
              waiting: waiting,
              etaMin: _routeEtaMin,
              subtitle: customerName,
              onChat: widget.onChat,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTrackingChip extends StatelessWidget {
  final bool waiting;
  const _LiveTrackingChip({required this.waiting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.deepRose.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: waiting ? AppColors.blush : const Color(0xFFFFD6DE),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            waiting ? 'CONNECTING' : 'LIVE',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedMapControl extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ExpandedMapControl({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: iconColor ?? AppColors.deepRose),
        ),
      ),
    );
  }
}

class _ExpandedZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ExpandedZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      shadowColor: Colors.black26,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onZoomIn,
              child: const SizedBox(
                width: 42,
                height: 38,
                child: Icon(Icons.add, size: 20, color: AppColors.deepRose),
              ),
            ),
            Container(height: 1, color: AppColors.border),
            InkWell(
              onTap: onZoomOut,
              child: const SizedBox(
                width: 42,
                height: 38,
                child: Icon(Icons.remove, size: 20, color: AppColors.deepRose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedTrackingEtaBar extends StatelessWidget {
  final bool waiting;
  final int? etaMin;
  final String subtitle;
  final VoidCallback onChat;

  const _ExpandedTrackingEtaBar({
    required this.waiting,
    required this.etaMin,
    required this.subtitle,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final title = waiting
        ? 'Heading to customer'
        : (etaMin != null
            ? 'Arriving in $etaMin min'
            : 'On the way to customer');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.roseCta.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  waiting ? 'Waiting for GPS…' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (etaMin != null && !waiting) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppColors.badgeGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$etaMin min',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Material(
            color: AppColors.blush.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onChat,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.deepRose,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TrackingIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x22502846),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.charcoal),
        ),
      ),
    );
  }
}

class _TeardropPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _TeardropPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PulsingRiderMarker extends StatefulWidget {
  final double? headingDegrees;

  const _PulsingRiderMarker({this.headingDegrees});

  @override
  State<_PulsingRiderMarker> createState() => _PulsingRiderMarkerState();
}

class _PulsingRiderMarkerState extends State<_PulsingRiderMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = 1 + (Math.sin(t * Math.pi * 2) * 0.08);
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3498db).withValues(alpha: 0.18),
                ),
              ),
              RiderHeadingMarker(headingDegrees: widget.headingDegrees),
            ],
          ),
        );
      },
    );
  }
}

class _TrackingDetailsSheet extends StatelessWidget {
  const _TrackingDetailsSheet({
    required this.order,
    required this.scrollController,
    required this.markingDelivered,
    this.routeEtaMin,
    this.routeDistanceKm,
    required this.onNavigate,
    required this.onDelivered,
    required this.onCall,
    required this.onChat,
    required this.customerPhone,
    required this.bottomInset,
  });

  final RiderOrder order;
  final ScrollController scrollController;
  final bool markingDelivered;
  final int? routeEtaMin;
  final double? routeDistanceKm;
  final VoidCallback onNavigate;
  final VoidCallback onDelivered;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final String? customerPhone;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final statusStyle = RiderStatusStyle.of(order.status);
    final riderSubtitle = () {
      if (order.status == 'on_delivery' &&
          routeEtaMin != null &&
          routeDistanceKm != null) {
        return '$routeEtaMin min · ${routeDistanceKm!.toStringAsFixed(1)} km';
      }
      if (order.status == 'on_delivery') return 'On the way';
      return order.statusLabel;
    }();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28502846),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + bottomInset),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
            Row(
              children: [
                Text(
                  'Order #${order.id}',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const Spacer(),
                RiderStatusBadge(
                  label: order.statusLabel.toUpperCase(),
                  style: statusStyle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TrackingPartyTile(
                    color: AppColors.sage,
                    icon: Icons.storefront_rounded,
                    title: 'Store',
                    subtitle: order.storeName ?? 'Pickup',
                  ),
                ),
                Expanded(
                  child: _TrackingPartyTile(
                    color: AppColors.deepRose,
                    icon: Icons.person_rounded,
                    title: 'Customer',
                    subtitle: order.customerName ?? 'Recipient',
                  ),
                ),
                Expanded(
                  child: _TrackingPartyTile(
                    color: const Color(0xFF3498db),
                    icon: Icons.navigation_rounded,
                    title: 'You',
                    subtitle: riderSubtitle,
                  ),
                ),
              ],
            ),
            if (order.status == 'on_delivery' &&
                routeEtaMin != null &&
                routeDistanceKm != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cream.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: AppColors.deepRose,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shortest driving route · $routeEtaMin min '
                        '(${routeDistanceKm!.toStringAsFixed(1)} km)',
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
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              'Customer',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Customer',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      if (customerPhone != null && customerPhone!.isNotEmpty)
                        Text(
                          customerPhone!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.successGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onCall,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.deepRose,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChat,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Address',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.deepRose,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.deliveryAddress ?? 'No address provided',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.charcoal,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (order.status == 'on_delivery')
              Row(
                children: [
                  Expanded(
                    child: RiderOutlineButton(
                      label: 'Navigate',
                      icon: Icons.navigation_rounded,
                      onTap: onNavigate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DeliveredActionButton(
                      loading: markingDelivered,
                      onTap: markingDelivered ? null : onDelivered,
                    ),
                  ),
                ],
              ),
            if (order.status == 'accepted')
              _AcceptAndTrackButton(orderId: order.id),
        ],
      ),
    );
  }
}

class _TrackingPartyTile extends StatelessWidget {
  const _TrackingPartyTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _DeliveredActionButton extends StatelessWidget {
  const _DeliveredActionButton({
    required this.loading,
    required this.onTap,
  });

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: onTap == null
                ? AppColors.muted.withValues(alpha: 0.35)
                : AppColors.successGreen,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppColors.successGreen.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Delivered',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AcceptAndTrackButton extends StatefulWidget {
  final int orderId;
  const _AcceptAndTrackButton({required this.orderId});
  @override
  State<_AcceptAndTrackButton> createState() => _AcceptAndTrackButtonState();
}

class _AcceptAndTrackButtonState extends State<_AcceptAndTrackButton> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    final ok = await context.read<RiderProvider>().acceptOrder(widget.orderId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      showToast(context, 'Order accepted! Tracking started.');
      Navigator.pop(context);
    } else {
      showToast(context, 'Failed to accept order', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiderGradientButton(
      label: _loading ? 'Accepting...' : 'Accept & Start Delivery',
      icon: Icons.delivery_dining_rounded,
      loading: _loading,
      onTap: _loading ? null : _accept,
    );
  }
}

class DeliveryProofDialog extends StatefulWidget {
  final int orderId;
  const DeliveryProofDialog({required this.orderId});

  @override
  State<DeliveryProofDialog> createState() => _DeliveryProofDialogState();
}

class _DeliveryProofDialogState extends State<DeliveryProofDialog> {
  final ImagePicker _imagePicker = ImagePicker();
  final Map<int, String?> _capturedImages = {1: null, 2: null};
  bool _isCapturingSequence = false;

  Future<void> _captureImage(int proofIndex) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() {
          _capturedImages[proofIndex] = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error capturing image: $e', isError: true);
      }
    }
  }

  Future<void> _captureSequence() async {
    if (_isCapturingSequence) return;
    setState(() => _isCapturingSequence = true);

    try {
      // Capture first proof
      if (_capturedImages[1] == null) {
        await _captureImage(1);
        if (!mounted) return;

        // Wait a moment before capturing second proof
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Capture second proof
      if (_capturedImages[2] == null) {
        await _captureImage(2);
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturingSequence = false);
      }
    }
  }

  bool get _bothCaptured =>
      _capturedImages[1] != null && _capturedImages[2] != null;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isExtraSmallScreen = screenSize.width < 320;

    // Responsive padding
    final horizontalPadding = isExtraSmallScreen
        ? 12.0
        : isSmallScreen
            ? 16.0
            : 20.0;

    // Responsive font sizes
    final headerFontSize = isExtraSmallScreen
        ? 20.0
        : isSmallScreen
            ? 22.0
            : 24.0;
    final subHeaderFontSize = isSmallScreen ? 12.0 : 13.0;

    return Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 24,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.95,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Delivery Proof',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capture 2 proof images before marking as delivered',
                  style: GoogleFonts.dmSans(
                    fontSize: subHeaderFontSize,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 20),

                // Proof 1
                _buildProofCard(1, isSmallScreen),
                const SizedBox(height: 16),

                // Proof 2
                _buildProofCard(2, isSmallScreen),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isCapturingSequence
                            ? null
                            : _bothCaptured
                                ? () => Navigator.pop(context,
                                    _capturedImages.cast<int, String>())
                                : _captureSequence,
                        icon: _isCapturingSequence
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Icon(
                                _bothCaptured ? Icons.check : Icons.camera_alt,
                                size: isSmallScreen ? 16 : 18,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bothCaptured
                              ? AppColors.successGreen
                              : AppColors.deepRose,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        label: Text(
                          _bothCaptured
                              ? 'Continue'
                              : _isCapturingSequence
                                  ? 'Capturing...'
                                  : 'Capture',
                          style: GoogleFonts.dmSans(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProofCard(int proofIndex, bool isSmallScreen) {
    final imagePath = _capturedImages[proofIndex];
    final hasCaptured = imagePath != null;

    // Responsive sizing
    final imageHeight = isSmallScreen ? 110.0 : 140.0;
    final cardPadding = isSmallScreen ? 10.0 : 14.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    final statusFontSize = isSmallScreen ? 11.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCaptured ? AppColors.successGreen : AppColors.border,
          width: hasCaptured ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Image Preview
          if (hasCaptured)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.file(
                File(imagePath),
                height: imageHeight,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: imageHeight,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                color: AppColors.cream,
              ),
              child: Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: isSmallScreen ? 32 : 40,
                  color: AppColors.muted,
                ),
              ),
            ),

          // Info & Buttons
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proof $proofIndex',
                            style: GoogleFonts.dmSans(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (hasCaptured)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: isSmallScreen ? 14 : 16,
                                  color: AppColors.successGreen,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Captured ✓',
                                    style: GoogleFonts.dmSans(
                                      fontSize: statusFontSize,
                                      color: AppColors.successGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Not captured',
                              style: GoogleFonts.dmSans(
                                fontSize: statusFontSize,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Progress badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasCaptured
                            ? AppColors.successGreen.withOpacity(0.1)
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasCaptured ? '$proofIndex/2' : '0/2',
                        style: GoogleFonts.dmSans(
                          fontSize: statusFontSize,
                          fontWeight: FontWeight.w700,
                          color: hasCaptured
                              ? AppColors.successGreen
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Retake button (only show if already captured)
                if (hasCaptured)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _captureImage(proofIndex),
                      icon: Icon(
                        Icons.camera_alt,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      label: Text(
                        'Capture',
                        style: GoogleFonts.dmSans(
                          fontSize: statusFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepRose,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 8 : 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
