import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits or updates a user's rating for the application.
  Future<void> submitRating(double rating) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to submit a rating.');
    }

    try {
      await _firestore.collection('ratings').doc(user.uid).set({
        'rating': rating,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous Traveler',
        'userEmail': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Rating submitted successfully for user: ${user.uid}');
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      rethrow;
    }
  }

  /// Checks if the user has already rated the app.
  Future<double?> getUserRating() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('ratings').doc(user.uid).get();
      if (doc.exists) {
        return (doc.data()?['rating'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching user rating: $e');
    }
    return null;
  }
}
