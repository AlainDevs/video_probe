import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';

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

  String _status = 'Idle';
  double _duration = 0.0;
  int _frameCount = 0;
  Uint8List? _frameData;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _probeVideo() async {
    setState(() {
      _status = 'Probing...';
    });

    try {
      // Using a dummy path because our C implementation stub ignores it anyway
      const path = "dummy_video.mp4";

      final duration = await _videoProbePlugin.getDuration(path);
      final frameCount = await _videoProbePlugin.getFrameCount(path);
      // Request frame 0
      final frame = await _videoProbePlugin.extractFrame(path, 0);

      if (!mounted) return;

      setState(() {
        _duration = duration;
        _frameCount = frameCount;
        _frameData = frame;
        _status = 'Success';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Video Probe FFI example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 10),
              Text('Duration: $_duration sec'),
              Text('Frames: $_frameCount'),
              const SizedBox(height: 20),
              if (_frameData != null)
                Column(
                  children: [
                    const Text('Extracted Frame (generated pattern):'),
                    Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: _frameData!.isNotEmpty
                          ? Image.memory(
                              _frameData!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.error),
                            )
                          : const Text('Empty Data'),
                    ),
                    Text('Bytes: ${_frameData!.length}'),
                  ],
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _probeVideo,
                child: const Text('Probe Dummy Video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
