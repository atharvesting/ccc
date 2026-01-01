import 'package:flutter/material.dart';
import '../models.dart';
import '../services/database_service.dart';
import '../data.dart';
import '../widgets.dart';
import 'profile_page.dart';

class SkillMatchingPage extends StatefulWidget {
  const SkillMatchingPage({super.key});

  @override
  State<SkillMatchingPage> createState() => _SkillMatchingPageState();
}

class _SkillMatchingPageState extends State<SkillMatchingPage> {
  int _selectedIndex = 0; // 0 = My Matches, 1 = Find by Skill
  bool _isLoading = false;
  List<UserProfile> _matches = [];
  
  // For "Find by Skill"
  final List<String> _selectedDomains = [];
  final List<String> _availableDomains = [
    'Python', 'Java', 'C++', 'Flutter', 'React', 'Web', 'Mobile', 'AI/ML', 'Data Science', 'DevOps', 'UI/UX', 'Cloud'
  ];

  @override
  void initState() {
    super.initState();
    _loadMyMatches();
  }

  Future<void> _loadMyMatches() async {
    setState(() {
      _isLoading = true;
      _selectedIndex = 0;
    });
    
    try {
      // Fetch current user profile to get latest skills
      final user = await DatabaseService().getUserProfile(currentUser.id);
      if (user != null) {
        final results = await DatabaseService().getProfileMatches(user);
        if (mounted) setState(() => _matches = results);
      }
    } catch (e) {
      debugPrint("Error loading matches: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchByDomains() async {
    if (_selectedDomains.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _selectedIndex = 1;
    });

    try {
      final results = await DatabaseService().getDomainMatches(_selectedDomains);
      if (mounted) setState(() => _matches = results);
    } catch (e) {
      debugPrint("Error searching domains: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleDomain(String domain) {
    setState(() {
      if (_selectedDomains.contains(domain)) {
        _selectedDomains.remove(domain);
      } else {
        if (_selectedDomains.length < 5) {
          _selectedDomains.add(domain);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      selectedIndex: 3,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF121212), Color(0xFF1A0033)], // Purple tint for matching
                stops: [0.0, 1.0],
              ),
            ),
          ),
          
          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 20),
                  
                  // Added Title
                  const Text(
                    "Skill Match",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggle Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildToggleButton("Suggested Peers", 0, _loadMyMatches),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildToggleButton("Find by Skill", 1, () {
                            setState(() {
                              _selectedIndex = 1;
                              _matches = []; // Clear previous results until search
                            });
                          }),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Domain Selector (Only for Index 1)
                  if (_selectedIndex == 1) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GlassyContainer(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Select Domains (Max 5)", style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _availableDomains.map((domain) {
                                final isSelected = _selectedDomains.contains(domain);
                                return FilterChip(
                                  label: Text(domain),
                                  selected: isSelected,
                                  onSelected: (_) => _toggleDomain(domain),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  selectedColor: Colors.purpleAccent.withValues(alpha: 0.3),
                                  checkmarkColor: Colors.purpleAccent,
                                  labelStyle: TextStyle(color: isSelected ? Colors.purpleAccent : Colors.white70),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: isSelected ? Colors.purpleAccent : Colors.white10),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _selectedDomains.isEmpty ? null : _searchByDomains,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Find Matches"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Results List
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                      : _matches.isEmpty
                        ? Center(
                            child: Text(
                              _selectedIndex == 0 
                                ? "No matches found based on your profile.\nTry adding more skills!" 
                                : "Select domains to find peers.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _matches.length,
                            itemBuilder: (context, index) {
                              final user = _matches[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ProfilePage(user: user)),
                                    );
                                  },
                                  child: GlassyContainer(
                                    themeColor: Colors.purpleAccent,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                                          child: Text(
                                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                            style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text("@${user.username}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: user.skills.take(4).map((s) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: getTagColor(s).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: getTagColor(s).withValues(alpha: 0.4), width: 0.5),
                                                  ),
                                                  child: Text(s, style: TextStyle(color: getTagColor(s), fontSize: 10)),
                                                )).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            const Icon(Icons.handshake, color: Colors.purpleAccent),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedIndex == 0 ? "Match" : "Found", 
                                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, int index, VoidCallback onTap) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kAppCornerRadius),
      child: GlassyContainer(
        color: isSelected ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderColor: isSelected ? Colors.purpleAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
        padding: 12,
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
