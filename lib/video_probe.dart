import 'video_probe_platform_interface.dart';
import 'video_probe_method_channel.dart';
// Note: Conditionals would be needed for correct registration if not using pubspec's dartPluginClass for all.
// But we used pubspec registration for web and native.
// For native FFI, we need to ensure FFI implementation is used if not handled by auto-registration.
// Since we didn't add 'dartPluginClass' to pubspec for native, we might need manual registration or updating pubspec.
// For now, let's keep the user facing API clean.

// Ideally, we add 'dartPluginClass: VideoProbeFfi' to pubspec for native platforms so it auto-registers.
// But let's assume valid platform interface usage.

import 'video_probe_ffi.dart';
import 'package:flutter/foundation.dart';

class VideoProbe {
  static bool _manualRegistrationDone = false;

  /// Resets internal state for testing purposes.
  @visibleForTesting
  static void resetForTesting() {
    _manualRegistrationDone = false;
  }

  static void _ensureInitialized() {
    if (_manualRegistrationDone) return;
    // Only register FFI if the platform instance is still the default MethodChannel
    // This allows tests to set a mock before calling methods
    if (!kIsWeb && VideoProbePlatform.instance is MethodChannelVideoProbe) {
      VideoProbeFfi.registerWith();
    }
    _manualRegistrationDone = true;
  }

  Future<String?> getPlatformVersion() {
    return VideoProbePlatform.instance.getPlatformVersion();
  }

  Future<double> getDuration(String path) {
    _ensureInitialized();
    return VideoProbePlatform.instance.getDuration(path);
  }

  Future<int> getFrameCount(String path) {
    _ensureInitialized();
    return VideoProbePlatform.instance.getFrameCount(path);
  }

  Future<Uint8List?> extractFrame(String path, int frameNum) {
    _ensureInitialized();
    return VideoProbePlatform.instance.extractFrame(path, frameNum);
  }
}
