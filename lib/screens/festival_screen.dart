
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app.dart';
import 'login_screen.dart';
import '../widgets/festival_application_form.dart';

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
          onPressed: () {
             if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
             } else {
                // Handle Deep Link root case
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppHome()));
                } else {
                   Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
             }
          },
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
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
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
                                  "ФЕСТИВАЛЬ ИГРОПРАКТИК",
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
                                    InkWell(
                                      onTap: () => _showLocationDetails(context),
                                      child: const Text(
                                        "Пространство АТС, Ул.Некрасова, 3-5",
                                        style: TextStyle(
                                          color: Colors.white, 
                                          fontSize: 14, 
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white54
                                        ),
                                      ),
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
                                 "Участие в играх на сумму ~10 000₽ всего за 1 500₽ (входной билет)."
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
                              const SizedBox(height: 16),
                              _buildFeatureRow(
                                 Icons.self_improvement, 
                                 "ЗОНА ТЕЛЕСНЫХ ПРАКТИК", 
                                 "Практики для укрепления физической опоры и управления тревогой."
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
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const FestivalApplicationForm(initialType: 'Посетитель'),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("СТАТЬ УЧАСТНИКОМ", style: TextStyle(fontWeight: FontWeight.bold)),
                                Text("Стоимость билета — 1500 ₽", style: TextStyle(fontSize: 10,  color: Colors.white70)),
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
                              InkWell(onTap: () => _showTariffDetails(context, "Мастер"), child: _buildPricingCard("МАСТЕР", "5 000 ₽", [
                                "Игровой стол",
                                "Представление на сайте",
                                "Включение в расписание",
                              ], Colors.blue)),
                              const SizedBox(width: 16),
                              InkWell(onTap: () => _showTariffDetails(context, "Маэстро"), child: _buildPricingCard("МАЭСТРО", "10 000 ₽", [
                                "Всё, что в Мастер",
                                "Выступление на сцене",
                                "Видеовизитка",
                                "Реклама на 2026 год"
                              ], Colors.purpleAccent, isHighlighted: true)),
                              const SizedBox(width: 16),
                              InkWell(onTap: () => _showTariffDetails(context, "Партнер"), child: _buildPricingCard("ПАРТНЕР", "20 000 ₽", [
                                "Всё, что в Маэстро",
                                "Логотип партнера",
                                "Розыгрыш ваших призов",
                                "Интервью"
                              ], Colors.amber)),
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
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white54),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16)
                                    ),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => const FestivalApplicationForm(initialType: 'Мастер'),
                                    ),
                                    child: const Text("СФОРМИРОВАТЬ ЗАЯВКУ"),
                                  ),
                                ),
                             ],
                           )
                        ),

                        const SizedBox(height: 50),

                        // --- PROGRAM SECTION ---
                        const Text(
                          "ПРОГРАММА",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildProgramSection(),
                        const SizedBox(height: 50),

                        // --- MASTERS SECTION ---
                        const Text(
                          "МАСТЕРА ФЕСТИВАЛЯ",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        _buildMasterCard(
                           context,
                           "Ксения Варакина",
                           "Коуч, психолог, бизнес-тренер",
                           "МАГИЯ ЛИЧНОСТИ",
                           "«Магия личности» — игра, после которой вы определите 1 стратегическое решение, меняющее вашу траекторию.\n\nЭто сочетание коучинговой глубины, психологической точности и игрового формата, который позволяет увидеть свои слепые зоны быстрее, чем за месяцы самокопания.\n\nЧто даёт игра?\nЭто не «ещё одно упражнение». Это формат, в котором:\n➡️ Заметны привычные, но уже неработающие стратегии,\n➡️ Легко найти решение, даже если откладывали его несколько месяцев или лет,\n➡️ За пару шагов можно увидеть то, что сдерживает и не даёт шагнуть вперёд.\n\nПосле игры вы:\n⚡️ Поймёте, какой шаг сделать в ближайшие 72 часа\n⚡️ Уйдёте с 3 чёткими решениями\n⚡️ Получите заряд энергии на конкретные действия\n\nНе просто веду игру, а помогаю увидеть в вас то, что вы давно перестали замечать.",
                           Colors.orangeAccent,
                           "assets/images/ksenia_varakina.jpg",
                           [
                              {'icon': Icons.send, 'url': 'https://t.me/ksvarakina', 'tooltip': 'Написать'},
                              {'icon': Icons.language, 'url': 'https://www.ksvarakina.ru', 'tooltip': 'Сайт'},
                              {'icon': Icons.campaign, 'url': 'https://t.me/varakina_fm', 'tooltip': 'Канал'},
                           ]
                        ),
                        const SizedBox(height: 24),
                        
                        _buildMasterCard(
                           context,
                           "Владимир Папушин",
                           "Предприниматель, игропрактик",
                           "РЫБАКОВ. ИГРА НА МИЛЛИАРД",
                           "«Рыбаков. Игра на миллиард» — Коммуникация, переговоры, стратегия.\n\nУникальный бизнес-тренажер, развивающий навыки предпринимательского мышления и масштабного видения.\n\nНа игре вы прокачаете:\n🎲 Навыки коммуникации и построения партнерств\n🎲 Стратегическое мышление\n🎲 Умение видеть возможности там, где другие видят проблемы\n\nВладимир — серийный предприниматель (20+ лет) и ведущий игропрактик (8+ лет), основатель компании «Pro Cash Flow» и клуба «Время лидеров».",
                           Colors.blue,
                           "assets/images/vladimir_papushin.jpg",
                           [
                              {'icon': Icons.language, 'url': 'https://cashflowpiter.ru/', 'tooltip': 'Сайт'},
                              {'icon': Icons.group, 'url': 'https://vk.com/pro_cashflow_spb', 'tooltip': 'VK'},
                              {'icon': Icons.send, 'url': 'https://t.me/cash_flow_piter', 'tooltip': 'Telegram'},
                              {'icon': Icons.play_circle_fill, 'url': 'http://www.youtube.com/@PRO-Cash-Flow', 'tooltip': 'YouTube'},
                              {'icon': Icons.camera_alt, 'url': 'https://www.instagram.com/vladimir4v', 'tooltip': 'Instagram'},
                           ]
                        ),
                        const SizedBox(height: 24),

                        _buildMasterCard(
                           context,
                           "Олег Баранец",
                           "Психолог, бизнес-аналитик",
                           "ТЕРРИТОРИЯ СЕБЯ",
                           "«Территория Себя» — Авторская трансформационная игра.\n\nИгра, которая помогает превратить хаос в ясную структуру развития. Это инструмент для глубокой диагностики и нахождения скрытых ресурсов личности.\n\nОлег — эксперт по систематизации жизни и бизнеса, основатель Info Cards Club.\n\n«Преобразую хаос в ясность».",
                           Colors.lightBlueAccent,
                           "assets/images/olegbaranets.jpg",
                           [
                              {'icon': Icons.send, 'url': 'https://t.me/id_territory', 'tooltip': 'Канал'},
                              {'icon': Icons.language, 'url': 'https://infocards.club', 'tooltip': 'Сайт'},
                           ]
                        ),
                        const SizedBox(height: 24),

                        _buildMasterCard(
                           context,
                           "Тома Стулова",
                           "Генератор идей, эксперт фототехники",
                           "КОММУНИКАТИВНАЯ ИГРА СО СМЫСЛОМ",
                           "Коммуникативная игра со смыслом. Игры, вечеринки, пикники, творческие мастер-классы, походы, нетворкинги...\n\nТома — генератор идей, оптимист и человек-энергия. Эксперт в области фототехники и фотосъемки. Снимает забавные рилсы. Любит спорт (йога, плавание, велосипед).\n\nПланы: Наполняться энергией и работать с вдохновляющими людьми.",
                           Colors.pinkAccent,
                           "assets/images/toma.jpg",
                           [
                              {'icon': Icons.send, 'url': 'https://t.me/tomastulova', 'tooltip': 'Telegram'},
                              {'icon': Icons.campaign, 'url': 'https://t.me/bla_bla_game', 'tooltip': 'Канал'},
                              {'icon': Icons.camera_alt, 'url': 'https://instagram.com/tomastulova', 'tooltip': 'Instagram'},
                           ]
                        ),
                        const SizedBox(height: 24),

                        _buildMasterCard(
                           context,
                           "Ольга Дорошкевич",
                           "Ресурсный коуч, игропрактик",
                           "ТЕРРИТОРИЯ ДЕНЕГ",
                           "«Территория Денег» — Трансформационная игра.\n\nЭто игра-помощник при переходе на новый денежный уровень. В игре Вы сможете изменить мышление «дефицита» на мышление «изобилия».\n\nИгра помогает:\n📍 Найти причины ограничивающие доход\n📍 Понять какой блок в теме денег\n📍 Выстроить эффективную денежную стратегию\n\nОльга — Ресурсный КОУЧ, автор игр, МАК карт, книги Живые Строки, мастер игровых техник, ченнелер.",
                           Colors.green,
                           "assets/images/olga.jpg",
                           [
                              {'icon': Icons.send, 'url': 'https://t.me/olga_doroshkevich', 'tooltip': 'Telegram'},
                              {'icon': Icons.campaign, 'url': 'https://t.me/OlgaDoroshkevichVselennya', 'tooltip': 'Канал'},
                              {'icon': Icons.play_circle_fill, 'url': 'https://www.youtube.com/@ODoroshkevich', 'tooltip': 'YouTube'},
                           ]
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
                          "Автор игры Территория Себя и платформы для игропрактик. Помогает превратить хаос в ясную структуру развития.",
                          Colors.blue,
                          "assets/images/olegbaranets.jpg",
                          [
                             {'icon': Icons.send, 'url': 'https://t.me/bons_oleg', 'tooltip': 'Написать'},
                             {'icon': Icons.campaign, 'url': 'https://t.me/id_territory', 'tooltip': 'Канал'},
                             {'icon': Icons.language, 'url': 'https://infocards.club/', 'tooltip': 'Сайт'},
                             {'icon': Icons.play_circle_fill, 'url': 'https://www.youtube.com/@infocardsclub', 'tooltip': 'YouTube'},
                          ]
                        ),
                        const SizedBox(height: 16),
                        _buildOrganizerCard(
                          "Наталия Баранец", 
                          "Психотерапевт", 
                          "Эксперт по психологии масштаба. Помогает преодолеть внутренние барьеры и подготовить психику к росту.",
                          Colors.pinkAccent,
                          "assets/images/nataliabaranets.jpg",
                          [
                             {'icon': Icons.send, 'url': 'https://t.me/baranets_info', 'tooltip': 'Написать'},
                             {'icon': Icons.campaign, 'url': 'https://t.me/baranetsinfo', 'tooltip': 'Канал'},
                             {'icon': Icons.language, 'url': 'https://baranets.info/', 'tooltip': 'Сайт'},
                             {'icon': Icons.play_circle_fill, 'url': 'https://www.youtube.com/@baranets_info', 'tooltip': 'YouTube'},
                          ]
                        ),

                        const SizedBox(height: 50),

                        // --- INFO PARTNERS ---
                        const Text(
                          "ИНФОРМАЦИОННЫЕ ПАРТНЕРЫ",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        _buildGlassCard(
                           child: Column(
                             children: [
                                _buildPartnerRow("АТС Некрасова — кластер событий", "https://t.me/ats_nekrasova"),
                                const Divider(color: Colors.white10),
                                _buildPartnerRow("ЛЮБОВЬ И ДЕНЬГИ", "https://t.me/love_borichevskaya"),
                                const Divider(color: Colors.white10),
                                _buildPartnerRow("Тренинги \"PRO CashFlow\"", "https://t.me/cash_flow_piter"),
                                const Divider(color: Colors.white10),
                                _buildPartnerRow("Клуб коммуникативных игр Томы Стуловой", "https://t.me/bla_bla_game"),
                             ],
                           )
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

  Widget _buildMasterCard(BuildContext context, String name, String role, String gameName, String gameDesc, Color color, String imagePath, [List<Map<String, dynamic>>? socialLinks]) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
           Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(imagePath, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.person, color: color, size: 35)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                       Text(role, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.2)),
                       
                       if (socialLinks != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                             spacing: 12,
                             children: socialLinks.map((link) {
                                return InkWell(
                                   onTap: () => launchUrl(Uri.parse(link['url']), mode: LaunchMode.externalApplication),
                                   child: Tooltip(
                                     message: link['tooltip'] ?? '',
                                     child: Icon(link['icon'], color: Colors.white70, size: 20)
                                   ),
                                );
                             }).toList(),
                          )
                       ]
                    ],
                  ),
                )
             ],
           ),
           const SizedBox(height: 20),
           
           // Game Block
           InkWell(
             onTap: () {
                showDialog(
                   context: context,
                   builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Icon(Icons.casino, color: color),
                          const SizedBox(width: 10),
                          Expanded(child: Text(gameName, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      content: SingleChildScrollView(
                         child: Text(gameDesc, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
                      ),
                      actions: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть", style: TextStyle(color: Colors.white54))),
                      ],
                   )
                );
             },
             child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                   color: color.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text("ПРЕДСТАВЛЯЕТ ИГРУ", style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                         children: [
                            Expanded(child: Text(gameName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                            Icon(Icons.info_outline, color: color.withOpacity(0.8)),
                         ],
                      ),
                      const SizedBox(height: 4),
                      const Text("Нажмите, чтобы узнать подробнее", style: TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic)),
                   ],
                ),
             ),
           )
        ],
      )
    );
  }

  Widget _buildOrganizerCard(String name, String role, String desc, Color color, [String? imagePath, List<Map<String, dynamic>>? socialLinks]) {
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
             child: ClipOval(
               child: imagePath != null 
                // Using SizedBox placeholder since asset might not exist yet, 
                // but code supports Image.asset with errorBuilder as per my plan.
                // Assuming Image.asset is fine if we have error handling.
                ? Image.asset(imagePath, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.person, color: color, size: 30))
                : Icon(Icons.person, color: color, size: 30),
             ),
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
                 if (socialLinks != null) ...[
                     const SizedBox(height: 12),
                     Wrap(
                        spacing: 8,
                        children: socialLinks.map((link) {
                           return InkWell(
                              onTap: () => launchUrl(Uri.parse(link['url']), mode: LaunchMode.externalApplication),
                              child: Tooltip(
                                message: link['tooltip'] ?? '',
                                child: Container(
                                   padding: const EdgeInsets.all(6),
                                   decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle
                                   ),
                                   child: Icon(link['icon'], color: Colors.white, size: 18)
                                ),
                              ),
                           );
                        }).toList(),
                     )
                  ]
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

  Widget _buildProgramSection() {
     return _buildGlassCard(
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              _buildProgramItem("12:00", "СЦЕНА", "Открытие фестиваля"),
              const Divider(color: Colors.white10),
              _buildProgramItem("13:00 - 17:00", "СЦЕНА", "Выступление экспертов (программа формируется)"),
              const Divider(color: Colors.white10),
              _buildProgramItem("12:00-18:00", "ИГРОВЫЕ ЗОНЫ", "Трансформационные игры:\n• Территория себя\n• Лила\n• Rybakov\n• Магия личности\n• полный список игр еще формируется"),
              const Divider(color: Colors.white10),
              _buildProgramItem("17:00", "СЦЕНА", "Розыгрыш призов, вручение и закрытие"),
           ],
        )
     );
  }

  Widget _buildProgramItem(String time, String zone, String desc) {
     return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(time, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(zone, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
                       const SizedBox(height: 4),
                       Text(desc, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                 )
              )
           ],
        ),
     );
  }

  Widget _buildPartnerRow(String title, String url) {
     return InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
           padding: const EdgeInsets.symmetric(vertical: 12),
           child: Row(
              children: [
                 const Icon(Icons.telegram, color: Colors.blueAccent, size: 24),
                 const SizedBox(width: 16),
                 Expanded(
                    child: Text(
                       title,
                       style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                 ),
                 const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
           ),
        ),
     );
  }

  void _showLocationDetails(BuildContext context) {
     showDialog(
        context: context,
        builder: (context) => AlertDialog(
           backgroundColor: const Color(0xFF1E293B),
           title: const Text("Пространство АТС", style: TextStyle(color: Colors.white)),
           content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                      "Выбор АТС как площадки символичен: это место, где десятилетиями соединялись линии связи. На один день мы превратим его в центр коммуникации смыслов, технологий и психологии.\n\nИндустриальная архитектура подчеркивает фундаментальность наших методов и готовность к «высоковольтному» масштабу.",
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                   ),
                   const SizedBox(height: 16),
                   InkWell(
                      onTap: () => launchUrl(Uri.parse('https://yandex.ru/profile/-/CLtT6A30'), mode: LaunchMode.externalApplication),
                      child: Row(
                         children: const [
                            Icon(Icons.map, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text("Открыть на карте (Яндекс)", style: TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline)),
                         ],
                      ),
                   )
                ],
              ),
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть"))
           ],
        )
     );
  }

  void _showTariffDetails(BuildContext context, String type) {
     String title = type;
     String content = "";

     // Using text logic from extracted file
     if (type == "Мастер") {
        content = 
           "✅ Представление игры на сайте проекта\n"
           "✅ Включение в официальное расписание\n"
           "✅ Игровой стол в Пространстве АТС\n\n"
           "Почему это эффективно?\n"
           "Вы получаете готовую инфраструктуру и поток клиентов, избавляясь от организационного хаоса.";
     } else if (type == "Маэстро") {
        content = 
           "✅ Всё, что в тарифе Мастер\n"
           "✅ Видеовизитка мастера на сайте\n"
           "✅ Выступление на главной сцене\n"
           "✅ Размещение вашего баннера в зале\n"
           "✅ Анонс ваших событий на весь 2026 год\n"
           "✅ Рекламные публикации в соцсетях\n\n"
           "Почему это эффективно?\n"
           "Вы заявляете о себе как о лидере мнений, используя сцену для подготовки аудитории к вашему масштабу.";
     } else if (type == "Партнер") {
        title = "Партнер Проекта";
        content = 
           "✅ Всё, что в тарифе Маэстро\n"
           "✅ Сохранение вашей афиши на сайте (6 мес.)\n"
           "✅ Съемка персонального видеоинтервью\n"
           "✅ Статус «Партнер проекта» на сайте\n"
           "✅ Печать информации в раздаточных материалах\n"
           "✅ Розыгрыш ваших призов и вручение со сцены\n\n"
           "Почему это эффективно?\n"
           "Вы становитесь частью бренда, закрепляя свое присутствие в инфополе на полгода вперед и создавая доверие через интервью и личный контакт.";
     }

     showDialog(
        context: context,
        builder: (context) => AlertDialog(
           backgroundColor: const Color(0xFF1E293B),
           title: Text(title, style: const TextStyle(color: Colors.white)),
           content: SingleChildScrollView(
              child: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
           ),
           actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                onPressed: () {
                   Navigator.pop(context);
                   showDialog(context: context, builder: (_) => FestivalApplicationForm(initialType: type));
                },
                child: const Text("Заявка на участие"),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть"))
           ],
        )
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
