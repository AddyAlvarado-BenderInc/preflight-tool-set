#!/usr/bin/env bash
# install.sh — Install rbara into PREFIX (default: ~/.local).
#
# Usage:
#   ./install.sh                 # installs to ~/.local
#   PREFIX=/usr/local ./install.sh   # system-wide (needs sudo)
#
# Layout after install:
#   $PREFIX/bin/rbara            wrapper script (this is what you run)
#   $PREFIX/lib/rbara/rbara-bin  the actual binary
#   $PREFIX/lib/rbara/libpdfium.so

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"

echo "==> Installing rbara to $PREFIX"

mkdir -p "$PREFIX/bin" "$PREFIX/lib/rbara"

install -m 0755 "$SCRIPT_DIR/lib/rbara/rbara-bin"      "$PREFIX/lib/rbara/rbara-bin"
install -m 0755 "$SCRIPT_DIR/lib/rbara/libpdfium.so"   "$PREFIX/lib/rbara/libpdfium.so"
install -m 0755 "$SCRIPT_DIR/bin/rbara"                "$PREFIX/bin/rbara"

echo
echo "[OK] Installed."
echo "     Wrapper:  $PREFIX/bin/rbara"
echo "     Library:  $PREFIX/lib/rbara/"
echo

# PATH hint
case ":$PATH:" in
  *":$PREFIX/bin:"*)
    echo "     '$PREFIX/bin' is already on your PATH."
    ;;
  *)
    echo "     NOTE: '$PREFIX/bin' is not on your PATH."
    echo "     Add this line to your shell rc (~/.bashrc, ~/.zshrc, etc.):"
    echo
    echo "         export PATH=\"$PREFIX/bin:\$PATH\""
    echo
    ;;
esac

echo "     Run:    rbara --help"
echo "     Uninstall: PREFIX=$PREFIX $SCRIPT_DIR/uninstall.sh"
