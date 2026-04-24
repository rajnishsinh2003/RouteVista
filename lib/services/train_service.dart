import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/train_model.dart';

class TrainService {
  static List<TrainModel>? _cachedTrains;

  static Future<List<TrainModel>> _loadTrains() async {
    if (_cachedTrains != null) return _cachedTrains!;
    
    try {
      final String response = await rootBundle.loadString('assets/json/train_dataset_1200.json');
      final data = json.decode(response);
      final List<dynamic> trainsList = data['trains'];
      _cachedTrains = trainsList.map((json) => TrainModel.fromJson(json)).toList();
      return _cachedTrains!;
    } catch (e) {
      print('Error loading trains: $e');
      return [];
    }
  }

  static Future<List<TrainModel>> searchTrains(String fromCity, String toCity) async {
    final allTrains = await _loadTrains();
    
    final queryFrom = fromCity.toLowerCase().trim();
    final queryTo = toCity.toLowerCase().trim();

    return allTrains.where((train) {
      final trainFrom = train.from.toLowerCase();
      final trainTo = train.to.toLowerCase();

      bool fromMatch = trainFrom.contains(queryFrom) || queryFrom.contains(trainFrom);
      bool targetMatch = toCity.isEmpty || (trainTo.contains(queryTo) || queryTo.contains(trainTo));

      return fromMatch && targetMatch;
    }).toList();
  }
}
