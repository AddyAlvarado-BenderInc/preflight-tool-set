#!/usr/bin/env bash
# uninstall.sh — Remove rbara from PREFIX (default: ~/.local).
#
# Usage:
#   ./uninstall.sh
#   PREFIX=/usr/local ./uninstall.sh

set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

echo "==> Uninstalling rbara from $PREFIX"

removed=0

if [[ -f "$PREFIX/bin/rbara" ]]; then
  rm -f "$PREFIX/bin/rbara"
  echo "    removed $PREFIX/bin/rbara"
  removed=1
fi

if [[ -d "$PREFIX/lib/rbara" ]]; then
  rm -rf "$PREFIX/lib/rbara"
  echo "    removed $PREFIX/lib/rbara/"
  removed=1
fi

if [[ "$removed" -eq 0 ]]; then
  echo "    nothing to remove."
else
  echo
  echo "[OK] Uninstalled."
fi
