import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/hotel_model.dart';
import 'dart:math';

class HotelService {
  static const Map<String, List<String>> _stateHotels = {
    "andhra_pradesh": [
      "Novotel Visakhapatnam","The Park Visakhapatnam","Dolphin Hotel Vizag","GreenPark Hotel Visakhapatnam",
      "Taj Tirupati","Marasa Sarovar Premiere Tirupati","Fortune Select Grand Ridge Tirupati",
      "Quality Hotel D V Manor Vijayawada","Novotel Vijayawada","The Gateway Hotel Vijayawada",
      "Hotel Daspalla Visakhapatnam","Palm Beach Hotel Vizag","Hotel Bliss Tirupati"
    ],
    "arunachal_pradesh": [
      "Hotel Tawang Heights","Hotel Mon Valley Tawang","Dolma Khangsar Guest House",
      "Hotel Ziro Palace","Blue Pine Hotel Itanagar","Hotel Pybss Itanagar",
      "Hotel Donyi Polo Ashok Itanagar","Hotel Kameng Bomdila","Hotel Pemaling Dirang"
    ],
    "assam": [
      "Radisson Blu Guwahati","Vivanta Guwahati","Novotel Guwahati","Hotel Dynasty Guwahati",
      "Hotel Prag Continental Guwahati","The Guwahati Address","Hotel Nandan Guwahati",
      "Hotel Brahmaputra Ashok Guwahati","Hotel Landmark Guwahati","Hotel Royal Heritage Guwahati"
    ],
    "bihar": [
      "Hotel Maurya Patna","Lemon Tree Premier Patna","Hotel Chanakya Patna","Hotel Republic Patna",
      "Hotel Patliputra Ashok","Hotel Gargee Grand Patna","Hotel Patliputra Continental",
      "Hotel Taj Darbar Bodh Gaya","Hotel Bodhgaya Regency","Hotel Royal Residency Bodh Gaya"
    ],
    "chhattisgarh": [
      "Courtyard by Marriott Raipur","Sayaji Hotel Raipur","Hotel Babylon International Raipur",
      "Hotel Grand Imperia Raipur","Hotel Simran Heritage Raipur","Hotel Celebration Raipur",
      "Hotel Devendra Raipur","Hotel Meera Raipur","Hotel Aditya Raipur"
    ],
    "delhi": [
      "The Leela Palace New Delhi","Taj Palace New Delhi","ITC Maurya Delhi","The Oberoi New Delhi",
      "Shangri-La Eros New Delhi","Hyatt Regency Delhi","The Lalit New Delhi","Le Meridien New Delhi"
    ],
    "goa": [
      "Taj Exotica Goa","The Leela Goa","Grand Hyatt Goa","ITC Grand Goa",
      "Novotel Goa Resort","Radisson Blu Goa","Holiday Inn Resort Goa",
      "Zuri White Sands Goa","Cidade de Goa Resort","Alila Diwa Goa"
    ],
    "gujarat": [
      "The Leela Gandhinagar","Hyatt Ahmedabad","Courtyard by Marriott Ahmedabad",
      "Radisson Blu Ahmedabad","Taj Skyline Ahmedabad","Fortune Landmark Ahmedabad",
      "Cambay Grand Ahmedabad","The Fern Residency Vadodara","Sayaji Hotel Vadodara"
    ],
    "haryana": [
      "The Oberoi Gurgaon","Trident Gurgaon","Leela Ambience Gurgaon",
      "Hyatt Regency Gurgaon","The Westin Gurgaon","Radisson Blu Faridabad",
      "Park Plaza Gurgaon","Holiday Inn Gurgaon","Fortune Select Global Gurgaon"
    ],
    "himachal_pradesh": [
      "The Oberoi Cecil Shimla","Wildflower Hall Shimla","Radisson Hotel Shimla",
      "Clarkes Hotel Shimla","Snow Valley Resorts Shimla","Span Resort Manali",
      "The Himalayan Manali","Solang Valley Resort","Apple Country Resort Manali"
    ],
    "karnataka": [
      "The Leela Palace Bangalore","ITC Gardenia Bangalore","Taj West End Bangalore",
      "The Oberoi Bangalore","Radisson Blu Bangalore","JW Marriott Bangalore",
      "Shangri-La Bangalore","Hyatt Centric Bangalore","The Ritz-Carlton Bangalore"
    ],
    "kerala": [
      "Kumarakom Lake Resort","Taj Bekal Resort","The Leela Kovalam",
      "Vivanta Trivandrum","Spice Village Thekkady","Vythiri Village Wayanad",
      "Fragrant Nature Kochi","The Raviz Kovalam","Brunton Boatyard Kochi"
    ],
    "maharashtra": [
      "The Taj Mahal Palace Mumbai","The Oberoi Mumbai","Trident Nariman Point",
      "ITC Grand Central Mumbai","JW Marriott Mumbai","The St. Regis Mumbai",
      "Hyatt Regency Mumbai","Novotel Juhu Beach","The Leela Mumbai",
      "Radisson Blu Nagpur","Taj Lands End Mumbai","The Westin Pune"
    ],
    "rajasthan": [
      "Taj Lake Palace Udaipur","Oberoi Udaivilas Udaipur","Rambagh Palace Jaipur",
      "Umaid Bhawan Palace Jodhpur","Samode Palace Jaipur","ITC Rajputana Jaipur",
      "Fairmont Jaipur","Leela Palace Udaipur","Hotel Ajit Bhawan Jodhpur"
    ],
    "tamil_nadu": [
      "Taj Coromandel Chennai","The Leela Palace Chennai","ITC Grand Chola Chennai",
      "Hyatt Regency Chennai","Radisson Blu Chennai","The Park Chennai",
      "Vivanta Chennai","Trident Chennai","The Residency Chennai"
    ],
    "uttar_pradesh": [
      "Taj Hotel Agra","ITC Mughal Agra","The Oberoi Amarvilas Agra",
      "Radisson Blu Agra","Hotel Clarks Shiraz Agra","Jaypee Palace Agra",
      "Trident Agra","Hotel Taj Vilas Agra","Hotel Crystal Sarovar Agra"
    ],
    "west_bengal": [
      "The Oberoi Grand Kolkata","ITC Sonar Kolkata","Taj Bengal Kolkata",
      "Hyatt Regency Kolkata","The Lalit Great Eastern Kolkata",
      "JW Marriott Kolkata","Novotel Kolkata","Peerless Inn Kolkata"
    ]
  };

  static final Random _random = Random();

  /// Map raw state name from Geolocator to our internal keys
  static String normalizeStateName(String rawState) {
    String state = rawState.toLowerCase().replaceAll(' ', '_');
    if (_stateHotels.containsKey(state)) return state;
    if (state.contains('delhi')) return 'delhi';
    if (state.contains('maharashtra')) return 'maharashtra';
    return 'maharashtra'; // Default fallback state
  }

  static Future<HotelModel> fetchHotelDetails(String hotelName, String stateName) async {
    final query = hotelName.replaceAll(' ', '_');
    final url = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$query');
    
    // Diversified fallback images so each hotel gets a unique one
    const fallbackImages = [
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1582719508461-905c673771fd?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1564501049412-61c2a3083791?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
    ];
    
    String imageUrl = fallbackImages[hotelName.length % fallbackImages.length];
    String description = 'A luxury and premium hotel offering superior services locally. Enjoy state-of-the-art amenities and world-class hospitality in the heart of $stateName.';

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['thumbnail'] != null && data['thumbnail']['source'] != null) {
          imageUrl = data['thumbnail']['source'];
        } else if (data['originalimage'] != null && data['originalimage']['source'] != null) {
           imageUrl = data['originalimage']['source'];
        }
        
        if (data['extract'] != null && data['extract'].toString().isNotEmpty) {
          description = data['extract'];
        }
      }
    } catch (e) {
      debugPrint('Wikipedia failed for $hotelName: $e');
    }

    return HotelModel(
      name: hotelName,
      description: description,
      imageUrl: imageUrl,
      location: stateName.replaceAll('_', ' ').toUpperCase(),
    );
  }

  /// Get a batch of hotels for a specific state
  static Future<List<HotelModel>> getNearbyHotels(String rawState, {int count = 5}) async {
    final stateKey = normalizeStateName(rawState);
    List<String> hotels = _stateHotels[stateKey] ?? _stateHotels['maharashtra']!;
    
    // We only take the first `count` to avoid blocking UI or rate-limiting
    final selectedHotels = hotels.take(count).toList();
    
    // Fetch all sequentially or parallelly (Parallel might trigger 429 if too many)
    List<HotelModel> results = [];
    for (String h in selectedHotels) {
      final model = await fetchHotelDetails(h, stateKey);
      results.add(model);
    }
    return results;
  }
}
