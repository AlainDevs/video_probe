cmake_minimum_required(VERSION 3.10)

project(video_probe_library)

add_library(video_probe SHARED
    ../src/video_probe.c
)
