import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:webview_flutter/webview_flutter.dart'; // Removed WebView
// Import for Platform check
// import 'dart:io' show Platform;

import 'calculation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
             // Telegram Channel Area (moved to top)
            _buildTelegramContent(),
            
            const Divider(),

            // Header / Welcome Area (moved to bottom)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Logo
                  Container(
                    height: 100, // Reduced from 120
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced from 24
                  const Text(
                    'Добро пожаловать!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Индивидуальная Диагностика Потенциала',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalculationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate),
                    label: const Text('Начать новый расчет'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'v1.3.0 (Firebase Auth & Video)', 
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelegramContent() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16), // Reduced from 32
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Reduced from 24
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.telegram, size: 48, color: Colors.blue), // Reduced from 64
              const SizedBox(height: 12),
              const Text(
                'Наш Telegram канал',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Reduced font slightly
              ),
              const SizedBox(height: 4),
              const Text(
                'Следите за новостями и обновлениями в нашем канале.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final Uri url = Uri.parse('https://t.me/id_territory'); 
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                     debugPrint("Could not launch $url");
                  }
                },
                child: const Text('Открыть канал'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
