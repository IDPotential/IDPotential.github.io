import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'games_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
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
                    if (pgmd < 2)
                      ElevatedButton.icon(
                        onPressed: () => _submitRequest(type: 'upgrade', text: 'Запрос на повышение'),
                        icon: const Icon(Icons.trending_up),
                        label: const Text('Повысить уровень'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
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

      await _processRequest(requestId, userId, type, amountToCredit);
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
