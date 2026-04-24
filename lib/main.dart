import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'screens/onboarding_screen.dart';
import 'firebase_options.dart';
import 'services/place_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Safe Firebase Initialization ──────────────────────────────
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
      // 🔥 One-time sync of Places.json to Firestore (run in background)
      PlaceService.syncLocalDataToFirestore();
    }
  } catch (e) {
    debugPrint('⚠️ Firebase Init Skip: $e');
  }

  // Initialize Notifications
  await NotificationService().init();

  // Clear search fields every time app starts
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_source');
  await prefs.remove('last_dest');
  
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final bool showOnboarding = prefs.getBool('show_onboarding') ?? true;
  final bool alreadyLoggedIn = await AuthService.isLoggedIn();

  runApp(RouteVistaApp(
    showOnboarding: showOnboarding,
    alreadyLoggedIn: alreadyLoggedIn,
  ));
}

class RouteVistaApp extends StatelessWidget {
  final bool showOnboarding;
  final bool alreadyLoggedIn;
  const RouteVistaApp({
    super.key,
    required this.showOnboarding,
    required this.alreadyLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is available
    final bool isFirebaseReady = Firebase.apps.isNotEmpty;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'RouteVista',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF065A60),
              brightness: Brightness.light,
              surface: const Color(0xFFF5F7FA),
              onSurface: const Color(0xFF1A1A2E),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            cardColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00BFA6),
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF0D1B2A), // Deep dark background
            cardColor: const Color(0xFF1B3A4B), // Slightly lighter for cards
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          // ── Resilient Routing ─────────────────────────────────────
          // 1. First-time user  → Onboarding
          // 2. Already logged in (session saved) → Home via SplashScreen
          // 3. Firebase ready → listen to auth stream
          // 4. Fallback → LoginScreen
          home: showOnboarding
              ? const OnboardingScreen()
              : alreadyLoggedIn
                  ? const SplashScreen()   // skip login, go straight to home
                  : !isFirebaseReady
                      ? const LoginScreen()
                      : StreamBuilder<User?>(
                          stream: FirebaseAuth.instance.authStateChanges(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const _SplashLoader();
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return const SplashScreen();
                            }
                            return const LoginScreen();
                          },
                        ),
        );
      },
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF065A60)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
      ),
    );
  }
}
