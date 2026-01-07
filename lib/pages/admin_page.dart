import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed direct import
import 'dart:ui'; // For ImageFilter
import '../services/database_service.dart';
import '../models.dart';
import '../data.dart'; // for currentUser
import '../widgets.dart'; // for kAppCornerRadius

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _announcementController = TextEditingController();
  final _postIdController = TextEditingController();
  
  // Ban User State
  final _banSearchController = TextEditingController();
  List<UserProfile> _banSearchResults = [];
  UserProfile? _selectedBanUser;

  // Transfer Admin State
  final _adminSearchController = TextEditingController();
  List<UserProfile> _adminSearchResults = [];
  UserProfile? _selectedAdminUser;

  bool _isLoading = false;
  bool _isOnePostPerDayEnabled = true; // State for rule

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final rule = await DatabaseService().getOnePostPerDayRule();
    if (mounted) {
      setState(() {
        _isOnePostPerDayEnabled = rule;
      });
    }
  }

  Future<void> _togglePostingRule(bool value) async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService().updateOnePostPerDayRule(value);
      setState(() => _isOnePostPerDayEnabled = value);
      if (mounted) showTopNotification(context, "Rule Updated: One Post Per Day is now ${value ? 'ON' : 'OFF'}");
    } catch (e) {
      // PERMISSION RECOVERY LOGIC
      if (e.toString().contains("permission-denied")) {
        try {
           debugPrint("Permission denied. Attempting to claim admin rights (Bootstrap)...");
           // Try to self-appoint as admin (Works only if no admin exists in DB yet)
           await DatabaseService().claimAdmin(currentUser.id);
           
           // Retry the operation
           await DatabaseService().updateOnePostPerDayRule(value);
           setState(() => _isOnePostPerDayEnabled = value);
           if (mounted) showTopNotification(context, "Admin Rights Claimed & Rule Updated!");
           return; // Success on retry
        } catch (e2) {
           debugPrint("Bootstrap failed: $e2");
           // Fall through to error
        }
      }

      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _postAnnouncement() async {
    if (_announcementController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final post = Post(
        id: '', // Firestore generates this
        userId: currentUser.id,
        userFullName: "Admin Announcement", // Special name
        username: "admin",
        content: _announcementController.text.trim(),
        timestamp: DateTime.now(), imageUrls: [], tags: [],
      );
      
      await DatabaseService().createAnnouncement(post);
      if (mounted) {
        showTopNotification(context, "Announcement Posted!");
        _announcementController.clear();
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Generic Search Helper
  Future<void> _searchUsers(String query, Function(List<UserProfile>) onResults) async {
    if (query.isEmpty) {
      onResults([]);
      return;
    }
    final results = await DatabaseService().searchUsers(query);
    onResults(results);
  }

  Future<bool?> _showConfirmation(
    String title,
    String content,
    String confirmText,
    Color confirmColor, {
    bool requiresTextInput = false,
    String? confirmationText,
  }) {
    if (!requiresTextInput) {
      return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text(confirmText, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
    }

    // For dangerous operations, require text input
    return showDialog<bool>(
      context: context,
      builder: (context) => _DangerConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        confirmColor: confirmColor,
        confirmationText: confirmationText ?? "DELETE ALL",
      ),
    );
  }

  Future<void> _confirmAndBanUser() async {
    if (_selectedBanUser == null) return;
    
    final confirm = await _showConfirmation(
      "Ban User?", 
      "Are you sure you want to delete ${_selectedBanUser!.fullName} (@${_selectedBanUser!.username})? This action cannot be undone.", 
      "BAN & DELETE", 
      Colors.red
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService().deleteUserAsAdmin(_selectedBanUser!.id);
      if (mounted) {
        showTopNotification(context, "User Deleted");
        setState(() {
          _selectedBanUser = null;
          _banSearchController.clear();
          _banSearchResults = [];
        });
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmAndTransferAdmin() async {
    if (_selectedAdminUser == null) return;

    final confirm = await _showConfirmation(
      "Transfer Admin Rights?", 
      "Are you sure you want to make ${_selectedAdminUser!.fullName} the new Admin? You will lose access to this page immediately.", 
      "TRANSFER ADMIN", 
      Colors.amber
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService().transferAdminRights(_selectedAdminUser!.id);
      if (mounted) {
        showTopNotification(context, "Admin Rights Transferred. Goodbye!");
        Navigator.pop(context); // Exit Admin Page
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePost() async {
    if (_postIdController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await DatabaseService().deletePostAsAdmin(_postIdController.text.trim());
      if (mounted) {
        showTopNotification(context, "Post Deleted");
        _postIdController.clear();
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllUsers() async {
    final confirm = await _showConfirmation(
      "⚠️ DELETE ALL USERS? ⚠️",
      "This will PERMANENTLY DELETE ALL users and their data. This action CANNOT be undone!\n\nType 'DELETE ALL' to confirm.",
      "DELETE ALL",
      Colors.red,
      requiresTextInput: true,
      confirmationText: "DELETE ALL",
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final count = await DatabaseService().deleteAllUsers();
      if (mounted) {
        showTopNotification(context, "Deleted $count users");
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllPosts() async {
    final confirm = await _showConfirmation(
      "⚠️ DELETE ALL POSTS? ⚠️",
      "This will PERMANENTLY DELETE ALL posts (global and community posts). This action CANNOT be undone!\n\nType 'DELETE ALL' to confirm.",
      "DELETE ALL",
      Colors.red,
      requiresTextInput: true,
      confirmationText: "DELETE ALL",
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final count = await DatabaseService().deleteAllPosts();
      if (mounted) {
        showTopNotification(context, "Deleted $count posts");
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllCommunities() async {
    final confirm = await _showConfirmation(
      "⚠️ DELETE ALL COMMUNITIES? ⚠️",
      "This will PERMANENTLY DELETE ALL communities and their posts. This action CANNOT be undone!\n\nType 'DELETE ALL' to confirm.",
      "DELETE ALL",
      Colors.red,
      requiresTextInput: true,
      confirmationText: "DELETE ALL",
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final count = await DatabaseService().deleteAllCommunities();
      if (mounted) {
        showTopNotification(context, "Deleted $count communities");
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAllEvents() async {
    final confirm = await _showConfirmation(
      "⚠️ DELETE ALL EVENTS? ⚠️",
      "This will PERMANENTLY DELETE ALL events. This action CANNOT be undone!\n\nType 'DELETE ALL' to confirm.",
      "DELETE ALL",
      Colors.red,
      requiresTextInput: true,
      confirmationText: "DELETE ALL",
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final count = await DatabaseService().deleteAllEvents();
      if (mounted) {
        showTopNotification(context, "Deleted $count events");
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, "Error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Stream<Map<String, int>> _getStatsStream() {
    // Only fetch once when the page is opened
    return Stream.value(null).asyncMap((_) => DatabaseService().getDatabaseStats());
  }

  void _showEditEventDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => EditEventRequestDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Admin Console", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Background Gradient
          AppBackground(
            gradientColors: AppColors.defaultGradient,
            child: Container(),
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
                  color: Colors.amber.withValues(alpha: 0.1),
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
                  color: Colors.red.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          
          // 3. Content
          if (_isLoading)
            const AppLoadingIndicator()
          else
            SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: kToolbarHeight + 20),
                        
                        // Section 0: Event Requests (New)
                        _buildSection(
                          title: "Event Requests",
                          icon: Icons.notifications_active,
                          color: Colors.green,
                          children: [
                            StreamBuilder<List<Event>>(
                              stream: DatabaseService().getPendingEventsStream(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("Error loading requests: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)),
                                  );
                                }
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                                }
                                final requests = snapshot.data ?? [];
                                if (requests.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("No pending event requests.", style: TextStyle(color: Colors.white54)),
                                  );
                                }
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: requests.length,
                                  separatorBuilder: (_, _) => const Divider(color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final event = requests[index];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(event.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(event.venue, style: const TextStyle(color: Colors.white54)),
                                          const SizedBox(height: 4),
                                          Text(
                                            "From: ${event.userFullName} (@${event.username})",
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.edit, color: Colors.white54, size: 20),
                                      onTap: () => _showEditEventDialog(event),
                                    );
                                  },
                                );
                              },
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 1: Announcement
                        _buildSection(
                          title: "Create Announcement",
                          icon: Icons.campaign,
                          color: Colors.amber,
                          children: [
                            _buildTextField(_announcementController, "Announcement Text", maxLines: 3),
                            const SizedBox(height: 16),
                            _buildButton("Post Announcement", Icons.send, Colors.amber.withValues(alpha: 0.2), Colors.amber, _postAnnouncement),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Ban User (Updated with Search)
                        _buildSection(
                          title: "Ban User",
                          icon: Icons.block,
                          color: Colors.redAccent,
                          children: [
                            _buildUserSearchSection(
                              controller: _banSearchController,
                              hint: "Search user to ban...",
                              results: _banSearchResults,
                              selectedUser: _selectedBanUser,
                              onSearch: (q) => _searchUsers(q, (res) => setState(() => _banSearchResults = res)),
                              onSelect: (u) => setState(() { _selectedBanUser = u; _banSearchResults = []; _banSearchController.clear(); }),
                              onClear: () => setState(() => _selectedBanUser = null),
                            ),
                            const SizedBox(height: 16),
                            _buildButton(
                              "Delete User & Data", 
                              Icons.delete_forever, 
                              Colors.red.withValues(alpha: 0.2), 
                              Colors.redAccent, 
                              _selectedBanUser != null ? _confirmAndBanUser : null
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 3: Transfer Admin (New)
                        _buildSection(
                          title: "Transfer Admin Rights",
                          icon: Icons.admin_panel_settings,
                          color: Colors.blueAccent,
                          children: [
                            const Text("Warning: You will lose admin access immediately.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildUserSearchSection(
                              controller: _adminSearchController,
                              hint: "Search new admin...",
                              results: _adminSearchResults,
                              selectedUser: _selectedAdminUser,
                              onSearch: (q) => _searchUsers(q, (res) => setState(() => _adminSearchResults = res)),
                              onSelect: (u) => setState(() { _selectedAdminUser = u; _adminSearchResults = []; _adminSearchController.clear(); }),
                              onClear: () => setState(() => _selectedAdminUser = null),
                            ),
                            const SizedBox(height: 16),
                            _buildButton(
                              "Transfer Rights", 
                              Icons.swap_horiz, 
                              Colors.blue.withValues(alpha: 0.2), 
                              Colors.blueAccent, 
                              _selectedAdminUser != null ? _confirmAndTransferAdmin : null
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 4: Delete Post
                        _buildSection(
                          title: "Delete Post",
                          icon: Icons.remove_circle_outline,
                          color: Colors.orangeAccent,
                          children: [
                            _buildTextField(_postIdController, "Target Post ID"),
                            const SizedBox(height: 16),
                            _buildButton("Delete Post", Icons.delete, Colors.orange.withValues(alpha: 0.2), Colors.orangeAccent, _deletePost),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 5: Database Statistics
                        _buildSection(
                          title: "Database Statistics",
                          icon: Icons.analytics,
                          color: Colors.cyan,
                          children: [
                            StreamBuilder<Map<String, int>>(
                              stream: _getStatsStream(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                                }
                                final stats = snapshot.data ?? {};
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatRow("Users", stats['users'] ?? 0, Icons.people),
                                    _buildStatRow("Global Posts", stats['posts'] ?? 0, Icons.article),
                                    _buildStatRow("Community Posts", stats['communityPosts'] ?? 0, Icons.forum),
                                    _buildStatRow("Communities", stats['communities'] ?? 0, Icons.groups),
                                    _buildStatRow("Events", stats['events'] ?? 0, Icons.event),
                                  ],
                                );
                              },
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 6: Bulk Delete Operations (DANGER ZONE)
                        _buildSection(
                          title: "DANGER ZONE",
                          icon: Icons.warning,
                          color: Colors.red,
                          children: [
                            const Text(
                              "These operations are IRREVERSIBLE. Use with extreme caution!",
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            _buildDangerButton("Delete ALL Users", Icons.delete_forever, _deleteAllUsers),
                            const SizedBox(height: 8),
                            _buildDangerButton("Delete ALL Posts", Icons.delete_sweep, _deleteAllPosts),
                            const SizedBox(height: 8),
                            _buildDangerButton("Delete ALL Communities", Icons.group_remove, _deleteAllCommunities),
                            const SizedBox(height: 8),
                            _buildDangerButton("Delete ALL Events", Icons.event_busy, _deleteAllEvents),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 6.5: Global Rules (New)
                        _buildSection(
                          title: "Global Rules",
                          icon: Icons.gavel,
                          color: Colors.purpleAccent,
                          children: [
                             SwitchListTile(
                               title: const Text("One Post Per Day Limit", style: TextStyle(color: Colors.white)),
                               subtitle: Text(
                                 _isOnePostPerDayEnabled ? "Users can only post once every 24h" : "No posting limits",
                                 style: const TextStyle(color: Colors.white54, fontSize: 12),
                               ),
                               value: _isOnePostPerDayEnabled,
                               activeTrackColor: Colors.purpleAccent,
                               contentPadding: EdgeInsets.zero,
                               onChanged: _togglePostingRule,
                             ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 7: Utility Operations
                        _buildSection(
                          title: "Utilities",
                          icon: Icons.settings,
                          color: Colors.grey,
                          children: [
                            _buildButton(
                              "Clear Admin Cache",
                              Icons.refresh,
                              Colors.grey.withValues(alpha: 0.2),
                              Colors.grey,
                              () {
                                DatabaseService().clearAdminCache();
                                showTopNotification(context, "Admin cache cleared");
                              },
                            ),
                          ]
                        ),
                        
                        const SizedBox(height: 40),
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

  Widget _buildUserSearchSection({
    required TextEditingController controller,
    required String hint,
    required List<UserProfile> results,
    required UserProfile? selectedUser,
    required Function(String) onSearch,
    required Function(UserProfile) onSelect,
    required VoidCallback onClear,
  }) {
    if (selectedUser != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 16, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selectedUser.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("@${selectedUser.username}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: onClear),
          ],
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: hint,
            labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
          ),
          onChanged: onSearch,
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(kAppCornerRadius),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final user = results[index];
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(radius: 14, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 14, color: Colors.white)),
                  title: Text(user.fullName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text("@${user.username}", style: const TextStyle(color: Colors.white54)),
                  onTap: () => onSelect(user),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(kAppCornerRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
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
    );
  }

  Widget _buildButton(String text, IconData icon, Color bgColor, Color fgColor, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
          disabledForegroundColor: Colors.white30,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        ),
      ),
    );
  }

  Widget _buildDangerButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withValues(alpha: 0.2),
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kAppCornerRadius),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(kAppCornerRadius),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerConfirmationDialog extends StatefulWidget {
  final String title;
  final String content;
  final String confirmText;
  final Color confirmColor;
  final String confirmationText;

  const _DangerConfirmationDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.confirmColor,
    required this.confirmationText,
  });

  @override
  State<_DangerConfirmationDialog> createState() => _DangerConfirmationDialogState();
}

class _DangerConfirmationDialogState extends State<_DangerConfirmationDialog> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = _textController.text == widget.confirmationText;
    
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      title: Text(widget.title, style: TextStyle(color: widget.confirmColor, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.content, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: "Type '${widget.confirmationText}' to confirm",
              labelStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kAppCornerRadius),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kAppCornerRadius),
                borderSide: const BorderSide(color: Colors.red),
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.pop(context, false),
        ),
        TextButton(
          onPressed: isConfirmed ? () => Navigator.pop(context, true) : null,
          child: Text(
            widget.confirmText,
            style: TextStyle(
              color: isConfirmed ? widget.confirmColor : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class EditEventRequestDialog extends StatefulWidget {
  final Event event;
  const EditEventRequestDialog({super.key, required this.event});

  @override
  State<EditEventRequestDialog> createState() => _EditEventRequestDialogState();
}

class _EditEventRequestDialogState extends State<EditEventRequestDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _venueController;
  
  // Contacts
  final _contactLabelController = TextEditingController();
  final _contactInfoController = TextEditingController();
  late List<EventContact> _contacts;

  // Links
  final _linkLabelController = TextEditingController();
  final _linkUrlController = TextEditingController();
  late List<EventLink> _links;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descController = TextEditingController(text: widget.event.description);
    _venueController = TextEditingController(text: widget.event.venue);
    _contacts = List.from(widget.event.contacts);
    _links = List.from(widget.event.links);
    _startDate = widget.event.startDate;
    _endDate = widget.event.endDate;
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addContact() {
    if (_contactLabelController.text.trim().isNotEmpty && _contactInfoController.text.trim().isNotEmpty) {
      setState(() {
        _contacts.add(EventContact(
          label: _contactLabelController.text.trim(),
          info: _contactInfoController.text.trim()
        ));
        _contactLabelController.clear();
        _contactInfoController.clear();
      });
    }
  }

  void _addLink() {
    if (_linkLabelController.text.trim().isNotEmpty && _linkUrlController.text.trim().isNotEmpty) {
      setState(() {
        _links.add(EventLink(label: _linkLabelController.text.trim(), url: _linkUrlController.text.trim()));
        _linkLabelController.clear();
        _linkUrlController.clear();
      });
    }
  }

  Future<void> _approve() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _venueController.text.isEmpty || _endDate == null) {
      showTopNotification(context, "Please fill all mandatory fields", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final updatedEvent = Event(
        id: widget.event.id,
        userId: widget.event.userId, // Preserve userId
        userFullName: widget.event.userFullName, // Preserve userFullName
        username: widget.event.username, // Preserve username
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        venue: _venueController.text.trim(),
        contacts: _contacts,
        links: _links,
        startDate: _startDate,
        endDate: _endDate!,
        isApproved: true, // Approve it
      );

      await DatabaseService().updateEvent(updatedEvent);
      if (mounted) {
        Navigator.pop(context);
        showTopNotification(context, "Event Approved & Updated");
      }
    } catch (e) {
      if (mounted) showTopNotification(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isSubmitting = true);
    try {
      await DatabaseService().deleteEvent(widget.event.id);
      if (mounted) {
        Navigator.pop(context);
        showTopNotification(context, "Event Rejected & Deleted");
      }
    } catch (e) {
      if (mounted) showTopNotification(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      title: const Text("Review Event Request", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Added User Info
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(kAppCornerRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(
                      "Submitted by: ${widget.event.userFullName} (@${widget.event.username})",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Action Buttons at Top
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _reject,
                      icon: const Icon(Icons.close),
                      label: const Text("Reject"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _approve,
                      icon: const Icon(Icons.check),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                        foregroundColor: Colors.greenAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),
              
              // Editable Fields
              _buildTextField(_titleController, "Title *"),
              const SizedBox(height: 12),
              _buildTextField(_descController, "Description *", maxLines: 3),
              const SizedBox(height: 12),
              _buildTextField(_venueController, "Venue *"),
              const SizedBox(height: 16),
              
              // Dates
              Row(
                children: [
                  Expanded(
                    child: _buildDateSelector("Start Date (Opt)", _startDate, () => _selectDate(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateSelector("End Date *", _endDate, () => _selectDate(false)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contacts
              const Text("Contacts", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 1, child: _buildTextField(_contactLabelController, "Label")),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildTextField(_contactInfoController, "Info")),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addContact),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _contacts.map((c) => Chip(
                  label: Text("${c.label}: ${c.info}"),
                  backgroundColor: Colors.white10,
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => setState(() => _contacts.remove(c)),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Links
              const Text("Links", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 1, child: _buildTextField(_linkLabelController, "Label")),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildTextField(_linkUrlController, "URL")),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addLink),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _links.map((l) => Chip(
                  label: Text(l.label),
                  backgroundColor: Colors.white10,
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => setState(() => _links.remove(l)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        isDense: true,
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kAppCornerRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          color: Colors.black.withValues(alpha: 0.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null ? label : "${date.day}/${date.month}/${date.year}",
              style: TextStyle(color: date == null ? Colors.grey : Colors.white),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}