import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../widgets/post_actions.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    // Trigger rebuild by calling setState
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getPosts(limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading posts',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshFeed,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share something!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          final posts = snapshot.data!.docs;
          
          return ListView.builder(
            controller: _scrollController,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;
              
              return PostCard(
                postId: post.id,
                postData: postData,
              );
            },
          );
        },
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  
  const PostCard({
    super.key,
    required this.postId,
    required this.postData,
  });

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(postTime);
    }
  }

  Widget _buildMediaCarousel(List<dynamic> mediaUrls) {
    if (mediaUrls.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: PageView.builder(
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          final mediaUrl = mediaUrls[index] as String;
          final isVideo = mediaUrl.contains('.mp4') || 
                         mediaUrl.contains('.mov') || 
                         mediaUrl.contains('.avi');
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isVideo
                  ? _buildVideoPlayer(mediaUrl)
                  : CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.grey),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: videoUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: Icon(Icons.video_file, color: Colors.white, size: 48),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = (postData['mediaUrls'] as List<dynamic>?) ?? [];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          ListTile(
            leading: CircleAvatar(
              backgroundImage: postData['userPhotoURL'] != null
                  ? CachedNetworkImageProvider(postData['userPhotoURL'])
                  : null,
              child: postData['userPhotoURL'] == null
                  ? Text(
                      (postData['userDisplayName'] ?? 'U').substring(0, 1).toUpperCase(),
                    )
                  : null,
            ),
            title: Text(
              postData['userDisplayName'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _formatTimestamp(postData['createdAt'] as Timestamp?),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                // Handle menu actions (report, block, etc.)
                switch (value) {
                  case 'report':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post reported')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag),
                      SizedBox(width: 8),
                      Text('Report'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Post content
          if (postData['content'] != null && postData['content'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                postData['content'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          
          // Media carousel
          _buildMediaCarousel(mediaUrls),
          
          // Media count indicator
          if (mediaUrls.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  mediaUrls.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          
          // Post actions
          PostActions(
            postId: postId,
            likesCount: postData['likesCount'] ?? 0,
            commentsCount: postData['commentsCount'] ?? 0,
          ),
        ],
      ),
    );
  }
}