import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/rider_service.dart';
import '../theme/app_theme.dart';

/// TikTok Shop-style live rider map. Compact on order details; tap to expand.
class LiveDeliveryMap extends StatefulWidget {
  final int orderId;
  final String? riderName;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<int?>? onEtaChanged;
  final VoidCallback? onChat;
  final bool compactHero;

  const LiveDeliveryMap({
    super.key,
    required this.orderId,
    this.riderName,
    this.onStatusChanged,
    this.onEtaChanged,
    this.onChat,
    this.compactHero = false,
  });

  @override
  State<LiveDeliveryMap> createState() => _LiveDeliveryMapState();
}

class _LiveDeliveryMapState extends State<LiveDeliveryMap> {
  final MapController _mapController = MapController();
  Timer? _poll;
  bool _mapReady = false;
  bool _fetchingRoute = false;
  bool _didInitialFit = false;

  LatLng? _rider;
  LatLng? _customer;
  LatLng? _store;
  List<LatLng> _route = [];
  int? _etaMin;
  bool _live = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final res = await ApiService.getOrderTracking(widget.orderId);
    if (!mounted || res.statusCode != 200 || res.data is! Map) return;
    final d = Map<String, dynamic>.from(res.data as Map);
    final live = d['live'] == true;
    final status = d['status']?.toString();
    if (status != null && status != _status) {
      _status = status;
      widget.onStatusChanged?.call(status);
    }

    LatLng? rider;
    final rLat = (d['rider_latitude'] as num?)?.toDouble();
    final rLng = (d['rider_longitude'] as num?)?.toDouble();
    if (rLat != null && rLng != null) rider = LatLng(rLat, rLng);

    LatLng? customer;
    final cLat = (d['customer_latitude'] as num?)?.toDouble();
    final cLng = (d['customer_longitude'] as num?)?.toDouble();
    if (cLat != null && cLng != null) customer = LatLng(cLat, cLng);

    LatLng? store;
    final sLat = (d['store_latitude'] as num?)?.toDouble();
    final sLng = (d['store_longitude'] as num?)?.toDouble();
    if (sLat != null && sLng != null) store = LatLng(sLat, sLng);

    final moved = rider != null &&
        (_rider == null || _haversineKm(_rider!, rider) * 1000 >= 20);

    setState(() {
      _live = live;
      _rider = rider ?? _rider;
      _customer = customer ?? _customer;
      _store = store ?? _store;
    });

    if (!live) {
      _poll?.cancel();
      return;
    }

    if (moved ||
        (_route.isEmpty && (_rider ?? _store) != null && _customer != null)) {
      await _fetchRoute();
    }
    if (!_didInitialFit) _fitIfReady();
  }

  Future<void> _fetchRoute() async {
    if (_fetchingRoute) return;
    final start = _rider ?? _store;
    final end = _customer;
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
        _route = info.points.map((p) => LatLng(p[0], p[1])).toList();
        if (info.durationSec != null) {
          _etaMin = math.max(1, (info.durationSec! / 60).round());
          widget.onEtaChanged?.call(_etaMin);
        }
      });
    } finally {
      _fetchingRoute = false;
    }
  }

  void _fitIfReady({bool force = false, MapController? controller}) {
    final map = controller ?? _mapController;
    if (controller == null && !_mapReady) return;
    if (controller == null && _didInitialFit && !force) return;
    final points = <LatLng>[
      if (_rider != null) _rider!,
      if (_customer != null) _customer!,
      if (_store != null && _rider == null) _store!,
    ];
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        map.move(points.first, 15);
      } else {
        map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(56, 88, 56, 120),
          ),
        );
      }
      if (controller == null) _didInitialFit = true;
    } catch (_) {}
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(x));
  }

  LatLng get _center =>
      _rider ?? _customer ?? _store ?? const LatLng(14.2691, 121.4113);

  Future<void> _expand() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _ExpandedDeliveryMapPage(
          orderId: widget.orderId,
          riderName: widget.riderName,
          rider: _rider,
          customer: _customer,
          store: _store,
          route: _route,
          etaMin: _etaMin,
          onChat: widget.onChat,
          onStatusChanged: widget.onStatusChanged,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_live && _status != null && _status != 'on_delivery') {
      return const SizedBox.shrink();
    }

    final waiting = _rider == null;
    if (widget.compactHero) {
      return SizedBox(
        height: 236,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: _MapCanvas(
                mapController: _mapController,
                center: _center,
                interactive: false,
                route: _route,
                rider: _rider,
                customer: _customer,
                store: _store,
                onReady: () {
                  _mapReady = true;
                  _fitIfReady();
                },
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x3A2C2520),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xCCFAF6F0),
                  ],
                  stops: [0, 0.22, 0.58, 1],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _expand,
                splashColor: const Color(0x22F2C4CE),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: _LiveChip(waiting: waiting),
            ),
            Positioned(
              top: 6,
              right: 12,
              child: _RoundIconButton(
                icon: Icons.open_in_full_rounded,
                tooltip: 'Expand map',
                onTap: _expand,
              ),
            ),
            if (_etaMin != null && !waiting)
              Positioned(
                left: 16,
                bottom: 36,
                child: _EtaPill(minutes: _etaMin!),
              ),
          ],
        ),
      );
    }

    final height = (MediaQuery.sizeOf(context).height * 0.42).clamp(320.0, 420.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _expand,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: _MapCanvas(
                    mapController: _mapController,
                    center: _center,
                    interactive: false,
                    route: _route,
                    rider: _rider,
                    customer: _customer,
                    store: _store,
                    onReady: () {
                      _mapReady = true;
                      _fitIfReady();
                    },
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x66000000),
                      ],
                      stops: [0, 0.18, 0.52, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: _LiveChip(waiting: waiting),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _RoundIconButton(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Expand map',
                    onTap: _expand,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _EtaBar(
                    riderName: widget.riderName,
                    waiting: waiting,
                    etaMin: _etaMin,
                    compact: true,
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

class _ExpandedDeliveryMapPage extends StatefulWidget {
  final int orderId;
  final String? riderName;
  final LatLng? rider;
  final LatLng? customer;
  final LatLng? store;
  final List<LatLng> route;
  final int? etaMin;
  final VoidCallback? onChat;
  final ValueChanged<String>? onStatusChanged;

  const _ExpandedDeliveryMapPage({
    required this.orderId,
    this.riderName,
    this.rider,
    this.customer,
    this.store,
    this.route = const [],
    this.etaMin,
    this.onChat,
    this.onStatusChanged,
  });

  @override
  State<_ExpandedDeliveryMapPage> createState() =>
      _ExpandedDeliveryMapPageState();
}

class _ExpandedDeliveryMapPageState extends State<_ExpandedDeliveryMapPage> {
  final MapController _mapController = MapController();
  Timer? _poll;
  bool _mapReady = false;
  bool _fetchingRoute = false;

  late LatLng? _rider;
  late LatLng? _customer;
  late LatLng? _store;
  late List<LatLng> _route;
  late int? _etaMin;

  @override
  void initState() {
    super.initState();
    _rider = widget.rider;
    _customer = widget.customer;
    _store = widget.store;
    _route = List<LatLng>.from(widget.route);
    _etaMin = widget.etaMin;
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final res = await ApiService.getOrderTracking(widget.orderId);
    if (!mounted || res.statusCode != 200 || res.data is! Map) return;
    final d = Map<String, dynamic>.from(res.data as Map);
    final status = d['status']?.toString();
    if (status != null) widget.onStatusChanged?.call(status);
    if (d['live'] != true) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    LatLng? rider;
    final rLat = (d['rider_latitude'] as num?)?.toDouble();
    final rLng = (d['rider_longitude'] as num?)?.toDouble();
    if (rLat != null && rLng != null) rider = LatLng(rLat, rLng);
    LatLng? customer;
    final cLat = (d['customer_latitude'] as num?)?.toDouble();
    final cLng = (d['customer_longitude'] as num?)?.toDouble();
    if (cLat != null && cLng != null) customer = LatLng(cLat, cLng);
    LatLng? store;
    final sLat = (d['store_latitude'] as num?)?.toDouble();
    final sLng = (d['store_longitude'] as num?)?.toDouble();
    if (sLat != null && sLng != null) store = LatLng(sLat, sLng);

    final moved = rider != null &&
        (_rider == null ||
            _haversineKm(_rider!, rider) * 1000 >= 20);

    setState(() {
      _rider = rider ?? _rider;
      _customer = customer ?? _customer;
      _store = store ?? _store;
    });

    if (moved ||
        (_route.isEmpty && (_rider ?? _store) != null && _customer != null)) {
      await _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    if (_fetchingRoute) return;
    final start = _rider ?? _store;
    final end = _customer;
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
        _route = info.points.map((p) => LatLng(p[0], p[1])).toList();
        if (info.durationSec != null) {
          _etaMin = math.max(1, (info.durationSec! / 60).round());
        }
      });
    } finally {
      _fetchingRoute = false;
    }
  }

  void _fit() {
    if (!_mapReady) return;
    final points = <LatLng>[
      if (_rider != null) _rider!,
      if (_customer != null) _customer!,
      if (_store != null && _rider == null) _store!,
    ];
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _mapController.move(points.first, 15);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(48, 100, 48, 180),
          ),
        );
      }
    } catch (_) {}
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.asin(math.sqrt(x));
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _rider == null;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _MapCanvas(
            mapController: _mapController,
            center: _rider ??
                _customer ??
                _store ??
                const LatLng(14.2691, 121.4113),
            interactive: true,
            route: _route,
            rider: _rider,
            customer: _customer,
            store: _store,
            onReady: () {
              _mapReady = true;
              _fit();
            },
          ),
          Positioned(
            top: top + 8,
            left: 12,
            child: _RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: top + 8,
            right: 12,
            child: _RoundIconButton(
              icon: Icons.my_location_rounded,
              tooltip: 'Recenter',
              onTap: _fit,
            ),
          ),
          Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _LiveChip(waiting: waiting)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _EtaBar(
                  riderName: widget.riderName,
                  waiting: waiting,
                  etaMin: _etaMin,
                  compact: false,
                  onChat: widget.onChat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final bool interactive;
  final List<LatLng> route;
  final LatLng? rider;
  final LatLng? customer;
  final LatLng? store;
  final VoidCallback onReady;

  const _MapCanvas({
    required this.mapController,
    required this.center,
    required this.interactive,
    required this.route,
    required this.rider,
    required this.customer,
    required this.store,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.5,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onMapReady: onReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.seanlazala.eflora',
          maxZoom: 19,
        ),
        if (route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                color: AppColors.blush,
                strokeWidth: 9,
              ),
              Polyline(
                points: route,
                color: AppColors.roseCta,
                strokeWidth: 4.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (store != null)
              Marker(
                point: store!,
                width: 44,
                height: 44,
                child: const _ShopPin(),
              ),
            if (customer != null)
              Marker(
                point: customer!,
                width: 52,
                height: 58,
                alignment: Alignment.topCenter,
                child: const _HomePin(),
              ),
            if (rider != null)
              Marker(
                point: rider!,
                width: 56,
                height: 56,
                child: const _RiderPin(),
              ),
          ],
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  final bool waiting;
  const _LiveChip({required this.waiting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.deepRose.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
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
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 18, color: AppColors.deepRose),
          ),
        ),
      ),
    );
  }
}

class _EtaBar extends StatelessWidget {
  final String? riderName;
  final bool waiting;
  final int? etaMin;
  final bool compact;
  final VoidCallback? onChat;

  const _EtaBar({
    required this.riderName,
    required this.waiting,
    required this.etaMin,
    required this.compact,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final title = waiting
        ? 'Rider is heading out'
        : (etaMin != null ? 'Arriving in $etaMin min' : 'Rider is on the way');
    final subtitle = waiting
        ? 'Waiting for live location'
        : (riderName != null && riderName!.trim().isNotEmpty
            ? riderName!
            : 'Your order is on the way');

    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 12 : 16, 14, compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const _RiderAvatar(),
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
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  compact ? 'Tap to expand map  ·  $subtitle' : subtitle,
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
          if (etaMin != null && !waiting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          if (onChat != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onChat,
              tooltip: 'Chat with rider',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.blush.withOpacity(0.45),
                foregroundColor: AppColors.deepRose,
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _EtaPill extends StatelessWidget {
  final int minutes;
  const _EtaPill({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: AppColors.badgeGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseCta.withOpacity(0.28),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        '$minutes min away',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RiderAvatar extends StatelessWidget {
  const _RiderAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseCta.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
    );
  }
}

class _RiderPin extends StatelessWidget {
  const _RiderPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseCta.withOpacity(0.5),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 26),
    );
  }
}

class _HomePin extends StatelessWidget {
  const _HomePin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.deepRose,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
        ),
        Container(
          width: 2,
          height: 8,
          color: AppColors.deepRose,
        ),
      ],
    );
  }
}

class _ShopPin extends StatelessWidget {
  const _ShopPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: const Icon(Icons.storefront, color: Colors.white, size: 18),
    );
  }
}
