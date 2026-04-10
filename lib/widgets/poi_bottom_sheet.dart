import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../services/poi_service.dart';

class PoiBottomSheet extends StatefulWidget {
  final PoiModel poi;
  final void Function(LatLng) onNavigate;
  final void Function(LatLng) onSetWaypoint;

  const PoiBottomSheet({
    super.key,
    required this.poi,
    required this.onNavigate,
    required this.onSetWaypoint,
  });

  @override
  State<PoiBottomSheet> createState() => _PoiBottomSheetState();
}

class _PoiBottomSheetState extends State<PoiBottomSheet> {
  bool _saved = false;

  String get _distanceText {
    final d = widget.poi.distanceFromRouteMeters;
    if (d < 1000) return '${d.toStringAsFixed(0)} m from route';
    return '${(d / 1000).toStringAsFixed(1)} km from route';
  }

  Future<void> _savePlace() async {
    final prefs = await SharedPreferences.getInstance();
    final placesJson = prefs.getString('saved_places') ?? '[]';
    final places = List<Map<String, dynamic>>.from(json.decode(placesJson));
    if (!places.any((p) => p['id'] == widget.poi.id)) {
      places.insert(0, {
        'id': widget.poi.id,
        'name': widget.poi.name,
        'location': '${widget.poi.lat.toStringAsFixed(4)}, ${widget.poi.lng.toStringAsFixed(4)}',
        'category': widget.poi.category,
        'rating': 4.5,
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString('saved_places', json.encode(places));
      if (mounted) setState(() => _saved = true);
    } else {
      if (mounted) setState(() => _saved = true);
    }
  }

  Widget _tagRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final tags = poi.tags;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: poi.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(poi.emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name,
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: poi.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  poi.category,
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: poi.color),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.near_me, size: 13, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(_distanceText, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // OSM tag details
                if (tags['opening_hours'] != null)
                  _tagRow(Icons.access_time, 'Hours', tags['opening_hours']!),
                if (tags['phone'] != null || tags['contact:phone'] != null)
                  _tagRow(Icons.phone, 'Phone', tags['phone'] ?? tags['contact:phone']!),
                if (tags['website'] != null || tags['contact:website'] != null)
                  _tagRow(Icons.language, 'Web', tags['website'] ?? tags['contact:website']!),
                if (tags['cuisine'] != null)
                  _tagRow(Icons.restaurant_menu, 'Cuisine', tags['cuisine']!),
                if (tags['brand'] != null)
                  _tagRow(Icons.storefront, 'Brand', tags['brand']!),
                if (tags['operator'] != null && tags['brand'] == null)
                  _tagRow(Icons.business, 'Operator', tags['operator']!),
                if (tags['fee'] != null)
                  _tagRow(Icons.currency_rupee, 'Fee', tags['fee']!),

                const SizedBox(height: 16),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065A60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigate(poi.latLng);
                      },
                      icon: const Icon(Icons.navigation, size: 17),
                      label: Text('Navigate', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: poi.color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSetWaypoint(poi.latLng);
                      },
                      icon: Icon(Icons.add_location_alt, size: 17, color: poi.color),
                      label: Text('Waypoint', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: poi.color)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: _saved ? Colors.green : Colors.grey[400]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: _saved ? Colors.green.withOpacity(0.05) : null,
                    ),
                    onPressed: _saved ? null : _savePlace,
                    icon: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                      size: 17,
                      color: _saved ? Colors.green : Colors.grey[600],
                    ),
                    label: Text(
                      _saved ? 'Saved!' : 'Save Place',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _saved ? Colors.green : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
