import 'dart:js' as js;

void initZoom(String meetingId, String password, String name, String sdkKey, String sdkSecret, [Map<String, dynamic>? customization]) {
  final jsCustomization = customization != null ? js.JsObject.jsify(customization) : js.JsObject.jsify({});
  js.context.callMethod('initZoom', [meetingId, password, name, sdkKey, sdkSecret, jsCustomization]);
}


void leaveZoom() {
  js.context.callMethod('leaveZoom');
}

void toggleZoomGrid(bool enable) {
  js.context.callMethod('toggleZoomGrid', [enable]);
}
