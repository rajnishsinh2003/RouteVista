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
    final locationArr = maneuver['location'] as List?;
    final loc = locationArr != null && locationArr.length >= 2
        ? LatLng(
            (locationArr[1] as num).toDouble(),
            (locationArr[0] as num).toDouble(),
          )
        : const LatLng(0, 0);

    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';
    final name = (step['name'] as String? ?? '').trim();

    final instruction = _buildInstruction(type, modifier, name);
    final distance = (step['distance'] as num?)?.toDouble() ?? 0;

    return NavigationStep(
      instruction: instruction,
      distanceMeters: distance,
      location: loc,
    );
  }

  static String _buildInstruction(String type, String modifier, String name) {
    final dest = name.isNotEmpty ? ' onto $name' : '';
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':        return 'Turn left$dest';
          case 'right':       return 'Turn right$dest';
          case 'sharp left':  return 'Turn sharp left$dest';
          case 'sharp right': return 'Turn sharp right$dest';
          case 'slight left': return 'Keep slight left$dest';
          case 'slight right':return 'Keep slight right$dest';
          case 'uturn':       return 'Make a U-turn$dest';
          default:            return 'Continue$dest';
        }
      case 'depart':      return name.isNotEmpty ? 'Head towards $name' : 'Start navigation';
      case 'arrive':      return 'You have arrived at your destination';
      case 'merge':       return 'Merge$dest';
      case 'ramp':        return modifier.contains('left') ? 'Take the ramp on the left' : 'Take the ramp on the right';
      case 'fork':        return modifier.contains('left') ? 'Keep left at the fork' : 'Keep right at the fork';
      case 'end of road': return modifier.contains('left') ? 'Turn left at the end of the road' : 'Turn right at the end of the road';
      case 'roundabout':
      case 'rotary':
        final exit = (modifier.isNotEmpty) ? modifier : 'the next';
        return 'At the roundabout, take $exit exit';
      case 'continue':    return 'Continue straight$dest';
      case 'new name':    return 'Continue$dest';
      default:            return name.isNotEmpty ? 'Continue onto $name' : 'Continue straight';
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
