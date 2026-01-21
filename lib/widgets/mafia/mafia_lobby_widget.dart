import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';

class MafiaLobbyWidget extends StatelessWidget {
  final String gameId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> participants;
  final bool isHost;

  const MafiaLobbyWidget({
    super.key,
    required this.gameId,
    required this.participants,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
       return const Center(child: Text("Ожидание игроков...", style: TextStyle(color: Colors.white54)));
    }

    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(participants);
    // Prioritize pending requests
    sortedDocs.sort((a, b) {
       final sA = a.data()['status'] ?? '';
       final sB = b.data()['status'] ?? '';
       if (sA == 'pending' && sB != 'pending') return -1;
       if (sA != 'pending' && sB == 'pending') return 1;
       return 0;
    });

    return Column(
      children: [
         const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Лобби: Игроки", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
         ),
         Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                childAspectRatio: 0.8,
                crossAxisSpacing: 8, mainAxisSpacing: 8
              ),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                  final data = sortedDocs[index].data();
                  final name = data['name'] ?? 'Unknown';
                  final status = data['status'];
                  final telegram = data['telegram'];
                  
                  return Card(
                      color: status == 'pending' ? Colors.orange.withOpacity(0.15) : Colors.white12,
                      shape: status == 'pending' 
                        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.orangeAccent, width: 1))
                        : null,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                              CircleAvatar(
                                 backgroundColor: Colors.white24, 
                                 child: Icon(Icons.person, color: Colors.white)
                              ),
                              const SizedBox(height: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                              
                              if (isHost && status == 'pending') ...[
                                 const Spacer(),
                                 // Telegram link if available
                                 if (telegram != null && telegram.toString().isNotEmpty)
                                     InkWell(
                                        onTap: () {
                                            String tg = telegram.toString().replaceAll('@', '');
                                            launchUrl(Uri.parse("https://t.me/$tg"));
                                        },
                                        child: Text(telegram, style: const TextStyle(color: Colors.blue, fontSize: 10))
                                     ),
                                 const SizedBox(height: 4),
                                 Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                       InkWell(
                                          onTap: () => FirestoreService().approveParticipant(gameId, sortedDocs[index].id),
                                          child: const Icon(Icons.check_circle, color: Colors.green)
                                       ),
                                       const SizedBox(width: 16),
                                       InkWell(
                                          onTap: () => FirestoreService().rejectParticipant(gameId, sortedDocs[index].id),
                                          child: const Icon(Icons.cancel, color: Colors.red)
                                       ),
                                    ],
                                 )
                              ] else if (status == 'approved') ...[
                                 const SizedBox(height: 4),
                                 const Text("В игре", style: TextStyle(color: Colors.green, fontSize: 10))
                              ]
                           ],
                        ),
                      )
                  );
              },
            ),
         )
      ],
    );
  }
}
