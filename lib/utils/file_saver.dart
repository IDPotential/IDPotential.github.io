import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileSaver {
  static Future<String> saveImage(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      _saveWeb(bytes, fileName);
      return 'Изображение сохранено в загрузки';
    } else {
      return await _saveFile(bytes, fileName);
    }
  }

  static Future<String> saveText(String text, String fileName) async {
    if (kIsWeb) {
      _saveWebText(text, fileName);
      return 'Файл сохранен в загрузки';
    } else {
      // Use existing _saveFile but convert string to bytes
      return await _saveFile(Uint8List.fromList(text.codeUnits), fileName); // Basic UTF8
    }
  }

  static void _saveWeb(Uint8List bytes, String fileName) async {
    // WASM compatible: Use Data URI
    final String base64 = base64Encode(bytes);
    final String uri = 'data:application/octet-stream;base64,$base64';
    if (await canLaunchUrl(Uri.parse(uri))) {
       await launchUrl(Uri.parse(uri));
    }
  }

  static void _saveWebText(String text, String fileName) async {
    // WASM compatible: Use Data URI
    final uri = Uri.dataFromString(
       text, 
       mimeType: 'text/plain', 
       encoding: utf8
    ).toString();
    
    if (await canLaunchUrl(Uri.parse(uri))) {
       await launchUrl(Uri.parse(uri));
    }
  }

  static Future<String> _saveFile(Uint8List bytes, String fileName) async {
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
  }
}
