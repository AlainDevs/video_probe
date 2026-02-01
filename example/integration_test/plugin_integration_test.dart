// Integration tests for video_probe plugin.
// These tests run on actual devices/simulators and test the native FFI bindings.
//
// Run on macOS: flutter test integration_test -d macos
// Run on iOS:   flutter test integration_test -d ios

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:video_probe/video_probe.dart';

/// Copies a bundled asset to the app's documents directory.
/// This allows tests to access files within the sandbox.
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

    // Copy test video from assets to documents directory (sandbox-safe)
    try {
      final videoFile = await getTestFile('test_video.mp4');
      testVideoPath = videoFile.path;
      testVideoReady = await videoFile.exists();
    } catch (e) {
      testVideoReady = false;
      testVideoPath = '';
    }
  });

  group('Platform Tests', () {
    testWidgets('getPlatformVersion returns non-empty string', (
      WidgetTester tester,
    ) async {
      final version = await plugin.getPlatformVersion();
      expect(version, isNotNull);
      expect(version!.isNotEmpty, true);

      if (Platform.isMacOS) {
        expect(version.contains('macOS'), true);
      } else if (Platform.isIOS) {
        expect(version.contains('iOS'), true);
      }
    });
  });

  group('FFI Error Handling', () {
    testWidgets('getDuration returns non-positive for nonexistent file', (
      WidgetTester tester,
    ) async {
      final duration = await plugin.getDuration('/nonexistent/video.mp4');
      expect(duration, lessThanOrEqualTo(0));
    });

    testWidgets('getFrameCount returns non-positive for nonexistent file', (
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

  group('Video Processing Tests', () {
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
  });
}
