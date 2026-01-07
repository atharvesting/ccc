import 'package:flutter/material.dart';
import '../widgets.dart';

class AboutPopup extends StatelessWidget {
  const AboutPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(1), // Gradient border width
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.85), // Translucent
                borderRadius: BorderRadius.circular(19),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 30),
                  // Logo / Icon
                  const AppLogo(),
                  const SizedBox(height: 20),
                  
                  // Title
                  // const Text(
                  //   "CCC",
                  //   style: TextStyle(
                  //     fontSize: 28,
                  //     fontWeight: FontWeight.bold,
                  //     color: Colors.white,
                  //     letterSpacing: 2,
                  //   ),
                  // ),
                  Text(
                    "COLLEGE CODING CULTURE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      letterSpacing: 4,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      "Bridging the gap between students, communities, and opportunities. Connect, Collaborate, and Create.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // Info Rows
                  _buildInfoRow(Icons.code_rounded, "v1.0.0 (Production)"),
                  _buildInfoRow(Icons.copyright_rounded, "2026 CCC Team - Atharv R, Deepesh W, Sanidhya B"),
                  
                  const SizedBox(height: 30),
                  
                  // Close Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(19),
                      bottomRight: Radius.circular(19),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(19),
                          bottomRight: Radius.circular(19),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          "CLOSE",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
