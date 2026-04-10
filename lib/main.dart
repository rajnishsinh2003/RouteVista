import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Safe Firebase Initialization ──────────────────────────────
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    }
  } catch (e) {
    debugPrint('⚠️ Firebase Init Skip: $e');
  }

  // Clear search fields every time app starts
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('last_source');
  await prefs.remove('last_dest');

  runApp(const RouteVistaApp());
}

class RouteVistaApp extends StatelessWidget {
  const RouteVistaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is available
    final bool isFirebaseReady = Firebase.apps.isNotEmpty;

    return MaterialApp(
      title: 'RouteVista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF065A60),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      // ── Resilient Routing ─────────────────────────────────────
      // We only use the StreamBuilder if Firebase is actually ready.
      // Otherwise, we show the LoginScreen directly for previewing.
      home: !isFirebaseReady
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
