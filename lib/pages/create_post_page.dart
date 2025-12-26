import 'package:flutter/material.dart';
import '../models.dart';
import '../data.dart';
import '../widgets.dart';
import '../services/database_service.dart';

class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _contentController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<String> _attachedImages = [];
  bool _isSubmitting = false;

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _attachMockImage() {
    setState(() {
      _attachedImages.add('https://via.placeholder.com/400x200/FF0000/FFFFFF?text=New+Screenshot+${_attachedImages.length + 1}');
    });
  }

  Future<void> _submitPost() async {
    if (_contentController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final newPost = Post(
      id: '',
      userId: currentUser.id,
      username: currentUser.username,
      userFullName: currentUser.fullName,
      content: _contentController.text,
      imageUrls: List.from(_attachedImages),
      tags: List.from(_selectedTags),
      timestamp: DateTime.now(),
    );

    try {
      await DatabaseService().createPost(newPost);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassyContainer(
              padding: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Daily Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'What did you work on today?',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kAppCornerRadius), // Using global constant
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: globalTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      final color = getTagColor(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (_) => _toggleTag(tag),
                        selectedColor: color.withValues(alpha: 0.3),
                        checkmarkColor: color,
                        backgroundColor: color.withValues(alpha: 0.05),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : color),
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _attachMockImage,
                        icon: const Icon(Icons.image, color: Colors.redAccent),
                        label: const Text('Attach Screenshot', style: TextStyle(color: Colors.redAccent)),
                      ),
                      const SizedBox(width: 16),
                      if (_attachedImages.isNotEmpty)
                        Text('${_attachedImages.length} attached', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _isSubmitting 
                      ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                      : ElevatedButton(
                          onPressed: _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kAppCornerRadius)), // Using global constant
                          ),
                          child: const Text('POST UPDATE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
