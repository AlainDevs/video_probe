#!/bin/bash
# Build and test Flutter Linux app in Docker
# Usage: ./docker/build-and-test.sh [build|test|shell]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Build Docker image if needed
build_image() {
    echo "Building Docker image..."
    docker build -t flutter-linux -f docker/Dockerfile .
}

# Run Flutter build
run_build() {
    echo "Building Flutter Linux app..."
    docker run --rm \
        -v "$PROJECT_DIR:/app" \
        -w /app/example \
        flutter-linux \
        flutter build linux --debug
}

# Run tests with virtual display
run_tests() {
    echo "Running tests..."
    docker run --rm \
        -v "$PROJECT_DIR:/app" \
        -w /app \
        -e DISPLAY=:99 \
        flutter-linux \
        bash -c "Xvfb :99 -screen 0 1280x1024x24 & sleep 2 && flutter test"
}

# Open shell in container
run_shell() {
    echo "Opening shell in container..."
    docker run -it --rm \
        -v "$PROJECT_DIR:/app" \
        -w /app \
        flutter-linux \
        bash
}

# Main
case "${1:-build}" in
    build)
        build_image
        run_build
        ;;
    test)
        build_image
        run_tests
        ;;
    shell)
        build_image
        run_shell
        ;;
    image)
        build_image
        ;;
    *)
        echo "Usage: $0 [build|test|shell|image]"
        echo "  build - Build the Flutter Linux app"
        echo "  test  - Run unit tests"
        echo "  shell - Open a shell in the container"
        echo "  image - Just build the Docker image"
        exit 1
        ;;
esac

echo "Done!"
