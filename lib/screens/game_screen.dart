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
  // Registration State
  String? _participantStatus; // 'pending', 'approved', null
  int? _selectedRole; // Restored
  
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

  // ... _fetchNearestGame, _initGameListeners, _listenToGameStage ...

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
         // Host see special layout
         return Scaffold(
             extendBodyBehindAppBar: true, 
             appBar: null, // Host controls everything
             body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
                ),
                child: SafeArea(child: _buildHostDashboard()) 
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
                         
                         return Card(
                            color: Colors.white12,
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
                                      // Show Diagnostic Card preview or placeholder
                                      if (numbers.isNotEmpty)
                                         Text("Код: ${numbers.take(3).join('-')}...", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(height: 4),
                                      if (roleId != null) 
                                         Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                            child: Text("Роль: $roleId", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                                         )
                                      else
                                         const Text("Выбирает...", style: TextStyle(color: Colors.white54, fontSize: 10))
                                  ] else ...[
                                      // Voting Mode: Show Role 
                                      if (roleId != null)
                                         Text("Роль: $roleId", style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold))
                                      else
                                         const Text("?", style: TextStyle(color: Colors.white54))
                                  ],
                                  const Spacer(),
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
                      final data = participants[index].data();
                      final uid = participants[index].id;
                      final name = data['name'] ?? 'Unknown';
                      final roleId = data['selectedRole'];
                      // final myVote = ... if we want to show if I voted
                      
                      return Card(
                         color: Colors.white10,
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                              CircleAvatar(
                                radius: 25, 
                                backgroundColor: Colors.purple.withOpacity(0.3),
                                child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(height: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              if (roleId != null)
                                 Text("Роль: $roleId", style: const TextStyle(color: Colors.orangeAccent)),
                              
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  minimumSize: const Size(0, 30),
                                ),
                                onPressed: () {
                                   _firestoreService.voteForPlayer(_targetGameId!, uid);
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Голос за $name учтен')));
                                },
                                child: const Text("Голос", style: TextStyle(fontSize: 12)),
                              )
                           ],
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

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton: (_isHost && _targetGameId != null) 
          ? FloatingActionButton(
              onPressed: _showHostPanel,
              backgroundColor: Colors.purple,
              child: const Icon(Icons.group),
            )
          : null,
    );
  }

  // ... _buildSetupForm ...

  Widget _buildSplitScreenGame() {
    return Column(
      children: [
        // Top Section: Registration / Status / Video
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black87,
            child: _buildTopPanel(),
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

  Widget _buildTopPanel() {
    if (_targetGameId == null) {
      // No game found - Show "No scheduled games" or Training Mode
      return _isVideoActive 
          ? _buildJitsiIframe() 
          : Center(
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
    if (_participantStatus == 'approved' || _isHost) {
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
             const SizedBox(height: 10),
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 30),
               child: Text("Ожидайте подтверждения ведущего. Вы можете написать администратору в Telegram.", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
             ),
             const SizedBox(height: 20),
             ElevatedButton.icon(
               icon: const Icon(Icons.send),
               label: const Text("Написать в Telegram"),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
               onPressed: () => launchUrl(Uri.parse('https://t.me/id_potential_support'), mode: LaunchMode.externalApplication), // Replace with actual support/host link
             )
           ],
        ),
      );
    } else {
      // Not registered
      return Center(
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.sports_esports, size: 50, color: Colors.greenAccent),
             const SizedBox(height: 20),
             const Text("Регистрация на игру", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             Text(_targetGameTitle ?? "Игра: $_targetGameId", style: const TextStyle(color: Colors.white70)),
             const SizedBox(height: 20),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
               ),
               onPressed: () async {
                  await _firestoreService.joinGameRequest(_targetGameId!, _gameProfile!.name, null); // Telegram handle not stored in profile currently
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

  void _showHostPanel() {
    if (_targetGameId == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("Управление Игрой", 
                         style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                       ),
                       IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                ),
                // Toggle Stage
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                     children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                               backgroundColor: _gameStage == 'selection' ? Colors.blue : Colors.blueGrey
                            ),
                            onPressed: () {
                               _firestoreService.updateGameStage(_targetGameId!, 'selection');
                                setSheetState(() {});
                               // Main set state handled by stream listener
                            },
                            child: const Text("Выбор роли"),
                          )
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                               backgroundColor: _gameStage == 'voting' ? Colors.purple : Colors.blueGrey
                            ),
                            onPressed: () {
                               _firestoreService.updateGameStage(_targetGameId!, 'voting');
                               setSheetState(() {});
                            },
                            child: const Text("Голосование"),
                          )
                        ),
                     ],
                  ),
                ),
                
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.getGameParticipantsStream(_targetGameId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text("Нет участников", style: TextStyle(color: Colors.white54)));
                      
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final userId = docs[index].id;
                          final name = data['name'] ?? 'Unknown';
                          final status = data['status'] ?? 'pending';
                          final roleId = data['selectedRole'];
                          
                          return Card(
                            color: Colors.white10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: status == 'approved' ? Colors.green : Colors.orange)),
                            child: InkWell(
                               onTap: () {
                                  // Can define action on tap (kick, info)
                               },
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Icon(Icons.person, size: 30, color: status == 'approved' ? Colors.greenAccent : Colors.orangeAccent),
                                   const SizedBox(height: 5),
                                   Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                   
                                   if (status == 'pending')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: InkWell(
                                           onTap: () => _firestoreService.approveParticipant(_targetGameId!, userId),
                                           child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                              child: const Text("Принять", style: TextStyle(fontSize: 10, color: Colors.white))
                                           ),
                                        ),
                                      ),
                                      
                                   if (status == 'approved' && roleId != null)
                                      Padding(
                                         padding: const EdgeInsets.only(top: 5),
                                         child: Text("Роль: $roleId", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      )
                                 ],
                               ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
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
