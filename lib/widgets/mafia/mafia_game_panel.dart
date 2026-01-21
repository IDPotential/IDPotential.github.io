import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mafia_host_controls.dart';
import 'night_phase_widget.dart';
import 'day_phase_widget.dart';
import 'voting_widget.dart';
import 'mafia_lobby_widget.dart';

class MafiaGamePanel extends StatelessWidget {
  final String gameId;
  final bool isHost;
  final String currentUserId;

  const MafiaGamePanel({
    super.key,
    required this.gameId,
    required this.isHost,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('games').doc(gameId).collection('participants').snapshots(),
      builder: (context, partSnapshot) {
        if (!partSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final participants = partSnapshot.data!.docs;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('games').doc(gameId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final gameData = snapshot.data!.data() as Map<String, dynamic>?;
            if (gameData == null) return const Center(child: Text("Ошибка загрузки данных игры"));

            final mafiaState = gameData['mafiaState'] as Map<String, dynamic>? ?? {};
            final phase = mafiaState['phase'] ?? 'lobby';

            return Column(
              children: [
                // Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Фаза: $phase", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (isHost)
                        const Text("Ведущий", style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ],
                  ),
                ),
                
                if (isHost)
                   MafiaHostControls(gameId: gameId, mafiaState: mafiaState, participants: participants),

                // Phase Content
                Expanded(
                  child: _buildPhaseContent(phase, mafiaState, participants),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildPhaseContent(String phase, Map<String, dynamic> state, List<QueryDocumentSnapshot<Map<String, dynamic>>> participants) {
    switch (phase) {
      case 'night':
        final currentTurn = state['current_role_turn'] ?? 'none';
        final meDoc = participants.where((d) => d.id == currentUserId).firstOrNull?.data();
        final myRole = meDoc?['mafiaRole'] ?? 'viewer';

        return NightPhaseWidget(
            gameId: gameId, 
            myRole: myRole, 
            currentTurnRole: currentTurn,
            participants: participants
        );
      case 'day':
         return DayPhaseWidget(state: state);
      case 'voting':
         return VotingWidget(gameId: gameId, participants: participants, isHost: isHost);
      default: // lobby
        return MafiaLobbyWidget(gameId: gameId, participants: participants, isHost: isHost);
    }
  }
}
