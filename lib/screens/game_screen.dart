import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
import '../services/knowledge_service.dart';
import '../models/calculation.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

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
  String _roomName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
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
            _gender = profile.gender;
            // Generate Personal Room Name
            _roomName = 'IDPotential_${profile.name.replaceAll(RegExp(r'\s+'), '')}_${profile.birthDate.replaceAll('.', '')}';
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading game profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final numbers = CalculatorService.calculateDiagnostic(
        _dateController.text,
        _nameController.text,
        _gender,
      );

      final calculation = Calculation(
         name: _nameController.text,
         birthDate: _dateController.text,
         gender: _gender,
         numbers: numbers,
         createdAt: DateTime.now(),
      );

      await _firestoreService.saveGameProfile(calculation);
      
      if (mounted) {
        setState(() {
          _gameProfile = calculation;
           _roomName = 'IDPotential_${calculation.name.replaceAll(RegExp(r'\s+'), '')}_${calculation.birthDate.replaceAll('.', '')}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль игры сохранен!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gameProfile == null) {
      return _buildRegistrationForm();
    }

    return _buildSplitScreenGame();
  }

  Widget _buildRegistrationForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text(
                    'Территория себя',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Введите свои данные для входа в игру',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person)),
                    validator: (value) => value!.isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Date
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(labelText: 'Дата рождения', prefixIcon: Icon(Icons.calendar_today), hintText: '25.12.1990'),
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
                  const SizedBox(height: 16),
                  
                  // Gender
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
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: _saveProfile, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), child: const Text('Войти в игру')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitScreenGame() {
    return Column(
      children: [
        // Video Section (simulated with button)
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black87,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_call, size: 60, color: Colors.white54),
                const SizedBox(height: 20),
                Text(
                  "Комната: ...${_roomName.length > 20 ? _roomName.substring(_roomName.length - 20) : _roomName}", 
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  label: const Text("Открыть видеозвонок (Jitsi)", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: _launchVideo,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _showRoomDialog,
                  child: const Text("Сменить комнату", style: TextStyle(color: Colors.white54)),
                )
              ],
            ),
          ),
        ),
        
        const Divider(height: 1, thickness: 1, color: Colors.grey),

        // Roles Section
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Мои Роли", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _launchVideo() async {
    final url = Uri.parse('https://meet.jit.si/$_roomName');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch video')));
      }
    }
  }

  Widget _buildRolesGrid() {
    // Logic: Unique, Sorted, No 0 (map to 22)
    final Set<int> uniqueNumbers = {};
    for (var n in _gameProfile!.numbers) {
      uniqueNumbers.add(n == 0 ? 22 : n);
    }
    final sortedNumbers = uniqueNumbers.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 5 cards per row for compactness
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
            onPressed: () {
              setState(() {
                _selectedRole = number;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Выбрана роль: $name')),
              );
            },
            child: const Text('Выбрать роль'),
          ),
        ],
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
           decoration: const InputDecoration(labelText: 'Room Name', hintText: 'MyGameRoom'),
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
      });
    }
  }
}
