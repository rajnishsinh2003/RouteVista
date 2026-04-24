import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';

class OfflineRoutesScreen extends StatefulWidget {
  const OfflineRoutesScreen({super.key});

  @override
  State<OfflineRoutesScreen> createState() => _OfflineRoutesScreenState();
}

class _OfflineRoutesScreenState extends State<OfflineRoutesScreen> {
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_routes') ?? '[]';
    if (mounted) {
      setState(() {
        _routes = List<Map<String, dynamic>>.from(json.decode(raw));
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRoute(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Route',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "${_routes[index]['source']} → ${_routes[index]['destination']}" from offline routes?',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    _routes.removeAt(index);
    await prefs.setString('offline_routes', json.encode(_routes));
    setState(() {});
  }

  void _openRoute(Map<String, dynamic> route) {
    final points = route['points'] as List? ?? [];
    double? srcLat, srcLon, dstLat, dstLon;
    if (points.length >= 2) {
      srcLat = (points.first['lat'] as num).toDouble();
      srcLon = (points.first['lon'] as num).toDouble();
      dstLat = (points.last['lat'] as num).toDouble();
      dstLon = (points.last['lon'] as num).toDouble();
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          useCurrentLocation: false,
          source: route['source'] as String,
          destination: route['destination'] as String,
          sourceLat: srcLat,
          sourceLon: srcLon,
          destLat: dstLat,
          destLon: dstLon,
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(dynamic hrs) {
    if (hrs == null) return '';
    final h = (hrs as num).toDouble();
    if (h < 1) return '${(h * 60).round()} min';
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return mm == 0 ? '${hh}h' : '${hh}h ${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF065A60)));
    }

    if (_routes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF065A60).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.offline_pin_outlined,
                    size: 48, color: Color(0xFF065A60)),
              ),
              const SizedBox(height: 20),
              Text('No Offline Routes',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Text(
                'Plan a route on the map and tap the download icon to save it for offline use.',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      color: const Color(0xFF065A60),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (context, index) => _buildCard(_routes[index], index),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> route, int index) {
    final distKm = route['distKm'] as num?;
    final durationHrs = route['durationHrs'];
    final pointCount = (route['points'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── header strip ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF065A60), Color(0xFF0A7C85)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_pin,
                    color: Colors.white70, size: 15),
                const SizedBox(width: 6),
                Text(
                  (route['name'] as String?)?.isNotEmpty == true
                      ? (route['name'] as String)
                      : 'Offline Route',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Transport mode badge
                if (route['transportMode'] != null) ...[
                  Text(
                    _modeEmoji(route['transportMode'] as String),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(_formatDate(route['savedAt'] as String?),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),

          // ── body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source → Destination
                Row(children: [
                  const Icon(Icons.radio_button_checked,
                      size: 17, color: Color(0xFF065A60)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(route['source'] ?? 'Start',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E))),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: List.generate(
                        3,
                        (_) => Container(
                            width: 2,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.grey[300])),
                  ),
                ),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 17, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(route['destination'] ?? 'Destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E))),
                  ),
                ]),

                const SizedBox(height: 14),

                // Stats chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (distKm != null)
                      _statChip(Icons.straighten,
                          '${distKm.toStringAsFixed(1)} km'),
                    if (durationHrs != null)
                      _statChip(Icons.schedule,
                          _formatDuration(durationHrs)),
                    _statChip(Icons.map, '$pointCount pts'),
                    if (route['transportMode'] != null)
                      _modeChip(route['transportMode'] as String),
                  ],
                ),

                const SizedBox(height: 14),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065A60),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: Text('Open Route',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      onPressed: () => _openRoute(route),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _deleteRoute(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: const Color(0xFF065A60)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E))),
      ]),
    );
  }

  String _modeEmoji(String mode) {
    switch (mode) {
      case 'walking': return '🚶 Walk';
      case 'cycling': return '🚲 Cycle';
      default:        return '🚗 Drive';
    }
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'walking': return const Color(0xFF8E44AD);
      case 'cycling': return const Color(0xFFE67E22);
      default:        return const Color(0xFF065A60);
    }
  }

  Widget _modeChip(String mode) {
    final color = _modeColor(mode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _modeEmoji(mode),
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
