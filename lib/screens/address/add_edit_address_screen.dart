import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import '../../config/mapbox_config.dart';
import '../../models/checkout.dart';
import '../../providers/address_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/glass.dart';

String _normalizeAddressMatch(String? value) {
  var s = (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[ñ]'), 'n');
  s = s.replaceAll(
    RegExp(r'\b(barangay|brgy\.?|city of|city|municipality of|municipality)\b'),
    ' ',
  );
  s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _streetNameCore(String street) {
  return _normalizeAddressMatch(
    street.replaceAll(
      RegExp(
        r'\b(street|st|road|rd|avenue|ave|blvd|boulevard|drive|dr|lane|ln|highway|hwy)\b',
        caseSensitive: false,
      ),
      ' ',
    ),
  );
}

String _stripStreetFromAddress(String haystack, String street) {
  var h = haystack;
  final streetNorm = street.trim();
  if (streetNorm.isNotEmpty) {
    h = h.replaceAll(RegExp(RegExp.escape(streetNorm), caseSensitive: false), ' ');
    final core = streetNorm
        .replaceAll(
          RegExp(
            r'\b(street|st|road|rd|avenue|ave|blvd|boulevard|drive|dr|lane|ln|highway|hwy)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .trim();
    if (core.isNotEmpty) {
      h = h.replaceAll(RegExp('\\b${RegExp.escape(core)}\\b', caseSensitive: false), ' ');
    }
  }
  return h;
}

String? _bestAddressMatch(String haystack, List<String> options) {
  final h = _normalizeAddressMatch(haystack);
  if (h.isEmpty || options.isEmpty) return null;

  String? best;
  var bestLen = -1;
  for (final option in options) {
    final n = _normalizeAddressMatch(option);
    if (n.isEmpty) continue;
    final isWord = h == n || RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(h);
    if (!isWord) continue;
    if (n.length > bestLen) {
      best = option;
      bestLen = n.length;
    }
  }
  return best;
}

String? _matchMunicipality({
  required String? geocodedMunicipality,
  required String formattedAddress,
  required String context,
  required String street,
  required List<String> municipalities,
}) {
  final areaText = _stripStreetFromAddress(
    [formattedAddress, context].where((e) => e.trim().isNotEmpty).join(', '),
    street,
  );
  final fromArea = _bestAddressMatch(areaText, municipalities);
  if (fromArea != null) return fromArea;

  final geo = (geocodedMunicipality ?? '').trim();
  if (geo.isNotEmpty && _normalizeAddressMatch(geo) == _streetNameCore(street)) {
    return null;
  }
  return _bestAddressMatch(geo, municipalities);
}

/// Grab / Foodpanda–style address form: map-first pin, auto current location,
/// compact tappable city/barangay rows (iOS wheel pickers), theme-aligned.
class AddEditAddressScreen extends StatefulWidget {
  final Address? address; // null = adding new, non-null = editing

  const AddEditAddressScreen({
    super.key,
    this.address,
  });

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  late TextEditingController _streetController;
  late TextEditingController _buildingDetailsController;
  late String _addressLabel;
  late bool _isDefault;

  String? _selectedMunicipality;
  String? _selectedBarangay;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedPlaceId;

  List<String> _barangays = [];
  bool _isLoadingBarangays = false;
  bool _isSaving = false;
  bool _isLocating = false;
  bool _isReverseGeocoding = false;
  bool _didAutoLocate = false;
  bool _mapReady = false;

  final MapController _mapController = MapController();
  late final MapOptions _mapOptions;

  late TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  late Debouncer<String> _searchDebouncer;
  final FocusNode _searchFocusNode = FocusNode();

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchDebouncer = Debouncer<String>(
      const Duration(milliseconds: 300),
      initialValue: '',
      onChanged: (query) {
        if (!mounted) return;
        if (query.isNotEmpty) {
          _searchPlaces(query);
        } else {
          setState(() => _searchResults = []);
        }
      },
    );

    if (_isEditing) {
      final a = widget.address!;
      _streetController = TextEditingController(text: a.street);
      _buildingDetailsController = TextEditingController(text: a.buildingDetails);
      _addressLabel = a.addressLabel;
      _isDefault = a.isDefault;
      _selectedMunicipality = a.municipality;
      _selectedBarangay = a.barangay;
      _selectedLatitude = a.latitude;
      _selectedLongitude = a.longitude;
      _selectedPlaceId = a.placeId;
    } else {
      _streetController = TextEditingController();
      _buildingDetailsController = TextEditingController();
      _addressLabel = 'Home';
      _isDefault = false;
      _selectedLatitude = 14.1694;
      _selectedLongitude = 121.2934;
    }

    _mapOptions = MapOptions(
      initialCenter: LatLng(
        _selectedLatitude ?? 14.1694,
        _selectedLongitude ?? 121.2934,
      ),
      initialZoom: _isEditing ? 16 : 15,
      keepAlive: true,
      onMapReady: () {
        if (!mounted) return;
        _mapReady = true;
      },
      onTap: _onMapTap,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!mounted) return;
    setState(() {
      _selectedLatitude = point.latitude;
      _selectedLongitude = point.longitude;
    });
    _reverseGeocodeAndFill(point.latitude, point.longitude);
  }

  void _moveMap(double lat, double lng, double zoom) {
    if (!mounted) return;
    if (!_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        try {
          _mapController.move(LatLng(lat, lng), zoom);
        } catch (_) {}
      });
      return;
    }
    try {
      _mapController.move(LatLng(lat, lng), zoom);
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    final provider = context.read<AddressProvider>();
    if (provider.municipalities.isEmpty) {
      await provider.loadMunicipalities();
    }
    if (!mounted) return;

    if (_isEditing && _selectedMunicipality != null) {
      await _loadBarangays(
        _selectedMunicipality!,
        moveMap: false,
        preferredBarangay: _selectedBarangay,
      );
      return;
    }

    // New address: pin + fill from current GPS location.
    if (!_didAutoLocate) {
      _didAutoLocate = true;
      await _goToMyLocation(showErrors: false);
    }
  }

  @override
  void dispose() {
    _searchDebouncer.cancel();
    _streetController.dispose();
    _buildingDetailsController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _formatAddressLine() {
    final parts = <String>[];
    if (_buildingDetailsController.text.trim().isNotEmpty) {
      parts.add(_buildingDetailsController.text.trim());
    }
    if (_streetController.text.trim().isNotEmpty) {
      parts.add(_streetController.text.trim());
    }
    if (_selectedBarangay != null) parts.add(_selectedBarangay!);
    if (_selectedMunicipality != null) parts.add(_selectedMunicipality!);
    return parts.join(', ');
  }

  Future<void> _loadBarangays(
    String municipality, {
    bool moveMap = true,
    String? preferredBarangay,
  }) async {
    setState(() => _isLoadingBarangays = true);

    final addressProvider = context.read<AddressProvider>();
    await addressProvider.loadBarangays(municipality);
    if (!mounted) return;

    final list = addressProvider.barangays;
    String? nextBarangay;
    if (preferredBarangay != null) {
      nextBarangay = _bestMatch(preferredBarangay, list) ??
          (list.contains(preferredBarangay) ? preferredBarangay : null);
    }
    nextBarangay ??= _selectedBarangay != null
        ? (_bestMatch(_selectedBarangay!, list) ??
            (list.contains(_selectedBarangay) ? _selectedBarangay : null))
        : null;

    double? movedLat;
    double? movedLng;

    setState(() {
      _barangays = list;
      _selectedBarangay = nextBarangay;
      _isLoadingBarangays = false;

      if (moveMap &&
          addressProvider.barangayLat != null &&
          addressProvider.barangayLng != null) {
        _selectedLatitude = addressProvider.barangayLat;
        _selectedLongitude = addressProvider.barangayLng;
        movedLat = addressProvider.barangayLat;
        movedLng = addressProvider.barangayLng;
        final lat = movedLat!;
        final lng = movedLng!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveMap(lat, lng, 14);
        });
      }
    });

    // Refresh street from the new pin (keep selected city/barangay).
    if (movedLat != null && movedLng != null) {
      await _reverseGeocodeAndFill(
        movedLat!,
        movedLng!,
        syncArea: false,
        overwriteStreet: true,
      );
    }
  }

  String? _bestMatch(String haystack, List<String> options) =>
      _bestAddressMatch(haystack, options);

  /// Reverse-geocode a map pin.
  ///
  /// [syncArea] updates municipality/barangay (pin drag / current location).
  /// When false (dropdown-driven pin moves), keeps the user's city/barangay and
  /// only refreshes the street field.
  Future<void> _reverseGeocodeAndFill(
    double lat,
    double lng, {
    bool syncArea = true,
    bool overwriteStreet = true,
  }) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final result = await context.read<AddressProvider>().googleReverseGeocode(lat, lng);
      if (!mounted) return;

      Map<String, dynamic>? data;
      result.when(
        success: (payload) => data = payload,
        error: (message, _) {
          if (kDebugMode) print('Reverse geocoding failed: $message');
        },
      );
      if (data == null) return;

      final placeId = data!['place_id']?.toString();
      if (placeId != null && placeId.isNotEmpty) {
        _selectedPlaceId = placeId;
      }

      final streetCandidate = (data!['street']?.toString() ?? '').trim();
      final formatted = (data!['formatted_address']?.toString() ?? '').trim();
      final geoContext = (data!['context']?.toString() ?? '').trim();
      final geoMunicipality = (data!['municipality']?.toString() ?? '').trim();
      final geoBarangay = (data!['barangay']?.toString() ?? '').trim();
      final areaText = _stripStreetFromAddress(
        [formatted, geoContext, geoMunicipality, geoBarangay]
            .where((e) => e.trim().isNotEmpty)
            .join(', '),
        streetCandidate,
      );

      if (overwriteStreet) {
        _streetController.text = streetCandidate.isNotEmpty
            ? streetCandidate
            : (formatted.split(',').first.trim());
      } else if (streetCandidate.isNotEmpty && _streetController.text.trim().isEmpty) {
        _streetController.text = streetCandidate;
      }

      if (!syncArea) {
        if (mounted) setState(() {});
        return;
      }

      final municipalities = context.read<AddressProvider>().municipalities;
      final matchedMunicipality = _matchMunicipality(
        geocodedMunicipality: geoMunicipality,
        formattedAddress: formatted,
        context: geoContext,
        street: streetCandidate,
        municipalities: municipalities,
      );

      if (matchedMunicipality != null) {
        final municipalityChanged = matchedMunicipality != _selectedMunicipality;
        setState(() => _selectedMunicipality = matchedMunicipality);

        if (municipalityChanged || _barangays.isEmpty) {
          await _loadBarangays(matchedMunicipality, moveMap: false);
        }
        if (!mounted) return;

        final matchedBarangay = _bestMatch(geoBarangay, _barangays) ??
            _bestMatch(areaText, _barangays);
        if (matchedBarangay != null) {
          setState(() => _selectedBarangay = matchedBarangay);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Reverse geocoding failed: $e');
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  /// Geocode barangay (like web handleBarangayChange) and move the pin.
  Future<void> _geocodeBarangay(String barangay) async {
    if (barangay.isEmpty || _selectedMunicipality == null) return;

    try {
      final query = '$barangay, $_selectedMunicipality, Laguna, Philippines';
      final result = await context.read<AddressProvider>().googlePlaceSearch(query);
      if (!mounted) return;

      List<Map<String, dynamic>> hits = [];
      result.when(
        success: (rows) => hits = rows,
        error: (message, _) {
          if (kDebugMode) print('Barangay geocoding failed: $message');
        },
      );
      if (hits.isEmpty) return;

      final feature = hits.first;
      final lat = (feature['lat'] as num?)?.toDouble();
      final lng = (feature['lng'] as num?)?.toDouble();

      if (lat != null && lng != null && mounted) {
        setState(() {
          _selectedLatitude = lat;
          _selectedLongitude = lng;
          _selectedPlaceId = feature['place_id']?.toString();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveMap(lat, lng, 15);
        });
        await _reverseGeocodeAndFill(
          lat,
          lng,
          syncArea: false,
          overwriteStreet: true,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Barangay geocoding failed: $e');
    }
  }

  Future<void> _goToMyLocation({bool showErrors = true}) async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLocating = false);
        if (showErrors) {
          showToast(
            context,
            'Turn on location services to use your current position',
            isError: true,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLocating = false);
        if (showErrors) {
          showToast(
            context,
            'Location permission is required to find your position',
            isError: true,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _isLocating = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveMap(position.latitude, position.longitude, 17);
      });
      await _reverseGeocodeAndFill(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      if (showErrors) {
        showToast(context, 'Could not get location: $e', isError: true);
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await context.read<AddressProvider>().googlePlaceSearch(query);
      if (!mounted) return;
      result.when(
        success: (rows) {
          setState(() {
            _searchResults = rows
                .map((feature) => {
                      'name': feature['name'] ?? 'Unknown',
                      'lat': (feature['lat'] as num?)?.toDouble() ?? 0.0,
                      'lng': (feature['lng'] as num?)?.toDouble() ?? 0.0,
                      'place_id': feature['place_id'],
                    })
                .toList();
          });
        },
        error: (_, __) {
          setState(() => _searchResults = []);
        },
      );
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();
    setState(() {
      _selectedLatitude = lat;
      _selectedLongitude = lng;
      _selectedPlaceId = place['place_id']?.toString();
      _searchResults = [];
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveMap(lat, lng, 16);
    });
    _reverseGeocodeAndFill(lat, lng);
  }

  Future<void> _saveAddress() async {
    if (_selectedMunicipality == null || _selectedBarangay == null) {
      showToast(context, 'Please select municipality and barangay', isError: true);
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      showToast(context, 'Please pin your exact location on the map', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final addressLine = _formatAddressLine();
    final addressProvider = context.read<AddressProvider>();

    try {
      if (!_isEditing) {
        if (addressProvider.addresses.length >= AddressProvider.maxAddresses) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          showToast(
            context,
            AddressProvider.addressLimitMessage,
            isError: true,
          );
          return;
        }
        final added = await addressProvider.addAddress(
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty
              ? _buildingDetailsController.text
              : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        );
        if (!added) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          showToast(
            context,
            addressProvider.error ?? AddressProvider.addressLimitMessage,
            isError: true,
          );
          return;
        }
      } else {
        await addressProvider.updateAddress(
          widget.address!.id!,
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty
              ? _buildingDetailsController.text
              : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      showToast(
        context,
        !_isEditing ? 'Address added' : 'Address updated',
      );

      Navigator.of(context).pop(
        Address(
          id: widget.address?.id,
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          addressLine: addressLine,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty
              ? _buildingDetailsController.text
              : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showToast(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _openPicker({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) async {
    if (options.isEmpty || !mounted) return;

    // Let the tap gesture finish before pushing a route (avoids wrong build scope).
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final result = await showIosWheelPicker(
      context: context,
      title: title,
      options: List<String>.from(options),
      selected: selected,
    );

    if (!mounted || result == null) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    onSelected(result);
  }

  Future<void> _expandAddressMap() async {
    final lat = _selectedLatitude ?? 14.1694;
    final lng = _selectedLongitude ?? 121.2934;
    final result = await Navigator.of(context).push<_ExpandedPinResult>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _ExpandedAddressMapPage(
          latitude: lat,
          longitude: lng,
          street: _streetController.text.trim(),
          barangay: _selectedBarangay,
          municipality: _selectedMunicipality,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      if (result.placeId != null && result.placeId!.isNotEmpty) {
        _selectedPlaceId = result.placeId;
      }
      if (result.street != null && result.street!.trim().isNotEmpty) {
        _streetController.text = result.street!.trim();
      }
      if (result.municipality != null && result.municipality!.isNotEmpty) {
        _selectedMunicipality = result.municipality;
      }
      if (result.barangay != null && result.barangay!.isNotEmpty) {
        _selectedBarangay = result.barangay;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveMap(result.latitude, result.longitude, 16);
    });
    if (result.municipality != null && result.municipality!.isNotEmpty) {
      await _loadBarangays(
        result.municipality!,
        moveMap: false,
        preferredBarangay: result.barangay,
      );
    } else {
      await _reverseGeocodeAndFill(result.latitude, result.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppColors.pageCream,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Address' : 'Add Address',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
      ),
      body: AppBackground(
        child: Column(
          children: [
            // Sibling of Consumer — Provider updates must not rebuild the map.
            _PinnedMapBox(
              latitude: _selectedLatitude,
              longitude: _selectedLongitude,
              isLocating: _isLocating,
              isReverseGeocoding: _isReverseGeocoding,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchResults: _searchResults,
              isSearching: _isSearching,
              onSearchChanged: (query) {
                setState(() {});
                _searchDebouncer.value = query;
              },
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              },
              onSelectPlace: _selectPlace,
              onUseMyLocation: () => _goToMyLocation(),
              onExpand: _expandAddressMap,
              mapController: _mapController,
              mapOptions: _mapOptions,
            ),
            Expanded(
              child: Consumer<AddressProvider>(
                builder: (context, addressProvider, _) {
                  if (addressProvider.isMunicipalitiesLoading &&
                      addressProvider.municipalities.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.deepRose),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    children: [
                      _buildUseCurrentLocationButton(),
                      const SizedBox(height: 14),
                      _buildDetectedSummaryCard(),
                      const SizedBox(height: 14),
                      _buildLabelChips(),
                      const SizedBox(height: 14),
                      _buildCompactField(
                        label: 'House / Unit / Landmark',
                        controller: _buildingDetailsController,
                        hint: 'e.g. Unit 3B, near sari-sari',
                        icon: Icons.home_work_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildCompactField(
                        label: 'Street',
                        controller: _streetController,
                        hint: 'Street name',
                        icon: Icons.signpost_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildSelectRow(
                        label: 'City / Municipality',
                        value: _selectedMunicipality,
                        placeholder: 'Select city',
                        required: true,
                        onTap: () => _openPicker(
                          title: 'City / Municipality',
                          options: List<String>.from(addressProvider.municipalities),
                          selected: _selectedMunicipality,
                          onSelected: (value) async {
                            setState(() {
                              _selectedMunicipality = value;
                              _selectedBarangay = null;
                              _barangays = [];
                            });
                            // Same as web loadBarangays(): recenter map on city coords.
                            await _loadBarangays(value, moveMap: true);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSelectRow(
                        label: 'Barangay',
                        value: _selectedBarangay,
                        placeholder: _selectedMunicipality == null
                            ? 'Select city first'
                            : (_isLoadingBarangays ? 'Loading…' : 'Select barangay'),
                        required: true,
                        loading: _isLoadingBarangays,
                        enabled: _selectedMunicipality != null &&
                            !_isLoadingBarangays &&
                            _barangays.isNotEmpty,
                        onTap: () => _openPicker(
                          title: 'Barangay',
                          options: List<String>.from(_barangays),
                          selected: _selectedBarangay,
                          onSelected: (value) {
                            setState(() => _selectedBarangay = value);
                            // Same as web handleBarangayChange(): geocode + move pin.
                            _geocodeBarangay(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDefaultToggle(),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
            _buildBottomBar(bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCurrentLocationButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLocating ? null : () => _goToMyLocation(),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.roseButton,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLocating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  _isLocating ? 'Getting your location…' : 'Use my current location',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
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

  Widget _buildDetectedSummaryCard() {
    final hasArea = _selectedMunicipality != null || _selectedBarangay != null;
    final line = _formatAddressLine();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.deepRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.deepRose, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasArea
                      ? [
                          if (_selectedBarangay != null) _selectedBarangay!,
                          if (_selectedMunicipality != null) _selectedMunicipality!,
                        ].join(', ')
                      : 'Move the pin or use current location',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  line.isNotEmpty
                      ? line
                      : 'Street and house details will fill in automatically when possible',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LABEL',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in const ['Home', 'Work', 'Other']) ...[
              Expanded(child: _labelChip(label)),
              if (label != 'Other') const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _labelChip(String label) {
    final selected = _addressLabel == label;
    final icon = label == 'Home'
        ? Icons.home_rounded
        : label == 'Work'
            ? Icons.work_rounded
            : Icons.bookmark_rounded;

    return GestureDetector(
      onTap: () => setState(() => _addressLabel = label),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.borderStrong,
          ),
          boxShadow: selected ? AppShadows.roseButton : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.muted,
            ),
          ),
          TextField(
            controller: controller,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.charcoal),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.muted.withValues(alpha: 0.7)),
              prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectRow({
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    bool required = false,
    bool enabled = true,
    bool loading = false,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: AppRadius.md,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: label.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.muted,
                          ),
                          children: required
                              ? [
                                  TextSpan(
                                    text: ' *',
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.deepRose,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value ?? placeholder,
                        style: GoogleFonts.dmSans(
                          fontSize: 14.5,
                          fontWeight: value != null ? FontWeight.w600 : FontWeight.w500,
                          color: value != null ? AppColors.charcoal : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
                  )
                else
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultToggle() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      radius: AppRadius.md,
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: _isDefault,
        onChanged: (v) => setState(() => _isDefault = v),
        activeTrackColor: AppColors.deepRose.withValues(alpha: 0.45),
        activeThumbColor: AppColors.deepRose,
        title: Text(
          'Set as default address',
          style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        ),
        subtitle: Text(
          'Used first at checkout',
          style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _buildBottomBar(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.warmWhite.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.roseButton,
          ),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isEditing ? 'Update Address' : 'Save Address',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Map + search chrome. Stable [MapOptions] so parent rebuilds do not reset the map.
class _PinnedMapBox extends StatefulWidget {
  const _PinnedMapBox({
    required this.latitude,
    required this.longitude,
    required this.isLocating,
    required this.isReverseGeocoding,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResults,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectPlace,
    required this.onUseMyLocation,
    required this.onExpand,
    required this.mapController,
    required this.mapOptions,
  });

  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final bool isReverseGeocoding;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<Map<String, dynamic>> onSelectPlace;
  final VoidCallback onUseMyLocation;
  final VoidCallback onExpand;
  final MapController mapController;
  final MapOptions mapOptions;

  @override
  State<_PinnedMapBox> createState() => _PinnedMapBoxState();
}

class _PinnedMapBoxState extends State<_PinnedMapBox> {
  String? _tileUrl;
  bool _isMapbox = false;

  @override
  void initState() {
    super.initState();
    _loadTiles();
  }

  Future<void> _loadTiles() async {
    final token = await MapboxConfig.publicToken();
    if (!mounted) return;
    setState(() {
      _isMapbox = token.isNotEmpty;
      _tileUrl = MapboxConfig.rasterTileUrl(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude ?? 14.1694;
    final lng = widget.longitude ?? 121.2934;
    final tileUrl = _tileUrl ?? MapboxConfig.rasterTileUrl('');

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          FlutterMap(
            key: const ValueKey('pinned-address-map'),
            mapController: widget.mapController,
            options: widget.mapOptions,
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.seanlazala.eflora',
                maxZoom: _isMapbox ? 22 : 19,
                errorTileCallback: (tile, error, stackTrace) {},
              ),
              if (widget.latitude != null && widget.longitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.deepRose,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              if (_isMapbox)
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© Mapbox'),
                    TextSourceAttribution('© OpenStreetMap'),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.pageCream.withValues(alpha: 0),
                      AppColors.pageCream,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 2,
                  shadowColor: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.warmWhite.withValues(alpha: 0.96),
                  child: TextField(
                    controller: widget.searchController,
                    focusNode: widget.searchFocusNode,
                    onChanged: widget.onSearchChanged,
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'Search street, landmark…',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13.5),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                      suffixIcon: widget.isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.deepRose,
                                ),
                              ),
                            )
                          : widget.searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18, color: AppColors.muted),
                                  onPressed: widget.onClearSearch,
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (widget.searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppColors.warmWhite,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: widget.searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 48),
                      itemBuilder: (context, index) {
                        final place = widget.searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.deepRose, size: 20),
                          title: Text(
                            place['name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                                fontSize: 12.5, color: AppColors.charcoal),
                          ),
                          onTap: () => widget.onSelectPlace(place),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 80,
            child: Material(
              color: AppColors.warmWhite,
              elevation: 3,
              shadowColor: const Color(0x33000000),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.isLocating ? null : widget.onUseMyLocation,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: widget.isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.deepRose,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded,
                            color: AppColors.deepRose, size: 22),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 28,
            child: Material(
              color: AppColors.warmWhite,
              elevation: 3,
              shadowColor: const Color(0x33000000),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onExpand,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.open_in_full_rounded,
                      color: AppColors.deepRose, size: 20),
                ),
              ),
            ),
          ),
          if (widget.isReverseGeocoding)
            Positioned(
              left: 12,
              bottom: 28,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                radius: AppRadius.pill,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.deepRose),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detecting address…',
                      style: GoogleFonts.dmSans(
                          fontSize: 11.5, color: AppColors.charcoal),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandedPinResult {
  const _ExpandedPinResult({
    required this.latitude,
    required this.longitude,
    this.street,
    this.barangay,
    this.municipality,
    this.placeId,
  });

  final double latitude;
  final double longitude;
  final String? street;
  final String? barangay;
  final String? municipality;
  final String? placeId;
}

class _ExpandedAddressMapPage extends StatefulWidget {
  const _ExpandedAddressMapPage({
    required this.latitude,
    required this.longitude,
    this.street,
    this.barangay,
    this.municipality,
  });

  final double latitude;
  final double longitude;
  final String? street;
  final String? barangay;
  final String? municipality;

  @override
  State<_ExpandedAddressMapPage> createState() => _ExpandedAddressMapPageState();
}

class _ExpandedAddressMapPageState extends State<_ExpandedAddressMapPage> {
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  late final Debouncer<String> _searchDebouncer;
  final FocusNode _searchFocusNode = FocusNode();

  late double _lat;
  late double _lng;
  bool _mapReady = false;
  bool _isLocating = false;
  String? _tileUrl;
  bool _isMapbox = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _resolving = false;
  int _geoSeq = 0;
  String? _street;
  String? _barangay;
  String? _municipality;
  String? _placeId;
  List<String> _barangays = [];
  bool _loadingBarangays = false;
  bool _lockArea = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.latitude;
    _lng = widget.longitude;
    _street = widget.street;
    _barangay = widget.barangay;
    _municipality = widget.municipality;
    _searchController = TextEditingController();
    _searchDebouncer = Debouncer<String>(
      const Duration(milliseconds: 300),
      initialValue: '',
      onChanged: (query) {
        if (!mounted) return;
        if (query.isNotEmpty) {
          _searchPlaces(query);
        } else {
          setState(() => _searchResults = []);
        }
      },
    );
    _loadTiles();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureBarangays();
      if (mounted) await _refreshDetails();
    });
  }

  Future<void> _loadTiles() async {
    final token = await MapboxConfig.publicToken();
    if (!mounted) return;
    setState(() {
      _isMapbox = token.isNotEmpty;
      _tileUrl = MapboxConfig.rasterTileUrl(token);
    });
  }

  @override
  void dispose() {
    _searchDebouncer.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _popWithPin() {
    Navigator.pop(
      context,
      _ExpandedPinResult(
        latitude: _lat,
        longitude: _lng,
        street: _street,
        barangay: _barangay,
        municipality: _municipality,
        placeId: _placeId,
      ),
    );
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
      _searchResults = [];
      _lockArea = false;
    });
    _refreshDetails();
  }

  Future<void> _refreshDetails() async {
    final seq = ++_geoSeq;
    setState(() => _resolving = true);
    try {
      final provider = context.read<AddressProvider>();
      if (provider.municipalities.isEmpty) {
        await provider.loadMunicipalities();
      }
      if (!mounted || seq != _geoSeq) return;

      final result = await provider.googleReverseGeocode(_lat, _lng);
      if (!mounted || seq != _geoSeq) return;

      Map<String, dynamic>? data;
      result.when(
        success: (payload) => data = payload,
        error: (_, __) {},
      );
      if (data == null) return;

      final streetCandidate = (data!['street']?.toString() ?? '').trim();
      final formatted = (data!['formatted_address']?.toString() ?? '').trim();
      final geoContext = (data!['context']?.toString() ?? '').trim();
      final geoMunicipality = (data!['municipality']?.toString() ?? '').trim();
      final geoBarangay = (data!['barangay']?.toString() ?? '').trim();
      final street = streetCandidate.isNotEmpty
          ? streetCandidate
          : (formatted.split(',').first.trim());
      final placeId = data!['place_id']?.toString();
      final areaText = _stripStreetFromAddress(
        [formatted, geoContext, geoMunicipality, geoBarangay]
            .where((e) => e.trim().isNotEmpty)
            .join(', '),
        street,
      );

      final matchedMunicipality = _matchMunicipality(
        geocodedMunicipality: geoMunicipality,
        formattedAddress: formatted,
        context: geoContext,
        street: street,
        municipalities: provider.municipalities,
      );

      String? matchedBarangay;
      if (matchedMunicipality != null) {
        await provider.loadBarangays(matchedMunicipality);
        if (!mounted || seq != _geoSeq) return;
        matchedBarangay = _bestAddressMatch(geoBarangay, provider.barangays) ??
            _bestAddressMatch(areaText, provider.barangays);
      }

      setState(() {
        _street = street.isNotEmpty ? street : null;
        if (placeId != null && placeId.isNotEmpty) _placeId = placeId;
        if (!_lockArea) {
          _municipality = matchedMunicipality;
          _barangay = matchedBarangay;
          if (matchedMunicipality != null) {
            _barangays = List<String>.from(provider.barangays);
          }
        }
      });
    } finally {
      if (mounted && seq == _geoSeq) setState(() => _resolving = false);
    }
  }

  Future<void> _ensureBarangays() async {
    if (_municipality == null || _municipality!.isEmpty) return;
    final provider = context.read<AddressProvider>();
    setState(() => _loadingBarangays = true);
    await provider.loadBarangays(_municipality!);
    if (!mounted) return;
    setState(() {
      _barangays = List<String>.from(provider.barangays);
      _loadingBarangays = false;
    });
  }

  Future<void> _openPicker({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) async {
    if (options.isEmpty || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final result = await showIosWheelPicker(
      context: context,
      title: title,
      options: List<String>.from(options),
      selected: selected,
    );
    if (!mounted || result == null) return;
    onSelected(result);
  }

  Future<void> _onCitySelected(String city) async {
    setState(() {
      _municipality = city;
      _barangay = null;
      _barangays = [];
      _loadingBarangays = true;
      _lockArea = true;
    });
    final provider = context.read<AddressProvider>();
    await provider.loadBarangays(city);
    if (!mounted) return;
    setState(() {
      _barangays = List<String>.from(provider.barangays);
      _loadingBarangays = false;
    });
    final lat = provider.barangayLat;
    final lng = provider.barangayLng;
    if (lat != null && lng != null) {
      setState(() {
        _lat = lat;
        _lng = lng;
      });
      if (_mapReady) {
        try {
          _mapController.move(LatLng(lat, lng), 14);
        } catch (_) {}
      }
      await _refreshDetails();
    }
  }

  Future<void> _onBarangaySelected(String barangay) async {
    if (_municipality == null) return;
    setState(() {
      _barangay = barangay;
      _lockArea = true;
    });
    final query = '$barangay, $_municipality, Laguna, Philippines';
    final result = await context.read<AddressProvider>().googlePlaceSearch(query);
    if (!mounted) return;
    List<Map<String, dynamic>> hits = [];
    result.when(success: (rows) => hits = rows, error: (_, __) {});
    if (hits.isEmpty) return;
    final lat = (hits.first['lat'] as num?)?.toDouble();
    final lng = (hits.first['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() {
      _lat = lat;
      _lng = lng;
      _placeId = hits.first['place_id']?.toString();
    });
    if (_mapReady) {
      try {
        _mapController.move(LatLng(lat, lng), 16);
      } catch (_) {}
    }
    await _refreshDetails();
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final cam = _mapController.camera;
      _mapController.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
    } catch (_) {}
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _lockArea = false;
      });
      if (_mapReady) {
        _mapController.move(LatLng(_lat, _lng), 17);
      }
      await _refreshDetails();
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final result = await context.read<AddressProvider>().googlePlaceSearch(query);
      if (!mounted) return;
      result.when(
        success: (rows) {
          setState(() {
            _searchResults = rows
                .map((feature) => {
                      'name': feature['name'] ?? 'Unknown',
                      'lat': (feature['lat'] as num?)?.toDouble() ?? 0.0,
                      'lng': (feature['lng'] as num?)?.toDouble() ?? 0.0,
                    })
                .toList();
          });
        },
        error: (_, __) => setState(() => _searchResults = []),
      );
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();
    setState(() {
      _lat = lat;
      _lng = lng;
      _searchResults = [];
      _searchController.clear();
      _lockArea = false;
    });
    _searchFocusNode.unfocus();
    if (_mapReady) _mapController.move(LatLng(lat, lng), 16);
    _refreshDetails();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tileUrl = _tileUrl ?? MapboxConfig.rasterTileUrl('');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithPin();
      },
      child: Scaffold(
        backgroundColor: AppColors.charcoal,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_lat, _lng),
                initialZoom: 16,
                keepAlive: true,
                onMapReady: () => _mapReady = true,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.seanlazala.eflora',
                  maxZoom: _isMapbox ? 22 : 19,
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_lat, _lng),
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.deepRose,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: top + 8,
              left: 12,
              child: _AddressMapControl(
                icon: Icons.close_rounded,
                iconColor: AppColors.deepRose,
                onTap: _popWithPin,
              ),
            ),
            Positioned(
              top: top + 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.deepRose.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'ADJUST PIN',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: top + 8,
              right: 12,
              child: Column(
                children: [
                  _AddressMapControl(
                    icon: Icons.my_location_rounded,
                    onTap: _isLocating ? () {} : _goToMyLocation,
                  ),
                  const SizedBox(height: 8),
                  _AddressZoomControls(
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),
            Positioned(
              top: top + 58,
              left: 12,
              right: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 2,
                    shadowColor: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: AppColors.warmWhite.withValues(alpha: 0.96),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (q) {
                        setState(() {});
                        _searchDebouncer.value = q;
                      },
                      style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal),
                      decoration: InputDecoration(
                        hintText: 'Search street, landmark…',
                        hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13.5),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.muted, size: 20),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.deepRose,
                                  ),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18, color: AppColors.muted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: AppColors.warmWhite,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 48),
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                color: AppColors.deepRose, size: 20),
                            title: Text(
                              place['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12.5, color: AppColors.charcoal),
                            ),
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + bottom,
              child: Material(
                color: AppColors.warmWhite,
                elevation: 6,
                shadowColor: const Color(0x33000000),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'LOCATION',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_resolving)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.deepRose,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Detecting address…',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _ExpandedDetailRow(
                        label: 'Street',
                        value: _street,
                      ),
                      const SizedBox(height: 8),
                      _ExpandedDetailRow(
                        label: 'City / Municipality',
                        value: _municipality,
                        placeholder: 'Select city',
                        onTap: () => _openPicker(
                          title: 'City / Municipality',
                          options: List<String>.from(
                            context.read<AddressProvider>().municipalities,
                          ),
                          selected: _municipality,
                          onSelected: _onCitySelected,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ExpandedDetailRow(
                        label: 'Barangay',
                        value: _barangay,
                        placeholder: _municipality == null
                            ? 'Select city first'
                            : (_loadingBarangays ? 'Loading…' : 'Select barangay'),
                        loading: _loadingBarangays,
                        enabled: _municipality != null &&
                            !_loadingBarangays &&
                            _barangays.isNotEmpty,
                        onTap: () => _openPicker(
                          title: 'Barangay',
                          options: List<String>.from(_barangays),
                          selected: _barangay,
                          onSelected: _onBarangaySelected,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _popWithPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepRose,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text(
                            'Use this location',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
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
}

class _ExpandedDetailRow extends StatelessWidget {
  const _ExpandedDetailRow({
    required this.label,
    required this.value,
    this.placeholder,
    this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.trim().isNotEmpty;
    final display = filled ? value!.trim() : (placeholder ?? '—');
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                display,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
                  color: filled ? AppColors.charcoal : AppColors.muted,
                ),
              ),
            ),
            if (onTap != null)
              loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deepRose,
                      ),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 22, color: AppColors.muted),
          ],
        ),
      ],
    );

    if (onTap == null) return row;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _AddressMapControl extends StatelessWidget {
  const _AddressMapControl({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

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

class _AddressZoomControls extends StatelessWidget {
  const _AddressZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

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
            Container(height: 1, color: AppColors.borderStrong),
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

/// iOS-style wheel picker — same chrome as the birthday date picker.
Future<String?> showIosWheelPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _IosWheelPickerSheet(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

class _IosWheelPickerSheet extends StatefulWidget {
  const _IosWheelPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  State<_IosWheelPickerSheet> createState() => _IosWheelPickerSheetState();
}

class _IosWheelPickerSheetState extends State<_IosWheelPickerSheet> {
  late int _index;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final i = widget.selected == null
        ? 0
        : widget.options.indexOf(widget.selected!);
    _index = i < 0 ? 0 : i;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () =>
                        Navigator.pop(context, widget.options[_index]),
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
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.light,
                  primaryColor: AppColors.deepRose,
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      fontSize: 21,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                child: CupertinoPicker(
                  scrollController: _controller,
                  itemExtent: 36,
                  magnification: 1.08,
                  squeeze: 1.12,
                  useMagnifier: true,
                  onSelectedItemChanged: (i) => _index = i,
                  children: [
                    for (final option in widget.options)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            option,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
