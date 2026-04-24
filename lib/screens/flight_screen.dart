import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/flight_service.dart';
import '../models/flight_model.dart';

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  
  List<FlightModel> _flights = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json'
        '&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1',
      );
      
      final res = await http.get(url, headers: {'User-Agent': 'RouteVista'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final city = addr['city'] ?? addr['state_district'] ?? addr['county'] ?? addr['state'];
        
        if (city != null) {
           String cleanedCity = city.toString().replaceAll(' District', '');
           if (FlightService.getIataFromCity(cleanedCity) != null) {
              if (mounted) {
                setState(() {
                  _originController.text = cleanedCity;
                });
              }
           }
        }
      }
    } catch (e) {
      debugPrint("Could not fetch location for origin city.");
    }
  }

  Future<void> _searchFlights() async {
    final origin = _originController.text.trim();
    final dest = _destController.text.trim();

    if (origin.isEmpty) {
      setState(() => _errorMessage = "Please enter an origin city (e.g., Delhi).");
      return;
    }
    
    if (FlightService.getIataFromCity(origin) == null) {
      setState(() => _errorMessage = "Origin city not found in our Indian airport directory.");
      return;
    }

    if (dest.isNotEmpty && FlightService.getIataFromCity(dest) == null) {
      setState(() => _errorMessage = "Destination city not found in our Indian airport directory.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _flights = [];
    });

    try {
      final flights = await FlightService.searchDomesticFlights(origin, dest);
      
      if (mounted) {
        setState(() {
          _flights = flights;
          _isLoading = false;
          if (flights.isEmpty) {
             _errorMessage = "No domestic flights scheduled for this route today.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Widget _buildFlightCard(FlightModel flight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065A60).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flight, color: Color(0xFF065A60), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      flight.airlineName,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: flight.flightStatus == 'scheduled' || flight.flightStatus == 'active' 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    flight.flightStatus.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10, 
                      fontWeight: FontWeight.w700,
                      color: flight.flightStatus == 'scheduled' || flight.flightStatus == 'active' 
                        ? Colors.green[700] 
                        : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                   flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flight.departureIata,
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
                      ),
                      Text(
                        flight.departureTime,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flight.departureAirport,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text(
                        flight.flightDate,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.flight_takeoff_rounded, color: Colors.grey[300], size: 28),
                      const SizedBox(height: 4),
                      Text(
                        flight.flightIata,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF065A60)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        flight.arrivalIata,
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
                      ),
                      Text(
                        flight.arrivalTime,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flight.arrivalAirport,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          'Domestic Flights 🇮🇳',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF065A60),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                // Origin Input
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _originController,
                    style: GoogleFonts.poppins(color: const Color(0xFF1A1A2E), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Departure City (e.g., Mumbai)',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.flight_takeoff, color: Color(0xFF065A60), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Destination Input
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _destController,
                    style: GoogleFonts.poppins(color: const Color(0xFF1A1A2E), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Destination City (e.g., Delhi) (Optional)',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.flight_land, color: Color(0xFF065A60), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _searchFlights,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Search Flights', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _errorMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                : _flights.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          'Enter origin & destination to search.',
                          style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _flights.length,
                        itemBuilder: (context, index) {
                          return _buildFlightCard(_flights[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
