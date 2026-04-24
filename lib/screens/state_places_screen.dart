import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place_model.dart';
import '../widgets/tour_card.dart';
import '../services/place_service.dart';
import '../services/bookmark_service.dart';
import 'place_detail_screen.dart';

class StatePlacesScreen extends StatefulWidget {
  final String stateName;

  const StatePlacesScreen({
    super.key,
    required this.stateName,
  });

  @override
  State<StatePlacesScreen> createState() => _StatePlacesScreenState();
}

class _StatePlacesScreenState extends State<StatePlacesScreen> {
  final Set<String> _warmedUpPlaces = {};
  Set<String> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    _listenBookmarks();
  }

  void _listenBookmarks() {
    BookmarkService.getBookmarkedPlaceIds().listen((ids) {
      if (mounted) setState(() => _bookmarkedIds = ids);
    });
  }

  Future<void> _toggleBookmark(PlaceModel place) async {
    await BookmarkService.toggleBookmark({
      'name': place.name,
      'location': place.state,
      'image': place.imageUrl,
      'rating': place.rating,
      'category': place.category,
      'description': place.description,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stateName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF065A60),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PlaceModel>>(
        stream: PlaceService.getPlacesByState(widget.stateName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA6)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No places found for ${widget.stateName}.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          final places = snapshot.data!;
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final bookmarkId = place.name.toLowerCase().replaceAll(' ', '_');
              final isBookmarked = _bookmarkedIds.contains(bookmarkId);
              
              // Dynamic Warm-Up: Trigger Wikipedia update when item builds
              if (!_warmedUpPlaces.contains(place.id)) {
                _warmedUpPlaces.add(place.id);
                PlaceService.updatePlaceDetailsIfNeeded(place);
              }

              return TourCard(
                name: place.name,
                location: place.state,
                imageUrl: place.imageUrl,
                rating: place.rating,
                isBookmarked: isBookmarked,
                width: null,
                margin: EdgeInsets.zero,
                onBookmark: () => _toggleBookmark(place),
                onTap: () {
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
                        onSave: () => _toggleBookmark(place),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
