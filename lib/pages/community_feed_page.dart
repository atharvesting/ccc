import 'package:flutter/material.dart';
import 'dart:ui';
import '../models.dart';
import '../services/database_service.dart';
import '../widgets.dart';
import 'create_post_page.dart';
import 'feed_page.dart'; // For PaginatedFeedList

class CommunityFeedPage extends StatefulWidget {
  final Community community;
  const CommunityFeedPage({super.key, required this.community});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  int _refreshCounter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("  (Code: ${widget.community.code})", style: const TextStyle(color: Colors.white54)),
          ],
        ),
        backgroundColor: Colors.transparent,
        // elevation: 0,
        centerTitle: true,
        // foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF121212), Color(0xFF001F2C)],
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
                  
                  // "Add Post" Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        final result = await showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Dismiss',
                          barrierColor: Colors.black.withValues(alpha: 0.7),
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return CreatePostDialog(communityId: widget.community.id);
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

                        if (result == true) {
                          setState(() {
                            _refreshCounter++;
                          });
                        }
                      },
                      child: GlassyContainer(
                        padding: 12.0,
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderColor: Colors.blueAccent.withValues(alpha: 0.3),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.edit, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "What have you built or worked on today?",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Feed
                  Expanded(
                    child: PaginatedFeedList(
                      key: ValueKey('community_${widget.community.id}_$_refreshCounter'),
                      fetchFunction: (lastPost) => DatabaseService().getCommunityPosts(widget.community.id, limit: 10, lastPost: lastPost),
                      emptyMessage: "No posts in this community yet.",
                      themeColor: Colors.blueAccent, // Pass blue theme
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
