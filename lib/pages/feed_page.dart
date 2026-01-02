import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb and defaultTargetPlatform
import 'dart:ui'; // For ImageFilter
import '../models.dart';
import '../data.dart'; // for currentUser
import '../services/database_service.dart';
import '../widgets.dart';
import 'create_post_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  int _selectedIndex = 0;
  int _refreshCounter = 0; // Added to trigger feed refresh

  // Optimization: Move complex object creation out of build method to save CPU cycles
  late final BoxDecoration _circleDecoration1;
  late final BoxDecoration _circleDecoration2;
  
  static final Tween<Offset> _slideTween = Tween<Offset>(
    begin: const Offset(0.0, 0.02),
    end: Offset.zero,
  );

  bool get isDesktopLike {
    if (kIsWeb) {
      // treat web as desktop UI
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux; // non‑web desktop
  }

  // Helper to check if posted today
  bool _hasPostedToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _showLimitNotification() {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopNotification(
        message: "Daily limit reached! You can post again tomorrow.",
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  void initState() {
    super.initState();

    // Optimization: Use BoxShadow for blur instead of ImageFiltered.
    // ImageFiltered with high sigma is very expensive and causes choppy scrolling.
    _circleDecoration1 = BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.redAccent.withValues(alpha: 0),
      boxShadow: [
        BoxShadow(
          color: Colors.redAccent.withValues(alpha: 0.2),
          blurRadius: 100, // Simulates the blur effect cheaply
          spreadRadius: 10,
        ),
      ],
    );

    _circleDecoration2 = BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.red.withValues(alpha: 0),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.2),
          blurRadius: 100, // Simulates the blur effect cheaply
          spreadRadius: 10,
        ),
      ],
    );
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
  Widget build(BuildContext context) { // Removed Future and async
    return GlobalScaffold(
      selectedIndex: 0,
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
          // 2. Decorative Circles - Optimized
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: _circleDecoration1,
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: _circleDecoration2,
            ),
          ),
          // 3. Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 10),
                  
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
                      onTap: () async {
                        // 1. Check Posting Limit
                        // Fetch latest profile to ensure we have the latest lastPostDate
                        // (e.g. if user posted in a community recently)
                        final latestProfile = await DatabaseService().getUserProfile(currentUser.id);
                        if (latestProfile != null) {
                          currentUser = latestProfile;
                        }

                        if (_hasPostedToday(currentUser.lastPostDate)) {
                          if (mounted) {
                            _showLimitNotification(); // Changed from SnackBar
                          }
                          return;
                        }

                        if (!context.mounted) return;

                        final result = await showGeneralDialog(
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

                        // If post was created successfully, refresh the feed
                        if (result == true) {
                          setState(() {
                            _refreshCounter++;
                          });
                          // Update currentUser again to reflect the new post immediately
                          final updated = await DatabaseService().getUserProfile(currentUser.id);
                          if (updated != null) {
                             currentUser = updated;
                          }
                        }
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
                            position: _slideTween.animate(animation), // Use static tween
                            child: child,
                          ),
                        );
                      },
                      child: _selectedIndex == 0
                          ? PaginatedFeedList(
                              key: ValueKey('global_$_refreshCounter'), // Update key to force refresh
                              fetchFunction: (lastPost) => DatabaseService().getGlobalPosts(limit: 9, lastPost: lastPost),
                              emptyMessage: "No updates yet. Be the first!",
                              pageSize: 9, // Pass the correct limit
                            )
                          : PaginatedFeedList(
                              key: ValueKey('following_$_refreshCounter'), // Update key to force refresh
                              fetchFunction: (lastPost) => DatabaseService().getFollowingPosts(currentUser.following, limit: 8, lastPost: lastPost),
                              emptyMessage: "You aren't following anyone yet, or they haven't posted.",
                              pageSize: 8, // Pass the correct limit
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
  final int pageSize; // Added parameter to handle dynamic limits
  final Color themeColor; // Added for theming

  const PaginatedFeedList({
    super.key,
    required this.fetchFunction,
    required this.emptyMessage,
    this.pageSize = 10, // Default value
    this.themeColor = Colors.redAccent, // Default value
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
        // Fix: Check against the configured pageSize, not hardcoded 10
        if (newPosts.length < widget.pageSize) {
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

    // Optimization: Fetch user profile stream once here instead of in every PostWidget
    return StreamBuilder<UserProfile>(
      stream: DatabaseService().getUserProfileStream(currentUser.id),
      builder: (context, snapshot) {
        final userProfile = snapshot.data ?? currentUser;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.redAccent,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: _posts.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: widget.themeColor), // Use theme color
                  ));
                }
                return RepaintBoundary(
                  child: PostWidget(
                    post: _posts[index],
                    userProfile: userProfile, // Pass the stream data down
                    themeColor: widget.themeColor, // Pass theme color
                  ),
                );
              },
            ),
          ),
        );
      }
    );
  }
}

class _TopNotification extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopNotification({required this.message, required this.onDismiss});

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -2.0), // Start further up
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // Bouncy effect
      reverseCurve: Curves.easeInBack,
    ));

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offsetAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(50), // Pill shape
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.priority_high, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
