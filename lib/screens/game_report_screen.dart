import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

class GameReportScreen extends StatefulWidget {
  final String gameId;
  final String gameTitle;
  final DateTime? gameDate;

  const GameReportScreen({
    super.key, 
    required this.gameId, 
    this.gameTitle = "Игра",
    this.gameDate
  });

  @override
  State<GameReportScreen> createState() => _GameReportScreenState();
}

class _GameReportScreenState extends State<GameReportScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Отчет по игре"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Копировать отчет",
            onPressed: () => _generateAndCopyReport(context),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.gameId)
            .collection('rounds')
            .orderBy('roundIndex')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Ошибка: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rounds = snapshot.data!.docs;

          if (rounds.isEmpty) {
            return const Center(
              child: Text("История игры пуста (нет сохраненных раундов)."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rounds.length + 1, // +1 for Header/Footer info
            itemBuilder: (context, index) {
              if (index == 0) {
                 return _buildHeader();
              }
              final roundData = rounds[index - 1].data();
              return _buildRoundCard(roundData);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: Colors.blueGrey.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gameTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            if (widget.gameDate != null)
               Text(DateFormat('dd.MM.yyyy HH:mm').format(widget.gameDate!), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            const Text("Совет: Нажмите кнопку копирования сверху, чтобы получить текстовый отчет для Telegram/Word.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundCard(Map<String, dynamic> data) {
    final int index = data['roundIndex'] ?? 0;
    final String situation = data['situation'] ?? "Нет описания";
    final List<dynamic> actions = data['actions'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text("Раунд $index", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(situation, maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ситуация:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                Text(situation, style: const TextStyle(fontStyle: FontStyle.italic)),
                const Divider(),
                ...actions.map((action) {
                  final name = action['name'] ?? "Unknown";
                  final pNum = action['playerNumber'];
                  final role = action['role'];
                  final answer = action['answer'];
                  final receivedVotes = action['receivedVotes'] ?? 0;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             if (pNum != null) 
                               CircleAvatar(radius: 10, backgroundColor: Colors.white24, child: Text("$pNum", style: const TextStyle(fontSize: 10, color: Colors.white))),
                             const SizedBox(width: 8),
                             Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                             const Spacer(),
                             if (receivedVotes > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                  child: Text("Голосов: $receivedVotes", style: const TextStyle(fontSize: 10, color: Colors.greenAccent))
                                )
                           ],
                         ),
                         if (role != null) Text("Роль: $role", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                         if (answer != null) Text("Ответ: $answer", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]
                    ),
                  );
                }).toList()
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _generateAndCopyReport(BuildContext context) async {
      try {
         final roundsQuery = await FirebaseFirestore.instance
            .collection('games')
            .doc(widget.gameId)
            .collection('rounds')
            .orderBy('roundIndex')
            .get();
         
         final sb = StringBuffer();
         sb.writeln("ОТЧЕТ ПО ИГРЕ");
         sb.writeln("Игра: ${widget.gameTitle}");
         if (widget.gameDate != null) {
            sb.writeln("Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(widget.gameDate!)}");
         }
         sb.writeln("-" * 20);
         sb.writeln("");

         for (var doc in roundsQuery.docs) {
             final data = doc.data();
             final index = data['roundIndex'];
             final situation = data['situation'];
             final List<dynamic> actions = data['actions'] ?? [];

             sb.writeln("РАУНД $index");
             sb.writeln("Ситуация: $situation");
             sb.writeln("");
             
             for (var action in actions) {
                final name = action['name'];
                final num = action['playerNumber'] != null ? "[${action['playerNumber']}] " : "";
                final role = action['role'] != null ? "Role: ${action['role']} " : "";
                final answer = action['answer'] ?? "";
                final votes = action['receivedVotes'] ?? 0;
                
                sb.writeln("$num$name");
                if (role.isNotEmpty) sb.writeln(role);
                if (answer.isNotEmpty) sb.writeln("Ответ: $answer");
                if (votes > 0) sb.writeln("Получено голосов: $votes");
                sb.writeln("");
             }
             sb.writeln("-" * 20);
             sb.writeln("");
         }
         
         // Fetch Final Results (Stats)
         final gameDoc = await FirebaseFirestore.instance.collection('games').doc(widget.gameId).get();
         final stats = Map<String, dynamic>.from(gameDoc.data()?['stats'] ?? {});
         
         if (stats.isNotEmpty) {
            sb.writeln("ИТОГИ ИГРЫ (Голоса):");
            final sorted = stats.entries.toList()..sort((a,b) => (b.value as int).compareTo(a.value as int));
            
            // Need player names map efficiently
            // We can check the last round actions or fetch participants again. 
            // For report speed, let's fetch participants once.
            final parts = await FirebaseFirestore.instance.collection('games').doc(widget.gameId).collection('participants').get();
            final Map<String, String> names = {};
             for (var p in parts.docs) {
                 names[p.id] = p.data()['name'] ?? "Unknown";
             }
            
            int rank = 1;
            for (var entry in sorted) {
               final name = names[entry.key] ?? "Игрок";
               sb.writeln("$rank. $name — ${entry.value}");
               rank++;
            }
         }

         await Clipboard.setData(ClipboardData(text: sb.toString()));
         if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Отчет скопирован в буфер обмена!")));
         }

      } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка генерации: $e")));
         }
      }
  }
}
