class FlightModel {
  final String flightDate;
  final String flightStatus;
  final Map<String, dynamic> departure;
  final Map<String, dynamic> arrival;
  final Map<String, dynamic> airline;
  final Map<String, dynamic> flight;

  FlightModel({
    required this.flightDate,
    required this.flightStatus,
    required this.departure,
    required this.arrival,
    required this.airline,
    required this.flight,
  });

  factory FlightModel.fromJson(Map<String, dynamic> json) {
    return FlightModel(
      flightDate: json['flight_date']?.toString() ?? '',
      flightStatus: json['flight_status']?.toString() ?? 'unknown',
      departure: json['departure'] as Map<String, dynamic>? ?? {},
      arrival: json['arrival'] as Map<String, dynamic>? ?? {},
      airline: json['airline'] as Map<String, dynamic>? ?? {},
      flight: json['flight'] as Map<String, dynamic>? ?? {},
    );
  }

  String get flightIata => flight['iata']?.toString() ?? 'Unknown';
  String get airlineName => airline['name']?.toString() ?? 'Unknown Airline';
  String get departureAirport => departure['airport']?.toString() ?? 'Origin';
  String get departureIata => departure['iata']?.toString() ?? 'ORG';
  String get arrivalAirport => arrival['airport']?.toString() ?? 'Destination';
  String get arrivalIata => arrival['iata']?.toString() ?? 'DST';
  String get scheduledDeparture => departure['scheduled']?.toString() ?? '';
  String get scheduledArrival => arrival['scheduled']?.toString() ?? '';
  String get departureTime => _formatTime(scheduledDeparture);
  String get arrivalTime => _formatTime(scheduledArrival);

  String _formatTime(String isoString) {
    if (isoString.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '--:--';
    }
  }
}
