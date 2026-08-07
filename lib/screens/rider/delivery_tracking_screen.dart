import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final RiderOrder order;
  const DeliveryTrackingScreen({super.key, required this.order});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _riderPosition;
  bool _loadingRoute = true;
  bool _markingDelivered = false;
  Timer? _positionTimer;

  LatLng? get _storeLocation {
    if (widget.order.storeLatitude != null && widget.order.storeLongitude != null) {
      return LatLng(widget.order.storeLatitude!, widget.order.storeLongitude!);
    }
    return null;
  }

  LatLng? get _customerLocation {
    if (widget.order.customerLatitude != null && widget.order.customerLongitude != null) {
      return LatLng(widget.order.customerLatitude!, widget.order.customerLongitude!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    final provider = context.read<RiderProvider>();

    // Get current rider location
    final pos = await provider.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _riderPosition = LatLng(pos.latitude, pos.longitude);
      });
    }

    // Start location tracking
    if (widget.order.status == 'on_delivery') {
      provider.startLocationTracking(widget.order.id);
      // Update rider position on screen periodically
      _positionTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final p = await provider.getCurrentLocation();
        if (p != null && mounted) {
          setState(() {
            _riderPosition = LatLng(p.latitude, p.longitude);
          });
          _fetchRoute();
        }
      });
    }

    // Fetch route
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final start = _riderPosition ?? _storeLocation;
    final end = _customerLocation;

    if (start == null || end == null) {
      setState(() => _loadingRoute = false);
      return;
    }

    final points = await RiderService.getRoute(
      start.latitude, start.longitude,
      end.latitude, end.longitude,
    );

    if (mounted) {
      setState(() {
        _loadingRoute = false;
        if (points != null) {
          _routePoints = points.map((p) => LatLng(p[0], p[1])).toList();
        }
      });
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
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Proofs captured successfully!', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
    final start = _riderPosition ?? _storeLocation;
    final end = _customerLocation;

    if (start == null || end == null) {
      showToast(context, 'Location data not available', isError: true);
      return;
    }

    // Animate map to fit both start and end points
    final bounds = LatLngBounds.fromPoints([start, end]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
    );

    // Show route info
    final distance = _calculateDistance(start, end);
    showToast(
      context,
      'Route to destination: ${distance.toStringAsFixed(1)} km',
      isError: false,
    );
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
    _positionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('Delivery #${widget.order.id}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_outlined, size: 20),
            onPressed: _openInMaps,
            tooltip: 'Open in Maps',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Map ──
          Expanded(
            flex: 3,
            child: _loadingRoute
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: AppColors.deepRose,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading route...',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 14,
                      onMapReady: () {
                        final b = _bounds;
                        if (b != null) {
                          _mapController.fitCamera(
                            CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(60)),
                          );
                        }
                      },
                    ),
                    children: [
                      // OpenStreetMap tile layer
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.eflowers.app',
                        maxZoom: 19,
                      ),

                      // Route polyline
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: AppColors.deepRose,
                              strokeWidth: 4,
                            ),
                          ],
                        ),

                      // Markers
                      MarkerLayer(
                        markers: [
                          // Store marker (pickup)
                          if (_storeLocation != null)
                            Marker(
                              point: _storeLocation!,
                              width: 44,
                              height: 44,
                              child: const _MapPin(
                                icon: Icons.store,
                                color: AppColors.sage,
                              ),
                            ),

                          // Customer marker (delivery)
                          if (_customerLocation != null)
                            Marker(
                              point: _customerLocation!,
                              width: 44,
                              height: 44,
                              child: const _MapPin(
                                icon: Icons.location_on,
                                color: AppColors.deepRose,
                              ),
                            ),

                          // Rider position
                          if (_riderPosition != null)
                            Marker(
                              point: _riderPosition!,
                              width: 44,
                              height: 44,
                              child: const _MapPin(
                                icon: Icons.delivery_dining,
                                color: Color(0xFF3498db),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ── Bottom Panel ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Legend
                    const Row(
                      children: [
                        _LegendDot(color: AppColors.sage, label: 'Store (Pickup)'),
                        SizedBox(width: 16),
                        _LegendDot(color: AppColors.deepRose, label: 'Customer'),
                        SizedBox(width: 16),
                        _LegendDot(color: Color(0xFF3498db), label: 'You'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Customer info
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.order.customerName ?? 'Customer',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        Text(
                          '₱${widget.order.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.order.deliveryAddress ?? 'No address',
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Actions
                    if (widget.order.status == 'on_delivery')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openInMaps,
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: const Text('Navigate'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _markingDelivered ? null : _markDelivered,
                              icon: _markingDelivered
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline, size: 18),
                              label: Text(_markingDelivered ? 'Updating' : 'Delivered'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),

                    if (widget.order.status == 'accepted')
                      SizedBox(
                        width: double.infinity,
                        child: _AcceptAndTrackButton(orderId: widget.order.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.muted),
        ),
      ],
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
    return ElevatedButton.icon(
      onPressed: _loading ? null : _accept,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.delivery_dining),
      label: Text(_loading ? 'Accepting...' : 'Accept & Start Delivery'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
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

  bool get _bothCaptured => _capturedImages[1] != null && _capturedImages[2] != null;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isExtraSmallScreen = screenSize.width < 320;
    
    // Responsive padding
    final horizontalPadding = isExtraSmallScreen ? 12.0 : isSmallScreen ? 16.0 : 20.0;
    
    // Responsive font sizes
    final headerFontSize = isExtraSmallScreen ? 20.0 : isSmallScreen ? 22.0 : 24.0;
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
                                ? () => Navigator.pop(context, _capturedImages.cast<int, String>())
                                : _captureSequence,
                        icon: _isCapturingSequence
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                _bothCaptured ? Icons.check : Icons.camera_alt,
                                size: isSmallScreen ? 16 : 18,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bothCaptured ? AppColors.successGreen : AppColors.deepRose,
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
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
                        color: hasCaptured ? AppColors.successGreen.withOpacity(0.1) : AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasCaptured ? '$proofIndex/2' : '0/2',
                        style: GoogleFonts.dmSans(
                          fontSize: statusFontSize,
                          fontWeight: FontWeight.w700,
                          color: hasCaptured ? AppColors.successGreen : AppColors.muted,
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
