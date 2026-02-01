
import 'video_probe_platform_interface.dart';

class VideoProbe {
  Future<String?> getPlatformVersion() {
    return VideoProbePlatform.instance.getPlatformVersion();
  }
}
