# Windows installer for rbara

A single-file `.exe` installer for the rbara prepress CLI/TUI on Windows x64.

## What ships in the installer

| File | Source | Purpose |
|---|---|---|
| `rbara.exe` | `target/x86_64-pc-windows-msvc/release/rbara.exe` (built with static MSVC CRT) | The binary |
| `pdfium.dll` | [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) `chromium/<NNNN>` release | PDF rendering backend |
| `LICENSE.txt` | `LICENSE-GPL-3.0` | License |

The static-CRT build means **no Visual C++ Redistributable is required** on the
target machine. The only external runtime dependency is `pdfium.dll`, which is
copied next to `rbara.exe` so it is found via the standard DLL search order.

## Pinned versions

- **PDFium**: `chromium/7776` (PDFium 148.0.7776.0) — change with `-PdfiumChromium`
- **rbara version**: read from `rbara/Cargo.toml` at build time

## Prerequisites (one-time)

1. **Inno Setup 6** — <https://jrsoftware.org/isdl.php>
   - Default install path is auto-detected; or put `iscc.exe` on `PATH`.
2. **Rust toolchain** with the `x86_64-pc-windows-msvc` target
   (default for `rustup` on Windows).
3. PowerShell 5.1+ (ships with Windows) and `tar.exe` (ships with Windows 10 1803+).

## Build

```powershell
cd installer\windows
.\build-installer.ps1
```

To pin a different pdfium build:

```powershell
.\build-installer.ps1 -PdfiumChromium 7811
```

To re-download pdfium (e.g., to verify a clean build):

```powershell
.\build-installer.ps1 -ForceDownload
```

Output:

```
installer\windows\dist\rbara-setup-<version>-x64.exe
```

## What the installer does at install time

- Installs to `%LOCALAPPDATA%\Programs\rbara\` (per-user, no admin required).
- Optionally appends the install directory to the user `PATH` (checkbox is on by default).
- Registers an Add/Remove Programs entry.

## What the uninstaller does

- Removes `rbara.exe`, `pdfium.dll`, and `LICENSE.txt`.
- Removes the install directory from the user `PATH` if present.
- Removes the Add/Remove Programs entry.

## SmartScreen note

The installer is unsigned. On first download, Windows SmartScreen will display
"Windows protected your PC" — click **More info → Run anyway**. To eliminate
this prompt, sign the installer with an Authenticode certificate (out of scope
for this build).

## Recommended terminals

`rbara` runs in any Windows terminal. For best rendering of the TUI's box
characters and orange theme color, we recommend:

- **Windows Terminal** (preinstalled on Windows 11; available in the Microsoft Store on Windows 10)
- **WezTerm** — <https://wezterm.org>
- **Ghostty** — <https://ghostty.org>
