#!/bin/bash

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <port-name> [port-name...]"
    echo "Example: $0 brpc arrow"
    exit 1
fi

if [ -n "$VCPKG_ROOT" ]; then
    echo "Using VCPKG_ROOT from environment: $VCPKG_ROOT"
else
    VCPKG_ROOT=$(dirname $(dirname $(which vcpkg)))
    echo "Detected VCPKG_ROOT: $VCPKG_ROOT"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OVERLAY_DIR="$PROJECT_ROOT/overlay"

echo "Project root: $PROJECT_ROOT"
echo "Overlay directory: $OVERLAY_DIR"
echo ""

if [ ! -d "$VCPKG_ROOT/ports" ]; then
    echo "Error: vcpkg ports directory not found at $VCPKG_ROOT/ports"
    exit 1
fi

mkdir -p "$OVERLAY_DIR"

for PORT_NAME in "$@"; do
    SOURCE_PORT="$VCPKG_ROOT/ports/$PORT_NAME"
    TARGET_PORT="$OVERLAY_DIR/$PORT_NAME"
    
    echo "Processing port: $PORT_NAME"
    echo "  Source: $SOURCE_PORT"
    echo "  Target: $TARGET_PORT"
    
    if [ ! -d "$SOURCE_PORT" ]; then
        echo "  ✗ Error: Port not found at source"
        echo ""
        continue
    fi
    
    if [ -d "$TARGET_PORT" ]; then
        echo "  ⚠ Warning: Port already exists in overlay, removing..."
        rm -rf "$TARGET_PORT"
    fi
    
    cp -r "$SOURCE_PORT" "$TARGET_PORT"
    echo "  ✓ Successfully copied"
    echo ""
done

echo "Done! You can now customize the port(s) in the overlay directory."