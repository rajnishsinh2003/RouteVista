import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flight_model.dart';
import 'package:flutter/foundation.dart';

class FlightService {
  static const String _apiKey = 'f3ac55abd955d575407c584955fc84ea';
  static const String _baseUrl = 'http://api.aviationstack.com/v1/flights';

  static const Map<String, String> indianAirports = {
    'delhi': 'DEL',
    'new delhi': 'DEL',
    'mumbai': 'BOM',
    'bangalore': 'BLR',
    'bengaluru': 'BLR',
    'hyderabad': 'HYD',
    'chennai': 'MAA',
    'kolkata': 'CCU',
    'ahmedabad': 'AMD',
    'pune': 'PNQ',
    'goa': 'GOI',
    'jaipur': 'JAI',
    'lucknow': 'LKO',
    'guwahati': 'GAU',
    'thiruvananthapuram': 'TRV',
    'trivandrum': 'TRV',
    'patna': 'PAT',
    'bhopal': 'BHO',
    'indore': 'IDR',
    'chandigarh': 'IXC',
    'kochi': 'COK',
    'cochin': 'COK',
    'bhubaneswar': 'BBI',
    'mangalore': 'IXE',
    'amritsar': 'ATQ',
    'nagpur': 'NAG',
    'varanasi': 'VNS',
    'surat': 'STV',
    'vadodara': 'BDQ',
    'coimbatore': 'CJB',
    'madurai': 'IXM',
    'port blair': 'IXZ',
    'ranchi': 'IXR',
    'raipur': 'RPR',
    'agartala': 'IXA',
    'imphal': 'IMF',
    'jammu': 'IXJ',
    'srinagar': 'SXR',
    'leh': 'IXL',
    'udaipur': 'UDR',
    'jodhpur': 'JDH',
    'dehradun': 'DED',
    'bagdogra': 'IXB',
    'siliguri': 'IXB',
  };

  static String? getIataFromCity(String city) {
    if (city.isEmpty) return null;
    final lowerCity = city.toLowerCase().trim();
    if (indianAirports.containsKey(lowerCity)) {
        return indianAirports[lowerCity];
    }
    // Partial matches
    for (final entry in indianAirports.entries) {
      if (lowerCity.contains(entry.key) || entry.key.contains(lowerCity)) {
        return entry.value;
      }
    }
    return null;
  }

  static Future<List<FlightModel>> searchDomesticFlights(String originCity, String targetCity) async {
    try {
      final originIata = getIataFromCity(originCity);
      final targetIata = getIataFromCity(targetCity);

      if (originIata == null) {
        throw Exception("Origin city not found or doesn't have a major airport.");
      }

      String url = '$_baseUrl?access_key=$_apiKey&dep_iata=$originIata';
      if (targetIata != null) {
        url += '&arr_iata=$targetIata';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          final List flightsData = data['data'];
          List<FlightModel> flights = flightsData
              .map((json) => FlightModel.fromJson(json))
              .toList();
          
          // Domestic filter: Target must also be in India (usually timezone Asia/Kolkata).
          flights = flights.where((f) {
            final isArrivalInKolkataTimezone = f.arrival['timezone'] == 'Asia/Kolkata';
            final isArrivalIataInIndia = indianAirports.values.contains(f.arrivalIata.toUpperCase());
            return isArrivalInKolkataTimezone || isArrivalIataInIndia;
          }).toList();

          return flights;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching domestic flights: $e');
      rethrow;
    }
  }
}
