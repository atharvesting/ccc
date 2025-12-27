import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // For ImageFilter
import '../models.dart';
import '../data.dart'; // for currentUser
import '../services/database_service.dart';
import '../widgets.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'search_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildFeedButton(int index, String text) {
    final bool isActive = _selectedIndex == index;
    return TextButton(
      onPressed: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.redAccent : Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to show behind AppBar
      appBar: AppBar(
        title: Text(
          '< < <',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            shadows: [
              const Shadow(
                blurRadius: 30.0,
                color: Colors.redAccent,
                offset: Offset(0, 0),
              ),
              Shadow(
                blurRadius: 30.0,
                color: Colors.red.withValues(alpha: 0.6),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent, // Glassy effect handled by body stack
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        // Removed bottom TabBar
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Users',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 20),
                  
                  // Custom Feed Switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFeedButton(0, "Global"),
                        const SizedBox(width: 20),
                        _buildFeedButton(1, "Following"),
                      ],
                    ),
                  ),

                  // "Add Post" Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Dismiss',
                          barrierColor: Colors.black.withValues(alpha: 0.7),
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return const CreatePostDialog();
                          },
                          transitionBuilder: (context, animation, secondaryAnimation, child) {
                            return BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 10 * animation.value, 
                                sigmaY: 10 * animation.value
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: animation, 
                                    curve: Curves.easeOutBack
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: GlassyContainer(
                        padding: 12.0,
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: Icon(Icons.edit, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "What is your progress for today?",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Feed List
                  Expanded(
                    child: AnimatedSwitcher(
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
                      child: _selectedIndex == 0
                          ? PaginatedFeedList(
                              key: const ValueKey('global'),
                              fetchFunction: (lastPost) => DatabaseService().getGlobalPosts(limit: 10, lastPost: lastPost),
                              emptyMessage: "No updates yet. Be the first!",
                            )
                          : PaginatedFeedList(
                              key: const ValueKey('following'),
                              fetchFunction: (lastPost) => DatabaseService().getFollowingPosts(currentUser.following, limit: 10, lastPost: lastPost),
                              emptyMessage: "You aren't following anyone yet, or they haven't posted.",
                            ),
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

class PaginatedFeedList extends StatefulWidget {
  final Future<List<Post>> Function(Post? lastPost) fetchFunction;
  final String emptyMessage;

  const PaginatedFeedList({
    super.key,
    required this.fetchFunction,
    required this.emptyMessage,
  });

  @override
  State<PaginatedFeedList> createState() => _PaginatedFeedListState();
}

class _PaginatedFeedListState extends State<PaginatedFeedList> {
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final newPosts = await widget.fetchFunction(_posts.isNotEmpty ? _posts.last : null);
      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
        if (newPosts.length < 10) {
          _hasMore = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error gracefully
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _hasMore = true;
    });
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    if (_posts.isEmpty && !_isLoading) {
      return Center(child: Text(widget.emptyMessage));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.redAccent,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.redAccent),
            ));
          }
          return PostWidget(post: _posts[index]);
        },
      ),
    );
  }
}
