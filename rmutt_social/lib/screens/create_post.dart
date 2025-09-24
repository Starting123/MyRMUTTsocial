import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/firebase_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  final List<File> _selectedMedia = [];
  final List<VideoPlayerController> _videoControllers = [];
  
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  
  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      final picker = ImagePicker();
      
      if (isVideo) {
        final pickedFile = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5), // 5 minute limit
        );
        
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          
          setState(() {
            _selectedMedia.add(file);
            _videoControllers.add(controller);
          });
        }
      } else {
        final pickedFiles = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        if (pickedFiles.isNotEmpty) {
          setState(() {
            _selectedMedia.addAll(pickedFiles.map((file) => File(file.path)));
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick media: ${e.toString()}';
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      final file = _selectedMedia[index];
      _selectedMedia.removeAt(index);
      
      // If it's a video, dispose the controller
      for (int i = 0; i < _videoControllers.length; i++) {
        if (_videoControllers[i].dataSource == file.path) {
          _videoControllers[i].dispose();
          _videoControllers.removeAt(i);
          break;
        }
      }
    });
  }

  Future<void> _createPost() async {
    if (_textController.text.trim().isEmpty && _selectedMedia.isEmpty) {
      setState(() {
        _errorMessage = 'Please add some content or media';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final mediaUrls = <String>[];

      // Upload media files
      if (_selectedMedia.isNotEmpty) {
        for (int i = 0; i < _selectedMedia.length; i++) {
          final file = _selectedMedia[i];
          final url = await firebaseService.uploadPostMedia(
            file,
            firebaseService.currentUser!.uid,
          );
          mediaUrls.add(url);
          
          setState(() {
            _uploadProgress = (i + 1) / _selectedMedia.length;
          });
        }
      }

      // Create the post
      await firebaseService.createPost(
        content: _textController.text.trim(),
        mediaUrls: mediaUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear the form
        _textController.clear();
        setState(() {
          _selectedMedia.clear();
          for (var controller in _videoControllers) {
            controller.dispose();
          }
          _videoControllers.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedMedia.length,
        itemBuilder: (context, index) {
          final file = _selectedMedia[index];
          final isVideo = file.path.toLowerCase().contains('.mp4') ||
              file.path.toLowerCase().contains('.mov') ||
              file.path.toLowerCase().contains('.avi');

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? _buildVideoPreview(file)
                      : Image.file(
                          file,
                          width: 150,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeMedia(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  const Positioned(
                    bottom: 8,
                    left: 8,
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview(File videoFile) {
    final controller = _videoControllers.firstWhere(
      (c) => c.dataSource == videoFile.path,
      orElse: () => VideoPlayerController.file(videoFile),
    );

    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photos from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: Text(
              'Post',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text input
            TextField(
              controller: _textController,
              maxLines: null,
              minLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Media picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _showMediaPicker,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Media'),
                  ),
                ),
              ],
            ),

            // Media preview
            _buildMediaPreview(),

            // Upload progress
            if (_isLoading && _uploadProgress > 0)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text('Uploading media... ${(_uploadProgress * 100).toInt()}%'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _uploadProgress),
                ],
              ),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Create post button
            ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create Post'),
            ),

            const SizedBox(height: 32),

            // Tips
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips for great posts:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Add images or videos to make your post more engaging'),
                    const Text('• Keep videos under 5 minutes for best performance'),
                    const Text('• Use clear, high-quality images'),
                    const Text('• Share your thoughts, experiences, or interesting content'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}