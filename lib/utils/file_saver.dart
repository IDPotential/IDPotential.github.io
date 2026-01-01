import 'package:universal_io/io.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class FileSaver {
  static Future<String> saveImage(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      _saveWeb(bytes, fileName);
      return 'Изображение сохранено в загрузки';
    } else {
      return await _saveFile(bytes, fileName);
    }
  }

  static void _saveWeb(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
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
