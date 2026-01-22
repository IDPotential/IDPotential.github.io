
import 'dart:ui';
import 'package:flutter/material.dart';

class FestivalScreen extends StatelessWidget {
  const FestivalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 1. Dynamic Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E0249), // Deep Purple
                  Color(0xFF0F044C), // Midnight Blue
                  Color(0xFF000000), // Black
                ],
              ),
            ),
          ),
          
          // 2. Ambient Glows
          Positioned(
            top: -100,
            left: -50,
            child: _buildGlowCircle(Colors.purpleAccent.withOpacity(0.4), 300),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: _buildGlowCircle(Colors.blueAccent.withOpacity(0.4), 250),
          ),

          // 3. Content Scroll
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO SECTION
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "21 ФЕВРАЛЯ 2026",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
                          ).createShader(bounds),
                          child: const Text(
                            "ТЕРРИТОРИЯ\nИГРЫ",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 48,
                              height: 0.9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white, // Masked
                              fontFamily: 'Roboto', 
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: const Text(
                            "СИСТЕМНАЯ ПЛОЩАДКА ДЛЯ РОСТА",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // LOCATION
                  Center(
                    child: Column(
                       children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Пространство АТС, Ул.Некрасова, 3-5",
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                             padding: EdgeInsets.symmetric(horizontal: 32),
                             child: Text(
                               "Историческое место, где соединялись линии связи. Мы превратим его в центр коммуникации смыслов.",
                               textAlign: TextAlign.center,
                               style: TextStyle(color: Colors.white54, fontSize: 12),
                             ),
                          ),
                       ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ABOUT SECTION (Glassmorphism)
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ТЕХНОЛОГИИ ПРОРЫВА",
                          style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "1. ДИАГНОСТИКА И КОД",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Система 22 архетипов (ИДП) и функциональные задачи мозга. Переход от описания личности к пониманию движущих сил.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                         const SizedBox(height: 16),
                        const Text(
                          "2. ВНУТРЕННИЕ ОПОРЫ",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Синтез стратегий подсознания и телесный интеллект. Технология «5х5» для движения сквозь страх масштаба.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                         const SizedBox(height: 16),
                        const Text(
                          "3. СИНЕРГИЯ И ВЫХОД В СВЕТ",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Магия перекрестного роста и живые демо-сеты. Единая афиша и круг доверия профессионального сообщества.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // SPEAKERS PREVIEW
                  const Text(
                    "ОРГАНИЗАТОРЫ",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160, // Increased height for descriptions
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSpeakerAvatar("Олег Баранец", "ИДП & Технологии", Colors.blue),
                        _buildSpeakerAvatar("Наталия Баранец", "Психология Масштаба", Colors.pinkAccent),
                        _buildSpeakerAvatar("Info Cards Club", "Сообщество", Colors.amber),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // CALL TO ACTION
                  _buildGlassCard(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Text(
                          "ВЫБИРАЙТЕ ДИАЛОГ С РОСТОМ",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 10,
                              shadowColor: Colors.purple.withOpacity(0.5),
                            ),
                            child: const Text(
                              "КУПИТЬ БИЛЕТ",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Glow and Glass helpers remain same)
  Widget _buildGlowCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(24)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSpeakerAvatar(String name, String role, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 24),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
              boxShadow: [
                 BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
              ]
            ),
            child: Icon(Icons.person, color: color, size: 45),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(role, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
