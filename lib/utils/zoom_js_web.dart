import 'dart:js_interop';

@JS('initZoom')
external void _initZoom(String meetingId, String password, String name, String sdkKey, String sdkSecret, JSAny? customization);

@JS('leaveZoom')
external void _leaveZoom();

@JS('toggleZoomGrid')
external void _toggleZoomGrid(bool enable);

void initZoom(String meetingId, String password, String name, String sdkKey, String sdkSecret, [Map<String, dynamic>? customization]) {
  final jsCustomization = customization != null ? customization.jsify() : null;
  _initZoom(meetingId, password, name, sdkKey, sdkSecret, jsCustomization);
}

void leaveZoom() {
  _leaveZoom();
}

void toggleZoomGrid(bool enable) {
  _toggleZoomGrid(enable);
}
