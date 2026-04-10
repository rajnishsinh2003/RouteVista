import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/tour_plan.dart';
import '../services/tour_service.dart';
import 'tour_detail_screen.dart';
import 'map_screen.dart';

class MonthlyToursScreen extends StatefulWidget {
  const MonthlyToursScreen({super.key});

  @override
  State<MonthlyToursScreen> createState() => _MonthlyToursScreenState();
}

class _MonthlyToursScreenState extends State<MonthlyToursScreen>
    with SingleTickerProviderStateMixin {
  final TourService _svc = TourService();
  final _uuid = const Uuid();

  int _selectedMonth = DateTime.now().month;
  String _selectedFilter = 'All';
  bool _bookmarkedOnly = false;
  Set<String> _bookmarks = {};
  List<TourPlan> _customTours = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late TabController _tabController;

  static const _filters = ['All', 'Easy', 'Moderate', 'Hard', 'Family', 'Couple', 'Solo', 'Adventure'];
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _monthColors = [
    Color(0xFF1565C0), Color(0xFFD32F2F), Color(0xFFE91E63),
    Color(0xFF388E3C), Color(0xFF7B1FA2), Color(0xFF0277BD),
    Color(0xFF00796B), Color(0xFFF57F17), Color(0xFFBF360C),
    Color(0xFF558B2F), Color(0xFF4527A0), Color(0xFFC62828),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bookmarks = await _svc.getBookmarks();
    final custom = await _svc.getCustomTours();
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _customTours = custom;
        _isLoading = false;
      });
    }
  }

  List<TourPlan> get _curatedWithBookmarks {
    return TourService.getCurated().map((t) {
      t.isBookmarked = _bookmarks.contains(t.id);
      return t;
    }).toList();
  }

  List<TourPlan> get _allTours => [..._curatedWithBookmarks, ..._customTours];

  List<TourPlan> get _filtered {
    return _allTours.where((t) {
      // Global search if query is not empty
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final match = t.title.toLowerCase().contains(query) ||
                      t.destination.toLowerCase().contains(query) ||
                      t.highlights.any((h) => h.toLowerCase().contains(query));
        if (!match) return false;
      } else {
        // Otherwise use month filter
        if (t.month != _selectedMonth) return false;
      }

      if (_bookmarkedOnly && !_bookmarks.contains(t.id)) return false;
      if (_selectedFilter == 'All') return true;
      if (['Easy','Moderate','Hard'].contains(_selectedFilter)) return t.difficulty == _selectedFilter;
      return (t.bestFor == _selectedFilter);
    }).toList();
  }

  List<TourPlan> get _bookmarkedTours {
    return _allTours.where((t) => _bookmarks.contains(t.id)).toList();
  }

  Future<void> _toggleBookmark(TourPlan t) async {
    await _svc.toggleBookmark(t.id);
    await _loadData();
  }

  void _openTourDetail(TourPlan t) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TourDetailScreen(
          tour: t,
          onBookmarkToggled: _loadData,
        ),
      ),
    );
    // If user tapped "Plan Route" from detail screen
    if (result != null && result['planRoute'] == true) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(
            useCurrentLocation: false,
            source: '',
            destination: result['destination'],
          ),
        ),
      );
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Tour Planner 🗓️',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Curated India travel by season',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60)),
                      ],
                    )),
                    // Bookmark toggle
                    GestureDetector(
                      onTap: () => setState(() => _bookmarkedOnly = !_bookmarkedOnly),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _bookmarkedOnly ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _bookmarkedOnly ? const Color(0xFFFFD700) : Colors.white38),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            _bookmarkedOnly ? Icons.bookmark : Icons.bookmark_border,
                            color: _bookmarkedOnly ? Colors.black : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Saved (${_bookmarks.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _bookmarkedOnly ? Colors.black : Colors.white,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // 🔎 Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search 300+ destinations (e.g. Manali, Yoga)',
                        hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              }) 
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Month selector
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 12,
                      itemBuilder: (_, i) {
                        final m = i + 1;
                        final sel = _selectedMonth == m;
                        final count = _allTours.where((t) => t.month == m).length;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMonth = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: 8, left: i == 0 ? 0 : 0),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? Colors.white : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: sel ? Colors.white : Colors.white30),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_months[i],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                    color: sel ? _monthColors[i] : Colors.white,
                                  )),
                              if (count > 0)
                                Text('$count', style: GoogleFonts.poppins(fontSize: 9, color: sel ? _monthColors[i] : Colors.white60)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: const Color(0xFF00BFA6),
                    indicatorWeight: 3,
                    tabs: const [Tab(text: 'Curated Tours'), Tab(text: 'My Plans')],
                  ),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────
            Container(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: _filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedFilter == f ? const Color(0xFF065A60) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _selectedFilter == f ? const Color(0xFF065A60) : Colors.grey[300]!),
                        ),
                        child: Text(f,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: _selectedFilter == f ? FontWeight.w600 : FontWeight.w400,
                            color: _selectedFilter == f ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

            // ── Body ─────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF065A60)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCuratedTab(),
                        _buildMyPlansTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF065A60),
        foregroundColor: Colors.white,
        onPressed: _showAddPlanSheet,
        icon: const Icon(Icons.add),
        label: Text('Plan My Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildCuratedTab() {
    final tours = _filtered.where((t) => !t.isCustom).toList();
    final allMonthTours = _curatedWithBookmarks.where((t) => t.month == _selectedMonth).toList();

    if (allMonthTours.isEmpty) {
      return _buildEmpty('No tours for ${_months[_selectedMonth - 1]}', 'Try another month');
    }
    if (tours.isEmpty) {
      return _buildEmpty('No tours match "$_selectedFilter"', 'Clear filters to see all');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: tours.length,
        itemBuilder: (_, i) => _TourCard(
          tour: tours[i],
          isBookmarked: _bookmarks.contains(tours[i].id),
          onTap: () => _openTourDetail(tours[i]),
          onBookmark: () => _toggleBookmark(tours[i]),
        ),
      ),
    );
  }

  Widget _buildMyPlansTab() {
    final custom = _customTours;
    if (custom.isEmpty) {
      return _buildEmpty('No custom plans yet', 'Tap "+ Plan My Trip" to create one');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: custom.length,
      itemBuilder: (_, i) => _TourCard(
        tour: custom[i],
        isBookmarked: _bookmarks.contains(custom[i].id),
        onTap: () => _openTourDetail(custom[i]),
        onBookmark: () => _toggleBookmark(custom[i]),
        onDelete: () async {
          await _svc.deleteCustomTour(custom[i].id);
          await _loadData();
        },
      ),
    );
  }

  Widget _buildEmpty(String title, String sub) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.explore_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      const SizedBox(height: 6),
      Text(sub, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400])),
    ]),
  );

  void _showAddPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddPlanSheet(
        initialMonth: _selectedMonth,
        onSave: (plan) async {
          final newPlan = TourPlan(
            id: 'custom_${_uuid.v4()}',
            title: plan['title'], destination: plan['destination'],
            routeHint: plan['routeHint'], month: plan['month'],
            durationDays: plan['durationDays'], budgetRange: plan['budgetRange'],
            difficulty: plan['difficulty'], highlights: plan['highlights'],
            bestFor: plan['bestFor'], weatherNote: plan['weatherNote'],
            description: plan['description'], heroEmoji: plan['emoji'],
            thingsToDo: [], thingsToEat: [], tips: [], bestTimeDetail: '',
          );
          await _svc.saveCustomTour(newPlan);
          await _loadData();
          if (mounted) setState(() => _tabController.animateTo(1));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOUR CARD
// ─────────────────────────────────────────────
class _TourCard extends StatelessWidget {
  final TourPlan tour;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  final VoidCallback? onDelete;

  const _TourCard({
    required this.tour, required this.isBookmarked,
    required this.onTap, required this.onBookmark, this.onDelete,
  });

  Color get _diffColor {
    switch (tour.difficulty) {
      case 'Easy':     return Colors.green.shade600;
      case 'Moderate': return Colors.orange.shade700;
      default:         return Colors.red.shade600;
    }
  }

  bool get isCustom => tour.id.startsWith('custom_');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top gradient header with emoji
            Container(
              height: 120, // Increased height for better image visibility
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: const Color(0xFF0D1B2A),
                image: tour.imageUrl != null && tour.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(tour.imageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4),
                          BlendMode.darken,
                        ),
                      )
                    : null,
                gradient: tour.imageUrl == null || tour.imageUrl!.isEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFF0D1B2A), Color(0xFF034748)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (tour.imageUrl == null || tour.imageUrl!.isEmpty)
                    Positioned(
                      right: 16, top: 0, bottom: 0,
                      child: Center(child: Text(tour.heroEmoji, style: const TextStyle(fontSize: 52))),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          if (isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
                              child: Text('My Plan', style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onBookmark,
                            child: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              color: isBookmarked ? const Color(0xFFFFD700) : Colors.white70,
                              size: 22,
                            ),
                          ),
                          if (onDelete != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onDelete,
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            ),
                          ],
                        ]),
                        Text(tour.title,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on, size: 13, color: Colors.grey),
                    const SizedBox(width: 3),
                    Expanded(child: Text(tour.destination,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(children: [
                    _stat(Icons.calendar_today, '${tour.durationDays}d', Colors.teal),
                    const SizedBox(width: 10),
                    _stat(Icons.currency_rupee, tour.budgetRange.split('–')[0].trim(), Colors.green),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _diffColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tour.difficulty,
                          style: GoogleFonts.poppins(fontSize: 11, color: _diffColor, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tour.bestFor,
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Highlights preview
                  Wrap(
                    spacing: 5, runSpacing: 4,
                    children: tour.highlights.take(3).map((h) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF065A60).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(h, style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF065A60))),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Weather
                  Row(children: [
                    const Icon(Icons.wb_sunny_outlined, size: 13, color: Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(child: Text(tour.weatherNote,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 3),
    Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);
}

// ─────────────────────────────────────────────
//  ADD PLAN BOTTOM SHEET
// ─────────────────────────────────────────────
class _AddPlanSheet extends StatefulWidget {
  final int initialMonth;
  final void Function(Map<String, dynamic>) onSave;

  const _AddPlanSheet({required this.initialMonth, required this.onSave});

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _highCtrl = TextEditingController();
  final _weatherCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late int _month;
  int _days = 3;
  String _difficulty = 'Easy';
  String _bestFor = 'Family';
  String _emoji = '🗺️';

  static const _emojis = ['🗺️','🏔️','🏖️','🌴','🏰','🕌','🌿','🎭','🍽️','🏕️','🤿','🚂','🐅','🦁','🌸','❄️','🌊','🎪'];
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Plan My Trip', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 14),

                // Emoji picker
                Text('Pick an Icon', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _emojis.map((e) => GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _emoji == e ? const Color(0xFF065A60).withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _emoji == e ? const Color(0xFF065A60) : Colors.transparent),
                        ),
                        child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                _field(_titleCtrl, 'Trip Title *', required: true),
                const SizedBox(height: 10),
                _field(_destCtrl, 'Destination *', required: true),
                const SizedBox(height: 10),
                _field(_routeCtrl, 'Route (e.g. Delhi → Agra → Jaipur)'),
                const SizedBox(height: 10),

                // Month + Days row
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: _dec('Month'),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i], style: GoogleFonts.poppins(fontSize: 13)))),
                    onChanged: (v) => setState(() => _month = v!),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration: $_days days', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      Slider(
                        value: _days.toDouble(), min: 1, max: 30, divisions: 29,
                        activeColor: const Color(0xFF065A60),
                        onChanged: (v) => setState(() => _days = v.toInt()),
                      ),
                    ],
                  )),
                ]),
                const SizedBox(height: 10),

                _field(_budgetCtrl, 'Budget Range (e.g. ₹10,000 – ₹20,000)'),
                const SizedBox(height: 10),

                // Difficulty + Best For
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: _dec('Difficulty'),
                    items: ['Easy','Moderate','Hard'].map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.poppins(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _bestFor,
                    decoration: _dec('Best For'),
                    items: ['Family','Couple','Solo','Adventure','Cultural','Nature','Friends']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.poppins(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _bestFor = v!),
                  )),
                ]),
                const SizedBox(height: 10),

                _field(_highCtrl, 'Highlights (comma separated)'),
                const SizedBox(height: 10),
                _field(_weatherCtrl, 'Weather Note'),
                const SizedBox(height: 10),
                _field(_descCtrl, 'Description', maxLines: 3),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065A60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final highlights = _highCtrl.text.isNotEmpty
                            ? _highCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                            : ['To be planned'];
                        widget.onSave({
                          'title': _titleCtrl.text,
                          'destination': _destCtrl.text,
                          'routeHint': _routeCtrl.text.isNotEmpty ? _routeCtrl.text : _destCtrl.text,
                          'month': _month,
                          'durationDays': _days,
                          'budgetRange': _budgetCtrl.text.isNotEmpty ? _budgetCtrl.text : 'Not specified',
                          'difficulty': _difficulty,
                          'highlights': highlights,
                          'bestFor': _bestFor,
                          'weatherNote': _weatherCtrl.text.isNotEmpty ? _weatherCtrl.text : 'Check local forecast',
                          'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : 'My custom tour plan.',
                          'emoji': _emoji,
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Save My Plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: _dec(label),
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

// Extension to check if custom
extension on TourPlan {
  bool get isCustom => id.startsWith('custom_');
}
