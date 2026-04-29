#!/usr/bin/env bash
# Wrap each stripped Linux eic binary into a self-extracting .sh installer.
# Inputs (produced by Tools/build-eic-linux.sh):
#   dist/eic-linux-x86_64
#   dist/eic-linux-aarch64
# Outputs:
#   dist/eic-installer-linux-x86_64.sh
#   dist/eic-installer-linux-aarch64.sh
#
# Each installer is a bash script with the binary embedded as base64 after a
# `__PAYLOAD__` marker. It installs to /usr/local/bin/eic by default; override
# with --prefix=DIR. Verifies size and SHA-256 before copying.

set -euo pipefail

cd "$(dirname "$0")/.."
DIST="dist"

filesize() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

write_installer() {
  local arch="$1"
  local bin="$DIST/eic-linux-$arch"
  local out="$DIST/eic-installer-linux-$arch.sh"

  if [ ! -f "$bin" ]; then
    echo "missing $bin — run Tools/build-eic-linux.sh first" >&2
    return 1
  fi

  local size sha
  size=$(filesize "$bin")
  sha=$(sha256 "$bin")
  echo "=== $arch: $size bytes, sha256=$sha ==="

  # Read EIC version from Build.xcconfig so installer reports it
  local version
  version=$(awk -F' = ' '/^MARKETING_VERSION/ {print $2; exit}' Build.xcconfig)
  : "${version:=unknown}"

  {
    cat <<HEADER
#!/usr/bin/env bash
# eic ${version} installer for Linux ${arch} (static musl build)
# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) — do not edit by hand.

set -euo pipefail

PREFIX="\${PREFIX:-/usr/local/bin}"
EIC_VERSION="${version}"
EIC_ARCH="${arch}"
EIC_SIZE="${size}"
EIC_SHA256="${sha}"

usage() {
  cat <<USAGE
eic \${EIC_VERSION} installer (Linux \${EIC_ARCH})

Usage: \$0 [--prefix DIR]

Installs the eic binary to \$PREFIX/eic (default: /usr/local/bin/eic).
Uses sudo if the destination is not writable. Override with PREFIX=DIR
or --prefix=DIR for a userland install (e.g. --prefix=\$HOME/.local/bin).
USAGE
}

while [ \$# -gt 0 ]; do
  case "\$1" in
    --prefix) PREFIX="\$2"; shift 2;;
    --prefix=*) PREFIX="\${1#*=}"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "unknown argument: \$1" >&2; usage >&2; exit 2;;
  esac
done

# Architecture sanity check
HOST_ARCH="\$(uname -m)"
case "\$HOST_ARCH" in
  x86_64|amd64) HOST_ARCH=x86_64;;
  aarch64|arm64) HOST_ARCH=aarch64;;
esac
if [ "\$HOST_ARCH" != "\$EIC_ARCH" ]; then
  echo "warning: this installer is for \$EIC_ARCH but the host reports \$HOST_ARCH" >&2
fi

# Decode the embedded payload
TMP=\$(mktemp -t eic.XXXXXX)
trap 'rm -f "\$TMP"' EXIT
sed -n '/^__PAYLOAD__\$/,\$p' "\$0" | tail -n +2 | base64 -d > "\$TMP"

# Verify
ACTUAL_SIZE=\$(wc -c < "\$TMP")
if [ "\$ACTUAL_SIZE" != "\$EIC_SIZE" ]; then
  echo "size mismatch: got \$ACTUAL_SIZE, expected \$EIC_SIZE" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA=\$(sha256sum "\$TMP" | awk '{print \$1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA=\$(shasum -a 256 "\$TMP" | awk '{print \$1}')
else
  ACTUAL_SHA=""
fi
if [ -n "\$ACTUAL_SHA" ] && [ "\$ACTUAL_SHA" != "\$EIC_SHA256" ]; then
  echo "sha256 mismatch: got \$ACTUAL_SHA, expected \$EIC_SHA256" >&2
  exit 1
fi
chmod +x "\$TMP"

# Install
DEST="\$PREFIX/eic"
SUDO=""
if [ ! -d "\$PREFIX" ]; then
  if mkdir -p "\$PREFIX" 2>/dev/null; then :; else SUDO="sudo"; fi
fi
if [ -z "\$SUDO" ] && [ ! -w "\$PREFIX" ]; then
  SUDO="sudo"
fi
if [ -n "\$SUDO" ]; then
  echo "Installing to \$DEST (requires sudo)..."
fi
\$SUDO install -d "\$PREFIX"
\$SUDO install -m 0755 "\$TMP" "\$DEST"

echo "Installed: \$DEST"
"\$DEST" --version 2>/dev/null || true

cat <<'NEXT'

Next steps (run on your Mac first):
  1. Launch MarkEdit InContext and note its port:
       PORT=\$(cat ~/.eic/eic.port)
  2. Open a reverse SSH tunnel from your Mac to this Linux host:
       ssh -fN -R 50051:127.0.0.1:\$PORT user@this-linux-host
  3. Then on this Linux host, edit a file:
       EIC_PORT=50051 EIC_CLIENT_NAME=\$(hostname) eic file.md

NEXT

exit 0

__PAYLOAD__
HEADER
    base64 < "$bin"
  } > "$out"
  chmod +x "$out"

  local out_size
  out_size=$(filesize "$out")
  echo "-> $out ($out_size bytes)"
}

write_installer x86_64
write_installer aarch64

echo
echo "Done. Installers default to /usr/local/bin/eic; override with --prefix=DIR."
echo "Test with:  bash $DIST/eic-installer-linux-<arch>.sh --prefix=/tmp/eic-test"
