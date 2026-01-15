import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/knowledge_service.dart';
import '../widgets/role_info_dialog.dart'; // Import Custom Dialog

class GameDetailsScreen extends StatelessWidget {
  final String gameId;
  final String gameTitle;
  final int? totalScore;
  final int? rank;
  final bool isHostView;

  const GameDetailsScreen({
    super.key, 
    required this.gameId, 
    required this.gameTitle,
    this.totalScore,
    this.rank,
    this.isHostView = false,
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
           // Header Stats (Hide for Host if not relevant, or show generic info)
           if (!isHostView) 
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
             child: isHostView 
               ? _buildHostStream() 
               : _buildParticipantStream(user.uid),
           )
        ],
      ),
    );
  }

  Widget _buildHostStream() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('rounds')
          .orderBy('timestamp', descending: false)
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
               final roundIdx = data['roundIndex'] ?? (index + 1);
               final actions = List<Map<String, dynamic>>.from(data['actions'] ?? []);
               
               return Card(
                 margin: const EdgeInsets.only(bottom: 12),
                 child: ExpansionTile(
                    leading: CircleAvatar(
                       backgroundColor: Colors.orangeAccent,
                       child: Text("$roundIdx", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(situation, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text("Участников: ${actions.length}"),
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
                               const Divider(),
                               const Text("Действия участников:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                               const SizedBox(height: 8),
                               ...actions.map((action) {
                                  final name = action['name'] ?? 'Игрок';
                                  final role = action['role'];
                                  final votes = action['receivedVotes'] ?? 0;
                                  final answer = action['answer'];
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        if (role != null) 
                                           Image.asset('assets/images/cards/role_$role.png', width: 24, height: 34, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.style, size: 24)),
                                        if (role == null) const SizedBox(width: 24),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              if (answer != null) Text(answer.toString(), style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          )
                                        ),
                                        Row(children: [
                                          const Icon(Icons.thumb_up, size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text("$votes", style: const TextStyle(fontWeight: FontWeight.bold))
                                        ])
                                      ],
                                    ),
                                  );
                               }).toList()
                            ]
                         )
                       )
                    ]
                 )
               );
            }
          );
      }
    );
  }

  Widget _buildParticipantStream(String uid) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
       stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
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
               final answer = data['answer']; // This is the user's thought/answer text
               final role = data['role'] as int?;
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
                               
                               if (answer != null && answer.toString().isNotEmpty) ...[
                                  const Text("Ваш комментарий/ответ:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                  const SizedBox(height: 4),
                                  Text(answer.toString(), style: const TextStyle(fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 16),
                               ],
                               
                               Row(
                                  children: [
                                     if (role != null) ...[
                                        Image.asset('assets/images/cards/role_$role.png', width: 40, height: 56, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.style)),
                                        const SizedBox(width: 12),
                                        InkWell(
                                           onTap: () {
                                              showDialog(
                                                 context: context,
                                                 builder: (context) => RoleInfoDialog(roleNumber: role!)
                                              );
                                           },
                                           child: Text(
                                              "Выбрана Роль $role ${KnowledgeService.getRoleInfo(role!)['role_name'] ?? ''}", 
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
