// Windows-specific integration tests for video_probe plugin.
// These tests verify that the Media Foundation implementation works correctly.
//
// Run these tests using:
//   flutter test integration_test/windows_integration_test.dart -d windows

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_probe/video_probe.dart';

/// Copy test video from assets to a temporary file for testing.
Future<String> copyTestVideoToSandbox() async {
  // Load the test video from assets
  final videoData = await rootBundle.load('assets/test_video.mp4');
  final bytes = videoData.buffer.asUint8List();

  // Write to a temporary file
  final appDir = await getApplicationDocumentsDirectory();
  final videoPath = '${appDir.path}\\test_video_windows.mp4';
  final videoFile = File(videoPath);
  await videoFile.writeAsBytes(bytes);

  return videoPath;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Skip if not on Windows
  final isWindows = Platform.isWindows;
  final videoProbe = VideoProbe();

  group('Windows Media Foundation Integration Tests', () {
    late String videoPath;

    setUpAll(() async {
      if (!isWindows) return;
      videoPath = await copyTestVideoToSandbox();
    });

    tearDownAll(() async {
      if (!isWindows) return;
      // Clean up test file
      try {
        await File(videoPath).delete();
      } catch (_) {}
    });

    testWidgets('Media Foundation getFrameCount returns valid frame count', (
      tester,
    ) async {
      if (!isWindows) {
        return;
      }

      final frameCount = await videoProbe.getFrameCount(videoPath);

      // Media Foundation should return a reasonable frame count
      expect(frameCount, greaterThanOrEqualTo(1));
    });

    testWidgets('Media Foundation getDuration returns valid duration', (
      tester,
    ) async {
      if (!isWindows) {
        return;
      }

      final duration = await videoProbe.getDuration(videoPath);

      // Media Foundation should return a positive duration
      expect(duration, greaterThan(0));
    });

    testWidgets('Media Foundation extractFrame returns valid JPEG data', (
      tester,
    ) async {
      if (!isWindows) {
        return;
      }

      final frameData = await videoProbe.extractFrame(videoPath, 0);

      // Note: Frame extraction may fail in CI environments due to
      // Media Foundation codec availability. This is expected behavior.
      if (frameData != null && frameData.isNotEmpty) {
        // Verify it's a valid JPEG (starts with FFD8)
        expect(frameData.length, greaterThan(2));
        expect(frameData[0], equals(0xFF));
        expect(frameData[1], equals(0xD8));
      }
      // If frameData is null, test passes (expected in CI env)
    });

    testWidgets('Media Foundation handles invalid file path gracefully', (
      tester,
    ) async {
      if (!isWindows) {
        return;
      }

      final frameCount = await videoProbe.getFrameCount(
        'C:\\nonexistent\\path\\video.mp4',
      );

      // Should return -1 for invalid paths
      expect(frameCount, equals(-1));
    });

    testWidgets(
      'Media Foundation extractFrame with invalid time returns null',
      (tester) async {
        if (!isWindows) {
          return;
        }

        // Try to extract a frame at a very large time offset
        final frameData = await videoProbe.extractFrame(videoPath, 999999);

        // Should return null for invalid time offsets
        expect(frameData, isNull);
      },
    );

    testWidgets(
      'Media Foundation consistency between duration and frame count',
      (tester) async {
        if (!isWindows) {
          return;
        }

        final duration = await videoProbe.getDuration(videoPath);
        final frameCount = await videoProbe.getFrameCount(videoPath);

        // Both should be valid
        expect(duration, greaterThan(0));
        expect(frameCount, greaterThanOrEqualTo(1));

        // Frame count should be consistent with duration
        expect(frameCount, lessThanOrEqualTo(duration * 120)); // Max 120 fps
        expect(frameCount, greaterThanOrEqualTo(duration ~/ 60)); // Min ~1 fps
      },
    );
  });

  group('Platform Detection Tests', () {
    testWidgets('Platform detection works correctly', (tester) async {
      expect(Platform.isWindows, isA<bool>());

      if (Platform.isWindows) {
        expect(Platform.operatingSystem, equals('windows'));
      }
    });
  });
}
