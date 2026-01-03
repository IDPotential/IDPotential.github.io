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
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkHostStatus();
    if (widget.gameId != null) {
       _checkParticipantStatus();
    }
  }

  void _checkParticipantStatus() {
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) return;
     
     _firestoreService.getGameParticipantsStream(widget.gameId!).listen((event) {
        final me = event.docs.where((d) => d.id == user.uid).firstOrNull;
        if (mounted) {
           setState(() {
              _participantStatus = me?.data()['status'];
           });
        }
     });
  }

  // Use this to check connection
  // ... _checkHostStatus ...

  // ... _loadProfile ... _saveProfile ...

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
      floatingActionButton: (_isHost && widget.gameId != null) 
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopPanel() {
    if (widget.gameId == null) {
      // Training Mode / Local
      return _isVideoActive 
          ? _buildJitsiIframe() 
          : _buildVideoPlaceholder();
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
             Text("Игра: ${widget.gameId}", style: const TextStyle(color: Colors.white70)), // Ideally pass Title
             const SizedBox(height: 20),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.green,
                 padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
               ),
               onPressed: () async {
                  await _firestoreService.joinGameRequest(widget.gameId!, _gameProfile!.name, null); // Telegram handle not stored in profile currently
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
              
              if (widget.gameId != null) {
                  // Sync selection
                  await _firestoreService.updateParticipantRole(widget.gameId!, number);
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
    if (widget.gameId == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Участники Игры", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getGameParticipantsStream(widget.gameId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Нет участников", style: TextStyle(color: Colors.white54)));
                  
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final userId = docs[index].id;
                      final name = data['name'] ?? 'Unknown';
                      final status = data['status'] ?? 'pending';
                      final roleId = data['selectedRole'];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         color: Colors.white10,
                        child: ListTile(
                          leading: Icon(
                             status == 'approved' ? Icons.check_circle : Icons.access_time,
                             color: status == 'approved' ? Colors.green : Colors.orange
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                             roleId != null ? "Выбрана роль: $roleId" : "Роль не выбрана",
                             style: const TextStyle(color: Colors.white70)
                          ),
                          trailing: status == 'pending' 
                             ? ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                 onPressed: () => _firestoreService.approveParticipant(widget.gameId!, userId),
                                 child: const Text("Принять"),
                               )
                             : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ... _showRoomDialog check ...
}
