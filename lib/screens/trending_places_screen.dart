import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/place_service.dart';
import '../services/bookmark_service.dart';
import '../models/place_model.dart';
import '../widgets/tour_card.dart';
import 'place_detail_screen.dart';

class TrendingPlacesScreen extends StatefulWidget {
  final Set<String> bookmarkedTours;
  final Function(Map<String, dynamic>) onToggleBookmark;
  final Function(String) onNavigate;

  const TrendingPlacesScreen({
    super.key,
    required this.bookmarkedTours,
    required this.onToggleBookmark,
    required this.onNavigate,
  });

  @override
  State<TrendingPlacesScreen> createState() => _TrendingPlacesScreenState();
}

class _TrendingPlacesScreenState extends State<TrendingPlacesScreen> {
  late Set<String> _bookmarkedIds;

  @override
  void initState() {
    super.initState();
    _bookmarkedIds = Set.from(widget.bookmarkedTours);
    _listenBookmarks();
  }

  void _listenBookmarks() {
    BookmarkService.getBookmarkedPlaceIds().listen((ids) {
      if (mounted) setState(() => _bookmarkedIds = ids);
    });
  }

  Future<void> _toggleBookmark(PlaceModel place) async {
    final data = {
      'name': place.name,
      'location': place.state,
      'image': place.imageUrl,
      'rating': place.rating,
      'category': place.category,
      'description': place.description,
    };
    await BookmarkService.toggleBookmark(data);
    widget.onToggleBookmark(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Trending in India', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: FutureBuilder<List<PlaceModel>>(
        future: PlaceService.getTrendingPlaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No trending places found.', style: GoogleFonts.poppins()),
            );
          }

          final trendingPlaces = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trendingPlaces.length,
            itemBuilder: (context, index) {
              final place = trendingPlaces[index];
              final bookmarkId = place.name.toLowerCase().replaceAll(' ', '_');
              final isBookmarked = _bookmarkedIds.contains(bookmarkId);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  height: 220, 
                  child: TourCard(
                    width: double.infinity,
                    margin: EdgeInsets.zero,
                    name: place.name,
                    location: place.state,
                    imageUrl: place.imageUrl,
                    rating: place.rating,
                    isBookmarked: isBookmarked,
                    onBookmark: () => _toggleBookmark(place),
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
                            onSave: () => _toggleBookmark(place),
                            onNavigate: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                              widget.onNavigate(place.name);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
