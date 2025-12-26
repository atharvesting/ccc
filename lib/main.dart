import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb check
import 'firebase_options.dart'; 
import 'pages/feed_page.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'services/database_service.dart';
import 'models.dart';
import 'data.dart';
import 'widgets.dart'; // Import for kAppCornerRadius

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const CccApp());
  } catch (e) {
    // Catch initialization errors (like missing web configuration)
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    "App Initialization Failed",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (kIsWeb) ...[
                    const Text(
                      "Web Fix Instructions:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    const Text("1. Open your terminal", style: TextStyle(color: Colors.black87)),
                    const Text("2. Run: flutter pub add firebase_core_web", style: TextStyle(color: Colors.black87)),
                    const Text("3. Stop the app and run it again", style: TextStyle(color: Colors.black87)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CccApp extends StatelessWidget {
  const CccApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CS Daily Progress',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
        scrollbars: true,
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.redAccent.withValues(alpha: 0.6)),
          trackColor: WidgetStateProperty.all(Colors.redAccent.withValues(alpha: 0.1)),
          radius: const Radius.circular(kAppCornerRadius), // Using global constant
          thickness: WidgetStateProperty.all(6),
          thumbVisibility: WidgetStateProperty.all(true),
          trackVisibility: WidgetStateProperty.all(false),
          interactive: true,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.red,
          surface: Color(0xCC2C2C2C),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
        }

        if (!snapshot.hasData) {
          return const AuthPage();
        }

        return FutureBuilder<UserProfile?>(
          future: DatabaseService().getUserProfile(snapshot.data!.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
            }

            if (profileSnapshot.hasData && profileSnapshot.data != null) {
              currentUser = profileSnapshot.data!;
              return const FeedPage();
            } else {
              return const OnboardingPage();
            }
          },
        );
      },
    );
  }
}
