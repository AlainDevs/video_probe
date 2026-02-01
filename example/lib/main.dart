import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:video_probe/video_probe.dart';

// Conditional imports for platform-specific code
import 'platform_helper_stub.dart'
    if (dart.library.io) 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _videoProbePlugin = VideoProbe();

  String _status = 'Select a video file';
  String? _selectedPath;
  double _duration = 0.0;
  int _frameCount = 0;
  Uint8List? _frameData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb, // On web, we need the bytes
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPath = result.files.single.path;
        _status = 'Video selected';
        _duration = 0.0;
        _frameCount = 0;
        _frameData = null;
      });
    } else if (kIsWeb && result != null && result.files.single.bytes != null) {
      // On web, create a blob URL from the bytes
      final bytes = result.files.single.bytes!;
      final blobUrl = createBlobUrl(bytes, 'video/mp4');
      setState(() {
        _selectedPath = blobUrl;
        _status = 'Video selected';
        _duration = 0.0;
        _frameCount = 0;
        _frameData = null;
      });
    }
  }

  /// Uses the bundled test video asset for testing.
  /// On native: copies to file system. On web: creates blob URL.
  Future<void> _useTestVideo() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading test video...';
    });

    try {
      // Load asset bytes
      final byteData = await rootBundle.load('assets/test_video.mp4');
      final bytes = byteData.buffer.asUint8List();

      // Use platform-specific helper to get a usable path/URL
      final videoPath = await getVideoPathFromBytes(bytes, 'test_video.mp4');

      if (!mounted) return;

      setState(() {
        _selectedPath = videoPath;
        _status = 'Test video ready';
        _duration = 0.0;
        _frameCount = 0;
        _frameData = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error loading test video: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _probeVideo() async {
    if (_selectedPath == null) {
      setState(() => _status = 'Please select a video first');
      return;
    }

    setState(() {
      _status = 'Probing...';
      _isLoading = true;
    });

    try {
      final duration = await _videoProbePlugin.getDuration(_selectedPath!);
      final frameCount = await _videoProbePlugin.getFrameCount(_selectedPath!);
      final frame = await _videoProbePlugin.extractFrame(_selectedPath!, 0);

      if (!mounted) return;

      setState(() {
        _duration = duration;
        _frameCount = frameCount;
        _frameData = frame;
        _status = 'Success';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Video Probe FFI Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                'Status: $_status',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedPath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'File: ${_selectedPath!.split('/').last}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Results card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Results',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.timer, size: 32),
                                const SizedBox(height: 4),
                                Text('${_duration.toStringAsFixed(2)} sec'),
                                Text(
                                  'Duration',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Icon(Icons.photo_library, size: 32),
                                const SizedBox(height: 4),
                                Text('$_frameCount'),
                                Text(
                                  'Frames',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Frame preview
                if (_frameData != null && _frameData!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Extracted Frame (first keyframe)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _frameData!,
                              width: 300,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => Column(
                                children: [
                                  const Icon(Icons.error, size: 48),
                                  Text('Error: $e'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(_frameData!.length / 1024).toStringAsFixed(1)} KB',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _useTestVideo,
                      icon: const Icon(Icons.movie),
                      label: const Text('Use Test Video'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _pickVideo,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Pick Video'),
                    ),
                    FilledButton.icon(
                      onPressed: (_selectedPath != null && !_isLoading)
                          ? _probeVideo
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Probe'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
