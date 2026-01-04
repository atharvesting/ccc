import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Added for platform check
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider; // Import for GoogleAuthProvider
import 'dart:ui';
import '../widgets.dart'; // Import for kAppCornerRadius

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

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
                const SizedBox(height: 20),
                // Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ]
                        ),
                        child: const Text("< < <", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "collegeCodingCulture",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                                    }),
                                    AuthCancelledAction((context) {
                                      FirebaseUIAuth.signOut(context: context);
                                      Navigator.pop(context);
                                    }),
                                  ],
                                ),
                              ),
                            );
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
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      final provider = GoogleAuthProvider();
                                      provider.setCustomParameters({'prompt': 'select_account'});
                                      
                                      if (kIsWeb) {
                                        await FirebaseAuth.instance.signInWithPopup(provider);
                                      } else {
                                        await FirebaseAuth.instance.signInWithProvider(provider);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Sign in failed: $e"),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
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
                                      // Simple G icon since we don't have assets
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
