import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class HotelDetailScreen extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double rating;
  final String pricePerNight;
  final String? location;
  final String? description;

  const HotelDetailScreen({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.pricePerNight,
    this.location,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF065A60),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[300]),
                    errorWidget: (c, u, e) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.hotel,
                        size: 60,
                        color: Colors.grey,
                      ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF065A60),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pricePerNight,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < rating.floor()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                                color: const Color(0xFFFFC107),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$rating',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
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
                  // Quick Info Row
                  Row(
                    children: [
                      _infoTag(Icons.wifi, 'Free WiFi'),
                      const SizedBox(width: 8),
                      _infoTag(Icons.pool, 'Pool'),
                      const SizedBox(width: 8),
                      _infoTag(Icons.spa, 'Spa'),
                      const SizedBox(width: 8),
                      _infoTag(Icons.restaurant, 'Restaurant'),
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
                    description ?? _getDescription(name),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amenities
                  Text(
                    'Amenities',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAmenitiesGrid(),

                  const SizedBox(height: 24),

                  // Policies
                  Text(
                    'Policies',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _policyRow(Icons.access_time, 'Check-in', '2:00 PM'),
                  _policyRow(Icons.access_time_filled, 'Check-out', '12:00 PM'),
                  _policyRow(
                    Icons.cancel_outlined,
                    'Cancellation',
                    'Free up to 24hrs',
                  ),
                  _policyRow(Icons.pets, 'Pets', 'Not Allowed'),

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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF065A60), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone, color: Color(0xFF065A60)),
                  onPressed: () => _makeCall(context),
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
                  onPressed: () => _searchHotel(context),
                  icon: const Icon(Icons.search),
                  label: Text(
                    'Search on Google',
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

  Widget _infoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF065A60).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF065A60)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF065A60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesGrid() {
    final amenities = [
      {'icon': Icons.wifi, 'label': 'WiFi'},
      {'icon': Icons.pool, 'label': 'Swimming Pool'},
      {'icon': Icons.spa, 'label': 'Spa & Wellness'},
      {'icon': Icons.restaurant, 'label': 'Restaurant'},
      {'icon': Icons.fitness_center, 'label': 'Gym'},
      {'icon': Icons.local_parking, 'label': 'Parking'},
      {'icon': Icons.ac_unit, 'label': 'AC Rooms'},
      {'icon': Icons.room_service, 'label': 'Room Service'},
      {'icon': Icons.local_laundry_service, 'label': 'Laundry'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: amenities.length,
      itemBuilder: (context, index) {
        final a = amenities[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                a['icon'] as IconData,
                size: 24,
                color: const Color(0xFF065A60),
              ),
              const SizedBox(height: 6),
              Text(
                a['label'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _policyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  void _makeCall(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact hotel for bookings',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _searchHotel(BuildContext context) async {
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent('$name hotel booking')}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getDescription(String hotelName) {
    final descriptions = {
      'The Oberoi Udaivilas':
          'Set on the banks of Lake Pichola in Udaipur, The Oberoi Udaivilas is a luxury heritage hotel that offers a truly regal experience. Spread over 50 acres, the hotel features stunning architecture inspired by the palaces of Mewar with domes, corridors, and courtyards. Guests can enjoy private pools, world-class dining, and breathtaking views of the City Palace and Jag Mandir.',
      'Taj Lake Palace':
          'Seemingly floating on Lake Pichola, the Taj Lake Palace is an architectural marvel built in 1746 as a royal pleasure palace. Now a luxury heritage hotel, it offers exquisite rooms with lake views, fine dining, and traditional Rajasthani hospitality. The hotel is accessible only by boat, adding to its magical charm.',
      'ITC Grand Chola':
          'ITC Grand Chola in Chennai is inspired by the grandeur of the Chola dynasty. This luxury hotel combines traditional South Indian architecture with modern amenities. It features multiple award-winning restaurants, a luxurious spa, and world-class business facilities. The hotel is LEED Platinum certified, reflecting its commitment to sustainability.',
      'Leela Palace':
          'The Leela Palace is a luxury hotel chain known for its opulent interiors, impeccable service, and prime locations across India. Each property is designed to reflect the cultural heritage of its city while offering contemporary luxury. Guests enjoy royal treatment with butler service, gourmet dining, and spa experiences.',
    };
    return descriptions[hotelName] ??
        '$hotelName is a premier hospitality destination offering world-class amenities and exceptional service. Enjoy luxurious rooms, fine dining, wellness facilities, and warm Indian hospitality. Perfect for both leisure and business travelers seeking a memorable stay.';
  }
}
