import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../screens/comments_screen.dart';
import '../screens/report_screen.dart';

class PostActions extends StatefulWidget {
  final String postId;
  final int likesCount;
  final int commentsCount;
  final String authorId;
  final Map<String, dynamic>? postData; // For report context

  const PostActions({
    super.key,
    required this.postId,
    required this.likesCount,
    required this.commentsCount,
    required this.authorId,
    this.postData,
  });

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  bool _isLiked = false;
  bool _isLoading = false;
  int _currentLikesCount = 0;

  @override
  void initState() {
    super.initState();
    _currentLikesCount = widget.likesCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final liked = await firebaseService.hasUserLikedPost(widget.postId);
      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Optimistic update
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _currentLikesCount += _isLiked ? 1 : -1;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.toggleLike(widget.postId);
    } catch (e) {
      // Rollback on error
      setState(() {
        _isLiked = wasLiked;
        _currentLikesCount = widget.likesCount;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isLiked ? 'like' : 'unlike'} post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'React to this post',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton('❤️', 'Love'),
                _buildReactionButton('😂', 'Laugh'),
                _buildReactionButton('😮', 'Wow'),
                _buildReactionButton('😢', 'Sad'),
                _buildReactionButton('😡', 'Angry'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String emoji, String label) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _addReaction(emoji, label);
      },
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addReaction(String emoji, String type) async {
    try {
      // For now, we'll just show a snackbar
      // In a full implementation, you'd save the reaction to Firestore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reacted with $emoji'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add reaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(postId: widget.postId),
      ),
    );
  }

  void _showReportDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          reportType: 'post',
          reportedId: widget.postId,
          reportedUserId: widget.authorId,
          additionalData: widget.postData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Like button
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentLikesCount.toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Reaction picker button
          GestureDetector(
            onLongPress: _showReactionPicker,
            onTap: _showReactionPicker,
            child: const Icon(
              Icons.add_reaction_outlined,
              color: Colors.grey,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Comments button
          GestureDetector(
            onTap: _openComments,
            child: Row(
              children: [
                const Icon(
                  Icons.comment_outlined,
                  color: Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.commentsCount.toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // More options button (share, report, etc.)
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share functionality coming soon!'),
                    ),
                  );
                  break;
                case 'report':
                  _showReportDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
            child: const Icon(
              Icons.more_horiz,
              color: Colors.grey,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}