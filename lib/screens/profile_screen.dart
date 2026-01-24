import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'games_list_screen.dart';
import 'game_details_screen.dart';
import '../widgets/role_info_dialog.dart';
import '../widgets/user_matrix_widget.dart';
import 'festival_applications_screen.dart'; // Import Matrix Widget

import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // Use AuthService wrapper
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  void _replyToQuestion(String requestId, String userId) async {
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
              // 1. Save to Firestore
              await _firestoreService.answerRequest(requestId, reply);
              
              // 2. Fetch User Email and Duplicate to Mail
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
              final email = userDoc.data()?['email'] as String?;
              
              if (email != null && email.isNotEmpty) {
                 final Uri emailLaunchUri = Uri(
                   scheme: 'mailto',
                   path: email,
                   query: _encodeQueryParameters(<String, String>{
                     'subject': 'Ответ на ваш запрос (ID Potential)',
                     'body': 'Здравствуйте!\n\nОтвет администратора:\n"$reply"\n\n--\nС уважением, команда ID Potential.'
                   }),
                 );
                 
                 if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ сохранен и открыт почтовый клиент')));
                 } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ сохранен, но не удалось открыть почту')));
                 }
              } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ сохранен (Email пользователя не найден)')));
              }
 
           } catch(e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
           }
       }
   }

   String? _encodeQueryParameters(Map<String, String> params) {
     return params.entries
         .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
         .join('&');
   }

  void _approveRequest(String requestId, String userId, String type, int? initialValue) async {
       int amountToCredit = initialValue ?? 0;
       
       if (type == 'bonus' || type == 'deposit') {
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
          // ... (status logic) ...
          if (pgmd == 1) statusName = "Гость (1)";
          else if (pgmd == 2) statusName = "Исследователь (2)";
          else if (pgmd == 3) statusName = "Опытный (3)";
          else if (pgmd == 5) statusName = "Диагност (5)";
          else if (pgmd == 100) statusName = "Администратор";
          else statusName = "Уровень $pgmd";

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Stats Card
                // User Stats Card (Compact)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Name and Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData['first_name'] ?? 'Пользователь',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (userData['username'] != null)
                                Text('@${userData['username']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.stars, size: 14, color: Colors.blue[300]),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusName, 
                                    style: TextStyle(fontSize: 13, color: Colors.grey[400])
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Right: Balance
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text(
                               "$credits кр.", 
                               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)
                             ),
                             const SizedBox(height: 4),
                             Text(
                               "Баланс", 
                               style: TextStyle(fontSize: 11, color: Colors.grey[500])
                             ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // My Matrix (Roles) Widget
                FutureBuilder<Map<String, dynamic>?>(
                   future: _firestoreService.getLatestCalculation(), // Fallback to latest calc
                   builder: (context, calcSnapshot) {
                       List<int> numbers = [];
                       final gameProfile = userData['game_profile'] as Map<String, dynamic>?;

                       if (gameProfile != null && gameProfile['numbers'] != null) {
                           numbers = List<int>.from(gameProfile['numbers']);
                       } else if (calcSnapshot.hasData && calcSnapshot.data != null) {
                           numbers = List<int>.from(calcSnapshot.data!['numbers']);
                       }
                       
                       if (numbers.isEmpty) return const SizedBox.shrink();

                       if (numbers.isEmpty) return const SizedBox.shrink();
                       return const SizedBox.shrink(); // Matrix removed by request
                   }
                ),
                
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
                         ),
                      if (userData['telegram_id'] == null)
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
                        label: const Text('Игровые сессии'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      ),
                      
                    if (isAdmin)
                       ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FestivalApplicationsScreen())),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Заявки Фестиваля'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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
                ] else ...[
                   // User Q&A History
                  const Divider(height: 40, thickness: 2),
                   Text(
                    "История обращений", 
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildUserRequestsList(),
                  const Divider(height: 40, thickness: 2),
                   Text(
                    "История игр", 
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildGameHistoryList(),
                ],
                  const SizedBox(height: 20),
                  Center(child: Text("Версия: $_appVersion", style: const TextStyle(color: Colors.grey, fontSize: 10))),
                  const SizedBox(height: 10),
                ],
              ),
            ),
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

            Color cardColor = Colors.white; // Default light
            Color borderColor = Colors.grey;
            IconData icon = Icons.info;
            
            if (type == 'deposit' || type == 'subscription' || type == 'credits' || type == 'bonus') {
              cardColor = Colors.green.shade50;
              borderColor = Colors.green.shade300;
              icon = Icons.attach_money;
            } else if (type == 'upgrade') {
              cardColor = Colors.orange.shade50;
              borderColor = Colors.orange.shade300;
              icon = Icons.upgrade;
            } else if (type == 'question') {
              cardColor = Colors.blue.shade50;
              borderColor = Colors.blue.shade300;
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
                leading: Icon(icon, color: borderColor),
                title: Text("$userName ($type)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty) Text(text, style: const TextStyle(color: Colors.black87)),
                    if (value != null && value > 0) Text("Сумма: $value", style: const TextStyle(color: Colors.black87)),
                    Text(date, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
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
                    
                    IconButton(
                        icon: const Icon(Icons.reply, color: Colors.blueAccent),
                        onPressed: () => _replyToQuestion(doc.id, data['userId']),
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

               Color cardColor = Colors.white; // White by default
               IconData icon = Icons.help_outline;
               
               if (type == 'deposit' || type == 'bonus' || type == 'subscription') {
                   cardColor = Colors.green.shade50;
                   icon = Icons.account_balance_wallet;
               } else if (type == 'upgrade') {
                   cardColor = Colors.orange.shade50;
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
                           Icon(icon, size: 16, color: Colors.grey.shade700),
                           const SizedBox(width: 8),
                           Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                         ],
                       ),
                       const SizedBox(height: 4),
                       Text(date, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                       
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
                                      color: (type == 'bonus' || type == 'deposit') ? Colors.green.shade800 : Colors.black87
                                    )
                                  )
                                ),
                              ],
                            )
                          else
                             Row(
                               children: [
                                 const Icon(Icons.check_circle, size: 20, color: Colors.green),
                                 const SizedBox(width: 4),
                                 Text("Выполнено", style: TextStyle(color: Colors.green.shade700, fontSize: 14)),
                               ],
                             )
                       else
                          Row(
                            children: [
                              const Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text("Ожидает обработки...", style: TextStyle(color: Colors.orange.shade900, fontSize: 12)),
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
                final dateRaw = data['date'] ?? '';
                final isTraining = data['isTraining'] == true;
                
                String dateStr = dateRaw.toString();
                if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
                if (data['date'] is Timestamp) {
                   dateStr = (data['date'] as Timestamp).toDate().toString().split(' ')[0];
                }

                if (isTraining) {
                   final role = data['role'] as int?;
                   final situation = data['situation'] ?? '';
                   
                   return Card(
                      color: Colors.purple.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                         leading: const CircleAvatar(
                            backgroundColor: Colors.purpleAccent,
                            child: Icon(Icons.psychology, color: Colors.white),
                         ),
                         title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text(dateStr),
                         trailing: role != null 
                            ? Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                               child: Text("#$role", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                            : null,
                         onTap: () {
                             // Show simple dialog with situation and role
                             showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                   title: const Text("Тренировка"),
                                   content: SingleChildScrollView(
                                      child: Column(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                            Text(situation, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                                            const SizedBox(height: 20),
                                            const Divider(),
                                            const SizedBox(height: 10),
                                            const Text("Ваш выбор:", style: TextStyle(color: Colors.grey)),
                                            const SizedBox(height: 10),
                                            if (role != null)
                                               GestureDetector(
                                                  onTap: () {
                                                      Navigator.pop(ctx);
                                                      showDialog(context: context, builder: (c) => RoleInfoDialog(roleNumber: role));
                                                  },
                                                  child: Column(
                                                     children: [
                                                        Image.asset('assets/images/cards/role_$role.png', height: 100, errorBuilder: (c,e,s)=>const Icon(Icons.image)),
                                                        const SizedBox(height: 8),
                                                        Text("Роль #$role", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, decoration: TextDecoration.underline))
                                                     ],
                                                  ),
                                               )
                                         ],
                                      ),
                                   ),
                                   actions: [
                                      TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Закрыть"))
                                   ],
                                )
                             );
                         },
                      ),
                   );
                }

                final score = data['score'] ?? 0;
                final rank = data['rank'] ?? 0;
                final total = data['totalParticipants'] ?? 0;

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
                      onTap: () {
                         Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => GameDetailsScreen(
                               gameId: docs[index].id,
                               gameTitle: title,
                               totalScore: score,
                               rank: rank,
                            ))
                         );
                      },
                   ),
                );
             }
         );
      }
    );
  }
}
