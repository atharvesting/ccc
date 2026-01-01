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
  
  // Streak properties
  final int currentStreak;
  final int highestStreak;
  final DateTime? lastPostDate;

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
    this.currentStreak = 0,
    this.highestStreak = 0,
    this.lastPostDate,
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
      'currentStreak': currentStreak,
      'highestStreak': highestStreak,
      'lastPostDate': lastPostDate != null ? Timestamp.fromDate(lastPostDate!) : null,
    };
  }

  // Create from Firestore Data
  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      username: map['username'] ?? '',
      fullName: map['userFullName'] ?? map['fullName'] ?? '', // Handle legacy field name
      bio: map['bio'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      currentSemester: map['currentSemester'] ?? '',
      openToCollaborate: map['openToCollaborate'] ?? false,
      phoneNumber: map['phoneNumber'],
      savedPostIds: List<String>.from(map['savedPostIds'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      currentStreak: map['currentStreak'] ?? 0,
      highestStreak: map['highestStreak'] ?? 0,
      lastPostDate: map['lastPostDate'] != null 
          ? (map['lastPostDate'] as Timestamp).toDate() 
          : null,
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
  final int streak; // New field for streak at time of posting

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.userFullName,
    required this.content,
    required this.imageUrls,
    required this.tags,
    required this.timestamp,
    this.streak = 0, // Default to 0
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
      'streak': streak,
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
      streak: map['streak'] ?? 0,
    );
  }
}

class EventLink {
  final String label;
  final String url;

  EventLink({required this.label, required this.url});

  Map<String, dynamic> toMap() => {'label': label, 'url': url};

  factory EventLink.fromMap(Map<String, dynamic> map) {
    return EventLink(
      label: map['label'] ?? '',
      url: map['url'] ?? '',
    );
  }
}

class EventContact {
  final String label;
  final String info;

  EventContact({required this.label, required this.info});

  Map<String, dynamic> toMap() => {'label': label, 'info': info};

  factory EventContact.fromMap(Map<String, dynamic> map) {
    return EventContact(
      label: map['label'] ?? '',
      info: map['info'] ?? '',
    );
  }
}

class Event {
  final String id;
  final String title;
  final String description;
  final List<EventContact> contacts;
  final String venue;
  final List<EventLink> links;
  final DateTime? startDate;
  final DateTime endDate;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.contacts,
    required this.venue,
    required this.links,
    this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'venue': venue,
      'links': links.map((l) => l.toMap()).toList(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  factory Event.fromMap(String id, Map<String, dynamic> map) {
    return Event(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      contacts: (map['contacts'] as List<dynamic>?)
          ?.map((x) {
            // Handle legacy string contacts if any exist in DB
            if (x is String) return EventContact(label: 'Contact', info: x);
            return EventContact.fromMap(Map<String, dynamic>.from(x));
          })
          .toList() ?? [],
      venue: map['venue'] ?? '',
      links: (map['links'] as List<dynamic>?)
          ?.map((x) => EventLink.fromMap(Map<String, dynamic>.from(x)))
          .toList() ?? [],
      startDate: map['startDate'] != null ? (map['startDate'] as Timestamp).toDate() : null,
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }
}
