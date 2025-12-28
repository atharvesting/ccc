import 'package:flutter/material.dart';
import 'dart:ui';
import '../models.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/database_service.dart';

class ProfilePage extends StatefulWidget {
  final UserProfile? user; // Optional: if null, show current user
  const ProfilePage({super.key, this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> { // Removed SingleTickerProviderStateMixin
  late UserProfile displayUser;
  // Removed TabController
  
  // Controllers
  late TextEditingController _bioController;
  late TextEditingController _fullNameController;
  late TextEditingController _semesterController;
  late TextEditingController _skillInputController;

  bool _isEditing = false;
  bool _isCurrentUser = false;
  List<String> _editingSkills = [];
  int _selectedTabIndex = 0; // Added state for tab selection
  int _newSkillRating = 3; // Default rating for new skills

  @override
  void initState() {
    super.initState();
    displayUser = widget.user ?? currentUser;
    _isCurrentUser = displayUser.id == currentUser.id;
    // Removed TabController initialization
    
    _bioController = TextEditingController(text: displayUser.bio);
    _fullNameController = TextEditingController(text: displayUser.fullName);
    _semesterController = TextEditingController(text: displayUser.currentSemester);
    _skillInputController = TextEditingController();
    _editingSkills = List.from(displayUser.skills);
  }

  // Helper to parse "Skill:5" -> ("Skill", 5)
  (String, int) _parseSkill(String raw) {
    final parts = raw.split(':');
    if (parts.length > 1) {
      final r = int.tryParse(parts.last);
      if (r != null && r >= 1 && r <= 5) {
        return (parts.sublist(0, parts.length - 1).join(':'), r);
      }
    }
    return (raw, 1); // Default if no rating found
  }

  @override
  void dispose() {
    _bioController.dispose();
    _fullNameController.dispose();
    _semesterController.dispose();
    _skillInputController.dispose();
    // Removed TabController disposal
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final updatedProfile = UserProfile(
      id: displayUser.id,
      username: displayUser.username,
      fullName: _fullNameController.text.trim(),
      bio: _bioController.text.trim(),
      skills: _editingSkills, // Skills are saved as "Name:Rating" strings in Firestore
      currentSemester: _semesterController.text.trim(),
      openToCollaborate: displayUser.openToCollaborate,
      phoneNumber: displayUser.phoneNumber,
      savedPostIds: displayUser.savedPostIds,
      followers: displayUser.followers,
      following: displayUser.following,
    );

    await DatabaseService().updateUserProfile(updatedProfile);

    setState(() {
      displayUser = updatedProfile;
      if (_isCurrentUser) {
        currentUser = updatedProfile;
      }
      _isEditing = false;
    });
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty) {
      // Check duplicates based on name only
      final exists = _editingSkills.any((s) => _parseSkill(s).$1.toLowerCase() == skill.toLowerCase());
      if (!exists) {
        setState(() {
          _editingSkills.add("$skill:$_newSkillRating");
          _skillInputController.clear();
          _newSkillRating = 3; // Reset to default
        });
      }
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _editingSkills.remove(skill);
    });
  }

  void _toggleFollow() {
    if (currentUser.following.contains(displayUser.id)) {
      DatabaseService().unfollowUser(currentUser.id, displayUser.id);
      setState(() {
        currentUser.following.remove(displayUser.id);
        displayUser.followers.remove(currentUser.id);
      });
    } else {
      DatabaseService().followUser(currentUser.id, displayUser.id);
      setState(() {
        currentUser.following.add(displayUser.id);
        displayUser.followers.add(currentUser.id);
      });
    }
  }

  void _showBioEditorDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
          title: const Text("Edit Bio", style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: _bioController,
              maxLength: 250,
              maxLines: 10,
              minLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Tell us about yourself...",
                hintStyle: const TextStyle(color: Colors.grey),
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
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {}); // Refresh main UI
                Navigator.pop(context);
              },
              child: const Text("Done", style: TextStyle(color: Colors.redAccent)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String text) {
    final bool isActive = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.redAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillGraph(List<String> rawSkills) {
    final parsedSkills = rawSkills.map((s) => _parseSkill(s)).toList();
    // Sort descending by rating
    parsedSkills.sort((a, b) => b.$2.compareTo(a.$2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0), // Match PostWidget horizontal margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: parsedSkills.map((item) {
          final name = item.$1;
          final rating = item.$2;
          final color = getTagColor(name);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              children: [
                SizedBox(
                  width: 100, // Fixed width for label
                  child: Align(
                    alignment: Alignment.centerRight, // Align chip to the right
                    child: Chip(
                      label: Text(name, style: TextStyle(fontSize: 12, color: color), overflow: TextOverflow.ellipsis),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: color.withValues(alpha: 0.15),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: rating / 5.0,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)
                            ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text("$rating/5", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Profile', style: textTheme.titleMedium),
        backgroundColor: const Color.fromARGB(255, 43, 0, 0),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveChanges();
                } else {
                  setState(() {
                    _isEditing = true;
                    // Reset editing state to current values
                    _editingSkills = List.from(displayUser.skills);
                    _fullNameController.text = displayUser.fullName;
                    _semesterController.text = displayUser.currentSemester;
                    _bioController.text = displayUser.bio;
                  });
                }
              },
            )
        ],
      ),
      // Changed structure: SingleChildScrollView is now the parent of Center/ConstrainedBox
      // This ensures the scrollbar is attached to the full screen width, not the centered column.
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
          // 2. Decorative Circles - Blurred AF
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          // 3. Content
          SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Spacer for AppBar
                      const SizedBox(height: kToolbarHeight + 20),
                      // Redesigned Profile Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              blurRadius: 40,
                              spreadRadius: 0,
                            ),
                          ],
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Column: Identity
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  const CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.person_4, size: 40, color: Colors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  _isEditing
                                      ? TextField(
                                          controller: _fullNameController,
                                          textAlign: TextAlign.center,
                                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            hintText: "Full Name",
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                        )
                                      : Text(
                                          displayUser.fullName,
                                          textAlign: TextAlign.center,
                                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "@${displayUser.username}",
                                    style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  if (!_isCurrentUser)
                                    ElevatedButton(
                                      onPressed: _toggleFollow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: currentUser.following.contains(displayUser.id) ? Colors.grey : Colors.redAccent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                                      ),
                                      child: Text(currentUser.following.contains(displayUser.id) ? "Unfollow" : "Follow", style: const TextStyle(color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Right Column: Details
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Bio
                                  _isEditing
                                      ? TextField(
                                          controller: _bioController,
                                          readOnly: true,
                                          onTap: _showBioEditorDialog,
                                          decoration: const InputDecoration(
                                            labelText: 'Bio (Tap to edit)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            suffixIcon: Icon(Icons.open_in_full, size: 16),
                                          ),
                                          maxLines: 3,
                                          style: textTheme.bodyMedium,
                                        )
                                      : Text(
                                          _bioController.text.isEmpty ? "No bio yet." : _bioController.text,
                                          style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
                                        ),
                                
                                  const SizedBox(height: 16),

                                  // Metadata Row
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _isEditing 
                                      ? SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: _semesterController,
                                            decoration: InputDecoration(
                                              labelText: "Semester",
                                              isDense: true,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                                            ),
                                            style: textTheme.bodySmall,
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                                          ),
                                          child: Text("Semester ${displayUser.currentSemester}", style: textTheme.bodySmall),
                                        ),
                                      
                                      if (displayUser.openToCollaborate)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.handshake, size: 12, color: Colors.greenAccent),
                                              const SizedBox(width: 4),
                                              Text("Open to Collaborate", style: textTheme.bodySmall?.copyWith(color: Colors.greenAccent)),
                                            ],
                                          ),
                                        ),

                                      if (displayUser.phoneNumber != null && displayUser.phoneNumber!.isNotEmpty)
                                        Text("📞 ${displayUser.phoneNumber}", style: textTheme.bodySmall?.copyWith(color: Colors.white54)),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Skills (Only show here if editing)
                                  if (_isEditing) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _skillInputController,
                                            style: textTheme.bodySmall,
                                            decoration: InputDecoration(
                                              labelText: 'Add skill',
                                              isDense: true,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                                            ),
                                            onSubmitted: (_) => _addSkill(),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(kAppCornerRadius),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: _newSkillRating,
                                              dropdownColor: const Color(0xFF1A1A1A),
                                              icon: const Icon(Icons.star, color: Colors.amber, size: 20),
                                              items: [1, 2, 3, 4, 5].map((r) => DropdownMenuItem(
                                                value: r,
                                                child: Text(r.toString(), style: const TextStyle(color: Colors.white)),
                                              )).toList(),
                                              onChanged: (val) => setState(() => _newSkillRating = val!),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle, color: Colors.redAccent),
                                          onPressed: _addSkill,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _editingSkills.map((rawSkill) {
                                        final (name, rating) = _parseSkill(rawSkill);
                                        final color = getTagColor(name);
                                        return Chip(
                                          label: Text("$name ($rating/5)", style: TextStyle(fontSize: 14, color: color)),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: color.withValues(alpha: 0.15),
                                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                                          onDeleted: () => _removeSkill(rawSkill),
                                          deleteIcon: Icon(Icons.close, size: 12, color: color),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Skill Graph (View Mode Only)
                      if (!_isEditing && displayUser.skills.isNotEmpty) ...[
                         _buildSkillGraph(displayUser.skills),
                         const SizedBox(height: 24),
                      ],
                      
                      // Tabs for Posts / Saved
                      if (_isCurrentUser)
                        Row(
                          children: [
                            _buildTabButton(0, "My Posts"),
                            _buildTabButton(1, "Saved"),
                          ],
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Content based on Tab
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.02),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _buildPostList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    if (_isCurrentUser && _selectedTabIndex == 1) {
      // Saved Posts
      return StreamBuilder<List<Post>>(
        key: const ValueKey('saved'),
        stream: DatabaseService().getSavedPostsStream(displayUser.savedPostIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No saved posts.")));
          return Column(children: posts.map((p) => PostWidget(post: p)).toList());
        },
      );
    } else {
      // User Posts
      return StreamBuilder<List<Post>>(
        key: const ValueKey('posts'),
        stream: DatabaseService().getUserPostsStream(displayUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No posts yet.")));
          return Column(children: posts.map((p) => PostWidget(post: p)).toList());
        },
      );
    }
  }
}
