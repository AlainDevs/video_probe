// IO (mobile/desktop) implementation
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Creates a blob URL from bytes (not used on IO platforms)
String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('createBlobUrl is only supported on web');
}

/// Gets a usable video path from bytes by writing to documents directory
Future<String> getVideoPathFromBytes(Uint8List bytes, String filename) async {
  final appDir = await getApplicationDocumentsDirectory();
  final filePath = '${appDir.path}/$filename';
  final file = File(filePath);

  // Ensure parent directory exists
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }

  await file.writeAsBytes(bytes);
  return filePath;
}
