import 'package:flutter/material.dart';
import 'dart:ui';
import 'models.dart';
import 'data.dart'; // for currentUser
import 'services/database_service.dart'; // Needed to fetch user profile
import 'pages/profile_page.dart'; // Needed for navigation

// Global Design Constant
const double kAppCornerRadius = 5.0;

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
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return "${months[date.month - 1]} ${date.day}";
}

class GlassyContainer extends StatelessWidget {
  final Widget child;
  final double padding;

  const GlassyContainer({super.key, required this.child, this.padding = 16.0});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PostWidget extends StatelessWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

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
    // We need to listen to the current user's profile to update the heart icon state
    return StreamBuilder<UserProfile>(
      stream: DatabaseService().getUserProfileStream(currentUser.id),
      builder: (context, snapshot) {
        final user = snapshot.data ?? currentUser;
        final isSaved = user.savedPostIds.contains(post.id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: GlassyContainer(
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
                              Text(
                                post.userFullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.white, 
                                  fontSize: 16,
                                  decoration: TextDecoration.underline, // Visual cue
                                  decorationColor: Colors.white30,
                                ),
                              ),
                              const SizedBox(width: 8,),
                              Text(
                                '@${post.username}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                            child: Image.network(post.imageUrls[index]),
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
    );
  }
}
