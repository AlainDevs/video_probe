import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:video_probe/video_probe.dart';
import 'package:video_probe/video_probe_platform_interface.dart';
import 'package:video_probe/video_probe_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock platform implementation for unit testing.
/// Must be set BEFORE creating VideoProbe instance.
class MockVideoProbePlatform
    with MockPlatformInterfaceMixin
    implements VideoProbePlatform {
  double mockDuration = 120.5;
  int mockFrameCount = 3000;
  Uint8List? mockFrameData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
  bool shouldFail = false;

  @override
  Future<String?> getPlatformVersion() => Future.value('test-version');

  @override
  Future<double> getDuration(String path) {
    if (shouldFail || path.isEmpty) return Future.value(-1.0);
    return Future.value(mockDuration);
  }

  @override
  Future<int> getFrameCount(String path) {
    if (shouldFail || path.isEmpty) return Future.value(-1);
    return Future.value(mockFrameCount);
  }

  @override
  Future<Uint8List?> extractFrame(String path, int frameNum) {
    if (shouldFail || path.isEmpty || frameNum < 0) return Future.value(null);
    return Future.value(mockFrameData);
  }
}

void main() {
  group('VideoProbePlatform', () {
    test('MethodChannelVideoProbe is the default instance', () {
      // This just checks the type, doesn't invoke FFI
      expect(
        VideoProbePlatform.instance,
        isInstanceOf<MethodChannelVideoProbe>(),
      );
    });
  });

  group('VideoProbe API with Mock', () {
    late VideoProbe plugin;
    late MockVideoProbePlatform mockPlatform;

    setUp(() {
      // Reset VideoProbe state and set mock BEFORE creating plugin instance
      VideoProbe.resetForTesting();
      mockPlatform = MockVideoProbePlatform();
      VideoProbePlatform.instance = mockPlatform;
      plugin = VideoProbe();
    });

    test('getPlatformVersion returns version string', () async {
      expect(await plugin.getPlatformVersion(), 'test-version');
    });

    group('getDuration', () {
      test('returns duration for valid path', () async {
        mockPlatform.mockDuration = 60.5;
        final duration = await plugin.getDuration('/path/to/video.mp4');
        expect(duration, 60.5);
      });

      test('returns -1.0 for empty path', () async {
        final duration = await plugin.getDuration('');
        expect(duration, -1.0);
      });

      test('returns -1.0 on failure', () async {
        mockPlatform.shouldFail = true;
        final duration = await plugin.getDuration('/path/to/video.mp4');
        expect(duration, -1.0);
      });
    });

    group('getFrameCount', () {
      test('returns frame count for valid path', () async {
        mockPlatform.mockFrameCount = 1000;
        final count = await plugin.getFrameCount('/path/to/video.mp4');
        expect(count, 1000);
      });

      test('returns -1 for empty path', () async {
        final count = await plugin.getFrameCount('');
        expect(count, -1);
      });

      test('returns -1 on failure', () async {
        mockPlatform.shouldFail = true;
        final count = await plugin.getFrameCount('/path/to/video.mp4');
        expect(count, -1);
      });
    });

    group('extractFrame', () {
      test('returns frame data for valid path and frame', () async {
        mockPlatform.mockFrameData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final frame = await plugin.extractFrame('/path/to/video.mp4', 0);
        expect(frame, isNotNull);
        expect(frame!.length, 5);
      });

      test('returns null for empty path', () async {
        final frame = await plugin.extractFrame('', 0);
        expect(frame, isNull);
      });

      test('returns null for negative frame number', () async {
        final frame = await plugin.extractFrame('/path/to/video.mp4', -1);
        expect(frame, isNull);
      });

      test('returns null on failure', () async {
        mockPlatform.shouldFail = true;
        final frame = await plugin.extractFrame('/path/to/video.mp4', 0);
        expect(frame, isNull);
      });
    });
  });

  group('Edge cases', () {
    late VideoProbe plugin;
    late MockVideoProbePlatform mockPlatform;

    setUp(() {
      VideoProbe.resetForTesting();
      mockPlatform = MockVideoProbePlatform();
      VideoProbePlatform.instance = mockPlatform;
      plugin = VideoProbe();
    });

    test('handles very long duration', () async {
      mockPlatform.mockDuration = 86400.0; // 24 hours
      final duration = await plugin.getDuration('/video.mp4');
      expect(duration, 86400.0);
    });

    test('handles zero duration', () async {
      mockPlatform.mockDuration = 0.0;
      final duration = await plugin.getDuration('/video.mp4');
      expect(duration, 0.0);
    });

    test('handles large frame count', () async {
      mockPlatform.mockFrameCount = 1000000; // 1M frames
      final count = await plugin.getFrameCount('/video.mp4');
      expect(count, 1000000);
    });

    test('handles zero frame count', () async {
      mockPlatform.mockFrameCount = 0;
      final count = await plugin.getFrameCount('/video.mp4');
      expect(count, 0);
    });

    test('handles large frame extraction', () async {
      mockPlatform.mockFrameCount = 1000;
      final frame = await plugin.extractFrame('/video.mp4', 999);
      expect(frame, isNotNull);
    });
  });
}
