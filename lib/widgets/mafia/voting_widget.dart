import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VotingWidget extends StatelessWidget {
  final String gameId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> participants;
  final bool isHost;

  const VotingWidget({
    super.key,
    required this.gameId,
    required this.participants,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Filter only alive players for voting targets? Or all? Usually only alive.
    // For now assuming all in participants list are "in game" or we check specific flag.
    
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Голосование", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final p = participants[index].data();
              final pid = participants[index].id;
              final name = p['name'] ?? 'Игрок';
              final votes = (p['votes'] as List<dynamic>?) ?? [];
              
              // Count votes for this player
              final voteCount = votes.length;
              
              final bool isMe = pid == currentUser?.uid;
              final bool hasVoted = _hasVoted(currentUser?.uid);

              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Голосов: $voteCount", style: const TextStyle(color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       // Display avatars of who voted for this player?
                       // Simple vote button
                       if (!isMe && !hasVoted && !isHost) 
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => _voteFor(pid),
                            child: const Text("Голосовать")
                          ),
                       if (isHost)
                          IconButton(
                             icon: const Icon(Icons.gavel, color: Colors.orange),
                             onPressed: () => _eliminatePlayer(context, pid, name),
                          )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _hasVoted(String? myUid) {
     if (myUid == null) return true;
     for (var p in participants) {
        final votes = (p.data()['votes'] as List<dynamic>?) ?? [];
        if (votes.contains(myUid)) return true;
     }
     return false;
  }

  Future<void> _voteFor(String targetUid) async {
     final myUid = FirebaseAuth.instance.currentUser?.uid;
     if (myUid == null) return;
     
     // Transaction effectively
     await FirebaseFirestore.instance.collection('games').doc(gameId).collection('participants').doc(targetUid).update({
        'votes': FieldValue.arrayUnion([myUid])
     });
  }

  Future<void> _eliminatePlayer(BuildContext context, String targetUid, String name) async {
     // Host action
     final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
           title: Text("Исключить $name?"),
           actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Нет")),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Да", style: TextStyle(color: Colors.red))),
           ],
        )
     );

     if (confirm == true) {
        // Mark as dead or remove
        await FirebaseFirestore.instance.collection('games').doc(gameId).collection('participants').doc(targetUid).update({
           'isAlive': false,
           'status': 'kicked'
        });
        
        await FirebaseFirestore.instance.collection('games').doc(gameId).update({
           'mafiaState.alivePlayers': FieldValue.arrayRemove([targetUid])
        });
     }
  }
}
