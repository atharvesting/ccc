import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Changed import
import 'package:flutter/foundation.dart'; // Added for debugPrint
// import 'dart:typed_data';
import '../models.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client; // Use Supabase client

  // HARDCODED ADMIN UID (Fallback)
  static const String _fallbackAdminUid = "aLYyefw5aCNwhrB5VHzCphBbgJv1"; 
  
  // Cache for admin status to avoid repeated database calls
  String? _cachedAdminUid;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Helper to check if a user is admin (Now Async to support transfer)
  // Cached to avoid repeated database calls
  Future<bool> isAdmin(String uid) async {
    // Check cache first
    if (_cachedAdminUid != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedAdminUid == uid;
    }
    
    try {
      final doc = await _db.collection('metadata').doc('admin').get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('uid')) {
        _cachedAdminUid = doc.data()!['uid'] as String;
        _cacheTimestamp = DateTime.now();
        return _cachedAdminUid == uid;
      }
    } catch (e) {
      debugPrint("Error checking admin status: $e");
    }
    
    // Fallback to hardcoded admin
    final isFallbackAdmin = uid == _fallbackAdminUid;
    if (isFallbackAdmin) {
      _cachedAdminUid = uid;
      _cacheTimestamp = DateTime.now();
    }
    return isFallbackAdmin;
  }

  Future<void> transferAdminRights(String newAdminUid) async {
    await _db.collection('metadata').doc('admin').set({'uid': newAdminUid});
    // Invalidate cache
    _cachedAdminUid = newAdminUid;
    _cacheTimestamp = DateTime.now();
  }

  // Real implementation needing UID
  Future<void> claimAdmin(String uid) async {
      // 1. Check if doc exists (Client check)
      final doc = await _db.collection('metadata').doc('admin').get();
      if (!doc.exists) {
        // 2. Try to create it
        await _db.collection('metadata').doc('admin').set({'uid': uid});
        // 3. Update Cache
        _cachedAdminUid = uid;
        _cacheTimestamp = DateTime.now();
      } else {
        throw Exception("Admin already exists.");
      }
  }

  // --- Storage ---
  
  Future<String> uploadImage(Uint8List fileData, String folderName) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${fileData.length}.jpg';
    final path = '$folderName/$fileName';
    
    // Upload to Supabase Storage (Bucket: 'ccc-image-bucket')
    // Ensure you have created a public bucket named 'ccc-image-bucket' in your Supabase dashboard
    await _supabase.storage.from('ccc-image-bucket').uploadBinary(
      path,
      fileData,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );

    // Get Public URL
    return _supabase.storage.from('ccc-image-bucket').getPublicUrl(path);
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

  // --- Bulk Admin Operations ---

  /// Delete ALL users from the database (DESTRUCTIVE)
  Future<int> deleteAllUsers() async {
    final usersQuery = await _db.collection('users').get();
    WriteBatch? batch = _db.batch();
    int count = 0;
    int batchCount = 0;
    
    for (var doc in usersQuery.docs) {
      batch!.delete(doc.reference);
      batchCount++;
      count++;
      
      // Firestore batch limit is 500 operations
      if (batchCount >= 500) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0 && batch != null) {
      await batch.commit();
    }
    
    return count;
  }

  /// Delete ALL posts from the database (DESTRUCTIVE)
  Future<int> deleteAllPosts() async {
    WriteBatch? batch = _db.batch();
    int count = 0;
    int batchCount = 0;
    
    // Delete global posts
    final globalPostsQuery = await _db.collection('posts').get();
    for (var doc in globalPostsQuery.docs) {
      batch!.delete(doc.reference);
      batchCount++;
      count++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }
    
    // Delete community posts
    final communitiesQuery = await _db.collection('communities').get();
    for (var communityDoc in communitiesQuery.docs) {
      final communityPostsQuery = await communityDoc.reference.collection('posts').get();
      for (var postDoc in communityPostsQuery.docs) {
        batch!.delete(postDoc.reference);
        batchCount++;
        count++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }
    }
    
    if (batchCount > 0 && batch != null) {
      await batch.commit();
    }
    
    return count;
  }

  /// Delete ALL communities from the database (DESTRUCTIVE)
  Future<int> deleteAllCommunities() async {
    final communitiesQuery = await _db.collection('communities').get();
    WriteBatch? batch = _db.batch();
    int count = 0;
    int batchCount = 0;
    
    for (var doc in communitiesQuery.docs) {
      // First delete all posts in the community
      final postsQuery = await doc.reference.collection('posts').get();
      for (var postDoc in postsQuery.docs) {
        batch!.delete(postDoc.reference);
        batchCount++;
        count++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }
      
      // Then delete the community itself
      batch!.delete(doc.reference);
      batchCount++;
      count++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0 && batch != null) {
      await batch.commit();
    }
    
    return count;
  }

  /// Delete ALL events from the database (DESTRUCTIVE)
  Future<int> deleteAllEvents() async {
    final eventsQuery = await _db.collection('events').get();
    WriteBatch? batch = _db.batch();
    int count = 0;
    int batchCount = 0;
    
    for (var doc in eventsQuery.docs) {
      batch!.delete(doc.reference);
      batchCount++;
      count++;
      
      if (batchCount >= 500) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0 && batch != null) {
      await batch.commit();
    }
    
    return count;
  }

  /// Get database statistics (useful for admin)
  Future<Map<String, int>> getDatabaseStats() async {
    final stats = <String, int>{};
    
    try {
      final usersCount = (await _db.collection('users').count().get()).count ?? 0;
      final postsCount = (await _db.collection('posts').count().get()).count ?? 0;
      final communitiesCount = (await _db.collection('communities').count().get()).count ?? 0;
      final eventsCount = (await _db.collection('events').count().get()).count ?? 0;
      
      // Count community posts
      int communityPostsCount = 0;
      final communities = await _db.collection('communities').get();
      for (var communityDoc in communities.docs) {
        final postsCount = (await communityDoc.reference.collection('posts').count().get()).count ?? 0;
        communityPostsCount += postsCount;
      }
      
      stats['users'] = usersCount;
      stats['posts'] = postsCount;
      stats['communityPosts'] = communityPostsCount;
      stats['communities'] = communitiesCount;
      stats['events'] = eventsCount;
    } catch (e) {
      debugPrint("Error getting database stats: $e");
    }
    
    return stats;
  }

  /// Clear admin cache (useful for testing)
  void clearAdminCache() {
    _cachedAdminUid = null;
    _cacheTimestamp = null;
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
      // Check if doc exists first
      if (doc.exists && doc.data() != null) {
        try {
           // Try to parse. If this fails due to model mismatch, it catches below.
           return UserProfile.fromMap(uid, doc.data()!);
        } catch (e) {
           debugPrint("CRITICAL: User doc exists but parsing failed: $e");
           // Returning null here causes AuthPage to redirect to Onboarding, 
           // which allows the user to 'repair' their profile by overwriting it.
           return null;
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
    return null;
  }

  Stream<UserProfile> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return UserProfile.fromMap(doc.id, doc.data()!);
    });
  }

  // --- Config / App Rules ---

  Future<bool> getOnePostPerDayRule() async {
    return false; // HARDCODED DISABLE
  }

  Future<void> updateOnePostPerDayRule(bool value) async {
    // using set with merge to ensure document creation if it doesn't exist
    await _db.collection('config').doc('posting_rules').set(
      {'onePostPerDay': value}, 
      SetOptions(merge: true)
    );
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

  Future<void> updatePost(Post post) async {
    // Update existing post (for editing within time limit)
    final postData = post.toMap();
    
    // Determine which collection to update
    if (post.communityId != null && post.communityId!.isNotEmpty) {
      await _db.collection('communities').doc(post.communityId).collection('posts').doc(post.id).update(postData);
    } else {
      await _db.collection('posts').doc(post.id).update(postData);
    }
  }

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
    
    // 2. Create the post
    // LOGIC CHANGE: If communityId is present, save to sub-collection.
    // Otherwise, save to global 'posts' collection.
    DocumentReference postRef;
    if (post.communityId != null && post.communityId!.isNotEmpty) {
      postRef = _db.collection('communities').doc(post.communityId).collection('posts').doc();
    } else {
      postRef = _db.collection('posts').doc();
    }

    final postData = post.toMap();
    postData['streak'] = currentStreak; // Store streak in post
    batch.set(postRef, postData);

    await batch.commit();
  }

  // Scalable Pagination: Global Feed
  Future<List<Post>> getGlobalPosts({int limit = 10, Post? lastPost}) async {
    // Query ONLY the global 'posts' collection. 
    // Community posts are in a different path, so they are automatically excluded.
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
  // NOTE: Changed to "Fan-out on Read" to avoid Firestore Composite Index requirements during development.
  // This performs individual queries for each followed user (max 10) and merges results.
  // This ensures posts appear immediately without manual index creation in Firebase Console.
  Future<List<Post>> getFollowingPosts(List<String> followingIds, {int limit = 10, Post? lastPost}) async {
    if (followingIds.isEmpty) return [];

    // Limit to 10 followed users for performance in this "Fan-out" approach
    final safeIds = followingIds.take(10).toList();

    try {
      List<Future<QuerySnapshot>> futures = [];

      for (String userId in safeIds) {
        // Query posts for ONE user. This uses default single-field indexes.
        var query = _db
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(limit);

        if (lastPost != null) {
          query = query.startAfter([lastPost.timestamp]);
        }
        
        futures.add(query.get());
      }

      // Execute all queries in parallel
      final List<QuerySnapshot> snapshots = await Future.wait(futures);
      
      List<Post> allPosts = [];
      for (var snap in snapshots) {
        for (var doc in snap.docs) {
          allPosts.add(Post.fromMap(doc.id, doc.data() as Map<String, dynamic>));
        }
      }

      // Merge and Sort
      allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Limit result
      if (allPosts.length > limit) {
        allPosts = allPosts.sublist(0, limit);
      }

      return allPosts;
    } catch (e) {
      debugPrint("Error fetching following posts: $e");
      return [];
    }
  }

  Stream<List<Post>> getPostsStream() {
    // Global feed stream
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
    // Only shows global posts on profile (privacy feature)
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
    
    // Optimized: Use Firestore 'in' query (limit 30 items per query)
    // For more than 30 saved posts, we'd need to batch queries
    if (savedIds.length > 30) {
      // Fallback: fetch all and filter (for >30 saved posts)
      return _db.collection('posts').orderBy('timestamp', descending: true).snapshots().map((snap) {
        final posts = snap.docs
            .map((doc) => Post.fromMap(doc.id, doc.data()))
            .where((p) => savedIds.contains(p.id))
            .toList();
        // Sort by timestamp descending
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return posts;
      });
    }
    
    // Optimized: Use 'in' query for up to 30 saved posts
    return _db
        .collection('posts')
        .where(FieldPath.documentId, whereIn: savedIds)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList();
      // Sort by timestamp descending (client-side since we can't use orderBy with whereIn)
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final term = query.toLowerCase();
    final endTerm = '$term\uf8ff';

    try {
      // Perform parallel queries for username and fullName using the search indices
      // This is scalable because it only fetches matching documents (limit 10)
      final results = await Future.wait([
        _db.collection('users')
           .where('search_username', isGreaterThanOrEqualTo: term)
           .where('search_username', isLessThan: endTerm)
           .limit(10)
           .get(),
        _db.collection('users')
           .where('search_fullName', isGreaterThanOrEqualTo: term)
           .where('search_fullName', isLessThan: endTerm)
           .limit(10)
           .get(),
      ]);

      final Map<String, UserProfile> uniqueUsers = {};
      
      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          uniqueUsers[doc.id] = UserProfile.fromMap(doc.id, doc.data());
        }
      }

      return uniqueUsers.values.toList();
    } catch (e) {
      debugPrint("Search Error: $e");
      return [];
    }
  }

  // --- Communities ---

  Future<void> createCommunity(Community community) async {
    // 1. Check Membership Limit (Max 3)
    // Since creator automatically joins, they must have < 3 communities currently.
    final userCommunities = await _db.collection('communities')
        .where('memberIds', arrayContains: community.creatorId)
        .get();
    
    if (userCommunities.docs.length >= 3) {
      throw Exception("You can only be part of 3 communities at most.");
    }

    // 2. Check if code exists (Uniqueness)
    final query = await _db.collection('communities').where('code', isEqualTo: community.code).get();
    if (query.docs.isNotEmpty) throw Exception("Community code already taken. Please choose another.");
    
    await _db.collection('communities').add(community.toMap());
  }

  Future<void> joinCommunity(String userId, String code) async {
    // 1. Check Membership Limit (Max 3)
    final userCommunities = await _db.collection('communities')
        .where('memberIds', arrayContains: userId)
        .get();
    
    if (userCommunities.docs.length >= 3) {
      throw Exception("You can only be part of 3 communities at most.");
    }

    // 2. Proceed with Join
    final query = await _db.collection('communities').where('code', isEqualTo: code).limit(1).get();
    if (query.docs.isEmpty) throw Exception("Invalid Community Code");
    
    final doc = query.docs.first;
    final community = Community.fromMap(doc.id, doc.data());
    
    if (community.memberIds.contains(userId)) throw Exception("You are already a member of this community.");
    
    await _db.collection('communities').doc(doc.id).update({
      'memberIds': FieldValue.arrayUnion([userId])
    });
  }

  Stream<List<Community>> getUserCommunitiesStream(String userId) {
    return _db.collection('communities')
      .where('memberIds', arrayContains: userId)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Community.fromMap(d.id, d.data())).toList());
  }

  Future<List<Post>> getCommunityPosts(String communityId, {int limit = 10, Post? lastPost}) async {
    // Query the SUB-COLLECTION for this specific community
    var query = _db.collection('communities').doc(communityId).collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit);
        
    if (lastPost != null) {
      query = query.startAfter([lastPost.timestamp]);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Post.fromMap(doc.id, doc.data())).toList();
  }

  // --- Events ---

  Future<void> createEvent(Event event) async {
    await _db.collection('events').add(event.toMap());
  }

  Future<void> updateEvent(Event event) async {
    await _db.collection('events').doc(event.id).set(event.toMap());
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  Future<void> approveEvent(String eventId) async {
    await _db.collection('events').doc(eventId).update({'isApproved': true});
  }

  Stream<List<Event>> getEventsStream() {
    return _db
        .collection('events')
        .where('isApproved', isEqualTo: true) // Only show approved events
        // Removed orderBy to avoid composite index requirement. Sorting client-side.
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) => Event.fromMap(doc.id, doc.data())).toList();
      events.sort((a, b) => b.endDate.compareTo(a.endDate));
      return events;
    });
  }

  Stream<List<Event>> getPendingEventsStream() {
    return _db
        .collection('events')
        .where('isApproved', isEqualTo: false) // Only show pending requests
        // Removed orderBy to avoid composite index requirement. Sorting client-side.
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) => Event.fromMap(doc.id, doc.data())).toList();
      events.sort((a, b) => b.endDate.compareTo(a.endDate));
      return events;
    });
  }

  // --- Skill Matching ---

  // Algorithm 1: Match based on User's Profile
  Future<List<UserProfile>> getProfileMatches(UserProfile currentUser) async {
    if (currentUser.skills.isEmpty) return [];

    // LOOSENED LOGIC: Fetch ALL users who are open to collaborate, 
    // instead of strictly filtering by skills in the DB query.
    final query = await _db.collection('users')
        .where('openToCollaborate', isEqualTo: true)
        .get();

    var candidates = query.docs
        .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
        .where((u) => u.id != currentUser.id) // Exclude self
        .toList();

    // 2. Rank candidates
    // Score = (Common Skills Count * 10) + (Sum of Ratings for Common Skills)
    candidates.sort((a, b) {
      int scoreA = _calculateMatchScore(currentUser.skills, a);
      int scoreB = _calculateMatchScore(currentUser.skills, b);
      return scoreB.compareTo(scoreA); // Descending
    });

    // Filter out users with 0 score (Must have at least one common skill)
    return candidates.where((u) => _calculateMatchScore(currentUser.skills, u) > 0).toList();
  }

  // Algorithm 2: Match based on Selected Domains
  Future<List<UserProfile>> getDomainMatches(List<String> selectedDomains) async {
    if (selectedDomains.isEmpty) return [];

    // LOOSENED LOGIC: Fetch ALL users who are open to collaborate
    final query = await _db.collection('users')
        .where('openToCollaborate', isEqualTo: true)
        .get();

    var candidates = query.docs
        .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
        .toList();

    // Rank based on how well they match the requested domains
    candidates.sort((a, b) {
      int scoreA = _calculateMatchScore(selectedDomains, a);
      int scoreB = _calculateMatchScore(selectedDomains, b);
      return scoreB.compareTo(scoreA);
    });

    // Filter out users with 0 score (Must have at least one common skill)
    return candidates.where((u) => _calculateMatchScore(selectedDomains, u) > 0).toList();
  }

  int _calculateMatchScore(List<String> targetSkills, UserProfile candidate) {
    int score = 0;
    // Normalize target skills for case-insensitive comparison
    final normalizedTargets = targetSkills.map((e) => e.toLowerCase()).toList();

    for (var skill in candidate.skills) {
      // Check if candidate's skill exists in target list (case-insensitive)
      // We iterate candidate skills to look up rating easily
      if (normalizedTargets.contains(skill.toLowerCase())) {
        score += 10; // Base score for having the skill
        score += candidate.skillRatings[skill] ?? 0; // Bonus for rating
      }
    }
    return score;
  }
}
