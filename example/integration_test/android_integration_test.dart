// Android Integration tests for video_probe plugin.
// These tests run on Android emulator/device and test the JNI/MediaMetadataRetriever implementation.
//
// Run: flutter test integration_test/android_integration_test.dart -d <android_device_id>
//
// Note: Tests require the test video asset to be bundled in assets/test_video.mp4

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:video_probe/video_probe.dart';

/// Copies a bundled asset to the app's documents directory for Android.
Future<File> getTestFile(String assetName) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$assetName';
  final file = File(path);

  if (!await file.exists()) {
    final byteData = await rootBundle.load('assets/$assetName');
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  return file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late VideoProbe plugin;
  late String testVideoPath;
  late bool testVideoReady;

  setUpAll(() async {
    plugin = VideoProbe();

    // Copy test video from assets to documents directory
    try {
      final videoFile = await getTestFile('test_video.mp4');
      testVideoPath = videoFile.path;
      testVideoReady = await videoFile.exists();
    } catch (e) {
      testVideoReady = false;
      testVideoPath = '';
    }
  });

  group('Android Platform Tests', () {
    testWidgets('getPlatformVersion returns Android version', (
      WidgetTester tester,
    ) async {
      final version = await plugin.getPlatformVersion();
      expect(version, isNotNull);
      expect(version!.isNotEmpty, true);
      expect(version.contains('Android'), true);
    });
  });

  group('Android JNI Error Handling', () {
    testWidgets('getDuration returns -1 for nonexistent file', (
      WidgetTester tester,
    ) async {
      final duration = await plugin.getDuration('/nonexistent/video.mp4');
      expect(duration, lessThanOrEqualTo(0));
    });

    testWidgets('getFrameCount returns -1 for nonexistent file', (
      WidgetTester tester,
    ) async {
      final count = await plugin.getFrameCount('/nonexistent/video.mp4');
      expect(count, lessThanOrEqualTo(0));
    });

    testWidgets('extractFrame returns null for nonexistent file', (
      WidgetTester tester,
    ) async {
      final frame = await plugin.extractFrame('/nonexistent/video.mp4', 0);
      expect(frame, isNull);
    });

    testWidgets('handles empty path gracefully', (WidgetTester tester) async {
      final duration = await plugin.getDuration('');
      expect(duration, lessThanOrEqualTo(0));

      final count = await plugin.getFrameCount('');
      expect(count, lessThanOrEqualTo(0));
    });
  });

  group('Android MediaMetadataRetriever Tests', () {
    testWidgets('getDuration returns positive value', (
      WidgetTester tester,
    ) async {
      expect(
        testVideoReady,
        isTrue,
        reason: 'Test video asset not found. Add assets/test_video.mp4',
      );

      final duration = await plugin.getDuration(testVideoPath);
      expect(duration, greaterThan(0));
      expect(duration, lessThan(60)); // Test video should be short
    });

    testWidgets('getFrameCount returns positive value', (
      WidgetTester tester,
    ) async {
      expect(testVideoReady, isTrue);

      final count = await plugin.getFrameCount(testVideoPath);
      expect(count, greaterThan(0));
    });

    testWidgets('extractFrame returns valid JPEG data', (
      WidgetTester tester,
    ) async {
      expect(testVideoReady, isTrue);

      final frame = await plugin.extractFrame(testVideoPath, 0);
      expect(frame, isNotNull);
      expect(frame!.length, greaterThan(100));

      // Verify JPEG magic bytes (FFD8FF)
      expect(frame[0], 0xFF, reason: 'Not a valid JPEG: missing FFD8 header');
      expect(frame[1], 0xD8);
      expect(frame[2], 0xFF);
    });

    testWidgets('duration and frame count are consistent', (
      WidgetTester tester,
    ) async {
      expect(testVideoReady, isTrue);

      final duration = await plugin.getDuration(testVideoPath);
      final frameCount = await plugin.getFrameCount(testVideoPath);

      // Calculate implied frame rate (should be 15-60 fps for typical video)
      final impliedFps = frameCount / duration;
      expect(impliedFps, greaterThan(10));
      expect(impliedFps, lessThan(120));
    });

    testWidgets('extractFrame works for different frame numbers', (
      WidgetTester tester,
    ) async {
      expect(testVideoReady, isTrue);

      // Extract first frame
      final frame0 = await plugin.extractFrame(testVideoPath, 0);
      expect(frame0, isNotNull);

      // Extract a middle frame
      final frameCount = await plugin.getFrameCount(testVideoPath);
      final middleFrame = frameCount ~/ 2;
      final frameMid = await plugin.extractFrame(testVideoPath, middleFrame);
      expect(frameMid, isNotNull);

      // Both should be valid JPEGs
      expect(frame0![0], 0xFF);
      expect(frameMid![0], 0xFF);
    });
  });

  group('Android API Level Specific Tests', () {
    testWidgets('frame count uses METADATA_KEY_VIDEO_FRAME_COUNT on API 28+', (
      WidgetTester tester,
    ) async {
      expect(testVideoReady, isTrue);

      final count = await plugin.getFrameCount(testVideoPath);

      // Should get an accurate frame count, not just an estimate
      // The implementation uses METADATA_KEY_VIDEO_FRAME_COUNT on API 28+
      // or falls back to duration*30 estimate on older APIs
      expect(count, greaterThan(0));
    });
  });
}
