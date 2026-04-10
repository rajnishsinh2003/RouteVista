import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'offline_routes_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => SavedScreenState();
}

class SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _savedTrips = [];
  List<Map<String, dynamic>> _savedPlaces = [];
  List<Map<String, dynamic>> _offlineRoutes = [];
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll(); // FIX #4: Always load on init
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Called from HomeScreen when Saved tab is selected
  Future<void> reload() => _loadAll();

  // FIX #4: Proper load with setState — reads BOTH trips and places
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString('saved_trips') ?? '[]';
    final placesJson = prefs.getString('saved_places') ?? '[]';
    final offlineJson = prefs.getString('offline_routes') ?? '[]';
    if (mounted) {
      setState(() {
        _savedTrips = List<Map<String, dynamic>>.from(json.decode(tripsJson));
        _savedPlaces = List<Map<String, dynamic>>.from(json.decode(placesJson));
        _offlineRoutes = List<Map<String, dynamic>>.from(json.decode(offlineJson));
        _isLoading = false;
      });
    }
  }

  Future<void> _removeTrip(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _savedTrips.removeAt(index);
    await prefs.setString('saved_trips', json.encode(_savedTrips));
    setState(() {});
  }

  Future<void> _removePlace(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _savedPlaces.removeAt(index);
    await prefs.setString('saved_places', json.encode(_savedPlaces));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'Your bookmarked routes and places',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.poppins(),
                    labelColor: const Color(0xFF065A60),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF065A60),
                    tabs: [
                      Tab(text: 'Trips (${_savedTrips.length})'),
                      Tab(text: 'Places (${_savedPlaces.length})'),
                      Tab(text: 'Offline (${_offlineRoutes.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF065A60)),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTripsList(),
                        _buildPlacesList(),
                        const OfflineRoutesScreen(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    if (_savedTrips.isEmpty) {
      return _buildEmpty(
        'No saved trips yet',
        'Plan a route to see it here',
        Icons.route,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedTrips.length,
        itemBuilder: (context, index) {
          final trip = _savedTrips[index];
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
                    color: const Color(0xFF065A60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.route, color: Color(0xFF065A60)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip['source']} → ${trip['destination']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        trip['date'] ?? 'Recently planned',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _removeTrip(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlacesList() {
    if (_savedPlaces.isEmpty) {
      return _buildEmpty(
        'No saved places yet',
        'Tap "Save Place" on any map marker\nor tour destination to save it here',
        Icons.bookmark_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedPlaces.length,
        itemBuilder: (context, index) {
          final place = _savedPlaces[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            child: Column(
              children: [
                if (place['image'] != null)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      place['image'],
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        color: const Color(0xFF065A60).withOpacity(0.08),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF065A60).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.place,
                            color: Color(0xFF065A60), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place['name'] ?? 'Unknown Place',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            if (place['location'] != null)
                              Text(
                                place['location'],
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (place['category'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF065A60).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  place['category'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF065A60),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (place['rating'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                place['rating'].toString(),
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _removePlace(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle, IconData icon) {
    return Center(
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
            child: Icon(icon, size: 48, color: const Color(0xFF065A60)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}
