import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hotel_service.dart';
import '../models/hotel_model.dart';
import '../screens/hotel_detail_screen.dart';

class AllHotelsScreen extends StatefulWidget {
  final String locationState;
  
  const AllHotelsScreen({super.key, required this.locationState});

  @override
  State<AllHotelsScreen> createState() => _AllHotelsScreenState();
}

class _AllHotelsScreenState extends State<AllHotelsScreen> {
  late Future<List<HotelModel>> _hotelsFuture;

  @override
  void initState() {
    super.initState();
    _hotelsFuture = HotelService.getNearbyHotels(widget.locationState, count: 18);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF065A60),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Hotels in ${widget.locationState.isNotEmpty ? widget.locationState.split('_').map((s) => s[0].toUpperCase()+s.substring(1)).join(' ') : 'Your Area'}',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: FutureBuilder<List<HotelModel>>(
        future: _hotelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA6)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading hotels', style: GoogleFonts.poppins()));
          }
          final hotels = snapshot.data ?? [];
          if (hotels.isEmpty) {
            return Center(child: Text('No hotels found in this region.', style: GoogleFonts.poppins()));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hotels.length,
            itemBuilder: (context, index) {
              final hotel = hotels[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HotelDetailScreen(
                        name: hotel.name,
                        imageUrl: hotel.imageUrl,
                        location: hotel.location,
                        description: hotel.description,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          hotel.imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: const Icon(Icons.hotel_rounded, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    hotel.name,
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.grey, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  hotel.location,
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hotel.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BFA6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'View Details',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
