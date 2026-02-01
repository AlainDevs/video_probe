import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:video_probe/video_probe.dart';

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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPath = result.files.single.path;
        _status = 'Video selected';
        _duration = 0.0;
        _frameCount = 0;
        _frameData = null;
      });
    }
  }

  Future<void> _probeVideo() async {
    if (_selectedPath == null) {
      setState(() => _status = 'Please select a video first');
      return;
    }

    setState(() => _status = 'Probing...');

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Video Probe FFI Example')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Status: $_status'),
                const SizedBox(height: 10),
                if (_selectedPath != null)
                  Text(
                    'File: ${_selectedPath!.split('/').last}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 10),
                Text('Duration: ${_duration.toStringAsFixed(2)} sec'),
                Text('Frames: $_frameCount'),
                const SizedBox(height: 20),
                if (_frameData != null && _frameData!.isNotEmpty)
                  Column(
                    children: [
                      const Text('Extracted Frame (first keyframe):'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _frameData!,
                          width: 300,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(Icons.error),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_frameData!.length / 1024).toStringAsFixed(1)} KB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Video'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _selectedPath != null ? _probeVideo : null,
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
