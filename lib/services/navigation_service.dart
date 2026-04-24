import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// A single OSRM turn-by-turn navigation step.
class NavigationStep {
  final String instruction;   // Human-readable turn instruction
  final double distanceMeters;
  final LatLng location;       // Maneuver point

  const NavigationStep({
    required this.instruction,
    required this.distanceMeters,
    required this.location,
  });

  factory NavigationStep.fromOsrm(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final name = (step['name'] as String? ?? '').trim();
    final langCode = step['langCode'] as String? ?? 'en-IN';

    final instruction = _buildInstruction(type, modifier, name, langCode);
    final distance = (step['distance'] as num?)?.toDouble() ?? 0;

    final locList = maneuver['location'] as List<dynamic>? ?? [0.0, 0.0];
    final loc = LatLng(locList[1].toDouble(), locList[0].toDouble()); // OSRM is [lon, lat]

    return NavigationStep(
      instruction: instruction,
      distanceMeters: distance,
      location: loc,
    );
  }

  static String _buildInstruction(String type, String modifier, String name, String langCode) {
    // Localization Mapping
    final Map<String, Map<String, dynamic>> i18n = {
      'en-IN': {
        'left': 'Turn left',
        'right': 'Turn right',
        'sharp_left': 'Turn sharp left',
        'sharp_right': 'Turn sharp right',
        'slight_left': 'Keep slight left',
        'slight_right': 'Keep slight right',
        'uturn': 'Make a U-turn',
        'continue': 'Continue',
        'onto': ' onto ',
        'head': 'Head towards ',
        'start': 'Start navigation',
        'arrive': 'You have arrived at your destination',
        'merge': 'Merge',
        'ramp_l': 'Take the ramp on the left',
        'ramp_r': 'Take the ramp on the right',
        'fork_l': 'Keep left at the fork',
        'fork_r': 'Keep right at the fork',
        'end_l': 'Turn left at the end of the road',
        'end_r': 'Turn right at the end of the road',
        'roundabout': 'At the roundabout, take ',
        'exit': ' exit',
        'next': 'the next',
        'straight': 'Continue straight',
      },
      'hi-IN': {
        'left': 'बाएँ मुड़ें',
        'right': 'दाएँ मुड़ें',
        'sharp_left': 'तेजी से बाएँ मुड़ें',
        'sharp_right': 'तेजी से दाएँ मुड़ें',
        'slight_left': 'हल्का बाएँ रहें',
        'slight_right': 'हल्का दाएँ रहें',
        'uturn': 'यू-टर्न लें',
        'continue': 'जारी रखें',
        'onto': ' पर ',
        'head': 'की ओर चलें ',
        'start': 'नेविगेशन शुरू करें',
        'arrive': 'आप अपनी मंजिल पर पहुँच गए हैं',
        'merge': 'मिलें',
        'ramp_l': 'बाईं ओर के रैंप पर चढ़ें',
        'ramp_r': 'दाईं ओर के रैंप पर चढ़ें',
        'fork_l': 'कांटे पर बाएँ रहें',
        'fork_r': 'कांटे पर दाएँ रहें',
        'end_l': 'सड़क के अंत में बाएँ मुड़ें',
        'end_r': 'सड़क के अंत में दाएँ मुड़ें',
        'roundabout': 'चौराहे पर, टर्न लें ',
        'exit': ' निकास',
        'next': 'अगला',
        'straight': 'सीधे चलते रहें',
      },
      'gu-IN': {
        'left': 'ડાબે વળો',
        'right': 'જમણે વળો',
        'sharp_left': 'ઝડપથી ડાબે વળો',
        'sharp_right': 'ઝડપથી જમણે વળો',
        'slight_left': 'થોડા ડાબે રહો',
        'slight_right': 'થોડા જમણે રહો',
        'uturn': 'યુ-ટર્ન લો',
        'continue': 'ચાલુ રાખો',
        'onto': ' પર ',
        'head': 'તરફ આગળ વધો ',
        'start': 'નેવિગેશન શરૂ કરો',
        'arrive': 'તમે તમારા ગંતવ્ય પર પહોંચી ગયા છો',
        'merge': 'ભેગા થાઓ',
        'ramp_l': 'ડાબી બાજુના રેમ્પ પર લો',
        'ramp_r': 'જમણી બાજુના રેમ્પ પર લો',
        'fork_l': 'ફોર્ક પર ડાબે રહો',
        'fork_r': 'ફોર્ક પર જમણે રહો',
        'end_l': 'રસ્તાના અંતે ડાબે વળો',
        'end_r': 'રસ્તાના અંતે જમણે વળો',
        'roundabout': 'રાઉન્ડઅબાઉટ પર, લો ',
        'exit': ' એક્ઝિટ',
        'next': 'આગળની',
        'straight': 'સીધા આગળ વધો',
      },
      'ta-IN': {
        'left': 'இடதுபுறம் திரும்பவும்',
        'right': 'வலதுபுறம் திரும்பவும்',
        'sharp_left': 'கடுமையாக இடதுபுறம் திரும்பவும்',
        'sharp_right': 'கடுமையாக வலதுபுறம் திரும்பவும்',
        'slight_left': 'சற்று இடதுபுறமாக செல்லவும்',
        'slight_right': 'சற்று வலதுபுறமாக செல்லவும்',
        'uturn': 'யூ-டர்ன் எடுக்கவும்',
        'continue': 'தொடரவும்',
        'onto': ' இல் ',
        'head': 'நோக்கிச் செல்லுங்கள் ',
        'start': 'வழிசெலுத்தலைத் தொடங்கவும்',
        'arrive': 'உங்கள் இலக்கை அடைந்துவிட்டீர்கள்',
        'merge': 'இணையுங்கள்',
        'ramp_l': 'இடதுபுறம் உள்ள ராம்பை எடுக்கவும்',
        'ramp_r': 'வலதுபுறம் உள்ள ராம்பை எடுக்கவும்',
        'fork_l': 'முச்சந்தியில் இடதுபுறமாகவே செல்லவும்',
        'fork_r': 'முச்சந்தியில் வலதுபுறமாகவே செல்லவும்',
        'end_l': 'சாலையின் முடிவில் இடதுபுறம் திரும்பவும்',
        'end_r': 'சாலையின் முடிவில் வலதுபுறம் திரும்பவும்',
        'roundabout': 'வட்டச் சாலையில், எடுக்கவும் ',
        'exit': ' வெளியேறு',
        'next': 'அடுத்த',
        'straight': 'நேராகத் தொடரவும்',
      },
    };

    final Map<String, dynamic> t = i18n[langCode] ?? i18n['en-IN']!;

    final dest = name.isNotEmpty ? '${t['onto']}$name' : '';
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':        return '${t['left']}$dest';
          case 'right':       return '${t['right']}$dest';
          case 'sharp left':  return '${t['sharp_left']}$dest';
          case 'sharp right': return '${t['sharp_right']}$dest';
          case 'slight left': return '${t['slight_left']}$dest';
          case 'slight right':return '${t['slight_right']}$dest';
          case 'uturn':       return '${t['uturn']}$dest';
          default:            return '${t['continue']}$dest';
        }
      case 'depart':      return name.isNotEmpty ? '${t['head']}$name' : '${t['start']}';
      case 'arrive':      return '${t['arrive']}';
      case 'merge':       return '${t['merge']}$dest';
      case 'ramp':        return modifier.contains('left') ? '${t['ramp_l']}' : '${t['ramp_r']}';
      case 'fork':        return modifier.contains('left') ? '${t['fork_l']}' : '${t['fork_r']}';
      case 'end of road': return modifier.contains('left') ? '${t['end_l']}' : '${t['end_r']}';
      case 'roundabout':
      case 'rotary':
        final exitNum = (modifier.isNotEmpty) ? modifier : '${t['next']}';
        return '${t['roundabout']}$exitNum${t['exit']}';
      case 'continue':    return '${t['straight']}$dest';
      case 'new name':    return '${t['continue']}$dest';
      default:            return name.isNotEmpty ? '${t['continue']}$dest' : '${t['straight']}';
    }
  }

  /// Icon to display for this step
  String get directionEmoji {
    final lower = instruction.toLowerCase();
    if (lower.contains('sharp left'))   return '↰';
    if (lower.contains('slight left'))  return '↖';
    if (lower.contains('left'))         return '←';
    if (lower.contains('sharp right'))  return '↱';
    if (lower.contains('slight right')) return '↗';
    if (lower.contains('right'))        return '→';
    if (lower.contains('u-turn'))       return '↩';
    if (lower.contains('roundabout'))   return '↻';
    if (lower.contains('arrived'))      return '🏁';
    if (lower.contains('head') || lower.contains('start')) return '▲';
    return '↑';
  }
}

/// Stateful navigation tracker that:
/// - Holds the list of OSRM steps
/// - Tracks which step is active based on the user's current position
/// - Reports the index of the closest route point (for polyline splitting)
class NavigationService {
  final List<NavigationStep> steps;
  int _currentStepIndex = 0;

  NavigationService({required this.steps});

  bool get hasSteps => steps.isNotEmpty;

  NavigationStep? get currentStep =>
      _currentStepIndex < steps.length ? steps[_currentStepIndex] : null;

  NavigationStep? get nextStep =>
      _currentStepIndex + 1 < steps.length ? steps[_currentStepIndex + 1] : null;

  /// Advance the step index if the user is past the current step's trigger
  /// radius (30 m). Returns true if a new step started.
  bool updatePosition(LatLng pos) {
    if (_currentStepIndex >= steps.length - 1) return false;
    final step = steps[_currentStepIndex];
    final distToStep = _haversine(pos, step.location);
    // Move to the next step once we're within 30 m of this maneuver point
    // OR once we've moved beyond it (>120 m to the maneuver and we're closer
    // to the NEXT step than to the current one).
    if (distToStep < 30) {
      _currentStepIndex++;
      return true;
    }
    return false;
  }

  /// Formatted distance string to the NEXT maneuver.
  String get distanceToNextTurn {
    final step = currentStep;
    if (step == null) return '';
    final m = step.distanceMeters;
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  /// Find the index in [routePoints] that is closest to [pos].
  static int closestIndex(LatLng pos, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final d = _haversine(pos, routePoints[i]);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Haversine distance in metres between two LatLng points.
  static double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinDlat = math.sin(dLat / 2);
    final sinDlon = math.sin(dLon / 2);
    final aVal = sinDlat * sinDlat + math.cos(lat1) * math.cos(lat2) * sinDlon * sinDlon;
    return R * 2 * math.atan2(math.sqrt(aVal), math.sqrt(1 - aVal));
  }

  /// Haversine distance in **kilometres** — public helper for polyline summing.
  static double haversineKm(LatLng a, LatLng b) => _haversine(a, b) / 1000.0;
}
