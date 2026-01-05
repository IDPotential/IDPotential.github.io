import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import '../utils/registry.dart'; 
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/knowledge_service.dart';
import '../models/calculation.dart';
import 'package:intl/intl.dart';

class ActiveGameScreen extends StatefulWidget {
  final String gameId;
  final Calculation? gameProfile;
  final bool isHost;
  final String? initialRoomName;

  const ActiveGameScreen({
    super.key, 
    required this.gameId, 
    this.gameProfile, 
    this.isHost = false,
    this.initialRoomName
  });

  @override
  State<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends State<ActiveGameScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // Game State
  late String _targetGameId;
  String? _targetGameTitle;
  String? _gameStage = 'selection';
  String? _gameStatus = 'active';
  Map<String, dynamic> _gameStats = {};
  String? _zoomId;
  String? _zoomPassword;

  // Player State
  String? _participantStatus;
  int? _selectedRole;
  int? _playerNumber;
  
  bool _isVideoActive = false; 
  String _roomName = '';
  final GlobalKey _zoomViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targetGameId = widget.gameId;
    _roomName = widget.initialRoomName ?? '';
    _registerZoomViewFactory();
    _initGameListeners();
  }

  @override
  void dispose() {
      if (kIsWeb) {
          try {
             js.context.callMethod('leaveZoom');
          } catch(e) {
             debugPrint("Zoom cleanup error: $e");
          }
      }
      super.dispose();
  }

  void _initGameListeners() {
      // Listen to Game Doc
      _firestoreService.getGameStream(_targetGameId).listen((doc) {
         if (!doc.exists) return;
         final data = doc.data();
         if (data != null) {
            if (mounted) setState(() {
              _gameStage = data['stage'] ?? 'selection';
              _gameStatus = data['status'] ?? 'active';
              _gameStats = data['stats'] ?? {};
              _zoomId = data['zoomId'];
              _zoomPassword = data['zoomPassword'];
              _targetGameTitle = data['title'];
            });
         }
      });

      // Listen to My Status
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         _firestoreService.getGameParticipantsStream(_targetGameId).listen((event) {
            final me = event.docs.where((d) => d.id == user.uid).firstOrNull;
            if (mounted) {
               setState(() {
                  _participantStatus = me?.data()['status'];
                  _playerNumber = me?.data()['playerNumber'];
                   _selectedRole = me?.data()['selectedRole'];
               });
            }
         });
      }
  }

  void _registerZoomViewFactory() {
    if (kIsWeb) {
      registerZoomViewFactory('zoom-container');
    }
  }

  void _connectToZoom() {
      if (_zoomId == null || _zoomId!.isEmpty) return;
      
      setState(() => _isVideoActive = true);
      
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? widget.gameProfile?.name.split(' ')[0] ?? "Player";

      Future.delayed(const Duration(milliseconds: 500), () {
          js.context.callMethod('initZoom', [
              _zoomId, 
              _zoomPassword ?? "", 
              userName,
              "EpevSkKvRxGrNoetCoYmOQ",
              "pZKWEleW18O3poQ9MYots4vyEVU3O6tc"
          ]);
      });
  }

  void _goHome() {
      // Return to Main Screen (Restoring Bottom Bar)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        body: Container(
           decoration: const BoxDecoration(
             gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
           ),
           child: SafeArea(
             child: _gameStatus == 'archived' 
               ? _buildGameArchivedScreen()
               : Column(
                   children: [
                     // Top Section: Video
                     Expanded(
                       flex: 5,
                       child: Container(
                         color: Colors.black87,
                         child: Stack(
                           children: [
                             _isVideoActive 
                               ? _buildZoomPanel() 
                               : _buildVideoPlaceholder(),
                             // Host Home Button in Top Left (if Host)
                             if (widget.isHost)
                                Positioned(
                                  top: 10, left: 10,
                                  child: IconButton(
                                    icon: const Icon(Icons.home, color: Colors.white70),
                                    onPressed: _goHome,
                                  )
                                )
                           ]
                         )
                       ),
                     ),
                     const Divider(height: 1, thickness: 1, color: Colors.grey),
                     // Bottom Section: Dashboard
                     Expanded(
                       flex: 5,
                       child: widget.isHost && _gameStatus != 'archived'
                         ? _buildHostDashboard()
                         : _buildPlayerDashboard(),
                     ),
                   ],
                 ),
           )
        )
      );
  }

  // --- HOST DASHBOARD ---

  Widget _buildHostDashboard() {
     // Removed "Ведущий" label, kept only necessary controls. 
     // Home button moved to Top Screen (in build/stack) or we can keep it here.
     // User requirement: "Interface host home also to main screen... remove bottom line".
     // I put Home button in Host dashboard before, but requested "Home icon to main screen... same rules".
     // Since split is 50/50, let's put it in the dashboard header for consistency with Player.
     
     return Column(
        children: [
           Container(
             color: Colors.black45,
             padding: const EdgeInsets.all(8),
             child: Row(
               children: [
                 IconButton(
                    icon: const Icon(Icons.home, color: Colors.white70, size: 20),
                    tooltip: 'На главный экран',
                    onPressed: _goHome,
                 ),
                 const Spacer(),
                  if (_gameStatus == 'finished')
                     ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(0, 30)),
                        onPressed: () => _showEndSessionDialog(),
                        child: const Text("Завершить игру", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                     )
                  else ...[
                     if (_gameStage == 'voting')
                        ElevatedButton(
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(0, 30)),
                           onPressed: () => _showEndRoundDialog(),
                           child: const Text("Завершить кон", style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))
                        ),
                     const SizedBox(width: 8),
                     ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(0, 30)),
                        onPressed: () => _showEndGameDialog(),
                        child: const Text("Финиш", style: TextStyle(fontSize: 10, color: Colors.white))
                     ),
                  ],
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [_gameStage == 'selection', _gameStage == 'voting'],
                    onPressed: (index) {
                       final newStage = index == 0 ? 'selection' : 'voting';
                       _firestoreService.updateGameStage(_targetGameId, newStage);
                       setState(() => _gameStage = newStage);
                    },
                    color: Colors.white60,
                    selectedColor: Colors.white,
                    fillColor: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Выбор")),
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Голос")),
                    ],
                 )
               ],
             ),
           ),
           Expanded(
             child: _gameStatus == 'finished' 
               ? _buildFinalResults() 
               : _buildVotingBoard(), // Host uses same Voting Board grid but with controls
           )
        ],
     );
  }

  // --- PLAYER DASHBOARD ---

  Widget _buildPlayerDashboard() {
    return Container(
      color: Colors.transparent, 
      child: Column(
        children: [
           if (_gameStatus == 'finished')
              Expanded(child: _buildFinalResults())
           else if (_gameStage == 'voting')
              Expanded(child: _buildVotingBoard())
           else ...[
              // Custom Header per request
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                   children: [
                      // Left: Home Icon
                      IconButton(
                          icon: const Icon(Icons.home, color: Colors.white70),
                          onPressed: _goHome,
                      ),
                      
                      // Center: "My Roles"
                      const Expanded(
                         child: Center(
                            child: Text("Мои Роли", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))
                         )
                      ),
                      
                      // Right: Selected Role + Cancel
                      if (_selectedRole != null) ...[
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  Text("Роль $_selectedRole", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => setState(() => _selectedRole = null),
                                    child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                                  )
                               ]
                             )
                          )
                      ] else 
                          // Spacer to balance the row if no role selected, or empty width
                          const SizedBox(width: 48), // Approx width of Home button
                   ],
                ),
              ),
              Expanded(child: _buildRolesGrid()),
           ]
        ],
      ),
    );
  }

  // --- COMMON WIDGETS (Video, Grid, Voting) ---

  Widget _buildVideoPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_call, size: 50, color: Colors.white54),
          const SizedBox(height: 10),
          Text("Игра: ${_targetGameTitle ?? _roomName}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Text("Подключиться к видео"),
            onPressed: _connectToZoom,
          ),
          const SizedBox(height: 10),
          // "Choose another game" moved here as requested
          if (!widget.isHost)
            TextButton(
              onPressed: () {
                  // Popping active game screen returns to Lobby (GameScreen)
                  Navigator.pop(context);
              },
              child: const Text("Выбрать другую игру", style: TextStyle(color: Colors.blueAccent)),
            )
        ],
      ),
    );
  }
  
  Widget _buildVideoOffPlaceholder() {
    // When video is active/inited but camera off or disconnected in UI
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text("Видео отключено", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
             icon: const Icon(Icons.videocam),
             label: const Text("Войти в конференцию"),
             onPressed: _connectToZoom,
          ),
          if (!widget.isHost)
             TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Выйти", style: TextStyle(color: Colors.white38)),
            )

        ],
      ),
    );
  }

  Widget _buildZoomPanel() {
    return Stack(
      children: [
        HtmlElementView(key: _zoomViewKey, viewType: 'zoom-container'),
        Positioned(
          top: 10, right: 10,
          child: FloatingActionButton(
            mini: true, backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
            onPressed: () {
               js.context.callMethod('leaveZoom');
               setState(() => _isVideoActive = false);
            },
          ),
        ),
      ],
    );
  }

  // Reuse logic directly
  Widget _buildRolesGrid() {
    final Set<int> uniqueNumbers = {};
    if (widget.gameProfile != null) {
      for (var n in widget.gameProfile!.numbers) {
        uniqueNumbers.add(n == 0 ? 22 : n);
      }
    }
    final sortedNumbers = uniqueNumbers.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, childAspectRatio: 0.65, crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: sortedNumbers.length,
      itemBuilder: (context, index) {
        final number = sortedNumbers[index];
        final isSelected = _selectedRole == number;
        return GestureDetector(
          onTap: () => _showRoleInfo(number),
          child: Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: Colors.orange, width: 3) : null,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 8)] : null,
            ),
            child: Card(
              clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero, elevation: isSelected ? 8 : 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.asset('assets/images/cards/role_$number.png', fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.image_not_supported)),
                  ),
                  Container(
                    color: isSelected ? Colors.orange : Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('$number', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVotingBoard() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId),
         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final participants = snapshot.data!.docs;
            final String? myUid = FirebaseAuth.instance.currentUser?.uid;
            
            // Check own vote
            String? myVoteId;
            try {
               final myDoc = participants.where((d) => d.id == myUid).firstOrNull;
               myVoteId = myDoc?.data()['votedFor'];
            } catch (_) {}
            
            return Padding(
               padding: const EdgeInsets.all(8.0),
               child: Column(
                 children: [
                   const Text("Голосование", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Expanded(
                     child: GridView.builder(
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10,
                       ),
                       itemCount: participants.length,
                       itemBuilder: (context, index) {
                          final doc = participants[index];
                          final pData = doc.data();
                          final pUid = doc.id;
                          final pNum = pData['playerNumber'];
                          final pName = pData['name'] ?? '...';
                          final pRoleId = pData['selectedRole']; // Only show during voting result? 
                          // Logic from GameScreen: if stage==voting, show roles? Or just avatars?
                          // In GameScreen, roleId was shown.
                          
                          final bool isSelected = myVoteId == pUid;
                          final bool isMe = myUid == pUid;

                          return GestureDetector(
                             onTap: () {
                                if (!widget.isHost) {
                                   if (isSelected) _firestoreService.clearVote(_targetGameId);
                                   else _firestoreService.voteForPlayer(_targetGameId, pUid);
                                }
                             },
                             child: Container(
                                decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: isSelected ? Colors.green : Colors.transparent, width: 3),
                                   boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 8)] : null,
                                ),
                                child: Card(
                                   color: isMe ? Colors.white12 : Colors.white10,
                                   clipBehavior: Clip.antiAlias,
                                   child: Stack(
                                      children: [
                                         if (pRoleId != null)
                                            Positioned.fill(child: Opacity(opacity: 0.2, child: Image.asset('assets/images/cards/role_$pRoleId.png', fit: BoxFit.cover))),
                                         Center(child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                               if (pNum != null) CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Text("$pNum", style: const TextStyle(color: Colors.white, fontSize: 12))),
                                               const SizedBox(height: 4),
                                               Text(pName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                               // Add host controls here if needed (approve/reject is usually selection stage, but this is voting board)
                                            ],
                                         ))
                                      ]
                                   )
                                )
                             )
                          );
                       },
                     ),
                   )
                 ]
               )
            );
         }
      );
  }
  
    Widget _buildFinalResults() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId),
         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final participants = snapshot.data!.docs;
            
            final sorted = _gameStats.entries.toList()
               ..sort((a, b) => (b.value as int).compareTo(a.value as int));

            return Container(
               padding: const EdgeInsets.all(24),
               child: Column(
                  children: [
                     const Icon(Icons.emoji_events, color: Colors.orange, size: 60),
                     const SizedBox(height: 10),
                     const Text("ИГРА ЗАВЕРШЕНА", style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 10),
                     const Text("Итоговая статистика (Голоса)", style: TextStyle(color: Colors.white70, fontSize: 16)),
                     const Divider(color: Colors.white24, height: 40),
                     Expanded(
                        child: sorted.isEmpty 
                          ? const Center(child: Text("Нет данных о голосовании", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: sorted.length,
                              itemBuilder: (context, index) {
                                 final uid = sorted[index].key;
                                 final score = sorted[index].value;
                                 final pDoc = participants.where((d) => d.id == uid).firstOrNull;
                                 final name = pDoc?.data()['name'] ?? "Unknown";
                                 final pNum = pDoc?.data()['playerNumber'];

                                 return Card(
                                    color: index == 0 ? Colors.orange.withOpacity(0.2) : Colors.white10,
                                    child: ListTile(
                                       leading: CircleAvatar(
                                          backgroundColor: index == 0 ? Colors.orange : Colors.white24,
                                          child: Text("${index + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                       ),
                                       title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                       subtitle: Text(pNum != null ? "Игрок $pNum" : ""),
                                       trailing: Text("$score", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                    ),
                                 );
                              }
                           ),
                     ),
                     if (widget.isHost)
                        Padding(
                           padding: const EdgeInsets.only(top: 20),
                           child: ElevatedButton(
                              onPressed: _goHome,
                              child: const Text("Выход в лобби"),
                           ),
                        )
                  ],
               ),
            );
         }
      );
   }

   Widget _buildGameArchivedScreen() {
      return Center(
         child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
               const SizedBox(height: 20),
               const Text("ИГРА ЗАВЕРШЕНА", style: TextStyle(color: Colors.white, fontSize: 24)),
               const SizedBox(height: 40),
               ElevatedButton(
                  onPressed: _goHome,
                  child: const Text("Вернуться в главное меню"),
               )
            ],
         ),
      );
   }


   void _showRoleInfo(int number) {
    final info = KnowledgeService.getRoleInfo(number);
    final name = info['role_name'] ?? 'Роль $number';
    final description = info['description'] ?? 'Описание отсутствует';
    
    final keyQuality = info['role_key'] ?? '';
    final strength = info['role_strength'] ?? '';
    final challenge = info['role_challenge'] ?? '';
    final roleInLife = info['role_inlife'] ?? '';
    final roleQuestion = info['role_question'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$number. $name'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
               if (keyQuality.isNotEmpty) 
                  Text(keyQuality, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
               const SizedBox(height: 10),
               const Text("Описание:", style: TextStyle(fontWeight: FontWeight.bold)),
               Text(description),
               const SizedBox(height: 10),

               if (strength.isNotEmpty) ...[
                  const Text("Сила:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text(strength),
                  const SizedBox(height: 8),
               ],
               
               if (challenge.isNotEmpty) ...[
                  const Text("Вызов:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  Text(challenge),
                  const SizedBox(height: 8),
               ],
               
               if (roleInLife.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text("Проявляется в жизни:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  Text(roleInLife),
                  const SizedBox(height: 8),
               ],
               
               if (roleQuestion.isNotEmpty) ...[
                  const Divider(),
                  const Text("Вопрос для рефлексии:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  Text(roleQuestion, style: const TextStyle(fontStyle: FontStyle.italic)),
               ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _selectedRole = number;
              });
              
              if (_targetGameId.isNotEmpty) {
                  await _firestoreService.updateParticipantRole(_targetGameId, number);
                  if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Выбрана роль: $name')));
                  }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Выбрать роль'),
          ),
        ],
      ),
    );
  }

  void _showEndSessionDialog() {
      showDialog(
         context: context,
         builder: (c) => AlertDialog(
            title: const Text("Завершить сессию?"),
            content: const Text("Результаты будут сохранены в истории, а все участники вернутся в лобби."),
            actions: [
               TextButton(onPressed: () => Navigator.pop(c), child: const Text("Отмена")),
               ElevatedButton(
                  onPressed: () {
                     Navigator.pop(c);
                     _firestoreService.archiveGame(_targetGameId);
                  },
                  child: const Text("Завершить"),
               )
            ],
         )
      );
   }

   void _showEndRoundDialog() {
       showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF1E293B),
             title: const Text("Завершить кон?", style: TextStyle(color: Colors.white)),
             content: const Text("Все текущие голоса будут занесены в статистику, а выборы (роли и голоса) будут сброшены для следующего кона.", style: TextStyle(color: Colors.white70)),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                   onPressed: () async {
                      Navigator.pop(ctx);
                      await _firestoreService.endRound(_targetGameId);
                   },
                   child: const Text("Завершить", style: TextStyle(color: Colors.black))
                )
             ],
          )
       );
   }

   void _showEndGameDialog() {
       showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF1E293B),
             title: const Text("Завершить игру?", style: TextStyle(color: Colors.white)),
             content: const Text("Игра будет остановлена, и всем участникам будет показана итоговая статистика.", style: TextStyle(color: Colors.white70)),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                   onPressed: () async {
                      Navigator.pop(ctx);
                      await _firestoreService.finishGame(_targetGameId);
                   },
                   child: const Text("Финиш", style: TextStyle(color: Colors.white))
                )
             ],
          )
       );
   }
   }

