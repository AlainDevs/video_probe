// Unit tests for VideoProbeWeb implementation
// These tests run in the Dart test environment (not browser)
// and verify the platform registration and API structure.

import 'package:flutter_test/flutter_test.dart';
import 'package:video_probe/video_probe_platform_interface.dart';

// Note: We can't directly test VideoProbeWeb in unit tests since it requires
// a browser environment. Instead, we test the platform interface and mock.

void main() {
  group('Web Platform Interface', () {
    test('VideoProbePlatform has required methods', () {
      // Verify the platform interface has all required methods
      final platform = VideoProbePlatform.instance;

      // These should not throw - they prove the interface exists
      expect(platform.getPlatformVersion, isA<Function>());
      expect(platform.getDuration, isA<Function>());
      expect(platform.getFrameCount, isA<Function>());
      expect(platform.extractFrame, isA<Function>());
    });
  });
}
