void downloadFileWeb(List<int> bytes, String fileName) {
  // No-op on non-web or when js_interop not available
  throw UnimplementedError("Web download not supported on this platform without dart:js_interop");
}
