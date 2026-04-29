#!/usr/bin/env bash
# build-installer.sh — Build the rbara macOS release tarball.
#
# Usage:
#   ./build-installer.sh [--pdfium-chromium 7776] [--arch arm64|x86_64] [--force-download]
#
# Default arch is the host arch (uname -m). Cross-arch builds require the
# corresponding Rust target installed (e.g. `rustup target add x86_64-apple-darwin`).
#
# Output: installer/macos/dist/rbara-<version>-macos-<arch>.tar.gz
#
# Prereqs:
#   - Xcode Command Line Tools (provides clang, install_name_tool, otool)
#       xcode-select --install
#   - Rust toolchain (stable)
#   - curl, tar  (preinstalled on macOS)

set -euo pipefail

PDFIUM_CHROMIUM="7776"
FORCE_DOWNLOAD=0
ARCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdfium-chromium) PDFIUM_CHROMIUM="$2"; shift 2 ;;
    --arch)            ARCH="$2"; shift 2 ;;
    --force-download)  FORCE_DOWNLOAD=1; shift ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# Detect arch
if [[ -z "$ARCH" ]]; then
  case "$(uname -m)" in
    arm64)  ARCH="arm64" ;;
    x86_64) ARCH="x86_64" ;;
    *) echo "ERROR: unsupported host arch $(uname -m)" >&2; exit 1 ;;
  esac
fi

case "$ARCH" in
  arm64)  RUST_TARGET="aarch64-apple-darwin"; PDFIUM_ASSET="pdfium-mac-arm64.tgz" ;;
  x86_64) RUST_TARGET="x86_64-apple-darwin"; PDFIUM_ASSET="pdfium-mac-x64.tgz" ;;
  *) echo "ERROR: --arch must be arm64 or x86_64" >&2; exit 1 ;;
esac

# Sanity-check tools
for tool in cargo curl tar install_name_tool otool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool '$tool' not found in PATH." >&2
    if [[ "$tool" == "install_name_tool" || "$tool" == "otool" ]]; then
      echo "       Install Xcode Command Line Tools:  xcode-select --install" >&2
    fi
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets/$ARCH"
BUILD_DIR="$SCRIPT_DIR/build/$ARCH"
DIST_DIR="$SCRIPT_DIR/dist"
PAYLOAD_DIR="$SCRIPT_DIR/payload/$ARCH"

mkdir -p "$ASSETS_DIR" "$BUILD_DIR" "$DIST_DIR"

# --- 1. Read version from rbara/Cargo.toml -----------------------------------
echo "==> Reading rbara version from Cargo.toml"
APP_VERSION="$(grep -E '^[[:space:]]*version[[:space:]]*=' "$REPO_ROOT/rbara/Cargo.toml" \
              | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
[[ -n "$APP_VERSION" ]] || { echo "ERROR: could not read rbara version" >&2; exit 1; }
echo "    rbara version: $APP_VERSION"
echo "    arch:          $ARCH ($RUST_TARGET)"
echo "    pdfium build:  chromium/$PDFIUM_CHROMIUM"

# --- 2. Build rbara release --------------------------------------------------
echo "==> Building rbara (release, $RUST_TARGET)"
( cd "$REPO_ROOT" && cargo build --release -p rbara --target "$RUST_TARGET" )
BUILT_BIN="$REPO_ROOT/target/$RUST_TARGET/release/rbara"
[[ -f "$BUILT_BIN" ]] || { echo "ERROR: $BUILT_BIN missing" >&2; exit 1; }

# --- 3. Fetch pdfium ---------------------------------------------------------
PDFIUM_DYLIB="$ASSETS_DIR/libpdfium.dylib"
if [[ "$FORCE_DOWNLOAD" -eq 1 || ! -f "$PDFIUM_DYLIB" ]]; then
  echo "==> Downloading pdfium chromium/$PDFIUM_CHROMIUM ($PDFIUM_ASSET)"
  TGZ="$ASSETS_DIR/pdfium.tgz"
  URL="https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${PDFIUM_CHROMIUM}/${PDFIUM_ASSET}"
  echo "    URL: $URL"
  curl -fL --retry 3 --retry-delay 2 -o "$TGZ" "$URL"

  EXTRACT="$BUILD_DIR/pdfium"
  rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
  tar -xzf "$TGZ" -C "$EXTRACT"
  cp -f "$EXTRACT/lib/libpdfium.dylib" "$PDFIUM_DYLIB"
  rm -f "$TGZ"
  echo "    Saved: $PDFIUM_DYLIB"
else
  echo "==> Reusing existing libpdfium.dylib (use --force-download to refresh)"
fi

# --- 4. Stage payload --------------------------------------------------------
echo "==> Staging payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/lib/rbara"

cp -f "$BUILT_BIN"     "$PAYLOAD_DIR/lib/rbara/rbara-bin"
cp -f "$PDFIUM_DYLIB"  "$PAYLOAD_DIR/lib/rbara/libpdfium.dylib"
chmod 0755 "$PAYLOAD_DIR/lib/rbara/rbara-bin" "$PAYLOAD_DIR/lib/rbara/libpdfium.dylib"

# Rewrite the dylib's own install name to be relocatable.
echo "==> Patching install names with install_name_tool"
install_name_tool -id "@loader_path/libpdfium.dylib" \
  "$PAYLOAD_DIR/lib/rbara/libpdfium.dylib"

# Find the binary's current reference to pdfium and rewrite it to @loader_path.
PDFIUM_REF="$(otool -L "$PAYLOAD_DIR/lib/rbara/rbara-bin" \
              | awk '/libpdfium\.dylib/ { print $1; exit }' || true)"
if [[ -n "$PDFIUM_REF" ]]; then
  echo "    rewriting   $PDFIUM_REF"
  echo "         -> @loader_path/libpdfium.dylib"
  install_name_tool -change "$PDFIUM_REF" "@loader_path/libpdfium.dylib" \
    "$PAYLOAD_DIR/lib/rbara/rbara-bin"
else
  echo "    NOTE: rbara-bin has no load-time pdfium reference (runtime dlopen)."
  echo "          Adding @loader_path to its rpath as a fallback."
  install_name_tool -add_rpath "@loader_path" \
    "$PAYLOAD_DIR/lib/rbara/rbara-bin" 2>/dev/null || true
fi

# Wrapper — same shape as Linux for consistency.
cat > "$PAYLOAD_DIR/bin/rbara" <<'WRAPPER'
#!/usr/bin/env bash
# rbara wrapper — locates the install root and execs the real binary.
# The bundled libpdfium.dylib is found via @loader_path (set by install_name_tool).
set -e
SELF="$(/usr/bin/python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$0" 2>/dev/null \
        || readlink -f "$0" 2>/dev/null \
        || echo "$0")"
PREFIX="$(cd "$(dirname "$SELF")/.." && pwd)"
exec "$PREFIX/lib/rbara/rbara-bin" "$@"
WRAPPER
chmod 0755 "$PAYLOAD_DIR/bin/rbara"

cp -f "$REPO_ROOT/LICENSE-GPL-3.0" "$PAYLOAD_DIR/LICENSE.txt"
cp -f "$SCRIPT_DIR/install.sh"    "$PAYLOAD_DIR/install.sh"
cp -f "$SCRIPT_DIR/uninstall.sh"  "$PAYLOAD_DIR/uninstall.sh"
cp -f "$SCRIPT_DIR/README.md"     "$PAYLOAD_DIR/README.md"
chmod 0755 "$PAYLOAD_DIR/install.sh" "$PAYLOAD_DIR/uninstall.sh"

# --- 5. Pack tarball ---------------------------------------------------------
TARBALL_NAME="rbara-${APP_VERSION}-macos-${ARCH}"
TARBALL="$DIST_DIR/${TARBALL_NAME}.tar.gz"
echo "==> Packing $TARBALL"
rm -f "$TARBALL"
STAGE="$BUILD_DIR/$TARBALL_NAME"
rm -rf "$STAGE"
cp -a "$PAYLOAD_DIR" "$STAGE"
tar -C "$BUILD_DIR" -czf "$TARBALL" "$TARBALL_NAME"

SIZE_KB=$(du -k "$TARBALL" | cut -f1)
echo
printf "[OK] Built: %s (%d KB)\n" "$TARBALL" "$SIZE_KB"
echo
echo "NOTE: This bundle is NOT codesigned or notarized."
echo "      First-time users will need to clear the quarantine attribute:"
echo "          xattr -dr com.apple.quarantine rbara-${APP_VERSION}-macos-${ARCH}"
echo "      (the install.sh README explains this)."
