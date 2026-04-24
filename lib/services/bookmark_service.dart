import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  /// Toggles a bookmark for a place
  static Future<void> toggleBookmark(Map<String, dynamic> placeData) async {
    if (_uid == null) return;

    final placeId = placeData['name'].toString().toLowerCase().replaceAll(' ', '_');
    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('place_bookmarks')
        .doc(placeId);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        ...placeData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Checks if a place is bookmarked
  static Future<bool> isBookmarked(String name) async {
    if (_uid == null) return false;
    final placeId = name.toLowerCase().replaceAll(' ', '_');
    final doc = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('place_bookmarks')
        .doc(placeId)
        .get();
    return doc.exists;
  }

  /// Gets a stream of all bookmarked place IDs for the current user
  static Stream<Set<String>> getBookmarkedPlaceIds() {
    if (_uid == null) return Stream.value({});
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('place_bookmarks')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }
}
