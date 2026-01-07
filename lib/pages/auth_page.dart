import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider; // Fixed ambiguous import
import 'dart:ui';
import '../widgets.dart'; 
import '../services/database_service.dart'; 
import '../data.dart'; 
import '../models.dart'; 
import 'feed_page.dart'; 
import 'onboarding_page.dart'; 

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  Future<void> _handleGuestLogin(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: "guest@ccc.com", 
        password: "12345678"
      );
      
      if (context.mounted && FirebaseAuth.instance.currentUser != null) {
        _handleSignIn(context, FirebaseAuth.instance.currentUser!.uid);
      }
    } catch (e) {
      if (context.mounted) {
        showTopNotification(
          context,
          "Guest login failed: $e. (Check credentials in auth_page.dart)", 
          isError: true
        );
      }
    }
  }

  // Helper to handle navigation logic after sign in
  Future<void> _handleSignIn(BuildContext context, String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      var profile = await DatabaseService().getUserProfile(uid);
      
      if (!context.mounted) return;

      // FIX: Auto-create profile for Guest Judge (so they skip onboarding)
      // This ensures the "connection" to the database exists immediately
      if (profile == null && user != null && user.email == "guest@ccc.com") {
         profile = UserProfile(
           id: uid,
           username: 'guest_judge',
           fullName: 'Guest Judge',
           bio: 'Visiting for review. Welcome to CCC!',
           skills: ['Evaluation', 'Feedback'],
           skillRatings: {'Evaluation': 5, 'Feedback': 5},
           currentSemester: 8, // Senior / Judge
           openToCollaborate: false,
         );
         // This creates the document in Firestore matching the Auth UID
         await DatabaseService().createUserProfile(profile);
      }

      if (profile != null) {
        // Existing user: Initialize global state and go to feed
        currentUser = profile;
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FeedPage()),
          );
        }
      } else {
        // New user: Go to onboarding (Normal flow for students)
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingPage()),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showTopNotification(context, "Error accessing account: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C0000), Color(0xFF1A1A1A)],
              ),
            ),
          ),
          // 2. Decorative Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
              ),
            ),
          ),
          // 3. Glassy Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
          
          // 4. Auth Screen Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30), // Increased spacing for top button
                // Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      const AppLogo(fontSize: 24, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "College Coding Culture",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Share your journey. Grow with others.",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Sign In Form
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scaffoldBackgroundColor: Colors.transparent,
                      // Customize Buttons to match design language
                      outlinedButtonTheme: OutlinedButtonThemeData(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kAppCornerRadius),
                          ),
                        ),
                      ),
                      elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kAppCornerRadius),
                          ),
                          elevation: 0,
                        ),
                      ),
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                          borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kAppCornerRadius),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    child: SignInScreen(
                      providers: [
                        EmailAuthProvider(),
                      ],
                      actions: [
                        ForgotPasswordAction((context, email) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        }),
                        AuthStateChangeAction<SignedIn>((context, state) {
                          if (!state.user!.emailVerified) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmailVerificationScreen(
                                  actions: [
                                    EmailVerifiedAction(() {
                                      Navigator.pop(context);
                                      // Proceed only after verification dialog closes
                                      if (state.user != null) {
                                        _handleSignIn(context, state.user!.uid);
                                      }
                                    }),
                                    AuthCancelledAction((context) {
                                      FirebaseUIAuth.signOut(context: context);
                                      Navigator.pop(context);
                                    }),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            // Valid login -> Navigate to app
                            _handleSignIn(context, state.user!.uid);
                          }
                        }),
                      ],
                      subtitleBuilder: (context, action) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            action == AuthAction.signIn
                                ? 'Welcome back!'
                                : 'Join the community of CS students.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                      footerBuilder: (context, action) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white24)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text("OR", style: TextStyle(color: Colors.white54)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white24)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Guest Entry Button
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () => _handleGuestLogin(context),
                                  icon: const Icon(Icons.key, color: Colors.white, size: 20),
                                  label: const Text(
                                    "GUEST ENTRY", 
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.black.withValues(alpha: 0.2), 
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Feature Disabled / Google Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Removed actual Google Sign-In logic
                                    showTopNotification(
                                      context, 
                                      "This feature is currently in testing phase.",
                                      isError: true 
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(kAppCornerRadius),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("G", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), 
                                      SizedBox(width: 12),
                                      Text("Sign in with Google", style: TextStyle(color: Colors.white, fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
