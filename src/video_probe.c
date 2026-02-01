#include "video_probe.h"
#include <string.h>

// A very short-lived memory allocator for demonstration
// In production, use your platform's video decoding logic here.

EXPORT intptr_t sum(intptr_t a, intptr_t b) {
    return a + b;
}

EXPORT double get_duration(char* path) {
    // TODO: Implement actual video duration extraction
    // This requires linking against a library like FFmpeg, or using platform specific APIs (AVFoundation, MediaMetadataRetriever, etc.)
    // For now, return a dummy value.
    if (path == NULL) return -1.0;
    return 120.5; // Dummy 120.5 seconds
}

EXPORT int get_frame_count(char* path) {
    // TODO: Implement actual frame count
    if (path == NULL) return -1;
    return 3000; // Dummy 3000 frames
}

EXPORT uint8_t* extract_frame(char* path, int frameNum, int* outSize) {
    // TODO: Implement actual frame extraction
    // For now, return a dummy buffer representing a "red pixel" or similar, or just random bytes.
    if (path == NULL) return NULL;
    
    // Create a dummy 100-byte buffer
    int size = 100;
    uint8_t* buffer = (uint8_t*)malloc(size);
    if (buffer == NULL) return NULL;

    for (int i = 0; i < size; i++) {
        buffer[i] = (uint8_t)(i % 256);
    }

    if (outSize != NULL) {
        *outSize = size;
    }
    return buffer;
}

EXPORT void free_frame(uint8_t* buffer) {
    if (buffer != NULL) {
        free(buffer);
    }
}
