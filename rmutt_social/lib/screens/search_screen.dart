import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  
  List<DocumentSnapshot> _userResults = [];
  List<DocumentSnapshot> _tagResults = [];
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _userResults.clear();
        _tagResults.clear();
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      final userFuture = firebaseService.searchUsers(query);
      final tagFuture = firebaseService.searchTags(query);
      
      final results = await Future.wait([userFuture, tagFuture]);
      
      setState(() {
        _userResults = results[0];
        _tagResults = results[1];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
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

  Future<void> _followUser(String userId, bool isPrivate) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.followUser(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPrivate 
                ? 'Follow request sent!' 
                : 'Successfully followed user!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unfollowUser(String userId) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.unfollowUser(userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unfollowed user!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfollow user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat(DocumentSnapshot userDoc) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final conversationId = await firebaseService.getOrCreateConversation(userDoc.id);
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUserName: userData['displayName'] ?? 'User',
              otherUserPhotoURL: userData['photoURL'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserTile(DocumentSnapshot userDoc) {
    final userData = userDoc.data() as Map<String, dynamic>;
    final isPrivate = userData['isPrivate'] ?? false;
    final currentUserId = Provider.of<FirebaseService>(context, listen: false).currentUser?.uid;
    
    // Check if already following (you might want to implement this check)
    final followers = (userData['followers'] as List<dynamic>?) ?? [];
    final isFollowing = followers.contains(currentUserId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userData['photoURL'] != null
              ? CachedNetworkImageProvider(userData['photoURL'])
              : null,
          child: userData['photoURL'] == null
              ? Text(
                  (userData['displayName'] ?? 'U').substring(0, 1).toUpperCase(),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userData['displayName'] ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isPrivate)
              const Icon(Icons.lock, size: 16, color: Colors.grey),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
              Text(userData['bio']),
            const SizedBox(height: 4),
            Text(
              '${followers.length} followers',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Follow/Unfollow button
            TextButton(
              onPressed: () {
                if (isFollowing) {
                  _unfollowUser(userDoc.id);
                } else {
                  _followUser(userDoc.id, isPrivate);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: isFollowing 
                    ? Colors.grey.shade300 
                    : Theme.of(context).primaryColor,
                foregroundColor: isFollowing ? Colors.black : Colors.white,
                minimumSize: const Size(80, 32),
              ),
              child: Text(
                isFollowing ? 'Unfollow' : 'Follow',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            // Chat button
            IconButton(
              onPressed: () => _startChat(userDoc),
              icon: const Icon(Icons.chat_bubble_outline),
              iconSize: 20,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildTagTile(DocumentSnapshot tagDoc) {
    final tagData = tagDoc.data() as Map<String, dynamic>;
    final postCount = tagData['postCount'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.tag, color: Colors.white),
        ),
        title: Text(
          '#${tagData['name'] ?? 'unknown'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$postCount posts'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to tag feed (implement if needed)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tag feed for #${tagData['name']} coming soon!')),
          );
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_userResults.isEmpty && _currentQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_currentQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Search for users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Find friends to connect with',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        return _buildUserTile(_userResults[index]);
      },
    );
  }

  Widget _buildTagsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_tagResults.isEmpty && _currentQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No tags found for "$_currentQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_tagResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Search for tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Discover trending topics',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _tagResults.length,
      itemBuilder: (context, index) {
        return _buildTagTile(_tagResults[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Search users and tags...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: 'Users',
                    icon: Badge(
                      label: Text(_userResults.length.toString()),
                      child: const Icon(Icons.people),
                    ),
                  ),
                  Tab(
                    text: 'Tags',
                    icon: Badge(
                      label: Text(_tagResults.length.toString()),
                      child: const Icon(Icons.tag),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildTagsTab(),
        ],
      ),
    );
  }
}

// Follow Request Screen
class FollowRequestsScreen extends StatelessWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getFollowRequests(),
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
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No follow requests'),
                  Text('When someone requests to follow you, they\'ll appear here'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.data!.docs[index];
              final requestData = request.data() as Map<String, dynamic>;
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(requestData['fromUserId'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: CircularProgressIndicator()),
                      title: Text('Loading...'),
                    );
                  }
                  
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userData['photoURL'] != null
                            ? CachedNetworkImageProvider(userData['photoURL'])
                            : null,
                        child: userData['photoURL'] == null
                            ? Text((userData['displayName'] ?? 'U')[0].toUpperCase())
                            : null,
                      ),
                      title: Text(userData['displayName'] ?? 'Unknown User'),
                      subtitle: Text(userData['bio'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await firebaseService.respondToFollowRequest(request.id, false);
                            },
                            child: const Text('Decline'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await firebaseService.respondToFollowRequest(request.id, true);
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}