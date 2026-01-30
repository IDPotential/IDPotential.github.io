import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:webview_flutter/webview_flutter.dart'; // Removed WebView
// Import for Platform check
// import 'dart:io' show Platform;

import 'calculation_screen.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

import 'package:package_info_plus/package_info_plus.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrev;
  const HomeScreen({super.key, this.onMenuTap, this.onSwipeNext, this.onSwipePrev});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
       setState(() {
          _appVersion = "${info.version} (${info.buildNumber})";
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenuTap != null 
          ? IconButton(icon: const Icon(Icons.menu), onPressed: widget.onMenuTap)
          : null,
        title: const Text('Главная'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Личный кабинет',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensure overscroll works
              child: Column(

          children: [
             // Festival Banner
             _buildFestivalBanner(context),

             // Telegram Channel Area (moved to top)
            _buildTelegramContent(),
            
            const Divider(),

            // Header / Welcome Area (moved to bottom)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // User Info & Credits
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirestoreService().getUserData(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const SizedBox();
                      
                      int credits = 0;
                      if (snapshot.hasData && snapshot.data!.exists) {
                         credits = snapshot.data!.data()?['credits'] ?? 0;
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$credits кр.',
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
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
                  const SizedBox(height: 8),

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
                  Text(
                    'v$_appVersion', 
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            ],
          ),
        ),
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
  Widget _buildFestivalBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E0249), Color(0xFF7B1FA2)], // Deep Purple to Purple
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/festival'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ТЕРРИТОРИЯ ИГРЫ",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "21 Февраля • Событие года",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
