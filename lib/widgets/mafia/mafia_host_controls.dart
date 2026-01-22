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
           mainAxisSize: MainAxisSize.min,
           children: [
              const Text("Панель Ведущего", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Main Phase Controls (Icons)
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                    IconButton(
                       icon: const Icon(Icons.wb_sunny),
                       color: widget.mafiaState['phase'] == 'day' ? Colors.orange : Colors.grey,
                       tooltip: "День",
                       onPressed: () => _nextPhase('day'),
                    ),
                    IconButton(
                       icon: const Icon(Icons.how_to_vote),
                       color: widget.mafiaState['phase'] == 'voting' ? Colors.blue : Colors.grey,
                       tooltip: "Голосование",
                       onPressed: () => _nextPhase('voting'),
                    ),
                    IconButton(
                       icon: const Icon(Icons.nightlight_round),
                       color: widget.mafiaState['phase'] == 'night' ? Colors.indigoAccent : Colors.grey,
                       tooltip: "Ночь",
                       onPressed: () => _nextPhase('night'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                       onPressed: _distributeRoles, 
                       style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                       ),
                       child: const Text("Рестарт/Роли", style: TextStyle(fontSize: 12))
                    ),
                 ],
              ),
              
              // Night Controls (Only visible at Night)
              if (widget.mafiaState['phase'] == 'night') ...[
                 const Divider(color: Colors.white24),
                 SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.start,
                       children: [
                          _buildNightRoleButton('mafia', Icons.groups, Colors.red),
                          _buildNightRoleButton('don', Icons.star, Colors.redAccent),
                          _buildNightRoleButton('sheriff', Icons.local_police, Colors.blue),
                          _buildNightRoleButton('doctor', Icons.medical_services, Colors.green),
                          _buildNightRoleButton('mirror', Icons.remove_red_eye, Colors.teal), // Mirror icon
                          // Add more as needed
                       ],
                    ),
                 ),
              ],
           ],
        ),
      ),
    );
  }

  Widget _buildNightRoleButton(String role, IconData icon, Color color) {
     final currentTurn = widget.mafiaState['current_role_turn'];
     final isActive = currentTurn == role;
     
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 4.0),
       child: IconButton(
          icon: Icon(icon),
          color: isActive ? color : Colors.grey[700],
          iconSize: 32,
          tooltip: role.toUpperCase(),
          onPressed: () => _setNightTurn(role),
       ),
     );
  }

  Future<void> _setNightTurn(String role) async {
       await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
          'mafiaState.current_role_turn': role
       });
  }
