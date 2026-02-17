import 'package:flutter/material.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import 'game_editor_dialog.dart';
import 'package:intl/intl.dart';

class GameManagerDialog extends StatelessWidget {
  final FestivalGame game;

  const GameManagerDialog({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(game.title, style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Мастер: ${game.masterName}", style: const TextStyle(color: Colors.white70)),
            Text("Записано: ${game.participants.length} / ${game.maxParticipants}", style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white24),
            const Text("Участники:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (game.participants.isEmpty)
              const Text("Нет участников", style: TextStyle(color: Colors.white30))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: game.participants.length,
                  itemBuilder: (context, index) {
                    final p = game.participants[index];
                    final date = (p['registeredAt'] as dynamic)?.toDate() ?? DateTime.now();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p['userName'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(DateFormat('dd.MM HH:mm').format(date), style: const TextStyle(color: Colors.white30, fontSize: 12)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _deleteGame(context), 
          child: const Text("Удалить игру", style: TextStyle(color: Colors.redAccent))
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(context: context, builder: (_) => GameEditorDialog(game: game));
          }, 
          child: const Text("Редактировать")
        ),
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Закрыть")
        ),
      ],
    );
  }

  void _deleteGame(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить игру?"),
        content: const Text("Это действие нельзя отменить."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Нет")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Да")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().deleteFestivalGame(game.id);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
        }
      }
    }
  }
}
