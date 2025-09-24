import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../widgets/post_actions.dart';

class GroupScreen extends StatefulWidget {
  final String? groupId;
  final bool isCreating;

  const GroupScreen({
    super.key,
    this.groupId,
    this.isCreating = false,
  });

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _postController = TextEditingController();
  
  bool _isPrivate = false;
  bool _isLoading = false;
  bool _isMember = false;
  bool _isAdmin = false;
  File? _selectedCoverImage;
  String? _coverImageUrl;
  Map<String, dynamic>? _groupData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (!widget.isCreating && widget.groupId != null) {
      _loadGroupData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      
      if (groupDoc.exists) {
        final data = groupDoc.data() as Map<String, dynamic>;
        setState(() {
          _groupData = data;
          _nameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _isPrivate = data['isPrivate'] ?? false;
          _coverImageUrl = data['coverImageUrl'];
          
          final firebaseService = Provider.of<FirebaseService>(context, listen: false);
          final currentUserId = firebaseService.currentUser?.uid;
          _isMember = (data['memberIds'] as List<dynamic>?)?.contains(currentUserId) ?? false;
          _isAdmin = (data['adminIds'] as List<dynamic>?)?.contains(currentUserId) ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedCoverImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _createOrUpdateGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      String? coverImageUrl = _coverImageUrl;

      // Upload cover image if selected
      if (_selectedCoverImage != null) {
        coverImageUrl = await firebaseService.uploadPostMedia(
          _selectedCoverImage!,
          firebaseService.currentUser!.uid,
        );
      }

      if (widget.isCreating) {
        // Create new group
        await firebaseService.createGroup(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          isPrivate: _isPrivate,
          coverImageUrl: coverImageUrl,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        // Update existing group
        await firebaseService.updateGroup(
          widget.groupId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          isPrivate: _isPrivate,
          coverImageUrl: coverImageUrl,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group updated successfully!')),
          );
          _loadGroupData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinLeaveGroup() async {
    setState(() => _isLoading = true);

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      if (_isMember) {
        await firebaseService.leaveGroup(widget.groupId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
        }
      } else {
        await firebaseService.joinGroup(widget.groupId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined group successfully')),
          );
        }
      }
      
      _loadGroupData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGroupPost() async {
    if (_postController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.createGroupPost(
        widget.groupId!,
        content: _postController.text.trim(),
      );
      
      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGroupSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image
          GestureDetector(
            onTap: _isAdmin ? _pickCoverImage : null,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                image: _selectedCoverImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedCoverImage!),
                        fit: BoxFit.cover,
                      )
                    : (_coverImageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(_coverImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null),
              ),
              child: _selectedCoverImage == null && _coverImageUrl == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Add Cover Photo'),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Group name
          TextField(
            controller: _nameController,
            enabled: widget.isCreating || _isAdmin,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descriptionController,
            enabled: widget.isCreating || _isAdmin,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Private group switch
          SwitchListTile(
            title: const Text('Private Group'),
            subtitle: const Text('Only members can see posts and join'),
            value: _isPrivate,
            onChanged: (widget.isCreating || _isAdmin) ? (value) {
              setState(() => _isPrivate = value);
            } : null,
          ),
          const SizedBox(height: 24),

          // Action buttons
          if (widget.isCreating || _isAdmin)
            ElevatedButton(
              onPressed: _isLoading ? null : _createOrUpdateGroup,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(widget.isCreating ? 'Create Group' : 'Update Group'),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupFeed() {
    if (widget.groupId == null) return const Center(child: Text('No group selected'));

    return Column(
      children: [
        // Post creation (for members)
        if (_isMember) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: const InputDecoration(
                      hintText: 'Share something with the group...',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _createGroupPost,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],

        // Posts stream
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: Provider.of<FirebaseService>(context).getGroupPosts(widget.groupId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No posts yet'),
                      Text('Be the first to share something!'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final post = snapshot.data!.docs[index];
                  return GroupPostCard(
                    postId: post.id,
                    groupId: widget.groupId!,
                    postData: post.data() as Map<String, dynamic>,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupMembers() {
    if (_groupData == null) return const Center(child: CircularProgressIndicator());

    final memberIds = (_groupData!['memberIds'] as List<dynamic>?) ?? [];
    
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _getGroupMembers(memberIds.cast<String>()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final members = snapshot.data ?? [];

        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final memberData = member.data() as Map<String, dynamic>;
            final isAdmin = (_groupData!['adminIds'] as List<dynamic>?)?.contains(member.id) ?? false;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: memberData['photoURL'] != null
                    ? CachedNetworkImageProvider(memberData['photoURL'])
                    : null,
                child: memberData['photoURL'] == null
                    ? Text((memberData['displayName'] ?? 'U')[0].toUpperCase())
                    : null,
              ),
              title: Text(memberData['displayName'] ?? 'Unknown'),
              subtitle: Text(memberData['bio'] ?? ''),
              trailing: isAdmin ? const Chip(label: Text('Admin')) : null,
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getGroupMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    final futures = memberIds.map((id) => 
        FirebaseFirestore.instance.collection('users').doc(id).get());
    
    final docs = await Future.wait(futures);
    return docs.where((doc) => doc.exists).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreating) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Group'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _buildGroupSettings(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupData?['name'] ?? 'Group'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isMember && !widget.isCreating)
            TextButton(
              onPressed: _isLoading ? null : _joinLeaveGroup,
              child: Text(
                _isMember ? 'Leave' : 'Join',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Members'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupFeed(),
          _buildGroupMembers(),
          _buildGroupSettings(),
        ],
      ),
    );
  }
}

class GroupPostCard extends StatelessWidget {
  final String postId;
  final String groupId;
  final Map<String, dynamic> postData;

  const GroupPostCard({
    super.key,
    required this.postId,
    required this.groupId,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: postData['userPhotoURL'] != null
                  ? CachedNetworkImageProvider(postData['userPhotoURL'])
                  : null,
              child: postData['userPhotoURL'] == null
                  ? Text((postData['userDisplayName'] ?? 'U')[0].toUpperCase())
                  : null,
            ),
            title: Text(postData['userDisplayName'] ?? 'Unknown User'),
            subtitle: Text(_formatTimestamp(postData['createdAt'] as Timestamp?)),
          ),
          
          if (postData['content'] != null && postData['content'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(postData['content']),
            ),
          
          // You can add media display here similar to the main feed
          
          PostActions(
            postId: '$groupId/posts/$postId',
            likesCount: postData['likesCount'] ?? 0,
            commentsCount: postData['commentsCount'] ?? 0,
            authorId: postData['userId'],
            postData: postData,
          ),
        ],
      ),
    );
  }
}