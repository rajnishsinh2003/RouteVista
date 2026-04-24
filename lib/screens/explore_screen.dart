import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'place_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _currentLocation;
  LatLng _mapCenter = const LatLng(20.5937, 78.9629);

  List<Map<String, dynamic>> _pois = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  bool _isOffline = false;
  String? _errorMessage;

  final _categories = ['All', 'Religious', 'Historical', 'Nature', 'Food', 'Hotels', 'Fuel'];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // FIX 1: GPS denied -> still fetch POIs at fallback location
  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _currentLocation = null;
        _mapCenter = const LatLng(20.5937, 78.9629);
        await _fetchPOIs();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      _mapCenter = _currentLocation!;
      await _fetchPOIs();
    } catch (e) {
      _currentLocation = null;
      _mapCenter = const LatLng(20.5937, 78.9629);
      await _fetchPOIs();
    }
  }

  // FIX 2: Fixed Overpass "All" query + FIX 3: filter unnamed POIs
  Future<void> _fetchPOIs() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _errorMessage = null;
    });

    final lat = _mapCenter.latitude;
    final lon = _mapCenter.longitude;

    String amenityFilter;
    switch (_selectedCategory) {
      case 'Religious':
        amenityFilter = 'node(around:10000,$lat,$lon)["amenity"="place_of_worship"];';
        break;
      case 'Historical':
        amenityFilter = 'node(around:10000,$lat,$lon)["historic"];';
        break;
      case 'Nature':
        amenityFilter = 'node(around:10000,$lat,$lon)["leisure"="park"];';
        break;
      case 'Food':
        amenityFilter = 'node(around:10000,$lat,$lon)["amenity"~"restaurant|cafe|fast_food"];';
        break;
      case 'Hotels':
        amenityFilter = 'node(around:10000,$lat,$lon)["tourism"~"hotel|guest_house"];';
        break;
      case 'Fuel':
        amenityFilter = 'node(around:10000,$lat,$lon)["amenity"="fuel"];';
        break;
      default:
        // FIX 2: all statements inside the union ( ... ); wrapper
        amenityFilter =
            'node(around:10000,$lat,$lon)["amenity"~"restaurant|fuel|hospital|place_of_worship"];'
            'node(around:10000,$lat,$lon)["tourism"~"hotel|museum|attraction"];'
            'node(around:10000,$lat,$lon)["historic"];'
            'node(around:10000,$lat,$lon)["leisure"="park"];';
    }

    final query = '[out:json][timeout:25];($amenityFilter);out;';

    try {
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<Map<String, dynamic>> pois = [];
        for (final e in data['elements']) {
          if (e['lat'] == null || e['tags'] == null) continue;
          // FIX 3: skip unnamed POIs
          final name = e['tags']['name'] as String?;
          if (name == null || name.trim().isEmpty) continue;
          pois.add({
            'name': name.trim(),
            'lat': e['lat'],
            'lon': e['lon'],
            'type': _getType(e['tags']),
          });
        }
        if (mounted) {
          setState(() {
            _pois = pois.take(50).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Server error (${res.statusCode}). Try again.';
          });
        }
      }
    } catch (e) {
      // FIX 4: show offline/error message instead of silent empty map
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
          _errorMessage = 'No internet connection. Please go online to explore places.';
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (data.isNotEmpty) {
          final newCenter = LatLng(
            double.parse(data[0]['lat'].toString()),
            double.parse(data[0]['lon'].toString()),
          );
          _mapCenter = newCenter;
          _mapController.move(newCenter, 13);
          await _fetchPOIs();
          return;
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Location not found', style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _recenterMap() {
    if (_currentLocation != null) {
      _mapCenter = _currentLocation!;
      _mapController.move(_currentLocation!, 13);
      _fetchPOIs();
    }
  }

  String _getType(Map tags) {
    if (tags['amenity'] == 'place_of_worship') return 'Religious';
    if (tags['historic'] != null) return 'Historical';
    if (tags['leisure'] == 'park') return 'Nature';
    if (tags['amenity'] == 'restaurant' || tags['amenity'] == 'cafe' || tags['amenity'] == 'fast_food') return 'Food';
    if (tags['tourism'] == 'hotel' || tags['tourism'] == 'guest_house') return 'Hotels';
    if (tags['amenity'] == 'fuel') return 'Fuel';
    return 'Other';
  }

  Color _getMarkerColor(String type) {
    switch (type) {
      case 'Religious':  return Colors.purple;
      case 'Historical': return Colors.brown;
      case 'Nature':     return Colors.green;
      case 'Food':       return Colors.orange;
      case 'Hotels':     return Colors.indigo;
      case 'Fuel':       return Colors.blueGrey;
      default:           return Colors.grey;
    }
  }

  IconData _getMarkerIcon(String type) {
    switch (type) {
      case 'Religious':  return Icons.temple_hindu;
      case 'Historical': return Icons.account_balance;
      case 'Nature':     return Icons.forest;
      case 'Food':       return Icons.restaurant;
      case 'Hotels':     return Icons.hotel;
      case 'Fuel':       return Icons.local_gas_station;
      default:           return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _mapCenter, initialZoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40, height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),
                  ..._pois.map((p) => Marker(
                    point: LatLng(p['lat'] as double, p['lon'] as double),
                    width: 35, height: 35,
                    child: GestureDetector(
                      onTap: () => _showPOIInfo(p),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor, shape: BoxShape.circle,
                          border: Border.all(color: _getMarkerColor(p['type'] as String), width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                        ),
                        child: Icon(_getMarkerIcon(p['type'] as String), size: 18, color: _getMarkerColor(p['type'] as String)),
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),

          // SEARCH BAR
          Positioned(
            top: topPad + 10, left: 12, right: 12,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                textInputAction: TextInputAction.search,
                onSubmitted: _searchLocation,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search a city or place...',
                  hintStyle: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () { _searchController.clear(); setState(() {}); },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // CATEGORY CHIPS
          Positioned(
            top: topPad + 66, left: 0, right: 0,
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (c, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      setState(() { _selectedCategory = cat; _isLoading = true; });
                      _fetchPOIs();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Center(
                        child: Text(cat,
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              )),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // LOADING
          if (_isLoading)
            Positioned(
              top: topPad + 120, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Loading...', style: GoogleFonts.poppins(fontSize: 13)),
                  ]),
                ),
              ),
            ),

          // FIX 4: Offline / error banner
          if (!_isLoading && _errorMessage != null)
            Positioned(
              top: topPad + 120, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isOffline ? Colors.orange[700] : Colors.redAccent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                ),
                child: Row(children: [
                  Icon(_isOffline ? Icons.wifi_off : Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                  ),
                  if (!_isOffline)
                    GestureDetector(
                      onTap: _fetchPOIs,
                      child: const Padding(padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.refresh, color: Colors.white, size: 18)),
                    ),
                ]),
              ),
            ),

          // FIX 5: Empty state
          if (!_isLoading && _pois.isEmpty && _errorMessage == null)
            Positioned(
              top: topPad + 120, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 8),
                    Text('No places found nearby',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                  ]),
                ),
              ),
            ),

          // POI COUNT CHIP
          Positioned(
            bottom: 20, left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
              ),
              child: Text('${_pois.length} places found',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),

          // RECENTER BUTTON
          if (_currentLocation != null)
            Positioned(
              bottom: 20, right: 20,
              child: GestureDetector(
                onTap: _recenterMap,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                  ),
                  child: Icon(Icons.my_location, color: Theme.of(context).primaryColor, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // FIX 3: Bottom sheet now has Navigate Here + View on Map buttons
  void _showPOIInfo(Map<String, dynamic> poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _getMarkerColor(poi['type'] as String).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getMarkerIcon(poi['type'] as String),
                    color: _getMarkerColor(poi['type'] as String), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(poi['name'] as String,
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getMarkerColor(poi['type'] as String).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(poi['type'] as String,
                        style: GoogleFonts.poppins(fontSize: 12,
                            color: _getMarkerColor(poi['type'] as String),
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text('Navigate',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MapScreen(
                        useCurrentLocation: _currentLocation != null,
                        source: _currentLocation != null ? 'My Location' : 'Current Location',
                        destination: poi['name'] as String,
                        sourceLat: _currentLocation?.latitude,
                        sourceLon: _currentLocation?.longitude,
                        destLat: (poi['lat'] as num).toDouble(),
                        destLon: (poi['lon'] as num).toDouble(),
                      ),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    foregroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: Text('Details', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlaceDetailScreen(
                        name: poi['name'] as String,
                        location: 'Nearby ${_mapCenter.latitude.toStringAsFixed(2)}, ${_mapCenter.longitude.toStringAsFixed(2)}',
                        imageUrl: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=400', 
                        rating: 4.0,
                        category: poi['type'] as String,
                        description: '${poi['name']} is a ${poi['type'].toString().toLowerCase()} found during your exploration.',
                      ),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  foregroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
                child: const Icon(Icons.map_outlined, size: 18),
                onPressed: () {
                  Navigator.pop(context);
                  _mapController.move(
                    LatLng((poi['lat'] as num).toDouble(), (poi['lon'] as num).toDouble()), 16);
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
