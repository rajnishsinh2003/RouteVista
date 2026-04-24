import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String placeId;
  final String comment;
  final double rating;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.placeId,
    required this.comment,
    required this.rating,
    required this.timestamp,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      placeId: data['placeId'] ?? '',
      comment: data['comment'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'placeId': placeId,
      'comment': comment,
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
