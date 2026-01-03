import 'package:flutter/material.dart';
import '../models.dart';
import '../services/database_service.dart';
import '../data.dart';
import '../widgets.dart';
import 'community_feed_page.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  void _showCreateDialog() {
    showDialog(context: context, builder: (context) => const _CreateCommunityDialog());
  }

  void _showJoinDialog() {
    showDialog(context: context, builder: (context) => const _JoinCommunityDialog());
  }

  @override
  Widget build(BuildContext context) {
    return GlobalScaffold(
      selectedIndex: 1,
      body: Stack(
        children: [
          // Background
          AppBackground(
            gradientColors: AppColors.communitiesGradient,
            child: Container(),
          ),
          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + kPageTitleSpacing),
                  
                  // Added Title
                  const PageTitle(title: "Communities"),
                  const SizedBox(height: AppSpacing.md),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _showCreateDialog,
                            borderRadius: BorderRadius.circular(kAppCornerRadius),
                            child: GlassyContainer(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderColor: Colors.blueAccent.withValues(alpha: 0.5),
                              padding: 16,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Create", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _showJoinDialog,
                            borderRadius: BorderRadius.circular(kAppCornerRadius),
                            child: GlassyContainer(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderColor: Colors.white.withValues(alpha: 0.2),
                              padding: 16,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Join", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // List
                  Expanded(
                    child: StreamBuilder<List<Community>>(
                      stream: DatabaseService().getUserCommunitiesStream(currentUser.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                        }
                        
                        final communities = snapshot.data ?? [];
                        
                        if (communities.isEmpty) {
                          return const EmptyStateWidget(
                            message: "You haven't joined any communities yet.\nCreate one or join using a code!",
                            icon: Icons.groups_outlined,
                            iconColor: AppColors.communitiesAccent,
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: communities.length,
                          itemBuilder: (context, index) {
                            final community = communities[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CommunityFeedPage(community: community)),
                                  );
                                },
                                child: GlassyContainer(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  borderColor: Colors.blueAccent.withValues(alpha: 0.3),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(kAppCornerRadius),
                                        ),
                                        child: Center(
                                          child: Text(
                                            community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(community.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(height: 4),
                                            Text(community.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                            const SizedBox(height: 4),
                                            Text("${community.memberIds.length} members", style: const TextStyle(color: Colors.white30, fontSize: 12)),
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

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog();

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _create() async {
    if (_nameController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Code are required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final community = Community(
        id: '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        code: _codeController.text.trim(),
        creatorId: currentUser.id,
        memberIds: [currentUser.id],
      );
      
      await DatabaseService().createCommunity(community);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Community Created!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      title: const Text("Create Community", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.grey)),
          ),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.grey)),
          ),
          TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Unique Code (for joining)", labelStyle: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isLoading ? null : _create,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Create"),
        ),
      ],
    );
  }
}

class _JoinCommunityDialog extends StatefulWidget {
  const _JoinCommunityDialog();

  @override
  State<_JoinCommunityDialog> createState() => _JoinCommunityDialogState();
}

class _JoinCommunityDialogState extends State<_JoinCommunityDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _join() async {
    if (_codeController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService().joinCommunity(currentUser.id, _codeController.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
      title: const Text("Join Community", style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _codeController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(labelText: "Enter Community Code", labelStyle: TextStyle(color: Colors.grey)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isLoading ? null : _join,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Join"),
        ),
      ],
    );
  }
}
