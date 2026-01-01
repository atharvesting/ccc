import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // HARDCODED ADMIN UID (Fallback)
  static const String _fallbackAdminUid = "aLYyefw5aCNwhrB5VHzCphBbgJv1"; 

  // Helper to check if a user is admin (Now Async to support transfer)
  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _db.collection('metadata').doc('admin').get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('uid')) {
        return doc.data()!['uid'] == uid;
      }
    } catch (e) {
      print("Error checking admin status: $e");
    }
    return uid == _fallbackAdminUid;
  }

  Future<void> transferAdminRights(String newAdminUid) async {
    await _db.collection('metadata').doc('admin').set({'uid': newAdminUid});
  }

  // --- Admin Features ---

  Future<void> deletePostAsAdmin(String postId) async {
    // In a real app, you'd check auth.currentUser.uid == adminUid here or via Security Rules
    await _db.collection('posts').doc(postId).delete();
  }

  Future<void> deleteUserAsAdmin(String targetUserId) async {
    // 1. Delete User Document
    await _db.collection('users').doc(targetUserId).delete();

    // 2. Delete all posts by this user
    final postsQuery = await _db.collection('posts').where('userId', isEqualTo: targetUserId).get();
    final batch = _db.batch();
    for (var doc in postsQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> createAnnouncement(Post post) async {
    // Force the type to be announcement if not already
    // You might need to add a 'type' field to your Post model, 
    // or just use a specific flag in the map.
    Map<String, dynamic> data = post.toMap();
    data['isAnnouncement'] = true; 
    
    await _db.collection('posts').add(data);
  }

  // --- Users ---

  Future<bool> isUsernameTaken(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

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
    final batch = _db.batch();
    
    // 1. Calculate Streak FIRST (Fetch User Profile)
    final userRef = _db.collection('users').doc(post.userId);
    final userDoc = await userRef.get();
    
    int currentStreak = 0;
    int highestStreak = 0;

    if (userDoc.exists) {
      final data = userDoc.data()!;
      final lastPostTimestamp = data['lastPostDate'] as Timestamp?;
      currentStreak = data['currentStreak'] ?? 0;
      highestStreak = data['highestStreak'] ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastPostTimestamp != null) {
        final lastDate = lastPostTimestamp.toDate().toLocal(); // Ensure Local Time
        final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final difference = today.difference(lastDateOnly).inDays;

        if (difference == 1) {
          // Posted yesterday, increment streak
          currentStreak++;
        } else if (difference > 1) {
          // Missed a day, reset streak
          currentStreak = 1;
        }
        
        // Ensure streak is at least 1 if we are posting (even if difference is 0 but streak was 0)
        if (currentStreak == 0) {
          currentStreak = 1;
        }
      } else {
        // First post ever
        currentStreak = 1;
      }

      if (currentStreak > highestStreak) {
        highestStreak = currentStreak;
      }

      batch.update(userRef, {
        'currentStreak': currentStreak,
        'highestStreak': highestStreak,
        'lastPostDate': Timestamp.fromDate(now),
      });
    } else {
      // Fallback for edge cases
      currentStreak = 1;
    }
    
    // 2. Create the post with the calculated streak
    final postRef = _db.collection('posts').doc();
    final postData = post.toMap();
    postData['streak'] = currentStreak; // Store streak in post
    batch.set(postRef, postData);

    await batch.commit();
  }

  // Scalable Pagination: Global Feed
  Future<List<Post>> getGlobalPosts({int limit = 10, Post? lastPost}) async {
    var query = _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (lastPost != null) {
      query = query.startAfter([lastPost.timestamp]);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList();
  }

  // Scalable Pagination: Following Feed
  // Note: Firestore 'whereIn' is limited to 30 values. 
  // For production with >30 following, you need a different strategy (e.g. Fan-out).
  Future<List<Post>> getFollowingPosts(List<String> followingIds, {int limit = 10, Post? lastPost}) async {
    if (followingIds.isEmpty) return [];

    // Take first 30 to avoid crash. 
    final safeIds = followingIds.take(8).toList();

    var query = _db
        .collection('posts')
        .where('userId', whereIn: safeIds)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (lastPost != null) {
      query = query.startAfter([lastPost.timestamp]);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList();
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

  // --- Events ---

  Future<void> createEvent(Event event) async {
    await _db.collection('events').add(event.toMap());
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  Stream<List<Event>> getEventsStream() {
    return _db
        .collection('events')
        .orderBy('endDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromMap(doc.id, doc.data())).toList();
    });
  }
}
