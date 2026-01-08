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
  List<int> _userMatrix = [];
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
      } else {
          debugPrint("Training Pack 'Соло' not found!");
      }

      // 3. Load User Calculation
      final calcData = await _firestoreService.getLatestCalculation();
      if (calcData != null) {
          if (calcData['numbers'] != null) {
              _userMatrix = List<int>.from(calcData['numbers']);
          } else if (calcData['matrix'] != null) {
              _userMatrix = List<int>.from(calcData['matrix']);
          }
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
              
              // Roles Dashboard (My Matrix)
              if (_userMatrix.isNotEmpty) ...[
                 Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                       color: Colors.white10,
                       borderRadius: BorderRadius.circular(16)
                    ),
                    child: Column(
                       children: [
                          Row(
                             children: [
                                Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ИНЬ", [_n(4), _n(5)])),
                                Expanded(child: _buildSheetSection("ДУАЛЬНОСТЬ ЯН", [_n(6), _n(7)])),
                             ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                             children: [
                                Expanded(child: _buildSheetSection("МОТИВ", [_n(8)])),
                                Expanded(child: _buildSheetSection("МЕТОД", [_n(9)])),
                                Expanded(child: _buildSheetSection("СФЕРА", [_n(10)])),
                             ]
                          ),
                          const SizedBox(height: 8),
                          Row(
                             children: [
                                Expanded(child: _buildSheetSection("СТРАХИ", [_n(11)])),
                                Expanded(child: _buildSheetSection("БАЛАНС", [_n(13)])),
                                Expanded(child: _buildSheetSection(" ТОЧКА ВЫХОДА", [_n(12)])),
                             ],
                          ),
                       ],
                    ),
                 ),
              ] else ...[
                 const Center(
                   child: Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("Внимание: Для использования тренировочного режима необходимо иметь сохраненный профиль (расчет).", 
                       style: TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center),
                   ),
                 ),
              ],
              
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

   // Helper to safely get role number from user matrix
   int _n(int idx) => (idx < _userMatrix.length) ? (_userMatrix[idx] == 0 ? 22 : _userMatrix[idx]) : 22;

   Widget _buildSheetSection(String title, List<int> cardNums) {
      return Column(
         children: [
            Padding(
               padding: const EdgeInsets.symmetric(vertical: 6),
               child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ),
            Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: cardNums.map<Widget>((num) {
                  final isSelected = _selectedRole == num;
                  return GestureDetector(
                     onTap: () => _showRoleDetails(num),
                     child: Container(
                        width: 50,
                        height: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(6),
                           border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white12, width: isSelected ? 2 : 0.5),
                           boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Stack(
                           children: [
                              ClipRRect(
                                 borderRadius: BorderRadius.circular(6),
                                 child: Image.asset(
                                    'assets/images/cards/role_$num.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (c, e, s) => Container(color: Colors.white10, child: Center(child: Text("$num", style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                                 ),
                              ),
                              Positioned(
                                 bottom: 0, right: 0, left: 0,
                                 child: Container(
                                    decoration: const BoxDecoration(
                                       color: Colors.black54,
                                       borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text("$num", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                 ),
                              ),
                              if (isSelected) 
                                 Positioned(
                                    top: 2, right: 2,
                                    child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14) 
                                 )
                           ],
                        ),
                     ),
                  );
               }).toList(),
            ),
         ],
      );
   }

  void _showRoleDetails(int number) {
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('$number. $name', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
               const SizedBox(height: 16),
               
               if (keyQuality.isNotEmpty) ...[
                 const Text("Ключевое качество:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                 Text(keyQuality, style: const TextStyle(color: Colors.white60)),
                 const SizedBox(height: 8),
               ],
               
               if (strength.isNotEmpty) ...[
                 const Text("Сила роли:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                 Text(strength, style: const TextStyle(color: Colors.white60)),
                 const SizedBox(height: 8),
               ],
               
               if (challenge.isNotEmpty) ...[
                  const Text("Вызов (ловушка):", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  Text(challenge, style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 8),
               ],
               
               if (roleInLife.isNotEmpty) ...[
                  const Text("В жизни:", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                  Text(roleInLife, style: const TextStyle(color: Colors.white60)),
               ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Отмена", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
               setState(() => _selectedRole = number);
               Navigator.pop(ctx);
            }, 
            child: const Text("Выбрать эту роль")
          ),
        ],
      ),
    );
  }
}
