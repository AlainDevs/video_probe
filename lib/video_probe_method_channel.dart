import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_probe_platform_interface.dart';

/// An implementation of [VideoProbePlatform] that uses method channels.
class MethodChannelVideoProbe extends VideoProbePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_probe');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<double> getDuration(String path) async {
    // If we were implementing MethodChannel fallback, it would go here.
    throw UnimplementedError(
      'getDuration() via MethodChannel is not implemented. Use FFI.',
    );
  }

  @override
  Future<int> getFrameCount(String path) async {
    throw UnimplementedError(
      'getFrameCount() via MethodChannel is not implemented. Use FFI.',
    );
  }

  @override
  Future<Uint8List?> extractFrame(String path, int frameNum) async {
    throw UnimplementedError(
      'extractFrame() via MethodChannel is not implemented. Use FFI.',
    );
  }
}
