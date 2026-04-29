# Linux installer for rbara

A self-contained `.tar.gz` bundle that drops `rbara` (and its bundled
`libpdfium.so`) into `~/.local` with one shell command.

## What ships in the tarball

```
rbara-<version>-linux-x64/
├── bin/rbara                   # POSIX wrapper script
├── lib/rbara/rbara-bin         # Release binary
├── lib/rbara/libpdfium.so      # Bundled pdfium
├── install.sh                  # Per-user installer
├── uninstall.sh
├── LICENSE.txt
└── README.md
```

The wrapper sets `LD_LIBRARY_PATH` to the install dir so the binary always
finds the bundled pdfium, regardless of what (if anything) the host system
has installed.

## Pinned versions

- **PDFium**: `chromium/7776` (PDFium 148.0.7776.0) — change with `--pdfium-chromium`
- **rbara version**: read from `rbara/Cargo.toml` at build time

## Build (maintainer)

Prereqs:
- Rust toolchain (stable) with the host `x86_64-unknown-linux-gnu` target
- `curl`, `tar`, `bash` (standard on every distro)

```bash
cd installer/linux
./build-installer.sh
```

Pin a different pdfium build:

```bash
./build-installer.sh --pdfium-chromium 7811
```

Force re-download:

```bash
./build-installer.sh --force-download
```

Output:

```
installer/linux/dist/rbara-<version>-linux-x64.tar.gz
```

## Install (end user)

Per-user (default — installs into `~/.local`):

```bash
tar -xzf rbara-<version>-linux-x64.tar.gz
cd rbara-<version>-linux-x64
./install.sh
```

System-wide (needs `sudo`):

```bash
sudo PREFIX=/usr/local ./install.sh
```

## Uninstall

```bash
cd rbara-<version>-linux-x64
./uninstall.sh
# or, if you discarded the extracted folder:
rm -rf ~/.local/lib/rbara ~/.local/bin/rbara
```

## Recommended terminals

`rbara` runs in any modern terminal emulator. For best rendering of the TUI's
box characters and orange theme color, we recommend:

- **WezTerm** — <https://wezterm.org>
- **Ghostty** — <https://ghostty.org>
- **Alacritty** — <https://alacritty.org>
- **GNOME Terminal**, **Konsole**, **xterm** — all work fine.

## Distro compatibility

The tarball is built against glibc on the build host. It runs unmodified on:
- Ubuntu 22.04+, Debian 12+
- Fedora 38+, RHEL 9+
- Arch Linux, openSUSE Tumbleweed
- Any glibc-based distro from ~2022 onward

For musl-based distros (Alpine), build from source against the
`x86_64-unknown-linux-musl` target — a separate musl bundle is not part of
this MVP.
