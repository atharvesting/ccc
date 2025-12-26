import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final List<String> _selectedSkills = [];
  bool _openToCollaborate = false;
  bool _isLoading = false;

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  Future<void> _completeOnboarding() async {
    if (_usernameController.text.isEmpty || _fullNameController.text.isEmpty || _semesterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all mandatory fields (Username, Name, Semester)')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newProfile = UserProfile(
          id: user.uid,
          username: _usernameController.text.trim(),
          fullName: _fullNameController.text.trim(),
          bio: _bioController.text.trim(),
          skills: _selectedSkills,
          currentSemester: _semesterController.text.trim(),
          openToCollaborate: _openToCollaborate,
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        );

        await DatabaseService().createUserProfile(newProfile);
        
        // Update local global state
        currentUser = newProfile;

        // FIX: Navigate to FeedPage after success
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FeedPage()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Profile"), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              GlassyContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Basic Info", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name (Required)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _semesterController,
                      decoration: const InputDecoration(
                        labelText: 'Current Semester (Required)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text("Open to Collaborate?"),
                      subtitle: const Text("Show a badge on your profile"),
                      value: _openToCollaborate,
                      activeColor: Colors.green,
                      onChanged: (val) => setState(() => _openToCollaborate = val),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                        hintText: 'CS Student @ University...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("Select your skills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: globalTags.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        final color = getTagColor(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          onSelected: (_) => _toggleSkill(skill),
                          selectedColor: color.withValues(alpha: 0.3),
                          checkmarkColor: color,
                          backgroundColor: color.withValues(alpha: 0.05),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : color),
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              else
                ElevatedButton(
                  onPressed: _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                  ),
                  child: const Text("COMPLETE SETUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
