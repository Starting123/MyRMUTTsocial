import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Authentication methods
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      if (result.user != null) {
        await createUserDocument(result.user!);
      }
      
      return result;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      
      // Create user document if it doesn't exist
      if (result.user != null) {
        await createUserDocument(result.user!);
      }
      
      return result;
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Firestore user document methods
  Future<void> createUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? 'User',
          'photoURL': user.photoURL,
          'bio': '',
          'isPrivate': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to create user document: ${e.toString()}');
    }
  }

  Future<DocumentSnapshot> getUserDocument(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? bio,
    bool? isPrivate,
    String? photoURL,
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final uid = _auth.currentUser!.uid;
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) {
      updateData['displayName'] = displayName;
      await _auth.currentUser!.updateDisplayName(displayName);
    }
    if (bio != null) updateData['bio'] = bio;
    if (isPrivate != null) updateData['isPrivate'] = isPrivate;
    if (photoURL != null) {
      updateData['photoURL'] = photoURL;
      await _auth.currentUser!.updatePhotoURL(photoURL);
    }

    await _firestore.collection('users').doc(uid).update(updateData);
  }

  // Storage methods
  Future<String> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('File upload failed: ${e.toString()}');
    }
  }

  Future<String> uploadProfileImage(File image, String userId) async {
    final path = 'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await uploadFile(image, path);
  }

  Future<String> uploadPostMedia(File media, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = media.path.split('.').last;
    final path = 'post_media/$userId/$timestamp.$extension';
    return await uploadFile(media, path);
  }

  // Post methods
  Future<DocumentReference> createPost({
    required String content,
    List<String> mediaUrls = const [],
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userDoc = await getUserDocument(_auth.currentUser!.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    return await _firestore.collection('posts').add({
      'userId': _auth.currentUser!.uid,
      'userDisplayName': userData['displayName'] ?? 'User',
      'userPhotoURL': userData['photoURL'],
      'content': content,
      'mediaUrls': mediaUrls,
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPosts({int limit = 10}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Reaction methods
  Future<void> toggleLike(String postId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userId = _auth.currentUser!.uid;
    final reactionRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId);

    final reactionDoc = await reactionRef.get();
    final postRef = _firestore.collection('posts').doc(postId);

    if (reactionDoc.exists) {
      // Remove like
      await reactionRef.delete();
      await postRef.update({
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Add like
      await reactionRef.set({
        'userId': userId,
        'type': 'like',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  Future<bool> hasUserLikedPost(String postId) async {
    if (_auth.currentUser == null) return false;

    final reactionDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(_auth.currentUser!.uid)
        .get();

    return reactionDoc.exists;
  }

  // Comment methods
  Future<void> addComment(String postId, String content) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userDoc = await getUserDocument(_auth.currentUser!.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
      'userId': _auth.currentUser!.uid,
      'userDisplayName': userData['displayName'] ?? 'User',
      'userPhotoURL': userData['photoURL'],
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update comments count
    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Chat methods
  Future<String> getOrCreateConversation(String otherUserId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final currentUserId = _auth.currentUser!.uid;
    final conversationId = [currentUserId, otherUserId]..sort();
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId.join('_'));

    final conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) {
      await conversationRef.set({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }

    return conversationRef.id;
  }

  Future<void> sendMessage(String conversationId, String content, {String? mediaUrl}) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userDoc = await getUserDocument(_auth.currentUser!.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'senderId': _auth.currentUser!.uid,
      'senderName': userData['displayName'] ?? 'User',
      'content': content,
      'mediaUrl': mediaUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Group methods
  Future<DocumentReference> createGroup({
    required String name,
    required String description,
    bool isPrivate = false,
    String? coverImageUrl,
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userDoc = await getUserDocument(_auth.currentUser!.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    return await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'isPrivate': isPrivate,
      'coverImageUrl': coverImageUrl,
      'ownerId': _auth.currentUser!.uid,
      'ownerName': userData['displayName'] ?? 'User',
      'adminIds': [_auth.currentUser!.uid],
      'memberIds': [_auth.currentUser!.uid],
      'memberCount': 1,
      'postCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGroup(String groupId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([_auth.currentUser!.uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> updateGroup(String groupId, {
    String? name,
    String? description,
    bool? isPrivate,
    String? coverImageUrl,
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (description != null) updateData['description'] = description;
    if (isPrivate != null) updateData['isPrivate'] = isPrivate;
    if (coverImageUrl != null) updateData['coverImageUrl'] = coverImageUrl;

    await _firestore.collection('groups').doc(groupId).update(updateData);
  }

  Stream<QuerySnapshot> getGroups({int limit = 20}) {
    return _firestore
        .collection('groups')
        .where('isPrivate', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserGroups() {
    if (_auth.currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: _auth.currentUser!.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<DocumentReference> createGroupPost(String groupId, {
    required String content,
    List<String> mediaUrls = const [],
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final userDoc = await getUserDocument(_auth.currentUser!.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    final postRef = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('posts')
        .add({
      'userId': _auth.currentUser!.uid,
      'userDisplayName': userData['displayName'] ?? 'User',
      'userPhotoURL': userData['photoURL'],
      'content': content,
      'mediaUrls': mediaUrls,
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update group post count
    await _firestore.collection('groups').doc(groupId).update({
      'postCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return postRef;
  }

  Stream<QuerySnapshot> getGroupPosts(String groupId, {int limit = 10}) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Search methods
  Future<List<DocumentSnapshot>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final result = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    return result.docs
        .where((doc) => doc.id != _auth.currentUser?.uid)
        .toList();
  }

  Future<List<DocumentSnapshot>> searchTags(String query) async {
    if (query.trim().isEmpty) return [];

    final result = await _firestore
        .collection('tags')
        .where('name', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('name', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(10)
        .get();

    return result.docs;
  }

  // Follow/Unfollow methods
  Future<void> followUser(String userId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final currentUid = _auth.currentUser!.uid;
    final targetUserDoc = await getUserDocument(userId);
    final targetUserData = targetUserDoc.data() as Map<String, dynamic>;

    if (targetUserData['isPrivate'] == true) {
      // Send follow request
      await _firestore.collection('followRequests').add({
        'fromUserId': currentUid,
        'toUserId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Direct follow
      await _firestore.collection('users').doc(currentUid).update({
        'following': FieldValue.arrayUnion([userId]),
      });
      await _firestore.collection('users').doc(userId).update({
        'followers': FieldValue.arrayUnion([currentUid]),
      });
    }
  }

  Future<void> unfollowUser(String userId) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final currentUid = _auth.currentUser!.uid;
    
    await _firestore.collection('users').doc(currentUid).update({
      'following': FieldValue.arrayRemove([userId]),
    });
    await _firestore.collection('users').doc(userId).update({
      'followers': FieldValue.arrayRemove([currentUid]),
    });
  }

  Future<void> respondToFollowRequest(String requestId, bool accept) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    final requestDoc = await _firestore.collection('followRequests').doc(requestId).get();
    if (!requestDoc.exists) throw Exception('Follow request not found');

    final requestData = requestDoc.data() as Map<String, dynamic>;
    final fromUserId = requestData['fromUserId'];

    if (accept) {
      // Accept the request
      await _firestore.collection('users').doc(fromUserId).update({
        'following': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'followers': FieldValue.arrayUnion([fromUserId]),
      });
    }

    // Delete the request
    await _firestore.collection('followRequests').doc(requestId).delete();
  }

  Stream<QuerySnapshot> getFollowRequests() {
    if (_auth.currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('followRequests')
        .where('toUserId', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Reporting methods
  Future<void> reportContent({
    required String contentType, // 'post', 'comment', 'user'
    required String contentId,
    required String reason,
    String? description,
  }) async {
    if (_auth.currentUser == null) throw Exception('No user logged in');

    await _firestore.collection('reports').add({
      'reporterId': _auth.currentUser!.uid,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      'description': description ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Notification methods
  Future<void> createNotification({
    required String userId,
    required String type, // 'like', 'comment', 'follow', 'group_invite'
    required String message,
    String? postId,
    String? groupId,
  }) async {
    await _firestore
        .collection('notifications')
        .doc(userId)
        .collection('userNotifications')
        .add({
      'type': type,
      'message': message,
      'postId': postId,
      'groupId': groupId,
      'fromUserId': _auth.currentUser?.uid,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotifications() {
    if (_auth.currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('notifications')
        .doc(_auth.currentUser!.uid)
        .collection('userNotifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    if (_auth.currentUser == null) return;
    
    await _firestore
        .collection('notifications')
        .doc(_auth.currentUser!.uid)
        .collection('userNotifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // Reporting System
  Future<void> createReport({
    required String reportType,
    required String reportedId,
    String? reportedUserId,
    required String reason,
    String? additionalDetails,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('Must be logged in to report content');
    }

    // Check if user has already reported this content
    final existingReport = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: _auth.currentUser!.uid)
        .where('reportedId', isEqualTo: reportedId)
        .where('reportType', isEqualTo: reportType)
        .get();

    if (existingReport.docs.isNotEmpty) {
      throw Exception('You have already reported this $reportType');
    }

    // Create the report
    await _firestore.collection('reports').add({
      'reporterId': _auth.currentUser!.uid,
      'reportType': reportType, // 'post', 'comment', 'user'
      'reportedId': reportedId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'additionalDetails': additionalDetails,
      'additionalData': additionalData,
      'status': 'pending', // 'pending', 'investigating', 'resolved', 'dismissed'
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update reported content with report count
    await _updateReportCount(reportType, reportedId);
  }

  Future<void> _updateReportCount(String reportType, String reportedId) async {
    String collection;
    switch (reportType) {
      case 'post':
        collection = 'posts';
        break;
      case 'comment':
        collection = 'comments';
        break;
      case 'user':
        collection = 'users';
        break;
      default:
        return;
    }

    await _firestore.collection(collection).doc(reportedId).update({
      'reportCount': FieldValue.increment(1),
    });
  }

  // Get reports (for moderators/admins)
  Stream<QuerySnapshot> getReports({String? status, String? reportType}) {
    Query query = _firestore.collection('reports');
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    if (reportType != null) {
      query = query.where('reportType', isEqualTo: reportType);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // Update report status (for moderators/admins)
  Future<void> updateReportStatus(String reportId, String status, {String? adminNotes}) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status,
      'adminNotes': adminNotes,
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedBy': _auth.currentUser?.uid,
    });
  }

  // Take action on reported content (for moderators/admins)
  Future<void> takeActionOnReportedContent({
    required String reportId,
    required String action, // 'hide', 'delete', 'warn_user', 'ban_user'
    String? adminNotes,
  }) async {
    final reportDoc = await _firestore.collection('reports').doc(reportId).get();
    if (!reportDoc.exists) return;

    final reportData = reportDoc.data() as Map<String, dynamic>;
    final reportType = reportData['reportType'];
    final reportedId = reportData['reportedId'];
    final reportedUserId = reportData['reportedUserId'];

    // Update report status
    await updateReportStatus(reportId, 'resolved', adminNotes: adminNotes);

    // Take specific action based on type
    switch (action) {
      case 'hide':
        await _hideContent(reportType, reportedId);
        break;
      case 'delete':
        await _deleteContent(reportType, reportedId);
        break;
      case 'warn_user':
        if (reportedUserId != null) {
          await _warnUser(reportedUserId, adminNotes ?? 'Content violation warning');
        }
        break;
      case 'ban_user':
        if (reportedUserId != null) {
          await _banUser(reportedUserId, adminNotes ?? 'Account banned for policy violation');
        }
        break;
    }
  }

  Future<void> _hideContent(String reportType, String reportedId) async {
    String collection;
    switch (reportType) {
      case 'post':
        collection = 'posts';
        break;
      case 'comment':
        collection = 'comments';
        break;
      default:
        return;
    }

    await _firestore.collection(collection).doc(reportedId).update({
      'isHidden': true,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteContent(String reportType, String reportedId) async {
    String collection;
    switch (reportType) {
      case 'post':
        collection = 'posts';
        break;
      case 'comment':
        collection = 'comments';
        break;
      default:
        return;
    }

    await _firestore.collection(collection).doc(reportedId).delete();
  }

  Future<void> _warnUser(String userId, String message) async {
    await _firestore.collection('users').doc(userId).update({
      'warnings': FieldValue.increment(1),
      'lastWarning': message,
      'lastWarningAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the user
    await createNotification(
      userId: userId,
      type: 'warning',
      message: 'Community Guidelines Warning: $message',
    );
  }

  Future<void> _banUser(String userId, String reason) async {
    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banReason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
    });

    // Create notification for the user
    await createNotification(
      userId: userId,
      type: 'ban',
      message: 'Account Suspended: $reason',
    );
  }
}