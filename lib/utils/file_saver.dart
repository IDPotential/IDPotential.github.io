import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart'; // Unused in current build

import 'web_helpers_stub.dart' if (dart.library.js_interop) 'web_helpers.dart';

class FileSaver {
  static Future<String> saveImage(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      downloadFileWeb(bytes, fileName);
      return 'Изображение сохранено в загрузки';
    } else {
      return await _saveFile(bytes, fileName);
    }
  }

  static Future<String> saveText(String text, String fileName) async {
    if (kIsWeb) {
       // Convert string to bytes for blob download
       final bytes = utf8.encode(text);
       downloadFileWeb(bytes, fileName);
       return 'Файл сохранен в загрузки';
    } else {
      // Use existing _saveFile but convert string to bytes
      return await _saveFile(Uint8List.fromList(text.codeUnits), fileName); // Basic UTF8
    }
  }

  // Deprecated internal helpers removed


  static Future<String> _saveFile(Uint8List bytes, String fileName) async {
    // TEMP FIX: Disable IO saving to check WASM build
    if (kIsWeb) return 'Not supported';
    return 'Saving not implemented for this build debugging session';
    /*
    try {
      String? downloadPath;
      
      if (Platform.isAndroid) {
        downloadPath = '/storage/emulated/0/Download';
      } else {
        final directory = await getDownloadsDirectory();
        downloadPath = directory?.path;
      }

      if (downloadPath == null) {
         // Fallback to documents if downloads is unavailable (unlikely on supported platforms)
         final directory = await getApplicationDocumentsDirectory();
         downloadPath = directory.path;
      }
      
      final path = '$downloadPath/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes);
      return 'Сохранено в: $path';
    } catch (e) {
      throw Exception('Ошибка сохранения файла: $e');
    }
    */
  }
}
