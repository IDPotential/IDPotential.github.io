import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart'; // import file_picker
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:universal_io/io.dart'; // Handles File cross-platform (io for mobile, stub for web)
import 'dart:convert'; // for utf8
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calculation.dart';
import '../services/firestore_service.dart';
import 'result_screen.dart';
import 'calculation_screen.dart';
import 'game_details_screen.dart';
import '../widgets/role_info_dialog.dart';
import 'training_history_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HistoryScreen({super.key, this.onMenuTap});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}



class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // State for Calculations
  List<String> _folders = [];
  List<Calculation> _allCalculations = [];
  List<Calculation> _processedCalculations = [];
  String? _currentFolder;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCalculations();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rawDocs = await _firestoreService.getCalculationsRaw();
      final List<Calculation> loadedCalcs = [];
      final Set<String> folderSet = {};
      for (var doc in rawDocs) {
        try {
          final calc = Calculation.fromMap(doc);
          loadedCalcs.add(calc.copyWith(firebaseId: doc['id']));
          if (calc.group != null && calc.group!.isNotEmpty) {
            folderSet.add(calc.group!);
          }
        } catch (e) {
          debugPrint("Error parsing doc: $e");
        }
      }
      _allCalculations = loadedCalcs;
      _folders = folderSet.toList()..sort();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Calculation> temp = _allCalculations;
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((calc) => 
        calc.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        calc.birthDate.contains(_searchQuery)
      ).toList();
    } else {
      if (_currentFolder == null) {
        temp = temp.where((calc) => calc.group == null || calc.group!.isEmpty).toList();
      } else {
        temp = temp.where((calc) => calc.group == _currentFolder).toList();
      }
    }
    setState(() {
      _processedCalculations = temp;
    });
  }

  Future<void> _createFolder() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Для создания папки переместите расчет в новую группу (Кнопка перемещения -> "Новая папка")')),
    );
  }

  void _openFolder(String folderName) {
    setState(() => _currentFolder = folderName);
    _applyFilters();
  }

  void _goBack() {
    if (_currentFolder != null) {
      setState(() => _currentFolder = null);
      _applyFilters();
    } else {
      // This case should be handled by WillPopScope or Navigator.pop if not in a folder
      // For the tabbed view, this will only be called if _currentFolder is not null.
    }
  }

  Future<void> _deleteFolder(String folderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить папку "$folderName"?'),
        content: const Text('Все расчеты в этой папке будут перемещены в общий список.'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Отмена')),
          TextButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Удалить', style: TextStyle(color:Colors.red))),
        ]
      )
    );
    if (confirm == true) {
      final items = _allCalculations.where((c) => c.group == folderName).toList();
      for (var item in items) {
         if (item.firebaseId != null) await _firestoreService.updateGroup(item.firebaseId!, null);
      }
      _loadCalculations();
    }
  }

  Future<void> _moveCalculation(Calculation calc) async {
     final availableDestinations = ['(Корневая папка)', ..._folders.where((f) => f != calc.group)];
     availableDestinations.add('+ Новая папка');

     if (!mounted) return;

     final result = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SingleChildScrollView(
           child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const ListTile(title: Text('Переместить в...', style: TextStyle(fontWeight: FontWeight.bold))),
                 ...availableDestinations.map((f) => ListTile(
                    leading: Icon(f.startsWith('+') ? Icons.create_new_folder : Icons.folder_open),
                    title: Text(f),
                    onTap: () {
                         if (f.startsWith('+')) Navigator.pop(ctx, 'NEW_FOLDER_ACTION');
                         else Navigator.pop(ctx, f);
                    }
                 ))
              ]
           )
        )
     );

     if (result == 'NEW_FOLDER_ACTION') {
        final controller = TextEditingController();
        final name = await showDialog<String>(
           context: context,
           builder: (ctx) => AlertDialog(
              title: const Text('Новая папка'),
              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Название'), autofocus: true),
              actions: [
                 TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Отмена')),
                 TextButton(onPressed: ()=>Navigator.pop(ctx, controller.text), child: const Text('Создать')),
              ]
           )
        );
        if (name != null && name.isNotEmpty && calc.firebaseId != null) {
           await _firestoreService.updateGroup(calc.firebaseId!, name);
           _loadCalculations();
        }
     } else if (result != null && calc.firebaseId != null) {
        final newGroup = result == '(Корневая папка)' ? null : result;
        await _firestoreService.updateGroup(calc.firebaseId!, newGroup);
        _loadCalculations();
     }
  }

  Future<void> _deleteCalculation(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить запись "$name"?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteCalculation(id);
      _loadCalculations();
    }
  }
  
  Future<void> _editCalculation(Calculation calc) async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CalculationScreen(existingCalculation: calc)));
      _loadCalculations();
  }

  Future<void> _confirmClearAll() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция "Очистить все" отключена для безопасности облачных данных')));
  }

  Future<void> _handleExport() async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Экспорт в разработке')));
  }

  Future<void> _handleImport() async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Импорт отключен (данные синхронизируются с облаком)')));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: WillPopScope(
        onWillPop: () async {
          final tabController = DefaultTabController.of(context);
          if (tabController != null && tabController.index == 0) { // If on "Диагностики" tab
            if (_currentFolder != null) {
              _goBack();
              return false; // Prevent popping the screen
            }
          }
          return true; // Allow popping the screen (either not in a folder or on "Игры" tab)
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_currentFolder ?? 'История'),
            leading: Builder(
              builder: (BuildContext context) {
                final tabController = DefaultTabController.of(context);
                if (tabController != null && tabController.index == 0 && _currentFolder != null) {
                  return IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack);
                } else if (Navigator.canPop(context)) {
                  return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context));
                } else if (widget.onMenuTap != null) {
                   return IconButton(icon: const Icon(Icons.menu), onPressed: widget.onMenuTap);
                }
                return const SizedBox.shrink(); 
              },
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: "Диагностики"),
                Tab(text: "Игры"),
              ],
            ),
            actions: [
               IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCalculations, tooltip: 'Обновить'),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: TabBarView(
                children: [
                   _buildDiagnosticsTab(),
                   _buildGamesTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsTab() {
     return Column(
       children: [
         // Search
         Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
               controller: _searchController,
               decoration: InputDecoration(
                  labelText: 'Поиск', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: (){
                     _searchController.clear();
                     setState(() => _searchQuery = '');
                     _applyFilters();
                  }) : null
               ),
               onChanged: (v) { setState(()=>_searchQuery=v); _applyFilters(); }
            )
         ),
         Expanded(
           child: _isLoading 
             ? const Center(child: CircularProgressIndicator())
             : ListView(
                 padding: const EdgeInsets.all(16),
                 children: [
                    // Folders
                    if (_currentFolder == null && _folders.isNotEmpty && _searchQuery.isEmpty) ...[
                       const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Папки', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                       ..._folders.map((f) => Card(
                          elevation: 2, margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                             leading: const Icon(Icons.folder, color: Colors.orange, size: 32),
                             title: Text(f, style: const TextStyle(fontWeight: FontWeight.bold)),
                             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                             onTap: () => _openFolder(f),
                             onLongPress: () => _deleteFolder(f),
                          )
                       )),
                       const SizedBox(height: 16),
                       const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Файлы', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                    ],

                    if (_processedCalculations.isEmpty && (_folders.isEmpty || _searchQuery.isNotEmpty || _currentFolder != null))
                       const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Ничего нет", style: TextStyle(color: Colors.grey)))),
                    
                    ..._processedCalculations.map((calc) => Card(
                       child: ListTile(
                          leading: CircleAvatar(
                             backgroundColor: (calc.gender == 'Ж' || calc.gender == 'F') ? Colors.pink.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                             child: Icon((calc.gender == 'Ж' || calc.gender == 'F') ? Icons.female : Icons.male, color: (calc.gender == 'Ж' || calc.gender == 'F') ? Colors.pink : Colors.blue, size: 20)
                          ),
                          title: Text(calc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(calc.birthDate),
                          trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                IconButton(
                                   icon: const Icon(Icons.drive_file_move_outline),
                                   onPressed: () => _moveCalculation(calc),
                                   tooltip: 'Переместить',
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                   iconSize: 20,
                                ),
                                PopupMenuButton<String>(
                                   onSelected: (v) {
                                      if (v == 'edit') _editCalculation(calc);
                                      if (v == 'delete' && calc.firebaseId != null) _deleteCalculation(calc.firebaseId!, calc.name);
                                   },
                                   itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'edit', child: Row(children:[Icon(Icons.perm_contact_calendar_outlined, color: Colors.blueGrey), SizedBox(width:8), Text("Изменить данные")])),
                                      const PopupMenuItem(value: 'delete', child: Row(children:[Icon(Icons.delete_outline, color:Colors.red), SizedBox(width:8), Text("Удалить")])),
                                   ],
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                   iconSize: 20,
                                   tooltip: 'Ещё',
                                )
                             ]
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(calculation: calc))),
                       )
                    ))
                 ]
             )
         )
       ],
     );
  }

   Widget _buildGamesTab() {
      // Nested StreamBuilder to fetch both Participant History and Host History
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
         stream: _firestoreService.getGameHistoryStream(), // Participant Stream
         builder: (context, partSnapshot) {
            
            return StreamBuilder<List<Map<String, dynamic>>>(
               stream: _firestoreService.getHostGamesStream(), // Host Stream
               builder: (context, hostSnapshot) {
                  if (partSnapshot.connectionState == ConnectionState.waiting && hostSnapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                  }

                  // 1. Process Participant Games
                  if (partSnapshot.hasError) {
                      debugPrint("Error loading participant history: ${partSnapshot.error}");
                  }
                  final partDocs = partSnapshot.data?.docs ?? [];
                  final List<Map<String, dynamic>> combinedList = [];

                  for (var doc in partDocs) {
                      final data = doc.data();
                      if (data['isTraining'] == true) continue; // Skip training

                      String dateStr = (data['date'] ?? '').toString();
                      DateTime? dateObj;
                      if (data['date'] is Timestamp) {
                         dateObj = (data['date'] as Timestamp).toDate();
                         dateStr = dateObj.toString().split(' ')[0];
                      } else if (dateStr.contains('T')) {
                         dateStr = dateStr.split('T')[0];
                         dateObj = DateTime.tryParse(data['date'] ?? '');
                      }

                      combinedList.add({
                         'type': 'participant',
                         'docId': doc.id,
                         'title': data['gameTitle'] ?? 'Игра',
                         'dateStr': dateStr,
                         'dateObj': dateObj ?? DateTime(2000),
                         'score': data['score'] ?? 0,
                         'rank': data['rank'] ?? 0,
                         'total': data['totalParticipants'] ?? 0,
                      });
                  }

                  // 2. Process Host Games
                  if (hostSnapshot.hasError) {
                      debugPrint("Error loading host history: ${hostSnapshot.error}");
                  }
                  final hostGames = hostSnapshot.data ?? [];
                  for (var data in hostGames) {
                      if (data['isTraining'] == true) continue; // Filter out training games
                      
                      String dateStr = (data['scheduledAt'] ?? '').toString();
                      DateTime? dateObj;
                      if (dateStr.isNotEmpty) {
                          dateObj = DateTime.tryParse(dateStr);
                          if (dateObj != null) {
                             dateStr = "${dateObj.year}-${dateObj.month.toString().padLeft(2,'0')}-${dateObj.day.toString().padLeft(2,'0')}";
                          }
                      }
                      
                      combinedList.add({
                         'type': 'host',
                         'docId': data['id'],
                         'title': data['title'] ?? 'Игра (Ведущий)',
                         'dateStr': dateStr,
                         'dateObj': dateObj ?? DateTime(2000),
                         'score': 0, // Not applicable
                         'rank': 'Host', // Marker
                         'total': 0
                      });
                  }

                  // 3. Sort by Date Descending
                  combinedList.sort((a, b) => (b['dateObj'] as DateTime).compareTo(a['dateObj'] as DateTime));

                  return ListView(
                     padding: const EdgeInsets.all(16),
                     children: [
                        // TRAININGS HEADER
                        Card(
                           color: Colors.purple.withOpacity(0.1),
                           margin: const EdgeInsets.only(bottom: 16),
                           child: ListTile(
                              leading: const CircleAvatar(
                                 backgroundColor: Colors.purple,
                                 child: Icon(Icons.school, color: Colors.white),
                              ),
                              title: const Text("Тренировочные игры", style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("Все ваши тренировки и ответы"),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (c) => const TrainingHistoryScreen()));
                              },
                           ),
                        ),

                        if (combinedList.isEmpty) 
                           const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Нет завершенных игр', style: TextStyle(color: Colors.grey)))),

                        ...combinedList.map((item) {
                           final isHost = item['type'] == 'host';
                           final rank = item['rank'];
                           
                           return Card(
                              color: isHost ? Colors.orangeAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.05),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                 leading: CircleAvatar(
                                    backgroundColor: isHost ? Colors.redAccent : (rank == 1 ? Colors.orange : Colors.blueGrey),
                                    child: isHost 
                                      ? const Icon(Icons.star, color: Colors.white) 
                                      : Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 ),
                                 title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                 subtitle: Text(isHost ? "Ведущий • ${item['dateStr']}" : "${item['dateStr']}"),
                                 trailing: isHost 
                                    ? const Icon(Icons.mic, color: Colors.white24)
                                    : Column(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       crossAxisAlignment: CrossAxisAlignment.end,
                                       children: [
                                          Text("${item['score']} кр.", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text("Место: $rank/${item['total']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                       ],
                                    ),
                                 onTap: () {
                                    if (isHost) {
                                       // Navigate to Host Report? Or Game Details?
                                       // GameDetailsScreen might need updates to handle host view if it relies on 'my participant doc'
                                       // For now, let's open it. GameDetailsScreen takes gameId.
                                       Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (context) => GameDetailsScreen(
                                             gameId: item['docId'],
                                             gameTitle: item['title'],
                                             totalScore: 0,
                                             rank: 0,
                                             isHostView: true, 
                                          ))
                                       );
                                    } else {
                                       Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (context) => GameDetailsScreen(
                                             gameId: item['docId'],
                                             gameTitle: item['title'],
                                             totalScore: item['score'],
                                             rank: item['rank'],
                                          ))
                                       );
                                    }
                                 },
                              ),
                           );
                        }).toList()
                     ],
                  );
               }
            );
         }
      );
   }
}
