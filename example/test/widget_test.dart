// Basic Flutter widget test for the video_probe example app.
//
// To run: flutter test test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:video_probe_example/main.dart';

void main() {
  testWidgets('Example app builds without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Let the app settle
    await tester.pumpAndSettle();

    // Verify the app bar title is present
    expect(find.text('Video Probe FFI Example'), findsOneWidget);
  });
}
