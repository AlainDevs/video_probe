import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'video_probe_platform_interface.dart';

/// JS interop extension type for video metadata
extension type JSVideoMetadata._(JSObject _) implements JSObject {
  external double get duration;
  external int get frameCount;
  external double get frameRate;
}

/// JS interop for videoProbeHelper (injected dynamically)
@JS('videoProbeHelper.getVideoMetadata')
external JSPromise<JSVideoMetadata> _jsGetVideoMetadata(JSArrayBuffer buffer);

@JS('videoProbeHelper.extractVideoFrame')
external JSPromise<JSUint8Array> _jsExtractVideoFrame(
  JSString url,
  JSNumber timeSeconds,
);

@JS('videoProbeHelper.getVideoDuration')
external JSPromise<JSNumber> _jsGetVideoDuration(JSString url);

/// Check if videoProbeHelper is available
@JS('videoProbeHelper')
external JSObject? get _videoProbeHelper;

/// The JavaScript helper code that will be injected
const String _jsHelperCode = r'''
(function() {
  if (window.videoProbeHelper) return; // Already loaded

  let mp4boxLoaded = false;
  let mp4boxLoading = null;

  async function ensureMp4BoxLoaded() {
    if (mp4boxLoaded) return;
    if (mp4boxLoading) return mp4boxLoading;
    
    mp4boxLoading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/mp4box@0.5.2/dist/mp4box.all.min.js';
      script.onload = () => { mp4boxLoaded = true; resolve(); };
      script.onerror = () => reject(new Error('Failed to load mp4box.js'));
      document.head.appendChild(script);
    });
    return mp4boxLoading;
  }

  async function getVideoMetadata(buffer) {
    await ensureMp4BoxLoaded();
    return new Promise((resolve, reject) => {
      const mp4boxfile = MP4Box.createFile();
      mp4boxfile.onReady = function(info) {
        let frameCount = 0, frameRate = 30, duration = info.duration / info.timescale;
        for (const track of info.tracks) {
          if (track.type === 'video') {
            frameCount = track.nb_samples;
            if (track.movie_duration && track.movie_timescale) {
              const trackDuration = track.movie_duration / track.movie_timescale;
              if (trackDuration > 0) frameRate = frameCount / trackDuration;
            }
            break;
          }
        }
        resolve({ duration, frameCount, frameRate });
      };
      mp4boxfile.onError = reject;
      buffer.fileStart = 0;
      mp4boxfile.appendBuffer(buffer);
      mp4boxfile.flush();
    });
  }

  async function extractVideoFrame(url, timeSeconds) {
    return new Promise((resolve, reject) => {
      const video = document.createElement('video');
      video.crossOrigin = 'anonymous';
      video.muted = true;
      video.preload = 'auto';
      video.onloadedmetadata = () => {
        video.currentTime = Math.min(Math.max(0, timeSeconds), video.duration - 0.001);
      };
      video.onseeked = () => {
        try {
          const canvas = document.createElement('canvas');
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
          canvas.toBlob(blob => {
            if (blob) blob.arrayBuffer().then(buf => resolve(new Uint8Array(buf))).catch(reject);
            else reject(new Error('Failed to create blob'));
          }, 'image/jpeg', 0.9);
        } catch (e) { reject(e); }
      };
      video.onerror = () => reject(new Error('Failed to load video'));
      video.src = url;
      video.load();
    });
  }

  async function getVideoDuration(url) {
    return new Promise((resolve, reject) => {
      const video = document.createElement('video');
      video.preload = 'metadata';
      video.onloadedmetadata = () => resolve(video.duration);
      video.onerror = () => reject(new Error('Failed to load video metadata'));
      video.src = url;
    });
  }

  window.videoProbeHelper = { getVideoMetadata, extractVideoFrame, getVideoDuration };
})();
''';

/// A web implementation of the VideoProbePlatform of the VideoProbe plugin.
/// This implementation is completely self-contained - no external JS files needed.
class VideoProbeWeb extends VideoProbePlatform {
  /// Cached metadata per URL to avoid re-parsing
  final Map<String, _VideoMetadata> _metadataCache = {};

  /// Whether the JS helper has been injected
  static bool _helperInjected = false;

  /// Constructs a VideoProbeWeb
  VideoProbeWeb();

  static void registerWith(Registrar registrar) {
    VideoProbePlatform.instance = VideoProbeWeb();
  }

  /// Injects the JS helper code if not already present
  void _ensureHelperInjected() {
    if (_helperInjected || _videoProbeHelper != null) {
      _helperInjected = true;
      return;
    }

    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.type = 'text/javascript';
    script.text = _jsHelperCode;
    web.document.head?.appendChild(script);
    _helperInjected = true;
  }

  @override
  Future<String?> getPlatformVersion() async {
    return 'Web';
  }

  @override
  Future<double> getDuration(String path) async {
    _ensureHelperInjected();
    try {
      // Try from cache first
      if (_metadataCache.containsKey(path)) {
        return _metadataCache[path]!.duration;
      }

      // Use HTML5 video element for duration
      final duration = await _jsGetVideoDuration(path.toJS).toDart;
      return duration.toDartDouble;
    } catch (e) {
      return -1.0;
    }
  }

  @override
  Future<int> getFrameCount(String path) async {
    _ensureHelperInjected();
    try {
      // Check cache first
      if (_metadataCache.containsKey(path)) {
        return _metadataCache[path]!.frameCount;
      }

      // Fetch video bytes for mp4box parsing
      final response = await web.window.fetch(path.toJS).toDart;
      final arrayBuffer = await response.arrayBuffer().toDart;

      // Get metadata via mp4box.js
      final metadata = await _jsGetVideoMetadata(arrayBuffer).toDart;

      final duration = metadata.duration;
      final frameCount = metadata.frameCount;
      final frameRate = metadata.frameRate;

      // Cache the result
      _metadataCache[path] = _VideoMetadata(
        duration: duration,
        frameCount: frameCount,
        frameRate: frameRate,
      );

      return frameCount;
    } catch (e) {
      return -1;
    }
  }

  @override
  Future<Uint8List?> extractFrame(String path, int frameNum) async {
    _ensureHelperInjected();
    try {
      // Get frame rate from cache or metadata
      double frameRate = 30.0;
      if (_metadataCache.containsKey(path)) {
        frameRate = _metadataCache[path]!.frameRate;
      } else {
        // Fetch metadata first
        await getFrameCount(path);
        if (_metadataCache.containsKey(path)) {
          frameRate = _metadataCache[path]!.frameRate;
        }
      }

      // Calculate time in seconds
      final timeSeconds = frameNum / frameRate;

      // Extract frame via canvas
      final result = await _jsExtractVideoFrame(
        path.toJS,
        timeSeconds.toJS,
      ).toDart;
      return result.toDart;
    } catch (e) {
      return null;
    }
  }
}

/// Cached video metadata
class _VideoMetadata {
  final double duration;
  final int frameCount;
  final double frameRate;

  _VideoMetadata({
    required this.duration,
    required this.frameCount,
    required this.frameRate,
  });
}
