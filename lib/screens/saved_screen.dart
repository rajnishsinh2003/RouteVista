import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'offline_routes_screen.dart';
import 'map_screen.dart';
import 'place_detail_screen.dart';
import '../services/bookmark_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    _loadAll(); 
    _listenToBookmarks(); // Listen to Firestore bookmarks
  }

  void _listenToBookmarks() {
    BookmarkService.getBookmarkedPlaceIds().listen((ids) {
      if (mounted) {
        setState(() {
          // We don't need the full list here since the list view uses its own StreamBuilder,
          // but we need the count for the tab header.
          _savedPlaces = ids.map((id) => {'id': id}).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Called from HomeScreen when Saved tab is selected
  Future<void> reload() => _loadAll();

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString('saved_trips') ?? '[]';
    final offlineJson = prefs.getString('offline_routes') ?? '[]';
    // Places are now handled via Firestore stream
    if (mounted) {
      setState(() {
        _savedTrips = List<Map<String, dynamic>>.from(json.decode(tripsJson));
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

  Future<void> _removePlace(String placeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('place_bookmarks')
        .doc(placeId)
        .delete();
    // No need to call setState here, StreamBuilder will handle it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Your bookmarked routes and places',
                    style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.poppins(),
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
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
                  ? Center(
                      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      useCurrentLocation: trip['useCurrentLocation'] as bool? ?? false,
                      source: trip['source'] as String? ?? 'Current Location',
                      destination: trip['destination'] as String? ?? 'Destination',
                      sourceLat: (trip['sourceLat'] as num?)?.toDouble(),
                      sourceLon: (trip['sourceLon'] as num?)?.toDouble(),
                      destLat: (trip['destLat'] as num?)?.toDouble(),
                      destLon: (trip['destLon'] as num?)?.toDouble(),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.route, color: Theme.of(context).primaryColor),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlacesList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildEmpty(
        'Login to see saved places',
        'Your bookmarks are synced to your account.',
        Icons.login,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('place_bookmarks')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            'No saved places yet',
            'Tap the bookmark icon on any place to save it here',
            Icons.bookmark_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final place = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaceDetailScreen(
                        name: place['name'] ?? 'Unknown Place',
                        location: place['location'] ?? '',
                        imageUrl: place['image'] ?? '',
                        rating: (place['rating'] as num?)?.toDouble() ?? 4.5,
                        category: place['category'] ?? 'General',
                        description: place['description'] ?? '',
                        highlights: List<String>.from(place['highlights'] ?? []),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    if (place['image'] != null && place['image'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          place['image'],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 60,
                            color: Theme.of(context).primaryColor.withOpacity(0.08),
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
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
                              color: Theme.of(context).primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.place, color: Theme.of(context).primaryColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place['name'] ?? 'Unknown Place',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                if (place['location'] != null)
                                  Text(
                                    place['location'],
                                    style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _removePlace(docId),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              color: Theme.of(context).primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 48, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
