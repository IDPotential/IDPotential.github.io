import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';

class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      if (data['role'] == 'admin' || data['pgmd'] == 100) {
        if (mounted) setState(() => _isAdmin = true);
      }
    }
  }

  void _showGameDialog({String? docId, String? currentTitle, DateTime? currentDate, String? currentZoomId, String? currentZoomPassword}) {
    final titleController = TextEditingController(text: currentTitle);
    final zoomIdController = TextEditingController(text: currentZoomId);
    final zoomPasswordController = TextEditingController(text: currentZoomPassword);
    DateTime selectedDate = currentDate ?? DateTime.now();
    bool isEditing = docId != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Редактировать игру' : 'Создать игру'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название игры'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      "Дата и время: ${DateFormat('dd.MM.yyyy HH:mm').format(selectedDate)}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('ru', 'RU'),
                    );
                    
                    if (pickedDate != null && context.mounted) {
                       final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                       );

                       if (pickedTime != null) {
                          setStateDialog(() {
                            selectedDate = DateTime(
                               pickedDate.year, 
                               pickedDate.month, 
                               pickedDate.day, 
                               pickedTime.hour, 
                               pickedTime.minute
                            );
                          });
                       }
                    }
                  },
                ),
                TextField(
                  controller: zoomIdController,
                  decoration: const InputDecoration(labelText: 'Zoom Meeting ID'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: zoomPasswordController,
                  decoration: const InputDecoration(labelText: 'Zoom Password'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    try {
                      if (isEditing) {
                        await _firestoreService.updateGame(
                          docId!,
                          title: titleController.text,
                          date: selectedDate,
                          zoomId: zoomIdController.text,
                          zoomPassword: zoomPasswordController.text,
                        );
                      } else {
                        await _firestoreService.createGame(
                          title: titleController.text,
                          date: selectedDate,
                          zoomId: zoomIdController.text,
                          zoomPassword: zoomPasswordController.text,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                    }
                  }
                },
                child: Text(isEditing ? 'Сохранить' : 'Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteGame(String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить игру?"),
        content: Text("Вы уверены, что хотите удалить игру \"$title\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             onPressed: () => Navigator.pop(context, true), 
             child: const Text("Удалить")
          ),
        ],
      ),
    );

    if (confirm == true) {
       await _firestoreService.deleteGame(docId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Игровые сессии')),
      floatingActionButton: _isAdmin ? FloatingActionButton(
        onPressed: () => _showGameDialog(),
        child: const Icon(Icons.add),
      ) : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getGamesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final games = snapshot.data!.docs;

          if (games.isEmpty) {
            return const Center(child: Text("Нет активных игр."));
          }
          
          // Client-side sorting because we removed Firestore orderBy to avoid index issues
          games.sort((a, b) {
             final dA = a.data()['scheduledAt'] ?? '';
             final dB = b.data()['scheduledAt'] ?? '';
             // Compare strings directly works checking ISO8601, but parsing is safer
             DateTime? dateA, dateB;
             try { dateA = DateTime.parse(dA); } catch (_) {}
             try { dateB = DateTime.parse(dB); } catch (_) {}
             
             if (dateA == null && dateB == null) return 0;
             if (dateA == null) return 1;
             if (dateB == null) return -1;
             return dateA.compareTo(dateB);
          });
          
          // Filter out very old games (older than 24h) to avoid clutter
          // games.removeWhere((g) => ...); // Optional, maybe safe to keep them visible but at top/bottom

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index].data();
              final docId = games[index].id;
              final dateStr = game['scheduledAt'] ?? '';
              DateTime? date;
              try { date = DateTime.parse(dateStr); } catch (_) {}
              
              final displayDate = date != null 
                  ? DateFormat('dd.MM.yyyy').format(date)
                  : "Дата не указана";
              
              final isFinished = date != null && date.isBefore(DateTime.now().subtract(const Duration(hours: 4))); // Crude finish check

              return Card(
                color: isFinished ? Colors.white10 : null,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(game['title'] ?? 'Без названия', style: TextStyle(color: isFinished ? Colors.grey : Colors.white)),
                  subtitle: Text(displayDate, style: TextStyle(color: isFinished ? Colors.grey : Colors.white70)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       if (_isAdmin)
                          PopupMenuButton(
                             icon: const Icon(Icons.more_vert),
                             onSelected: (value) {
                                if (value == 'edit') {
                                   _showGameDialog(
                                      docId: docId, 
                                      currentTitle: game['title'], 
                                      currentDate: date,
                                      currentZoomId: game['zoomId'],
                                      currentZoomPassword: game['zoomPassword']
                                   );
                                } else if (value == 'delete') {
                                   _deleteGame(docId, game['title'] ?? '');
                                }
                             },
                             itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Изменить")),
                                const PopupMenuItem(value: 'delete', child: Text("Удалить", style: TextStyle(color: Colors.red))),
                             ],
                          ),
                       const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GameScreen(gameId: docId)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
