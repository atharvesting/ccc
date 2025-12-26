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

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging || _tabController.animation!.value == _tabController.index) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFeedButton(int index, String text) {
    final bool isActive = _tabController.index == index;
    return TextButton(
      onPressed: () {
        _tabController.animateTo(index);
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
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Global Feed
                        StreamBuilder<List<Post>>(
                          stream: DatabaseService().getPostsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                            }

                            if (snapshot.hasError) {
                              return Center(child: Text("Error: ${snapshot.error}"));
                            }

                            final posts = snapshot.data ?? [];

                            if (posts.isEmpty) {
                              return const Center(child: Text("No updates yet. Be the first!"));
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 20),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                return PostWidget(post: posts[index]);
                              },
                            );
                          },
                        ),
                        // Following Feed
                        StreamBuilder<List<Post>>(
                          stream: DatabaseService().getPostsStream(), // Fetch all and filter
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                            }

                            final allPosts = snapshot.data ?? [];
                            // Filter posts where userId is in currentUser.following
                            final followingPosts = allPosts.where((p) => currentUser.following.contains(p.userId)).toList();
                            
                            if (followingPosts.isEmpty) {
                              return const Center(child: Text("You aren't following anyone yet, or they haven't posted."));
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 20),
                              itemCount: followingPosts.length,
                              itemBuilder: (context, index) {
                                return PostWidget(post: followingPosts[index]);
                              },
                            );
                          },
                        ),
                      ],
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
