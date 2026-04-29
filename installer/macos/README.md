# macOS installer for rbara

A self-contained `.tar.gz` bundle that drops `rbara` (and its bundled
`libpdfium.dylib`) into `~/.local` with one shell command. Built natively
for Apple silicon (`arm64`) or Intel (`x86_64`).

## What ships in the tarball

```
rbara-<version>-macos-<arch>/
├── bin/rbara                       # POSIX wrapper script
├── lib/rbara/rbara-bin             # Release binary (install_name patched)
├── lib/rbara/libpdfium.dylib       # Bundled pdfium (@loader_path id)
├── install.sh                      # Per-user installer
├── uninstall.sh
├── LICENSE.txt
└── README.md
```

The binary's reference to `libpdfium.dylib` has been rewritten to
`@loader_path/libpdfium.dylib` via `install_name_tool`, so the bundled
pdfium is found automatically without needing `DYLD_LIBRARY_PATH` (which
is unreliable on macOS due to SIP).

## Pinned versions

- **PDFium**: `chromium/7776` (PDFium 148.0.7776.0) — change with `--pdfium-chromium`
- **rbara version**: read from `rbara/Cargo.toml` at build time

## Build (maintainer)

Prereqs:
- macOS 12+ (Monterey or later)
- Xcode Command Line Tools — `xcode-select --install`
- Rust stable — <https://rustup.rs>
- For cross-arch: `rustup target add x86_64-apple-darwin` (or `aarch64-apple-darwin`)

```bash
cd installer/macos
./build-installer.sh                  # native arch (uname -m)
./build-installer.sh --arch arm64     # force Apple silicon
./build-installer.sh --arch x86_64    # force Intel
```

Pin a different pdfium build:

```bash
./build-installer.sh --pdfium-chromium 7811
```

Output:

```
installer/macos/dist/rbara-<version>-macos-<arch>.tar.gz
```

## Install (end user)

```bash
tar -xzf rbara-<version>-macos-<arch>.tar.gz
cd rbara-<version>-macos-<arch>
./install.sh                                 # installs to ~/.local
```

System-wide:

```bash
sudo PREFIX=/usr/local ./install.sh
```

## ⚠ Gatekeeper note (unsigned binary)

This bundle is **not codesigned or notarized**. If you downloaded the
tarball through a browser, macOS will quarantine the contents. The
`install.sh` script clears the `com.apple.quarantine` attribute
automatically, but if you copy/move the binary later you may see:

> `"rbara" cannot be opened because the developer cannot be verified.`

To clear it manually:

```bash
xattr -dr com.apple.quarantine ~/.local/lib/rbara ~/.local/bin/rbara
```

Or right-click the binary in Finder → **Open** → **Open Anyway**.

## Uninstall

```bash
cd rbara-<version>-macos-<arch>
./uninstall.sh
# or, if you discarded the extracted folder:
rm -rf ~/.local/lib/rbara ~/.local/bin/rbara
```

## Recommended terminals

`rbara` runs in any modern macOS terminal emulator. For best rendering of
the TUI's box characters and orange theme color, we recommend:

- **WezTerm** — <https://wezterm.org>
- **Ghostty** — <https://ghostty.org>
- **Alacritty** — <https://alacritty.org>
- **iTerm2** — <https://iterm2.com>
- **Terminal.app** — works fine; ensure the profile uses a Nerd Font or
  any monospace font with full Unicode box-drawing coverage.

## Architecture support

Two separate tarballs are produced (one per arch). A universal binary
(`lipo`-merged) is not part of the MVP — Apple silicon adoption is high
enough that the per-arch story is acceptable, and the per-arch tarballs
are smaller.
