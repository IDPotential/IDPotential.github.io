
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app.dart';
import 'login_screen.dart';
import '../widgets/festival_application_form.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import '../widgets/festival_game_card.dart';
import '../widgets/game_editor_dialog.dart';

import '../widgets/game_manager_dialog.dart';
import '../widgets/ticket_link_dialog.dart';
import '../widgets/profile_settings_dialog.dart';
import '../data/festival_content.dart';
import '../widgets/participant_list_dialog.dart';


class FestivalScreen extends StatefulWidget {
  final String? initialTab;
  const FestivalScreen({super.key, this.initialTab});

  @override
  State<FestivalScreen> createState() => _FestivalScreenState();
}

class _FestivalScreenState extends State<FestivalScreen> {
  final GlobalKey _visitorsKey = GlobalKey();
  final GlobalKey _expertsKey = GlobalKey();
  final GlobalKey _programKey = GlobalKey();
  final GlobalKey _mastersKey = GlobalKey();
  final GlobalKey _organizersKey = GlobalKey();
  final GlobalKey _partnersKey = GlobalKey();
  
  int _currentIndex = 0;
  String? _userRole;
  String? _userId;
   String? _firstName;
   String? _phoneNumber;
   String? _ticketNumber;
   bool _isLoadingProfile = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    if (widget.initialTab == 'schedule') {
      _currentIndex = 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            final data = doc.data();
            _userRole = data?['role'];
            _firstName = data?['first_name'];
            _phoneNumber = data?['phoneNumber'];
            _ticketNumber = data?['ticketLogin'] ?? data?['ticket'];
          });
        }
      } catch (e) {
         debugPrint("Error fetching profile: $e");
      } finally {
         if (mounted) setState(() => _isLoadingProfile = false);
      }
    } else {
       if(mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _onMenuSelected(dynamic value) {
    if (value is int) {
      setState(() {
        _currentIndex = value;
      });
    } else if (value is GlobalKey) {
       setState(() {
          _currentIndex = 0; // Ensure we are on the landing page
       });
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (value.currentContext != null) {
            Scrollable.ensureVisible(
              value.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              alignment: 0.1,
            );
         }
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F044C), // Fallback color
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
             if (_currentIndex != 0) {
                setState(() => _currentIndex = 0);
             } else if (Navigator.of(context).canPop()) {
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
        actions: [
          if (_userId == null)
            TextButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(isTicketMode: true))),
              child: const Text("Войти", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.link, color: Colors.amberAccent),
              tooltip: "Привязать билет",
              onPressed: _showTicketLinkDialog,
            ),
          IconButton(
             icon: const Icon(Icons.account_circle, color: Colors.white),
             tooltip: "Профиль",
             onPressed: _showProfileSettings,
          ),
          PopupMenuButton<dynamic>(
            icon: const Icon(Icons.menu, color: Colors.white),
            color: const Color(0xFF1E293B),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text("Информация", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 1, child: Text("Расписание", style: TextStyle(color: Colors.white))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: null, enabled: false, child: Text("НАВИГАЦИЯ", style: TextStyle(color: Colors.white54, fontSize: 12))),
              PopupMenuItem(value: _visitorsKey, child: const Text("Посетителям", style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: _expertsKey, child: const Text("Экспертам", style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: _programKey, child: const Text("Программа", style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: _mastersKey, child: const Text("Мастера", style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: _organizersKey, child: const Text("Организаторы", style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: _partnersKey, child: const Text("Партнеры", style: TextStyle(color: Colors.white))),
            ],
          ),
          const SizedBox(width: 16),
        ],
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
            child: IndexedStack(
              index: _currentIndex,
              children: [
                SingleChildScrollView(
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
                        Text(
                          "ДЛЯ ПОСЕТИТЕЛЕЙ",
                          key: _visitorsKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                                builder: (_) => Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 800),
                                    child: const FestivalApplicationForm(initialType: 'Посетитель')
                                  )
                                ),
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
                        Text(
                          "ДЛЯ ЭКСПЕРТОВ",
                          key: _expertsKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                                      builder: (_) => Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 800),
                                          child: const FestivalApplicationForm(initialType: 'Мастер')
                                        )
                                      ),
                                    ),
                                    child: const Text("СФОРМИРОВАТЬ ЗАЯВКУ"),
                                  ),
                                ),
                             ],
                           )
                        ),

                        const SizedBox(height: 50),

                        // --- PROGRAM SECTION ---
                        Text(
                          "ПРОГРАММА",
                          key: _programKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildProgramSection(),
                        const SizedBox(height: 50),

                        // --- MASTERS SECTION ---
                        Text(
                          "МАСТЕРА ФЕСТИВАЛЯ",
                          key: _mastersKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        ...festivalContent.values.map((content) {
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 24),
                             child: _buildMasterCard(
                               context,
                               content.masterName,
                               content.role,
                               content.title,
                               content.description,
                               content.color,
                               content.imagePath,
                               content.links,
                               content.secondaryImagePath
                             ),
                           );
                        }),

                        // --- ORGANIZERS ---
                        Text(
                          "ОРГАНИЗАТОРЫ",
                          key: _organizersKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                        Text(
                          "ИНФОРМАЦИОННЫЕ ПАРТНЕРЫ",
                          key: _partnersKey,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
            _buildSchedule(),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedule() {
     // 1. Strict Gate: Only Admin or Deep Link Access allowed
     // Everyone else sees "Schedule Forming"
     bool canAccess = _userRole == 'admin' || (widget.initialTab == 'schedule');
     
     if (!canAccess) {
        return _buildSchedulePlaceholder();
     }

     // 2. Auth Check for those who CAN access
     if (_isLoadingProfile) {
        return const Center(child: CircularProgressIndicator());
     }
     
     if (_userId == null) {
        return Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text("Войти для просмотра расписания"),
          )
        );
     }

     // 3. Profile Check for Regular Users (Admins bypass)
     if (_userRole != 'admin' && _userRole != 'master') {
        if ((_firstName?.isEmpty ?? true) || (_phoneNumber?.isEmpty ?? true)) {
            return _buildProfileForm();
        }
     }
     
     return _buildScheduleContent();
  }

  Widget _buildSchedulePlaceholder() {
      return SizedBox.expand(
        child: Container(
          color: Colors.black54,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Расписание игр формируется.\n19 февраля в 18 часов откроется предзапись на игры.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildProfileForm() {
     return SizedBox.expand(
       child: Container(
         color: Colors.black87,
         padding: const EdgeInsets.all(24),
         child: Center(
           child: SingleChildScrollView(
             child: Form(
               key: _formKey,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const Text("Заполните профиль", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text("Для доступа к расписанию и быстрой записи необходимы ваши данные.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    TextFormField(
                       controller: _nameController,
                       decoration: const InputDecoration(labelText: "Имя Фамилия"),
                       style: const TextStyle(color: Colors.white),
                       validator: (v) => v?.isEmpty ?? true ? "Введите имя" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                       controller: _phoneController,
                       decoration: const InputDecoration(labelText: "Телефон"),
                       style: const TextStyle(color: Colors.white),
                       validator: (v) => v?.isEmpty ?? true ? "Введите телефон" : null,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                       value: _consent,
                       onChanged: (v) => setState(() => _consent = v ?? false),
                       title: const Text("Согласен на обработку персональных данных", style: TextStyle(color: Colors.white70, fontSize: 12)),
                       checkColor: Colors.black,
                       activeColor: Colors.white,
                       contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                       onPressed: _submitProfile,
                       child: const Text("Сохранить и перейти к расписанию"),
                    )
                 ],
               ),
             ),
           ),
         ),
       ),
     );
  }

  Future<void> _submitProfile() async {
     if (_formKey.currentState!.validate() && _consent) {
        await FirestoreService().updateUserProfile(_userId!, firstName: _nameController.text, phoneNumber: _phoneController.text);
        await _fetchUserData(); 
     } else if (!_consent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Необходимо согласие")));
     }
  }

  Widget _buildScheduleContent() {
    return StreamBuilder<List<FestivalGame>>(
      stream: FirestoreService().getFestivalGamesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final games = snapshot.data!;
        games.sort((a, b) => a.startTime.compareTo(b.startTime));
        
        final slot1 = games.where((g) => g.slotId == 1).toList();
        final slot2 = games.where((g) => g.slotId == 2).toList();
        final slot3 = games.where((g) => g.slotId == 3).toList();
        final other = games.where((g) => g.slotId == null || g.slotId == 0).toList();

        return SizedBox.expand(
          child: Container(
            color: const Color(0xFF0F044C), // Deep Blue Background
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                     // --- GREETING BLOCK (Scrollable now) ---
                     Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           if (_firstName != null)
                              Text("$_firstName, рады видеть тебя на фестивале!", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           const Text("Можешь записаться на сеты игр или выбрать случайное распределение.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                           const SizedBox(height: 12),
                           Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                 const Text("Расписание игр", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                 if (_userRole == 'admin' || _userRole == 'master')
                                     IconButton(
                                       onPressed: _showCreateGameDialog,
                                       icon: const Icon(Icons.add, color: Colors.amberAccent),
                                       tooltip: "Создать игру",
                                     ),
                              ],
                           ),
                           const SizedBox(height: 8),
                           SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                 onPressed: _trustTheFlow,
                                 icon: const Icon(Icons.auto_awesome),
                                 label: const Text("Довериться потоку"),
                                 style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.purpleAccent,
                                     foregroundColor: Colors.white,
                                 ),
                              ),
                           ),
                           const SizedBox(height: 20),
                        ],
                     ),

                     // --- SLOTS ---
                     if (slot1.isNotEmpty) _buildSlotSection("12:45 — 14:15 | Первый Сет", slot1),
                     if (slot2.isNotEmpty) _buildSlotSection("14:45 — 16:15 | Второй Сет", slot2),
                     if (slot3.isNotEmpty) _buildSlotSection("16:30 — 18:00 | Третий Сет", slot3),
                     if (other.isNotEmpty) _buildSlotSection("Другие игры", other),
                     const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotSection(String title, List<FestivalGame> games) {
     return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                 child: Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
           ),
           GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: 2,
                 childAspectRatio: 1.0,
                 crossAxisSpacing: 10,
                 mainAxisSpacing: 10,
              ),
              itemCount: games.length,
              itemBuilder: (ctx, index) {
                 final g = games[index];
                 final isRegistered = g.isUserRegistered(_userId ?? '', _ticketNumber);
                 final isMyGame = g.hasMasterAccess(_userId, _ticketNumber);
                 
                 return FestivalGameCard(
                   game: g,
                   isRegistered: isRegistered,
                   isMaster: isMyGame,
                   onRegister: () => _handleGameAction(g, isRegistered),
                   onManage: (_userRole == 'admin' || isMyGame) ? () => _showManageGameDialog(g) : null,
                   onShowParticipants: isMyGame ? () => showDialog(context: context, builder: (_) => ParticipantListDialog(game: g)) : null,
                 );
              }
           ),
           const SizedBox(height: 24),
        ],
     );
  }


  void _trustTheFlow() async {
     if (_ticketNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text("Для записи на игру необходим билет. Приобретите билет или привяжите его в настройках."),
           backgroundColor: Colors.orange,
           duration: Duration(seconds: 4),
        ));
        return;
     }

     final allGames = await FirestoreService().getFestivalGamesOnce();
     final slot1 = allGames.where((g) => g.slotId == 1 && g.placesLeft > 0).toList();
     final slot2 = allGames.where((g) => g.slotId == 2 && g.placesLeft > 0).toList();
     final slot3 = allGames.where((g) => g.slotId == 3 && g.placesLeft > 0).toList();
     
     if (slot1.isEmpty && slot2.isEmpty && slot3.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Нет доступных игр для случайного выбора")));
        return;
     }

     final rng = DateTime.now().millisecondsSinceEpoch;
     final s1 = slot1.isNotEmpty ? slot1[rng % slot1.length] : null;
     final s2 = slot2.isNotEmpty ? slot2[(rng + 1) % slot2.length] : null;
     final s3 = slot3.isNotEmpty ? slot3[(rng + 2) % slot3.length] : null;
     
     if (!mounted) return;

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Твой Путь Фестиваля", style: TextStyle(color: Colors.white)),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                if (s1 != null) Text("12:45: ${s1.title}", style: const TextStyle(color: Colors.white)),
                if (s2 != null) Text("14:45: ${s2.title}", style: const TextStyle(color: Colors.white)),
                if (s3 != null) Text("16:30: ${s3.title}", style: const TextStyle(color: Colors.white)),
                if (s1 == null && s2 == null && s3 == null) const Text("К сожалению, все места заняты.", style: TextStyle(color: Colors.white54)),
             ],
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
             if (s1 != null || s2 != null || s3 != null)
                ElevatedButton(
                   onPressed: () async {
                      Navigator.pop(ctx);
                      final name = _firstName ?? 'Участник';
                      final contact = _phoneNumber ?? 'Не указан';
                      
                      try {
                        if (s1 != null) await FirestoreService().joinFestivalGame(game: s1, userName: name, contact: contact, ticket: _ticketNumber);
                        if (s2 != null) await FirestoreService().joinFestivalGame(game: s2, userName: name, contact: contact, ticket: _ticketNumber);
                        if (s3 != null) await FirestoreService().joinFestivalGame(game: s3, userName: name, contact: contact, ticket: _ticketNumber);
                        
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Вы записаны на выбранные игры!")));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
                      }
                   },
                   child: const Text("Записаться на всё"),
                )
          ],
       )
     );
  }

  Future<void> _handleGameAction(FestivalGame game, bool isRegistered) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Сначала войдите в систему")));
    return;
  }

  // Requirement: Must have a ticket to register
  if ((_ticketNumber == null || _ticketNumber!.isEmpty) && !isRegistered) { // Allow cancel even if ticket is missing? Maybe not.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text("Для записи на игру необходим билет. Приобретите билет или привяжите его в настройках."),
         backgroundColor: Colors.orange,
         duration: Duration(seconds: 4),
      ));
      return;
  }

  if (isRegistered) {
       // Cancel Flow
       final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF1E293B),
             title: const Text("Отмена записи", style: TextStyle(color: Colors.white)),
             content: Text("Вы действительно хотите отменить запись на игру '${game.title}'?", style: const TextStyle(color: Colors.white70)),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Нет")),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                   onPressed: () => Navigator.pop(ctx, true),
                   child: const Text("Отменить запись"),
                )
             ],
          )
       );
       
       if (confirm == true) {
          try {
             await FirestoreService().cancelFestivalRegistration(game, _ticketNumber);
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Запись отменена")));
          } catch (e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка отмены: $e")));
          }
       }

    } else {
       // Register Flow
       try {
         // Using new method with logging
         await FirestoreService().joinFestivalGame(
          game: game,
          userName: _firstName ?? 'Участник',
          contact: _phoneNumber ?? 'Не указан',
          ticket: _ticketNumber
       );
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Вы записаны на игру '${game.title}'!")));
       } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка записи: ${e.toString().replaceAll('Exception: ', '')}")));
       }
    }
  }

  void _showCreateGameDialog() {
     showDialog(context: context, builder: (_) => const GameEditorDialog());
  }
  
  void _showManageGameDialog(FestivalGame game) {
     showDialog(context: context, builder: (_) => GameManagerDialog(game: game));
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

  Widget _buildMasterCard(BuildContext context, String name, String role, String gameName, String gameDesc, Color color, String imagePath, [List<Map<String, dynamic>>? socialLinks, String? gameImagePath]) {
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
                   builder: (_) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: AlertDialog(
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
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              if (gameImagePath != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(gameImagePath, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Text(gameDesc, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
                           ],
                         ),
                      ),
                      actions: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть", style: TextStyle(color: Colors.white54))),
                      ],
                   )
                  )
                ));
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
        color: color.withOpacity(0.0), // Transparent center to let shadow fail gracefully if needed
        boxShadow: [
           BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 100, // High blur for glow effect
              spreadRadius: 20,
           )
        ],
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
              _buildProgramItem("12:00-18:00", "ИГРОВЫЕ ЗОНЫ", "Трансформационные игры:\n• Территория себя\n• Территория денег\n• Очередь из Денег\n• Путь Желаний\n• Лила\n• Rybakov\n• Магия личности\n• Арт-терапевтическая практика\n• Кагомэ-Кагомэ (трансформация)\n• Недостатки vs SuperСпособности"),
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
        builder: (context) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: AlertDialog(
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
            ),
          ),
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
        builder: (context) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: AlertDialog(
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
                       showDialog(
                          context: context,
                          builder: (_) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: FestivalApplicationForm(initialType: type)
                            )
                          )
                       );
                    },
                    child: const Text("Заявка на участие"),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть"))
               ],
            ),
          ),
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

  void _showTicketLinkDialog() {
    showDialog(
      context: context,
      builder: (context) => const TicketLinkDialog(),
    );
  }

  void _showProfileSettings() {
    showDialog(
      context: context,
      builder: (context) => const ProfileSettingsDialog(),
    );
  }
}
