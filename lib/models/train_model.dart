class TrainModel {
  final String number;
  final String name;
  final String from;
  final String to;
  final String departure;
  final String arrival;
  final String duration;
  final List<String> classes;
  final Map<String, dynamic> prices;

  TrainModel({
    required this.number,
    required this.name,
    required this.from,
    required this.to,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.classes,
    required this.prices,
  });

  factory TrainModel.fromJson(Map<String, dynamic> json) {
    return TrainModel(
      number: json['number'] ?? '',
      name: json['name'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      departure: json['departure'] ?? '',
      arrival: json['arrival'] ?? '',
      duration: json['duration'] ?? '',
      classes: List<String>.from(json['class'] ?? []),
      prices: json['price'] ?? {},
    );
  }
}
