//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <video_probe/video_probe_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) video_probe_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VideoProbePlugin");
  video_probe_plugin_register_with_registrar(video_probe_registrar);
}
