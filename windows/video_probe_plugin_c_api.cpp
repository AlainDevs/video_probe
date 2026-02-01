#include "include/video_probe/video_probe_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "video_probe_plugin.h"

void VideoProbePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  video_probe::VideoProbePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
