import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class N8nService {
  // Use 10.0.2.2 for Android Emulator to access host localhost
  // For physical device, you need the actual local IP of your machine (e.g., 192.168.1.x)
  static const String _baseUrl = 'http://10.0.2.2:5678/webhook/game-report';
  static const String _baseUrlWeb = 'http://localhost:5678/webhook/game-report';

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
