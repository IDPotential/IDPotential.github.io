import 'package:flutter/material.dart';
import '../services/calculator_service.dart';
import '../services/firestore_service.dart';
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

    return _buildGameView();
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
                    'Введите данные для создания игрового профиля',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value!.isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Date
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Дата рождения (ДД.ММ.ГГГГ)',
                      prefixIcon: Icon(Icons.calendar_today),
                      hintText: '25.12.1990',
                    ),
                    keyboardType: TextInputType.datetime,
                    onChanged: (value) {
                      String newText = value;
                      
                      // 1. Replace separators
                      newText = newText.replaceAll(RegExp(r'[\/,\-]'), '.');
                      
                      // 2. Auto-insert dots for 01012001 -> 01.01.2001
                      if (RegExp(r'^\d{8}$').hasMatch(newText)) {
                          newText = '${newText.substring(0, 2)}.${newText.substring(2, 4)}.${newText.substring(4)}';
                      }

                      if (newText != value) {
                        _dateController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(offset: newText.length),
                        );
                      }
                    },
                    validator: (value) {
                       if (value == null || value.isEmpty) return 'Введите дату';
                       final regExp = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                       if (!regExp.hasMatch(value)) return 'Формат ДД.ММ.ГГГГ';
                       return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Gender
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Пол:'),
                      const SizedBox(width: 20),
                      ChoiceChip(
                        label: const Text('М'),
                        selected: _gender == 'М',
                        onSelected: (selected) => setState(() => _gender = 'М'),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Ж'),
                        selected: _gender == 'Ж',
                        onSelected: (selected) => setState(() => _gender = 'Ж'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Создать профиль'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gameProfile!.name, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  Text(_gameProfile!.birthDate, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                   setState(() {
                     _gameProfile = null; // Switch back to edit mode
                   });
                },
                tooltip: 'Изменить данные',
              )
            ],
          ),
        ),
        const Divider(),
        
        // Cards Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 cards per row
              childAspectRatio: 0.6, // Taller cards (approx tarot ratio)
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _gameProfile!.numbers.length,
            itemBuilder: (context, index) {
              final number = _gameProfile!.numbers[index];
              // Map 0 to 22 for image asset
              final imageNum = number == 0 ? 22 : number;
              
              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Image.asset(
                        'assets/images/cards/role_$imageNum.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
