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
}