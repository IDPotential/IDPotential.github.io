import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart';

void downloadFileWeb(List<int> bytes, String fileName) {
  final array = Uint8List.fromList(bytes).toJS;
  final blob = Blob([array].toJS);
  final url = URL.createObjectURL(blob);
  
  final anchor = document.createElement('a') as HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  
  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  
  URL.revokeObjectURL(url);
}
