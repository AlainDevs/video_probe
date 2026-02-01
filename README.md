# video_probe

A Flutter FFI plugin for extracting video metadata (duration, frame count) and frames from video files.

## Features

- 🎥 **Get video duration** — Returns duration in seconds
- 🎞️ **Get frame count** — Returns total number of frames
- 📸 **Extract frames** — Extract individual frames as byte data
- 🍎 **Shared Darwin Source** — Single codebase for iOS and macOS

## Supported Platforms

| Platform | Status |
|----------|--------|
| macOS    | ✅     |
| iOS      | ✅     |
| Linux    | ✅     |
| Windows  | ✅     |
| Android  | ✅     |
| Web      | ❌     |

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  video_probe:
    path: ../video_probe  # or publish to pub.dev
```

## Usage

```dart
import 'package:video_probe/video_probe.dart';

// Get video duration
final duration = await VideoProbe.getDuration('/path/to/video.mp4');
print('Duration: $duration seconds');

// Get frame count
final frames = await VideoProbe.getFrameCount('/path/to/video.mp4');
print('Total frames: $frames');

// Extract a frame
final frameData = await VideoProbe.extractFrame('/path/to/video.mp4', 100);
if (frameData != null) {
  // Use the frame data (Uint8List)
}
```

## Project Structure

This plugin uses Flutter's **Shared Darwin Source** feature for iOS/macOS:

```
video_probe/
├── src/                          # Native C source (single source of truth)
│   ├── video_probe.c
│   └── video_probe.h
├── darwin/                       # Shared iOS + macOS code
│   ├── Classes/
│   │   ├── VideoProbePlugin.swift
│   │   ├── video_probe.c → ../../src/video_probe.c  (symlink)
│   │   └── video_probe.h → ../../src/video_probe.h  (symlink)
│   └── video_probe.podspec
├── linux/                        # Linux CMake build
├── windows/                      # Windows CMake build
├── android/                      # Android CMake build
└── lib/                          # Dart API
    ├── video_probe.dart
    ├── video_probe_ffi.dart
    └── video_probe_bindings_generated.dart
```

### Why Shared Darwin Source?

- **No code duplication** — iOS and macOS share the same Swift plugin and C sources
- **Single podspec** — One `darwin/video_probe.podspec` handles both platforms
- **Symlinks to src/** — The C code lives in `src/` and is symlinked into `darwin/Classes/`
- **Git preserves symlinks** — Cloning the repo preserves the symlinks automatically

## Development

### Regenerating FFI Bindings

If you modify `src/video_probe.h`, regenerate the Dart bindings:

```bash
dart run ffigen
```

### Building for macOS/iOS

```bash
cd example
flutter run -d macos  # or -d ios
```

### Building for Linux/Windows

```bash
cd example
flutter run -d linux  # or -d windows
```

## TODO

The current implementation returns dummy values. To add real video processing:

1. **macOS/iOS**: Link against AVFoundation
2. **Linux**: Link against FFmpeg/GStreamer
3. **Windows**: Link against Media Foundation
4. **Android**: Use MediaMetadataRetriever via JNI

## License

See [LICENSE](LICENSE) for details.
