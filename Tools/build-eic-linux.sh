#!/usr/bin/env bash
# Cross-compile the eic client to static Linux binaries for x86_64 and aarch64
# using the Swift Static Linux SDK. Designed to be run on a macOS host.
#
# Outputs:
#   dist/eic-linux-x86_64
#   dist/eic-linux-aarch64
#
# IMPORTANT: the toolchain and the static SDK must be the same Swift release
# (the SDK ships pre-compiled .swiftmodules that the host compiler must match
# bit-for-bit). Apple's Xcode-bundled Swift can NOT be used because Apple
# only ships the toolchain, not a matching static SDK. Use swiftly to install
# an open-source toolchain alongside Xcode's, then point this script at it.
#
# One-time setup (~3GB download):
#   brew install swiftly
#   swiftly init --no-modify-profile --skip-install   # answer Y
#   source ~/.swiftly/env.sh
#   swiftly install 6.2
#   # Find the SDK URL + checksum (URL pattern: swift-X.Y-release/static-sdk/swift-X.Y-RELEASE/swift-X.Y-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz)
#   ~/Library/Developer/Toolchains/swift-6.2-RELEASE.xctoolchain/usr/bin/swift sdk install \
#     https://download.swift.org/swift-6.2-release/static-sdk/swift-6.2-RELEASE/swift-6.2-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz \
#     --checksum d2225840e592389ca517bbf71652f7003dbf45ac35d1e57d98b9250368769378
#
# Versioning:
#   - SWIFT_VERSION below pins both the toolchain and the SDK release.
#   - When bumping, verify the SDK URL exists at:
#       https://download.swift.org/swift-${SWIFT_VERSION}-release/static-sdk/swift-${SWIFT_VERSION}-RELEASE/
#     Note that some patch releases (e.g. 6.2.4) don't ship a matching static SDK;
#     the canonical SDK lives under the bare-minor URL (e.g. swift-6.2-release).

set -euo pipefail

SWIFT_VERSION="${EIC_SWIFT_VERSION:-6.2}"
TOOLCHAIN="$HOME/Library/Developer/Toolchains/swift-${SWIFT_VERSION}-RELEASE.xctoolchain"
SWIFT="$TOOLCHAIN/usr/bin/swift"

if [ ! -x "$SWIFT" ]; then
  echo "error: open-source Swift ${SWIFT_VERSION} toolchain not found at $TOOLCHAIN" >&2
  echo "install it with: swiftly install ${SWIFT_VERSION}" >&2
  echo "(see header of this script for the full one-time setup)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
PKG_PATH="EICClient"
OUT_DIR="dist"
mkdir -p "$OUT_DIR"

SDK_BUNDLE="swift-${SWIFT_VERSION}-RELEASE_static-linux-0.0.1"
if ! "$SWIFT" sdk list 2>/dev/null | grep -q "$SDK_BUNDLE"; then
  echo "error: static SDK $SDK_BUNDLE not installed for this toolchain." >&2
  echo "install with: $SWIFT sdk install <URL> --checksum <sha256>" >&2
  echo "see the header of this script for the URL/checksum pattern." >&2
  exit 1
fi

OBJCOPY="$TOOLCHAIN/usr/bin/llvm-objcopy"
if [ ! -x "$OBJCOPY" ]; then
  echo "warning: llvm-objcopy not found at $OBJCOPY; skipping strip" >&2
  OBJCOPY=""
fi

filesize() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

build_one() {
  local triple="$1"
  local suffix="$2"
  echo "=== Building $triple -> eic-linux-$suffix ==="
  "$SWIFT" build \
    --package-path "$PKG_PATH" \
    --swift-sdk "$triple" \
    -c release \
    --product eic
  local src="$PKG_PATH/.build/$triple/release/eic"
  local dest="$OUT_DIR/eic-linux-$suffix"
  cp "$src" "$dest.unstripped"
  if [ -n "$OBJCOPY" ]; then
    "$OBJCOPY" --strip-all "$src" "$dest"
    echo "-> $dest ($(filesize "$dest") bytes stripped, $(filesize "$dest.unstripped") bytes unstripped)"
  else
    cp "$src" "$dest"
    echo "-> $dest ($(filesize "$dest") bytes, NOT stripped — install llvm-objcopy)"
  fi
}

build_one "x86_64-swift-linux-musl"  "x86_64"
build_one "aarch64-swift-linux-musl" "aarch64"

echo
echo "Built. Each stripped binary is ~75M; .unstripped sidecars (~225M) are kept for debugging."
echo
echo "Run Tools/build-eic-installer.sh next to wrap each stripped binary into a self-extracting .sh installer."
echo
echo "Use over SSH (open editor on Mac from a remote shell):"
echo "  PORT=\$(cat ~/.eic/eic.port)"
echo "  ssh -fN -R 50051:127.0.0.1:\$PORT user@linux-host"
echo "  ssh user@linux-host 'EIC_PORT=50051 EIC_CLIENT_NAME=\$(hostname) ~/eic file.md'"
