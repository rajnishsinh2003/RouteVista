import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/poi.dart';
import '../services/auth_service.dart';
import '../services/rating_service.dart';
import '../main.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _ratingService = RatingService();

  // Firebase user info
  User? get _fbUser => _authService.currentUser;
  String get _displayName {
    final fb = _fbUser?.displayName;
    if (fb != null && fb.trim().isNotEmpty) return fb.trim();
    return _name;
  }

  String get _displayEmail => _fbUser?.email ?? '';

  // Local preferences
  String _name = 'Traveler';
  VehicleType _preferredVehicle = VehicleType.car;
  FuelType _preferredFuel = FuelType.petrol;
  bool _notifications = true;
  bool _isDarkMode = false;
  bool _signingOut = false;
  String _selectedLanguage = 'en-IN'; // Default

  // Trip Stats
  int _totalTrips = 0;
  double _totalKm = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString('offline_routes') ?? '[]';
      final routes = List<Map<String, dynamic>>.from(json.decode(routesJson));
      
      double km = 0;
      for (var r in routes) {
        km += (r['distKm'] as num?)?.toDouble() ?? 0;
      }
      
      if (mounted) {
        setState(() {
          _totalTrips = routes.length;
          _totalKm = km;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? _fbUser?.displayName ?? 'Traveler';
      _preferredVehicle = VehicleType.values[prefs.getInt('vehicle_pref') ?? 1];
      _preferredFuel = FuelType.values[prefs.getInt('fuel_pref') ?? 0];
      _notifications = prefs.getBool('notifications') ?? true;
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      _selectedLanguage = prefs.getString('language_pref') ?? 'en-IN';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _name);
    await prefs.setInt('vehicle_pref', _preferredVehicle.index);
    await prefs.setInt('fuel_pref', _preferredFuel.index);
    await prefs.setBool('notifications', _notifications);
    await prefs.setBool('is_dark_mode', _isDarkMode);
    await prefs.setString('language_pref', _selectedLanguage);
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preferences saved!', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF065A60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Sign out ───────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.logout, color: Colors.redAccent),
          const SizedBox(width: 10),
          Text('Sign Out',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _signingOut = true);
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign out failed. Try again.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // ── Profile Card ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF065A60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Avatar with initial
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFA6).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _displayName.isNotEmpty
                              ? _displayName[0].toUpperCase()
                              : 'T',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (_displayEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _displayEmail,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          Text(
                            'RouteVista Explorer 🧭',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF00BFA6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white60, size: 20),
                      onPressed: _editName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── My Stats ───────────────────────────────────────
              _sectionTitle('My Stats'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.route, color: Color(0xFF00BFA6), size: 32),
                          const SizedBox(height: 8),
                          Text(_totalTrips.toString(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                          Text('Saved Trips', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.speed, color: Color(0xFFE67E22), size: 32),
                          const SizedBox(height: 8),
                          Text(_totalKm.toStringAsFixed(0), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                          Text('KMs Planned', style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Travel Preferences ─────────────────────────────
              _sectionTitle('Travel Preferences'),
              const SizedBox(height: 12),
              _settingCard(
                'Preferred Vehicle',
                VehicleDefaults.label(_preferredVehicle),
                Icons.directions_car,
                onTap: _selectVehicle,
              ),
              const SizedBox(height: 8),
              _settingCard(
                'Fuel Type',
                FuelRates.label(_preferredFuel),
                Icons.local_gas_station,
                onTap: _selectFuel,
              ),

              const SizedBox(height: 24),
              _sectionTitle('App Settings'),
              const SizedBox(height: 12),
              _toggleCard(
                'Dark Mode',
                'Use dark theme across app',
                Icons.dark_mode_outlined,
                _isDarkMode,
                (v) {
                  setState(() => _isDarkMode = v);
                  themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                  // Auto-save this particular setting immediately
                  SharedPreferences.getInstance().then((p) => p.setBool('is_dark_mode', v));
                },
              ),
              const SizedBox(height: 8),
              _toggleCard(
                'Notifications',
                'Trip reminders & alerts',
                Icons.notifications_outlined,
                _notifications,
                (v) {
                  setState(() => _notifications = v);
                  SharedPreferences.getInstance().then((p) => p.setBool('notifications', v));
                },
              ),
              const SizedBox(height: 8),
              _settingCard(
                'Voice Language',
                _getLanguageLabel(_selectedLanguage),
                Icons.translate_rounded,
                onTap: _selectLanguage,
              ),
              const SizedBox(height: 8),
              _settingCard(
                'Change Password',
                'Update your account security',
                Icons.lock_outline_rounded,
                onTap: _showChangePasswordDialog,
              ),

              const SizedBox(height: 24),
              _sectionTitle('About'),
              const SizedBox(height: 12),
              _settingCard('Version', '1.0.0', Icons.info_outline),
              const SizedBox(height: 8),
              _settingCard(
                'Rate RouteVista',
                'Tell us what you think',
                Icons.star_outline,
                onTap: _showRatingDialog,
              ),
              const SizedBox(height: 8),
              _settingCard(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip_outlined,
                onTap: () async {
                  final url = Uri.parse('https://github.com/rajnishsinh2003/RouteVista/blob/main/Privacy%20Policy');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
              ),
              const SizedBox(height: 8),
              _settingCard(
                'Developer Info',
                'Meet the creator',
                Icons.code_rounded,
                onTap: _showDeveloperInfo,
              ),

              const SizedBox(height: 24),

              // ── Save Preferences button ─────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF065A60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Preferences',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Sign Out button ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signingOut ? null : _signOut,
                  icon: _signingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  label: Text(
                    _signingOut ? 'Signing out...' : 'Sign Out',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: Colors.redAccent.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable section widgets ───────────────────────────────────

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );

  Widget _settingCard(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF065A60).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF065A60), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF065A60).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF065A60), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF065A60),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────

  void _editName() {
    final controller = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Your Name',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF065A60), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _name = controller.text.trim().isEmpty
                  ? 'Traveler'
                  : controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065A60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _selectVehicle() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Select Vehicle',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: VehicleType.values
            .map((v) => SimpleDialogOption(
                  onPressed: () {
                    setState(() => _preferredVehicle = v);
                    Navigator.pop(ctx);
                  },
                  child: Text(VehicleDefaults.label(v),
                      style: GoogleFonts.poppins()),
                ))
            .toList(),
      ),
    );
  }

  void _selectFuel() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Select Fuel Type',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: FuelType.values
            .map((f) => SimpleDialogOption(
                  onPressed: () {
                    setState(() => _preferredFuel = f);
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    '${FuelRates.label(f)} (₹${FuelRates.getRate(f).toInt()}/L)',
                    style: GoogleFonts.poppins(),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _selectLanguage() {
    final langs = {
      'en-IN': 'English (India)',
      'hi-IN': 'Hindi (हिन्दी)',
      'gu-IN': 'Gujarati (ગુજરાતી)',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Select Voice Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: langs.entries.map((e) => SimpleDialogOption(
          onPressed: () {
            setState(() => _selectedLanguage = e.key);
            Navigator.pop(ctx);
            _savePreferences();
          },
          child: Row(
            children: [
              Text(e.value, style: GoogleFonts.poppins()),
              if (_selectedLanguage == e.key) ...[
                const Spacer(),
                const Icon(Icons.check_circle, color: Color(0xFF065A60), size: 18),
              ],
            ],
          ),
        )).toList(),
      ),
    );
  }

  String _getLanguageLabel(String code) {
    switch (code) {
      case 'hi-IN': return 'Hindi (हिन्दी)';
      case 'gu-IN': return 'Gujarati (ગુજરાતી)';
      default: return 'English (India)';
    }
  }

  Widget _buildStatsDashboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Distance Covered (Last 5 Trips)',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroupData(0, 35),
                  _makeGroupData(1, 48),
                  _makeGroupData(2, 65),
                  _makeGroupData(3, 40),
                  _makeGroupData(4, 55),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey[100]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category Mix', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    _categoryLegend('Cultural', const Color(0xFF065A60)),
                    _categoryLegend('Nature', const Color(0xFF00BFA6)),
                    _categoryLegend('Urban', const Color(0xFFFFC107)),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 20,
                    sections: [
                      PieChartSectionData(color: const Color(0xFF065A60), value: 40, radius: 25, showTitle: false),
                      PieChartSectionData(color: const Color(0xFF00BFA6), value: 30, radius: 25, showTitle: false),
                      PieChartSectionData(color: const Color(0xFFFFC107), value: 30, radius: 25, showTitle: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF065A60),
          width: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _categoryLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Change Password', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: GoogleFonts.poppins(fontSize: 14),
                        prefixIcon: const Icon(Icons.lock_open_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: GoogleFonts.poppins(fontSize: 14),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: GoogleFonts.poppins(fontSize: 14),
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v != newPassCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF065A60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  setDialogState(() => loading = true);
                  try {
                    await _authService.changePassword(
                      currentPassword: currentPassCtrl.text,
                      newPassword: newPassCtrl.text,
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Password updated successfully! ✅', style: GoogleFonts.poppins()),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  } catch (e) {
                    final msg = (e is FirebaseAuthException) 
                        ? AuthService.friendlyError(e.code) 
                        : 'Update failed. Check current password.';
                    setDialogState(() => loading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(msg, style: GoogleFonts.poppins()),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                },
                child: loading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Update', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeveloperInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Color(0xFF00BFA6)),
            const SizedBox(width: 10),
            Text('Developer Info', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rajnish Sinh',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text('B.Tech Computer Engineering',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Text('rajnishsinh2003@gmail.com',
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF065A60))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF065A60).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF065A60).withValues(alpha: 0.1)),
              ),
              child: Text(
                '\"RouteVista — Discover India, even when the signal disappears.\"',
                style: GoogleFonts.poppins(fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://github.com/rajnishsinh2003/RouteVista');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Color(0xFF00BFA6)),
                  const SizedBox(width: 8),
                  Text('GitHub Repository',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF00BFA6))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF065A60))),
          ),
        ],
      ),
    );
  }
  void _showRatingDialog() async {
    double selectedRating = 0;
    
    // Attempt to fetch existing rating to pre-fill
    final double? existing = await _ratingService.getUserRating();
    if (existing != null) selectedRating = existing;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Theme.of(context).cardColor,
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065A60).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Color(0xFF065A60), size: 32),
                ),
                const SizedBox(height: 16),
                Text('Enjoying RouteVista?',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing != null 
                    ? 'Want to update your rating?' 
                    : 'Your feedback helps us make your travel planning even better!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final int starValue = index + 1;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedRating = starValue.toDouble());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          starValue <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: starValue <= selectedRating ? const Color(0xFFFFC107) : Colors.grey[400],
                          size: 26,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Not Now', style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065A60),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: selectedRating == 0 ? null : () async {
                        Navigator.pop(ctx);
                        try {
                          await _ratingService.submitRating(selectedRating);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Thank you for your rating!', style: GoogleFonts.poppins()),
                              backgroundColor: const Color(0xFF065A60),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Failed to submit rating. Please try again.'),
                              backgroundColor: Colors.redAccent,
                            ));
                          }
                        }
                      },
                      child: Text('Submit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
