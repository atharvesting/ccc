import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username; // Handle (e.g. @dev_wizard)
  final String fullName; // Display Name (e.g. John Doe)
  String bio;
  final List<String> skills;
  final String currentSemester;
  final bool openToCollaborate;
  final String? phoneNumber;
  final List<String> savedPostIds; // New: For "Like/Save" feature
  final List<String> followers;    // New: For "Follow" feature
  final List<String> following;    // New: For "Follow" feature

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.skills,
    required this.currentSemester,
    required this.openToCollaborate,
    this.phoneNumber,
    this.savedPostIds = const [],
    this.followers = const [],
    this.following = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'fullName': fullName,
      'bio': bio,
      'skills': skills,
      'currentSemester': currentSemester,
      'openToCollaborate': openToCollaborate,
      'phoneNumber': phoneNumber,
      'savedPostIds': savedPostIds,
      'followers': followers,
      'following': following,
    };
  }

  // Create from Firestore Data
  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? 'Unknown User',
      bio: map['bio'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      currentSemester: map['currentSemester'] ?? 'N/A',
      openToCollaborate: map['openToCollaborate'] ?? false,
      phoneNumber: map['phoneNumber'],
      savedPostIds: List<String>.from(map['savedPostIds'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
    );
  }
}

class Post {
  final String id;
  final String userId;
  final String username;
  final String userFullName; // Store name on post for easy display
  final String content;
  final List<String> imageUrls;
  final List<String> tags;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.userFullName,
    required this.content,
    required this.imageUrls,
    required this.tags,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userFullName': userFullName,
      'content': content,
      'imageUrls': imageUrls,
      'tags': tags,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    return Post(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Unknown',
      userFullName: map['userFullName'] ?? 'Unknown User',
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
