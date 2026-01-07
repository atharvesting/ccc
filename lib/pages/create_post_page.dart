// import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Added import
import '../models.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/database_service.dart';

class CreatePostDialog extends StatefulWidget {
  final String? communityId; // Optional: If set, post to this community
  final Post? postToEdit; // Optional: If set, edit this post
  const CreatePostDialog({super.key, this.communityId, this.postToEdit});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  late TextEditingController _contentController;
  late List<String> _selectedTags;
  final List<Uint8List> _selectedImageBytes = []; // Store image bytes for new images
  final List<String> _existingImageUrls = []; // Store existing image URLs when editing
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    'Python', 'Java', 'C++', 'Flutter', 'React', 'Web', 'Mobile', 'AI/ML', 'Data Science', 'DevOps'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      // Editing mode: populate with existing post data
      _contentController = TextEditingController(text: widget.postToEdit!.content);
      _selectedTags = List.from(widget.postToEdit!.tags);
      _existingImageUrls.addAll(widget.postToEdit!.imageUrls);
    } else {
      // Create mode: empty fields
      _contentController = TextEditingController();
      _selectedTags = [];
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image to reduce upload size
        maxWidth: 1024,   // Resize large images to max 1024px width
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes.add(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isEmpty) return;

    final isEditing = widget.postToEdit != null;
    
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)),
        title: Text(isEditing ? "Confirm Edit" : "Confirm Post", style: const TextStyle(color: Colors.white)),
        content: Text(
          isEditing ? "Are you sure you want to update this post?" : "Are you sure you want to share this update?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isEditing ? "Update" : "Post",
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    // Upload new images (if any)
    List<String> uploadedImageUrls = [];
    try {
      // Note: Ensure your Supabase bucket 'images' is set to PUBLIC.
      // Otherwise, these URLs will not be viewable by users.
      for (var bytes in _selectedImageBytes) {
        String url = await DatabaseService().uploadImage(bytes, 'post_images');
        uploadedImageUrls.add(url);
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        String errorMessage = "Error uploading images";
        if (e.toString().contains("403") || e.toString().contains("security policy")) {
          errorMessage = "Permission denied. Please run the SQL script in supabase_setup.sql";
        }
        showTopNotification(context, errorMessage, isError: true);
        setState(() => _isSubmitting = false);
      }
      return;
    }

    // Combine existing URLs with newly uploaded ones
    final allImageUrls = [..._existingImageUrls, ...uploadedImageUrls];

    if (isEditing) {
      // Update existing post
      final updatedPost = Post(
        id: widget.postToEdit!.id,
        userId: widget.postToEdit!.userId,
        username: widget.postToEdit!.username,
        userFullName: widget.postToEdit!.userFullName,
        content: _contentController.text,
        imageUrls: allImageUrls,
        tags: List.from(_selectedTags),
        timestamp: widget.postToEdit!.timestamp, // Keep original timestamp
        streak: widget.postToEdit!.streak, // Keep original streak
        communityId: widget.postToEdit!.communityId, // Keep original community
      );

      try {
        await DatabaseService().updatePost(updatedPost);
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } catch (e) {
        if (mounted) {
          showTopNotification(context, "Error updating post: $e", isError: true);
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      // Create new post
      final newPost = Post(
        id: '',
        userId: currentUser.id,
        username: currentUser.username,
        userFullName: currentUser.fullName,
        content: _contentController.text,
        imageUrls: allImageUrls,
        tags: List.from(_selectedTags),
        timestamp: DateTime.now(),
        communityId: widget.communityId, // Pass community ID
      );

      try {
        await DatabaseService().createPost(newPost);
        if (mounted) Navigator.pop(context, true); // Return success
      } catch (e, stack) {
        debugPrint("Error creating post: $e\n$stack");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
          );
        }
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
                          widget.postToEdit != null
                              ? 'Edit Post'
                              : (isCommunity ? 'Post to Community' : 'New Daily Update'),
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

                          // Image Preview Area (existing + new images)
                          if (_existingImageUrls.isNotEmpty || _selectedImageBytes.isNotEmpty)
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _existingImageUrls.length + _selectedImageBytes.length,
                                itemBuilder: (context, index) {
                                  final isExisting = index < _existingImageUrls.length;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: isExisting
                                              ? Image.network(
                                                  _existingImageUrls[index],
                                                  height: 80,
                                                  width: 80,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.memory(
                                                  _selectedImageBytes[index - _existingImageUrls.length],
                                                  height: 80,
                                                  width: 80,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (isExisting) {
                                                  _existingImageUrls.removeAt(index);
                                                } else {
                                                  _selectedImageBytes.removeAt(index - _existingImageUrls.length);
                                                }
                                              });
                                            },
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
                            : Icon(widget.postToEdit != null ? Icons.save : Icons.send, size: 18),
                          label: Text(widget.postToEdit != null ? "Update" : "Post"),
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
