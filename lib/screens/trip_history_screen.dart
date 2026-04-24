import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_trips') ?? '[]';
    if (mounted) {
      setState(() {
        _trips = List<Map<String, dynamic>>.from(json.decode(raw));
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Remove all trip history? This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All',
                style: GoogleFonts.poppins(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_trips');
    setState(() => _trips = []);
  }

  Future<void> _deleteSingleTrip(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _trips.removeAt(index);
    await prefs.setString('saved_trips', json.encode(_trips));
    setState(() {});
  }

  void _relaunchTrip(Map<String, dynamic> trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          useCurrentLocation: trip['useCurrentLocation'] as bool? ?? false,
          source: trip['source'] as String? ?? '',
          destination: trip['destination'] as String? ?? '',
          sourceLat: (trip['sourceLat'] as num?)?.toDouble(),
          sourceLon: (trip['sourceLon'] as num?)?.toDouble(),
          destLat: (trip['destLat'] as num?)?.toDouble(),
          destLon: (trip['destLon'] as num?)?.toDouble(),
        ),
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Trip History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (_trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF065A60)))
          : _trips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  color: const Color(0xFF065A60),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) =>
                        _buildTripCard(_trips[index], index),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
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
              child: const Icon(Icons.history_rounded,
                  size: 50, color: Color(0xFF065A60)),
            ),
            const SizedBox(height: 20),
            Text('No Trip History',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(
              'Your planned routes will appear here so you can re-launch them anytime.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, int index) {
    final source = trip['source'] as String? ?? 'Start';
    final destination = trip['destination'] as String? ?? 'Destination';
    final date = _formatDate(trip['date'] as String?);
    final usedLocation = trip['useCurrentLocation'] as bool? ?? false;

    return Dismissible(
      key: Key('trip_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _deleteSingleTrip(index),
      child: Container(
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
            // Header strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF065A60), Color(0xFF0A7C85)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: Colors.white70, size: 15),
                  const SizedBox(width: 6),
                  Text('Past Route',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4)),
                  const Spacer(),
                  if (date.isNotEmpty)
                    Text(date,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source
                  Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF065A60).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.radio_button_checked,
                          size: 15, color: Color(0xFF065A60)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        usedLocation ? '📍 Your Location' : source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E)),
                      ),
                    ),
                  ]),

                  Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                            width: 2,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.grey[300]),
                      ),
                    ),
                  ),

                  // Destination
                  Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on,
                          size: 15, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E)),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 14),

                  // Re-launch button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065A60),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: Text('Re-Launch Route',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () => _relaunchTrip(trip),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
