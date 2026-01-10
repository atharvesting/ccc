import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // For ImageFilter
import '../models.dart';
import '../data.dart';
import '../services/database_service.dart';
import '../widgets.dart';
import 'feed_page.dart'; // Import FeedPage

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _semesterController = TextEditingController();
  final _phoneController = TextEditingController();
  final _skillInputController = TextEditingController(); // Added for custom skills

  final List<String> _selectedSkills = []; // Stores "Skill:Rating" strings
  int _newSkillRating = 3; // Default rating
  bool _openToCollaborate = false;
  bool _isLoading = false;

  // Helper to parse "Skill:5" -> ("Skill", 5)
  (String, int) _parseSkill(String raw) {
    final parts = raw.split(':');
    if (parts.length > 1) {
      final r = int.tryParse(parts.last);
      if (r != null && r >= 1 && r <= 5) {
        return (parts.sublist(0, parts.length - 1).join(':'), r);
      }
    }
    return (raw, 1);
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty) {
      // Check duplicates based on name only
      final exists = _selectedSkills.any((s) => _parseSkill(s).$1.toLowerCase() == skill.toLowerCase());
      if (!exists) {
        setState(() {
          _selectedSkills.add("$skill:$_newSkillRating");
          _skillInputController.clear();
          _newSkillRating = 3; // Reset to default
        });
      }
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  Future<void> _completeOnboarding() async {
    if (_usernameController.text.isEmpty || _fullNameController.text.isEmpty || _semesterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all mandatory fields (Username, Name, Semester)')));
      return;
    }

    // Validate Semester is a number
    if (int.tryParse(_semesterController.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semester must be a valid number')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final username = _usernameController.text.trim();
      
      // Check uniqueness
      final isTaken = await DatabaseService().isUsernameTaken(username);
      if (isTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username is already taken. Please choose another.')));
          setState(() => _isLoading = false);
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Parse skills and ratings from "Skill:Rating" format
        final List<String> skills = [];
        final Map<String, int> skillRatings = {};
        
        for (var rawSkill in _selectedSkills) {
          final (skillName, rating) = _parseSkill(rawSkill);
          skills.add(skillName);
          skillRatings[skillName] = rating;
        }
        
        final newProfile = UserProfile(
          id: user.uid,
          username: username,
          fullName: _fullNameController.text.trim(),
          bio: _bioController.text.trim(),
          skills: skills,
          skillRatings: skillRatings,
          currentSemester: int.tryParse(_semesterController.text.trim()) ?? 1, // Parse String to int
          openToCollaborate: _openToCollaborate,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        );

        await DatabaseService().createUserProfile(newProfile);
        
        // Update local global state
        currentUser = newProfile;

        // FIX: Navigate to FeedPage after success
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FeedPage()),
          );
        }
      } else {
         // Should not happen, but safe to handle
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error. Please sign in again.')));
         }
      }
    } catch (e) {
      if (mounted) { // Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool required = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType, // Added keyboardType parameter
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0xFF121212), // Middle: Darker
                  Color(0xFF2C0000), // Edges: Lighter/Redder
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // 2. Decorative Circles
          Positioned(
            top: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          
          // 3. Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: GlassyContainer(
                  padding: 32,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Center(
                            child: Text(
                              "Setup Your Profile", 
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Row 1: Identity
                          if (isWide)
                            Row(
                              children: [
                                Expanded(child: _buildTextField(_fullNameController, "Full Name", Icons.badge, required: true)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTextField(_usernameController, "Username", Icons.person, required: true)),
                              ],
                            )
                          else ...[
                            _buildTextField(_fullNameController, "Full Name", Icons.badge, required: true),
                            const SizedBox(height: 16),
                            _buildTextField(_usernameController, "Username", Icons.person, required: true),
                          ],
                          const SizedBox(height: 16),

                          // Row 2: Contact & Info
                          if (isWide)
                            Row(
                              children: [
                                Expanded(child: _buildTextField(_semesterController, "Semester", Icons.school, required: true, keyboardType: TextInputType.number)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTextField(_phoneController, "Phone", Icons.phone, keyboardType: TextInputType.phone)),
                              ],
                            )
                          else ...[
                            _buildTextField(_semesterController, "Semester", Icons.school, required: true, keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            _buildTextField(_phoneController, "Phone", Icons.phone, keyboardType: TextInputType.phone),
                          ],
                          const SizedBox(height: 16),

                          // Bio
                          TextField(
                            controller: _bioController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Bio',
                              labelStyle: const TextStyle(color: Colors.white54),
                              hintText: 'Tell us a bit about yourself...',
                              hintStyle: const TextStyle(color: Colors.white24),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Collaboration Switch
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(kAppCornerRadius),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: SwitchListTile(
                              title: const Text("Open to Collaborate?", style: TextStyle(color: Colors.white)),
                              subtitle: const Text("Show a badge on your profile", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              value: _openToCollaborate,
                              activeThumbColor: Colors.greenAccent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              onChanged: (val) => setState(() => _openToCollaborate = val),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          const Text("Skills & Ratings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          const SizedBox(height: 12),

                          // Skill Input Row
                          if (isWide)
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(_skillInputController, "Add Skill", Icons.code),
                                ),
                                const SizedBox(width: 12),
                                _buildRatingDropdown(),
                                const SizedBox(width: 12),
                                _buildAddSkillButton(),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildTextField(_skillInputController, "Add Skill", Icons.code),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildRatingDropdown()),
                                    const SizedBox(width: 12),
                                    _buildAddSkillButton(),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Skills Wrap
                          if (_selectedSkills.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedSkills.map((rawSkill) {
                                final (name, rating) = _parseSkill(rawSkill);
                                final color = getTagColor(name);
                                return Chip(
                                  label: Text("$name ($rating/5)", style: TextStyle(fontSize: 12, color: color)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                                  onDeleted: () => _removeSkill(rawSkill),
                                  deleteIcon: Icon(Icons.close, size: 14, color: color),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                                );
                              }).toList(),
                            )
                          else
                            const Text("No skills added yet.", style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),

                          const SizedBox(height: 32),
                          
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                              : ElevatedButton(
                                  onPressed: _completeOnboarding,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                                    elevation: 5,
                                    shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                                  ),
                                  child: const Text("COMPLETE SETUP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(kAppCornerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _newSkillRating,
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.star, color: Colors.amber, size: 20),
          isExpanded: true, // Ensure it takes available width in mobile layout
          items: [1, 2, 3, 4, 5].map((r) => DropdownMenuItem(
            value: r,
            child: Text(r.toString(), style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (val) => setState(() => _newSkillRating = val!),
        ),
      ),
    );
  }

  Widget _buildAddSkillButton() {
    return IconButton.filled(
      onPressed: _addSkill,
      icon: const Icon(Icons.add),
      style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
    );
  }
}
