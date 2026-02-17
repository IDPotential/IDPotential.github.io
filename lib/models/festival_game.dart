import 'package:cloud_firestore/cloud_firestore.dart';

class FestivalGame {
  final String id;
  final String title;
  final String description;
  final String masterId;
  final String masterName;
  final DateTime startTime;
  final int durationMinutes;
  final String location;
  final int maxParticipants;
  final List<Map<String, dynamic>> participants; // [{userId, userName, registeredAt}]

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
  });

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  int get placesLeft => maxParticipants - participants.length;

  bool isUserRegistered(String userId) {
    return participants.any((p) => p['userId'] == userId);
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
    );
  }
}
