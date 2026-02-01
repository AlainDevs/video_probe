// Web implementation
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Creates a blob URL from bytes
String createBlobUrl(Uint8List bytes, String mimeType) {
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

/// Gets a usable video path from bytes by creating a blob URL
Future<String> getVideoPathFromBytes(Uint8List bytes, String filename) async {
  return createBlobUrl(bytes, 'video/mp4');
}
