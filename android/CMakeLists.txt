cmake_minimum_required(VERSION 3.10)

project(video_probe_library)

# For Android NDK, JNI headers are already available via the sysroot
# No need for find_package(JNI) which doesn't work with Android toolchain

add_library(video_probe SHARED
    ../src/video_probe_android.c
)

# Include project headers
target_include_directories(video_probe PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

# Link Android log library for __android_log_print
target_link_libraries(video_probe
    log
)
