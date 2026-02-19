import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerJitsiViewFactory(String viewType, String url) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = url
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%'
      ..allow = 'camera; microphone; fullscreen; display-capture; autoplay';
    return iframe;
  });
}

void registerZoomViewFactory(String viewType) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div = web.document.createElement('div') as web.HTMLDivElement
      ..id = 'zoom-meeting-container'
      ..style.height = '100%'
      ..style.width = '100%'
      ..style.position = 'relative'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = 'black';
    return div;
  });
}
