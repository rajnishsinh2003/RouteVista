import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class QuickServiceScreen extends StatefulWidget {
  final String serviceType; // restaurant, fuel, hospital, police
  final IconData icon;
  final Color color;

  const QuickServiceScreen({
    super.key,
    required this.serviceType,
    required this.icon,
    required this.color,
  });

  @override
  State<QuickServiceScreen> createState() => _QuickServiceScreenState();
}

class _QuickServiceScreenState extends State<QuickServiceScreen> {
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final amenityType = _getAmenityType(widget.serviceType);
      final query = """
        [out:json][timeout:25];
        node(around:10000,${_currentPosition!.latitude},${_currentPosition!.longitude})["amenity"~"$amenityType"];
        out;
      """;

      final res = await http.post(
        Uri.parse("https://overpass-api.de/api/interpreter"),
        body: "data=${Uri.encodeComponent(query)}",
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final elements = data['elements'] as List;

        List<Map<String, dynamic>> places = [];
        for (var e in elements) {
          if (e['tags'] == null) continue;
          final name = e['tags']['name'] ?? widget.serviceType.toUpperCase();
          final lat = e['lat'] as double;
          final lon = e['lon'] as double;
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lon,
          );
          places.add({
            'name': name,
            'lat': lat,
            'lon': lon,
            'distance': dist,
            'address': e['tags']['addr:street'] ?? e['tags']['addr:city'] ?? 'Nearby',
            'phone': e['tags']['phone'] ?? e['tags']['contact:phone'] ?? '',
          });
        }

        places.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        setState(() {
          _places = places.take(20).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load places';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Unable to find nearby ${widget.serviceType}s. Please check your location settings.';
        _isLoading = false;
      });
    }
  }

  String _getAmenityType(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'restaurants':
        return 'restaurant|cafe|fast_food';
      case 'fuel stations':
        return 'fuel';
      case 'hospitals':
        return 'hospital|clinic';
      case 'police':
        return 'police';
      default:
        return serviceType.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        foregroundColor: Colors.white,
        title: Text(
          'Nearby ${widget.serviceType}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: widget.color),
                  const SizedBox(height: 16),
                  Text(
                    'Finding nearby ${widget.serviceType}...',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = '';
                            });
                            _loadNearbyPlaces();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _places.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.icon, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No ${widget.serviceType} found nearby',
                            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _places.length,
                      itemBuilder: (context, index) {
                        final place = _places[index];
                        final distKm = (place['distance'] as double) / 1000;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(widget.icon, color: widget.color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place['name'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      place['address'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${distKm.toStringAsFixed(1)} km',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: widget.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
