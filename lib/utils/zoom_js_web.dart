import 'dart:js' as js;

void initZoom(String meetingId, String password, String name, String sdkKey, String sdkSecret) {
  js.context.callMethod('initZoom', [meetingId, password, name, sdkKey, sdkSecret]);
}

void leaveZoom() {
  js.context.callMethod('leaveZoom');
}
