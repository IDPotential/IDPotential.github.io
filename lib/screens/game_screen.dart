import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/registry.dart'; // Import registry
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
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
  int? _selectedRole;
  bool _isVideoActive = false; 
  String _roomName = '';
  
  // Host State
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkHostStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
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
        if (role == 'admin' || role == 'diagnost' || pgmd == 100) {
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
        final calc = await CalculatorService.calculate(name, date, _gender);
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
    );
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

  Widget _buildSplitScreenGame() {
    return Column(
      children: [
        // Top Controls
        Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Expanded(
                 child: Text(
                   "Участник: ${_gameProfile!.name}", 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                   overflow: TextOverflow.ellipsis,
                 )
               ),
               if (_isHost && widget.gameId != null)
                 ElevatedButton.icon(
                   icon: const Icon(Icons.dashboard, size: 16),
                   label: const Text("Host Panel"),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.purple,
                     padding: const EdgeInsets.symmetric(horizontal: 10),
                   ),
                   onPressed: _showHostPanel,
                 ),
               const SizedBox(width: 8),
               if (!_isVideoActive)
                  IconButton(
                    icon: const Icon(Icons.video_call),
                    onPressed: () => setState(() => _isVideoActive = true),
                    tooltip: 'Видео',
                  ),
               IconButton(
                 icon: const Icon(Icons.settings),
                 onPressed: _showRoomDialog,
                 tooltip: 'Комната',
               ),
             ],
           ),
        ),

        // Video Section
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black87,
            child: _isVideoActive 
              ? _buildJitsiIframe()
              : Center(
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
                        onPressed: () {
                          setState(() {
                             _isVideoActive = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
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

  Widget _buildJitsiIframe() {
    final String room = _roomName.isEmpty ? 'IdPotentialGame' : _roomName;
    final String viewType = 'jitsi-meet-$room';
    
    try {
      Registry.registerJitsiViewFactory(viewType, 'https://meet.jit.si/$room');
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

  Widget _buildRolesGrid() {
    final Set<int> uniqueNumbers = {};
    for (var n in _gameProfile!.numbers) {
      uniqueNumbers.add(n == 0 ? 22 : n);
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

  void _showRoleInfo(int number) {
    final info = KnowledgeService.getRoleInfo(number);
    final name = info['role_name'] ?? 'Роль $number';
    final description = info['description'] ?? 'Описание отсутствует';
    final keyQuality = info['role_key'] ?? '';
    final strength = info['role_strength'] ?? '';
    final challenge = info['role_challenge'] ?? '';
    final manifestation = info['manifestation'] ?? '';
    final roleQuestion = info['role_question'] ?? '';
    
    final answerController = TextEditingController();

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

              if (manifestation.isNotEmpty) ...[
                 const Text("Проявляется:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                 Text(manifestation),
                 const SizedBox(height: 8),
              ],

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
              
              if (roleQuestion.isNotEmpty) ...[
                 const Divider(),
                 const Text("Вопрос для рефлексии:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                 Text(roleQuestion, style: const TextStyle(fontStyle: FontStyle.italic)),
                 const SizedBox(height: 10),
                 TextField(
                   controller: answerController,
                   decoration: const InputDecoration(
                     hintText: 'Ваш ответ...',
                     border: OutlineInputBorder(),
                   ),
                   maxLines: 2,
                 ),
                 const SizedBox(height: 5),
                 ElevatedButton(
                   onPressed: () async {
                      if (answerController.text.isNotEmpty) {
                         if (widget.gameId != null) {
                            try {
                              await FirestoreService().submitGameAnswer(
                                  gameId: widget.gameId!,
                                  roleId: number,
                                  roleName: name,
                                  answer: answerController.text
                              );
                              if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ сохранен!')));
                                 Navigator.pop(context); 
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                              }
                            }
                         } else {
                            if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Режим тренировки: ответ не отправлен.')));
                            }
                         }
                      }
                   },
                   child: const Text('Сохранить ответ'),
                 )
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedRole = number;
              });
              Navigator.pop(context);
              if (widget.gameId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Выбрана роль: $name')),
                );
              }
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
              child: Text("Панель Ведущего - Ответы Игроков", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getGameAnswersStream(widget.gameId!),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Пока нет ответов", style: TextStyle(color: Colors.white54)));
                  
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final userName = data['userName'] ?? 'Unknown';
                      final roleName = data['roleName'] ?? 'Unknown Role';
                      final answer = data['answer'] ?? '';
                      final time = (data['timestamp'] as Timestamp?)?.toDate();
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.white10,
                        child: ListTile(
                          leading: CircleAvatar(child: Text(userName[0].toUpperCase())),
                          title: Text("$userName - $roleName", style: const TextStyle(color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(answer, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                              const SizedBox(height: 4),
                              if (time != null)
                                Text("${time.hour}:${time.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
