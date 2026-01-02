import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Added import
import 'dart:typed_data'; // Added import
import '../models.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/database_service.dart';

class CreatePostDialog extends StatefulWidget {
  final String? communityId; // Optional: If set, post to this community
  const CreatePostDialog({super.key, this.communityId});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _contentController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<Uint8List> _selectedImageBytes = []; // Store image bytes
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    'Python', 'Java', 'C++', 'Flutter', 'React', 'Web', 'Mobile', 'AI/ML', 'Data Science', 'DevOps'
  ];

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (_selectedTags.length < 3) {
          _selectedTags.add(tag);
        }
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes.add(bytes);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImageBytes.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isEmpty) return;

    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        title: const Text("Confirm Post", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to share this update?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Post", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    // Upload Images
    List<String> uploadedImageUrls = [];
    try {
      for (var bytes in _selectedImageBytes) {
        String url = await DatabaseService().uploadImage(bytes, 'post_images');
        uploadedImageUrls.add(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading images: $e")));
        setState(() => _isSubmitting = false);
      }
      return;
    }

    final newPost = Post(
      id: '',
      userId: currentUser.id,
      username: currentUser.username,
      userFullName: currentUser.fullName,
      content: _contentController.text,
      imageUrls: uploadedImageUrls,
      tags: List.from(_selectedTags),
      timestamp: DateTime.now(),
      communityId: widget.communityId, // Pass community ID
    );

    try {
      await DatabaseService().createPost(newPost);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating post: $e")),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCommunity = widget.communityId != null;
    final themeColor = isCommunity ? Colors.blueAccent : Colors.redAccent;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassyContainer(
              color: themeColor.withValues(alpha: 0.1),
              // color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
              borderColor: themeColor.withValues(alpha: 0.3),
              padding: 0, // Reset padding as we handle it inside for full-width dividers
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCommunity ? 'Post to Community' : 'New Daily Update', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: themeColor.withValues(alpha: 0.2)),
                  
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _contentController,
                            maxLines: 5,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: themeColor,
                            decoration: const InputDecoration(
                              hintText: "What did you learn or build today?",
                              hintStyle: TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Image Preview Area
                          if (_selectedImageBytes.isNotEmpty)
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImageBytes.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(_selectedImageBytes[index], height: 80, width: 80, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              color: Colors.black54,
                                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          
                          const SizedBox(height: 20),
                          
                          // Tags
                          const Text("Tags (Max 3)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (_) => _toggleTag(tag),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                selectedColor: themeColor.withValues(alpha: 0.2),
                                checkmarkColor: themeColor,
                                labelStyle: TextStyle(
                                  color: isSelected ? themeColor : Colors.white70,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? themeColor : Colors.white10,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Divider(height: 1, color: themeColor.withValues(alpha: 0.2)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(foregroundColor: Colors.white54),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 16),
                        // Add Image Button
                        IconButton(
                          onPressed: _isSubmitting ? null : _pickImage,
                          icon: const Icon(Icons.image, color: Colors.white70),
                          tooltip: "Add Image",
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitPost,
                          icon: _isSubmitting 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, size: 18),
                          label: const Text("Post"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
