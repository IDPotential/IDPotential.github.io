import 'package:flutter/material.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../utils/file_saver.dart';

class ParticipantListDialog extends StatelessWidget {
  final FestivalGame game;

  const ParticipantListDialog({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.amberAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Записались: ${game.title}",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: FirestoreService().getFestivalGameParticipants(game.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Ошибка: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }
                  
                  final participants = snapshot.data ?? [];
                  if (participants.isEmpty) {
                    return const Center(child: Text("Пока никто не записался", style: TextStyle(color: Colors.white54)));
                  }

                  return ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (ctx, index) {
                       final p = participants[index];
                       final date = (p['joinedAt'] as dynamic)?.toDate();
                       final dateStr = date != null ? DateFormat('HH:mm dd.MM').format(date) : '';
                       
                       return ListTile(
                         leading: CircleAvatar(
                           backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                           child: Text("${index + 1}", style: const TextStyle(color: Colors.blueAccent)),
                         ),
                         title: Text(p['name'] ?? 'Без имени', style: const TextStyle(color: Colors.white)),
                         subtitle: Text("${p['contact'] ?? 'Нет контакта'} • $dateStr", style: const TextStyle(color: Colors.white54)),
                       );
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _downloadList(context),
                icon: const Icon(Icons.download),
                label: const Text("Скачать список (.txt)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(double.infinity, 45)
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _downloadList(BuildContext context) async {
      try {
        final participants = await FirestoreService().getFestivalGameParticipants(game.id);
        
        if (!context.mounted) return;
        
        if (participants.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Список пуст")));
           return;
        }

        final buffer = StringBuffer();
        buffer.writeln("Игра: ${game.title}");
        buffer.writeln("Мастер: ${game.masterName}");
        buffer.writeln("Время игры: ${DateFormat('dd.MM.yyyy HH:mm').format(game.startTime)}");
        buffer.writeln("------------------------------------------------");
        
        for (int i = 0; i < participants.length; i++) {
           final p = participants[i];
           
           // Format: 1. Name (Contact) [DOB: dd.mm.yyyy] [Registered: HH:mm dd.MM]
           String line = "${i+1}. ${p['name']} (${p['contact']})";
           
           if (p['birthDate'] != null) {
              final dob = (p['birthDate'] as dynamic).toDate();
              line += " [ДР: ${DateFormat('dd.MM.yyyy').format(dob)}]";
           }
           
           if (p['joinedAt'] != null) {
               final joined = (p['joinedAt'] as dynamic).toDate();
               line += " [Записан: ${DateFormat('HH:mm dd.MM').format(joined)}]";
           }
           
           buffer.writeln(line);
        }
        
        final fileName = "participants_${game.title.replaceAll(RegExp(r'[^\w\u0400-\u04FF]'), '_')}.txt";
        await FileSaver.saveText(buffer.toString(), fileName);
        
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Скачивание началось")));

      } catch (e) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка скачивания: $e")));
      }
  }
}
