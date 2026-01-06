import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'games_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // Use AuthService wrapper
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- User Actions ---

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showTopUpDialog(String userId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пополнить баланс'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите вариант пополнения:'),
            const SizedBox(height: 16),
            _buildDepositOption(userId, 'Разовое 500₽ (50 кр.)', 500, 50),
            _buildDepositOption(userId, 'Разовое 1000₽ (100 кр.)', 1000, 100),
            _buildDepositOption(userId, 'Подписка 3000₽/мес (500 кр.)', 3000, 500, isSubscription: true),
            const Divider(),
            _buildDepositOption(userId, 'Запрос бонуса', 0, 0, isBonus: true), // Added Bonus option
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositOption(String userId, String label, int price, int credits, {bool isSubscription = false, bool isBonus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 45),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () {
          Navigator.pop(context);
          _submitRequest(
            type: isBonus ? 'bonus' : (isSubscription ? 'subscription' : 'deposit'),
            text: '$label',
            value: credits,
          );
        },
        child: Text(label),
      ),
    );
  }

  Future<void> _showAskQuestionDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Задать вопрос'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Введите ваш вопрос...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _submitRequest(
                  type: 'question',
                  text: controller.text.trim(),
                );
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest({required String type, String? text, int? value}) async {
    try {
      await _firestoreService.createRequest(type: type, text: text, value: value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка успешно отправлена!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLinkTelegramDialog() async {
    final TextEditingController controller = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Привязка Telegram'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "1. В боте @id_potential_bot зайдите в\nМой кабинет -> Вход в приложение\n"
                  "2. Скопируйте полученный код\n"
                  "3. Вставьте его ниже:",
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                     labelText: "Ключ (Токен)",
                     border: OutlineInputBorder(),
                     hintText: "eyJhbGciOi..."
                  ),
                  maxLines: 3,
                ),
                if (isLoading) const Padding(
                   padding: EdgeInsets.only(top: 10),
                   child: CircularProgressIndicator(),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (controller.text.trim().isEmpty) return;
                  
                  setState(() => isLoading = true);
                  try {
                     await _authService.linkTelegramAccount(controller.text.trim());
                     if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Telegram успешно привязан! Данные скоро появятся.'), backgroundColor: Colors.green),
                        );
                     }
                  } catch (e) {
                     setState(() => isLoading = false);
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Ошибка привязки: $e'), backgroundColor: Colors.red),
                        );
                     }
                  }
                },
                child: const Text('Привязать'),
              ),
            ],
          );
        }
      ),
    );
  }

  bool _isTokenKeyOnly() {
     final user = _auth.currentUser;
     if (user == null) return false;
     // Check if 'password' provider is present
     return !user.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _showLinkEmailDialog() async {
     final emailCtrl = TextEditingController();
     final passCtrl = TextEditingController();
     bool isLoading = false;
     
     await showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
          builder: (context, setStateLocal) => AlertDialog(
             title: const Text("Привязать Email"),
             content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text("Создайте пару Email/Пароль для входа в этот аккаунт без токена.", style: TextStyle(fontSize: 13)),
                   const SizedBox(height: 10),
                   TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                   ),
                   const SizedBox(height: 10),
                   TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: "Пароль (мин. 6 симв.)", border: OutlineInputBorder()),
                      obscureText: true,
                   ),
                   if (isLoading) const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                   )
                ],
             ),
             actions: [
                TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text("Отмена")),
                ElevatedButton(
                   onPressed: isLoading ? null : () async {
                      if (emailCtrl.text.isEmpty || passCtrl.text.length < 6) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Введите корректные данные"), backgroundColor: Colors.orange));
                         return;
                      }
                      setStateLocal(() => isLoading = true);
                      try {
                         await _authService.linkEmailAndPassword(emailCtrl.text.trim(), passCtrl.text.trim());
                         if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email успешно привязан!"), backgroundColor: Colors.green));
                            setState(() {}); // Refresh UI to hide button
                         }
                      } catch (e) {
                         setStateLocal(() => isLoading = false);
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red));
                      }
                   },
                   child: const Text("Привязать"),
                )
             ],
          ),
       )
     );
  }

  // --- Admin Actions ---

  Future<void> _processRequest(String requestId, String userId, String type, int? value) async {
    try {
      await _firestoreService.processRequest(requestId, userId, type, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка обработана'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openTelegram(String? username) async {
    if (username == null || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram username не найден'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Clean username
    final cleanName = username.replaceAll('@', '');
    final uri = Uri.parse('https://t.me/$cleanName');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личный кабинет'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getUserData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!.data();
          if (userData == null) return const Center(child: Text("Пользователь не найден"));

          final credits = userData['credits'] ?? 0;
          final role = userData['role'];
          final pgmd = userData['pgmd'] ?? 1;
          final isAdmin = role == 'admin' || pgmd == 100;
          
          final String statusName;
          if (pgmd == 1) statusName = "Гость (1)";
          else if (pgmd == 2) statusName = "Исследователь (2)";
          else if (pgmd == 3) statusName = "Опытный (3)";
          else if (pgmd == 5) statusName = "Диагност (5)";
          else if (pgmd == 100) statusName = "Администратор";
          else statusName = "Уровень $pgmd";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Stats Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.account_circle, size: 60, color: Colors.blueAccent),
                        const SizedBox(height: 10),
                        Text(
                          userData['first_name'] ?? 'Пользователь',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (userData['username'] != null)
                          Text('@${userData['username']}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem("Баланс", "$credits кр.", Icons.account_balance_wallet),
                            _buildStatItem("Статус", statusName, Icons.stars),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                if (pgmd >= 10)
                   Card(
                      color: (userData['isHostMode'] ?? false) ? Colors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      child: SwitchListTile(
                         title: const Text("Режим Ведущего", style: TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: const Text("Включите, чтобы видеть панель управления игрой"),
                         secondary: Icon(Icons.manage_accounts, color: (userData['isHostMode'] ?? false) ? Colors.purple : Colors.grey),
                         value: userData['isHostMode'] ?? false,
                         onChanged: (val) {
                            _firestoreService.toggleHostMode(val);
                         },
                      ),
                   ),

                const SizedBox(height: 20),
                
                // Actions
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (pgmd != 100) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showTopUpDialog(snapshot.data!.id),
                        icon: const Icon(Icons.add_card),
                        label: const Text('Пополнить баланс'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAskQuestionDialog,
                        icon: const Icon(Icons.help_outline),
                        label: const Text('Задать вопрос'),
                      ),
                    ],
                      if (pgmd < 2)
                        ElevatedButton.icon(
                          onPressed: () => _submitRequest(type: 'upgrade', text: 'Запрос на повышение'),
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Повысить уровень'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                        ),
                      
                      // Show "Link Telegram" only if we are NOT already linked AND (optional: we are not purely a telegram user? No, always allow linking)
                      // Actually, if we are logged in via Token, we ARE the telegram user.
                      // Logic: If I am "Token User" (no password provider), I want to "Link Email".
                      // If I am "Email User", I want to "Link Telegram".
                      
                      if (_isTokenKeyOnly())
                         ElevatedButton.icon(
                           onPressed: _showLinkEmailDialog,
                           icon: const Icon(Icons.email, color: Colors.blue),
                           label: const Text('Привязать Email (Вход по паролю)'),
                           style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue)
                           ),
                         )
                      else if (userData['telegram_id'] == null)
                        ElevatedButton.icon(
                          onPressed: _showLinkTelegramDialog,
                          icon: const Icon(Icons.link, color: Colors.blue),
                          label: const Text('Привязать Telegram'),
                          style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.white, 
                             foregroundColor: Colors.blue,
                             side: const BorderSide(color: Colors.blue)
                          ),
                        ),

                    if (isAdmin || (pgmd >= 10 && (userData['isHostMode'] ?? false)))
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GamesListScreen())),
                        icon: const Icon(Icons.videogame_asset),
                        label: const Text('Игровые сессии'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      ),
                  ],
                ),
                
                if (isAdmin) ...[
                  const Divider(height: 40, thickness: 2),
                  Text(
                    "Панель Администратора", 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  _buildAdminRequestsList(),
                  
                  // --- MIGRATION TOOLS ---
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.orange),
                    title: const Text("Загрузить 'Ситуации 2026'"),
                    subtitle: const Text("Миграция из файла в Firestore"),
                    onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                              title: const Text("Загрузить ситуации?"),
                              content: const Text("Это создаст новый пакет 'Ситуации 2026' в базе данных."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отмена")),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Загрузить"))
                              ],
                          )
                        );

                        if (confirm == true) {
                          // RAW TEXT FROM FILE
                              const rawText = """
Категория: Карьера и работа
1. Ваш удалённый коллега постоянно «исчезает» во время рабочих созвонов, и от этого страдают общие дедлайны.
2. Вам предложили стать ментором для нового сотрудника, но его ценности и подход к работе вам откровенно неприятны.
3. Вы обнаружили, что ваш успешный проект присвоил себе руководитель, упомянув вас лишь в сноске.
4. Начальник публично (в общем чате) раскритиковал вашу идею, предложив взамен заведомо слабый вариант.
5. Вы - единственный специалист в команде, кто умеет работать с критически важным ПО. Вам предлагают надбавку, но только если вы обязуетесь не уходить ближайшие 3 года.
6. Вам нужно уволиться с комфортной, но скучной работы, чтобы полностью погрузиться в рискованный стартап.
7. Вашу ключевую компетенцию вот-вот заменит искусственный интеллект. Нужно срочно решать, как перепрофилироваться.
8. Коллега, с которым вы дружили, после повышения начал вести себя высокомерно и дистанцироваться.
9. Вам нужно провести фидбэк-сессию с сотрудником, который искренне считает свою посредственную работу блестящей.
10. Вам звонят с предложением о фрилансе от компании, которая уволила вас полгода назад «в связи с оптимизацией».
Категория: Отношения и семья
11. Ваш взрослый ребёнок просит переехать обратно к вам после болезненного разрыва отношений.
12. Ваши лучшие друзья разводятся, и каждый из них ждёт, что вы примете его сторону.
13. Вы узнаёте, что ваш партнёр много лет втайне оплачивал учёбу младшему брату/сестре, скрывая это от вас.
14. Ваши родители настаивают на проведении всех праздников по своим традициям, игнорируя желания вашей молодой семьи.
15. После многих лет брака вы понимаете, что у вас и супруга кардинально разные представления о старости и заботе друг о друге.
16. Ваш партнёр решил кардинально сменить образ жизни (стать веганом, уйти в духовные практики, заняться экстремальным спортом) и ждёт вашего безоговорочного присоединения.
17. Ваша давняя дружба дала трещину из-за политических разногласий.
18. Вы влюбились в человека, который живёт в другой стране и не готов переезжать.
19. Родственник просит вас стать «донором» или суррогатным родителем для него и его партнёра.
20. Вы понимаете, что ваш партнёр идеален «на бумаге», но рядом с ним вы не чувствуете себя живым/живой.
Категория: Финансы и ресурсы
21. Вы узнали, что ваш финансовый консультант много лет вкладывал ваши деньги в высокорисковые активы без вашего ведома.
22. После неожиданного наследства у вас испортились отношения с братьями и сёстрами из-за дележа.
23. Вам нужно выбрать: оплатить дорогостоящее лечение питомца или использовать эти деньги для первоначального взноса за жильё.
24. Ваш бизнес начал приносить стабильную прибыль, и перед вами встаёт выбор - масштабироваться с большими рисками или сохранить текущий комфортный размер.
25. Вы подписали общий кредит с партнёром, а теперь расстаётесь.
26. Вам предлагают крупную сумму за продажу персональных данных (истории браузера, медицинские показатели) для «научного исследования».
27. Вы выиграли грант на реализацию мечты, но для этого нужно уволиться с работы.
28. Ваш взрослый ребёнок просит вас взять кредит на его бизнес-идею, которая кажется вам авантюрной.
29. Вы обнаружили ошибку в свою пользу в налоговой декларации. Исправление грозит штрафом и доплатой, неисправление - риском проверки.
30. Вам нужно объяснить престарелым родителям, что их накоплений не хватит на достойную старость, и предложить финансово помочь.
Категория: Личностный рост и экзистенциальные кризисы
31. Вы достигли «потолка» в своём главном увлечении, и оно перестало приносить радость.
32. Вы осознали, что самый близкий круг вашего общения токсичен и тянет вас вниз, но расстаться - значит остаться в одиночестве.
33. Вам поставили диагноз, который требует кардинально изменить образ жизни (питание, активность, стресс).
34. Вы встретили свою школьную учительницу, которая когда-то сказала, что «из вас ничего не выйдет», и теперь вы - успешный человек.
35. Вы понимаете, что для счастья вам нужно научиться просить о помощи, но вся ваша идентичность построена на самодостаточности.
36. Вам предлагают пройти генетический тест, который может показать предрасположенность к тяжёлым заболеваниям.
37. Вы потратили годы на достижение цели, признанной обществом (дом, машина, должность), и осознали её пустоту для себя лично.
38. Вы стали свидетелем чуда (спасения, невероятного совпадения) и это пошатнуло вашу материалистическую картину мира.
39. Вы чувствуете, что «переросли» своего долгосрочного психотерапевта.
40. Вас пригласили выступить с откровенной исповедью о вашем самом тёмном периоде жизни на большой публичной конференции.
Категория: Сложный моральный выбор
41. Вы знаете, что ваш друг изменяет жене. Его супруга - тоже ваш близкий друг.
42. Вы можете спасти компанию от банкротства, уволив невиновного «козла отпущения», взявшего на себя коллективную ошибку.
43. Ваш ребёнок совершил проступок (например, разбил окно), а вину собираются возложить на другого, социально уязвимого подростка.
44. Вы нашли дневник умершего родственника с шокирующими семейными тайнами. Показать его другим членам семьи или уничтожить?
45. Вы - врач. Родственник безнадёжно больного пациента умоляет вас «ускорить исход», чтобы прекратить страдания.
46. Вы выиграли судебный процесс, зная, что закон в данном случае несправедлив к вашему оппоненту.
47. Вы можете раскрыть правду о коррупционной схеме, но это лишит работы сотни невиновных сотрудников компании.
48. Во время военных действий или природного катаклизма у вас есть место в укрытии только для одного из двух ваших детей.
49. Вы узнали, что ваш герой детства, чьими принципами вы руководствовались, на самом деле был мифом, созданным пиарщиками.
50. Вы должны решить, простить ли человека, чьё предательство когда-то спасло вас от большей беды.
Категория: Новые Горизонты и Возможности
51. Вы выиграли годовой оплачиваемый «отпуск» для самореализации.
52. Вам предложили возглавить социально значимый проект с мизерным бюджетом, но огромным потенциалом изменить жизнь многих людей к лучшему.
53. Ваша давняя, казалось бы, утопическая идея неожиданно получила финансирование от инвестора-мечты.
54. Вы случайно (через ошибку в рассылке) узнали уникальный профессиональный секрет, который может совершить прорыв в вашей области.
55. Вам предлагают стать соавтором книги или исследования человека, чьё мнение вы цените выше всего. Но для этого нужно кардинально пересмотреть и опубликовать свои самые сокровенные мысли.
56. Вы обнаружили, что ваше хобби приносит неожиданный доход, достаточный для жизни.
57. Вы можете основать бесплатную школу или спонсорскую-программу в сфере своей экспертизы. 
58. У вас есть возможность организовать идеальное мероприятие (встречу, фестиваль, конференцию), которое объединит всех самых важных людей из разных сфер вашей жизни. 
59. Вам дали право создать новый традиционный праздник или ритуал для своей семьи или сообщества. 
60. Вы осознали, что обладаете уникальным набором навыков, который может помочь решить локальную, но болезненную проблему в вашем городе.
""";
                          await _firestoreService.parseAndUploadSituations2026(rawText);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Пакет загружен!")));
                        }
                    },
                  ),
                ] else ...[
                   // User Q&A History
                  const Divider(height: 40, thickness: 2),
                   Text(
                    "История игр", 
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildGameHistoryList(),
                  const Divider(height: 40, thickness: 2),
                   Text(
                    "История обращений", 
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildUserRequestsList(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildAdminRequestsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
           return const Center(child: Text("Нет новых заявок", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final type = data['type'] ?? 'unknown';
            final text = data['text'] ?? '';
            final value = data['value'];
            final userName = data['userName'] ?? 'Unknown';
            final userContact = data['userContact'];
            final date = (data['createdAt'] as Timestamp?)?.toDate().toString() ?? '';

            Color cardColor = const Color(0xFF1E293B); // Default dark
            Color borderColor = Colors.grey;
            IconData icon = Icons.info;
            
            if (type == 'deposit' || type == 'subscription' || type == 'credits' || type == 'bonus') {
              cardColor = Colors.green.withOpacity(0.1);
              borderColor = Colors.green.withOpacity(0.5);
              icon = Icons.attach_money;
            } else if (type == 'upgrade') {
              cardColor = Colors.orange.withOpacity(0.1);
              borderColor = Colors.orange.withOpacity(0.5);
              icon = Icons.upgrade;
            } else if (type == 'question') {
              cardColor = Colors.blue.withOpacity(0.1);
              borderColor = Colors.blue.withOpacity(0.5);
              icon = Icons.question_answer;
            }

            return Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: borderColor),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon, color: borderColor.withOpacity(1.0)),
                title: Text("$userName ($type)", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty) Text(text),
                    if (value != null && value > 0) Text("Сумма: $value"),
                    Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (userContact != null)
                      IconButton(
                        icon: const Icon(Icons.telegram, color: Colors.blue),
                        onPressed: () => _openTelegram(userContact),
                        tooltip: 'Telegram: $userContact',
                      ),
                    
                    if (type == 'question')
                       IconButton(
                        icon: const Icon(Icons.reply, color: Colors.blueAccent),
                        onPressed: () => _replyToQuestion(doc.id),
                        tooltip: 'Ответить',
                      ),
                      
                    if (type != 'question') 
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _approveRequest(doc.id, data['userId'], type, value),
                        tooltip: 'Одобрить',
                      ),
                      
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => _processRequest(doc.id, data['userId'], 'manual_close', 0),
                      tooltip: 'Отклонить/Закрыть',
                    ),
                    
                    if (type == 'question')
                       IconButton(
                        icon: const Icon(Icons.done_all, color: Colors.grey),
                        onPressed: () => _processRequest(doc.id, data['userId'], 'manual_close', 0),
                        tooltip: 'Закрыть без ответа',
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveRequest(String requestId, String userId, String type, int? initialValue) async {
      int amountToCredit = initialValue ?? 0;
      
      if (type == 'bonus' || type == 'deposit') {
          // ... (existing amount dialog logic) ...
         final controller = TextEditingController(text: amountToCredit > 0 ? amountToCredit.toString() : '');
          final enteredAmount = await showDialog<int>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Подтвердить пополнение ($type)'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Сумма кредитов', suffixText: 'кр.'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                TextButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text);
                    Navigator.pop(context, val);
                  }, 
                  child: const Text('Пополнить')
                ),
              ]
            )
          );
          
          if (enteredAmount == null) return; 
          amountToCredit = enteredAmount;
      }

      await _processRequest(requestId, userId, 'approve_$type', amountToCredit);
  }

  Future<void> _replyToQuestion(String requestId) async {
      final controller = TextEditingController();
      final reply = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ответить пользователю'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Введите ответ...', border: OutlineInputBorder()),
            maxLines: 5,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
             ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                   Navigator.pop(context, controller.text.trim());
                }
              }, 
              child: const Text('Отправить')
            ),
          ]
        )
      );

      if (reply != null && reply.isNotEmpty) {
          try {
             await _firestoreService.answerRequest(requestId, reply);
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ отправлен')));
          } catch(e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
          }
      }
  }

  Widget _buildUserRequestsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getUserRequests(),
      builder: (context, snapshot) {
         if (snapshot.hasError) return const Text('Ошибка загрузки');
         if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
         
         final docs = snapshot.data!.docs;
         if (docs.isEmpty) return const Text('История запросов пуста', style: TextStyle(color: Colors.grey));

         return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
               final data = docs[index].data();
               final question = data['text'] ?? '';
               final answer = data['answer'];
               final status = data['status'];
               final type = data['type'];
               final date = (data['createdAt'] as Timestamp?)?.toDate().toString().split('.')[0] ?? '';

               Color cardColor = const Color(0xFF1E293B); // Dark Blue (Slate 800) by default
               IconData icon = Icons.help_outline;
               
               if (type == 'deposit' || type == 'bonus' || type == 'subscription') {
                   cardColor = Colors.green.withOpacity(0.05);
                   icon = Icons.account_balance_wallet;
               } else if (type == 'upgrade') {
                   cardColor = Colors.orange.withOpacity(0.05);
                   icon = Icons.trending_up;
               }

               return Card(
                 color: cardColor,
                 margin: const EdgeInsets.only(bottom: 8),
                 child: Padding(
                   padding: const EdgeInsets.all(12.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Icon(icon, size: 16, color: Colors.grey),
                           const SizedBox(width: 8),
                           Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold))),
                         ],
                       ),
                       const SizedBox(height: 4),
                       Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                       
                       const Divider(),
                       
                       if (status == 'completed' || status == 'answered') 
                          if (answer != null)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    answer, 
                                    style: TextStyle(
                                      color: (type == 'bonus' || type == 'deposit') ? Colors.greenAccent : Colors.white70
                                    )
                                  )
                                ),
                              ],
                            )
                          else
                             const Row(
                               children: [
                                 Icon(Icons.check_circle, size: 20, color: Colors.green),
                                 SizedBox(width: 4),
                                 Text("Выполнено", style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                               ],
                             )
                       else
                          const Row(
                            children: [
                              Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                              SizedBox(width: 4),
                              Text("Ожидает обработки...", style: TextStyle(color: Colors.orange, fontSize: 12)),
                            ],
                          )
                     ],
                   ),
                 ),
               );
            }
         );
      }
    );
  }

  Widget _buildGameHistoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getGameHistoryStream(),
      builder: (context, snapshot) {
         if (snapshot.hasError) return const Text('Ошибка загрузки');
         if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
         
         final docs = snapshot.data!.docs;
         if (docs.isEmpty) return const Text('У вас пока нет завершенных игр', style: TextStyle(color: Colors.grey));

         return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
               final data = docs[index].data();
               final title = data['gameTitle'] ?? 'Игра';
               final score = data['score'] ?? 0;
               final rank = data['rank'] ?? 0;
               final total = data['totalParticipants'] ?? 0;
               final dateRaw = data['date'] ?? '';
               
               String dateStr = dateRaw;
               if (dateRaw is String && dateRaw.contains('T')) {
                  dateStr = dateRaw.split('T')[0];
               }

               return Card(
                  color: Colors.blueAccent.withOpacity(0.05),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                     leading: CircleAvatar(
                        backgroundColor: rank == 1 ? Colors.orange : Colors.blueGrey,
                        child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     ),
                     title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text(dateStr),
                     trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           Text("$score кр.", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                           Text("Место: $rank/$total", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                     ),
                  ),
               );
            }
         );
      }
    );
  }
}
