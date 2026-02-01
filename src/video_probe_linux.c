/**
 * Linux-specific video probe implementation using GStreamer.
 * 
 * This file provides video metadata extraction and frame extraction
 * using the GStreamer multimedia framework.
 */

#include <gst/gst.h>
#include <gst/pbutils/pbutils.h>
#include <gst/app/gstappsink.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations from video_probe.h
double get_duration(const char* path);
int get_frame_count(const char* path);
unsigned char* extract_frame(const char* path, int frame_num, int* out_size);
void free_frame(unsigned char* data);

// Helper to create file URI from path
static char* path_to_uri(const char* path) {
    if (path == NULL || strlen(path) == 0) {
        return NULL;
    }
    
    // Check if already a URI
    if (strncmp(path, "file://", 7) == 0) {
        return g_strdup(path);
    }
    
    // Convert to file URI
    GError* error = NULL;
    char* uri = g_filename_to_uri(path, NULL, &error);
    if (error) {
        g_error_free(error);
        return NULL;
    }
    return uri;
}

// Get video duration in seconds using GstDiscoverer
double get_duration(const char* path) {
    if (path == NULL || strlen(path) == 0) {
        return -1.0;
    }

    static gboolean gst_initialized = FALSE;
    if (!gst_initialized) {
        gst_init(NULL, NULL);
        gst_initialized = TRUE;
    }

    char* uri = path_to_uri(path);
    if (uri == NULL) {
        return -1.0;
    }

    GError* error = NULL;
    GstDiscoverer* discoverer = gst_discoverer_new(5 * GST_SECOND, &error);
    if (error) {
        g_error_free(error);
        g_free(uri);
        return -1.0;
    }

    GstDiscovererInfo* info = gst_discoverer_discover_uri(discoverer, uri, &error);
    g_free(uri);

    if (error) {
        g_error_free(error);
        g_object_unref(discoverer);
        return -1.0;
    }

    if (info == NULL) {
        g_object_unref(discoverer);
        return -1.0;
    }

    GstDiscovererResult result = gst_discoverer_info_get_result(info);
    if (result != GST_DISCOVERER_OK) {
        gst_discoverer_info_unref(info);
        g_object_unref(discoverer);
        return -1.0;
    }

    GstClockTime duration_ns = gst_discoverer_info_get_duration(info);
    double duration_sec = (double)duration_ns / GST_SECOND;

    gst_discoverer_info_unref(info);
    g_object_unref(discoverer);

    return duration_sec;
}

// Get frame count by calculating duration * fps
int get_frame_count(const char* path) {
    if (path == NULL || strlen(path) == 0) {
        return -1;
    }

    static gboolean gst_initialized = FALSE;
    if (!gst_initialized) {
        gst_init(NULL, NULL);
        gst_initialized = TRUE;
    }

    char* uri = path_to_uri(path);
    if (uri == NULL) {
        return -1;
    }

    GError* error = NULL;
    GstDiscoverer* discoverer = gst_discoverer_new(5 * GST_SECOND, &error);
    if (error) {
        g_error_free(error);
        g_free(uri);
        return -1;
    }

    GstDiscovererInfo* info = gst_discoverer_discover_uri(discoverer, uri, &error);
    g_free(uri);

    if (error) {
        g_error_free(error);
        g_object_unref(discoverer);
        return -1;
    }

    if (info == NULL) {
        g_object_unref(discoverer);
        return -1;
    }

    GstDiscovererResult result = gst_discoverer_info_get_result(info);
    if (result != GST_DISCOVERER_OK) {
        gst_discoverer_info_unref(info);
        g_object_unref(discoverer);
        return -1;
    }

    // Get duration
    GstClockTime duration_ns = gst_discoverer_info_get_duration(info);
    double duration_sec = (double)duration_ns / GST_SECOND;

    // Get video stream info for framerate
    GList* video_streams = gst_discoverer_info_get_video_streams(info);
    if (video_streams == NULL) {
        gst_discoverer_info_unref(info);
        g_object_unref(discoverer);
        return -1;
    }

    GstDiscovererVideoInfo* video_info = (GstDiscovererVideoInfo*)video_streams->data;
    guint fps_num = gst_discoverer_video_info_get_framerate_num(video_info);
    guint fps_den = gst_discoverer_video_info_get_framerate_denom(video_info);

    double fps = 30.0; // Default fallback
    if (fps_den > 0) {
        fps = (double)fps_num / (double)fps_den;
    }

    gst_discoverer_stream_info_list_free(video_streams);
    gst_discoverer_info_unref(info);
    g_object_unref(discoverer);

    int frame_count = (int)(duration_sec * fps + 0.5); // Round to nearest
    return frame_count > 0 ? frame_count : -1;
}

// Extract a frame at the given frame number and return as JPEG
unsigned char* extract_frame(const char* path, int frame_num, int* out_size) {
    if (path == NULL || strlen(path) == 0 || frame_num < 0 || out_size == NULL) {
        if (out_size) *out_size = 0;
        return NULL;
    }

    *out_size = 0;

    static gboolean gst_initialized = FALSE;
    if (!gst_initialized) {
        gst_init(NULL, NULL);
        gst_initialized = TRUE;
    }

    char* uri = path_to_uri(path);
    if (uri == NULL) {
        return NULL;
    }

    // First, get the framerate to calculate timestamp
    GError* error = NULL;
    GstDiscoverer* discoverer = gst_discoverer_new(5 * GST_SECOND, &error);
    if (error) {
        g_error_free(error);
        g_free(uri);
        return NULL;
    }

    GstDiscovererInfo* info = gst_discoverer_discover_uri(discoverer, uri, &error);
    if (error || info == NULL) {
        if (error) g_error_free(error);
        g_object_unref(discoverer);
        g_free(uri);
        return NULL;
    }

    // Check discoverer result
    GstDiscovererResult result = gst_discoverer_info_get_result(info);
    if (result != GST_DISCOVERER_OK) {
        gst_discoverer_info_unref(info);
        g_object_unref(discoverer);
        g_free(uri);
        return NULL;
    }

    // Get video duration to check if frame is valid
    GstClockTime duration_ns = gst_discoverer_info_get_duration(info);

    GList* video_streams = gst_discoverer_info_get_video_streams(info);
    double fps = 30.0;
    if (video_streams) {
        GstDiscovererVideoInfo* video_info = (GstDiscovererVideoInfo*)video_streams->data;
        guint fps_num = gst_discoverer_video_info_get_framerate_num(video_info);
        guint fps_den = gst_discoverer_video_info_get_framerate_denom(video_info);
        if (fps_den > 0) {
            fps = (double)fps_num / (double)fps_den;
        }
        gst_discoverer_stream_info_list_free(video_streams);
    }
    gst_discoverer_info_unref(info);
    g_object_unref(discoverer);

    // Calculate timestamp for the frame
    GstClockTime timestamp = (GstClockTime)((double)frame_num / fps * GST_SECOND);

    // Check if timestamp is beyond video duration
    if (timestamp > duration_ns) {
        g_free(uri);
        return NULL;
    }

    // Build pipeline: uridecodebin ! videoconvert ! jpegenc ! appsink
    // Use I420 format which jpegenc supports well
    gchar* pipeline_str = g_strdup_printf(
        "uridecodebin uri=\"%s\" ! videoconvert ! video/x-raw,format=I420 ! "
        "jpegenc quality=90 ! appsink name=sink max-buffers=1 drop=true",
        uri
    );
    g_free(uri);

    GstElement* pipeline = gst_parse_launch(pipeline_str, &error);
    g_free(pipeline_str);

    if (error || pipeline == NULL) {
        if (error) g_error_free(error);
        return NULL;
    }

    GstElement* sink = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
    if (sink == NULL) {
        gst_object_unref(pipeline);
        return NULL;
    }

    // Start pipeline and seek to timestamp
    gst_element_set_state(pipeline, GST_STATE_PAUSED);
    
    // Wait for pipeline to preroll
    GstStateChangeReturn ret = gst_element_get_state(pipeline, NULL, NULL, 10 * GST_SECOND);
    if (ret == GST_STATE_CHANGE_FAILURE) {
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(sink);
        gst_object_unref(pipeline);
        return NULL;
    }

    // Seek to the desired timestamp
    gboolean seek_result = gst_element_seek_simple(
        pipeline,
        GST_FORMAT_TIME,
        GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT,
        timestamp
    );

    if (!seek_result) {
        // Seek failed, try without KEY_UNIT flag
        seek_result = gst_element_seek_simple(
            pipeline,
            GST_FORMAT_TIME,
            GST_SEEK_FLAG_FLUSH,
            timestamp
        );
    }

    // Wait for seek to complete
    gst_element_get_state(pipeline, NULL, NULL, 5 * GST_SECOND);

    // Start playing to decode the frame
    gst_element_set_state(pipeline, GST_STATE_PLAYING);

    // Pull the sample with timeout
    GstSample* sample = gst_app_sink_try_pull_sample(GST_APP_SINK(sink), 5 * GST_SECOND);
    
    unsigned char* frame_result = NULL;
    
    if (sample) {
        GstBuffer* buffer = gst_sample_get_buffer(sample);
        if (buffer) {
            GstMapInfo map;
            if (gst_buffer_map(buffer, &map, GST_MAP_READ)) {
                frame_result = (unsigned char*)malloc(map.size);
                if (frame_result) {
                    memcpy(frame_result, map.data, map.size);
                    *out_size = (int)map.size;
                }
                gst_buffer_unmap(buffer, &map);
            }
        }
        gst_sample_unref(sample);
    }

    // Cleanup
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(sink);
    gst_object_unref(pipeline);

    return frame_result;
}

void free_frame(unsigned char* data) {
    if (data) {
        free(data);
    }
}
