import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Search by display name
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      setState(() {
        _searchResults = querySnapshot.docs
            .where((doc) => doc.id != Provider.of<FirebaseService>(context, listen: false).currentUser?.uid)
            .toList();
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
      setState(() => _isLoading = false);
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
    
    return ListTile(
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
      title: Text(userData['displayName'] ?? 'Unknown User'),
      subtitle: Text(userData['bio'] ?? 'No bio available'),
      trailing: userData['isPrivate'] == true
          ? const Icon(Icons.lock, size: 16, color: Colors.grey)
          : null,
      onTap: () => _startChat(userDoc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Chat'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults.clear());
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // Search results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isEmpty
                                  ? Icons.search
                                  : Icons.person_search,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Search for users to start chatting'
                                  : 'No users found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Type a name to search'
                                  : 'Try a different search term',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildUserTile(_searchResults[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}