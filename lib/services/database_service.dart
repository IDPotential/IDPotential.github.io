import 'package:hive_flutter/hive_flutter.dart';
import '../models/calculation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  
  static const String _calculationsBox = 'calculations';
  static const String _foldersBoxName = 'folders';
  static const String _settingsBoxName = 'settings';
  bool _isInitialized = false;
  
  DatabaseService._internal();
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    // Регистрируем адаптер для Calculation
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CalculationAdapter());
    }
    
    await Hive.openBox<Calculation>(_calculationsBox);
    await Hive.openBox<String>(_foldersBoxName);
    await Hive.openBox(_settingsBoxName);
    _isInitialized = true;
  }
  
  Box<Calculation> get _box => Hive.box<Calculation>(_calculationsBox);
  Box<String> get _foldersBox => Hive.box<String>(_foldersBoxName);
  Box get settingsBox => Hive.box(_settingsBoxName);
  
  // CRUD операции для расчетов
  Future<int> insertCalculation(Calculation calculation) async {
    await init();
    // Use Hive's auto-increment key generation (safe for Web)
    final id = await _box.add(calculation);
    
    // Update the object with its assigned ID
    final calcWithId = calculation.copyWith(id: id);
    await _box.put(id, calcWithId);
    
    return id;
  }
  
  Future<List<Calculation>> getCalculations({String? group}) async {
    await init();
    final calculations = _box.values.toList();
    
    if (group != null) {
      return calculations.where((calc) => calc.group == group).toList();
    }
    
    // Сортируем по дате создания (новые сначала)
    calculations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return calculations;
  }
  
  // Folder Operations
  Future<List<String>> getFolders() async {
    await init();
    // Get explicit folders
    final folders = _foldersBox.values.toList();
    
    // Also get implicit groups (if created by some other means)
    final implicitGroups = _box.values
        .map((c) => c.group)
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>();
        
    final allFolders = {...folders, ...implicitGroups}.toList()..sort();
    return allFolders;
  }
  
  Future<void> createFolder(String name) async {
    await init();
    if (!_foldersBox.values.contains(name)) {
      await _foldersBox.add(name);
    }
  }
  
  Future<void> deleteFolder(String name) async {
    await init();
    // Delete validation from box
    final Map<dynamic, String> folderMap = _foldersBox.toMap().cast<dynamic, String>();
    final entry = folderMap.entries.firstWhere((e) => e.value == name, orElse: () => const MapEntry(-1, ''));
    
    if (entry.key != -1) {
      await _foldersBox.delete(entry.key);
    }
    
    // Also "ungroup" items in this folder
    final itemsInFolder = (await getCalculations(group: name));
    for (var item in itemsInFolder) {
      await updateCalculationGroup(item.id!, null);
    }
  }

  Future<void> renameFolder(String oldName, String newName) async {
    await init();
    
    // 1. Rename in folders box
    final Map<dynamic, String> folderMap = _foldersBox.toMap().cast<dynamic, String>();
    final entry = folderMap.entries.firstWhere((e) => e.value == oldName, orElse: () => const MapEntry(-1, ''));
    
    if (entry.key != -1) {
      await _foldersBox.put(entry.key, newName);
    } else {
      // Create if didn't exist explicitly
      await createFolder(newName);
    }
    
    // 2. Move items
    final items = await getCalculations(group: oldName);
    for (var item in items) {
      await updateCalculationGroup(item.id!, newName);
    }
  }
  
  Future<void> updateCalculationGroup(int id, String? group) async {
    await init();
    final calc = _box.get(id);
    if (calc != null) {
      // Convert null to empty string to ensure it overwrites existing group
      // because copyWith(group: null) would ignore the change.
      final newGroup = group ?? ''; 
      await _box.put(id, calc.copyWith(group: newGroup));
    }
  }
  
  Future<void> deleteCalculation(int id) async {
    await init(); // Retained for consistency with other methods
    await _box.delete(id);
  }

  Future<void> deleteAllCalculations() async {
    await init(); // Added for consistency
    await _box.clear();
  }
  
  Future<void> updateDecryptionStatus(int id, int decryption) async {
    await init();
    final calc = _box.get(id);
    if (calc != null) {
      await _box.put(id, calc.copyWith(decryption: decryption));
    }
  }

  Future<void> updateCalculation(int id, Calculation updatedCalc) async {
    await init();
    await _box.put(id, updatedCalc);
  }
  
  Future<void> clearAll() async {
    await init();
    await _box.clear();
    await _foldersBox.clear();
  }
}