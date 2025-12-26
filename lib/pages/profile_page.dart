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

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late UserProfile displayUser;
  late TabController _tabController;
  
  // Controllers
  late TextEditingController _bioController;
  late TextEditingController _fullNameController;
  late TextEditingController _semesterController;
  late TextEditingController _skillInputController;

  bool _isEditing = false;
  bool _isCurrentUser = false;
  List<String> _editingSkills = [];

  @override
  void initState() {
    super.initState();
    displayUser = widget.user ?? currentUser;
    _isCurrentUser = displayUser.id == currentUser.id;
    _tabController = TabController(length: 2, vsync: this);
    
    _bioController = TextEditingController(text: displayUser.bio);
    _fullNameController = TextEditingController(text: displayUser.fullName);
    _semesterController = TextEditingController(text: displayUser.currentSemester);
    _skillInputController = TextEditingController();
    _editingSkills = List.from(displayUser.skills);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _fullNameController.dispose();
    _semesterController.dispose();
    _skillInputController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final updatedProfile = UserProfile(
      id: displayUser.id,
      username: displayUser.username,
      fullName: _fullNameController.text.trim(),
      bio: _bioController.text.trim(),
      skills: _editingSkills,
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

  void _addSkill(String skill) {
    if (skill.isNotEmpty && !_editingSkills.contains(skill)) {
      setState(() {
        _editingSkills.add(skill);
        _skillInputController.clear();
      });
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

  void _showFollowers() {
    if (!_isCurrentUser) return; // Only owner sees list per prompt "person being followed can see"
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Followers", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 300,
          child: displayUser.followers.isEmpty 
            ? const Center(child: Text("No followers yet", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: displayUser.followers.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<UserProfile?>(
                    future: DatabaseService().getUserProfile(displayUser.followers[index]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final u = snapshot.data!;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person)),
                        title: Text(u.fullName, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("@${u.username}", style: const TextStyle(color: Colors.grey)),
                      );
                    },
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('@${displayUser.username}', style: textTheme.titleMedium),
        backgroundColor: Colors.transparent,
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
                                    child: Icon(Icons.person, size: 40, color: Colors.white),
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
                                    style: textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                                  if (_isCurrentUser)
                                    TextButton(
                                      onPressed: _showFollowers,
                                      child: Text("${displayUser.followers.length} Followers", style: const TextStyle(color: Colors.white70)),
                                    )
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
                                          decoration: const InputDecoration(
                                            labelText: 'Bio',
                                            border: OutlineInputBorder(),
                                            isDense: true,
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
                                              labelText: "Sem",
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
                                          child: Text("Sem ${displayUser.currentSemester}", style: textTheme.bodySmall),
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
                                              Text("Open to Collab", style: textTheme.bodySmall?.copyWith(color: Colors.greenAccent)),
                                            ],
                                          ),
                                        ),

                                      if (displayUser.phoneNumber != null && displayUser.phoneNumber!.isNotEmpty)
                                        Text("📞 ${displayUser.phoneNumber}", style: textTheme.bodySmall?.copyWith(color: Colors.white54)),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Skills
                                  if (_isEditing) ...[
                                    TextField(
                                      controller: _skillInputController,
                                      style: textTheme.bodySmall,
                                      decoration: InputDecoration(
                                        labelText: 'Add skill',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                                      ),
                                      onSubmitted: (val) => _addSkill(val.trim()),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: (_isEditing ? _editingSkills : displayUser.skills).map((skill) {
                                      final color = getTagColor(skill);
                                      return Chip(
                                        label: Text(skill, style: TextStyle(fontSize: 14, color: color)),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: color.withValues(alpha: 0.15),
                                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                                        onDeleted: _isEditing ? () => _removeSkill(skill) : null,
                                        deleteIcon: Icon(Icons.close, size: 12, color: color),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Tabs for Posts / Saved
                      if (_isCurrentUser)
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.redAccent,
                          tabs: const [
                            Tab(text: "My Posts"),
                            Tab(text: "Saved"),
                          ],
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Content based on Tab (Manual implementation since we are inside SingleChildScrollView)
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          if (_isCurrentUser && _tabController.index == 1) {
                            // Saved Posts
                            return StreamBuilder<List<Post>>(
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
                              stream: DatabaseService().getUserPostsStream(displayUser.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                                final posts = snapshot.data ?? [];
                                if (posts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No posts yet.")));
                                return Column(children: posts.map((p) => PostWidget(post: p)).toList());
                              },
                            );
                          }
                        },
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
}
