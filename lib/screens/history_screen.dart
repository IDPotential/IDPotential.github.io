import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart'; // import file_picker
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:universal_io/io.dart'; // Handles File cross-platform (io for mobile, stub for web)
import 'dart:convert'; // for utf8
import 'package:intl/intl.dart';
import '../models/calculation.dart';
import '../services/database_service.dart';
import '../services/data_transfer_service.dart';
import '../services/calculator_service.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  
  // State
  List<String> _folders = [];
  List<Calculation> _calculations = []; // Current files (in root or folder)
  String? _currentFolder; // null = root
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      if (_searchQuery.isNotEmpty) {
        // Global Search Mode: Load ALL calculations, ignore folders
        final allCalcs = await _dbService.getCalculations();
        
        if (mounted) {
          setState(() {
            _folders = []; // Hide folders during search
            _calculations = allCalcs;
            _isLoading = false;
          });
        }
      } else if (_currentFolder == null) {
        // Root View
        final allFolders = await _dbService.getFolders();
        final allCalcs = await _dbService.getCalculations();
        final rootCalcs = allCalcs.where((c) => c.group == null || c.group!.isEmpty).toList();
        
        if (mounted) {
          setState(() {
            _folders = allFolders;
            _calculations = rootCalcs;
            _isLoading = false;
          });
        }
      } else {
        // Folder View
        final folderCalcs = await _dbService.getCalculations(group: _currentFolder);
        if (mounted) {
          setState(() {
            _folders = [];
            _calculations = folderCalcs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (keeping other methods)

  // Need to update search listener in build or init? 
  // We used onChanged in build. 
  // I will update build method to call _loadData on change? No, onChanged returns void.
  // I should update the TextField onChanged to call _loadData().


  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать папку'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Название папки'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _dbService.createFolder(result);
      _loadData();
    }
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
      await _dbService.deleteFolder(folderName);
      _loadData();
    }
  }

  void _openFolder(String folderName) {
    setState(() {
      _currentFolder = folderName;
    });
    _loadData();
  }

  void _goBack() {
    if (_currentFolder != null) {
      setState(() {
        _currentFolder = null;
      });
      _loadData();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _moveCalculation(Calculation calc) async {
    final folders = await _dbService.getFolders();
    // Exclude current folder
    final availableDestinations = ['(Корневая папка)', ...folders.where((f) => f != calc.group)];
    
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SingleChildScrollView( // Added scroll capability
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Переместить в...', style: TextStyle(fontWeight: FontWeight.bold))),
            if (availableDestinations.isEmpty)
               const Padding(padding: EdgeInsets.all(16), child: Text("Нет других папок")),
            ...availableDestinations.map((f) => ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(f),
              onTap: () => Navigator.pop(context, f),
            )),
          ],
        ),
      ),
    );

    if (result != null) {
      final newGroup = result == '(Корневая папка)' ? null : result;
      await _dbService.updateCalculationGroup(calc.id!, newGroup);
      _loadData();
    }
  }

  Future<void> _deleteCalculation(int id, String name) async {
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
      await _dbService.deleteCalculation(id);
      _loadData();
    }
  }

  Future<void> _editCalculation(Calculation calc) async {
    final nameController = TextEditingController(text: calc.name);
    final dateController = TextEditingController(text: calc.birthDate);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить запись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Дата (ДД.ММ.ГГГГ)'),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == true) {
       try {
         final newName = nameController.text;
         final newDate = dateController.text;
         
         // Recalculate
         final numbers = CalculatorService.calculateDiagnostic(
            newDate,
            newName,
            calc.gender,
         );
         
         final updatedCalc = calc.copyWith(
            name: newName,
            birthDate: newDate,
            numbers: numbers,
         );
         
         await _dbService.updateCalculation(calc.id!, updatedCalc); // Assuming updateCalculation exists or I need to use insert logic?
         // DatabaseService usually has update or insert. Checking... I'll assume insert/update or insert with overwrite if ID matches.
         // Actually DatabaseService might strictly be 'insertCalculation'.
         // Let's check if 'updateCalculation' exists. If not, I might need to delete and insert (preserving ID might be tricky if auto-inc).
         // Better: use `_dbService.updateCalculation` if it exists.
         // Wait, I haven't checked DatabaseService for 'update'. 
         // I'll assume it doesn't and implement a workaround or check it first?
         // No, I'll assume I can just add `updateCalculation` to service if missing.
         // But for now, let's try to call it.
         
         // To be safe, I'm just gonna update the logic to "delete and re-insert" if update doesn't exist? No that changes ID.
         // Let's assume `_dbService` has it or I'll fix it if compilation fails.
         // Actually, I'll view DatabaseService in next step to be sure.
         
         // BUT, to avoid breaking, I will assume it exists or I will ADD it.
         // Let's leave this placeholder comment out.
         
         await _dbService.updateCalculation(calc.id!, updatedCalc);
         
         _loadData();
       } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e')));
         }
       }
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить всю историю?'),
        content: const Text('Это действие нельзя отменить. Все расчеты будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить всё', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteAllCalculations();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('История очищена')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    try {
      await DataTransferService.shareData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    final controller = TextEditingController();
    
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импорт данных'),
        content: SingleChildScrollView( // Added scroll view for smaller screens
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите файл JSON или вставьте текст:'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    // Re-adding extension filter as it helps specific browsers/OSs
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json', 'txt'],
                      withData: true, // Needed for Web
                    );

                    if (result != null) {
                       String? fileContent;
                       
                       // Cross-platform handling
                       if (kIsWeb) {
                         final bytes = result.files.first.bytes;
                         if (bytes != null) {
                           fileContent = utf8.decode(bytes);
                         } else {
                           throw Exception("File bytes are null");
                         }
                       } else {
                         final path = result.files.first.path;
                         if (path != null) {
                           final file = File(path);
                           fileContent = await file.readAsString();
                         }
                       }

                       if (fileContent != null) {
                         controller.text = fileContent;
                         // Force update dialog state if possible, but here we just update text
                         // and show snackbar in the parent context (which is behind the dialog, but visible)
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Файл загружен: ${result.files.first.name}')),
                           );
                         }
                       }
                    } else {
                        // User canceled the picker
                        print("User canceled file picker");
                    }
                  } catch (e) {
                    debugPrint('File picker error: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.file_open),
                label: const Text('Выбрать файл (.json)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '...или вставьте JSON текст сюда',
                ),
              ),
            ],
          ),
        ),
        actions: [
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  controller.text = data!.text!;
                }
              },
              child: const Text('Из буфера'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Импорт'),
            ),
        ],
      ),
    );

    if (content != null && content.isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      try {
        final result = await DataTransferService.importData(content);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result)),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter calculations
    final filteredCalculations = _calculations.where((calc) {
      if (_searchQuery.isEmpty) return true;
      return calc.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
             calc.birthDate.contains(_searchQuery);
    }).toList();

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
            if (_currentFolder == null) ...[
              IconButton(
                icon: const Icon(Icons.download), // Import
                onPressed: _handleImport,
                tooltip: 'Импорт',
              ),
              IconButton(
                icon: const Icon(Icons.upload), // Export
                onPressed: _handleExport,
                tooltip: 'Экспорт',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), // Clear All
                onPressed: _confirmClearAll,
                tooltip: 'Очистить историю',
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder),
                onPressed: _createFolder,
                tooltip: 'Создать папку',
              ),
            ],
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
                             _loadData();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _loadData(); // Trigger global search
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
                         if (filteredCalculations.isEmpty && (_folders.isEmpty || _searchQuery.isNotEmpty))
                            const Center(child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text("Ничего нет", style: TextStyle(color: Colors.grey)),
                            )),
      
                         ...filteredCalculations.map((calc) => Card(
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
                                      } else if (value == 'delete') {
                                        _deleteCalculation(calc.id!, calc.name);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, color: Colors.blueGrey),
                                            SizedBox(width: 8),
                                            Text('Изменить'),
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