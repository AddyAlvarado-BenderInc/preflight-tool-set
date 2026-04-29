#!/usr/bin/env bash
# build-installer.sh — Build the rbara Linux x86_64 release tarball.
#
# Usage:  ./build-installer.sh [--pdfium-chromium 7776] [--force-download]
#
# Output: installer/linux/dist/rbara-<version>-linux-x64.tar.gz
#
# Prereqs (build host):
#   - cargo (stable, with the host x86_64-unknown-linux-gnu target)
#   - curl, tar (standard on every distro)
#
# The tarball is fully self-contained:
#   bin/rbara           POSIX wrapper script (sets LD_LIBRARY_PATH then execs rbara-bin)
#   lib/rbara/rbara-bin Release binary
#   lib/rbara/libpdfium.so  Bundled pdfium
#   install.sh          Per-user installer (~/.local by default; override with PREFIX=)
#   uninstall.sh        Reverses install.sh
#   LICENSE.txt         GPL-3.0
#   README.md           Quick install/uninstall instructions

set -euo pipefail

PDFIUM_CHROMIUM="7776"
FORCE_DOWNLOAD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdfium-chromium) PDFIUM_CHROMIUM="$2"; shift 2 ;;
    --force-download)  FORCE_DOWNLOAD=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
PAYLOAD_DIR="$SCRIPT_DIR/payload"

mkdir -p "$ASSETS_DIR" "$BUILD_DIR" "$DIST_DIR"

# --- 1. Read version from rbara/Cargo.toml -----------------------------------
echo "==> Reading rbara version from Cargo.toml"
APP_VERSION="$(grep -E '^\s*version\s*=' "$REPO_ROOT/rbara/Cargo.toml" \
              | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [[ -z "$APP_VERSION" ]]; then
  echo "ERROR: could not read rbara version" >&2; exit 1
fi
echo "    rbara version: $APP_VERSION"
echo "    pdfium chromium build: $PDFIUM_CHROMIUM"

# --- 2. Build rbara release --------------------------------------------------
echo "==> Building rbara (release)"
( cd "$REPO_ROOT" && cargo build --release -p rbara )
BUILT_BIN="$REPO_ROOT/target/release/rbara"
[[ -f "$BUILT_BIN" ]] || { echo "ERROR: $BUILT_BIN missing" >&2; exit 1; }

# --- 3. Fetch pdfium ---------------------------------------------------------
PDFIUM_SO="$ASSETS_DIR/libpdfium.so"
if [[ "$FORCE_DOWNLOAD" -eq 1 || ! -f "$PDFIUM_SO" ]]; then
  echo "==> Downloading pdfium chromium/$PDFIUM_CHROMIUM (linux-x64)"
  TGZ="$ASSETS_DIR/pdfium.tgz"
  URL="https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${PDFIUM_CHROMIUM}/pdfium-linux-x64.tgz"
  echo "    URL: $URL"
  curl -fL --retry 3 --retry-delay 2 -o "$TGZ" "$URL"

  EXTRACT="$BUILD_DIR/pdfium"
  rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
  tar -xzf "$TGZ" -C "$EXTRACT"
  cp -f "$EXTRACT/lib/libpdfium.so" "$PDFIUM_SO"
  rm -f "$TGZ"
  echo "    Saved: $PDFIUM_SO"
else
  echo "==> Reusing existing libpdfium.so (use --force-download to refresh)"
fi

# --- 4. Stage payload --------------------------------------------------------
echo "==> Staging payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR/bin" "$PAYLOAD_DIR/lib/rbara"
cp -f "$BUILT_BIN"   "$PAYLOAD_DIR/lib/rbara/rbara-bin"
cp -f "$PDFIUM_SO"   "$PAYLOAD_DIR/lib/rbara/libpdfium.so"
chmod 0755 "$PAYLOAD_DIR/lib/rbara/rbara-bin" "$PAYLOAD_DIR/lib/rbara/libpdfium.so"

cat > "$PAYLOAD_DIR/bin/rbara" <<'WRAPPER'
#!/usr/bin/env bash
# rbara wrapper — locates the install root and invokes the real binary
# with LD_LIBRARY_PATH pointing at the bundled pdfium.
set -e
SELF="$(readlink -f "$0")"
PREFIX="$(cd "$(dirname "$SELF")/.." && pwd)"
LIB_DIR="$PREFIX/lib/rbara"
exec env LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
     "$LIB_DIR/rbara-bin" "$@"
WRAPPER
chmod 0755 "$PAYLOAD_DIR/bin/rbara"

cp -f "$REPO_ROOT/LICENSE-GPL-3.0" "$PAYLOAD_DIR/LICENSE.txt"
cp -f "$SCRIPT_DIR/install.sh"   "$PAYLOAD_DIR/install.sh"
cp -f "$SCRIPT_DIR/uninstall.sh" "$PAYLOAD_DIR/uninstall.sh"
cp -f "$SCRIPT_DIR/README.md"    "$PAYLOAD_DIR/README.md"
chmod 0755 "$PAYLOAD_DIR/install.sh" "$PAYLOAD_DIR/uninstall.sh"

# --- 5. Pack tarball ---------------------------------------------------------
TARBALL_NAME="rbara-${APP_VERSION}-linux-x64"
TARBALL="$DIST_DIR/${TARBALL_NAME}.tar.gz"
echo "==> Packing $TARBALL"
rm -f "$TARBALL"
# Rename the staging dir so the archive extracts into a versioned folder.
STAGE="$BUILD_DIR/$TARBALL_NAME"
rm -rf "$STAGE"
cp -a "$PAYLOAD_DIR" "$STAGE"
tar -C "$BUILD_DIR" -czf "$TARBALL" "$TARBALL_NAME"

SIZE_KB=$(du -k "$TARBALL" | cut -f1)
echo
printf "[OK] Built: %s (%.2f MB)\n" "$TARBALL" "$(echo "scale=2; $SIZE_KB/1024" | bc 2>/dev/null || echo "$SIZE_KB KB")"
