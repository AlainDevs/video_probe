import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:video_probe/video_probe_bindings_generated.dart';
import 'package:video_probe/video_probe_platform_interface.dart';

class VideoProbeFfi extends VideoProbePlatform {
  /// The dynamic library.
  late final DynamicLibrary _dylib;

  /// The generated bindings.
  late final VideoProbeBindings _bindings;

  VideoProbeFfi() {
    _dylib = _loadDynamicLibrary();
    _bindings = VideoProbeBindings(_dylib);
  }

  static void registerWith() {
    VideoProbePlatform.instance = VideoProbeFfi();
  }

  DynamicLibrary _loadDynamicLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libvideo_probe.so');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libvideo_probe_plugin.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('video_probe_plugin.dll');
    } else if (Platform.isMacOS || Platform.isIOS) {
      // Symbols are linked into the app process via CocoaPods
      return DynamicLibrary.process();
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }

  @override
  Future<double> getDuration(String path) async {
    final pathPtr = path.toNativeUtf8();
    try {
      return _bindings.get_duration(pathPtr.cast());
    } finally {
      calloc.free(pathPtr);
    }
  }

  @override
  Future<int> getFrameCount(String path) async {
    final pathPtr = path.toNativeUtf8();
    try {
      return _bindings.get_frame_count(pathPtr.cast());
    } finally {
      calloc.free(pathPtr);
    }
  }

  @override
  Future<Uint8List?> extractFrame(String path, int frameNum) async {
    final pathPtr = path.toNativeUtf8();
    final sizePtr = calloc<Int>();

    try {
      final bufferPtr = _bindings.extract_frame(
        pathPtr.cast(),
        frameNum,
        sizePtr,
      );

      if (bufferPtr == nullptr) {
        return null;
      }

      final size = sizePtr.value;
      if (size <= 0) {
        _bindings.free_frame(bufferPtr);
        return null;
      }

      // Copy data to Dart Uint8List
      final data = bufferPtr.asTypedList(size);
      final result = Uint8List.fromList(
        data,
      ); // Create a copy so we can free the C buffer

      _bindings.free_frame(bufferPtr);
      return result;
    } finally {
      calloc.free(pathPtr);
      calloc.free(sizePtr);
    }
  }
}
