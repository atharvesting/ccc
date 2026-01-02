import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'data.dart'; // for currentUser
import 'services/database_service.dart'; // Needed to fetch user profile
import 'pages/profile_page.dart';
import 'pages/feed_page.dart';
import 'pages/communities_page.dart';
import 'pages/events_page.dart';
import 'pages/skill_matching_page.dart';
import 'pages/search_page.dart';
import 'pages/auth_page.dart';
import 'pages/admin_page.dart'; // Added import

// Global Design Constant
const double kAppCornerRadius = 5.0;

// Shared Shadows for the App Title
final List<Shadow> kAppTitleShadows = [
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
];

// Helper for Tag Colors
Color getTagColor(String tag) {
  final t = tag.toLowerCase();
  // Languages - Brighter Blue (Light Blue A400)
  if (['python', 'java', 'c++', 'dart', 'javascript', 'typescript', 'c', 'c#', 'ruby', 'go', 'rust', 'swift', 'kotlin', 'html', 'css'].contains(t)) {
    return const Color(0xFF00B0FF);
  }
  // Frameworks - Brighter Cyan (Cyan A400)
  if (['flutter', 'react', 'vue', 'angular', 'django', 'flask', 'spring', 'node.js', 'next.js', 'express'].contains(t)) {
    return const Color.fromARGB(255, 0, 255, 0);
  }
  // Concepts/Science - Brighter Purple (Purple A400)
  if (['ai/ml', 'ai', 'ml', 'data science', 'tensorflow', 'pytorch', 'algorithms', 'data structures', 'math', 'computer vision', 'nlp'].contains(t)) {
    return const Color(0xFFD500F9);
  }
  // Domains/Infrastructure - Brighter Indigo (Indigo A400)
  if (['web', 'mobile', 'cloud', 'security', 'database', 'devops', 'frontend', 'backend', 'full stack', 'system design'].contains(t)) {
    return const Color.fromARGB(255, 219, 61, 254);
  }
  // Tools/Platforms - Brighter Orange (Orange A400)
  if (['git', 'docker', 'kubernetes', 'figma', 'firebase', 'aws', 'azure', 'gcp', 'linux', 'jira'].contains(t)) {
    return const Color(0xFFFF9100);
  }
  
  // Fallback - Brighter Accents
  final hash = tag.codeUnits.fold(0, (p, c) => p + c);
  final colors = [
    const Color(0xFFFF4081), // Pink A200
    const Color(0xFF1DE9B6), // Teal A400
    const Color(0xFFC6FF00), // Lime A400
    const Color(0xFFFFC400), // Amber A400
    const Color(0xFFFF3D00), // Deep Orange A400
    const Color(0xFF00E676), // Green A400
  ];
  return colors[hash % colors.length];
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final postDate = DateTime(date.year, date.month, date.day);
  final difference = today.difference(postDate).inDays;

  if (difference == 0) {
    return "Today";
  } else if (difference == 1) {
    return "Yesterday";
  } else if (difference < 7 && difference > 0) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return weekdays[date.weekday - 1];
  } else {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[date.month - 1]} ${date.day}";
  }
}

class GlassyContainer extends StatelessWidget {
  final Widget child;
  final double padding;
  final Color? color;
  final Color? borderColor;
  final Color? themeColor; // Added for easy theming

  const GlassyContainer({
    super.key, 
    required this.child, 
    this.padding = 16.0,
    this.color,
    this.borderColor,
    this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = themeColor ?? Colors.red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color ?? baseColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
          border: Border.all(color: borderColor ?? baseColor.withValues(alpha: 0.3)),
        ),
        child: child,
      ),
    );
  }
}

class PostWidget extends StatelessWidget {
  final Post post;
  final UserProfile? userProfile; // Optimization: Pass this to avoid N+1 streams
  final Color themeColor; // Added for theming

  const PostWidget({
    super.key, 
    required this.post, 
    this.userProfile,
    this.themeColor = Colors.redAccent,
  });

  void _navigateToProfile(BuildContext context) async {
    // Fetch the full user profile based on the ID in the post
    final userProfile = await DatabaseService().getUserProfile(post.userId);
    if (userProfile != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage(user: userProfile)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Optimization: If userProfile is provided (lifted state), use it directly.
    // Otherwise, fall back to internal StreamBuilder (legacy behavior).
    if (userProfile != null) {
      return _buildPostContent(context, userProfile!);
    }

    return StreamBuilder<UserProfile>(
      stream: DatabaseService().getUserProfileStream(currentUser.id),
      builder: (context, snapshot) {
        final user = snapshot.data ?? currentUser;
        return _buildPostContent(context, user);
      }
    );
  }

  Widget _buildPostContent(BuildContext context, UserProfile viewerProfile) {
    final isSaved = viewerProfile.savedPostIds.contains(post.id);
    final isAnnouncement = post.username == 'admin';
    
    final effectiveColor = isAnnouncement ? Colors.amber : themeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: GlassyContainer(
        themeColor: effectiveColor,
        // We can rely on GlassyContainer's defaults derived from themeColor, 
        // or override if we want specific opacities for posts.
        // Using defaults (0.1 bg, 0.3 border) looks clean.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Clickable User Info
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isAnnouncement) ...[
                            const Icon(Icons.campaign, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            post.userFullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.white, // Use theme color
                              fontSize: 16,
                              decoration: TextDecoration.underline, // Visual cue
                              decorationColor: effectiveColor.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 8,),
                          Text(
                            '@${post.username}',
                            style: TextStyle(color: effectiveColor, fontSize: 12), // Use theme color
                          ),
                          // Streak Icon (From Post Data)
                          if (!isAnnouncement && post.streak > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    "${post.streak}",
                                    style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatDate(post.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved ? Colors.redAccent : Colors.white54,
                        size: 20,
                      ),
                      onPressed: () {
                        DatabaseService().toggleSavePost(currentUser.id, post.id);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.content),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: post.tags.map((t) {
                  final color = getTagColor(t);
                  return Chip(
                    label: Text(t, style: TextStyle(fontSize: 10, color: color)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: color.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                  );
                }).toList(),
              )
            ],
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.network(post.imageUrls[index], fit: BoxFit.contain),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                          child: Image.network(post.imageUrls[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GlobalScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final int selectedIndex;

  const GlobalScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    required this.selectedIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == selectedIndex) return;

    Widget page;
    switch (index) {
      case 0:
        page = const FeedPage();
        break;
      case 1:
        page = const CommunitiesPage();
        break;
      case 2:
        page = const EventsPage();
        break;
      case 3:
        page = const SkillMatchingPage();
        break;
      case 4:
        page = const SearchPage();
        break;
      case 5:
        page = const ProfilePage();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true, // Allows body to extend behind the bottom bar
      appBar: AppBar(
        toolbarHeight: 60, // Increased height for floating effect
        title: Container(
          margin: const EdgeInsets.only(top: 10), // Push down from status bar
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(
            '< < <',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              shadows: kAppTitleShadows,
              height: 1.1, // Fix vertical alignment
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Admin Button Logic
          FutureBuilder<bool>(
            future: DatabaseService().isAdmin(currentUser.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  tooltip: 'Admin Console',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminPage()),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                 Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthPage()), 
                    (route) => false
                 );
              }
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400), // Constrain width for web
              child: Container(
                height: 65,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222).withValues(alpha: 0.7), // Solid dark grey, no glass effect
                  borderRadius: BorderRadius.circular(35), // Pill shape
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(context, Icons.home_outlined, Icons.home, 0),
                    _buildNavItem(context, Icons.groups_2, Icons.groups, 1),
                    _buildNavItem(context, Icons.event_note_outlined, Icons.event_note, 2),
                    _buildNavItem(context, Icons.hub, Icons.hub, 3),
                    _buildNavItem(context, Icons.search, Icons.search, 4),
                    _buildNavItem(context, Icons.person_3, Icons.person, 5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, IconData selectedIcon, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 50,
        height: double.infinity,
        alignment: Alignment.center,
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? Colors.redAccent : Colors.white70,
          size: 26,
        ),
      ),
    );
  }
}
