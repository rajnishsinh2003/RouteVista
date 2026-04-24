import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'place_detail_screen.dart';

class QuickServiceScreen extends StatefulWidget {
  final String category;
  final IconData icon;
  final Color color;

  const QuickServiceScreen({
    super.key,
    required this.category,
    required this.icon,
    required this.color,
  });

  @override
  State<QuickServiceScreen> createState() => _QuickServiceScreenState();
}

class _QuickServiceScreenState extends State<QuickServiceScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyServices();
  }

  Future<void> _fetchNearbyServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition();
      
      // Overpass API Query
      String tags = '';
      if (widget.category == 'Hospitals') tags = '["amenity"="hospital"]';
      else if (widget.category == 'Fuel') tags = '["amenity"="fuel"]';
      else if (widget.category == 'Restaurants') tags = '["amenity"="restaurant"]';
      else if (widget.category == 'Hotels') tags = '["tourism"="hotel"]';
      else tags = '["amenity"="${widget.category.toLowerCase()}"]';

      final query = '''
        [out:json][timeout:25];
        (
          node$tags(around:5000, ${position.latitude}, ${position.longitude});
          way$tags(around:5000, ${position.latitude}, ${position.longitude});
        );
        out body;
        >;
        out skel qt;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;
        
        List<Map<String, dynamic>> formatted = [];
        for (var e in elements) {
          if (e['tags'] != null) {
            final tags = e['tags'];
            final lat = e['lat'] ?? (e['center'] != null ? e['center']['lat'] : null);
            final lon = e['lon'] ?? (e['center'] != null ? e['center']['lon'] : null);
            
            if (lat != null && lon != null) {
              double distance = Geolocator.distanceBetween(
                position.latitude, position.longitude, lat, lon
              ) / 1000;

              formatted.add({
                'name': tags['name'] ?? 'Unnamed ${widget.category}',
                'location': tags['addr:street'] ?? 'Nearby ${_getCity(tags)}',
                'lat': lat,
                'lon': lon,
                'distance': distance,
                'category': widget.category,
                'tags': tags,
              });
            }
          }
        }
        
        formatted.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        if (mounted) {
          setState(() {
            _results = formatted;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to fetch services');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not find nearby ${widget.category}. Please check your connection and GPS.';
          _isLoading = false;
        });
      }
    }
  }

  String _getCity(Map tags) {
    return tags['addr:city'] ?? tags['addr:suburb'] ?? 'Location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Nearby ${widget.category}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNearbyServices,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _results.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: widget.color),
          const SizedBox(height: 16),
          Text(
            'Searching for ${widget.category.toLowerCase()}...',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[800]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchNearbyServices,
              style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No ${widget.category.toLowerCase()} found nearby.',
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color),
            ),
            title: Text(
              item['name'],
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['location'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions, size: 14, color: widget.color),
                    const SizedBox(width: 4),
                    Text(
                      '${item['distance'].toStringAsFixed(1)} km away',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: widget.color),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailScreen(
                    name: item['name'],
                    location: item['location'],
                    imageUrl: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=400', // Default service image
                    rating: 4.0,
                    category: widget.category,
                    description: _generateDescription(item),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _generateDescription(Map item) {
    final tags = item['tags'] as Map;
    String desc = '${item['name']} is a ${widget.category.toLowerCase()} located in ${item['location']}. ';
    if (tags['opening_hours'] != null) desc += 'Opening hours: ${tags['opening_hours']}. ';
    if (tags['phone'] != null) desc += 'Phone: ${tags['phone']}. ';
    if (tags['website'] != null) desc += 'Website: ${tags['website']}. ';
    return desc;
  }
}
