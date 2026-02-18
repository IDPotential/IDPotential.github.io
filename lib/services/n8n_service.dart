import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
class N8nService {
  // Use 10.0.2.2 for Android Emulator to access host localhost
  // For physical device, you need the actual local IP of your machine (e.g., 192.168.1.x)
  
  // Base URLs for reports
  static const String _baseUrl = 'http://10.0.2.2:5678/webhook/game-report';
  static const String _baseUrlWeb = 'http://localhost:5678/webhook/game-report';

  Future<void> sendFestivalApplication({
    required String name,
    required String phone,
    String? promo,
    required String type, // Visitor, Master, Maestro, Partner
  }) async {
    final url = kIsWeb ? 'http://localhost:5678/webhook/festival-application' : 'http://10.0.2.2:5678/webhook/festival-application';
    
    try {
      debugPrint('Sending Festival Application: $name, $type');
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'festival_application',
          'name': name,
          'phone': phone,
          'promo': promo,
          'participationType': type,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error sending festival application to n8n: $e');
    }
  }

  Future<void> sendGameApplication({
    required String gameTitle,
    required String clientName,
    required String contact, // Link to TG or Email
    required String time,
  }) async {
    final url = kIsWeb ? 'http://localhost:5678/webhook/game-application' : 'http://10.0.2.2:5678/webhook/game-application';
    
    try {
      debugPrint('Sending Game Application: $clientName -> $gameTitle');
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'game_application',
          'gameTitle': gameTitle,
          'clientName': clientName,
          'contact': contact,
          'time': time,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error sending game application to n8n: $e');
    }
  }

  Future<void> sendSupportRequest({
    required String userId,
    required String userName,
    required String contact,
    required String type,
    String? text,
  }) async {
    final url = kIsWeb ? 'http://localhost:5678/webhook/support-request' : 'http://10.0.2.2:5678/webhook/support-request';

    try {
      debugPrint('Sending Support Request: $userName ($type)');
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'support_request',
          'userId': userId,
          'userName': userName,
          'contact': contact,
          'requestType': type,
          'text': text ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Error sending support request to n8n: $e');
    }
  }

  Future<void> triggerGameReport({
    required String gameId,
    required String meetingId,
    required List<String> playerNames,
    required String date,
  }) async {
    final url = kIsWeb ? _baseUrlWeb : _baseUrl;
    
    try {
      debugPrint('Triggering n8n report for game: $gameId, meeting: $meetingId');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gameId': gameId,
          'meetingId': meetingId,
          'players': playerNames,
          'date': date,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('n8n webhook triggered successfully');
      } else {
        debugPrint('Failed to trigger n8n webhook: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error calling n8n webhook: $e');
    }
  }
}
