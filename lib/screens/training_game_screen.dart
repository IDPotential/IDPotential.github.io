import 'package:flutter/material.dart';
import 'dart:math';
import '../services/firestore_service.dart';
import '../data/diagnostic_data.dart'; // Import Diagnostic Data
import '../services/knowledge_service.dart';

import 'calculation_screen.dart';
import '../widgets/role_info_dialog.dart'; // Import Custom Dialog

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

  void _openProfileCreation() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CalculationScreen()),
      );
      _loadData(); // Reload after return
  }

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
      // 1. Load User Calculation FIRST to get Age & Matrix
      final calcData = await _firestoreService.getLatestCalculation();
      int userAge = 30; // Default to adult if unknown

      if (calcData != null) {
          // Matrix
          if (calcData['numbers'] != null) {
              _userMatrix = List<int>.from(calcData['numbers']);
          } else if (calcData['matrix'] != null) {
              _userMatrix = List<int>.from(calcData['matrix']);
          }
          
          // Age Calculation
          if (calcData['birthDate'] != null) {
             try {
                // Expected format: DD.MM.YYYY
                final parts = calcData['birthDate'].toString().split('.');
                if (parts.length == 3) {
                   final year = int.parse(parts[2]);
                   userAge = DateTime.now().year - year;
                   debugPrint("User Age: $userAge (Born: $year)");
                }
             } catch (e) {
                debugPrint("Error parsing birthDate: $e");
             }
          }
      }

      // 2. Get Daily Limit
      final count = await _firestoreService.getDailyTrainingCount();
      _dailyCount = count;

      // 3. Load Situations based on Age
      final packs = await _firestoreService.getSituationPacks();
      debugPrint("DEBUG: Found ${packs.length} packs. User Age: $userAge");

      Map<String, dynamic>? targetPackData;

      // Logic: 
      // < 12: pack_Solo_kids
      // 12-17: pack_Solo_teen
      // 18+ : Соло or default

      if (userAge < 12) {
          targetPackData = packs.where((d) {
             final t = d.data()['title'].toString().toLowerCase();
             return t.contains('kids') || t.contains('дети');
          }).firstOrNull?.data();
          if (targetPackData != null) debugPrint("Selected: KIDS pack");
      } 
      
      if (targetPackData == null && userAge >= 12 && userAge < 18) {
          targetPackData = packs.where((d) {
             final t = d.data()['title'].toString().toLowerCase();
             return t.contains('teen') || t.contains('подрост'); 
          }).firstOrNull?.data();
          if (targetPackData != null) debugPrint("Selected: TEEN pack");
      }

      // Fallback / Adult
      if (targetPackData == null) {
          targetPackData = packs.where((d) => d.data()['title'].toString().contains('Соло')).firstOrNull?.data();
          targetPackData ??= packs.firstOrNull?.data();
          debugPrint("Selected: DEFAULT/SOLO pack");
      }

      if (targetPackData != null) {
          final situations = List<Map<String, dynamic>>.from(targetPackData['situations'] ?? []);
          _allSituations = situations;
      } else {
          debugPrint("Training Pack not found!");
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
                 Center(
                   child: Padding(
                     padding: EdgeInsets.all(20),
                     child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Text("У вас нет игрового профиля", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            Text("Для тренировки необходимо создать свою карту (расчет).", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                            SizedBox(height: 24),
                            // Button to create profile
                            ElevatedButton( // Button needed here
                                onPressed: _openProfileCreation, // Method to be added
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                child: Text("Создать профиль")
                            )
                        ],
                     ),
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

   Widget _buildNumberSelection() {
      // Logic: Unique, sorted, 0->22
      final Set<int> uniqueNumbers = {};
      for (var n in _userMatrix) {
         if (n > 0 && n <= 22) uniqueNumbers.add(n);
         if (n == 0) uniqueNumbers.add(22);
      }
      // If empty (shouldn't happen), fill 1-22
      if (uniqueNumbers.isEmpty) {
         uniqueNumbers.addAll(List.generate(22, (i) => i + 1));
      }
      
      final sortedNumbers = uniqueNumbers.toList()..sort();

      return LayoutBuilder(
        builder: (context, constraints) {
          // RESPONSIVE: Increase columns on wider screens
          final int crossAxisCount = constraints.maxWidth > 900 ? 10 : (constraints.maxWidth > 600 ? 7 : 5);
          final double aspectRatio = constraints.maxWidth > 600 ? 0.75 : 0.65;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount, 
              childAspectRatio: aspectRatio, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8,
            ),
            itemCount: sortedNumbers.length,
            itemBuilder: (context, index) {
              final number = sortedNumbers[index];
              final isSelected = _selectedRole == number;
              return GestureDetector(
                onTap: () => setState(() => _selectedRole = number),
                onLongPress: () => _showRoleDetails(number),
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
                          child: Image.asset(
                              'assets/images/cards/role_$number.png', 
                              fit: BoxFit.cover, 
                              errorBuilder: (c,e,s)=>const Icon(Icons.image_not_supported)
                          ),
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
      );
   }

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
    showDialog(
      context: context,
      builder: (ctx) => RoleInfoDialog(
        roleNumber: number,
        canSelect: true,
        onSelect: () {
           setState(() => _selectedRole = number);
        },
      ),
    );
  }
}
