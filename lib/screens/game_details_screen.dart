import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/knowledge_service.dart';
import 'role_detail_screen.dart';

class GameDetailsScreen extends StatelessWidget {
  final String gameId;
  final String gameTitle;
  final int? totalScore;
  final int? rank;

  const GameDetailsScreen({
    super.key, 
    required this.gameId, 
    required this.gameTitle,
    this.totalScore,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Ошибка авторизации")));

    return Scaffold(
      appBar: AppBar(
        title: Text(gameTitle),
      ),
      body: Column(
        children: [
           // Header Stats
           Container(
             padding: const EdgeInsets.all(16),
             color: Colors.blueAccent.withOpacity(0.1),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceAround,
               children: [
                  _buildStat("Очки", "${totalScore ?? '-'}"),
                  _buildStat("Место", "${rank ?? '-'}"),
               ],
             ),
           ),
           
           Expanded(
             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
               stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('game_history')
                  .doc(gameId)
                  .collection('rounds')
                  .orderBy('timestamp', descending: false) // Chronological order usually better for reading history
                  .snapshots(),
               builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Детали раундов не найдены", style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                       final data = docs[index].data();
                       final situation = data['situation'] ?? 'Нет описания';
                       final answer = data['answer'];
                       final role = data['role'];
                       final votes = data['votes'] ?? 0;
                       final roundIdx = data['roundIndex'] ?? (index + 1);
                       
                       return Card(
                         margin: const EdgeInsets.only(bottom: 12),
                         child: ExpansionTile(
                            leading: CircleAvatar(
                               backgroundColor: Colors.blueGrey,
                               child: Text("$roundIdx", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(situation, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text("Роль: $role · Голосов: $votes", style: TextStyle(color: votes > 0 ? Colors.green : Colors.grey)),
                            children: [
                               Padding(
                                 padding: const EdgeInsets.all(16.0),
                                 child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                       const Text("Ситуация:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                       const SizedBox(height: 4),
                                       Text(situation, style: const TextStyle(fontSize: 15)),
                                       const SizedBox(height: 16),
                                       
                                       // Removed 'Your Answer' section by request
                                       // const Text("Ваш ответ:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                       // const SizedBox(height: 4),
                                       // ...
                                       Row(
                                          children: [
                                             if (role != null) ...[
                                                Image.asset('assets/images/cards/role_$role.png', width: 40, height: 56, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.style)),
                                                const SizedBox(width: 12),
                                                InkWell(
                                                   onTap: () {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => RoleDetailScreen(roleNumber: role)));
                                                   },
                                                   child: Text(
                                                      "Выбрана Роль $role ${KnowledgeService.getRoleInfo(role)['role_name'] ?? ''}", 
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, decoration: TextDecoration.underline)
                                                   ),
                                                )
                                             ],
                                             const Spacer(),
                                             Icon(Icons.thumb_up, color: votes > 0 ? Colors.green : Colors.grey, size: 20),
                                             const SizedBox(width: 8),
                                             Text("$votes голосов", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                                          ],
                                       )
                                    ],
                                 ),
                               )
                            ],
                         ),
                       );
                    },
                  );
               }
             ),
           )
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
     return Column(
        children: [
           Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
           Text(label, style: const TextStyle(color: Colors.grey)),
        ],
     );
  }
}
