import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username; // Handle (e.g. @dev_wizard)
  final String fullName; // Display Name (e.g. John Doe)
  String bio;
  final List<String> skills;
  final Map<String, int> skillRatings; // New: Rating for each skill (1-5)
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
    this.skillRatings = const {}, // Default empty
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
      'skillRatings': skillRatings,
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
      skillRatings: Map<String, int>.from(map['skillRatings'] ?? {}),
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
  final String? communityId; // New: Link to a community

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
    this.communityId,
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
      'communityId': communityId,
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
      communityId: map['communityId'],
    );
  }
}

class Community {
  final String id;
  final String name;
  final String description;
  final String code;
  final String creatorId;
  final List<String> memberIds;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.code,
    required this.creatorId,
    required this.memberIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'code': code,
      'creatorId': creatorId,
      'memberIds': memberIds,
    };
  }

  factory Community.fromMap(String id, Map<String, dynamic> map) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      code: map['code'] ?? '',
      creatorId: map['creatorId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
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
  final bool isApproved; // New field

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.contacts,
    required this.venue,
    required this.links,
    this.startDate,
    required this.endDate,
    this.isApproved = false, // Default to false (pending)
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
      'isApproved': isApproved,
    };
  }

  factory Event.fromMap(String id, Map<String, dynamic> map) {
    return Event(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      contacts: (map['contacts'] as List<dynamic>?)
          ?.map((x) {
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
      isApproved: map['isApproved'] ?? false,
    );
  }
}
