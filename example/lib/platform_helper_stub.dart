// Stub implementation for unsupported platforms
import 'dart:typed_data';

/// Creates a blob URL from bytes (web only, stub for other platforms)
String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('createBlobUrl is not supported on this platform');
}

/// Gets a usable video path from bytes
Future<String> getVideoPathFromBytes(Uint8List bytes, String filename) async {
  throw UnsupportedError(
    'getVideoPathFromBytes is not supported on this platform',
  );
}
