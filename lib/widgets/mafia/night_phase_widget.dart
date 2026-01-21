import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NightPhaseWidget extends StatelessWidget {
  final String gameId;
  final String myRole; // 'mafia', 'doctor', etc.
  final String currentTurnRole; // The role currently acting
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> participants;

  const NightPhaseWidget({
    super.key,
    required this.gameId,
    required this.myRole,
    required this.currentTurnRole,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    // If it's my turn
    if (myRole == currentTurnRole) {
       return _buildActionInterface(context);
    }
    
    // Special case for Mafia teammates? 
    // Usually Mafia members wake up together. 
    // If currentTurnRole == 'mafia' and myRole == 'mafia' (or boss), show chat/selection.
    if (currentTurnRole == 'mafia' && (myRole == 'mafia' || myRole == 'boss')) {
       return _buildActionInterface(context);
    }

    // Otherwise sleep
    return _buildSleepingInterface();
  }

  Widget _buildSleepingInterface() {
     return Container(
        color: Colors.black,
        child: Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.nightlight_round, color: Colors.blueGrey, size: 80),
                 const SizedBox(height: 16),
                 Text(
                    "Город спит...", 
                    style: TextStyle(color: Colors.blueGrey[200], fontSize: 24, fontWeight: FontWeight.bold)
                 ),
                 const SizedBox(height: 8),
                 Text(
                    "Сейчас ходит: ${_getRoleName(currentTurnRole)}",
                    style: const TextStyle(color: Colors.white38, fontSize: 14)
                 ),
              ],
           )
        ),
     );
  }

  Widget _buildActionInterface(BuildContext context) {
      // Determine prompt text
      String prompt = "Выберите цель";
      if (currentTurnRole == 'doctor') prompt = "Кого лечить?";
      if (currentTurnRole == 'mafia') prompt = "Кого устранить?";
      if (currentTurnRole == 'commissioner') prompt = "Кого проверить?";
      
      return Container(
         color: Colors.blueGrey[900], // Slightly lighter than black
         padding: const EdgeInsets.all(16),
         child: Column(
            children: [
               Text(prompt, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 20),
               Expanded(
                  child: GridView.builder(
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                     ),
                     itemCount: participants.length,
                     itemBuilder: (context, index) {
                        final p = participants[index].data();
                        final pid = participants[index].id;
                        final name = p['name'] ?? 'Игрок';
                        
                        // Check if alive (TODO: Filter only alive players)
                        
                        return GestureDetector(
                           onTap: () => _performAction(context, pid, name),
                           child: Container(
                              decoration: BoxDecoration(
                                 color: Colors.white10,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.white24)
                              ),
                              child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                    const CircleAvatar(
                                       backgroundColor: Colors.grey, 
                                       child: Icon(Icons.person, color: Colors.white)
                                    ),
                                    const SizedBox(height: 8),
                                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                                 ],
                              ),
                           ),
                        );
                     },
                  )
               )
            ],
         ),
      );
  }
  
  String _getRoleName(String roleId) {
     switch(roleId) {
        case 'mafia': return "Мафия";
        case 'doctor': return "Доктор";
        case 'commissioner': return "Комиссар";
        case 'maniac': return "Маньяк";
        default: return roleId;
     }
  }

  void _performAction(BuildContext context, String targetId, String targetName) async {
     // Save action to Firestore
     // For prototype: Just show snackbar
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Вы выбрали: $targetName")));
     
     // Real implementation: Write to games/{gameId}/mafiaState/night_actions
     await FirebaseFirestore.instance.collection('games').doc(gameId).update({
        'mafiaState.night_actions.$currentTurnRole': {
            'targetId': targetId,
            'targetName': targetName,
            'timestamp': FieldValue.serverTimestamp()
        }
     });
  }
}
