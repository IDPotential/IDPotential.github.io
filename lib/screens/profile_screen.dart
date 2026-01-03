import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

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

  Widget _buildDepositOption(String userId, String label, int price, int credits, {bool isSubscription = false}) {
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
            type: isSubscription ? 'subscription' : 'deposit',
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
                  ],
                ),
                
                // Admin Panel Section
                if (isAdmin) ...[
                  const Divider(height: 40, thickness: 2),
                  Text(
                    "Панель Администратора", 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  _buildAdminRequestsList(),
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

            Color cardColor = Colors.white;
            IconData icon = Icons.info;
            
            if (type == 'deposit' || type == 'subscription' || type == 'credits') {
              cardColor = Colors.green.shade50;
              icon = Icons.attach_money;
            } else if (type == 'upgrade') {
              cardColor = Colors.orange.shade50;
              icon = Icons.upgrade;
            } else if (type == 'question') {
              cardColor = Colors.blue.shade50;
              icon = Icons.question_answer;
            }

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon),
                title: Text("$userName ($type)"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty) Text(text),
                    if (value != null) Text("Значение: $value"),
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
                    
                    if (type != 'question') // Questions need manual answer, or just mark done
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _processRequest(doc.id, data['userId'], type, value),
                        tooltip: 'Одобрить',
                      ),
                      
                    IconButton(
                      icon: const Icon(Icons.done, color: Colors.grey),
                      onPressed: () => _processRequest(doc.id, data['userId'], 'manual_close', 0),
                      tooltip: 'Отметить как готово',
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
}
