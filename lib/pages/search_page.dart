import 'package:flutter/material.dart';
import '../models.dart';
import '../services/database_service.dart';
import '../widgets.dart'; // For GlobalScaffold, GlassyContainer, kAppCornerRadius
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<UserProfile> _results = [];
  bool _isLoading = false;
  String _currentQuery = ""; // To handle race conditions

  void _performSearch(String query) async {
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final users = await DatabaseService().searchUsers(query);
      
      // Race condition check: If query changed while waiting, discard results
      if (_currentQuery != query) return;
      if (!mounted) return;

      setState(() => _results = users);
    } catch (e) {
      print("Search Error: $e"); // Log error for debugging
    } finally {
      // Only stop loading if this is still the active query
      if (mounted && _currentQuery == query) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      selectedIndex: 4,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF121212), Color(0xFF2C0000)],
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
                  const Text(
                    "Search Users",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassyContainer(
                      padding: 4.0,
                      // color: Colors.white.withValues(alpha: 0.1),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search by name or username...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.white54),
                          prefixIcon: Icon(Icons.search, color: Colors.white54),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) {
                          _performSearch(val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Results
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty 
                                    ? "Start typing to find peers..." 
                                    : "No users found.",
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final user = _results[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => ProfilePage(user: user)),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(kAppCornerRadius),
                                      child: GlassyContainer(
                                        padding: 12,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.redAccent,
                                              child: Text(
                                                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.fullName, 
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                                                  ),
                                                  Text(
                                                    "@${user.username}", 
                                                    style: const TextStyle(color: Colors.white54, fontSize: 14)
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
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
}
