import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---

  Future<void> createUserProfile(UserProfile user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updateUserProfile(UserProfile user) async {
    // 1. Update User Document
    await _db.collection('users').doc(user.id).update(user.toMap());

    // 2. Update all posts by this user to reflect new name
    // We use a batch write for atomicity and efficiency
    final batch = _db.batch();
    final postsQuery = await _db.collection('posts').where('userId', isEqualTo: user.id).get();

    for (var doc in postsQuery.docs) {
      batch.update(doc.reference, {'userFullName': user.fullName});
    }

    await batch.commit();
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      var doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(uid, doc.data()!);
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
    return null;
  }

  Stream<UserProfile> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return UserProfile.fromMap(doc.id, doc.data()!);
    });
  }

  // --- Social Features ---

  Future<void> toggleSavePost(String userId, String postId) async {
    final userRef = _db.collection('users').doc(userId);
    final userDoc = await userRef.get();
    if (!userDoc.exists) return;

    final savedIds = List<String>.from(userDoc.data()?['savedPostIds'] ?? []);
    if (savedIds.contains(postId)) {
      savedIds.remove(postId);
    } else {
      savedIds.add(postId);
    }
    await userRef.update({'savedPostIds': savedIds});
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId])
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([currentUserId])
    });

    await batch.commit();
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _db.batch();
    final currentUserRef = _db.collection('users').doc(currentUserId);
    final targetUserRef = _db.collection('users').doc(targetUserId);

    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId])
    });
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([currentUserId])
    });

    await batch.commit();
  }

  // --- Posts ---

  Future<void> createPost(Post post) async {
    // We let Firestore generate the ID, so we use .add() or .doc().set()
    // Here we use the ID generated in the app or let firestore do it.
    // Better to let firestore generate ID for posts.
    await _db.collection('posts').add(post.toMap());
  }

  Stream<List<Post>> getPostsStream() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Post.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<Post>> getUserPostsStream(String userId) {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList();
      // Sort client-side to avoid needing a composite index immediately
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  Stream<List<Post>> getSavedPostsStream(List<String> savedIds) {
    if (savedIds.isEmpty) return Stream.value([]);
    // Simple implementation: fetch all and filter.
    return _db.collection('posts').orderBy('timestamp', descending: true).snapshots().map((snap) {
      return snap.docs
          .map((doc) => Post.fromMap(doc.id, doc.data()))
          .where((p) => savedIds.contains(p.id))
          .toList();
    });
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    // Fetching all users for client-side filtering.
    // Ideally, use a dedicated search service (Algolia) for production scaling.
    final snapshot = await _db.collection('users').get();
    final allUsers = snapshot.docs.map((doc) => UserProfile.fromMap(doc.id, doc.data())).toList();

    final lowerQuery = query.toLowerCase();
    return allUsers.where((user) {
      return user.fullName.toLowerCase().contains(lowerQuery) ||
             user.username.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
