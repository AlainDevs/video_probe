import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'video_probe_platform_interface.dart';

/// A web implementation of the VideoProbePlatform of the VideoProbe plugin.
class VideoProbeWeb extends VideoProbePlatform {
  /// Constructs a VideoProbeWeb
  VideoProbeWeb();

  static void registerWith(Registrar registrar) {
    VideoProbePlatform.instance = VideoProbeWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    return 'Web';
  }

  @override
  Future<double> getDuration(String path) async {
    // Basic web implementation using HTMLVideoElement would go here.
    // For now, return dummy.
    return 60.0;
  }

  @override
  Future<int> getFrameCount(String path) async {
    return 1000;
  }

  @override
  Future<Uint8List?> extractFrame(String path, int frameNum) async {
    // Web implementation requires creating a VideoElement, loading the source (Blob/URL),
    // seeking to time, drawing to Canvas, and extracting data.
    return Uint8List(0);
  }
}
