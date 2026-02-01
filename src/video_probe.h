#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// A dummy function to test FFI integration
EXPORT intptr_t sum(intptr_t a, intptr_t b);

// Returns the duration of the video in seconds.
// Returns -1.0 on error.
EXPORT double get_duration(char* path);

// Returns the total number of frames in the video.
// Returns -1 on error.
EXPORT int get_frame_count(char* path);

// Extracts a specific frame as a JPG/PNG buffer.
// Returns a pointer to the buffer. The caller is responsible for freeing it using free_frame().
// Sets *outSize to the size of the buffer.
// Returns NULL on error.
EXPORT uint8_t* extract_frame(char* path, int frameNum, int* outSize);

// Frees the buffer returned by extract_frame.
EXPORT void free_frame(uint8_t* buffer);

#ifdef __cplusplus
}
#endif
