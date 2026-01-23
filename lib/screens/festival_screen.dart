
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
                   // --- HERO SECTION ---
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "21 ФЕВРАЛЯ 2026 • 12:00 – 18:00",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 2,
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
                             padding: EdgeInsets.symmetric(horizontal: 16),
                             child: Text(
                               "Историческое место, где соединялись линии связи. Мы превратим его в центр коммуникации смыслов.",
                               textAlign: TextAlign.center,
                               style: TextStyle(color: Colors.white54, fontSize: 12),
                             ),
                          ),
                       ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  // --- VISITOR SECTION ---
                  const Text(
                    "ДЛЯ ПОСЕТИТЕЛЕЙ",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFeatureRow(
                           Icons.verified, 
                           "ВЫГОДА", 
                           "Участие в играх на сумму ~10 000₽ всего за 1 000₽ (входной билет)."
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                           Icons.timer, 
                           "МАРАФОН ИГР", 
                           "Пройдите до 5 различных трансформационных игр за один день (6 часов)."
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureRow(
                           Icons.mic, 
                           "СЦЕНА СМЫСЛОВ", 
                           "Выступления авторов методик. Найдите «своего» эксперта."
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  // VISITOR CTA
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("СТАТЬ УЧАСТНИКОМ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Стоимость билета — 1000 ₽", style: TextStyle(fontSize: 10,  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // --- PARTNER SECTION ---
                  const Text(
                    "ДЛЯ ЭКСПЕРТОВ",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Масштабируйте свою практику. Выберите свой тариф:",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  // PRICING CARDS
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildPricingCard("МАСТЕР", "5 000 ₽", [
                          "Игровой стол",
                          "Представление на сайте",
                          "Включение в расписание",
                        ], Colors.blue),
                        const SizedBox(width: 16),
                        _buildPricingCard("МАЭСТРО", "10 000 ₽", [
                          "Всё, что в Мастер",
                          "Выступление на сцене",
                          "Видеовизитка",
                          "Реклама на 2026 год"
                        ], Colors.purpleAccent, isHighlighted: true),
                        const SizedBox(width: 16),
                        _buildPricingCard("ПАРТНЕР", "20 000 ₽", [
                          "Всё, что в Маэстро",
                          "Логотип партнера",
                          "Розыгрыш ваших призов",
                          "Интервью"
                        ], Colors.amber),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // PARTNER CTA
                  _buildGlassCard(
                     padding: const EdgeInsets.all(20),
                     child: Column(
                       children: [
                          const Text("Подать заявку как Мастер", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                           SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16)
                              ),
                              child: const Text("СФОРМИРОВАТЬ ЗАЯВКУ"),
                            ),
                          ),
                       ],
                     )
                  ),

                  const SizedBox(height: 50),

                  // --- ORGANIZERS ---
                  const Text(
                    "ОРГАНИЗАТОРЫ",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildOrganizerCard(
                    "Олег Баранец", 
                    "Психолог, бизнес-аналитик", 
                    "Автор системы «ИДП» (22 архетипа). Помогает превратить хаос в ясную структуру развития.",
                    Colors.blue
                  ),
                  const SizedBox(height: 16),
                  _buildOrganizerCard(
                    "Наталия Баранец", 
                    "Психотерапевт", 
                    "Эксперт по психологии масштаба. Помогает преодолеть внутренние барьеры и подготовить психику к росту.",
                    Colors.pinkAccent
                  ),

                  const SizedBox(height: 60),

                  Center(
                    child: Text(
                      "Санкт-Петербург • 21 Февраля",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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

  // --- HELPERS ---

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amberAccent, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPricingCard(String title, String price, List<String> features, Color color, {bool isHighlighted = false}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHighlighted ? color : Colors.white10, width: isHighlighted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 const Icon(Icons.check, color: Colors.white54, size: 14),
                 const SizedBox(width: 8),
                 Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 11))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildOrganizerCard(String name, String role, String desc, Color color) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             width: 60,
             height: 60,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: color.withOpacity(0.2),
               border: Border.all(color: color),
             ),
             child: Icon(Icons.person, color: color, size: 30),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                 Text(role, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                 const SizedBox(height: 8),
                 Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
               ],
             ),
           )
        ],
      ),
    );
  }

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
}
