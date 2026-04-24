import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

class PlaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'places';

  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// One-time sync: Uploads Places.json to Firestore
  static Future<void> syncLocalDataToFirestore() async {
    try {
      // We expect around 350+ places for all states.
      final snapshot = await _firestore.collection(_collectionName).limit(100).get();
      print('🔍 [Sync] Current Firestore count check: found ${snapshot.docs.length} places (threshold: 100)');
      
      if (snapshot.docs.length >= 100) {
        print('ℹ️ Firestore sufficiently populated. Skipping sync.');
        return;
      }

      print('🚀 [Sync] Starting Places Migration...');
      final String response = await rootBundle.loadString('assets/json/places.json');
      final data = json.decode(response);
      final Map<String, dynamic> states = data['places'] ?? {};

      int stateCount = 0;
      int placeCount = 0;
      
      WriteBatch batch = _firestore.batch();
      int currentBatchCount = 0;

      for (var stateEntry in states.entries) {
        stateCount++;
        final stateName = _toTitleCase(stateEntry.key);
        final List<dynamic> placeNames = stateEntry.value;

        for (var name in placeNames) {
          placeCount++;
          currentBatchCount++;
          final id = '${stateEntry.key}_${name.toString().toLowerCase().replaceAll(' ', '_')}';
          final docRef = _firestore.collection(_collectionName).doc(id);
          
          batch.set(docRef, {
            'name': name,
            'state': stateName,
            'category': 'General',
            'imageUrl': '',
            'description': '',
            'rating': 4.5,
            'highlights': [],
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // A WriteBatch can contain up to 500 operations.
          if (currentBatchCount >= 450) {
            await batch.commit();
            print('📦 [Sync] Committed intermediate batch of $currentBatchCount places...');
            batch = _firestore.batch();
            currentBatchCount = 0;
          }
        }
      }
      
      if (currentBatchCount > 0) {
        await batch.commit();
      }
      print('✅ [Sync] Migration complete! Total States: $stateCount, Total Places: $placeCount');
    } catch (e) {
      print('❌ Error syncing places: $e');
    }
  }

  /// Fetches summary and image from Wikipedia REST API
  static Future<Map<String, dynamic>?> fetchWikipediaData(String placeName) async {
    try {
      final url = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(placeName)}');
      final response = await http.get(url, headers: {'User-Agent': 'RouteVista-App'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'description': data['extract'] ?? '',
          'imageUrl': data['originalimage']?['source'] ?? data['thumbnail']?['source'] ?? '',
          'category': _inferCategory(data['extract'] ?? '', placeName),
        };
      }
    } catch (e) {
      print('Error fetching Wikipedia for $placeName: $e');
    }
    return null;
  }

  /// Simple keyword-based category inference
  static String _inferCategory(String text, String name) {
    final lowerText = (text + name).toLowerCase();
    
    if (lowerText.contains('temple') || lowerText.contains('mosque') || 
        lowerText.contains('church') || lowerText.contains('sacred') || 
        lowerText.contains('shrine') || lowerText.contains('guru') || 
        lowerText.contains('spiritual')) {
      return 'Religious';
    }
    
    if (lowerText.contains('fort') || lowerText.contains('castle') || 
        lowerText.contains('ancient') || lowerText.contains('monument') || 
        lowerText.contains('built in') || lowerText.contains('history') || 
        lowerText.contains('dynasty')) {
      return 'Historical';
    }
    
    if (lowerText.contains('park') || lowerText.contains('valley') || 
        lowerText.contains('beach') || lowerText.contains('waterfall') || 
        lowerText.contains('hills') || lowerText.contains('sanctuary') || 
        lowerText.contains('river') || lowerText.contains('nature')) {
      return 'Nature';
    }

    if (lowerText.contains('restaurant') || lowerText.contains('food') || 
        lowerText.contains('cuisine') || lowerText.contains('market')) {
      return 'Food';
    }
    
    if (lowerText.contains('hotel') || lowerText.contains('resort') || 
        lowerText.contains('stay') || lowerText.contains('luxury')) {
      return 'Hotels';
    }

    return 'General';
  }

  /// Get Stream of places grouped by state
  static Stream<Map<String, List<PlaceModel>>> getPlacesGroupedByState() {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      final Map<String, List<PlaceModel>> groups = {};
      for (var doc in snapshot.docs) {
        final place = PlaceModel.fromFirestore(doc);
        final stateKey = _toTitleCase(place.state);
        if (!groups.containsKey(stateKey)) {
          groups[stateKey] = [];
        }
        groups[stateKey]!.add(place);
      }
      return groups;
    });
  }

  /// Get Stream of places for a specific state
  static Stream<List<PlaceModel>> getPlacesByState(String stateName) {
    return _firestore
        .collection(_collectionName)
        .where('state', isEqualTo: stateName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PlaceModel.fromFirestore(doc)).toList());
  }

  /// Get a few trending places (highest rating, limit 5)
  static Future<List<PlaceModel>> getTrendingPlaces() async {
    final query = await _firestore
        .collection(_collectionName)
        .orderBy('rating', descending: true)
        .limit(5)
        .get();
    return query.docs.map((doc) => PlaceModel.fromFirestore(doc)).toList();
  }


  /// Updates a place document with Wikipedia data if missing
  static Future<void> updatePlaceDetailsIfNeeded(PlaceModel place) async {
    // If it's already "complete", skip
    if (place.description.isNotEmpty && place.imageUrl.isNotEmpty) return;
    
    // Tiny delay to respect Wikipedia's rate limits (especially during dashboard warm-up)
    await Future.delayed(const Duration(milliseconds: 200));

    final wikiData = await fetchWikipediaData(place.name);
    if (wikiData != null) {
      await _firestore.collection(_collectionName).doc(place.id).update({
        'description': wikiData['description'] ?? place.description,
        'imageUrl': wikiData['imageUrl'] ?? place.imageUrl,
        'category': wikiData['category'] ?? place.category,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }
}
