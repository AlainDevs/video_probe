import 'package:flutter_test/flutter_test.dart';
import 'package:video_probe/video_probe.dart';
import 'package:video_probe/video_probe_platform_interface.dart';
import 'package:video_probe/video_probe_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoProbePlatform
    with MockPlatformInterfaceMixin
    implements VideoProbePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VideoProbePlatform initialPlatform = VideoProbePlatform.instance;

  test('$MethodChannelVideoProbe is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVideoProbe>());
  });

  test('getPlatformVersion', () async {
    VideoProbe videoProbePlugin = VideoProbe();
    MockVideoProbePlatform fakePlatform = MockVideoProbePlatform();
    VideoProbePlatform.instance = fakePlatform;

    expect(await videoProbePlugin.getPlatformVersion(), '42');
  });
}
