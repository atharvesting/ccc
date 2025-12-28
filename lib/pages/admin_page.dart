import 'package:flutter/material.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Announcement Posted!")));
        _announcementController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<bool?> _showConfirmation(String title, String content, String confirmText, Color confirmColor) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: const Text("Cancel", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text(confirmText, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)),
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Deleted")));
        setState(() {
          _selectedBanUser = null;
          _banSearchController.clear();
          _banSearchResults = [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin Rights Transferred. Goodbye!")));
        Navigator.pop(context); // Exit Admin Page
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost() async {
    if (_postIdController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await DatabaseService().deletePostAsAdmin(_postIdController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post Deleted")));
        _postIdController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Admin Console", style: textTheme.titleMedium),
        backgroundColor: const Color.fromARGB(255, 43, 0, 0),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
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
            const Center(child: CircularProgressIndicator(color: Colors.redAccent))
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
                        
                        // Section 1: Announcement
                        _buildSection(
                          title: "📢 Create Announcement",
                          color: Colors.amber,
                          children: [
                            _buildTextField(_announcementController, "Announcement Text", maxLines: 3),
                            const SizedBox(height: 16),
                            _buildButton("Post Announcement", Icons.campaign, Colors.amber, Colors.black, _postAnnouncement),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Ban User (Updated with Search)
                        _buildSection(
                          title: "🚫 Ban User",
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
                              Icons.person_off, 
                              Colors.red[900]!, 
                              Colors.white, 
                              _selectedBanUser != null ? _confirmAndBanUser : null
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 3: Transfer Admin (New)
                        _buildSection(
                          title: "👑 Transfer Admin Rights",
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
                              "Make Admin", 
                              Icons.verified_user, 
                              Colors.blue[900]!, 
                              Colors.white, 
                              _selectedAdminUser != null ? _confirmAndTransferAdmin : null
                            ),
                          ]
                        ),

                        const SizedBox(height: 24),

                        // Section 4: Delete Post
                        _buildSection(
                          title: "🗑️ Delete Post",
                          color: Colors.redAccent,
                          children: [
                            _buildTextField(_postIdController, "Target Post ID"),
                            const SizedBox(height: 16),
                            _buildButton("Delete Post", Icons.delete_forever, Colors.red[900]!, Colors.white, _deletePost),
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

  Widget _buildSection({required String title, required Color color, required List<Widget> children}) {
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
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
}