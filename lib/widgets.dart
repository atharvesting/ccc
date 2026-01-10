import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // For ImageFilter
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
import 'pages/create_post_page.dart'; // For CreatePostDialog
import 'pages/about_popup.dart'; // Added import
// For TopNotification

// ============================================
// UNIFIED DESIGN SYSTEM
// ============================================

// Global Design Constants
const double kAppCornerRadius = 5.0;
const double kDefaultPadding = 16.0;
const double kDefaultSpacing = 8.0;
const double kPageTitleSize = 26.0;
const double kPageTitleSpacing = 20.0;

// Unified Color Palette
class AppColors {
  // Primary Theme
  static const Color primary = Colors.redAccent;
  static const Color primaryDark = Color(0xFF2C0000);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF2C2C2C);
  
  // Accent Colors for Different Sections
  static const Color feedAccent = Colors.redAccent;
  static const Color communitiesAccent = Colors.blueAccent;
  static const Color eventsAccent = Colors.redAccent;
  static const Color matchingAccent = Colors.purpleAccent;
  static const Color searchAccent = Colors.redAccent;
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  
  // Background Gradients
  static const List<Color> defaultGradient = [background, primaryDark];
  static const List<Color> communitiesGradient = [background, Color(0xFF001F2C)];
  static const List<Color> matchingGradient = [background, Color(0xFF1A0033)];
}

// Unified Spacing
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

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

// REUSABLE LOGO WIDGET
class AppLogo extends StatelessWidget {
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppLogo({
    super.key, 
    this.fontSize = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: padding,
      child: Text(
        '< < <',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: kAppTitleShadows,
          height: 1.1,
        ),
      ),
    );
  }
}

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

class PostWidget extends StatefulWidget {
  final Post post;
  final UserProfile? userProfile; // Optimization: Pass this to avoid N+1 streams
  final Color themeColor; // Added for theming
  final VoidCallback? onPostUpdated; // Callback when post is edited

  const PostWidget({
    super.key, 
    required this.post, 
    this.userProfile,
    this.themeColor = Colors.redAccent,
    this.onPostUpdated,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool _isSaved; // Local state for optimistic updates
  bool _isSaving = false; // Prevent double-taps

  @override
  void initState() {
    super.initState();
    _isSaved = widget.userProfile?.savedPostIds.contains(widget.post.id) ?? false;
  }

  @override
  void didUpdateWidget(PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update saved state if userProfile changes
    if (widget.userProfile != null) {
      _isSaved = widget.userProfile!.savedPostIds.contains(widget.post.id);
    }
  }

  bool _canEditPost() {
    // Can edit if: own post AND within 15 minutes
    if (widget.post.userId != currentUser.id) return false;
    final now = DateTime.now();
    final difference = now.difference(widget.post.timestamp);
    return difference.inMinutes <= 15;
  }

  void _editPost() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CreatePostDialog(postToEdit: widget.post);
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
    ).then((result) {
      if (result == true && widget.onPostUpdated != null) {
        widget.onPostUpdated!();
      }
    });
  }

  void _handleSaveToggle() async {
    if (_isSaving) return; // Prevent double-taps
    
    setState(() {
      _isSaving = true;
      _isSaved = !_isSaved; // Optimistic update
    });

    try {
      await DatabaseService().toggleSavePost(currentUser.id, widget.post.id);
      // Update currentUser's savedPostIds for consistency
      if (_isSaved) {
        if (!currentUser.savedPostIds.contains(widget.post.id)) {
          currentUser.savedPostIds.add(widget.post.id);
        }
      } else {
        currentUser.savedPostIds.remove(widget.post.id);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });
        showTopNotification(context, "Error: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _navigateToProfile(BuildContext context) async {
    // Fetch the full user profile based on the ID in the post
    final userProfile = await DatabaseService().getUserProfile(widget.post.userId);
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
    // Otherwise, fetch the post author's profile (not currentUser).
    if (widget.userProfile != null) {
      return _buildPostContent(context, widget.userProfile!);
    }

    // Fetch the post author's profile, not the current user's profile
    return FutureBuilder<UserProfile?>(
      future: DatabaseService().getUserProfile(widget.post.userId),
      builder: (context, snapshot) {
        // Use a default profile if not found, but this shouldn't happen
        final user = snapshot.data ?? UserProfile(
          id: widget.post.userId,
          username: widget.post.username,
          fullName: widget.post.userFullName,
          bio: '',
          skills: [],
          currentSemester: 1,
          openToCollaborate: false,
        );
        return _buildPostContent(context, user);
      }
    );
  }

  Widget _buildPostContent(BuildContext context, UserProfile viewerProfile) {
    final isAnnouncement = widget.post.username == 'admin';
    final effectiveColor = isAnnouncement ? Colors.amber : widget.themeColor;
    final canEdit = _canEditPost();

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
                            widget.post.userFullName,
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
                            '@${widget.post.username}',
                            style: TextStyle(color: effectiveColor, fontSize: 12), // Use theme color
                          ),
                          // Streak Icon (From Post Data)
                          if (!isAnnouncement && widget.post.streak > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    "${widget.post.streak}",
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
                      _formatDate(widget.post.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    // Edit button (only for own posts within 15 min)
                    if (canEdit) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.blueAccent,
                        onPressed: _editPost,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "Edit post",
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Save button with optimistic update
                    IconButton(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                            )
                          : Icon(
                              _isSaved ? Icons.favorite : Icons.favorite_border,
                              color: _isSaved ? Colors.redAccent : Colors.white54,
                              size: 20,
                            ),
                      onPressed: _isSaving ? null : _handleSaveToggle,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: _isSaved ? "Unsave post" : "Save post",
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.post.content),
            if (widget.post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: widget.post.tags.map((t) {
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
            if (widget.post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.post.imageUrls.length,
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
                                    child: Image.network(widget.post.imageUrls[index], fit: BoxFit.contain),
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
                          child: Image.network(widget.post.imageUrls[index]),
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
  final VoidCallback? onAdminClosed; // Added callback

  const GlobalScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    required this.selectedIndex,
    this.onAdminClosed, // Initialize
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
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows body to extend behind the bottom bar
      body: Stack(
        children: [
          body, // The page content
          
          // Custom Floating Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SizedBox(
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none, // Allow shadows to overflow
                  children: [
                    // Title
                    GestureDetector(
                      onTap: () {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Close',
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (_, _, _) => const AboutPopup(),
                          transitionBuilder: (context, animation, secondaryAnimation, child) {
                            return BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 5 * animation.value,
                                sigmaY: 5 * animation.value,
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutBack,
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        child: const AppLogo(),
                      ),
                    ),
                    
                    // Actions
                    Positioned(
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<bool>(
                            future: DatabaseService().isAdmin(currentUser.id),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data == true) {
                                return IconButton(
                                  icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                                  tooltip: 'Admin Console',
                                  onPressed: () async {
                                    // Await the return from AdminPage
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AdminPage()),
                                    );
                                    
                                    // Trigger callback to refresh parent page if provided
                                    if (onAdminClosed != null) {
                                      onAdminClosed!();
                                    }
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                    _buildNavItem(context, Icons.groups_2_outlined, Icons.groups_2, 1),
                    _buildNavItem(context, Icons.event_note_outlined, Icons.event_note, 2),
                    _buildNavItem(context, Icons.hub_outlined, Icons.hub, 3),
                    _buildNavItem(context, Icons.search_outlined, Icons.search, 4),
                    _buildNavItem(context, Icons.person_3_outlined, Icons.person_3, 5),
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
          size: 30,
        ),
      ),
    );
  }
}

// ============================================
// REUSABLE UI COMPONENTS
// ============================================

/// Unified Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: iconColor ?? AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unified Page Title Widget
class PageTitle extends StatelessWidget {
  final String title;
  final Color? color;

  const PageTitle({
    super.key,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: kPageTitleSize,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}

/// Unified Loading Indicator
class AppLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;

  const AppLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size ?? 40,
        height: size ?? 40,
        child: CircularProgressIndicator(
          color: color ?? AppColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Unified Background Gradient Container
class AppBackground extends StatelessWidget {
  final List<Color>? gradientColors;
  final Widget child;

  const AppBackground({
    super.key,
    this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: gradientColors ?? AppColors.defaultGradient,
          stops: const [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Unified Action Button
class AppActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isExpanded;

  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primary,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
        ),
      ),
    );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// --- Helper for Top Notification ---

void showTopNotification(BuildContext context, String message, {bool isError = false}) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => TopNotification(
      message: message,
      isError: isError,
      onDismiss: () => entry.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
}

class TopNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const TopNotification({
    super.key, 
    required this.message, 
    required this.onDismiss,
    this.isError = false,
  });

  @override
  State<TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<TopNotification> with SingleTickerProviderStateMixin {
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
    final color = widget.isError ? Colors.redAccent : Colors.greenAccent;
    
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
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(50), // Pill shape
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
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
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isError ? Icons.priority_high : Icons.check, 
                          color: Colors.black, 
                          size: 16
                        ),
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
