import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';

class MafiaHostControls extends StatefulWidget {
  final String gameId;
  final Map<String, dynamic> mafiaState;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> participants;

  const MafiaHostControls({
    super.key,
    required this.gameId,
    required this.mafiaState,
    required this.participants,
  });

  @override
  State<MafiaHostControls> createState() => _MafiaHostControlsState();
}

class _MafiaHostControlsState extends State<MafiaHostControls> {
  final FirestoreService _firestoreService = FirestoreService();

  // Roles configuration
  final Map<String, int> _roleCounts = {
    'mafia': 2,
    'doctor': 1,
    'commissioner': 1,
    'civilian': 4,
    // Add others as needed
  };

  Future<void> _distributeRoles() async {
     // Flatten roles based on counts
     List<String> rolesDeck = [];
     _roleCounts.forEach((role, count) {
        for(int i=0; i<count; i++) rolesDeck.add(role);
     });
     
     // Adjust deck size to participants
     if (rolesDeck.length < widget.participants.length) {
        // Fill rest with civilians
        int diff = widget.participants.length - rolesDeck.length;
        for(int i=0; i<diff; i++) rolesDeck.add('civilian');
     } else if (rolesDeck.length > widget.participants.length) {
        rolesDeck = rolesDeck.sublist(0, widget.participants.length);
     }
     
     rolesDeck.shuffle();
     
     final batch = FirebaseFirestore.instance.batch();
     
     for (int i=0; i < widget.participants.length; i++) {
        final p = widget.participants[i];
        final role = rolesDeck[i];
        
        // Update Participant Doc with Role
        final ref = FirebaseFirestore.instance.collection('games').doc(widget.gameId).collection('participants').doc(p.id);
        batch.update(ref, {'mafiaRole': role});
     }
     
     // Init State
     final gameRef = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
     batch.update(gameRef, {
        'mafiaState.phase': 'night',
        'mafiaState.turn': 1,
        'mafiaState.current_role_turn': 'mafia', // Start with Mafia for simplicity or defined order
        'mafiaState.alivePlayers': widget.participants.map((e) => e.id).toList(),
     });
     
     await batch.commit();
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Роли распределены, Ночь началась!")));
  }

  Future<void> _nextPhase(String phase) async {
      await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
          'mafiaState.phase': phase
      });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const Text("Панель Ведущего", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                 spacing: 8,
                 children: [
                    ElevatedButton(
                       onPressed: _distributeRoles, 
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                       child: const Text("Раздать роли и Начать")
                    ),
                    ElevatedButton(
                       onPressed: () => _nextPhase('day'), 
                       child: const Text("День")
                    ),
                    ElevatedButton(
                       onPressed: () => _nextPhase('voting'), 
                       child: const Text("Голосование")
                    ),
                    ElevatedButton(
                       onPressed: () => _nextPhase('night'), 
                       child: const Text("Ночь")
                    ),
                 ],
              )
           ],
        ),
      ),
    );
  }
}
