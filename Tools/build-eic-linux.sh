#!/usr/bin/env bash
# Cross-compile the eic client to static Linux binaries for x86_64 and aarch64
# using the Swift static Linux SDK. Designed to be run on a macOS host with Swift 6.0+.
#
# Outputs:
#   dist/eic-linux-x86_64
#   dist/eic-linux-aarch64
#
# Prerequisites (one-time):
#   swift sdk install https://download.swift.org/swift-6.0.3-release/static-sdk/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
#     --checksum 67f765e0030e661a7450f7e4877cfe008db4f57f177d5a08a6e26fd661cdd0bd
#
# (See https://www.swift.org/install/macos/static-linux/ for current SDK URL and checksum.)

set -euo pipefail

cd "$(dirname "$0")/.."
PKG_PATH="EICClient"
OUT_DIR="dist"
mkdir -p "$OUT_DIR"

SDK_ID="$(swift sdk list 2>/dev/null | grep -E 'swift-.*-RELEASE_static-linux' | head -1 || true)"
if [ -z "${SDK_ID}" ]; then
  echo "error: no Swift static-linux SDK installed. Install it with:" >&2
  echo "  swift sdk install <URL-to-static-linux-artifactbundle> --checksum <sha256>" >&2
  echo "See https://www.swift.org/install/macos/static-linux/ for the current URL/checksum." >&2
  exit 1
fi

echo "Using SDK: $SDK_ID"

build_one() {
  local triple="$1"
  local suffix="$2"
  echo "=== Building $triple -> eic-linux-$suffix ==="
  swift build \
    --package-path "$PKG_PATH" \
    --swift-sdk "$triple" \
    -c release \
    --product eic
  cp "$PKG_PATH/.build/$triple/release/eic" "$OUT_DIR/eic-linux-$suffix"
  echo "-> $OUT_DIR/eic-linux-$suffix ($(stat -f%z "$OUT_DIR/eic-linux-$suffix" 2>/dev/null || stat -c%s "$OUT_DIR/eic-linux-$suffix") bytes)"
}

build_one "x86_64-swift-linux-musl" "x86_64"
build_one "aarch64-swift-linux-musl" "aarch64"

echo
echo "Done. Distribute the binaries in $OUT_DIR/ alongside a short README:"
echo "  1. Copy the binary to /usr/local/bin/eic (or anywhere on PATH) on the Linux host."
echo "  2. Arrange for SSH to forward the Mac's eic port to the remote host, e.g.:"
echo "       ssh -R 50051:127.0.0.1:\$(cat ~/.eic/eic.port) remote-host"
echo "     and export EIC_PORT=50051 in the remote shell (via SendEnv/AcceptEnv or shell rc)."
echo "  3. Run 'eic file.md' on the remote host — the editor opens on your Mac."
