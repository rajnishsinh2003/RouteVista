import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────
//  POI MODEL
// ─────────────────────────────────────────────
class PoiModel {
  final String id;
  final String name;
  final String category;
  final String subCategory;
  final double lat;
  final double lng;
  double distanceFromRouteMeters;
  int indexAlongRoute;
  final Map<String, String> tags;

  PoiModel({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.lat,
    required this.lng,
    this.distanceFromRouteMeters = 0,
    this.indexAlongRoute = 0,
    required this.tags,
  });

  LatLng get latLng => LatLng(lat, lng);

  Color get color {
    switch (category) {
      case 'Fuel':        return Colors.blueGrey;
      case 'Food':        return Colors.orange;
      case 'Hotel':       return Colors.indigo;
      case 'Hospital':    return Colors.red;
      case 'History':     return Colors.brown;
      case 'Nature':      return Colors.green;
      case 'Religious':   return Colors.purple;
      case 'Police':      return Colors.blue;
      case 'Bank':        return Colors.teal;
      case 'Shop':        return Colors.pink;
      default:            return Colors.grey;
    }
  }

  IconData get icon {
    switch (category) {
      case 'Fuel':        return Icons.local_gas_station;
      case 'Food':        return Icons.restaurant;
      case 'Hotel':       return Icons.hotel;
      case 'Hospital':    return Icons.local_hospital;
      case 'History':     return Icons.account_balance;
      case 'Nature':      return Icons.forest;
      case 'Religious':   return Icons.temple_buddhist;
      case 'Police':      return Icons.local_police;
      case 'Bank':        return Icons.account_balance_wallet;
      case 'Shop':        return Icons.shopping_bag;
      default:            return Icons.place;
    }
  }

  String get emoji {
    switch (category) {
      case 'Fuel':        return '⛽';
      case 'Food':        return '🍽️';
      case 'Hotel':       return '🏨';
      case 'Hospital':    return '🏥';
      case 'History':     return '🏛️';
      case 'Nature':      return '🌿';
      case 'Religious':   return '🕌';
      case 'Police':      return '🚔';
      case 'Bank':        return '🏧';
      case 'Shop':        return '🛒';
      default:            return '📍';
    }
  }
}

// ─────────────────────────────────────────────
//  POI SERVICE — ALL POIs, NO LIMIT
// ─────────────────────────────────────────────
class PoiService {
  static const double _corridorMeters = 500;
  static const double _maxSegmentKm = 25; // Smaller segments for reliability
  static const int _pointStep = 3; // Denser sampling for overlapping coverage

  // ── Main entry ──────────────────────────────
  /// [onProgress]  — called after every segment with (done, total).
  /// [onBatch]     — called immediately with newly discovered POIs after each
  ///                 segment so the UI can show them right away.
  Future<List<PoiModel>> fetchAllPois(
    List<LatLng> routePoints, {
    void Function(int done, int total)? onProgress,
    void Function(List<PoiModel> newPois)? onBatch,
  }) async {
    if (routePoints.isEmpty) return [];

    final segments = _splitIntoSegments(routePoints, _maxSegmentKm);
    final Map<String, PoiModel> seen = {}; // global dedup across segments
    int doneCount = 0;

    // ── Controlled Parallelism (Max 3 concurrent) ─────────────
    const int maxConcurrent = 3;
    final List<Future<void>> workers = [];
    int nextSegment = 0;

    Future<void> worker() async {
      while (nextSegment < segments.length) {
        final currentIdx = nextSegment++;
        final segment = segments[currentIdx];
        
        try {
          final query = _buildAroundQuery(segment);
          final rawPois = await _queryOverpass(query);

          final newPois = <PoiModel>[];
          for (final poi in rawPois) {
            if (seen.containsKey(poi.id)) continue; 
            
            final d = _nearestDistanceToRoute(poi.latLng, routePoints);
            if (d <= _corridorMeters) {
              poi.distanceFromRouteMeters = d;
              poi.indexAlongRoute = _indexAlongRoute(poi.latLng, routePoints);
              seen[poi.id] = poi;
              newPois.add(poi);
            }
          }

          if (newPois.isNotEmpty) {
            onBatch?.call(newPois);
          }
        } catch (e) {
          debugPrint('PoiService: Error in segment $currentIdx: $e');
        } finally {
          doneCount++;
          onProgress?.call(doneCount, segments.length);
        }
      }
    }

    // Start workers
    for (int i = 0; i < math.min(maxConcurrent, segments.length); i++) {
      workers.add(worker());
    }

    await Future.wait(workers);

    final all = seen.values.toList();
    all.sort((a, b) => a.indexAlongRoute.compareTo(b.indexAlongRoute));
    debugPrint('PoiService: ${all.length} total POIs across ${segments.length} segments');
    return all;
  }

  // ── Split route into ≤50km segments ─────────
  List<List<LatLng>> _splitIntoSegments(List<LatLng> points, double maxKm) {
    if (points.length < 2) return [points];

    final segments = <List<LatLng>>[];
    var current = <LatLng>[points.first];
    double accumulated = 0;

    for (int i = 1; i < points.length; i++) {
      final d = _distanceKm(points[i - 1], points[i]);
      accumulated += d;
      current.add(points[i]);

      if (accumulated >= maxKm && i < points.length - 1) {
        segments.add(List.from(current));
        // Overlap: start next segment from last 3 points for continuity
        current = current.length >= 3
            ? current.sublist(current.length - 3)
            : [current.last];
        accumulated = 0;
      }
    }
    if (current.length >= 2) segments.add(current);
    if (segments.isEmpty) segments.add(points);
    return segments;
  }

  // ── Build Overpass QL using around with route coords ──
  String _buildAroundQuery(List<LatLng> segmentPoints) {
    // Sample every Nth point to keep query size manageable
    final sampled = <LatLng>[];
    for (int i = 0; i < segmentPoints.length; i += _pointStep) {
      sampled.add(segmentPoints[i]);
    }
    if (sampled.isEmpty || sampled.last != segmentPoints.last) {
      sampled.add(segmentPoints.last);
    }

    final coordStr = sampled.map((p) => '${p.latitude},${p.longitude}').join(',');
    final r = _corridorMeters.toInt();

    return '''
[out:json][timeout:60];
(
  nwr(around:$r,$coordStr)["amenity"~"fuel|restaurant|fast_food|cafe|hospital|clinic|pharmacy|atm|bank|police|place_of_worship|toilets|charging_station|parking"];
  nwr(around:$r,$coordStr)["tourism"~"hotel|guest_house|motel|hostel|museum|viewpoint|attraction|monument|information"];
  nwr(around:$r,$coordStr)["historic"];
  nwr(around:$r,$coordStr)["leisure"~"park|nature_reserve|garden|playground"];
  nwr(around:$r,$coordStr)["natural"~"peak|waterfall|beach|spring|cave_entrance"];
  nwr(around:$r,$coordStr)["shop"~"supermarket|mall|convenience|bakery|chemist|department_store"];
);
out center;''';
  }

  // ── Query Overpass with retry ────────────────
  Future<List<PoiModel>> _queryOverpass(String query, {int retryCount = 0}) async {
    try {
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: 'data=${Uri.encodeComponent(query)}',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 65));

      if (res.statusCode == 200) {
        return _parseResponse(res.body);
      } else if (res.statusCode == 429 && retryCount < 2) {
        await Future.delayed(const Duration(seconds: 15));
        return _queryOverpass(query, retryCount: retryCount + 1);
      } else if (res.statusCode == 504 && retryCount < 1) {
        await Future.delayed(const Duration(seconds: 5));
        return _queryOverpass(query, retryCount: retryCount + 1);
      }
    } catch (e) {
      if (retryCount < 1) {
        await Future.delayed(const Duration(seconds: 5));
        return _queryOverpass(query, retryCount: retryCount + 1);
      }
      debugPrint('Overpass error: $e');
    }
    return [];
  }

  // ── Parse Overpass JSON response ─────────────
  List<PoiModel> _parseResponse(String body) {
    final pois = <PoiModel>[];
    try {
      final data = json.decode(body);
      for (final e in data['elements'] ?? []) {
        double? lat, lon;
        if (e['lat'] != null && e['lon'] != null) {
          lat = (e['lat'] as num).toDouble();
          lon = (e['lon'] as num).toDouble();
        } else if (e['center'] != null) {
          lat = (e['center']['lat'] as num).toDouble();
          lon = (e['center']['lon'] as num).toDouble();
        }
        if (lat == null || lon == null) continue;

        final tags = Map<String, String>.from(
          (e['tags'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        );
        final category = _classifyPoi(tags);
        // Allow 'Other' category so we don't drop interesting unnamed/unclassified points
        
        final name = tags['name'] ??
            tags['brand'] ??
            tags['operator'] ??
            _defaultName(category, tags);

        pois.add(PoiModel(
          id: e['id'].toString(),
          name: name,
          category: category,
          subCategory: _subCategory(tags),
          lat: lat,
          lng: lon,
          tags: tags,
        ));
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return pois;
  }

  // ── Classify POI into category ───────────────
  String _classifyPoi(Map<String, String> t) {
    final amenity  = t['amenity'] ?? '';
    final tourism  = t['tourism'] ?? '';
    final shop     = t['shop'] ?? '';
    final historic = t['historic'];
    final leisure  = t['leisure'] ?? '';
    final natural  = t['natural'] ?? '';

    if (amenity == 'fuel' || amenity == 'charging_station') return 'Fuel';
    if (['restaurant','fast_food','cafe','food_court','bar','pub','biryani'].contains(amenity)) return 'Food';
    if (['hotel','guest_house','motel','hostel','resort','apartment'].contains(tourism)) return 'Hotel';
    if (['hospital','clinic','pharmacy','doctors','dentist','chemist'].contains(amenity)) return 'Hospital';
    if (['atm','bank','money_transfer','bureau_de_change'].contains(amenity)) return 'Bank';
    if (amenity == 'police' || amenity == 'fire_station') return 'Police';
    if (['place_of_worship','church','mosque','temple','hindu_temple','shrine'].contains(amenity)) return 'Religious';
    
    if (historic != null || ['museum','monument','castle','ruins','wayside_shrine'].contains(tourism)) return 'History';
    if (['viewpoint','attraction','information','picnic_site','camp_site'].contains(tourism)) return 'Nature';
    if (['park','nature_reserve','garden','playground','wildlife_hide'].contains(leisure)) return 'Nature';
    if (['peak','waterfall','beach','spring','cave_entrance','tree'].contains(natural)) return 'Nature';
    if (['supermarket','mall','convenience','bakery','department_store','clothes','electronics','furniture'].contains(shop)) return 'Shop';
    if (amenity == 'toilets' || amenity == 'parking' || amenity == 'post_office' || amenity == 'townhall') return 'Shop'; // Services grouped under Shop/Service
    return 'Other';
  }

  String _subCategory(Map<String, String> t) =>
      t['amenity'] ?? t['tourism'] ?? t['shop'] ?? t['natural'] ?? t['leisure'] ?? '';

  String _defaultName(String category, Map<String, String> tags) {
    final sub = _subCategory(tags);
    if (sub.isNotEmpty) return '${sub[0].toUpperCase()}${sub.substring(1).replaceAll('_', ' ')}';
    return category;
  }

  // ── Geometry helpers ─────────────────────────
  double _distanceKm(LatLng a, LatLng b) => _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final a = sinDLat * sinDLat +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * sinDLon * sinDLon;
    return R * 2 * math.asin(math.sqrt(a));
  }

  double _nearestDistanceToRoute(LatLng poi, List<LatLng> route) {
    double minDist = double.infinity;
    for (final rp in route) {
      final d = _haversineKm(poi.latitude, poi.longitude, rp.latitude, rp.longitude) * 1000;
      if (d < minDist) minDist = d;
      if (minDist <= 10) break; // early exit if very close
    }
    return minDist;
  }

  int _indexAlongRoute(LatLng poi, List<LatLng> route) {
    double minDist = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < route.length; i++) {
      final d = _haversineKm(poi.latitude, poi.longitude, route[i].latitude, route[i].longitude);
      if (d < minDist) {
        minDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}
