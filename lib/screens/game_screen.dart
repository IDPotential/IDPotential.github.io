import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/registry.dart'; // Import registry
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/knowledge_service.dart';
import '../services/knowledge_service.dart';
import '../services/knowledge_service.dart';
import '../models/calculation.dart';

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
  String _gender = 'М';
  
  bool _isLoading = true;
  Calculation? _gameProfile;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Game State
  String? _targetGameId;
  String? _targetGameTitle;
  bool _isHost = false; 
  String _gameStage = 'selection'; // selection, voting

  // Registration State
  String? _participantStatus; // 'pending', 'approved', null
  int? _selectedRole;
  
  bool _isVideoActive = false; 
  String _roomName = '';
  int? _playerNumber; // 1-8

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkHostStatus();
    
    if (widget.gameId != null) {
       _targetGameId = widget.gameId;
       _initGameListeners();
    } else {
       _fetchNearestGame();
    }
  }

  Future<void> _fetchNearestGame() async {
      final gameDoc = await _firestoreService.getNearestGame();
      if (gameDoc != null) {
         if (mounted) {
            setState(() {
               _targetGameId = gameDoc.id;
               _targetGameTitle = gameDoc.data()['title'];
            });
            _initGameListeners();
         }
      } else {
         if (mounted) setState(() {});
      }
  }

  void _initGameListeners() {
      if (_targetGameId == null) return;
      _listenToGameStage();
      _checkParticipantStatus();
  }

  void _listenToGameStage() {
     if (_targetGameId == null) return;
     _firestoreService.getGameStream(_targetGameId!).listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data != null && data['stage'] != null) {
           if (mounted) setState(() => _gameStage = data['stage']);
        }
     });
  }

  void _checkParticipantStatus() {
     final user = FirebaseAuth.instance.currentUser;
     if (user == null || _targetGameId == null) return;
     
     _firestoreService.getGameParticipantsStream(_targetGameId!).listen((event) {
        final me = event.docs.where((d) => d.id == user.uid).firstOrNull;
        if (mounted) {
           setState(() {
              _participantStatus = me?.data()['status'];
              _playerNumber = me?.data()['playerNumber'];
           });
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
      if (_isHost && _targetGameId != null) {
         // Host see split layout
         return Scaffold(
             extendBodyBehindAppBar: true, 
             body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top Section: Video
                      Expanded(
                        flex: 4,
                        child: Container(
                          color: Colors.black87,
                          child: _isVideoActive 
                            ? _buildJitsiIframe() 
                            : _buildVideoPlaceholder(),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Colors.grey),
                      // Bottom Section: Management Dashboard
                      Expanded(
                        flex: 6,
                        child: _buildHostDashboard(),
                      ),
                    ],
                  ),
                )
             )
         );
      }
      
    // Participant View
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
            : (_gameProfile == null ? _buildSetupForm() : _buildSplitScreenGame()),
        ),
      ),
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
                 const Text("Ведущий", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 const Spacer(),
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
             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
                builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   final docs = snapshot.data!.docs;
                   
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
                             color: Colors.white12,
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
                                          if (status == 'pending')
                                              ElevatedButton(
                                                 style: ElevatedButton.styleFrom(minimumSize: const Size(0,30), backgroundColor: Colors.green),
                                                 onPressed: () => _firestoreService.approveParticipant(_targetGameId!, docs[index].id),
                                                 child: const Text("Принять", style: TextStyle(fontSize: 10))
                                              )
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
                     onPressed: _fetchNearestGame,
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
       return _isVideoActive 
          ? _buildJitsiIframe() 
          : _buildVideoPlaceholder();
    } else if (_participantStatus == 'pending') {
      return Center(
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.access_time, size: 50, color: Colors.orange),
             const SizedBox(height: 20),
             const Text("Заявка отправлена", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             
             // ... Same pending UI ...
           ],
        ),
      );
    } else {
      // Not registered
      return Center(
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             // ...
             Text(_targetGameTitle ?? "Игра: $_targetGameId", style: const TextStyle(color: Colors.white70)),
             const SizedBox(height: 20),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 // ...
               ),
               onPressed: () async {
                  // Pass Numbers now!
                  await _firestoreService.joinGameRequest(_targetGameId!, _gameProfile!.name, null, _gameProfile!.numbers); 
                  setState(() {
                    _participantStatus = 'pending';
                  });
               },
               child: const Text("Подать заявку"),
             )
           ],
        ),
      );
    }
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
                    const Text("Выберите свой номер игрока (1-8)", style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 20),
                    Wrap(
                       spacing: 10, runSpacing: 10,
                       alignment: WrapAlignment.center,
                       children: List.generate(8, (index) {
                          final num = index + 1;
                          final isTaken = usedNumbers.contains(num);
                          return ElevatedButton(
                             style: ElevatedButton.styleFrom(
                                backgroundColor: isTaken ? Colors.grey : Colors.blue,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(20)
                             ),
                             onPressed: isTaken ? null : () async {
                                await _firestoreService.setPlayerNumber(_targetGameId!, num);
                                setState(() {
                                   _playerNumber = num;
                                });
                             },
                             child: Text("$num"),
                          );
                       }),
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
        // Only Admin (100) is Host. Diagnost (5) is a participant.
        if (role == 'admin' || pgmd == 100) {
           if (mounted) setState(() => _isHost = true);
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
      
      try {
        final numbers = CalculatorService.calculateDiagnostic(date, name, _gender);
        final calc = Calculation(
          name: name,
          birthDate: date,
          gender: _gender,
          numbers: numbers,
          createdAt: DateTime.now(),
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
          flex: 4,
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
          flex: 6,
          child: Container(
            color: Colors.transparent, 
            child: Column(
              children: [
                 if (_gameStage == 'voting')
                    Expanded(child: _buildVotingBoard())
                 else ...[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Мои Роли", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          if (_selectedRole != null)
                             Chip(
                               label: Text("Выбрано: $_selectedRole"), 
                               backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                               onDeleted: () => setState(() => _selectedRole = null),
                             ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildRolesGrid()),
                 ]
              ],
            ),
          ),
        ),
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
          Text("Комната: ${_roomName.isEmpty ? 'IdPotentialGame' : _roomName}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Text("Подключиться к видео"),
            onPressed: () => setState(() => _isVideoActive = true),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _showRoomDialog,
            child: const Text("Сменить комнату", style: TextStyle(color: Colors.blueAccent)),
          )
        ],
      ),
    );
  }

  Widget _buildJitsiIframe() {
    final String room = _roomName.isEmpty ? 'IdPotentialGame' : _roomName;
    final String viewType = 'jitsi-meet-$room';
    
    // Free Jitsi URL
    final String url = 'https://meet.jit.si/$room';
    
    try {
      registerJitsiViewFactory(viewType, url);
    } catch(e) {
      debugPrint("Registry error: $e");
    }

    return Stack(
      children: [
        HtmlElementView(viewType: viewType),
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
            onPressed: () => setState(() => _isVideoActive = false),
          ),
        )
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
                            _buildSheetSection("ФАЗЫ ЖИЗНИ", [n(0), n(1), n(2)]),
                            _buildSheetSection("ТОЧКА ВХОДА", [n(3)]),
                            Row(
                               children: [
                                  Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ИНЬ", [n(5), n(4)])),
                                  Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ЯН", [n(6), n(7)])),
                               ],
                            ),
                            _buildSheetSection("ЯДРО МОТИВАЦИИ", [n(8)]),
                            _buildSheetSection("РЕАЛИЗАЦИЯ (МЕТОД / СФЕРА)", [n(9), n(10)]),
                            _buildSheetSection("ГАРМОНИЯ", [n(11), n(12), n(13)]),
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
                             errorBuilder: (c, e, s) => Container(color: Colors.white05, child: Center(child: Text("$num", style: const TextStyle(color: Colors.white54, fontSize: 10)))),
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
}
