class TourPlan {
  final String id;
  final String title;
  final String destination;
  final String routeHint; // e.g. "Delhi → Agra → Jaipur"
  final int month; // 1–12
  final int durationDays;
  final String budgetRange;
  final String difficulty; // Easy / Moderate / Hard
  final List<String> highlights;
  final String bestFor; // "Family, Couple"
  final String weatherNote;
  final String description;
  final String heroEmoji;
  final String? imageUrl; // New field for photos
  final List<String> thingsToDo;
  final List<String> thingsToEat;
  final List<String> tips;
  final String bestTimeDetail;
  bool isBookmarked;

  TourPlan({
    required this.id,
    required this.title,
    required this.destination,
    required this.routeHint,
    required this.month,
    required this.durationDays,
    required this.budgetRange,
    required this.difficulty,
    required this.highlights,
    required this.bestFor,
    required this.weatherNote,
    required this.description,
    required this.heroEmoji,
    this.imageUrl, // New optional parameter
    required this.thingsToDo,
    required this.thingsToEat,
    required this.tips,
    required this.bestTimeDetail,
    this.isBookmarked = false,
  });

  String get monthName {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month];
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'destination': destination,
    'routeHint': routeHint, 'month': month, 'durationDays': durationDays,
    'budgetRange': budgetRange, 'difficulty': difficulty,
    'highlights': highlights, 'bestFor': bestFor,
    'weatherNote': weatherNote, 'description': description,
    'heroEmoji': heroEmoji, 'imageUrl': imageUrl,
    'thingsToDo': thingsToDo, 'thingsToEat': thingsToEat,
    'tips': tips, 'bestTimeDetail': bestTimeDetail,
    'isBookmarked': isBookmarked,
  };

  factory TourPlan.fromJson(Map<String, dynamic> j) => TourPlan(
    id: j['id'], title: j['title'], destination: j['destination'],
    routeHint: j['routeHint'] ?? j['destination'],
    month: j['month'], durationDays: j['durationDays'],
    budgetRange: j['budgetRange'], difficulty: j['difficulty'],
    highlights: List<String>.from(j['highlights']),
    bestFor: j['bestFor'], weatherNote: j['weatherNote'],
    description: j['description'], heroEmoji: j['heroEmoji'] ?? '🗺️',
    imageUrl: j['imageUrl'],
    thingsToDo: List<String>.from(j['thingsToDo'] ?? []),
    thingsToEat: List<String>.from(j['thingsToEat'] ?? []),
    tips: List<String>.from(j['tips'] ?? []),
    bestTimeDetail: j['bestTimeDetail'] ?? '',
    isBookmarked: j['isBookmarked'] ?? false,
  );
}
