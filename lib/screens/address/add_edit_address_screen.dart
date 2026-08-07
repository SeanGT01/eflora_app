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
import '../../theme/app_theme.dart';

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
  bool _isLoading = false;
  bool _isSaving = false;
  final MapController _mapController = MapController();
  bool _isLocating = false;

  // Place search
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  late Debouncer<String> _searchDebouncer;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchDebouncer = Debouncer<String>(
      const Duration(milliseconds: 300),
      initialValue: '',
      onChanged: (query) {
        if (query.isNotEmpty) {
          _searchPlaces(query);
        } else {
          setState(() => _searchResults = []);
        }
      },
    );

    if (widget.address != null) {
      _streetController = TextEditingController(text: widget.address!.street);
      _buildingDetailsController = TextEditingController(text: widget.address!.buildingDetails);
      _addressLabel = widget.address!.addressLabel;
      _isDefault = widget.address!.isDefault;
      _selectedMunicipality = widget.address!.municipality;
      _selectedBarangay = widget.address!.barangay;
      _selectedLatitude = widget.address!.latitude;
      _selectedLongitude = widget.address!.longitude;
      _selectedPlaceId = widget.address!.placeId;
    } else {
      _streetController = TextEditingController();
      _buildingDetailsController = TextEditingController();
      _addressLabel = 'Home';
      _isDefault = false;
      _selectedLatitude = 14.1694; // Default to Laguna center
      _selectedLongitude = 121.2934;
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _buildingDetailsController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _formatAddressLine() {
    final parts = <String>[];
    if (_streetController.text.isNotEmpty) parts.add(_streetController.text);
    if (_buildingDetailsController.text.isNotEmpty) parts.add(_buildingDetailsController.text);
    if (_selectedBarangay != null) parts.add(_selectedBarangay!);
    if (_selectedMunicipality != null) parts.add(_selectedMunicipality!);
    return parts.join(', ');
  }

  Future<void> _loadBarangays(String municipality, {bool moveMap = true}) async {
    setState(() => _isLoading = true);

    final addressProvider = Provider.of<AddressProvider>(context, listen: false);
    await addressProvider.loadBarangays(municipality);

    if (!mounted) return;

    setState(() {
      _barangays = addressProvider.barangays;
      _selectedBarangay = null;
      // If editing and has saved barangay in this municipality, restore it
      if (widget.address != null && _barangays.contains(widget.address!.barangay)) {
        _selectedBarangay = widget.address!.barangay;
      } else if (moveMap && _barangays.isNotEmpty) {
        // Dropdown-driven change: pick first so the form stays valid.
        _selectedBarangay = _barangays.first;
      }

      // Move map to municipality center when selecting from the dropdown only.
      if (moveMap &&
          addressProvider.barangayLat != null &&
          addressProvider.barangayLng != null) {
        _selectedLatitude = addressProvider.barangayLat;
        _selectedLongitude = addressProvider.barangayLng;
        final lat = addressProvider.barangayLat!;
        final lng = addressProvider.barangayLng!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(LatLng(lat, lng), 14);
        });
      }

      _isLoading = false;
    });
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
    s = s.replaceAll(RegExp(r'\b(barangay|brgy\.?|city of|city|municipality of|municipality)\b'), ' ');
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
      if (h == n || h.contains(' $n ') || h.startsWith('$n ') || h.endsWith(' $n') || h.contains(n)) {
        if (h == n || RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(h)) {
          exact = option;
          break;
        }
        contains ??= option;
      }
    }
    return exact ?? contains;
  }

  /// Reverse-geocode a map pin and sync municipality / barangay / street fields.
  Future<void> _reverseGeocodeAndFill(double lat, double lng) async {
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
        options: Options(headers: {'User-Agent': 'eflowers-app'}),
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
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      final municipalities = addressProvider.municipalities;
      final matchedMunicipality = _bestMatch(contextText, municipalities);

      final streetCandidate = (address['road'] ??
              address['pedestrian'] ??
              address['path'] ??
              address['residential'] ??
              '')
          .toString()
          .trim();

      if (streetCandidate.isNotEmpty) {
        _streetController.text = streetCandidate;
      }

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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pin set. Select municipality/barangay if they were not detected.'),
          ),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) print('Reverse geocoding failed: $e');
    }
  }

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
        options: Options(headers: {'User-Agent': 'eflowers-app'}),
      );

      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final feature = (response.data as List).first;
        final lat = double.tryParse(feature['lat']?.toString() ?? '');
        final lng = double.tryParse(feature['lon']?.toString() ?? '');

        if (lat != null && lng != null && mounted) {
          setState(() {
            _selectedLatitude = lat;
            _selectedLongitude = lng;
          });
          // Move map to barangay location with higher zoom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(LatLng(lat, lng), 15);
          });
        }
      }
    } catch (e) {
      // Silently fail - user can still select location manually
      if (kDebugMode) print('Barangay geocoding failed: $e');
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to find your position')),
        );
        setState(() => _isLocating = false);
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
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
      await _reverseGeocodeAndFill(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
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
        options: Options(headers: {'User-Agent': 'eflowers-app'}),
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
    } catch (e) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isSearching = false);
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
    // Defer move so the layout settles after search suggestions collapse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(LatLng(lat, lng), 16);
    });
    _reverseGeocodeAndFill(lat, lng);
  }

  Future<void> _saveAddress() async {
    // Validate required fields
    if (_selectedMunicipality == null || _selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select municipality and barangay')),
      );
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your exact location on the map')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final addressLine = _formatAddressLine();
    final addressProvider = Provider.of<AddressProvider>(context, listen: false);

    try {
      if (widget.address == null) {
        // Adding new address
        await addressProvider.addAddress(
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty ? _buildingDetailsController.text : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        );
      } else {
        // Updating existing address
        await addressProvider.updateAddress(
          widget.address!.id!,
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty ? _buildingDetailsController.text : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.address == null ? 'Address added' : 'Address updated'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      // Return the saved address
      Navigator.of(context).pop(
        Address(
          id: widget.address?.id,
          municipality: _selectedMunicipality!,
          barangay: _selectedBarangay!,
          addressLine: addressLine,
          latitude: _selectedLatitude!,
          longitude: _selectedLongitude!,
          street: _streetController.text.isNotEmpty ? _streetController.text : null,
          buildingDetails: _buildingDetailsController.text.isNotEmpty ? _buildingDetailsController.text : null,
          addressLabel: _addressLabel,
          isDefault: _isDefault,
          placeId: _selectedPlaceId,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildSectionLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.charcoal,
          ),
          children: required
              ? [TextSpan(text: ' *', style: TextStyle(color: AppColors.deepRose))]
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(widget.address == null ? 'Add Address' : 'Edit Address'),
      ),
      body: Consumer<AddressProvider>(
        builder: (context, addressProvider, _) {
          if (addressProvider.isMunicipalitiesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.deepRose),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Address Label Selection
              _buildSectionLabel('Address Label'),
              Wrap(
                spacing: 8,
                children: ['Home', 'Work', 'Other'].map((label) {
                  final selected = _addressLabel == label;
                  final IconData icon = label == 'Home'
                      ? Icons.home_rounded
                      : label == 'Work'
                          ? Icons.work_rounded
                          : Icons.location_on_rounded;
                  return FilterChip(
                    avatar: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.muted),
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _addressLabel = label),
                    selectedColor: AppColors.deepRose,
                    checkmarkColor: Colors.white,
                    labelStyle: GoogleFonts.dmSans(
                      color: selected ? Colors.white : AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.deepRose : AppColors.borderStrong,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Municipality Dropdown
              _buildSectionLabel('Municipality / City', required: true),
              DropdownButtonFormField<String>(
                value: _selectedMunicipality,
                hint: Text('Select Municipality/City',
                    style: GoogleFonts.dmSans(color: AppColors.muted.withOpacity(0.55), fontSize: 13.5)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                decoration: const InputDecoration(),
                items: addressProvider.municipalities.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.dmSans(fontSize: 13.5)));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMunicipality = value;
                      _selectedBarangay = null;
                      _barangays = [];
                    });
                    _loadBarangays(value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Barangay Dropdown
              _buildSectionLabel('Barangay', required: true),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2)),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedBarangay,
                  hint: Text('Select Barangay',
                      style: GoogleFonts.dmSans(color: AppColors.muted.withOpacity(0.55), fontSize: 13.5)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                  decoration: const InputDecoration(),
                  items: _barangays.map((b) {
                    return DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.dmSans(fontSize: 13.5)));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedBarangay = value);
                      _geocodeBarangay(value);
                    }
                  },
                ),
              const SizedBox(height: 20),

              // Street Input
              _buildSectionLabel('Street'),
              TextField(
                controller: _streetController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Main Street, J.P. Rizal Ave',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Building Details Input
              _buildSectionLabel('House / Unit Details'),
              TextField(
                controller: _buildingDetailsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g., Bldg 5, Unit 301, near Sari-Sari Store',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Place Search
              _buildSectionLabel('Search Location'),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (query) => _searchDebouncer.value = query,
                decoration: InputDecoration(
                  hintText: 'Search for places, streets, landmarks...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.muted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                ),
              ),
              // Search Suggestions
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: AppColors.warmWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.deepRose.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on_rounded, color: AppColors.deepRose, size: 18),
                        ),
                        title: Text(
                          place['name'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.charcoal),
                        ),
                        onTap: () => _selectPlace(place),
                      );
                    },
                  ),
                ),
              if (_searchController.text.isNotEmpty && _searchResults.isEmpty && !_isSearching)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No locations found. Try a different search term.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 24),

              // Map Section
              _buildSectionLabel('Pin Your Exact Location', required: true),
              Text(
                'Tap on the map to place the pin at your exact address',
                style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          _selectedLatitude ?? 14.1694,
                          _selectedLongitude ?? 121.2934,
                        ),
                        initialZoom: _selectedLatitude != null ? 16 : 12,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLatitude = point.latitude;
                            _selectedLongitude = point.longitude;
                          });
                          _reverseGeocodeAndFill(point.latitude, point.longitude);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.eflowers.app',
                          maxZoom: 19,
                        ),
                        if (_selectedLatitude != null && _selectedLongitude != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_selectedLatitude!, _selectedLongitude!),
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: AppColors.deepRose,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // My Location FAB
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        heroTag: 'myLocationBtn',
                        backgroundColor: AppColors.warmWhite,
                        elevation: 2,
                        onPressed: _isLocating ? null : _goToMyLocation,
                        child: _isLocating
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepRose),
                              )
                            : const Icon(Icons.my_location_rounded, color: AppColors.deepRose, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedLatitude != null && _selectedLongitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.dmSans(color: AppColors.muted, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 24),

              // Address Preview
              if (_formatAddressLine().isNotEmpty) ...[
                _buildSectionLabel('Address Preview'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.deepRose.withOpacity(0.06),
                    border: Border.all(color: AppColors.dustyRose.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, color: AppColors.deepRose, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatAddressLine(),
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.charcoal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Set as Default Checkbox
              Container(
                decoration: BoxDecoration(
                  color: AppColors.warmWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: CheckboxListTile(
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value ?? false),
                  title: Text('Set as default delivery address',
                      style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.charcoal)),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.deepRose,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAddress,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.address == null ? 'Save Address' : 'Update Address'),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
