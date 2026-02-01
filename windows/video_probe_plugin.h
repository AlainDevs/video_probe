#ifndef FLUTTER_PLUGIN_VIDEO_PROBE_PLUGIN_H_
#define FLUTTER_PLUGIN_VIDEO_PROBE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace video_probe {

class VideoProbePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  VideoProbePlugin();

  virtual ~VideoProbePlugin();

  // Disallow copy and assign.
  VideoProbePlugin(const VideoProbePlugin&) = delete;
  VideoProbePlugin& operator=(const VideoProbePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace video_probe

#endif  // FLUTTER_PLUGIN_VIDEO_PROBE_PLUGIN_H_
