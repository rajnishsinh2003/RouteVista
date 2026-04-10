import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/poi_service.dart';

class PoiFilterBar extends StatelessWidget {
  final List<PoiModel> allPois;
  final Set<String> activeCategories;
  final void Function(String category) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectNone;

  const PoiFilterBar({
    super.key,
    required this.allPois,
    required this.activeCategories,
    required this.onToggle,
    required this.onSelectAll,
    required this.onSelectNone,
  });

  Map<String, int> get _counts {
    final map = <String, int>{};
    for (final p in allPois) {
      map[p.category] = (map[p.category] ?? 0) + 1;
    }
    return map;
  }

  static const _categoryOrder = [
    'Fuel', 'Food', 'Hotel', 'Hospital', 'Bank',
    'Police', 'History', 'Nature', 'Religious', 'Shop',
  ];

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    
    // Dynamically get all categories that have at least one POI
    final available = counts.keys.toList();
    
    // Sort available categories: predefined ones first in order, then others alphabetically
    available.sort((a, b) {
      final idxA = _categoryOrder.indexOf(a);
      final idxB = _categoryOrder.indexOf(b);
      
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.compareTo(b);
    });

    if (available.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // All button
            _ActionChip(
              label: 'All',
              onTap: onSelectAll,
              active: activeCategories.length == available.length,
              color: Colors.black,
            ),
            const SizedBox(width: 6),
            // None button
            _ActionChip(
              label: 'None',
              onTap: onSelectNone,
              active: activeCategories.isEmpty,
              color: Colors.grey,
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 28, color: Colors.grey[300]),
            const SizedBox(width: 10),
            ...available.map((cat) {
              final poi = allPois.firstWhere((p) => p.category == cat);
              final count = counts[cat] ?? 0;
              final active = activeCategories.contains(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onToggle(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? poi.color.withOpacity(0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? poi.color : Colors.grey[300]!,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(poi.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$cat ($count)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? poi.color : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color color;

  const _ActionChip({
    required this.label,
    required this.onTap,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? color : Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
