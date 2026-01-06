import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../utils/zoom_js.dart' as zoom_js;
import '../utils/registry.dart'; 
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/config_service.dart';
import '../services/knowledge_service.dart';
import '../models/calculation.dart';
import 'package:intl/intl.dart';
import 'active_game_screen.dart';

class GameScreen extends StatefulWidget {
  final String? gameId;
  const GameScreen({super.key, this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _telegramController = TextEditingController();
  String _gender = 'М';
  
  bool _isLoading = true;
  Calculation? _gameProfile;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Game State
  String? _targetGameId;
  String? _targetGameTitle;
  String? _targetGameDate;
  String? _targetHostName;
  bool _isHost = false; 
  String _gameStage = 'selection'; // selection, voting
  String _gameStatus = 'active'; // active, finished
  Map<String, dynamic> _gameStats = {};
  String? _zoomId;
  String? _zoomPassword;

  // Registration State
  String? _participantStatus; // 'pending', 'approved', null
  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  StreamSubscription<QuerySnapshot>? _participantSubscription;
  int? _selectedRole;
  
  bool _isVideoActive = false; 
  String _roomName = '';
  int? _playerNumber; // 1-8
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _registerZoomViewFactory();
    _loadProfile();
    _checkHostStatus();
    
    if (widget.gameId != null) {
       _targetGameId = widget.gameId;
       _initGameListeners();
    } else {
       _initGameListeners();
    } else {
       _loadGameSession();
    }
  }
  
  @override
  void dispose() {
      _gameSubscription?.cancel();
      _participantSubscription?.cancel();
      // Zoom cleanup handled in ActiveGameScreen
      _nameController.dispose();
      _telegramController.dispose();
      super.dispose();
  }

  bool _showGameSelection = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _availableGames = [];

  Future<void> _loadGameSession() async {
      String? lastGameId;
      try {
         // Attempt to restore session
         lastGameId = DatabaseService().settingsBox.get('active_game_id');
      } catch (_) {}
      
      final snapshot = await _firestoreService.getGamesStream().first;
      final games = snapshot.docs;
      
      if (games.isEmpty) {
         if (mounted) setState(() {});
         return;
      }
      
      _availableGames = games;

      // Client-side sorting
      games.sort((a, b) {
          final d1 = a.data()['scheduledAt'] ?? '';
          final d2 = b.data()['scheduledAt'] ?? '';
          return d1.compareTo(d2);
      });

      QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
      
      // 1. Try to restore specific session
      if (lastGameId != null && games.any((g) => g.id == lastGameId)) {
         targetDoc = games.firstWhere((g) => g.id == lastGameId);
      } 
      // 2. Auto-join if only one game
      else if (games.length == 1) {
         targetDoc = games.first;
      } 
      // 3. Fallback to selection
      else {
          if (mounted) {
             setState(() {
                _showGameSelection = true;
                // If restore failed (game finished/archived?), clear the pref
                if (lastGameId != null) {
                   DatabaseService().settingsBox.delete('active_game_id');
                }
             });
          }
          return;
      }
      
      if (targetDoc != null) {
         _selectGame(targetDoc.id, targetDoc.data());
      }
  }

  void _selectGame(String gameId, Map<String, dynamic> data) {
      if (mounted) {
         setState(() {
            _targetGameId = gameId;
            _targetGameTitle = data['title'];
            final ts = data['scheduledAt'] as Timestamp?;
            _targetGameDate = ts != null ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate()) : null;
            _targetHostName = data['hostName'];
            _zoomId = data['zoomId'];
            _zoomPassword = data['zoomPassword'];
         });
         _initGameListeners();
      }
  }

  void _initGameListeners() {
      if (_targetGameId == null) return;
      _listenToGameStage();
      _checkParticipantStatus();
  }

  void _listenToGameStage() {
     _gameSubscription?.cancel();
     if (_targetGameId == null) return;
     
     _gameSubscription = _firestoreService.getGameStream(_targetGameId!).listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data != null) {
           if (mounted) setState(() {
             _gameStage = data['stage'] ?? 'selection';
             _gameStatus = data['status'] ?? 'active';
             _gameStats = data['stats'] ?? {};
             _zoomId = data['zoomId'];
             _zoomPassword = data['zoomPassword'];
           });
        }
     }, onError: (e) {
         debugPrint("Game Stream Error: $e");
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка связи с игрой: $e")));
     });
  }



  void _checkParticipantStatus() {
     _participantSubscription?.cancel();
     final user = FirebaseAuth.instance.currentUser;
     if (user == null || _targetGameId == null) return;
     
     setState(() => _isCheckingStatus = true); // Start loading

     _participantSubscription = _firestoreService.getGameParticipantsStream(_targetGameId!).listen((event) {
        final me = event.docs.where((d) => d.id == user.uid).firstOrNull;
        if (mounted) {
           setState(() {
              _isCheckingStatus = false; // Stop loading
              _participantStatus = me?.data()['status'];
              _playerNumber = me?.data()['playerNumber'];
               _selectedRole = me?.data()['selectedRole'];
           });
           
           if (_participantStatus == 'approved') {
               // Auto-refresh UI or trigger notification if needed
           }
        }
     }, onError: (e) {
        debugPrint("Participant Stream Error: $e");
        if (mounted) {
           setState(() => _isCheckingStatus = false);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка обновления статуса: $e")));
        }
     });
  }

  // ... Host Check ...

  // ... Profile Load ...

  // ... Save Profile ...
  
  // ... _buildSetupForm ...
  
  // ... _buildRolesGrid ...

  // ... _buildVotingBoard ...

  @override
  Widget build(BuildContext context) {
      if (_showGameSelection) {
         return _buildGameSelectionScreen();
      }

      // Main Lobby View
      return Scaffold(
        extendBodyBehindAppBar: true, 
        appBar: _gameProfile == null 
          ? AppBar(title: const Text('Загрузка...'), backgroundColor: Colors.transparent, elevation: 0) 
          : null,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            )
          ),
          child: SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : (_gameStatus == 'archived' && !_isHost
                  ? _buildGameSelectionScreen() // Or archived view
                  : (_gameProfile == null ? _buildSetupForm() : _buildLobbyUI())),
          ),
        ),
      );
  }

  Widget _buildLobbyUI() {
     // Check if Host
     if (_isHost && _targetGameId != null) {
        return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 60),
                 const SizedBox(height: 20),
                 Text("Ведущий игры: ${_targetGameTitle ?? '...'}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                 const SizedBox(height: 30),
                 ElevatedButton(
                    style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                       backgroundColor: Colors.blueAccent
                    ),
                    onPressed: _openActiveGame,
                    child: const Text("ВОЙТИ В ИГРУ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 ),
                 const SizedBox(height: 20),
                 TextButton(
                    onPressed: () => setState(() => _showGameSelection = true),
                    child: const Text("Выбрать другую игру/Создать", style: TextStyle(color: Colors.white54)),
                 )
              ],
           ),
        );
     }
     
     // Participant
     return _buildTopPanel();
  }

  void _openActiveGame() {
     if (_targetGameId == null) return;
     
     Navigator.of(context).push(
        MaterialPageRoute(
           builder: (_) => ActiveGameScreen(
              gameId: _targetGameId!, 
              gameProfile: _gameProfile,
              isHost: _isHost,
              initialRoomName: _roomName,
           )
        )
     );
  }
  
  Widget _buildHostDashboard() {
     // Host Dashboard: Grid of Players based on stage
     return Column(
        children: [
           // Host Top Bar Controls
           Container(
             color: Colors.black45,
             padding: const EdgeInsets.all(8),
             child: Row(
               children: [
                 IconButton(
                    icon: const Icon(Icons.home, color: Colors.white70, size: 20),
                    tooltip: 'Выйти в меню',
                    onPressed: () => setState(() => _showGameSelection = true),
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
                       _firestoreService.updateGameStage(_targetGameId!, newStage);
                       setState(() => _gameStage = newStage);
                    },
                    color: Colors.white60,
                    selectedColor: Colors.white,
                    fillColor: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Выбор")),
                       Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Голосование")),
                    ],
                 )
               ],
             ),
           ),
           Expanded(
           child: _gameStatus == 'finished' ? _buildFinalResults() : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
                builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   final docs = snapshot.data!.docs.toList();
                   // Prioritize pending requests
                   docs.sort((a, b) {
                      final sA = a.data()['status'] ?? '';
                      final sB = b.data()['status'] ?? '';
                      if (sA == 'pending' && sB != 'pending') return -1;
                      if (sA != 'pending' && sB == 'pending') return 1;
                      return 0;
                   });
                   
                   return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 8, mainAxisSpacing: 8
                      ),
                      itemCount: docs.length,
                       itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final name = data['name'] ?? 'Unknown';
                          final pNum = data['playerNumber'];
                          final roleId = data['selectedRole'];
                          final numbers = List<int>.from(data['numbers'] ?? []);
                          final status = data['status'];
                          final votedForId = data['votedFor'];
                          
                          // Find target player name for voting display
                          String votedForName = "...";
                          if (votedForId != null) {
                             final target = docs.where((d) => d.id == votedForId).firstOrNull;
                             if (target != null) {
                                final tData = target.data();
                                votedForName = tData['playerNumber'] != null ? "Игрок ${tData['playerNumber']}" : tData['name'];
                             }
                          }

                          return Card(
                             clipBehavior: Clip.antiAlias,
                             color: status == 'pending' ? Colors.orange.withOpacity(0.15) : Colors.white12,
                             shape: status == 'pending' 
                                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.orangeAccent, width: 1))
                                : null,
                             child: Stack(
                                children: [
                                   // Semi-transparent background of selected role (visible in BOTH modes)
                                   if (roleId != null)
                                      Positioned.fill(
                                         child: Opacity(
                                            opacity: 0.15, // Slightly less for host dashboard clarity
                                            child: Image.asset(
                                               'assets/images/cards/role_$roleId.png',
                                               fit: BoxFit.cover,
                                               errorBuilder: (c, e, s) => Container(),
                                            )
                                         )
                                      ),
                                   
                                   Center(
                                     child: Column(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [
                                          // Header: Number + Name
                                          if (pNum != null)
                                             CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Text("$pNum", style: const TextStyle(fontSize: 12, color: Colors.white))),
                                          const SizedBox(height: 4),
                                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                          const Spacer(),
                                          if (status == 'pending') ...[
                                                  FutureBuilder<DocumentSnapshot>(
                                                     future: FirebaseFirestore.instance.collection('users').doc(data['userId'] ?? 'unknown').get(),
                                                     builder: (context, snapshot) {
                                                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                                                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                                        final telegram = userData?['telegram'] as String?;
                                                        
                                                        if (telegram != null && telegram.isNotEmpty) {
                                                            return TextButton.icon(
                                                                icon: const Icon(Icons.alternate_email, size: 14, color: Colors.blueAccent),
                                                                label: const Text("Написать", style: TextStyle(color: Colors.blueAccent, fontSize: 10)),
                                                                onPressed: () {
                                                                    String tg = telegram.replaceAll('@', '');
                                                                    launchUrl(Uri.parse("https://t.me/$tg"));
                                                                },
                                                            );
                                                        } else {
                                                            return const Text("Telegram: не указан", style: TextStyle(color: Colors.white30, fontSize: 10));
                                                        }
                                                     }
                                                  ),
                                              Row(
                                                 mainAxisAlignment: MainAxisAlignment.center,
                                                 children: [
                                                    ElevatedButton(
                                                       style: ElevatedButton.styleFrom(
                                                          minimumSize: const Size(0,30), 
                                                          backgroundColor: Colors.green,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8)
                                                       ),
                                                       onPressed: () => _firestoreService.approveParticipant(_targetGameId!, docs[index].id),
                                                       child: const Text("Принять", style: TextStyle(fontSize: 10))
                                                    ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                       icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                                       onPressed: () => _firestoreService.rejectParticipant(_targetGameId!, docs[index].id),
                                                    )
                                                 ],
                                              )
                                          ]
                                          else if (_gameStage == 'selection') ...[
                                              // Show Diagnostic Card preview link
                                              if (numbers.isNotEmpty)
                                                 TextButton(
                                                    onPressed: () => _showDiagnosticCard(numbers, name),
                                                    child: const Text("Карта", style: TextStyle(color: Colors.blueAccent, fontSize: 12, decoration: TextDecoration.underline))
                                                 ),
                                              const SizedBox(height: 4),
                                              if (roleId != null) 
                                                 Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                                    child: Text("#$roleId", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))
                                                 )
                                              else
                                                 const Text("Выбирает...", style: TextStyle(color: Colors.white54, fontSize: 10))
                                          ] else ...[
                                              // Voting Mode: Show who they voted for
                                              if (roleId != null)
                                                 Text("#$roleId", style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                                              
                                              const SizedBox(height: 4),
                                              if (votedForId != null)
                                                 Container(
                                                     padding: const EdgeInsets.all(4),
                                                     decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                                     child: Text("Голос за: \n$votedForName", textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent, fontSize: 9))
                                                 )
                                              else
                                                 const Text("Не голосовал", style: TextStyle(color: Colors.white38, fontSize: 9)),
                                          ],
                                          const Spacer(),
                                       ],
                                     ),
                                   ),
                                ],
                             ),
                          );
                       },
                   );
                },
             ),
           )
        ],
     );
  }

  Widget _buildTopPanel() {
    if (_targetGameId == null) {
      // No game found - Show "No scheduled games"
      return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 50, color: Colors.white54),
                  const SizedBox(height: 20),
                  const Text("Нет ближайших игр", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                     onPressed: _loadGameSession,
                     child: const Text("Обновить"),
                  )
                ],
              ),
            );
    }
    
    // Game Session Mode
    if (_participantStatus == 'approved') {
       if (_playerNumber == null) {
          // Need to choose number
          return _buildNumberSelection();
       }
       
       // Ready to Enter
       return Center(
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                const Icon(Icons.play_circle_fill, color: Colors.green, size: 80),
                const SizedBox(height: 20),
                Text("Вы в игре: ${_targetGameTitle ?? ''}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 30),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      backgroundColor: Colors.green
                   ),
                   onPressed: _handleEnterGame,
                   child: const Text("ВОЙТИ В ИГРУ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _showGameSelection = true),
                  child: const Text("Выбрать другую игру", style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline))
                )
             ],
          ),
       );
    } else if (_participantStatus == 'pending') {
      return Center(
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.access_time, size: 50, color: Colors.orange),
             const SizedBox(height: 20),
             const Text("Заявка отправлена", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             
             // ... Same pending UI ...
             const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Ожидайте подтверждения ведущего...", style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
             ),
             TextButton.icon(
                onPressed: _checkParticipantStatus,
                icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                label: const Text("Проверить статус", style: TextStyle(color: Colors.blueAccent)),
             )
           ],
        ),
      );
    } else {
      // Not registered or Checking
      return Center(
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text(_targetGameTitle ?? "Игра: $_targetGameId", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             if (_targetGameDate != null) ...[
                 const SizedBox(height: 8),
                 Text("Дата: $_targetGameDate", style: const TextStyle(color: Colors.white70)),
             ],
             if (_targetHostName != null) ...[
                 const SizedBox(height: 4),
                 Text("Ведущий: $_targetHostName", style: const TextStyle(color: Colors.orangeAccent)),
             ],
             const SizedBox(height: 20),
             
             if (_isCheckingStatus)
                const Column(
                   children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text("Проверка статуса...", style: TextStyle(color: Colors.white54))
                   ],
                )
             else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () async {
                      // Pass Numbers now!
                      await _firestoreService.joinGameRequest(_targetGameId!, _gameProfile!.name, _gameProfile!.telegram, _gameProfile!.numbers); 
                      setState(() {
                        _participantStatus = 'pending';
                      });
                  },
                  child: const Text("Подать заявку", style: TextStyle(fontSize: 16)),
                ),
             
             const SizedBox(height: 12),
             TextButton(
                onPressed: () {
                    setState(() {
                        _showGameSelection = true;
                    });
                },
                child: const Text("Выбрать другую игру", style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline))
             )
           ],
        ),
      );
    }
  }

  void _handleEnterGame() {
    if (_targetGameId == null) return;
    
    // Save session for reconnection
    DatabaseService().settingsBox.put('active_game_id', _targetGameId);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActiveGameScreen(
         gameId: _targetGameId!, 
         isHost: _isHost, 
         playerNumber: _playerNumber,
         selectedRole: _selectedRole, 
         zoomId: _zoomId,
         zoomPassword: _zoomPassword,
      )),
    );
  }

  Widget _buildNumberSelection() {
     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
        builder: (context, snapshot) {
           final usedNumbers = <int>{};
           if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                 if (doc.data()['playerNumber'] != null) {
                    usedNumbers.add(doc.data()['playerNumber']);
                 }
              }
           }
           
           return Center(
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const Text("Выберите свой номер игрока (1-10)", style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 20),
                    Container(
                      width: 350, // Constraint width to ensure good look or just let Grid take space
                      height: 180,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5, childAspectRatio: 1.0, crossAxisSpacing: 10, mainAxisSpacing: 10,
                        ),
                        itemCount: 10,
                        itemBuilder: (context, index) {
                           final num = index + 1;
                           final isTaken = usedNumbers.contains(num);
                           return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                 backgroundColor: isTaken ? Colors.grey : Colors.blue,
                                 shape: const CircleBorder(),
                                 padding: EdgeInsets.zero, // Compact
                              ),
                              onPressed: isTaken ? null : () async {
                                 await _firestoreService.setPlayerNumber(_targetGameId!, num);
                                 setState(() {
                                    _playerNumber = num;
                                 });
                              },
                              child: Text("$num", style: const TextStyle(fontWeight: FontWeight.bold)),
                           );
                        },
                      ),
                    )
                 ],
              ),
           );
        }
     );
  }

  Future<void> _checkHostStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final role = data['role'];
        final pgmd = data['pgmd'];
        final isHostMode = data['isHostMode'] ?? false;
        
        // Allow if Admin or Diagnost-Host (>= 10) AND Host Mode is enabled
        final hasRights = role == 'admin' || (pgmd != null && pgmd >= 10);
        
        if (hasRights && isHostMode) {
           if (mounted) setState(() => _isHost = true);
        } else {
           if (mounted) setState(() => _isHost = false);
        }
      }
    } catch (e) {
      debugPrint("Error checking host status: $e");
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _firestoreService.getGameProfile();
      if (mounted) {
        setState(() {
          _gameProfile = profile;
          if (profile != null) {
            _nameController.text = profile.name;
            _dateController.text = profile.birthDate;
            _telegramController.text = profile.telegram ?? '';
            _gender = profile.gender;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final name = _nameController.text;
      final date = _dateController.text; 
      final telegram = _telegramController.text;
      
      try {
        final numbers = CalculatorService.calculateDiagnostic(date, name, _gender);
        final calc = Calculation(
          name: name,
          birthDate: date,
          gender: _gender,
          numbers: numbers,
          createdAt: DateTime.now(),
          telegram: telegram,
        );

        await _firestoreService.saveGameProfile(calc);
        if (mounted) {
          setState(() {
            _gameProfile = calc;
            _isLoading = false;
          });
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
           setState(() => _isLoading = false);
         }
      }
    }
  }
  
  Widget _buildSetupForm() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Настройка профиля игры", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Введите имя' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                   controller: _dateController,
                   decoration: const InputDecoration(labelText: 'Дата рождения (ДД.ММ.ГГГГ)', prefixIcon: Icon(Icons.calendar_today), hintText: '01.01.2000'),
                   keyboardType: TextInputType.datetime,
                   onChanged: (value) {
                      String newText = value.replaceAll(RegExp(r'[\/,\-]'), '.');
                      if (RegExp(r'^\d{8}$').hasMatch(newText)) {
                          newText = '${newText.substring(0, 2)}.${newText.substring(2, 4)}.${newText.substring(4)}';
                      }
                      if (newText != value) {
                        _dateController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
                      }
                   },
                   validator: (value) => !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(value ?? '') ? 'Формат ДД.ММ.ГГГГ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                   controller: _telegramController,
                   decoration: const InputDecoration(labelText: 'Telegram (напр. @username)', prefixIcon: Icon(Icons.alternate_email)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Пол:'),
                    const SizedBox(width: 20),
                    ChoiceChip(label: const Text('М'), selected: _gender == 'М', onSelected: (s) => setState(() => _gender = 'М')),
                    const SizedBox(width: 10),
                    ChoiceChip(label: const Text('Ж'), selected: _gender == 'Ж', onSelected: (s) => setState(() => _gender = 'Ж')),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: const Text("Войти в игру"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRolesGrid() {
    final Set<int> uniqueNumbers = {};
    if (_gameProfile != null) {
      for (var n in _gameProfile!.numbers) {
        uniqueNumbers.add(n == 0 ? 22 : n);
      }
    }
    final sortedNumbers = uniqueNumbers.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              elevation: isSelected ? 8 : 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/images/cards/role_$number.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
                  Container(
                    color: isSelected ? Colors.orange : Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$number',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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
      if (_targetGameId == null) return const Center(child: Text("Нет активной игры"));
      
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
         builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final participants = snapshot.data!.docs;
            final String? myUid = FirebaseAuth.instance.currentUser?.uid;
            final myDoc = participants.where((d) => d.id == myUid).firstOrNull;
            final String? myVoteId = myDoc?.data()['votedFor'];
            
            return Column(
               children: [
                 const Padding(
                   padding: EdgeInsets.all(8.0),
                   child: Text("Голосование", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                 ),
                 Expanded(
                   child: GridView.builder(
                     padding: const EdgeInsets.all(12),
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3,
                       childAspectRatio: 0.7,
                       crossAxisSpacing: 10,
                       mainAxisSpacing: 10,
                     ),
                     itemCount: participants.length,
                     itemBuilder: (context, index) {
                        final pData = participants[index].data();
                        final pUid = participants[index].id;
                        final pNum = pData['playerNumber'];
                        final pName = pData['name'] ?? '...';
                        final pRoleId = pData['selectedRole'];
                        
                        final bool isSelected = myVoteId == pUid;
                        final bool isMe = myUid == pUid;

                        return GestureDetector(
                           onTap: () {
                              if (isSelected) {
                                 _firestoreService.clearVote(_targetGameId!);
                              } else {
                                 _firestoreService.voteForPlayer(_targetGameId!, pUid);
                              }
                           },
                           child: Container(
                              decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(
                                    color: isSelected ? Colors.green : (isMe ? Colors.white24 : Colors.transparent),
                                    width: 3
                                 ),
                                 boxShadow: isSelected ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 8)] : null,
                              ),
                              child: Card(
                                 clipBehavior: Clip.antiAlias,
                                 elevation: isSelected ? 8 : 2,
                                 color: isMe ? Colors.white12 : Colors.white10,
                                 child: Stack(
                                    children: [
                                       // Semi-transparent role background
                                       if (pRoleId != null)
                                          Positioned.fill(
                                             child: Opacity(
                                                opacity: 0.2,
                                                child: Image.asset(
                                                   'assets/images/cards/role_$pRoleId.png',
                                                   fit: BoxFit.cover,
                                                   errorBuilder: (c, e, s) => Container(),
                                                )
                                             )
                                          ),
                                       
                                       Center(
                                          child: Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                                if (pNum != null)
                                                   CircleAvatar(
                                                      radius: 12,
                                                      backgroundColor: isSelected ? Colors.green : Colors.white24,
                                                      child: Text("$pNum", style: const TextStyle(fontSize: 12, color: Colors.white)),
                                                   ),
                                                const SizedBox(height: 5),
                                                Text(pName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                if (isSelected)
                                                   const Padding(
                                                      padding: EdgeInsets.only(top: 4),
                                                      child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                   ),
                                             ],
                                          )
                                       ),
                                    ],
                                 ),
                              ),
                           ),
                        );
                     },
                   ),
                 ),
               ],
            );
         }
      );
  }



  // ... _buildSetupForm ...

  Widget _buildSplitScreenGame() {
    return Column(
      children: [
        // Top Section: Registration / Status / Video
        Expanded(
          flex: 5,
          child: Stack(
            children: [
               // Background Role Card for UI
               if (_selectedRole != null)
                  Positioned.fill(
                     child: Opacity(
                        opacity: 0.2, // Subtle background
                        child: Image.asset(
                           'assets/images/cards/role_$_selectedRole.png',
                           fit: BoxFit.cover,
                           errorBuilder: (c, e, s) => Container(),
                        )
                     )
                  ),
               Container(
                 color: Colors.black54, // Semi-transparent overlay for readability
                 child: _buildTopPanel(),
               ),
            ],
          ),
        ),
        
        const Divider(height: 1, thickness: 1, color: Colors.grey),

        // Roles Section
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.transparent, 
            child: Column(
              children: [
                 if (_gameStatus == 'finished')
                    Expanded(child: _buildFinalResults())
                 else if (_gameStage == 'voting')
                    Expanded(child: _buildVotingBoard())
                 else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Align(
                             alignment: Alignment.center,
                             child: Text("Мои Роли", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          ),
                          Align(
                             alignment: Alignment.centerRight,
                             child: IconButton(
                                icon: const Icon(Icons.home, color: Colors.white70),
                                onPressed: () {
                                   if (mounted) setState(() => _showGameSelection = true);
                                },
                             ),
                          )
                        ],
                      ),
                    ),
                    Expanded(child: _buildRolesGrid()),
                 ]
              ],
            ),
          ),
        ),
        // Spacer to lift content above bottom nav if needed, or user wants it removed.
        // We can't remove the nav easily, but we gave them more space.
          TextButton(
            onPressed: () => setState(() => _showGameSelection = true),
            child: const Text("Выбрать другую игру", style: TextStyle(color: Colors.blueAccent)),
          )
        ],
    );
  }



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
        ],
      ),
    );
  }


  void _registerZoomViewFactory() {
    if (kIsWeb) {
      registerZoomViewFactory('zoom-container');
    }
  }

  Widget _buildVideoOffPlaceholder() {
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
          )
        ],
      ),
    );
  }

  void _connectToZoom() {
      if (_zoomId == null || _zoomId!.isEmpty) return;
      
      setState(() => _isVideoActive = true);
      
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? _nameController.text.split(' ')[0] ?? "Player";

      // Call JS init
      Future.delayed(const Duration(milliseconds: 500), () {
          zoom_js.initZoom(
              _zoomId!, 
              _zoomPassword ?? "", 
              userName,
              ConfigService().zoomKey,
              ConfigService().zoomSecret
          );
      });
  }

  // GlobalKey to preserve the platform view across builds
  final GlobalKey _zoomViewKey = GlobalKey();

  Widget _buildZoomPanel() {
    if (!_isVideoActive) return _buildVideoOffPlaceholder();

    return Stack(
      children: [
        HtmlElementView(
          key: _zoomViewKey, // GlobalKey prevents unmounting during SetState
          viewType: 'zoom-container',
        ),
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
            onPressed: () {
               zoom_js.leaveZoom();
               setState(() => _isVideoActive = false);
            },
          ),
        ),
        if (_zoomId == null || _zoomId!.isEmpty)
           const Center(child: Text("Zoom ID не указан ведущим", style: TextStyle(color: Colors.white54))),
      ],
    );
  }
  // ... _buildRolesGrid ...

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
              
              if (_targetGameId != null) {
                  // Sync selection
                  await _firestoreService.updateParticipantRole(_targetGameId!, number);
                  if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Выбрана роль: $name (Отправлено ведущему)')));
                  }
              } else {
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


  
  void _showDiagnosticCard(List<int> numbers, String name) {
     int n(int idx) => (idx < numbers.length) ? (numbers[idx] == 0 ? 22 : numbers[idx]) : 22;

     showDialog(
       context: context,
       builder: (context) => Dialog(
         backgroundColor: Colors.transparent,
         child: Container(
           width: 380, // Mimicking mobile/sheet width
           height: 550,
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: const Color(0xFF0F172A),
             borderRadius: BorderRadius.circular(24),
             border: Border.all(color: Colors.white24),
             image: const DecorationImage(
                image: AssetImage('assets/images/IDPGMD092025.png'),
                opacity: 0.1, // Using it as background template reference
                fit: BoxFit.cover,
             ),
             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 30)],
           ),
           child: Column(
             children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
                   ],
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                   child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                         children: [
                             Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Expanded(flex: 3, child: _buildSheetSection("ФАЗЫ ЖИЗНИ", [n(0), n(1), n(2)])),
                                   Expanded(flex: 1, child: _buildSheetSection("ТОЧКА ВХОДА", [n(3)])),
                                ],
                             ),
                             Row(
                                children: [
                                   Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ИНЬ", [n(4), n(5)])),
                                   Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ЯН", [n(6), n(7)])),
                                ],
                             ),
                             Row(
                                children: [
                                   Expanded(child: _buildSheetSection("МОТИВ", [n(8)])),
                                   Expanded(child: _buildSheetSection("МЕТОД", [n(9)])),
                                   Expanded(child: _buildSheetSection("СФЕРА", [n(10)])),
                                ]
                             ),
                             Row(
                                children: [
                                   Expanded(child: _buildSheetSection("СТРАХИ", [n(11)])),
                                   Expanded(child: _buildSheetSection("БАЛАНС", [n(13)])),
                                   Expanded(child: _buildSheetSection("ТОЧКА ВЫХОДА", [n(12)])),
                                ],
                             ),
                         ],
                      ),
                   )
                ),
             ],
           ),
         ),
       ),
     );
  }

  Widget _buildSheetSection(String title, List<int> cardNums) {
     return Column(
        children: [
           Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
           ),
           Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: cardNums.map((num) => Container(
                 width: 55,
                 height: 78,
                 margin: const EdgeInsets.symmetric(horizontal: 4),
                 decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12, width: 0.5),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                 ),
                 child: Stack(
                    children: [
                       ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                             'assets/images/cards/role_$num.png',
                             fit: BoxFit.cover,
                             errorBuilder: (c, e, s) => Container(color: Colors.white.withOpacity(0.05), child: Center(child: Text("$num", style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                          ),
                       ),
                       Positioned(
                          bottom: 0, right: 0, left: 0,
                          child: Container(
                             decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                             ),
                             padding: const EdgeInsets.symmetric(vertical: 1),
                             child: Text("$num", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                       ),
                    ],
                 ),
              )).toList(),
           ),
        ],
     );
  }

  void _showRoomDialog() async {
    final controller = TextEditingController(text: _roomName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Введите название комнаты'),
        content: TextField(
           controller: controller,
           decoration: const InputDecoration(labelText: 'Room Name', hintText: 'IdPotentialGame'),
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
           ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('ОК')),
        ]
      )
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _roomName = result;
        _isVideoActive = false;
      });
    }
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
                     await _firestoreService.endRound(_targetGameId!);
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
                     await _firestoreService.finishGame(_targetGameId!);
                  },
                  child: const Text("Финиш", style: TextStyle(color: Colors.white))
               )
            ],
         )
      );
  }

  Widget _buildFinalResults() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
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
                     if (_isHost)
                        Padding(
                           padding: const EdgeInsets.only(top: 20),
                           child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
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
               const Text("ИГРА ЗАВЕРШЕНА", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               const Text("Сессия закрыта ведущим", style: TextStyle(color: Colors.white70)),
               const SizedBox(height: 40),
               ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                  child: const Text("Вернуться в главное меню"),
               )
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
                     _firestoreService.archiveGame(_targetGameId!);
                  },
                  child: const Text("Завершить"),
               )
            ],
         )
      );
   }

   Widget _buildGameSelectionScreen() {
      return Scaffold(
         appBar: AppBar(title: const Text("Выберите игру"), backgroundColor: const Color(0xFF0F172A)),
         body: Container(
            color: const Color(0xFF0F172A),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
               stream: _firestoreService.getGamesStream(),
               builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final games = snapshot.data!.docs;
                  if (games.isEmpty) return const Center(child: Text("Нет доступных игр", style: TextStyle(color: Colors.white54)));

                  // Client-side sorting to avoid Firestore Index issues
                  games.sort((a, b) {
                     final d1 = a.data()['scheduledAt'] ?? '';
                     final d2 = b.data()['scheduledAt'] ?? '';
                     return d1.compareTo(d2); // Simple string sort for ISO8601 works
                  });

                  return ListView.builder(
                     itemCount: games.length,
                     itemBuilder: (context, index) {
                        final gameDoc = games[index];
                        final game = gameDoc.data();
                        final gameId = gameDoc.id;
                        final dateStr = game['scheduledAt'];
                        DateTime date = DateTime.now();
                        if (dateStr != null) {
                           if (dateStr is Timestamp) {
                              date = dateStr.toDate();
                           } else {
                              try { date = DateTime.parse(dateStr.toString()); } catch(_) {}
                           }
                        } else if (game['scheduledTimestamp'] != null) { 
                           // Fallback if schema changes
                           date = (game['scheduledTimestamp'] as Timestamp).toDate();
                        }
                        
                        // Defensive check for DateFormat if it was previously string
                         String dateDisplay;
                         try {
                            dateDisplay = DateFormat('dd.MM.yyyy HH:mm').format(date);
                         } catch (e) {
                            dateDisplay = "Дата не указана";
                         }

                        return Card(
                           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                           color: Colors.white10,
                           child: ListTile(
                              leading: const Icon(Icons.videogame_asset, color: Colors.blueAccent),
                              title: Text(game['title'] ?? 'Игра без названия', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    Text(dateDisplay, style: const TextStyle(color: Colors.white70)),
                                    Text("Ведущий: ${game['hostName'] ?? 'Ведущий'}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                 ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                              onTap: () {
                                 if (mounted) {
                                    setState(() {
                                       _targetGameId = gameId;
                                       _targetGameTitle = game['title'];
                                       _zoomId = game['zoomId'];
                                       _zoomPassword = game['zoomPassword'];
                                       _showGameSelection = false;
                                       
                                       // Update date for display in lobby
                                       _targetGameDate = dateDisplay;
                                       _targetHostName = game['hostName'];
                                    });
                                    _initGameListeners();
                                 }
                              },
                           ),
                        );
                     },
                  );
               }
            ),
         ),
      );
   }
}
