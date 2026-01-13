import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';
import 'game_report_screen.dart';

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

  void _showGameDialog({
    String? docId, 
    String? currentTitle, 
    DateTime? currentDate, 
    String? currentZoomId, 
    String? currentZoomPassword, 
    String? currentPackId, 
    List<String>? currentCategories, 
    bool? currentIsTestGame,
    String? currentGameType // territory, money_queue, mafia
  }) {
    final titleController = TextEditingController(text: currentTitle);
    final zoomIdController = TextEditingController(text: currentZoomId);
    final zoomPasswordController = TextEditingController(text: currentZoomPassword);
    DateTime selectedDate = currentDate ?? DateTime.now();
    
    // Situation Selection State
    String? selectedPackId = currentPackId;
    List<String> selectedCategories = currentCategories ?? [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> availablePacks = [];
    List<String> availableCategories = []; // Categories for the selected pack
    
    bool isTestGame = currentIsTestGame ?? false;
    bool isEditing = docId != null;
    String selectedGameType = currentGameType ?? 'territory';
    
    final Map<String, String> gameTypes = {
       'territory': 'Территория Себя',
       'money_queue': 'Очередь из Денег',
       'mafia': 'Мафия'
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          
          // LOAD PACKS (Once)
          if (availablePacks.isEmpty) {
             _firestoreService.getSituationPacks().then((packs) {
                if (context.mounted && packs.isNotEmpty) {
                   setStateDialog(() {
                      availablePacks = packs;
                      // Default to first pack if none selected
                      if (selectedPackId == null) {
                         selectedPackId = packs.first.id;
                      }
                      
                      // Find categories for selected pack
                      final packData = packs.firstWhere((p) => p.id == selectedPackId).data();
                      final sits = (packData['situations'] as List<dynamic>? ?? []);
                      final cats = sits.map((s) => s['category'] as String? ?? "General").toSet().toList();
                      cats.sort();
                      availableCategories = cats;
                   });
                }
             });
          }

          return AlertDialog(
            title: Text(isEditing ? 'Редактировать игру' : 'Создать игру'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GAME TYPE DROPDOWN
                  DropdownButtonFormField<String>(
                     value: selectedGameType,
                     decoration: const InputDecoration(labelText: 'Тип игры'),
                     dropdownColor: const Color(0xFF1E293B),
                     style: const TextStyle(color: Colors.white),
                     items: gameTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                     onChanged: (val) {
                        if (val != null) setStateDialog(() => selectedGameType = val);
                     },
                  ),
                  const SizedBox(height: 16),

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
                  CheckboxListTile(
                    title: const Text("Тестовая игра (только для тестеров)"),
                    value: isTestGame,
                    onChanged: (val) => setStateDialog(() => isTestGame = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (selectedGameType == 'territory') ...[ // Only show for Territory
                       const Divider(),
                       const Text("Ситуации", style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),

                       if (availablePacks.isEmpty)
                         const Text("Загрузка пакетов... (или нет доступных)", style: TextStyle(fontSize: 12, color: Colors.grey))
                       else ...[
                           DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                 labelText: 'Пакет ситуаций (${availablePacks.length})',
                                 labelStyle: const TextStyle(color: Colors.white70),
                                 filled: true,
                                 fillColor: Colors.white10,
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              value: selectedPackId,
                              items: availablePacks.map((p) {
                                 return DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                       p.data()['title'] ?? 'Без названия',
                                       style: const TextStyle(color: Colors.white),
                                       overflow: TextOverflow.ellipsis,
                                    ),
                                 );
                              }).toList(),
                              onChanged: (val) {
                                 if (val != null) {
                                    setStateDialog(() {
                                       selectedPackId = val;
                                       selectedCategories = [];
                                       // Update categories
                                       final packData = availablePacks.firstWhere((p) => p.id == val).data();
                                       final sits = (packData['situations'] as List<dynamic>? ?? []);
                                       final cats = sits.map((s) => s['category'] as String? ?? "General").toSet().toList();
                                       cats.sort();
                                       availableCategories = cats;
                                    });
                                 }
                              },
                           ),
                           const SizedBox(height: 8),
                           if (availableCategories.isNotEmpty) ...[
                               const Text("Фильтр категорий (пусто = все):", style: TextStyle(fontSize: 12)),
                               Wrap(
                                  spacing: 6,
                                  children: availableCategories.map((cat) {
                                     final isSelected = selectedCategories.contains(cat);
                                     return FilterChip(
                                        label: Text(cat, style: const TextStyle(fontSize: 11)),
                                        selected: isSelected,
                                        onSelected: (val) {
                                           setStateDialog(() {
                                              if (val) {
                                                 selectedCategories.add(cat);
                                              } else {
                                                 selectedCategories.remove(cat);
                                              }
                                           });
                                        },
                                     );
                                  }).toList(),
                               )
                           ]
                       ]
                  ]
                ],
              ),
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
                          situationPackId: selectedPackId,
                          situationCategories: selectedCategories,
                          isTestGame: isTestGame,
                          gameType: selectedGameType,
                        );
                      } else {
                        await _firestoreService.createGame(
                          title: titleController.text,
                          date: selectedDate,
                          zoomId: zoomIdController.text,
                          zoomPassword: zoomPasswordController.text,
                          situationPackId: selectedPackId,
                          situationCategories: selectedCategories,
                          isTestGame: isTestGame,
                          gameType: selectedGameType,
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
      appBar: AppBar(title: const Text('Игровые сессии v1.53', style: TextStyle(fontSize: 16))),
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
                                      currentZoomPassword: game['zoomPassword'],
                                      currentPackId: game['situationPackId'],
                                      currentCategories: (game['situationCategories'] as List<dynamic>?)?.cast<String>(),
                                      currentIsTestGame: game['isTestGame'],
                                      currentGameType: game['gameType'],
                                   );
                                } else if (value == 'delete') {
                                   _deleteGame(docId, game['title'] ?? '');
                                } else if (value == 'report') {
                                   Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (context) => GameReportScreen(
                                         gameId: docId, 
                                         gameTitle: game['title'] ?? 'Game',
                                         gameDate: date,
                                      ))
                                   );
                                }
                             },
                             itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Изменить")),
                                const PopupMenuItem(value: 'report', child: Text("Отчет")),
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
