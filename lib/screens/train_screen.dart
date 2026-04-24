import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/train_service.dart';
import '../models/train_model.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  List<TrainModel> _trains = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
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
           if (mounted) {
             setState(() {
               _fromController.text = cleanedCity;
             });
           }
        }
      }
    } catch (e) {
      debugPrint("Could not fetch location for origin city.");
    }
  }

  Future<void> _searchTrains() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();

    if (from.isEmpty) {
      setState(() => _errorMessage = "Please enter a departure city.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _trains = [];
    });

    try {
      final results = await TrainService.searchTrains(from, to);
      
      if (mounted) {
        setState(() {
          _trains = results;
          _isLoading = false;
          if (results.isEmpty) {
             _errorMessage = "No trains found for this route in our dataset.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error searching trains: $e";
        });
      }
    }
  }

  Widget _buildTrainCard(TrainModel train) {
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            train.name,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                          ),
                          Text(
                            'Train #${train.number}',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF065A60), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.train, color: Color(0xFF065A60)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          train.departure,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          train.from,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          train.duration,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.arrow_forward, color: Colors.grey[300], size: 20),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          train.arrival,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          train.to,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: train.classes.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c,
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                          ),
                        );
                      }).toList(),
                    ),
                    Text(
                      'from ₹${train.prices.values.first}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF00BFA6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
          'Train Search 🚆',
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
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _fromController,
                    style: GoogleFonts.poppins(color: const Color(0xFF1A1A2E), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'From (e.g., Surat)',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFF065A60), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _toController,
                    style: GoogleFonts.poppins(color: const Color(0xFF1A1A2E), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'To (e.g., Howrah)',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: const Icon(Icons.flag, color: Color(0xFF065A60), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _searchTrains,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Search Trains', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
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
                : _trains.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          'Enter origin & destination to search.',
                          style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trains.length,
                        itemBuilder: (context, index) {
                          return _buildTrainCard(_trains[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
