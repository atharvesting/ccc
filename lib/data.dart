import 'models.dart';

// Global Tags
final List<String> globalTags = [
  'Python', 'Flutter', 'Java', 'C++', 'Web', 'Mobile', 'AI/ML', 
  'Algorithms', 'Design', 'Database', 'Cloud', 'Security'
];

// Current Session State
// This acts as a cache for the currently logged-in user's profile
UserProfile currentUser = UserProfile(
  id: 'temp', 
  username: 'Guest', 
  fullName: 'Guest User',
  bio: '', 
  skills: [],
  currentSemester: '1',
  openToCollaborate: false,
);
