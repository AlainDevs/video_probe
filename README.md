# video_probe

A Flutter FFI plugin for extracting video metadata (duration, frame count) and keyframes from video files.

## Features

- 🎥 **Get video duration** — Returns duration in seconds
- 🎞️ **Get frame count** — Returns total number of frames  
- 📸 **Extract keyframes** — Extract frames as JPEG byte data
- 🍎 **Shared Darwin Source** — Single codebase for iOS and macOS

## Supported Platforms

| Platform | Status | Implementation |
|----------|--------|----------------|
| macOS    | ✅ Working | AVFoundation |
| iOS      | ✅ Working | AVFoundation |
| Android  | ✅ Working | MediaMetadataRetriever |
| Linux    | ✅ Working | GStreamer |
| Windows  | ✅ Working | Media Foundation |
| Web      | ❌ | Not supported |

## Installation

```yaml
dependencies:
  video_probe:
    path: ../video_probe
```

## Usage

```dart
import 'package:video_probe/video_probe.dart';

final probe = VideoProbe();

// Get video duration (seconds)
final duration = await probe.getDuration('/path/to/video.mp4');

// Get total frame count
final frames = await probe.getFrameCount('/path/to/video.mp4');

// Extract first keyframe as JPEG
final jpegBytes = await probe.extractFrame('/path/to/video.mp4', 0);
if (jpegBytes != null) {
  // Display with Image.memory(jpegBytes)
}
```

## Project Structure

```
video_probe/
├── darwin/Classes/
│   ├── video_probe_avfoundation.swift  # AVFoundation implementation
│   └── VideoProbePlugin.swift          # Flutter plugin registration
├── src/
│   ├── video_probe.c                   # C stub (Linux/Windows/Android)
│   └── video_probe.h                   # FFI header
├── lib/
│   ├── video_probe.dart                # Public API
│   ├── video_probe_ffi.dart            # FFI bindings
│   └── video_probe_bindings_generated.dart
└── example/
    ├── lib/main.dart                   # Demo app with file picker
    ├── assets/test_video.mp4           # Test asset
    └── integration_test/               # Integration tests
```

## Testing

```bash
# Unit tests
flutter test

# Integration tests (macOS)
cd example && flutter test integration_test -d macos

# Integration tests (iOS)
cd example && flutter test integration_test -d ios
```

## Development

### Regenerate FFI Bindings

```bash
dart run ffigen
```

### Build & Run

```bash
cd example
flutter run -d macos  # or -d ios
```

## Platform Implementation Details

### macOS/iOS (AVFoundation)

Uses Swift with `@_cdecl` to export C-compatible functions:
- `get_duration`: `AVURLAsset.duration`
- `get_frame_count`: `duration × nominalFrameRate`
- `extract_frame`: `AVAssetImageGenerator` → JPEG

### Linux (GStreamer)

Uses GStreamer multimedia framework:
- `get_duration`: `GstDiscoverer`
- `get_frame_count`: `duration × framerate`
- `extract_frame`: GStreamer pipeline → jpegenc → appsink

**Requirements:**
```bash
# Ubuntu/Debian
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav
```

### Android (MediaMetadataRetriever)

Uses platform JNI APIs:
- `get_duration`: `MediaMetadataRetriever.METADATA_KEY_DURATION`
- `get_frame_count`: `duration × framerate` from video track
- `extract_frame`: `getFrameAtTime()` → JPEG

### Windows (Media Foundation)

Uses Windows Media Foundation APIs:
- `get_duration`: `IMFSourceReader` + `MF_PD_DURATION`
- `get_frame_count`: `duration × framerate`
- `extract_frame`: `IMFSourceReader::ReadSample()` → WIC JPEG encoder

## License

See [LICENSE](LICENSE) for details.
