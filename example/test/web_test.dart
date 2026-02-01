// Web tests for video_probe plugin.
// These tests run in Chrome and test the actual web implementation.
//
// Run: cd example && flutter test test/web_test.dart -d chrome
//
// Note: These tests use blob URLs created from bundled assets.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:video_probe/video_probe.dart';

/// Creates a blob URL from asset bytes for web testing.
Future<String> createBlobUrlFromAsset(String assetName) async {
  final byteData = await rootBundle.load('assets/$assetName');
  final bytes = byteData.buffer.asUint8List();

  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'video/mp4'));
  return web.URL.createObjectURL(blob);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoProbe plugin;

  setUp(() {
    plugin = VideoProbe();
  });

  group('Web Platform Tests', () {
    test('getPlatformVersion returns Web', () async {
      final version = await plugin.getPlatformVersion();
      expect(version, isNotNull);
      expect(version, equals('Web'));
    });
  });

  group('Web Error Handling', () {
    test('getDuration returns -1 for invalid URL', () async {
      final duration = await plugin.getDuration('invalid://url');
      expect(duration, equals(-1.0));
    });

    test('getFrameCount returns -1 for invalid URL', () async {
      final count = await plugin.getFrameCount('invalid://url');
      expect(count, equals(-1));
    });

    test('extractFrame returns null for invalid URL', () async {
      final frame = await plugin.extractFrame('invalid://url', 0);
      expect(frame, isNull);
    });
  });

  group('Web Video Processing Tests', () {
    late String testVideoUrl;
    late bool testVideoReady;

    setUpAll(() async {
      try {
        testVideoUrl = await createBlobUrlFromAsset('test_video.mp4');
        testVideoReady = testVideoUrl.isNotEmpty;
      } catch (e) {
        testVideoReady = false;
        testVideoUrl = '';
      }
    });

    test('getDuration returns positive value', () async {
      expect(
        testVideoReady,
        isTrue,
        reason: 'Test video asset not found. Add assets/test_video.mp4',
      );

      final duration = await plugin.getDuration(testVideoUrl);
      expect(duration, greaterThan(0));
      expect(duration, lessThan(60)); // Test video should be short
    });

    test('getFrameCount returns positive value (via mp4box.js)', () async {
      expect(testVideoReady, isTrue);

      final count = await plugin.getFrameCount(testVideoUrl);
      expect(count, greaterThan(0));
    });

    test('extractFrame returns valid JPEG data', () async {
      expect(testVideoReady, isTrue);

      final frame = await plugin.extractFrame(testVideoUrl, 0);
      expect(frame, isNotNull);
      expect(frame!.length, greaterThan(100));

      // Verify JPEG magic bytes (FFD8FF)
      expect(frame[0], 0xFF, reason: 'Not a valid JPEG: missing FFD8 header');
      expect(frame[1], 0xD8);
      expect(frame[2], 0xFF);
    });

    test('duration and frame count are consistent', () async {
      expect(testVideoReady, isTrue);

      final duration = await plugin.getDuration(testVideoUrl);
      final frameCount = await plugin.getFrameCount(testVideoUrl);

      // Both should be valid
      expect(duration, greaterThan(0));
      expect(frameCount, greaterThan(0));

      // Calculate implied frame rate (should be 15-60 fps for typical video)
      final impliedFps = frameCount / duration;
      expect(impliedFps, greaterThan(10));
      expect(impliedFps, lessThan(120));
    });

    test('repeated calls use cached metadata', () async {
      expect(testVideoReady, isTrue);

      // First call - fetches and parses
      final count1 = await plugin.getFrameCount(testVideoUrl);

      // Second call - should use cache
      final count2 = await plugin.getFrameCount(testVideoUrl);

      expect(count1, equals(count2));
    });
  });
}
