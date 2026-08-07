import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import '../../models/checkout.dart';
import '../../providers/address_provider.dart';
import '../../theme/app_background.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';

/// Grab / Foodpanda–style address form: map-first pin, auto current location,
/// compact tappable city/barangay rows (bottom-sheet pickers), theme-aligned.
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
  /// Kept stable across rebuilds — new onTap closures break flutter_map's InheritedModel.
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
        if (!mounted) return;
        if (_mapReady) {
          try {
            _mapController.move(LatLng(lat, lng), zoom);
          } catch (_) {}
        } else {
          // Map may still be mounting; try once more next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_mapReady) return;
            try {
              _mapController.move(LatLng(lat, lng), zoom);
            } catch (_) {}
          });
        }
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

  String _normalizeForMatch(String? value) {
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

  String? _bestMatch(String haystack, List<String> options) {
    final h = _normalizeForMatch(haystack);
    if (h.isEmpty || options.isEmpty) return null;

    String? exact;
    String? contains;
    for (final option in options) {
      final n = _normalizeForMatch(option);
      if (n.isEmpty) continue;
      if (h == n ||
          h.contains(' $n ') ||
          h.startsWith('$n ') ||
          h.endsWith(' $n') ||
          h.contains(n)) {
        if (h == n || RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(h)) {
          exact = option;
          break;
        }
        contains ??= option;
      }
    }
    return exact ?? contains;
  }

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
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lng.toString(),
          'format': 'json',
          'addressdetails': '1',
          'zoom': '18',
        },
        options: Options(headers: {'User-Agent': 'eflora-app/1.0'}),
      );

      if (!mounted || response.statusCode != 200 || response.data is! Map) return;

      final data = Map<String, dynamic>.from(response.data as Map);
      final address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
      final displayName = data['display_name']?.toString() ?? '';

      final contextParts = <String>[
        displayName,
        address['suburb']?.toString() ?? '',
        address['neighbourhood']?.toString() ?? '',
        address['village']?.toString() ?? '',
        address['hamlet']?.toString() ?? '',
        address['city_district']?.toString() ?? '',
        address['quarter']?.toString() ?? '',
        address['city']?.toString() ?? '',
        address['municipality']?.toString() ?? '',
        address['town']?.toString() ?? '',
        address['county']?.toString() ?? '',
        address['state']?.toString() ?? '',
        address['road']?.toString() ?? '',
        address['pedestrian']?.toString() ?? '',
      ].where((e) => e.trim().isNotEmpty);

      final contextText = contextParts.join(', ');

      final streetCandidate = (address['road'] ??
              address['pedestrian'] ??
              address['path'] ??
              address['residential'] ??
              '')
          .toString()
          .trim();
      final houseNumber = (address['house_number'] ?? '').toString().trim();

      if (overwriteStreet) {
        _streetController.text = streetCandidate;
      } else if (streetCandidate.isNotEmpty && _streetController.text.trim().isEmpty) {
        _streetController.text = streetCandidate;
      }

      if (houseNumber.isNotEmpty && _buildingDetailsController.text.trim().isEmpty) {
        _buildingDetailsController.text = houseNumber;
      }

      if (!syncArea) {
        if (mounted) setState(() {});
        return;
      }

      final municipalities = context.read<AddressProvider>().municipalities;
      final matchedMunicipality = _bestMatch(contextText, municipalities);

      if (matchedMunicipality != null) {
        final municipalityChanged = matchedMunicipality != _selectedMunicipality;
        setState(() => _selectedMunicipality = matchedMunicipality);

        if (municipalityChanged || _barangays.isEmpty) {
          await _loadBarangays(matchedMunicipality, moveMap: false);
        }
        if (!mounted) return;

        final matchedBarangay = _bestMatch(contextText, _barangays);
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
      final dio = Dio();
      final query = '$barangay, $_selectedMunicipality, Laguna, Philippines';
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'countrycodes': 'PH',
          'format': 'json',
          'limit': '1',
        },
        options: Options(headers: {'User-Agent': 'eflora-app/1.0'}),
      );

      if (response.statusCode == 200 &&
          response.data is List &&
          (response.data as List).isNotEmpty) {
        final feature = (response.data as List).first;
        final lat = double.tryParse(feature['lat']?.toString() ?? '');
        final lng = double.tryParse(feature['lon']?.toString() ?? '');

        if (lat != null && lng != null && mounted) {
          setState(() {
            _selectedLatitude = lat;
            _selectedLongitude = lng;
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on location services to use your current position')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to find your position')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
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
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': '$query, Laguna, Philippines',
          'countrycodes': 'PH',
          'format': 'json',
          'limit': '5',
          'addressdetails': '1',
        },
        options: Options(headers: {'User-Agent': 'eflora-app/1.0'}),
      );

      if (response.statusCode == 200) {
        final features = response.data as List;
        setState(() {
          _searchResults = features
              .map((feature) => {
                    'name': feature['display_name'] ?? 'Unknown',
                    'lat': double.tryParse(feature['lat']?.toString() ?? '') ?? 0.0,
                    'lng': double.tryParse(feature['lon']?.toString() ?? '') ?? 0.0,
                  })
              .cast<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    final lat = place['lat'] as double;
    final lng = place['lng'] as double;
    setState(() {
      _selectedLatitude = lat;
      _selectedLongitude = lng;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select municipality and barangay')),
      );
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pin your exact location on the map')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final addressLine = _formatAddressLine();
    final addressProvider = context.read<AddressProvider>();

    try {
      if (!_isEditing) {
        await addressProvider.addAddress(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!_isEditing ? 'Address added' : 'Address updated'),
          backgroundColor: AppColors.successGreen,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
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

    final items = List<String>.from(options);
    final current = selected;

    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      // Fixed-height sheet; avoids unbounded flex overflow with isScrollControlled.
      backgroundColor: AppColors.warmWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 440,
            child: _AddressPickerSheet(
              title: title,
              options: items,
              selected: current,
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    onSelected(result);
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
        showFlowers: false,
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

/// Map + search chrome. Owns a stable [FlutterMap] configuration so parent
/// rebuilds (sheets / Provider) do not recreate MapOptions.
class _PinnedMapBox extends StatelessWidget {
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
  final MapController mapController;
  final MapOptions mapOptions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: mapOptions,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.seanlazala.eflora',
                maxZoom: 19,
              ),
              if (latitude != null && longitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude!, longitude!),
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
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: onSearchChanged,
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'Search street, landmark…',
                      hintStyle: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 13.5),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                      suffixIcon: isSearching
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
                          : searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18, color: AppColors.muted),
                                  onPressed: onClearSearch,
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                if (searchResults.isNotEmpty)
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
                      itemCount: searchResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 48),
                      itemBuilder: (context, index) {
                        final place = searchResults[index];
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
                          onTap: () => onSelectPlace(place),
                        );
                      },
                    ),
                  ),
              ],
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
                onTap: isLocating ? null : onUseMyLocation,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: isLocating
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
          if (isReverseGeocoding)
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

/// Searchable list sheet used for city / barangay selection.
class _AddressPickerSheet extends StatefulWidget {
  const _AddressPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  late final TextEditingController _queryController;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _filtered = List<String>.from(widget.options);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    final n = q.trim().toLowerCase();
    setState(() {
      _filtered = n.isEmpty
          ? List<String>.from(widget.options)
          : widget.options.where((o) => o.toLowerCase().contains(n)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderStrong,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _queryController,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: GoogleFonts.dmSans(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    final isSelected = item == widget.selected;
                    return ListTile(
                      title: Text(
                        item,
                        style: GoogleFonts.dmSans(
                          fontSize: 14.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: AppColors.charcoal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.deepRose)
                          : null,
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
