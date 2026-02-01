
import 'package:flutter/foundation.dart';

import 'video_probe_platform_interface.dart';
import 'video_probe_method_channel.dart';

// Conditional import: only load FFI on non-web platforms
import 'video_probe_ffi_stub.dart' if (dart.library.ffi) 'video_probe_ffi.dart';

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
    // and we're not on web
    if (!kIsWeb && VideoProbePlatform.instance is MethodChannelVideoProbe) {
      registerFfiImplementation();
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
