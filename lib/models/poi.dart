import 'package:latlong2/latlong.dart';

enum PlaceType { religious, history, nature, cultural, food, hotel, fuel, hospital, police, other }

enum VehicleType { bike, car, bus, luxuryBus }

enum FuelType { petrol, diesel, cng }

class TripPOI {
  final String id;
  final String name;
  final PlaceType type;
  final LatLng location;
  final double rating;
  final double entryFee;
  double distanceFromUser;

  TripPOI({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.rating = 4.5,
    this.entryFee = 0.0,
    this.distanceFromUser = 0.0,
  });
}

class TripBudget {
  double fuelCost;
  double foodCost;
  double accommodation;
  double entryTickets;
  double tollCharges;

  double get total => fuelCost + foodCost + accommodation + entryTickets + tollCharges;

  TripBudget({
    this.fuelCost = 0,
    this.foodCost = 0,
    this.accommodation = 0,
    this.entryTickets = 0,
    this.tollCharges = 0,
  });
}

class WeatherInfo {
  final double temp;
  final String condition;
  final double windSpeed;
  final int humidity;
  WeatherInfo({
    required this.temp,
    required this.condition,
    this.windSpeed = 0,
    this.humidity = 0,
  });
}

// Indian fuel rates (₹ per litre/kg) — approximate 2024-25
class FuelRates {
  static double getRate(FuelType type) {
    switch (type) {
      case FuelType.petrol:
        return 105.0;
      case FuelType.diesel:
        return 90.0;
      case FuelType.cng:
        return 80.0;
    }
  }

  static String label(FuelType type) {
    switch (type) {
      case FuelType.petrol:
        return 'Petrol';
      case FuelType.diesel:
        return 'Diesel';
      case FuelType.cng:
        return 'CNG';
    }
  }
}

// Default mileage (km per litre/kg)
class VehicleDefaults {
  static double mileage(VehicleType v) {
    switch (v) {
      case VehicleType.bike:
        return 45.0;
      case VehicleType.car:
        return 15.0;
      case VehicleType.bus:
        return 5.0;
      case VehicleType.luxuryBus:
        return 4.0;
    }
  }

  static String label(VehicleType v) {
    switch (v) {
      case VehicleType.bike:
        return 'Bike 🏍️';
      case VehicleType.car:
        return 'Car 🚗';
      case VehicleType.bus:
        return 'Bus 🚌';
      case VehicleType.luxuryBus:
        return 'Luxury Bus 🚎';
    }
  }

  static String icon(VehicleType v) {
    switch (v) {
      case VehicleType.bike:
        return '🏍️';
      case VehicleType.car:
        return '🚗';
      case VehicleType.bus:
        return '🚌';
      case VehicleType.luxuryBus:
        return '🚎';
    }
  }

  // Whether the vehicle is available for this distance
  static bool isAvailable(VehicleType v, double distanceKm) {
    if (v == VehicleType.bike && distanceKm > 100) return false;
    if (v == VehicleType.luxuryBus && distanceKm < 50) return false; // Too short for luxury bus
    return true;
  }
}

// Budget calculator utility
class BudgetCalculator {
  static TripBudget calculate({
    required double distanceKm,
    required double durationHrs,
    required VehicleType vehicle,
    required FuelType fuelType,
    int travelers = 1,
  }) {
    final mileage = VehicleDefaults.mileage(vehicle);
    final rate = FuelRates.getRate(fuelType);
    final fuelNeeded = distanceKm / mileage;
    final fuelCost = fuelNeeded * rate;

    // Food: ₹200 per meal per person, 1 meal every 4 hours
    final meals = (durationHrs / 4).ceil();
    final foodCost = meals * 200.0 * travelers;

    // Accommodation: ₹1500/night if >10 hrs
    final nights = durationHrs > 10 ? (durationHrs / 24).ceil() : 0;
    double accommodation;
    switch (vehicle) {
      case VehicleType.luxuryBus:
        accommodation = nights * 3000.0;
        break;
      case VehicleType.bus:
        accommodation = nights * 1500.0;
        break;
      case VehicleType.car:
        accommodation = nights * 2000.0;
        break;
      case VehicleType.bike:
        accommodation = nights * 1000.0;
        break;
    }

    // Tolls: rough estimate ₹2/km for car, ₹5/km for bus
    double tolls = 0;
    if (vehicle == VehicleType.car) tolls = distanceKm * 1.5;
    if (vehicle == VehicleType.bus || vehicle == VehicleType.luxuryBus) {
      tolls = distanceKm * 3.0;
    }

    return TripBudget(
      fuelCost: fuelCost,
      foodCost: foodCost,
      accommodation: accommodation,
      tollCharges: tolls,
    );
  }

  // Check if current fuel is enough
  static Map<String, dynamic> checkFuelSufficiency({
    required double currentFuelLitres,
    required double vehicleAverage, // km per litre
    required double totalDistanceKm,
  }) {
    final rangeWithCurrentFuel = currentFuelLitres * vehicleAverage;
    final isEnough = rangeWithCurrentFuel >= totalDistanceKm;
    final remainingAfterTrip = rangeWithCurrentFuel - totalDistanceKm;
    final needsRefuel = rangeWithCurrentFuel < 50; // less than 50km range

    return {
      'range_km': rangeWithCurrentFuel,
      'is_enough': isEnough,
      'remaining_km': remainingAfterTrip,
      'needs_refuel_soon': needsRefuel,
      'fuel_needed_litres': isEnough ? 0.0 : (totalDistanceKm - rangeWithCurrentFuel) / vehicleAverage,
    };
  }
}