import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/tour_card.dart';
import '../widgets/hotel_card.dart';
import 'place_detail_screen.dart';
import 'hotel_detail_screen.dart';
import '../models/place_model.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> hotels;

  const SearchScreen({super.key, required this.hotels});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceModel> _allPlaces = [];
  List<PlaceModel> _filteredPlaces = [];
  List<Map<String, dynamic>> _filteredHotels = [];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filteredHotels = widget.hotels;
    _loadAllPlaces();
  }

  Future<void> _loadAllPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('places').get();
      final places = snapshot.docs.map((doc) => PlaceModel.fromFirestore(doc)).toList();
      if (mounted) {
        setState(() {
          _allPlaces = places;
          _filteredPlaces = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _query = query.toLowerCase();
      _filteredPlaces = _allPlaces.where((p) {
        final name = p.name.toLowerCase();
        final loc = p.state.toLowerCase();
        final cat = p.category.toLowerCase();
        return name.contains(_query) || loc.contains(_query) || cat.contains(_query);
      }).toList();

      _filteredHotels = widget.hotels.where((h) {
        final name = h['name'].toString().toLowerCase();
        final loc = h['location'].toString().toLowerCase();
        return name.contains(_query) || loc.contains(_query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search tours, hotels...',
              hintStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA6)))
          : (_query.isEmpty && _filteredPlaces.isEmpty && _filteredHotels.isEmpty)
              ? _buildEmptyState('Type something to search')
              : (_filteredPlaces.isEmpty && _filteredHotels.isEmpty)
                  ? _buildEmptyState('No results found for "$_query"')
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      children: [
                        if (_filteredPlaces.isNotEmpty) ...[
                          _sectionHeader('Places (${_filteredPlaces.length})'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 20, right: 8),
                              itemCount: _filteredPlaces.length,
                              itemBuilder: (context, index) {
                                final place = _filteredPlaces[index];
                                return TourCard(
                                  name: place.name,
                                  location: place.state,
                                  imageUrl: place.imageUrl,
                                  rating: place.rating,
                                  isBookmarked: false,
                                  onTap: () => Navigator.push(
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
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        if (_filteredHotels.isNotEmpty) ...[
                          _sectionHeader('Hotels (${_filteredHotels.length})'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 195,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 20, right: 8),
                              itemCount: _filteredHotels.length,
                              itemBuilder: (context, index) {
                                final hotel = _filteredHotels[index];
                                return HotelCard(
                                  name: hotel['name'],
                                  imageUrl: hotel['image'],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HotelDetailScreen(
                                        name: hotel['name'],
                                        imageUrl: hotel['image'],
                                        location: hotel['location'],
                                        description: hotel['description'],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            text,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
