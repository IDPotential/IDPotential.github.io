import 'dart:ui_web' as ui_web;
import 'package:universal_html/html.dart' as html;

void registerJitsiViewFactory(String viewType, String url) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
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
    final div = html.DivElement()
      ..id = 'zoom-meeting-container'
      ..style.height = '100%'
      ..style.width = '100%'
      ..style.backgroundColor = 'black';
    return div;
  });
}
