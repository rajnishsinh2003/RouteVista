import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'monthly_tours_screen.dart';
import 'place_detail_screen.dart';
import 'hotel_detail_screen.dart';
import 'quick_service_screen.dart';
import 'weather_screen.dart';
import 'budget_screen.dart';
import 'explore_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import '../widgets/section_header.dart';
import '../widgets/tour_card.dart';
import '../widgets/hotel_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/quick_action_tile.dart';
import 'trip_history_screen.dart';
import 'chatbot_screen.dart';
import 'search_screen.dart';
import '../services/notification_service.dart';
import '../models/place_model.dart';
import '../services/place_service.dart';
import '../services/bookmark_service.dart';
import 'state_places_screen.dart';
import 'all_states_screen.dart';
import 'trending_places_screen.dart';
import 'flight_screen.dart';
import 'train_screen.dart';
import 'all_hotels_screen.dart';
import '../services/hotel_service.dart';
import '../models/hotel_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // FIX #1: Always start empty — never restored from storage
  final _sourceController = TextEditingController();
  final _savedScreenKey = GlobalKey<SavedScreenState>();
  final _destController = TextEditingController();
  bool _useCurrentLocation = false;
  int _currentNavIndex = 0;
  String _selectedCategory = 'All';
  Set<String> _bookmarkedTours = {};
  List<Map<String, dynamic>> _recentTrips = [];
  Map<String, int> _categoryAffinity = {};
  String _userName = 'Traveler';

  double? _sourceLat, _sourceLon;
  double? _destLat, _destLon;

  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];
  bool _showSourceSuggestions = false;
  bool _showDestSuggestions = false;
  Timer? _sourceDebounce;
  Timer? _destDebounce;
  bool _isGettingLocation = false;

  final List<String> _indianStates = const [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu Kashmir',
    'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
    'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh',
    'Uttarakhand', 'West Bengal'
  ];

  Future<List<HotelModel>>? _hotelsFuture;
  String _userState = 'maharashtra';

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.all_inclusive, 'label': 'All', 'color': const Color(0xFF065A60)},
    {'icon': Icons.temple_hindu, 'label': 'Religious', 'color': Colors.purple},
    {'icon': Icons.account_balance, 'label': 'Historical', 'color': Colors.brown},
    {'icon': Icons.forest, 'label': 'Nature', 'color': Colors.green},
    {'icon': Icons.restaurant, 'label': 'Food', 'color': Colors.orange},
    {'icon': Icons.hotel, 'label': 'Hotels', 'color': Colors.indigo},
  ];

  List<Map<String, dynamic>> get _filteredTours => []; // Obsolete

  @override
  void initState() {
    super.initState();
    // FIX #1: Do NOT call _loadSavedRoute() — fields always start empty
    _loadRecentTrips();
    _listenToBookmarks();
    _loadAffinity();
    _fetchDashboardHotels();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('user_name');
    final fbName = FirebaseAuth.instance.currentUser?.displayName;
    
    if (mounted) {
      setState(() {
        if (localName != null && localName.trim().isNotEmpty) {
          _userName = localName.trim();
        } else if (fbName != null && fbName.trim().isNotEmpty) {
          _userName = fbName.trim();
        } else {
          _userName = 'Traveler';
        }
      });
    }
  }

  Future<void> _fetchDashboardHotels() async {
    String stateName = 'maharashtra'; // fallback
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
          final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1');
          final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final addr = data['address'] ?? {};
            final state = addr['state'] ?? addr['county'] ?? 'maharashtra';
            stateName = state.toString();
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _userState = stateName;
        _hotelsFuture = HotelService.getNearbyHotels(stateName, count: 5);
      });
    }
  }

  void _listenToBookmarks() {
    BookmarkService.getBookmarkedPlaceIds().listen((ids) {
      if (mounted) {
        setState(() {
          _bookmarkedTours = ids;
        });
      }
    });
  }

  Future<void> _toggleBookmark(Map<String, dynamic> placeData) async {
    await BookmarkService.toggleBookmark(placeData);
    // The stream listener will update the UI
  }

  Future<void> _loadAffinity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('category_affinity') ?? '{}';
    if (mounted) {
      setState(() {
        _categoryAffinity = Map<String, int>.from(json.decode(raw));
      });
    }
  }

  Future<void> _trackActivity(String category) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _categoryAffinity[category] = (_categoryAffinity[category] ?? 0) + 1;
    });
    await prefs.setString('category_affinity', json.encode(_categoryAffinity));
  }

  Future<void> _loadRecentTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_trips') ?? '[]';
    if (mounted) {
      setState(() {
        final all = List<Map<String, dynamic>>.from(json.decode(raw));
        _recentTrips = all.take(5).toList();
      });
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final placesJson = prefs.getString('saved_places') ?? '[]';
    final places = List<Map<String, dynamic>>.from(json.decode(placesJson));
    if (mounted) {
      setState(() {
        _bookmarkedTours = places.map((p) => p['id'].toString()).toSet();
      });
    }
  }

  @override
  void dispose() {
    _sourceDebounce?.cancel();
    _destDebounce?.cancel();
    _sourceController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.length < 2) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=in',
      );
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        return data.map<Map<String, dynamic>>((item) => {
              'name': item['display_name'],
              'lat': item['lat'],
              'lon': item['lon'],
            }).toList();
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
    return [];
  }

  void _onSourceChanged(String value) {
    if (value == '📍 Your Location' || _useCurrentLocation) return;
    if (value.isEmpty) {
      if (mounted) {
        setState(() {
          _sourceSuggestions = [];
          _showSourceSuggestions = true; // Show "Use Current Location" even if empty
        });
      }
      return;
    }
    _sourceDebounce?.cancel();
    _sourceDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length >= 2) {
        final results = await _searchPlaces(value);
        if (mounted) {
          setState(() {
            _sourceSuggestions = results;
            _showSourceSuggestions = true;
            _useCurrentLocation = false;
          });
        }
      } else {
        if (mounted) setState(() => _showSourceSuggestions = true);
      }
    });
  }

  void _onDestChanged(String value) {
    _destDebounce?.cancel();
    _destDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length >= 2) {
        final results = await _searchPlaces(value);
        if (mounted) {
          setState(() {
            _destSuggestions = results;
            _showDestSuggestions = results.isNotEmpty;
          });
        }
      } else {
        if (mounted) setState(() => _showDestSuggestions = false);
      }
    });
  }

  Future<bool> _checkServices() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool connected;
    if (connectivityResult is List) {
      connected = (connectivityResult as List).any((r) => r != ConnectivityResult.none);
    } else {
      connected = connectivityResult != ConnectivityResult.none;
    }
    if (!connected) {
      _showError("No Internet Connection", "Please enable WiFi or Mobile Data.");
      return false;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Location Disabled", "Please enable GPS.");
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Permission Denied", "Location permission required.");
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError("Permission Permanently Denied", "Enable location permission from settings.");
      return false;
    }
    return true;
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // FIX #2: Reverse geocode to get real address name
  Future<void> _useCurrentLocationFunc() async {
    if (!await _checkServices()) return;
    setState(() {
      _isGettingLocation = true;
      _sourceController.text = 'Getting location...';
      _showSourceSuggestions = false;
      _useCurrentLocation = false;
    });
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Reverse geocode with Nominatim
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json'
        '&lat=${position.latitude}&lon=${position.longitude}&zoom=16&addressdetails=1',
      );
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      String addressName = 'My Location';
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[];
        final road = addr['road'] ?? addr['pedestrian'] ?? addr['suburb'];
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
        final state = addr['state'];
        if (road != null) parts.add(road);
        if (city != null) parts.add(city);
        if (state != null) parts.add(state);
        if (parts.isNotEmpty) {
          addressName = parts.join(', ');
        } else {
          addressName = (data['display_name'] as String?)
                  ?.split(',')
                  .take(2)
                  .join(',')
                  .trim() ??
              'My Location';
        }
      }
      if (mounted) {
        setState(() {
          _useCurrentLocation = true;
          _sourceController.text = addressName;
          _sourceLat = position.latitude;
          _sourceLon = position.longitude;
          _isGettingLocation = false;
          _showSourceSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _sourceController.text = '';
          _useCurrentLocation = false;
        });
        _showError('Location Error', 'Could not get your location. Please try again.');
      }
    }
  }

  Future<void> _startTrip() async {
    if (_destController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a destination", style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (!await _checkServices()) return;

    final prefs = await SharedPreferences.getInstance();
    // FIX #1: Do NOT save source/dest to prefs (they must not restore on restart)
    // Save trip history only
    final tripsJson = prefs.getString('saved_trips') ?? '[]';
    final trips = List<Map<String, dynamic>>.from(json.decode(tripsJson));
    trips.insert(0, {
      'source': _sourceController.text,
      'destination': _destController.text,
      'sourceLat': _sourceLat,
      'sourceLon': _sourceLon,
      'destLat': _destLat,
      'destLon': _destLon,
      'useCurrentLocation': _useCurrentLocation,
      'date': DateTime.now().toString().split(' ')[0],
    });
    await prefs.setString('saved_trips', json.encode(trips.take(20).toList()));

    // Notify user
    NotificationService().showNotification(
      id: 1,
      title: '🛰️ Navigation Starting',
      body: 'Heading to ${_destController.text}... Drive safely!',
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          useCurrentLocation: _useCurrentLocation,
          source: _sourceController.text,
          destination: _destController.text,
          sourceLat: _sourceLat,
          sourceLon: _sourceLon,
          destLat: _destLat,
          destLon: _destLon,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeBody(),
          const ExploreScreen(),
          const MonthlyToursScreen(),
          SavedScreen(key: _savedScreenKey),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentNavIndex == 0 
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF00BFA6),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon/icon.png', width: 30, height: 30, fit: BoxFit.contain),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotScreen()),
              ),
            )
          : null,
    );
  }

  Widget _buildHomeBody() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: true,
          snap: true,
          backgroundColor: const Color(0xFF065A60),
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Hello, $_userName! 👋',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text('RouteVista',
                                style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.history_rounded,
                              color: Colors.white, size: 22),
                          tooltip: 'Trip History',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TripHistoryScreen()),
                            ).then((_) => _loadRecentTrips());
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 🔔 Notification Bell
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded,
                              color: Colors.white, size: 22),
                          tooltip: 'Notifications',
                          onPressed: () {
                            NotificationService().showNotification(
                              title: '🔔 RouteVista Updates',
                              body: 'Stay tuned for weather alerts and trip reminders!',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() => _currentNavIndex = 4),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BFA6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildRoutePlannerCard(),
              const SizedBox(height: 24),
              
              // ── Explore by State ──────────────────────────────
              SectionHeader(
                title: 'Explore by State', 
                emoji: '🗺️', 
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllStatesScreen(states: _indianStates),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _indianStates.length,
                  itemBuilder: (context, index) {
                    final state = _indianStates[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatePlacesScreen(stateName: state),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            state,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),
              
              // ── Trending in India ──────────────────────────────
              SectionHeader(
                title: 'Trending in India', 
                emoji: '🔥', 
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrendingPlacesScreen(
                        bookmarkedTours: _bookmarkedTours,
                        onToggleBookmark: _toggleBookmark,
                        onNavigate: (placeName) {
                          setState(() {
                            _destController.text = placeName;
                            _destLat = null;
                            _destLon = null;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<PlaceModel>>(
                future: PlaceService.getTrendingPlaces(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF00BFA6))),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  List<PlaceModel> trendingPlaces = snapshot.data!;
                  
                  // Apply category filter
                  if (_selectedCategory != 'All') {
                    trendingPlaces = trendingPlaces.where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
                  }
                  
                  if (trendingPlaces.isEmpty) {
                    return SizedBox(
                      height: 100,
                      child: Center(child: Text('No $_selectedCategory places found.', style: GoogleFonts.poppins(color: Colors.grey))),
                    );
                  }
                  
                  return SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 20),
                      itemCount: trendingPlaces.length,
                      itemBuilder: (context, index) {
                        final place = trendingPlaces[index];
                        final id = place.name.toLowerCase().replaceAll(' ', '_');
                        final isBookmarked = _bookmarkedTours.contains(id);
                        
                        return TourCard(
                          name: place.name,
                          location: place.state,
                          imageUrl: place.imageUrl,
                          rating: place.rating,
                          isBookmarked: isBookmarked,
                          onBookmark: () => _toggleBookmark({
                            'name': place.name,
                            'location': place.state,
                            'image': place.imageUrl,
                            'rating': place.rating,
                            'category': place.category,
                            'description': place.description,
                          }),
                          onTap: () {
                            PlaceService.updatePlaceDetailsIfNeeded(place);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaceDetailScreen(
                                  name: place.name,
                                  location: place.state,
                                  imageUrl: place.imageUrl,
                                  rating: place.rating,
                                  category: place.category,
                                  description: place.description,
                                  highlights: place.highlights,
                                  onSave: () => _toggleBookmark({
                                     'name': place.name,
                                     'location': place.state,
                                     'image': place.imageUrl,
                                     'rating': place.rating,
                                     'category': place.category,
                                     'description': place.description,
                                  }),
                                  onNavigate: () {
                                    setState(() {
                                      _destController.text = place.name;
                                      _destLat = null;
                                      _destLon = null;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // ── Popular Hotels ───────────────────────────
              SectionHeader(
                title: 'Hotels Near You', 
                emoji: '🏨', 
                onSeeAll: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => AllHotelsScreen(locationState: _userState))
                  );
                }
              ),
              const SizedBox(height: 8),
              if (_hotelsFuture == null)
                const SizedBox(
                  height: 195,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF065A60))),
                )
              else
                FutureBuilder<List<HotelModel>>(
                  future: _hotelsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 195,
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF065A60))),
                      );
                    }
                    final hotels = snapshot.data ?? [];
                    if (hotels.isEmpty) {
                      return const SizedBox(
                        height: 195,
                        child: Center(child: Text('No hotels found nearby.')),
                      );
                    }
                    return SizedBox(
                      height: 195,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 20),
                        itemCount: hotels.length,
                        itemBuilder: (context, index) {
                          final hotel = hotels[index];
                          return HotelCard(
                            name: hotel.name,
                            imageUrl: hotel.imageUrl,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HotelDetailScreen(
                                    name: hotel.name,
                                    imageUrl: hotel.imageUrl,
                                    location: hotel.location,
                                    description: hotel.description,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 28),
              SectionHeader(title: 'Quick Services', emoji: '⚡'),
              const SizedBox(height: 8),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),
              // ── Recent Routes ───────────────────────────
              if (_recentTrips.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Row(children: [
                        Text('🕒 ',
                            style: const TextStyle(fontSize: 18)),
                        Text('Recent Routes',
                            style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A2E))),
                      ]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TripHistoryScreen()),
                      ).then((_) => _loadRecentTrips()),
                      child: Text('See All',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF065A60))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: _recentTrips.map((trip) {
                      final src = (trip['useCurrentLocation'] as bool? ?? false)
                          ? '📍 Your Location'
                          : (trip['source'] as String? ?? 'Start');
                      final dst = trip['destination'] as String? ?? 'Destination';
                      final date = trip['date'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF065A60).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.route_rounded,
                                color: Color(0xFF065A60), size: 20),
                          ),
                          title: Text(
                            '$src → $dst',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: date.isNotEmpty
                              ? Text(date,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: Colors.grey[500]))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.replay_rounded,
                                color: Color(0xFF065A60), size: 20),
                            tooltip: 'Re-launch',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapScreen(
                                    useCurrentLocation:
                                        trip['useCurrentLocation'] as bool? ?? false,
                                    source: trip['source'] as String? ?? '',
                                    destination:
                                        trip['destination'] as String? ?? '',
                                    sourceLat: (trip['sourceLat'] as num?)
                                        ?.toDouble(),
                                    sourceLon: (trip['sourceLon'] as num?)
                                        ?.toDouble(),
                                    destLat:
                                        (trip['destLat'] as num?)?.toDouble(),
                                    destLon:
                                        (trip['destLon'] as num?)?.toDouble(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutePlannerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF065A60).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF065A60).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.route_rounded, color: Color(0xFF065A60), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Plan Your Route',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Source field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _sourceController,
              style: GoogleFonts.poppins(fontSize: 14),
              onChanged: _onSourceChanged,
              onTap: () {
                setState(() => _showDestSuggestions = false);
                _onSourceChanged(_sourceController.text);
              },
              decoration: InputDecoration(
                hintText: 'Start Location',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.circle_outlined,
                    color: Color(0xFF065A60), size: 18),
                suffixIcon: _isGettingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00BFA6)),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.gps_fixed_rounded,
                            color: Color(0xFF00BFA6), size: 20),
                        onPressed: _useCurrentLocationFunc,
                        tooltip: 'Use Current Location',
                      ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Source suggestions
          if (_showSourceSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.gps_fixed,
                        color: Color(0xFF00BFA6), size: 18),
                    title: Text('📍 Use Current Location',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onTap: () {
                      _useCurrentLocationFunc();
                      setState(() => _showSourceSuggestions = false);
                    },
                  ),
                  const Divider(height: 1),
                  ..._sourceSuggestions.map((s) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined,
                            size: 18, color: Colors.grey),
                        title: Text(
                          s['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        onTap: () {
                          _sourceController.text = s['name'].split(',')[0];
                          setState(() {
                            _sourceLat = double.tryParse(s['lat'].toString());
                            _sourceLon = double.tryParse(s['lon'].toString());
                            _showSourceSuggestions = false;
                            _useCurrentLocation = false;
                          });
                        },
                      )),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              children: List.generate(
                3,
                (i) => Container(
                  width: 2,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065A60).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),

          // Destination field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _destController,
              style: GoogleFonts.poppins(fontSize: 14),
              onChanged: _onDestChanged,
              onTap: () => setState(() => _showSourceSuggestions = false),
              decoration: InputDecoration(
                hintText: 'Destination',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.location_on,
                    color: Colors.redAccent, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Destination suggestions
          if (_showDestSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _destSuggestions
                    .map((s) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined,
                              size: 18, color: Colors.grey),
                          title: Text(
                            s['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          onTap: () {
                            _destController.text = s['name'].split(',')[0];
                            setState(() {
                              _destLat = double.tryParse(s['lat'].toString());
                              _destLon = double.tryParse(s['lon'].toString());
                              _showDestSuggestions = false;
                            });
                          },
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFF065A60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _startTrip,
              icon: const Icon(Icons.explore_rounded, size: 22),
              label: Text('PLAN ROUTE',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {'icon': Icons.restaurant_rounded, 'label': 'Restaurants', 'color': Colors.orange},
      {'icon': Icons.local_gas_station_rounded, 'label': 'Fuel Stations', 'color': Colors.blueGrey},
      {'icon': Icons.local_hospital_rounded, 'label': 'Hospitals', 'color': Colors.red},
      {'icon': Icons.local_police_rounded, 'label': 'Police', 'color': Colors.blue},
      {'icon': Icons.cloud_rounded, 'label': 'Weather', 'color': Colors.cyan},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Budget', 'color': Colors.green},
      {'icon': Icons.flight_takeoff_rounded, 'label': 'Flights', 'color': Colors.indigo},
      {'icon': Icons.train_rounded, 'label': 'Trains', 'color': Colors.brown},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return QuickActionTile(
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            onTap: () {
              final label = action['label'] as String;
              if (label == 'Weather') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
              } else if (label == 'Budget') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
              } else if (label == 'Flights') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FlightScreen()));
              } else if (label == 'Trains') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainScreen()));
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickServiceScreen(
                      category: label,
                      icon: action['icon'] as IconData,
                      color: action['color'] as Color,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('💎 PREMIUM',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFD700),
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 10),
                Text('Upgrade to RouteVista Pro',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Offline maps, AI trip planner, ad-free experience',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Explore Plans',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700), size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildDealsSection() {
    final deals = [
      {
        'title': '30% Off Hotels',
        'subtitle': 'Book partner hotels & save big',
        'icon': Icons.hotel_rounded,
        'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      },
      {
        'title': 'Free Fuel Card',
        'subtitle': 'Get ₹200 fuel credit on first trip',
        'icon': Icons.local_gas_station_rounded,
        'gradient': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
      },
      {
        'title': 'Food Combo',
        'subtitle': 'Flat 20% off on route restaurants',
        'icon': Icons.fastfood_rounded,
        'gradient': [const Color(0xFFF7971E), const Color(0xFFFFD200)],
      },
    ];
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 10),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return Container(
            width: 230,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: deal['gradient'] as List<Color>,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(deal['title'] as String,
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(deal['subtitle'] as String,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Claim Now',
                            style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Icon(deal['icon'] as IconData,
                    size: 36, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdBannerSlot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text('Ad Space — AdMob Integration',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.explore_rounded, 'Explore'),
              _buildNavItem(2, Icons.calendar_month_rounded, 'Tours'),
              _buildNavItem(3, Icons.bookmark_rounded, 'Saved'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
        if (index == 3) _savedScreenKey.currentState?.reload();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF065A60).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: isActive ? const Color(0xFF065A60) : Colors.grey[400]),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF065A60))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SearchScreen(hotels: []),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF065A60), size: 20),
            const SizedBox(width: 12),
            Text(
              'Where to next?',
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF065A60).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFF065A60), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
