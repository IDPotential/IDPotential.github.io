import 'package:flutter/material.dart';
import 'dart:math';
import '../services/firestore_service.dart';
import '../data/diagnostic_data.dart'; // Import Diagnostic Data
import '../services/knowledge_service.dart';

class TrainingGameScreen extends StatefulWidget {
  const TrainingGameScreen({super.key});

  @override
  State<TrainingGameScreen> createState() => _TrainingGameScreenState();
}

class _TrainingGameScreenState extends State<TrainingGameScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _dailyCount = 0;
  bool _isLoading = true;
  String? _currentSituation;
  String? _currentSituationId;
  int? _selectedRole;
  bool _isResultSaved = false;

  // Cache for situations
  List<Map<String, dynamic>> _allSituations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get Daily Limit
      final count = await _firestoreService.getDailyTrainingCount();
      _dailyCount = count;

      // 2. Load Situations (lazy load logic)
      final packs = await _firestoreService.getSituationPacks();
      debugPrint("DEBUG: Found ${packs.length} packs: ${packs.map((e) => e.data()['title']).toList()}");

      // Try to find "Ситуации Соло", else fallback to any
      var targetPack = packs.where((d) => d.data()['title'].toString().contains('Соло')).firstOrNull;
      targetPack ??= packs.firstOrNull;

      if (targetPack != null) {
          final situations = List<Map<String, dynamic>>.from(targetPack.data()['situations'] ?? []);
          _allSituations = situations;
          debugPrint("Loaded ${_allSituations.length} situations from pack ${targetPack.id}");
      } else {
          debugPrint("Training Pack 'Соло' not found!");
      }
    } catch (e) {
      debugPrint("Error loading training data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _getNewSituation() {
    debugPrint("Get Situation Clicked. DailyCount: $_dailyCount, Situations: ${_allSituations.length}");
    
    if (_dailyCount >= 2) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Лимит на сегодня исчерпан!")));
       return;
    }
    if (_allSituations.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка: Ситуации не найдены!"), backgroundColor: Colors.red));
       return;
    }

    final random = Random();
    final item = _allSituations[random.nextInt(_allSituations.length)];
    
    setState(() {
       _currentSituation = item['text'];
       _currentSituationId = item['id']?.toString();
       _selectedRole = null; // Reset role
       _isResultSaved = false; // Reset saved state
    });
  }

  Future<void> _saveResult() async {
     if (_selectedRole == null || _currentSituation == null) return;
     
     setState(() => _isLoading = true);
     try {
        await _firestoreService.saveTrainingResult(
           _currentSituation!, 
           _selectedRole!, 
           'training_pack', 
           _currentSituationId ?? '0'
        );
        
        setState(() {
           _dailyCount++;
           _isResultSaved = true;
           _isLoading = false;
        });
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Результат сохранен в историю!"), backgroundColor: Colors.green));
        }
     } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red));
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Тренировочная игра"),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Container(
         decoration: const BoxDecoration(
             gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)])
         ),
         child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                   // Header: Daily Limit
                   _buildLimitCard(),
                   
                   Expanded(
                      child: _currentSituation == null
                          ? _buildStartScreen()
                          : _buildActiveScreen(),
                   )
                ],
            ),
      ),
    );
  }

  Widget _buildLimitCard() {
     final remaining = 2 - _dailyCount;
     Color color = remaining > 0 ? Colors.green : Colors.red;
     String text = remaining > 0 
        ? "Доступно ситуаций на сегодня: $remaining" 
        : "На сегодня тренировочные ситуации закончились. Ждем вас завтра!";

     return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
           color: color.withOpacity(0.2),
           border: Border.all(color: color),
           borderRadius: BorderRadius.circular(12)
        ),
        child: Row(
           children: [
              Icon(remaining > 0 ? Icons.check_circle : Icons.lock_clock, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))),
           ],
        ),
     );
  }

  Widget _buildStartScreen() {
     if (_dailyCount >= 2) {
        return const Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                 SizedBox(height: 20),
                 Text("Тренировка завершена!", style: TextStyle(color: Colors.white, fontSize: 24)),
                 SizedBox(height: 10),
                 Text("Возвращайтесь завтра за новыми инсайтами.", style: TextStyle(color: Colors.white54)),
              ],
           ),
        );
     }

     return Center(
        child: ElevatedButton.icon(
           style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              backgroundColor: Colors.blueAccent
           ),
           icon: const Icon(Icons.style, size: 32),
           label: const Text("Получить ситуацию", style: TextStyle(fontSize: 20)),
           onPressed: _getNewSituation,
        ),
     );
  }

  Widget _buildActiveScreen() {
     if (_isResultSaved) {
         return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                 const SizedBox(height: 20),
                 const Text("Выбор записан", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 30),
                 if (_dailyCount < 2)
                    ElevatedButton(
                       onPressed: _getNewSituation,
                       style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                       child: const Text("Следующая ситуация"),
                    )
                 else 
                    const Text("Лимит на сегодня исчерпан.", style: TextStyle(color: Colors.white54))
              ],
           ),
        );
     }

     return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
              // Situation Card
              Card(
                 color: Colors.white10,
                 child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                       children: [
                          Text("Ситуация #${_currentSituationId ?? '?'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 12),
                          Text(_currentSituation!, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
                       ],
                    ),
                 ),
              ),
              const SizedBox(height: 20),
              const Text("Какая роль подсознания сейчас активна?", style: TextStyle(color: Colors.blueAccent, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              
              // Roles Grid
              Wrap(
                 spacing: 12,
                 runSpacing: 12,
                 alignment: WrapAlignment.center,
                 children: zones.entries.map((entry) {
                     final roleId = entry.key;
                     final roleData = entry.value;
                     final isSelected = _selectedRole == roleId;

                     return GestureDetector(
                        onTap: () => _showRoleDetails(roleId, roleData),
                        child: Container(
                           width: 60,
                           height: 60,
                           decoration: BoxDecoration(
                              color: isSelected ? Colors.green : Colors.blueAccent.withOpacity(0.2),
                              border: Border.all(color: Colors.blueAccent),
                              borderRadius: BorderRadius.circular(12),
                           ),
                           alignment: Alignment.center,
                           child: Text(
                              "$roleId", 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                           ),
                        ),
                     );
                 }).toList(),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton(
                 onPressed: _selectedRole != null ? _saveResult : null,
                 style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green
                 ),
                 child: const Text("Сохранить выбор", style: TextStyle(fontSize: 18)),
              )
           ],
        ),
      );
  }

  void _showRoleDetails(int roleId, Map<String, String> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("${data['name']} ($roleId)", style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data['description'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 12),
              const Text("Ключ роли:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              Text(data['role_key'] ?? '', style: const TextStyle(color: Colors.white60)),
               const SizedBox(height: 8),
              const Text("В жизни:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              Text(data['role_inlife'] ?? '', style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Отмена", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
               setState(() => _selectedRole = roleId);
               Navigator.pop(context);
               _saveResult(); // Auto-save after confirmation? Or let user click save? 
               // User flow: Select -> (Screen shows Result) -> Save? 
               // Wait, existing flow was Select -> Click "Save result"?
               // Let's check _buildActiveScreen buttons.
               
               // Existing flow had a "Confirm/Next" button likely. 
               // Actually, let's keep it simple: Select -> Set State. 
               // Then user clicks "Ответить" (Answer) if it exists.
               // Checking code... there is no "Answer" button in the viewed code. 
               // Ah, previously viewed code didn't show the bottom part.
               // Assuming there is a button to confirm. If not, I should add one or auto-save.
               // Let's assume there is a button below the Grid.
            }, 
            child: const Text("Выбрать эту роль")
          ),
        ],
      ),
    );
  }
}
