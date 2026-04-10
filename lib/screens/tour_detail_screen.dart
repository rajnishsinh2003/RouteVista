import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tour_plan.dart';
import '../services/tour_service.dart';

class TourDetailScreen extends StatefulWidget {
  final TourPlan tour;
  final VoidCallback onBookmarkToggled;

  const TourDetailScreen({
    super.key,
    required this.tour,
    required this.onBookmarkToggled,
  });

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final TourService _svc = TourService();
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.tour.isBookmarked;
  }

  Future<void> _toggleBookmark() async {
    await _svc.toggleBookmark(widget.tour.id);
    setState(() => _isBookmarked = !_isBookmarked);
    widget.onBookmarkToggled();
  }

  Future<void> _saveTourDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final placesJson = prefs.getString('saved_places') ?? '[]';
    final places = List<Map<String, dynamic>>.from(jsonDecode(placesJson));
    final id = 'tour_${widget.tour.id}';
    if (!places.any((p) => p['id'] == id)) {
      places.insert(0, {
        'id': id,
        'name': widget.tour.title,
        'location': widget.tour.destination,
        'category': 'Tour Destination',
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString('saved_places', jsonEncode(places));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.tour.title} saved to places!',
              style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF065A60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Color get _diffColor {
    switch (widget.tour.difficulty) {
      case 'Easy':     return Colors.green.shade600;
      case 'Moderate': return Colors.orange.shade700;
      default:         return Colors.red.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF065A60),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: _isBookmarked ? const Color(0xFFFFD700) : Colors.white,
                ),
                onPressed: _toggleBookmark,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t.title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white,
                      shadows: [const Shadow(color: Colors.black45, blurRadius: 10)])),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (t.imageUrl != null)
                    Image.network(
                      t.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultBackground(t.heroEmoji),
                    )
                  else
                    _defaultBackground(t.heroEmoji),
                  // Dark overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Key Info Chips Row ────────
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _chip(Icons.location_on, t.destination, Colors.blue),
                      _chip(Icons.calendar_today, '${t.durationDays} Days', Colors.teal),
                      _chip(Icons.currency_rupee, t.budgetRange, Colors.green),
                      _chip(Icons.people_outline, t.bestFor, Colors.purple),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _diffColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _diffColor.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_diffIcon, size: 14, color: _diffColor),
                          const SizedBox(width: 4),
                          Text(t.difficulty,
                              style: GoogleFonts.poppins(fontSize: 12, color: _diffColor, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Route Hint ────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065A60).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF065A60).withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.route, color: Color(0xFF065A60), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.routeHint,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF065A60)))),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Weather ───────────────────
                  _sectionCard(
                    icon: Icons.wb_sunny_outlined,
                    color: Colors.orange,
                    title: 'Weather & Best Time',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.weatherNote, style: GoogleFonts.poppins(fontSize: 13, height: 1.5)),
                        const SizedBox(height: 6),
                        Text(t.bestTimeDetail,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                      ],
                    ),
                  ),

                  // ── Description ───────────────
                  _sectionCard(
                    icon: Icons.info_outline,
                    color: const Color(0xFF065A60),
                    title: 'About This Trip',
                    child: Text(t.description, style: GoogleFonts.poppins(fontSize: 13, height: 1.6)),
                  ),

                  // ── Highlights ────────────────
                  _sectionCard(
                    icon: Icons.star_outline,
                    color: Colors.amber,
                    title: 'Highlights',
                    child: Wrap(
                      spacing: 6, runSpacing: 6,
                      children: t.highlights.map((h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Text(h, style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ),

                  // ── Things To Do ──────────────
                  _sectionCard(
                    icon: Icons.checklist,
                    color: Colors.indigo,
                    title: 'Things To Do',
                    child: Column(
                      children: t.thingsToDo.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('${e.key + 1}',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.value, style: GoogleFonts.poppins(fontSize: 13, height: 1.4))),
                        ]),
                      )).toList(),
                    ),
                  ),

                  // ── Things To Eat ─────────────
                  _sectionCard(
                    icon: Icons.restaurant_outlined,
                    color: Colors.orange,
                    title: 'Must Eat',
                    child: Column(
                      children: t.thingsToEat.map((food) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Text('🍽️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(food, style: GoogleFonts.poppins(fontSize: 13))),
                        ]),
                      )).toList(),
                    ),
                  ),

                  // ── Tips ─────────────────────
                  _sectionCard(
                    icon: Icons.tips_and_updates_outlined,
                    color: Colors.teal,
                    title: 'Travel Tips',
                    child: Column(
                      children: t.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700], height: 1.4))),
                        ]),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Action Buttons ────────────
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065A60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context, {'planRoute': true, 'destination': t.destination});
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: Text('Plan Route', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF065A60)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saveTourDestination,
                        icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFF065A60), size: 18),
                        label: Text('Save Place', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF065A60))),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  IconData get _diffIcon {
    switch (widget.tour.difficulty) {
      case 'Easy':     return Icons.sentiment_satisfied_alt;
      case 'Moderate': return Icons.sentiment_neutral;
      default:         return Icons.whatshot;
    }
  }

  Widget _defaultBackground(String emoji) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(emoji, style: const TextStyle(fontSize: 80)),
    ),
  );
}
