import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart'; // import file_picker
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:universal_io/io.dart'; // Handles File cross-platform (io for mobile, stub for web)
import 'dart:convert'; // for utf8
import '../models/calculation.dart';
import '../services/firestore_service.dart';
import 'result_screen.dart';
import 'calculation_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // State
  List<String> _folders = [];
  List<Calculation> _allCalculations = []; // All fetched calculations
  List<Calculation> _processedCalculations = []; // Filtered for current view
  String? _currentFolder; // null = root
  
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Fetch all from Firestore
      final rawDocs = await _firestoreService.getCalculationsRaw();
      
      final List<Calculation> loadedCalcs = [];
      final Set<String> folderSet = {};

      for (var doc in rawDocs) {
        try {
          final calc = Calculation.fromMap(doc);
          // Ensure firebaseId is set from doc ID
          loadedCalcs.add(calc.copyWith(firebaseId: doc['id'])); // Ensure firebaseId is populated
          
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

    // 1. Search Filter
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((calc) => 
        calc.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        calc.birthDate.contains(_searchQuery)
      ).toList();
      // Search ignores folders
    } else {
      // 2. Folder Filter
      if (_currentFolder == null) {
        // Root: Show only items without group
        temp = temp.where((calc) => calc.group == null || calc.group!.isEmpty).toList();
      } else {
        // Folder: Show items in this group
        temp = temp.where((calc) => calc.group == _currentFolder).toList();
      }
    }
    
    // Sort by date descending (already done by Firestore query, but good to ensure)
    // Firestore query was orderBy createdAt.
    
    setState(() {
      _processedCalculations = temp;
    });
  }

  Future<void> _createFolder() async {
    // In Firestore model, folders are implicit. 
    // We can't create an empty folder easily without a separate collection.
    // For now, we will just show a message or creating a folder implies moving an item to it?
    // Let's implement "Create Folder" as "Enter Name -> Then select items to move"? 
    // Or just "Create Folder" adds it to local list until refresh?
    // better: Show dialog "To create a folder, move a calculation into a new group".
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Для создания папки переместите расчет в новую группу (Кнопка перемещения -> "Новая папка")')),
    );
  }

  Future<void> _deleteFolder(String folderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить папку "$folderName"?'),
        content: const Text('Все расчеты в этой папке будут перемещены в общий список.'),
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
      // Find all items in this group and ungroup them
      final itemsToUngroup = _allCalculations.where((c) => c.group == folderName).toList();
      
      for (var item in itemsToUngroup) {
         if (item.firebaseId != null) {
            await _firestoreService.updateGroup(item.firebaseId!, null);
         }
      }
      
      _loadData(); // Refresh
    }
  }

  void _openFolder(String folderName) {
    setState(() {
      _currentFolder = folderName;
    });
    _applyFilters(); // Just re-filter local data
  }

  void _goBack() {
    if (_currentFolder != null) {
      setState(() {
        _currentFolder = null;
      });
      _applyFilters();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _moveCalculation(Calculation calc) async {
    final availableDestinations = ['(Корневая папка)', ..._folders.where((f) => f != calc.group)];
    
    // Add option for new folder
    availableDestinations.add('+ Новая папка');

    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Переместить в...', style: TextStyle(fontWeight: FontWeight.bold))),
            ...availableDestinations.map((f) => ListTile(
              leading: Icon(f == '+ Новая папка' ? Icons.create_new_folder : Icons.folder_open),
              title: Text(f),
              onTap: () async {
                 if (f == '+ Новая папка') {
                    Navigator.pop(context, 'NEW_FOLDER_ACTION');
                 } else {
                    Navigator.pop(context, f);
                 }
              },
            )),
          ],
        ),
      ),
    );

    if (result == 'NEW_FOLDER_ACTION') {
        // Ask for name
        final controller = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Новая папка'),
            content: TextField(
              controller: controller, 
              decoration: const InputDecoration(hintText: 'Название'),
              autofocus: true,
            ),
            actions: [
               TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Отмена")),
               TextButton(onPressed: ()=>Navigator.pop(context, controller.text), child: const Text("Создать")),
            ]
          )
        );
        
        if (name != null && name.isNotEmpty && calc.firebaseId != null) {
             await _firestoreService.updateGroup(calc.firebaseId!, name);
             _loadData();
        }
    } else if (result != null && calc.firebaseId != null) {
      final newGroup = result == '(Корневая папка)' ? null : result;
      await _firestoreService.updateGroup(calc.firebaseId!, newGroup);
      _loadData();
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
      _loadData();
    }
  }



  Future<void> _editCalculation(Calculation calc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalculationScreen(existingCalculation: calc),
      ),
    );
    // Refresh list after returning (in case of changes)
    _loadData();
  }

  Future<void> _confirmClearAll() async {
    // Clear All not implemented in FirestoreService yet (safe guard against wiping cloud details easily).
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция "Очистить все" отключена для безопасности облачных данных')));
  }

  Future<void> _handleExport() async {
      // Export current list to JSON
      // DataTransferService handles sharing.
      // Need to adjust DataTransferService to accept list of calculations?
      // Or just serialize _allCalculations.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Экспорт в разработке')));
  }

  Future<void> _handleImport() async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Импорт отключен (данные синхронизируются с облаком)')));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentFolder != null) {
          _goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: (_currentFolder != null || Navigator.canPop(context)) 
             ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
             : null,
          title: Text(_currentFolder ?? 'История'),
          actions: [
             // Removed Export/Import/ClearAll for now as we are on Cloud Sync
             IconButton(
               icon: const Icon(Icons.refresh),
               onPressed: _loadData,
               tooltip: 'Обновить',
             ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Поиск',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                             _searchController.clear();
                             setState(() => _searchQuery = '');
                             _applyFilters();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _applyFilters();
                },
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                         // Folders Section (Only in root and NO SEARCH active)
                         if (_currentFolder == null && _folders.isNotEmpty && _searchQuery.isEmpty) ...[
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 8),
                             child: Text('Папки', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                           ),
                           ..._folders.map((folder) => Card(
                             elevation: 2,
                             margin: const EdgeInsets.only(bottom: 8),
                             child: ListTile(
                               leading: const Icon(Icons.folder, color: Colors.orange, size: 32),
                               title: Text(folder, style: const TextStyle(fontWeight: FontWeight.bold)),
                               trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                               onTap: () => _openFolder(folder),
                               onLongPress: () => _deleteFolder(folder),
                             ),
                           )),
                           const SizedBox(height: 16),
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 8),
                             child: Text('Файлы', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                           ),
                         ],
      
                         // Calculations List
                         if (_processedCalculations.isEmpty && (_folders.isEmpty || _searchQuery.isNotEmpty || _currentFolder != null))
                            const Center(child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text("Ничего нет", style: TextStyle(color: Colors.grey)),
                            )),
      
                         ..._processedCalculations.map((calc) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: calc.gender == 'М'
                                    ? Colors.blue.withOpacity(0.2)
                                    : Colors.pink.withOpacity(0.2),
                                child: Icon(
                                  calc.gender == 'М' ? Icons.male : Icons.female,
                                  color: calc.gender == 'М' ? Colors.blue : Colors.pink,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                calc.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                calc.birthDate,
                              ),

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

                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editCalculation(calc);
                                      } else if (value == 'delete' && calc.firebaseId != null) {
                                        _deleteCalculation(calc.firebaseId!, calc.name);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.perm_contact_calendar_outlined, color: Colors.blueGrey),
                                            SizedBox(width: 8),
                                            Text('Изменить данные'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Удалить'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    iconSize: 20,
                                    tooltip: 'Ещё',
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ResultScreen(calculation: calc),
                                  ),
                                );
                              },
                            ),
                          )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
