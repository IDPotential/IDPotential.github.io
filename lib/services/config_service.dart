import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1), // Use lower for dev
      ));

      await _remoteConfig.setDefaults({
        'zoom_sdk_key': '',
        'zoom_sdk_secret': '',
      });

      await _remoteConfig.fetchAndActivate();
      debugPrint("Remote Config Initialized");
    } catch (e) {
      debugPrint("Remote Config Error: $e");
    }
  }

  String get zoomKey => _remoteConfig.getString('zoom_sdk_key');
  String get zoomSecret => _remoteConfig.getString('zoom_sdk_secret');
}
