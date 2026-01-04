import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/calculation.dart';
import 'database_service.dart';
import 'package:share_plus/share_plus.dart';

class DataTransferService {
  static const int currentVersion = 1;

  /// Exports all data to a JSON string
  static Future<String> exportData() async {
    final calculations = await DatabaseService().getCalculations();
    final folders = await DatabaseService().getFolders();
    
    final data = {
      'version': currentVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'calculations': calculations.map((c) => c.toMap()).toList(),
      'folders': folders,
    };
    
    // Pretty print JSON
    return const JsonEncoder.withIndent('  ').convert(data);
  }
  
  /// Shares data via available system options
  static Future<void> shareData() async {
    final jsonString = await exportData();
    await Share.share(jsonString, subject: 'Diagnostic Data backup');
  }
  
  /// Copies data to clipboard
  static Future<void> copyToClipboard() async {
    final jsonString = await exportData();
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// Imports data from a JSON string.
  /// Returns a status string e.g. "Imported 5, Skipped 2 duplicates".
  static Future<String> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      // Basic validation
      if (!data.containsKey('calculations')) {
        throw Exception("Invalid data format: missing 'calculations' field");
      }
      
      final db = DatabaseService();
      final existingCalcs = await db.getCalculations();
      
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      List<String> errorDetails = [];
      
      final List<dynamic> calcList = data['calculations'];
      
      // Also restore implicit folders if any
      if (data.containsKey('folders')) {
        final List<dynamic> folderList = data['folders'];
        for (var f in folderList) {
          await db.createFolder(f.toString());
        }
      }

      for (var item in calcList) {
        try {
          final newCalc = Calculation.fromMap(item);
          
          // Check for duplicate
          bool isDuplicate = existingCalcs.any((existing) {
             bool sameMeta = existing.name == newCalc.name && existing.birthDate == newCalc.birthDate;
             if (!sameMeta) return false;
             
             // If meta matches, check numbers if available
             if (existing.numbers.isNotEmpty && newCalc.numbers.isNotEmpty) {
               return existing.numbers[0] == newCalc.numbers[0];
             }
             return true; // Assume duplicate if same name/date and no numbers to diff
          });
          
          if (!isDuplicate) {
             // Ensure group exists if specified
             if (newCalc.group != null && newCalc.group!.isNotEmpty) {
               await db.createFolder(newCalc.group!);
             }
             
             await db.insertCalculation(newCalc);
             imported++;
          } else {
            skipped++;
          }
        } catch (e) {
          errors++;
          errorDetails.add(e.toString());
          debugPrint("Error parsing item: $e");
        }
      }
      
      String status = "Импорт завершен: +$imported, дубликатов: $skipped.";
      if (errors > 0) {
        status += "\nОшибок: $errors. (Первая: ${errorDetails.first})";
      }
      return status;
      
    } catch (e) {
      return "Ошибка импорта: ${e.toString()}";
    }
  }
}
