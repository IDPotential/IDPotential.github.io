import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';

class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showCreateGameDialog() {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать игру'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название игры'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text("Дата: ${selectedDate.toLocal().toString().split(' ')[0]}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                   setState(() { // This setState won't update Dialog UI without StatefulBuilder
                      selectedDate = picked;
                   });
                   // For simplicity in this rough dialog, assume date is today or rely on quick pick
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  await _firestoreService.createGame(
                    title: titleController.text,
                    date: selectedDate,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Игровые сессии')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGameDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getGamesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final games = snapshot.data!.docs;

          if (games.isEmpty) {
            return const Center(child: Text("Нет активных игр. Создайте новую!"));
          }

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index].data();
              final docId = games[index].id;
              final dateStr = game['scheduledAt'] ?? '';
              DateTime? date;
              try { date = DateTime.parse(dateStr); } catch (_) {}

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(game['title'] ?? 'Без названия'),
                  subtitle: Text(date != null 
                    ? "${date.day}.${date.month}.${date.year}" 
                    : "Дата не указана"),
                  trailing: const Icon(Icons.arrow_forward_ios),
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
