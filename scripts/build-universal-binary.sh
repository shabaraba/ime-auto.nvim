#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWIFT_SOURCE="$PROJECT_ROOT/swift/ime-tool.swift"
OUTPUT_DIR="$PROJECT_ROOT/bin"
OUTPUT_BINARY="$OUTPUT_DIR/swift-ime"
TEMP_DIR="$OUTPUT_DIR"

# Cleanup function
cleanup() {
  rm -f "$TEMP_DIR/swift-ime-x86_64" "$TEMP_DIR/swift-ime-arm64"
}
trap cleanup EXIT

echo "Building Universal Binary for ime-auto.nvim..."

# Check if swiftc is available
if ! command -v swiftc &> /dev/null; then
  echo "❌ Error: swiftc not found!"
  echo "Please install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build for Intel (x86_64)
echo "Building for Intel (x86_64)..."
swiftc -O -target x86_64-apple-macos10.15 \
  -o "$OUTPUT_DIR/swift-ime-x86_64" \
  "$SWIFT_SOURCE"

# Build for Apple Silicon (arm64)
echo "Building for Apple Silicon (arm64)..."
swiftc -O -target arm64-apple-macos11.0 \
  -o "$OUTPUT_DIR/swift-ime-arm64" \
  "$SWIFT_SOURCE"

# Create Universal Binary
echo "Creating Universal Binary..."
lipo -create \
  "$OUTPUT_DIR/swift-ime-x86_64" \
  "$OUTPUT_DIR/swift-ime-arm64" \
  -output "$OUTPUT_BINARY"

# Verify
echo "Verifying Universal Binary..."
lipo -info "$OUTPUT_BINARY"
file "$OUTPUT_BINARY"

echo "✅ Universal Binary created successfully: $OUTPUT_BINARY"
