# Flutter Linux Development Environment
# For building and testing Flutter Linux apps from macOS
#
# Build: docker build -t flutter-linux -f docker/Dockerfile .
# Run:   docker run -v $(pwd):/app -w /app flutter-linux flutter build linux

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    git \
    curl \
    unzip \
    xz-utils \
    zip \
    # Flutter Linux dependencies
    clang \
    lld \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    # GStreamer for video_probe
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    # X11 for running tests
    xvfb \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN git clone https://github.com/flutter/flutter.git -b stable ${FLUTTER_HOME} \
    && flutter precache --linux \
    && flutter config --enable-linux-desktop \
    && flutter doctor

WORKDIR /app

# Default command
CMD ["flutter", "doctor", "-v"]
