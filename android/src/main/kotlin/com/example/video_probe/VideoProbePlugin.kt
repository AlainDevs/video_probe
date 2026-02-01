package com.example.video_probe

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** VideoProbePlugin */
class VideoProbePlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    companion object {
        private var initialized = false

        init {
            // Load the native library so JNI functions are available
            System.loadLibrary("video_probe")
        }

        // Native method declaration - implemented in video_probe_android.c
        @JvmStatic
        private external fun nativeInit()
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "video_probe")
        channel.setMethodCallHandler(this)

        // Initialize the native library with JavaVM reference
        // This is needed because FFI loading doesn't trigger JNI_OnLoad
        if (!initialized) {
            nativeInit()
            initialized = true
        }
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

