import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class N8nService {
  // Use 10.0.2.2 for Android Emulator to access host localhost
  // For physical device, you need the actual local IP of your machine (e.g., 192.168.1.x)
  static const String _festivalWebhook = 'http://10.0.2.2:5678/webhook/festival-application';
  static const String _gameWebhook = 'http://10.0.2.2:5678/webhook/game-application';
  
  // Base URLs for reports
  static const String _baseUrl = 'http://10.0.2.2:5678/webhook/game-report';
  static const String _baseUrlWeb = 'http://localhost:5678/webhook/game-report';

  // Helper to get correct URL based on platform
  String _getUrl(String endpoint) {
     // If you use a single webhook handling different types, just use one URL.
     // Assuming for now user might set up specific webhooks, or we send 'type' in body to one webhook.
     // Let's use the base logic but allow overrides.
     // Actually, let's use a single notification webhook if possible, or distinct ones.
     // Given the user prompt, they likely have N8N. I'll define distinct endpoints for clarity, 
     // but defaulting to a generic structure if they want to route internally in N8N.
     
     // For now, I'll use specific paths which user can map in N8N.
     final baseUrl = kIsWeb ? 'https://webhook.n8n.cloud/webhook/...' : 'http://10.0.2.2:5678/webhook'; 
     // Since I don't know the exact N8N setup, I'll use a generic 'notification' webhook logic 
     // or stick to the existing pattern.
     // The existing code uses specific URLs. I will add new ones.
     
     if (kIsWeb) {
        return 'https://primary-production-426b.up.railway.app/webhook/$endpoint'; // Example/Placeholder
        // ideally user provides these. I'll keep localhost for dev or try to deduce.
     } 
     return 'http://10.0.2.2:5678/webhook/$endpoint';
  }

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
