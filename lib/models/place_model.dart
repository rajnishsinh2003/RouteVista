import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name;
  final String state;
  final String category;
  final String imageUrl;
  final String description;
  final double rating;
  final List<String> highlights;

  PlaceModel({
    required this.id,
    required this.name,
    required this.state,
    this.category = 'General',
    this.imageUrl = '',
    this.description = '',
    this.rating = 4.5,
    this.highlights = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
      'category': category,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'highlights': highlights,
    };
  }

  factory PlaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      state: data['state'] ?? '',
      category: data['category'] ?? 'General',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] ?? 4.5).toDouble(),
      highlights: List<String>.from(data['highlights'] ?? []),
    );
  }
}
