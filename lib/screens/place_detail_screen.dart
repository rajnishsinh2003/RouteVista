import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String name;
  final String location;
  final String imageUrl;
  final double rating;
  final String category;
  final String description;
  final VoidCallback? onNavigate;
  final VoidCallback? onSave;

  const PlaceDetailScreen({
    super.key,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.rating,
    this.category = '',
    this.description = '',
    this.onNavigate,
    this.onSave,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF065A60),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[300]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.landscape, size: 60, color: Colors.grey),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BFA6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.category,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          widget.name,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.location,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Quick Info
                  Row(
                    children: [
                      _infoChip(Icons.star_rounded, '$widget.rating', const Color(0xFFFFC107)),
                      const SizedBox(width: 12),
                      _infoChip(Icons.access_time, 'Open 06:00-20:00', Colors.green),
                      const SizedBox(width: 12),
                      _infoChip(Icons.currency_rupee, 'Free Entry', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // About
                  Text(
                    'About',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description.isNotEmpty
                        ? widget.description
                        : _getDefaultDescription(widget.name),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Highlights
                  Text(
                    'Highlights',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._getHighlights(widget.name).map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF065A60).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle, color: Color(0xFF065A60), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            h,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  )),

                  const SizedBox(height: 24),

                  // Tips
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Travel Tip',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.orange[800],
                                ),
                              ),
                              Text(
                                'Best time to visit is early morning for fewer crowds. Carry water and comfortable footwear.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isSaved) {
                    setState(() => _isSaved = true);
                    if (widget.onSave != null) widget.onSave!();
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF065A60), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF065A60)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065A60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onNavigate != null) widget.onNavigate!();
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(
                    'Navigate Here',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getDefaultDescription(String placeName) {
    final descriptions = {
      'Taj Mahal': 'The Taj Mahal is an ivory-white marble mausoleum on the right bank of the river Yamuna in Agra, Uttar Pradesh. It was commissioned in 1631 by the fifth Mughal emperor, Shah Jahan, to house the tomb of his beloved wife, Mumtaz Mahal. Often described as one of the Seven Wonders of the World, it attracts millions of visitors annually and is a UNESCO World Heritage Site.',
      'Goa Beaches': 'Goa, the smallest state in India, is renowned for its stunning beaches, vibrant nightlife, Portuguese heritage architecture, and delicious seafood cuisine. From the bustling shores of Baga and Calangute to the serene sands of Palolem and Agonda, Goa offers something for every type of traveler. The state is also home to beautiful churches, spice plantations, and wildlife sanctuaries.',
      'Jaipur City Palace': 'The City Palace in Jaipur is a magnificent blend of Rajasthani and Mughal architecture. Built by Maharaja Sawai Jai Singh II, it includes the Chandra Mahal and Mubarak Mahal palaces along with other buildings. The palace complex is surrounded by walls and gardens. Part of the palace is still a royal residence, while the rest houses museums displaying royal costumes, paintings, and armory.',
      'Kerala Backwaters': 'The Kerala backwaters are a chain of brackish lagoons and lakes lying parallel to the Arabian Sea coast in Kerala. They include five large lakes linked by canals, both manmade and natural. A houseboat cruise through the backwaters is one of the most iconic experiences in India. The serene waterways are fringed by palm trees, rice paddies, and quaint villages.',
      'Varanasi Ghats': 'Varanasi, one of the oldest continuously inhabited cities in the world, sits on the banks of the sacred River Ganges. The ghats of Varanasi are a series of steps leading down to the river where pilgrims perform ritual ablutions. The evening Ganga Aarti ceremony at Dashashwamedh Ghat is a mesmerizing spectacle of fire, chanting, and devotion that attracts thousands daily.',
    };
    return descriptions[placeName] ??
        '$placeName is a popular tourist destination in India known for its rich cultural heritage, stunning architecture, and vibrant atmosphere. Visitors can explore historical monuments, enjoy local cuisine, and experience the unique traditions of the region. The best time to visit is during the cooler months from October to March.';
  }

  List<String> _getHighlights(String placeName) {
    final highlights = {
      'Taj Mahal': ['UNESCO World Heritage Site', 'Seven Wonders of the World', 'Mughal Architecture Masterpiece', 'Best at Sunrise & Sunset'],
      'Goa Beaches': ['Pristine Sandy Beaches', 'Water Sports & Activities', 'Portuguese Heritage', 'Vibrant Nightlife & Cuisine'],
      'Jaipur City Palace': ['Royal Rajasthani Architecture', 'Museum with Royal Artifacts', 'Beautiful Courtyards & Gardens', 'Light & Sound Show'],
      'Kerala Backwaters': ['Houseboat Cruises', 'Lush Green Landscapes', 'Traditional Kerala Cuisine', 'Bird Watching & Nature Walks'],
      'Varanasi Ghats': ['Sacred Ganga Aarti Ceremony', 'Ancient Temples & Shrines', 'Boat Rides at Dawn', 'Spiritual & Cultural Hub'],
    };
    return highlights[placeName] ?? ['Popular Tourist Spot', 'Rich Cultural Heritage', 'Local Cuisine & Shopping', 'Photography & Sightseeing'];
  }
}
