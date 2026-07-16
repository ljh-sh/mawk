# scripts/package.ps1
# Stage the built mawk into a self-contained Windows .zip archive.
#
# Used by .github/workflows/build-and-test.yml + release.yml on:
#   - windows-latest    (x86_64-windows)
#   - windows-11-arm    (aarch64-windows)
#
# mawk has NO external library dependencies (only libc + libm via
# ucrt/mingw). No DLLs to bundle. No RPATH. Just mawk.exe + man page.
#
# Layout inside dist/mawk-$TARGET/:
#   bin/mawk.exe                  ← the CLI binary
#   man/man1/mawk.1              ← the man page
#   LICENSE NOTICE README.md
#
# Output: dist/mawk-$TARGET.zip + .sha256 (basename-keyed).
$ErrorActionPreference = 'Stop'

$BUILD_DIR = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { "$PSScriptRoot\..\build" }
$MAWK_SRC  = if ($env:MAWK_SRC)  { $env:MAWK_SRC }  else { "$PSScriptRoot\..\upstream" }
$DIST      = if ($env:DIST)      { $env:DIST }      else { "$PSScriptRoot\..\dist" }
$TARGET    = if ($env:TARGET)    { $env:TARGET }    else { throw "set TARGET, e.g. x86_64-windows" }

$BIN = "$BUILD_DIR\mawk.exe"
if (-not (Test-Path $BIN)) { throw "error: $BIN not built (BUILD_DIR=$BUILD_DIR)" }

$MAN_SRC = "$MAWK_SRC\man\mawk.1"
if (-not (Test-Path $MAN_SRC)) { throw "error: $MAN_SRC not found" }

$STAGE = "$DIST\mawk-$TARGET"
if (Test-Path $STAGE) { Remove-Item -Recurse -Force $STAGE }
$binDir  = "$STAGE\bin"
$manDir  = "$STAGE\man\man1"
New-Item -ItemType Directory -Force -Path $binDir, $manDir | Out-Null

# ─── 1. Single binary (bin/mawk.exe only) ────────────────────────────
Copy-Item $BIN $binDir\mawk.exe

# ─── 2. Man page ─────────────────────────────────────────────────────
Copy-Item $MAN_SRC $manDir\mawk.1

# ─── 3. LICENSE (upstream GPL-2.0 copy) ─────────────────────────────
Copy-Item "$MAWK_SRC\COPYING" $STAGE\LICENSE

# ─── 4. NOTICE (wrapper + upstream license split) ───────────────────
@"
# NOTICE

This archive (mawk-$TARGET) packages a build of mawk 1.3.4 plus the
wrapper build/packaging layer.

## License (wrapper)

The wrapper files (scripts/, .github/, README.md, NOTICE) are:

    Copyright (c) 2026 Li Junhao
    Licensed under the GNU General Public License, version 2 or later.
    See LICENSE for the full GPL-2.0 text.

## License (upstream mawk)

bin\mawk.exe, man\man1\mawk.1, and bundled files in upstream\ are
derived from mawk 1.3.4, vendored from
https://invisible-island.net/mawk/ (maintained by Thomas E. Dickey).

Upstream mawk is licensed under the GNU General Public License,
version 2 or later (see LICENSE).
"@ | Out-File -FilePath "$STAGE\NOTICE" -Encoding UTF8

# ─── 5. README (install + dispatch info) ────────────────────────────
@'
# mawk — single-binary release (Windows)

Self-contained archive from https://github.com/ljh-sh/mawk (release tag).

## Install

### Recommended: x-cmd eget (one-liner)

```powershell
x eget ljh-sh/mawk
```

`x eget` auto-detects your platform, downloads the matching archive,
verifies SHA256, extracts to %LOCALAPPDATA%\ljh-sh\mawk\<ver>\,
and adds the install location to your PATH. x-cmd handles the
dispatch wrapper internally.

### Manual install

```powershell
Expand-Archive mawk-$TARGET.zip
Move-Item mawk-$TARGET "$env:LOCALAPPDATA\ljh-sh\mawk\1.3.4"
```

Then run via full path:
```powershell
& "$env:LOCALAPPDATA\ljh-sh\mawk\1.3.4\bin\mawk.exe" --version
```

Or symlink to put mawk on PATH:
```powershell
New-Item -ItemType SymbolicLink `
    -Path "$env:LOCALAPPDATA\ljh-sh\mawk\bin\mawk.exe" `
    -Target "$env:LOCALAPPDATA\ljh-sh\mawk\1.3.4\bin\mawk.exe"
```

### Optional: traditional awk symlink

```powershell
New-Item -ItemType SymbolicLink `
    -Path "$env:LOCALAPPDATA\ljh-sh\mawk\bin\awk.exe" `
    -Target "$env:LOCALAPPDATA\ljh-sh\mawk\1.3.4\bin\mawk.exe"
```

(We don`t ship this symlink in the archive — it`s added at deploy
time by the package manager or the user`s shell config.)

## What`s in this archive

```
bin\mawk.exe          # the CLI, dynamic-linked (only ucrt + msvcrt)
man\man1\mawk.1      # the man page
LICENSE              # GNU GPL-2.0 (upstream copy)
NOTICE               # wrapper + upstream license split
README.md            # this file
```

## Build configuration

- `--disable-echo --enable-builtin-regex --enable-builtin-srand`
- Windows: ucrt via mingw-w64-x86_64-gcc

No bundled libraries — mawk has no external dependencies. Only
ucrt/msvcrt (which Windows provides).

## License

GPL-2.0-or-later — see LICENSE and NOTICE.
'@ | Out-File -FilePath "$STAGE\README.md" -Encoding UTF8

# ─── 6. Zip it up ────────────────────────────────────────────────────
$zipPath = "$DIST\mawk-$TARGET.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
[System.IO.Compression.ZipFile]::CreateFromDirectory($STAGE, $zipPath, `
    [System.IO.Compression.CompressionLevel]::Optimal, $false)

# Per-archive .sha256 (basename-keyed for portability)
$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
"$hash  mawk-$TARGET.zip" | Out-File -FilePath "$zipPath.sha256" -Encoding ASCII

Write-Host "==> packaged: $zipPath"
Get-ChildItem $zipPath, "$zipPath.sha256" | Select-Object Name, Length | Format-Table -AutoSize

Write-Host ""
Write-Host "==> Layout preview:"
Get-ChildItem $STAGE -Recurse | Select-Object FullName | Format-Table -AutoSize