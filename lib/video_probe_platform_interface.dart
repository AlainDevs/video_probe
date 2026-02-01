import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'video_probe_method_channel.dart';

abstract class VideoProbePlatform extends PlatformInterface {
  /// Constructs a VideoProbePlatform.
  VideoProbePlatform() : super(token: _token);

  static final Object _token = Object();

  static VideoProbePlatform _instance = MethodChannelVideoProbe();

  /// The default instance of [VideoProbePlatform] to use.
  ///
  /// Defaults to [MethodChannelVideoProbe].
  static VideoProbePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VideoProbePlatform] when
  /// they register themselves.
  static set instance(VideoProbePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
