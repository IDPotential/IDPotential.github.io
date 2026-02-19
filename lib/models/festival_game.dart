import 'package:cloud_firestore/cloud_firestore.dart';

class FestivalGame {
  final String id;
  final String title;
  final String description;
  final String masterId; // Primary/Creator (optional if using list)
  final String masterName; // Display name (primary)
  final DateTime startTime;
  final int durationMinutes;
  final String location;
  final int maxParticipants;
  final List<Map<String, dynamic>> participants; 
  final int? slotId; 
  
  // New Fields
  final String? activityId; // Link to festival_activities catalog
  final List<String> masterIds; // List of UIDs who can manage this game
  final List<String> masterTickets; // List of Tickets (mXXXXX) that have access

  FestivalGame({
    required this.id,
    required this.title,
    required this.description,
    required this.masterId,
    required this.masterName,
    required this.startTime,
    required this.durationMinutes,
    required this.location,
    required this.maxParticipants,
    required this.participants,
    this.slotId,
    this.activityId,
    this.masterIds = const [],
    this.masterTickets = const [],
  });

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));
  int get placesLeft => maxParticipants - participants.length;

  bool isUserRegistered(String userId, [String? ticket]) {
    return participants.any((p) => p['userId'] == userId || (ticket != null && p['ticket'] == ticket));
  }
  
  // Check if a user has master access
  bool hasMasterAccess(String? uid, String? ticket) {
     if (uid != null && (uid == masterId || masterIds.contains(uid))) return true;
     if (ticket != null && masterTickets.contains(ticket)) return true;
     return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'masterId': masterId,
      'masterName': masterName,
      'startTime': Timestamp.fromDate(startTime),
      'durationMinutes': durationMinutes,
      'location': location,
      'maxParticipants': maxParticipants,
      'participants': participants,
      'slotId': slotId,
      'activityId': activityId,
      'masterIds': masterIds,
      'masterTickets': masterTickets,
    };
  }

  factory FestivalGame.fromMap(Map<String, dynamic> map, String id) {
    return FestivalGame(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      masterId: map['masterId'] ?? '',
      masterName: map['masterName'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      durationMinutes: map['durationMinutes'] ?? 60,
      location: map['location'] ?? '',
      maxParticipants: map['maxParticipants'] ?? 10,
      participants: List<Map<String, dynamic>>.from(map['participants'] ?? []),
      slotId: map['slotId'],
      activityId: map['activityId'],
      masterIds: List<String>.from(map['masterIds'] ?? []),
      masterTickets: List<String>.from(map['masterTickets'] ?? []),
    );
  }
}
