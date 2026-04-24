import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../models/poi.dart';
import '../services/poi_service.dart';
import '../services/navigation_service.dart';
import '../widgets/poi_filter_bar.dart';
import '../widgets/poi_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  final bool useCurrentLocation;
  final String source;
  final String destination;
  final double? sourceLat;
  final double? sourceLon;
  final double? destLat;
  final double? destLon;

  const MapScreen({
    super.key,
    required this.useCurrentLocation,
    required this.source,
    required this.destination,
    this.sourceLat,
    this.sourceLon,
    this.destLat,
    this.destLon,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final DraggableScrollableController sheetController = DraggableScrollableController();

  LatLng? sourceLatLng;
  LatLng? destinationLatLng;
  LatLng? currentLocation;
  List<LatLng> routePoints = [];

  // ── Waypoint model (rich) ────────────────────
  final List<_WaypointModel> _waypoints = [];

  // Proximity alert state per waypoint
  final Set<int> _approachingAlerted = {}; // index → 100m triggered
  final Set<int> _reachedAlerted    = {}; // index → 20m triggered

  // ── Dynamic route coloring ───────────────────
  List<LatLng> _traveledPoints = [];   // GREEN — already passed
  List<LatLng> _remainingPoints = [];  // RED   — still ahead
  int _currentRouteIndex = 0;

  // ── Old POI system (kept for compatibility) ──
  List<TripPOI> allPlaces = [];
  List<TripPOI> filteredPlaces = [];
  TripBudget budget = TripBudget();
  WeatherInfo? destWeather;

  // ── New full POI system ──────────────────────
  final PoiService _poiService = PoiService();
  List<PoiModel> _allPois = [];
  List<PoiModel> _visiblePois = [];
  Set<String> _activeCategories = {};
  bool _isFetchingPois = false;
  int _poiFetchDone = 0;
  int _poiFetchTotal = 0;
  bool _poisLoaded = false;
  bool _showPoiList = false;
  int _poiListPage = 0;
  static const int _pageSize = 100;

  bool isLoading = true;
  bool isNavigating = false;
  bool _isMuted = false;
  String selectedFilter = 'All';
  String statusMessage = "Preparing route...";
  double totalDistKm = 0;
  double durationHrs = 0;

  VehicleType selectedVehicle = VehicleType.car;
  FuelType selectedFuel = FuelType.petrol;
  double currentFuelLitres = 0;
  double vehicleAverage = 15;

  // ── Transport Mode ───────────────────────────
  String _transportMode = 'driving'; // driving, walking, cycling
  static const Map<String, Map<String, dynamic>> _transportModes = {
    'driving': {'icon': '🚗', 'label': 'Drive',  'color': Color(0xFF065A60)},
    'walking': {'icon': '🚶', 'label': 'Walk',   'color': Color(0xFF8E44AD)},
    'cycling': {'icon': '🚲', 'label': 'Cycle',  'color': Color(0xFFE67E22)},
  };
  Map<String, dynamic> fuelStatus = {};

  // ── Map layer switcher ───────────────────────
  String _selectedLayer = 'Standard';
  bool _showLayerPicker = false;

  static const Map<String, String> _layerTiles = {
    'Standard':  'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    'Satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'Terrain':   'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    'Dark':      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  };

  static const Map<String, String> _layerEmoji = {
    'Standard':  '🗺️',
    'Satellite': '🛰️',
    'Terrain':   '🏔️',
    'Dark':      '🌙',
  };

  DateTime? navigationStartTime;
  double remainingKm = 0;
  bool showDriverRestAlert = false;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ConnectivityResult>? _connectivityStream;
  bool isOffline = false;
  bool isGpsOff = false;

  // ── Turn-by-turn navigation ──────────────────
  final FlutterTts _tts = FlutterTts();
  NavigationService? _navService;
  List<NavigationStep> _navSteps = [];
  String _currentInstruction = '';
  String _distanceToTurn = '';
  bool _hasArrived = false;

  // Offline save
  bool _routeSaved = false;
  bool _isSavingOffline = false;
  int _downloadProgress = 0;
  int _downloadTotal = 0;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initTts();
    _startMonitoring();
    _initializeTrip();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _connectivityStream?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── TTS initialisation ───────────────────────
  Future<void> _initTts() async {
    final prefs = await SharedPreferences.getInstance();
    String lang = prefs.getString('language_pref') ?? 'en-IN';
    
    // Cleanup/Normalize lang code for some engines
    if (lang == 'en-GB') lang = 'en-IN'; // Prefer Indian accent if possible

    try {
      // Check if language is available
      bool isAvailable = await _tts.isLanguageAvailable(lang);
      
      if (!isAvailable) {
        debugPrint('⚠️ Language $lang not strictly available. Probing alternates...');
        // Fallback checks for Gujarati which might be 'gu' or 'gu-IN'
        if (lang.startsWith('gu')) {
          if (await _tts.isLanguageAvailable('gu-IN')) lang = 'gu-IN';
          else if (await _tts.isLanguageAvailable('gu')) lang = 'gu';
        } else if (lang.startsWith('hi')) {
          if (await _tts.isLanguageAvailable('hi-IN')) lang = 'hi-IN';
          else if (await _tts.isLanguageAvailable('hi')) lang = 'hi';
        }
      }

      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // On some Androids, you must set the engine explicitly for better Indian support
      if (!kIsWeb && Platform.isAndroid) {
        await _tts.setEngine('com.google.android.tts');
      }
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty || _isMuted) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  void _startMonitoring() {
    _connectivityStream = Connectivity().onConnectivityChanged.listen((result) {
      setState(() => isOffline = result == ConnectivityResult.none);
    });
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Geolocator.getServiceStatusStream().listen((status) {
        setState(() => isGpsOff = status == ServiceStatus.disabled);
        if (isGpsOff && isNavigating) {
          _showErrorDialog("GPS Disabled", "Location services turned off. Navigation paused.");
        }
      });
    }
  }

  Future<void> _initializeTrip() async {
    var connectivity = await Connectivity().checkConnectivity();
    bool connected = connectivity is List
        ? (connectivity as List).any((r) => r != ConnectivityResult.none)
        : connectivity != ConnectivityResult.none;

    if (!connected) {
      setState(() { isOffline = true; });
      // Try to restore from saved offline route before giving up
      final loaded = await _tryLoadOfflineRoute();
      if (!loaded) {
        setState(() { isLoading = false; statusMessage = "No Internet. No offline route found for this trip."; });
      }
      return;
    }

    await _checkPermissions();

    if (widget.useCurrentLocation) {
      if (widget.sourceLat != null && widget.sourceLon != null) {
        sourceLatLng = LatLng(widget.sourceLat!, widget.sourceLon!);
      } else {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        sourceLatLng = LatLng(p.latitude, p.longitude);
      }
      currentLocation = sourceLatLng;
    } else if (widget.sourceLat != null && widget.sourceLon != null) {
      sourceLatLng = LatLng(widget.sourceLat!, widget.sourceLon!);
    } else {
      sourceLatLng = await _getCoordinates(widget.source);
    }

    if (widget.destLat != null && widget.destLon != null) {
      destinationLatLng = LatLng(widget.destLat!, widget.destLon!);
    } else {
      destinationLatLng = await _getCoordinates(widget.destination);
    }

    if (sourceLatLng == null || destinationLatLng == null) {
      setState(() { isLoading = false; statusMessage = "Could not find locations."; });
      return;
    }

    setState(() => statusMessage = "Calculating best route...");
    await _fetchRoute(sourceLatLng!, destinationLatLng!);
    _calculateBudget();

    setState(() => statusMessage = "Fetching weather...");
    destWeather = await _fetchWeather(destinationLatLng!);

    setState(() { isLoading = false; remainingKm = totalDistKm; });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (routePoints.isNotEmpty) {
        mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routePoints),
          padding: const EdgeInsets.all(50),
        ));
      }
    });

    // Start POI fetch after map is shown
    if (routePoints.isNotEmpty) {
      _startPoiFetch();
      _saveToHistory();
    }
  }

  // ── Load saved offline route when there's no internet ───────────────────
  Future<bool> _tryLoadOfflineRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_routes') ?? '[]';
      final all = List<Map<String, dynamic>>.from(json.decode(raw));
      if (all.isEmpty) return false;

      // Match by source + destination (case-insensitive trim)
      final src = widget.source.trim().toLowerCase();
      final dst = widget.destination.trim().toLowerCase();
      Map<String, dynamic>? match;
      for (final r in all) {
        final rs = (r['source'] as String? ?? '').trim().toLowerCase();
        final rd = (r['destination'] as String? ?? '').trim().toLowerCase();
        if (rs == src && rd == dst) { match = r; break; }
      }

      // Also accept if coordinates match (when opened from OfflineRoutesScreen)
      if (match == null && widget.sourceLat != null && widget.destLat != null) {
        for (final r in all) {
          final points = r['points'] as List? ?? [];
          if (points.length >= 2) {
            final fLat = (points.first['lat'] as num).toDouble();
            final lLat = (points.last['lat'] as num).toDouble();
            if ((fLat - widget.sourceLat!).abs() < 0.001 &&
                (lLat - widget.destLat!).abs() < 0.001) {
              match = r; break;
            }
          }
        }
      }

      if (match == null) return false;

      final points = match['points'] as List;
      final loaded = points
          .map<LatLng>((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lon'] as num).toDouble()))
          .toList();

      if (loaded.isEmpty) return false;

      sourceLatLng      = loaded.first;
      destinationLatLng = loaded.last;
      currentLocation   = widget.useCurrentLocation ? loaded.first : null;

      setState(() {
        routePoints  = loaded;
        totalDistKm  = (match!['distKm'] as num?)?.toDouble() ?? 0;
        durationHrs  = (match['durationHrs'] as num?)?.toDouble() ?? 0;
        remainingKm  = totalDistKm;
        isLoading    = false;
        statusMessage = 'Loaded from offline storage';
        _routeSaved  = true; // already saved — don't show download button
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (routePoints.isNotEmpty) {
          mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(routePoints),
            padding: const EdgeInsets.all(50),
          ));
        }
      });

      return true;
    } catch (e) {
      debugPrint('Offline route load error: $e');
      return false;
    }
  }

  // ── Start full POI fetch ─────────────────────
  Future<void> _startPoiFetch() async {
    setState(() {
      _isFetchingPois = true;
      _poiFetchDone = 0;
      _poiFetchTotal = 0;
      _poisLoaded = false;
      _allPois = [];
      _visiblePois = [];
      _activeCategories = {};
      _poiListPage = 0;
    });

    await _poiService.fetchAllPois(
      routePoints,
      onProgress: (done, total) {
        if (mounted) setState(() { _poiFetchDone = done; _poiFetchTotal = total; });
      },
      onBatch: (newPois) {
        if (mounted) {
          setState(() {
            _allPois.addAll(newPois);
            _allPois.sort((a, b) => a.indexAlongRoute.compareTo(b.indexAlongRoute));

            // Auto-enable any newly discovered categories
            _activeCategories.addAll(newPois.map((p) => p.category));
            
            _poisLoaded = true; // Unhide the UI as soon as first batch arrives
            _updateVisiblePois();
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isFetchingPois = false;
      });
    }
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_activeCategories.contains(cat)) {
        _activeCategories.remove(cat);
      } else {
        _activeCategories.add(cat);
      }
      _updateVisiblePois();
    });
  }

  void _updateVisiblePois() {
    _visiblePois = _allPois.where((p) => _activeCategories.contains(p.category)).toList();
    _poiListPage = 0;
  }

  List<PoiModel> get _currentPagePois {
    final end = math.min((_poiListPage + 1) * _pageSize, _visiblePois.length);
    return _visiblePois.sublist(0, end);
  }

  // ── Geocoding ───────────────────────────────
  Future<LatLng?> _getCoordinates(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      final data = json.decode(res.body);
      if (data is List && data.isNotEmpty) {
        return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
      }
    } catch (e) { debugPrint("Geocode Error: $e"); }
    return null;
  }

  // ── Route fetch (with step-level instructions) ──
  Future<void> _fetchRoute(LatLng start, LatLng end, {bool retainTraveled = false}) async {
    try {
      String coordsPath = '${start.longitude},${start.latitude};';
      for (final wp in _waypoints) {
        coordsPath += '${wp.latLng.longitude},${wp.latLng.latitude};';
      }
      coordsPath += '${end.longitude},${end.latitude}';

      // Map internal mode to OSRM profile
      final profile = _transportMode == 'walking' ? 'foot' : (_transportMode == 'cycling' ? 'bike' : 'driving');
      
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/$coordsPath'
        '?overview=full&geometries=geojson&steps=true&annotations=false',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final route = data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;

        // --- Parse step-level turn instructions ---
        final List<NavigationStep> steps = [];
        final legs = route['legs'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        final langCode = prefs.getString('language_pref') ?? 'en-IN';

        for (final leg in legs) {
          final legSteps = leg['steps'] as List? ?? [];
          for (final s in legSteps) {
            s['langCode'] = langCode;
            steps.add(NavigationStep.fromOsrm(s as Map<String, dynamic>));
          }
        }

        setState(() {
          final newRoutePoints = coords
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
              
          final double distKm = (route['distance'] as num).toDouble() / 1000;
          double duration;

          // Realistic duration based on mode (OSRM demo server often returns car time for all profiles)
          if (_transportMode == 'walking') {
            duration = distKm / 5.0; // 5 km/h
          } else if (_transportMode == 'cycling') {
            duration = distKm / 18.0; // 18 km/h
          } else {
            duration = (route['duration'] as num).toDouble() / 3600; // API provided duration for driving
          }

          if (retainTraveled && isNavigating) {
            _remainingPoints = newRoutePoints;
            routePoints = [..._traveledPoints, ..._remainingPoints];
            _currentRouteIndex = _traveledPoints.isNotEmpty ? _traveledPoints.length - 1 : 0;
            
            double traveledKmTotal = 0;
            for (int i = 0; i < _traveledPoints.length - 1; i++) {
              traveledKmTotal += NavigationService.haversineKm(_traveledPoints[i], _traveledPoints[i + 1]);
            }
            totalDistKm = traveledKmTotal + distKm;
            remainingKm = distKm;
            durationHrs = duration; // Remaining duration
          } else {
            routePoints = newRoutePoints;
            totalDistKm = distKm;
            remainingKm = totalDistKm;
            durationHrs = duration;
            _traveledPoints = [];
            _remainingPoints = List.of(routePoints);
            _currentRouteIndex = 0;
            _hasArrived = false;
          }
          
          _navSteps = steps;
        });
      }
    } catch (e) { debugPrint("Route Error: $e"); }
  }

  // ── Navigate to a place (reroute) ───────────
  Future<void> _navigateToPoi(LatLng dest) async {
    final start = currentLocation ?? sourceLatLng!;
    setState(() { statusMessage = "Rerouting..."; isLoading = true; });
    destinationLatLng = dest;
    await _fetchRoute(start, dest, retainTraveled: isNavigating);
    setState(() { isLoading = false; });
    if (routePoints.isNotEmpty && !isNavigating) {
      mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(routePoints),
        padding: const EdgeInsets.all(50),
      ));
    }
  }

  // ── Reverse-geocode a LatLng to a place name ─
  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json',
      );
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};
        // Prefer the most specific available label
        final name = address['amenity'] ??
            address['road'] ??
            address['neighbourhood'] ??
            address['suburb'] ??
            address['city'] ??
            address['town'] ??
            address['village'] ??
            data['display_name'] ??
            'Unknown Location';
        return name.toString();
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return 'Unknown Location';
  }

  // ── Add waypoint ─────────────────────────────
  Future<void> _addWaypoint(LatLng waypointLatLng) async {
    if (sourceLatLng == null || destinationLatLng == null) return;

    // Resolve name & compute straight-line distance from source first
    final name = await _reverseGeocode(waypointLatLng);
    final distKm = sourceLatLng != null
        ? NavigationService.haversineKm(sourceLatLng!, waypointLatLng)
        : 0.0;

    // ── Only update markers (no isLoading = full screen spinner) ──
    setState(() {
      _waypoints.add(_WaypointModel(
        latLng: waypointLatLng,
        name: name,
        distFromSourceKm: distKm,
      ));
      statusMessage = 'Waypoint added';
    });

    // Show confirmation snackbar immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📍 Waypoint added: $name', style: GoogleFonts.poppins()),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }

    // Now update route silently (no full-screen loader)
    final start = (isNavigating && currentLocation != null) ? currentLocation! : sourceLatLng!;
    await _fetchRoute(start, destinationLatLng!, retainTraveled: isNavigating);
    _calculateBudget();

    // Hot-reload navigation steps if already driving
    if (isNavigating) {
      _navService = NavigationService(steps: _navSteps);
      if (_navService!.hasSteps) {
        setState(() {
          _currentInstruction = _navService!.currentStep!.instruction;
          _distanceToTurn = _navService!.distanceToNextTurn;
        });
        _speak(_currentInstruction);
      }
    }

    if (routePoints.isNotEmpty && !isNavigating) {
      mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(routePoints),
        padding: const EdgeInsets.all(50),
      ));
    }
  }

  // ── Show Waypoint bottom sheet ─────────────────
  void _showWaypointOptions(_WaypointModel wp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaypointBottomSheet(
        waypoint: wp,
        onRemove: () {
          Navigator.pop(context);
          _removeWaypoint(wp);
        },
      ),
    );
  }

  // ── Remove Waypoint ──────────────────────────
  Future<void> _removeWaypoint(_WaypointModel wp) async {
    final removedName = wp.name;
    final idx = _waypoints.indexOf(wp);

    setState(() {
      _waypoints.remove(wp);
      // Reset proximity alerts for removed waypoint and shift higher indexes
      _approachingAlerted.remove(idx);
      _reachedAlerted.remove(idx);
      statusMessage = 'Removing waypoint...';
    });

    final start = (isNavigating && currentLocation != null) ? currentLocation! : sourceLatLng!;
    await _fetchRoute(start, destinationLatLng!, retainTraveled: isNavigating);
    _calculateBudget();

    if (isNavigating) {
      _navService = NavigationService(steps: _navSteps);
      if (_navService!.hasSteps) {
        setState(() {
          _currentInstruction = _navService!.currentStep!.instruction;
          _distanceToTurn = _navService!.distanceToNextTurn;
        });
        _speak(_currentInstruction);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Waypoint "$removedName" removed & route updated',
              style: GoogleFonts.poppins())),
        ]),
        backgroundColor: const Color(0xFF065A60),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _calculateBudget() {
    setState(() {
      budget = BudgetCalculator.calculate(
        distanceKm: totalDistKm,
        durationHrs: durationHrs,
        vehicle: selectedVehicle,
        fuelType: selectedFuel,
      );
    });
  }

  void _updateFuelStatus() {
    setState(() {
      fuelStatus = BudgetCalculator.checkFuelSufficiency(
        currentFuelLitres: currentFuelLitres,
        vehicleAverage: vehicleAverage,
        totalDistanceKm: totalDistKm,
      );
    });
  }

  Future<WeatherInfo?> _fetchWeather(LatLng loc) async {
    try {
      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current_weather=true",
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['current_weather'];
        return WeatherInfo(
          temp: (data['temperature'] as num).toDouble(),
          condition: _getWeatherString(data['weathercode']),
        );
      }
    } catch (_) {}
    return null;
  }

  String _getWeatherString(int code) {
    if (code == 0) return "Clear Sky";
    if (code < 3) return "Partly Cloudy";
    if (code < 60) return "Foggy";
    if (code < 80) return "Rainy";
    return "Stormy";
  }

  Future<void> _checkPermissions() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) await Geolocator.requestPermission();
  }

  void _toggleNavigation() {
    setState(() => isNavigating = !isNavigating);
    if (isNavigating) {
      navigationStartTime = DateTime.now();
      remainingKm = totalDistKm;
      _hasArrived = false;
      _currentRouteIndex = 0;
      _traveledPoints = [];
      _remainingPoints = List.of(routePoints);

      // Build nav service from current steps
      _navService = NavigationService(steps: _navSteps);
      if (_navService!.hasSteps) {
        setState(() {
          _currentInstruction = _navService!.currentStep!.instruction;
          _distanceToTurn = _navService!.distanceToNextTurn;
        });
        _speak(_currentInstruction);
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 8,
        ),
      ).listen((pos) => _onLocationUpdate(pos));
    } else {
      _positionStream?.cancel();
      _tts.stop();
      navigationStartTime = null;
      showDriverRestAlert = false;
      // Reset polyline split
      _traveledPoints = [];
      _remainingPoints = List.of(routePoints);
      if (routePoints.isNotEmpty) {
        mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routePoints),
          padding: const EdgeInsets.all(50),
        ));
      }
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_trips') ?? '[]';
      List<Map<String, dynamic>> trips = List<Map<String, dynamic>>.from(json.decode(raw));
      
      // Prevent duplicates (same source/dest on same day)
      final today = DateTime.now().toIso8601String().split('T')[0];
      bool exists = trips.any((t) => 
        t['source'] == widget.source && 
        t['destination'] == widget.destination &&
        (t['date'] ?? '').contains(today)
      );
      
      if (exists) return;

      trips.insert(0, {
        'source': widget.source,
        'destination': widget.destination,
        'sourceLat': sourceLatLng?.latitude,
        'sourceLon': sourceLatLng?.longitude,
        'destLat': destinationLatLng?.latitude,
        'destLon': destinationLatLng?.longitude,
        'useCurrentLocation': widget.useCurrentLocation,
        'date': DateTime.now().toIso8601String(),
        'distance': totalDistKm,
        'duration': durationHrs,
        'mode': _transportMode,
      });

      // Keep only last 20
      if (trips.length > 20) trips = trips.sublist(0, 20);

      await prefs.setString('saved_trips', json.encode(trips));
    } catch (e) {
      debugPrint('Save history error: $e');
    }
  }

  // ── Core location update handler ─────────────
  void _onLocationUpdate(Position pos) {
    final newLoc = LatLng(pos.latitude, pos.longitude);

    // ── 1. Split route into traveled / remaining ──
    final idx = NavigationService.closestIndex(newLoc, routePoints);
    if (idx >= _currentRouteIndex) {
      _currentRouteIndex = idx;
    }
    final traveled = routePoints.sublist(0, _currentRouteIndex + 1);
    final remaining = routePoints.sublist(_currentRouteIndex);

    // ── 2. Compute remaining distance (along-route, not straight-line) ──
    double remKm = 0;
    if (remaining.length >= 2) {
      // Insert current position as the very first point so we measure from
      // exactly where the user is, not from the snapped route index.
      final polyForCalc = [newLoc, ...remaining.skip(1)];
      for (int i = 0; i < polyForCalc.length - 1; i++) {
        remKm += NavigationService.haversineKm(polyForCalc[i], polyForCalc[i + 1]);
      }
    } else if (destinationLatLng != null) {
      remKm = NavigationService.haversineKm(newLoc, destinationLatLng!);
    }

    // ── 3. Waypoint proximity alerts ─────────────
    for (int i = 0; i < _waypoints.length; i++) {
      final wpDist = NavigationService.haversineKm(newLoc, _waypoints[i].latLng) * 1000; // metres
      if (wpDist <= 20 && !_reachedAlerted.contains(i)) {
        _reachedAlerted.add(i);
        _approachingAlerted.add(i);
        _speak('Waypoint reached: ${_waypoints[i].name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Text('✅ ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text('Waypoint reached: ${_waypoints[i].name}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
            ]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else if (wpDist <= 100 && !_approachingAlerted.contains(i)) {
        _approachingAlerted.add(i);
        _speak('Approaching waypoint: ${_waypoints[i].name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Text('📍 ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text('Approaching waypoint: ${_waypoints[i].name}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
            ]),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }

    // ── 4. Arrival check ─────────────────────────
    if (!_hasArrived && remKm < 0.05 && destinationLatLng != null) {
      _hasArrived = true;
      setState(() {
        currentLocation = newLoc;
        _traveledPoints = traveled;
        _remainingPoints = remaining;
        remainingKm = remKm;
        _currentInstruction = 'You have arrived at your destination';
        _distanceToTurn = '';
      });
      _speak('You have arrived at your destination!');
      return;
    }

    // ── 4. Step advancement & voice ──────────────
    if (_navService != null) {
      final advanced = _navService!.updatePosition(newLoc);
      if (advanced && _navService!.currentStep != null) {
        final step = _navService!.currentStep!;
        final dist = _navService!.distanceToNextTurn;
        _speak('${step.instruction} in $dist');
        if (mounted) {
          setState(() {
            _currentInstruction = step.instruction;
            _distanceToTurn = dist;
          });
        }
      }
    }


    // ── 6. Update state ──────────────────────────
    if (mounted) {
      setState(() {
        currentLocation = newLoc;
        remainingKm = remKm;
        _traveledPoints = traveled;
        _remainingPoints = remaining;
        
        // Dynamically update duration based on remaining distance
        if (_transportMode == 'walking') {
          durationHrs = remKm / 5.0;
        } else if (_transportMode == 'cycling') {
          durationHrs = remKm / 18.0;
        } else {
          // For driving, we use a simple proportion of the total distance
          // but we must be careful not to update durationHrs in a way that 
          // feeds back into itself. A better way is using a constant speed 
          // derived from the original route or a default like 40km/h.
          if (totalDistKm > 0) {
            // Estimate based on 40km/h average for driving if we're moving
            durationHrs = remKm / 40.0; 
          }
        }
      });
    }

    mapController.move(newLoc, 18);

    // ── 7. Driver rest alert ─────────────────────
    if (navigationStartTime != null) {
      final elapsed = DateTime.now().difference(navigationStartTime!).inHours;
      if (elapsed >= 2 && !showDriverRestAlert) {
        showDriverRestAlert = true;
        _showDriverRestDialog(elapsed);
      }
    }
  }

  void _showDriverRestDialog(int hours) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.coffee, color: Colors.orange, size: 28),
          const SizedBox(width: 10),
          Text('Take a Break! ☕', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          durationHrs > 8
              ? 'You\'ve been driving $hours+ hours. Consider a 30-min rest or switching drivers.'
              : 'You\'ve been driving $hours+ hours. Take a 15-minute break to stay alert.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); showDriverRestAlert = false; navigationStartTime = DateTime.now(); },
            child: Text('Take a Break', style: GoogleFonts.poppins(color: Colors.orange, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Continue', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Offline tile download ────────────────────
  Future<void> _saveRouteOffline() async {
    if (routePoints.isEmpty) return;

    double minLat = routePoints.map((p) => p.latitude).reduce(math.min) - 0.05;
    double maxLat = routePoints.map((p) => p.latitude).reduce(math.max) + 0.05;
    double minLon = routePoints.map((p) => p.longitude).reduce(math.min) - 0.05;
    double maxLon = routePoints.map((p) => p.longitude).reduce(math.max) + 0.05;

    int tileCount = 0;
    for (int z = 7; z <= 14; z++) {
      final x0 = ((minLon + 180) / 360 * (1 << z)).floor();
      final x1 = ((maxLon + 180) / 360 * (1 << z)).floor();
      final y0 = ((1 - (math.log(math.tan(maxLat * math.pi / 180) + 1 / math.cos(maxLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      final y1 = ((1 - (math.log(math.tan(minLat * math.pi / 180) + 1 / math.cos(minLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      tileCount += ((x1 - x0).abs() + 1) * ((y1 - y0).abs() + 1);
    }

    // ── Ask for optional route name ─────────────
    final nameController = TextEditingController(
      text: '${widget.source.split(',')[0]} → ${widget.destination.split(',')[0]}',
    );
    final nameResult = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.download_for_offline, color: Colors.orange),
          const SizedBox(width: 8),
          Flexible(child: Text('Save Route Offline', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route name (optional):', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Weekend Goa Trip',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF065A60), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Text('Tiles: ~$tileCount  •  ~${(tileCount * 15 / 1024).toStringAsFixed(1)} MB  •  30 days',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (nameResult == null) return;
    final routeName = nameResult.isEmpty
        ? '${widget.source.split(',')[0]} → ${widget.destination.split(',')[0]}'
        : nameResult;
    final confirm = true;

    setState(() { _isSavingOffline = true; _downloadProgress = 0; _downloadTotal = tileCount; });

    final cacheManager = DefaultCacheManager();
    // Bounding box with buffer (approx 0.05 degrees)
    minLat = math.min(sourceLatLng!.latitude, destinationLatLng!.latitude) - 0.05;
    maxLat = math.max(sourceLatLng!.latitude, destinationLatLng!.latitude) + 0.05;
    minLon = math.min(sourceLatLng!.longitude, destinationLatLng!.longitude) - 0.05;
    maxLon = math.max(sourceLatLng!.longitude, destinationLatLng!.longitude) + 0.05;

    // Expand bounding box with all route points
    for (var p in routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    int totalTiles = 0;
    
    // First pass: Calculate total tiles to download
    for (int z = 10; z <= 16; z++) {
      final x0 = ((minLon + 180) / 360 * (1 << z)).floor();
      final x1 = ((maxLon + 180) / 360 * (1 << z)).floor();
      final y0 = ((1 - (math.log(math.tan(maxLat * math.pi / 180) + 1 / math.cos(maxLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      final y1 = ((1 - (math.log(math.tan(minLat * math.pi / 180) + 1 / math.cos(minLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      totalTiles += (x1 - x0 + 1) * (y1 - y0 + 1);
    }

    if (mounted) setState(() { _downloadTotal = totalTiles; _downloadProgress = 0; });

    int done = 0;
    // Limit to prevent huge downloads (safety cap)
    if (totalTiles > 500) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route too long for full detail offline. Saving base maps only.')));
      }
    }

    for (int z = 10; z <= (totalTiles > 500 ? 13 : 16); z++) {
      final x0 = ((minLon + 180) / 360 * (1 << z)).floor();
      final x1 = ((maxLon + 180) / 360 * (1 << z)).floor();
      final y0 = ((1 - (math.log(math.tan(maxLat * math.pi / 180) + 1 / math.cos(maxLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      final y1 = ((1 - (math.log(math.tan(minLat * math.pi / 180) + 1 / math.cos(minLat * math.pi / 180)) / math.pi)) / 2 * (1 << z)).floor();
      for (int x = x0; x <= x1; x++) {
        for (int y = y0; y <= y1; y++) {
          try {
            final url = _layerTiles[_selectedLayer]!
                .replaceAll('{z}', z.toString())
                .replaceAll('{x}', x.toString())
                .replaceAll('{y}', y.toString())
                .replaceAll('{r}', '');
            await cacheManager.downloadFile(url);
          } catch (_) {}
          done++;
          if (mounted) setState(() => _downloadProgress = done);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getString('offline_routes') ?? '[]';
    final routes = List<Map<String, dynamic>>.from(json.decode(routesJson));
    routes.insert(0, {
      'id': _uuid.v4(),
      'name': routeName,
      'source': widget.source,
      'destination': widget.destination,
      'transportMode': _transportMode,
      'points': routePoints.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
      'distKm': totalDistKm,
      'durationHrs': durationHrs,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString('offline_routes', json.encode(routes.take(10).toList()));

    if (mounted) {
      setState(() { _isSavingOffline = false; _routeSaved = true; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Route saved offline! $done tiles downloaded.', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _shareRoute() {
    if (sourceLatLng == null || destinationLatLng == null) return;
    
    // Attempt to extract purely string names instead of coordinates if possible
    final String sourceName = widget.source.split(',')[0];
    final String destName = widget.destination.split(',')[0];
    
    final String dist = totalDistKm.toStringAsFixed(1);
    final String time = durationHrs.toStringAsFixed(1);
    final String modeLabel = _transportModes[_transportMode]?['label'] ?? 'Drive';
    
    final String message = "🗺️ RouteVista Planned Route:\n"
        "📍 From: $sourceName\n"
        "🏁 To: $destName\n"
        "📏 Distance: $dist km\n"
        "⏱️ Time: ~$time h ($modeLabel)\n\n"
        "Plan your next trip with RouteVista!";
        
    Share.share(message);
  }

  void _showErrorDialog(String title, String body) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }



  // ════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: sourceLatLng ?? const LatLng(20, 78),
              initialZoom: 5,
            ),
            children: [
              TileLayer(urlTemplate: _layerTiles[_selectedLayer]!),
              PolylineLayer(polylines: [
                // ── Traveled segment → GREEN ───────
                if (_traveledPoints.length > 1)
                  Polyline(
                    points: _traveledPoints,
                    color: const Color(0xFF2ECC71),
                    strokeWidth: 6,
                    borderColor: const Color(0xFF27AE60),
                    borderStrokeWidth: 1.5,
                  ),
                // ── Remaining segment → RED ────────
                if (_remainingPoints.length > 1)
                  Polyline(
                    points: _remainingPoints,
                    color: const Color(0xFFE74C3C),
                    strokeWidth: 5,
                    borderColor: const Color(0xFFC0392B),
                    borderStrokeWidth: 1.5,
                  ),
                // ── Before navigation starts: full route in RED ──
                if (_traveledPoints.isEmpty && routePoints.isNotEmpty)
                  Polyline(
                    points: routePoints,
                    color: const Color(0xFFE74C3C),
                    strokeWidth: 5,
                    borderColor: const Color(0xFFC0392B),
                    borderStrokeWidth: 1.5,
                  ),
              ]),
              MarkerLayer(markers: [
                // Source
                if (sourceLatLng != null)
                  Marker(
                    point: sourceLatLng!, width: 40, height: 40,
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF065A60), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      child: const Icon(Icons.trip_origin, color: Colors.white, size: 18),
                    ),
                  ),
                // Destination
                if (destinationLatLng != null)
                  Marker(
                    point: destinationLatLng!, width: 40, height: 40,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      child: const Icon(Icons.flag, color: Colors.white, size: 18),
                    ),
                  ),
                // Waypoints (orange markers — only re-renders MarkerLayer)
                ..._waypoints.map((wp) => Marker(
                  point: wp.latLng, width: 44, height: 44,
                  child: GestureDetector(
                    onTap: () => _showWaypointOptions(wp),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(Icons.place, color: Colors.white, size: 20),
                    ),
                  ),
                )),
                // Navigation marker
                if (currentLocation != null && isNavigating)
                  Marker(
                    point: currentLocation!, width: 50, height: 50,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)]),
                      child: const Icon(Icons.navigation, color: Colors.white, size: 22),
                    ),
                  ),
                // ── NEW: All POI markers ──────
                ..._visiblePois.map((poi) => Marker(
                  point: poi.latLng, width: 36, height: 36,
                  child: GestureDetector(
                    onTap: () => _showPoiSheet(poi),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: poi.color, width: 2),
                        boxShadow: [BoxShadow(color: poi.color.withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                      child: Center(child: Text(poi.emoji, style: const TextStyle(fontSize: 16))),
                    ),
                  ),
                )),
              ]),
            ],
          ),

          // ── OFFLINE / GPS BANNER ─────────────
          if (isOffline || isGpsOff)
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                color: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: SafeArea(bottom: false,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(isOffline ? "No Internet Connection" : "GPS Signal Lost",
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                ),
              ),
            ),

          // ── LOADING ──────────────────────────
          if (isLoading)
            Container(
              color: Colors.black45,
              child: Center(child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: Color(0xFF065A60)),
                    const SizedBox(height: 15),
                    Text(statusMessage, style: GoogleFonts.poppins(fontSize: 14)),
                  ]),
                ),
              )),
            ),

          // ── TOP INFO CARD ─────────────────────
          if (!isLoading)
            Positioned(
              top: (isOffline || isGpsOff) ? 60 : 40,
              left: 12, right: 12,
              child: SafeArea(child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Source -> Destination label
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.radio_button_checked, size: 14, color: Color(0xFF065A60)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.source.split(',')[0],
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                            ),
                            const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                                widget.destination.split(',')[0],
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, thickness: 0.5),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start, 
                          children: [
                            _infoCol(Icons.timer, "${durationHrs.toStringAsFixed(1)} h"),
                            const SizedBox(width: 10),
                            _infoCol(Icons.speed, "${totalDistKm.toInt()} km"),
                            const SizedBox(width: 10),
                            if (isNavigating) ...[
                              _infoCol(Icons.near_me, "${remainingKm.toStringAsFixed(1)} km"),
                              const SizedBox(width: 10),
                            ],
                            _infoCol(Icons.cloud, "${destWeather?.temp ?? '-'}°C"),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isNavigating ? Colors.redAccent : const Color(0xFF065A60),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _toggleNavigation,
                              child: Text(isNavigating ? "STOP" : "NAV",
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            if (isNavigating) ...[
                              IconButton(
                                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, 
                                    color: _isMuted ? Colors.redAccent : const Color(0xFF065A60)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _isMuted = !_isMuted);
                                  if (_isMuted) {
                                    _tts.stop();
                                  } else if (_currentInstruction.isNotEmpty) {
                                    _speak(_currentInstruction);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Share button — more prominent visibility
                            if (routePoints.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.share_outlined, color: Colors.blueAccent),
                                tooltip: 'Share Route',
                                onPressed: _shareRoute,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints()),
                              const SizedBox(width: 8),
                            ],
                            // Offline save button — after share
                            if (routePoints.isNotEmpty && !_routeSaved) ...[
                              _isSavingOffline
                                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                                      SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          value: _downloadTotal > 0 ? _downloadProgress / _downloadTotal : null,
                                          strokeWidth: 2.5, color: Colors.orange)),
                                      Text('$_downloadProgress/$_downloadTotal', style: const TextStyle(fontSize: 8)),
                                    ])
                                  : IconButton(
                                      icon: const Icon(Icons.download_for_offline_outlined, color: Colors.orange),
                                      tooltip: 'Save for offline', onPressed: _saveRouteOffline,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints()),
                            ],
                            if (_routeSaved) ...[
                              const Tooltip(message: 'Saved offline', child: Icon(Icons.offline_pin, color: Colors.green)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )),
          ),

          // ── POI FETCH PROGRESS BAR ────────────
          if (_isFetchingPois)
            Positioned(
              top: (isOffline || isGpsOff) ? 170 : 150,
              left: 12, right: 12,
              child: SafeArea(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF065A60))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      _poiFetchTotal > 0
                          ? 'Scanning route for places... segment $_poiFetchDone of $_poiFetchTotal'
                          : 'Identifying all places along route...',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                    )),
                  ]),
                  if (_poiFetchTotal > 0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _poiFetchDone / _poiFetchTotal,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF065A60),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ]),
              )),
            ),

          // ── POI FILTER BAR ────────────────────
          if (_poisLoaded && _allPois.isNotEmpty)
            Positioned(
              top: _isFetchingPois ? 230 : ((isOffline || isGpsOff) ? 170 : 150),
              left: 0, right: 0,
              child: SafeArea(child: PoiFilterBar(
                allPois: _allPois,
                activeCategories: _activeCategories,
                onToggle: _toggleCategory,
                onSelectAll: () => setState(() {
                  _activeCategories = _allPois.map((p) => p.category).toSet();
                  _updateVisiblePois();
                }),
                onSelectNone: () => setState(() {
                  _activeCategories = {};
                  _updateVisiblePois();
                }),
              )),
            ),

          // ── POI COUNT CHIP ────────────────────
          if (_poisLoaded)
            Positioned(
              top: _isFetchingPois ? 280 : ((isOffline || isGpsOff) ? 220 : 200),
              right: 12,
              child: SafeArea(child: GestureDetector(
                onTap: () => setState(() => _showPoiList = !_showPoiList),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065A60),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.place, color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${_visiblePois.length} places',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(_showPoiList ? Icons.expand_less : Icons.expand_more, color: Colors.white, size: 16),
                  ]),
                ),
              )),
            ),

          // ── BACK BUTTON ───────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
              ),
              child: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
            ),
          ),

          // ── TRANSPORT MODE SELECTOR ───────────
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            left: 12,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _transportModes.entries.map((entry) {
                    final isSelected = _transportMode == entry.key;
                    final modeColor = entry.value['color'] as Color;
                    return GestureDetector(
                      onTap: () async {
                        if (_transportMode == entry.key) return;
                        setState(() => _transportMode = entry.key);
                        if (sourceLatLng != null && destinationLatLng != null) {
                          setState(() { isLoading = true; statusMessage = 'Recalculating for ${entry.value["label"]}...'; });
                          await _fetchRoute(
                            (isNavigating && currentLocation != null) ? currentLocation! : sourceLatLng!,
                            destinationLatLng!,
                          );
                          _calculateBudget();
                          setState(() => isLoading = false);
                          if (routePoints.isNotEmpty && !isNavigating) {
                            mapController.fitCamera(CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(routePoints),
                              padding: const EdgeInsets.all(50),
                            ));
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? modeColor.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: modeColor, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.value['icon'] as String,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.value['label'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? modeColor : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // ── MAP LAYER SWITCHER ────────────────
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.14,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Layer cards (shown when expanded)
                if (_showLayerPicker)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Map Type', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _layerTiles.keys.map((name) {
                            final bool selected = _selectedLayer == name;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedLayer = name;
                                _showLayerPicker = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 62,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? const Color(0xFF065A60) : Colors.grey.shade200,
                                    width: selected ? 2.5 : 1,
                                  ),
                                  color: selected ? const Color(0xFF065A60).withValues(alpha: 0.07) : Colors.grey.shade50,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_layerEmoji[name]!, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        color: selected ? const Color(0xFF065A60) : Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                // Toggle FAB
                GestureDetector(
                  onTap: () => setState(() => _showLayerPicker = !_showLayerPicker),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _showLayerPicker ? const Color(0xFF065A60) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _showLayerPicker ? '✕' : _layerEmoji[_selectedLayer]!,
                        style: TextStyle(
                          fontSize: _showLayerPicker ? 16 : 20,
                          color: _showLayerPicker ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── NAVIGATION BANNER ─────────────────
          if (isNavigating && _currentInstruction.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.12,
              left: 12,
              right: 12,
              child: _buildNavigationBanner(),
            ),

          // ── BOTTOM SHEET ──────────────────────
          if (!isLoading)
            DraggableScrollableSheet(
              controller: sheetController,
              initialChildSize: 0.1,
              minChildSize: 0.07,
              maxChildSize: 0.85,
              builder: (c, s) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black.withValues(alpha: 0.1))],
                ),
                child: ListView(
                  controller: s,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 16),

                    // ── TRIP SUMMARY ────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065A60).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF065A60).withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _summaryItem('Distance', '${totalDistKm.toStringAsFixed(1)} km', Icons.straighten),
                              _summaryItem('Time', '${durationHrs.toStringAsFixed(1)} h', Icons.schedule),
                              _summaryItem('Budget', '₹${budget.total.toStringAsFixed(0)}', Icons.payments_outlined),
                            ],
                          ),
                          if (fuelStatus.isNotEmpty && !fuelStatus['is_enough']) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Low Fuel! Range: ${fuelStatus['range_km'].toStringAsFixed(0)} km',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.red[900], fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── All Places List ──────────
                    Row(children: [
                      Text("All Places Along Route",
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_isFetchingPois)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF065A60))),
                          const SizedBox(width: 6),
                          Text('Fetching...', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        ])
                      else if (_poisLoaded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF065A60).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_allPois.length} total',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF065A60), fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    const SizedBox(height: 8),

                    // POI list sorted by route position
                    if (_visiblePois.isEmpty && _poisLoaded)
                      Center(child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('No places found for selected categories',
                            style: GoogleFonts.poppins(color: Colors.grey[400])),
                      )),

                    ..._currentPagePois.map((poi) => _poiListTile(poi)),

                    // Show More button
                    if (_currentPagePois.length < _visiblePois.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _poiListPage++),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF065A60)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Show more (${_visiblePois.length - _currentPagePois.length} remaining)',
                            style: GoogleFonts.poppins(color: const Color(0xFF065A60), fontSize: 13),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Budget section
                    Text("Trip Budget Estimate",
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: VehicleType.values
                          .where((v) => VehicleDefaults.isAvailable(v, totalDistKm))
                          .map((v) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(VehicleDefaults.label(v)),
                              selected: selectedVehicle == v,
                              onSelected: (_) {
                                setState(() { selectedVehicle = v; vehicleAverage = VehicleDefaults.mileage(v); });
                                _calculateBudget(); _updateFuelStatus();
                              },
                              selectedColor: const Color(0xFF065A60).withValues(alpha: 0.2),
                              labelStyle: GoogleFonts.poppins(fontSize: 12),
                            ),
                          )).toList()),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: FuelType.values.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${FuelRates.label(f)} ₹${FuelRates.getRate(f).toInt()}/L'),
                          selected: selectedFuel == f,
                          onSelected: (_) { setState(() => selectedFuel = f); _calculateBudget(); },
                          selectedColor: Colors.orange.withValues(alpha: 0.2),
                          labelStyle: GoogleFonts.poppins(fontSize: 11),
                        ),
                      )).toList()),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0D1B2A), Color(0xFF065A60)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        _budgetRow("⛽ Fuel", budget.fuelCost),
                        _budgetRow("🍔 Food", budget.foodCost),
                        _budgetRow("🏨 Accommodation", budget.accommodation),
                        _budgetRow("🛣️ Tolls", budget.tollCharges),
                        Divider(color: Colors.white.withValues(alpha: 0.3), height: 16),
                        _budgetRow("TOTAL", budget.total, isTotal: true),
                      ]),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationBanner() {
    final bool arrived = _hasArrived;
    final String emoji = arrived
        ? '🏁'
        : (_navService?.currentStep?.directionEmoji ?? '↑');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: arrived
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [const Color(0xFF0D1B2A), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Direction icon circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Instruction + distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentInstruction,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_distanceToTurn.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'in $_distanceToTurn',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Remaining km badge
          if (remainingKm > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    remainingKm < 1
                        ? '${(remainingKm * 1000).toStringAsFixed(0)}m'
                        : remainingKm.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (remainingKm >= 1)
                    Text(
                      'km left',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _poiListTile(PoiModel poi) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: poi.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: Text(poi.emoji, style: const TextStyle(fontSize: 18))),
      ),
      title: Text(poi.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Row(children: [
        Text(poi.category, style: GoogleFonts.poppins(fontSize: 11, color: poi.color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text(
          poi.distanceFromRouteMeters < 1000
              ? '${poi.distanceFromRouteMeters.toStringAsFixed(0)}m'
              : '${(poi.distanceFromRouteMeters / 1000).toStringAsFixed(1)}km from route',
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
        ),
      ]),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
      onTap: () {
        mapController.move(poi.latLng, 15);
        _showPoiSheet(poi);
      },
    );
  }

  void _showPoiSheet(PoiModel poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PoiBottomSheet(
        poi: poi,
        onNavigate: _navigateToPoi,
        onSetWaypoint: _addWaypoint,
      ),
    );
  }

  Widget _infoCol(IconData i, String t) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 18, color: const Color(0xFF065A60)),
      const SizedBox(height: 2),
      Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11)),
    ],
  );

  Widget _budgetRow(String l, double v, {bool isTotal = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: GoogleFonts.poppins(fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400, color: Colors.white, fontSize: isTotal ? 15 : 13)),
      Text("₹${v.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500, color: isTotal ? const Color(0xFF00BFA6) : Colors.white, fontSize: isTotal ? 16 : 13)),
    ]),
  );

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF065A60)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}  // END _MapScreenState

// ════════════════════════════════════════════
//  Waypoint Model
// ════════════════════════════════════════════
class _WaypointModel {
  final LatLng latLng;
  final String name;
  final double distFromSourceKm;

  const _WaypointModel({
    required this.latLng,
    required this.name,
    required this.distFromSourceKm,
  });
}

// ════════════════════════════════════════════
//  Waypoint Bottom Sheet Widget
// ════════════════════════════════════════════
class _WaypointBottomSheet extends StatelessWidget {
  final _WaypointModel waypoint;
  final VoidCallback onRemove;

  const _WaypointBottomSheet({required this.waypoint, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final distText = waypoint.distFromSourceKm < 1
        ? '${(waypoint.distFromSourceKm * 1000).toStringAsFixed(0)} m from start'
        : '${waypoint.distFromSourceKm.toStringAsFixed(1)} km from start';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.place, color: Colors.orange, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waypoint.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Waypoint',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info tiles
          _InfoTile(
            icon: Icons.my_location,
            label: 'Coordinates',
            value: '${waypoint.latLng.latitude.toStringAsFixed(5)}, '
                '${waypoint.latLng.longitude.toStringAsFixed(5)}',
            iconColor: const Color(0xFF065A60),
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.straighten,
            label: 'Distance',
            value: distText,
            iconColor: Colors.deepPurple,
          ),
          const SizedBox(height: 24),

          // Remove button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: Text(
                'Remove Waypoint',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

// Small info row used inside bottom sheet
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: const Color(0xFF1A1A2E), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
