#!/usr/bin/env sh
# Stage the built mawk into a self-contained dist archive. Linux + macOS.
#   TARGET    e.g. x86_64-linux-glibc | aarch64-alpine-musl | aarch64-macos
#   BUILD_DIR (default $ROOT/build)
#   MAWK_SRC  (default $ROOT/upstream — for the man page)
#   DIST      (default $ROOT/dist)
#
# mawk has NO external library deps (only libc + libm), so the dist
# is just bin/mawk + man/man1/mawk.1 + LICENSE + NOTICE + README.
# No lib/ directory needed.
#
# SINGLE-BINARY POLICY: bin/ contains only `mawk`. NO `awk` symlink,
# NO `pgawk` debug variant, NO `mawk.debug` etc. Aliases are added
# at deployment time (x eget / package manager) — not embedded in
# the build artifact. This matches the ljh-sh vendored-C convention.
#
# Stage layout inside dist/mawk-$TARGET/:
#   bin/mawk              ← the CLI binary, chmod +x
#   man/man1/mawk.1        ← the man page
#   README.md             ← install + dispatch info
#   LICENSE               ← upstream GPL-2.0 copy
#   NOTICE                ← wrapper + upstream license split
#
# Output: dist/mawk-$TARGET.tar.xz + .sha256 (basename-keyed).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
MAWK_SRC="${MAWK_SRC:-$ROOT/upstream}"
DIST="${DIST:-$ROOT/dist}"
TARGET="${TARGET:?set TARGET, e.g. x86_64-linux-glibc}"

ext_for() { [ -f "$1.exe" ] && printf '%s.exe' "$1" || printf '%s' "$1"; }
BIN="$(ext_for "$BUILD_DIR/mawk")"
[ -x "$BIN" ] || { echo "error: $BIN not built (out-of-tree BUILD_DIR=$BUILD_DIR)" >&2; exit 1; }

# Man page lives under upstream/mawk.1 (upstream installs it as
# `mawk.1`, not `awk.1`).
MAN_SRC="$MAWK_SRC/man/mawk.1"
[ -f "$MAN_SRC" ] || { echo "error: $MAN_SRC not found" >&2; exit 1; }

STAGE="$DIST/mawk-$TARGET"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/man/man1"

# ─── 1. Single binary (bin/mawk only) ─────────────────────────────────
cp "$BIN" "$STAGE/bin/mawk"
chmod +x "$STAGE/bin/mawk"

# ─── 2. Man page ─────────────────────────────────────────────────────
cp "$MAN_SRC" "$STAGE/man/man1/mawk.1"

# ─── 3. LICENSE (upstream GPL-2.0 copy — required by GPL terms) ───────
cp "$MAWK_SRC/COPYING" "$STAGE/LICENSE"

# ─── 4. NOTICE (wrapper GPL-2.0 + upstream GPL-2.0 split) ─────────────
cat > "$STAGE/NOTICE" <<EOF
# NOTICE

This archive (mawk-$TARGET) packages a build of mawk 1.3.4 (continuously
versioned as 1.3.4-YYYYMMDD) plus the wrapper build/packaging layer.

## License (wrapper)

The wrapper files (scripts/, .github/, README.md, NOTICE, AUDIT-*.md)
are:

    Copyright (c) 2026 Li Junhao
    Licensed under the GNU General Public License, version 2 or later.
    See LICENSE for the full GPL-2.0 text.

## License (upstream mawk)

bin/mawk, man/man1/mawk.1, and all bundled files in upstream/ are
derived from mawk 1.3.4, vendored from the official source archive at
https://invisible-island.net/mawk/ (maintained by Thomas E. Dickey).

Upstream mawk is Copyright (C) 2008-2024,2026 Thomas E. Dickey and
Copyright (C) 1991-1994,1995 Michael D. Brennan, licensed under the
GNU General Public License, version 2 or later.

GPL-2.0 grants explicit redistribution rights for binary forms
provided that:

1. The GPL-2.0 license text accompanies the binary (LICENSE file).
2. Source code for the GPL-2.0 component is made available — it is,
   at upstream/ in the source repo and at
   https://invisible-island.net/mawk/.
3. Modified versions are clearly marked — ljh-sh/mawk carries
   no source modifications to mawk 1.3.4 (byte-for-byte upstream).

## Vendor integrity

This repository vendors upstream mawk byte-for-byte from the official
distribution. No source patches are applied. To verify the upstream
tarball before vendoring:

    curl -L -O https://invisible-island.net/datafiles/release/mawk.tar.gz
    # Author signature is published at https://invisible-island.net/mawk/
    # Mawk is maintained by Thomas E. Dickey <dickey@invisible-island.net>
    # Source archives are served over HTTPS; no detached signature file.
EOF

# ─── 5. README (install + dispatch info) ──────────────────────────────
cat > "$STAGE/README.md" <<'EOF'
# mawk — single-binary release

Self-contained archive from https://github.com/ljh-sh/mawk (release tag).

## Install

### Recommended: x-cmd `eget` (one-liner)

```sh
x eget ljh-sh/mawk
```

`x eget` auto-detects your platform, downloads the matching release
archive, verifies SHA256, extracts to `~/.local/share/ljh-sh/mawk/<ver>/`,
and adds the install location to your PATH (via x-cmd's PATH
management). x-cmd handles the dispatch wrapper internally — we
don't ship a shim in this archive.

### Manual install

```sh
tar -xJf mawk-<target>.tar.xz
# Pick a permanent location (suggestion: /opt/ljh-sh/mawk/<ver>/):
sudo mkdir -p /opt/ljh-sh/mawk
sudo cp -r mawk-<target> /opt/ljh-sh/mawk/1.3.4
# Symlink to put mawk on PATH:
sudo ln -s /opt/ljh-sh/mawk/1.3.4/bin/mawk /usr/local/bin/mawk
```

### Optional: traditional `awk` symlink

```sh
sudo ln -s /usr/local/bin/mawk /usr/local/bin/awk
```

(We don't ship this symlink in the archive — it's added at deploy
time by the package manager or the user's shell config.)

## What's in this archive

```
bin/mawk              # the CLI, dynamic-linked (only libc + libm)
man/man1/mawk.1        # the man page
LICENSE               # GNU GPL-2.0 (upstream copy)
NOTICE                # wrapper + upstream license split
README.md             # this file
```

## Build configuration

- `--disable-echo` (cleaner configure output)
- `--enable-builtin-regex` (mawk's own regex engine, default)
- `--enable-builtin-srand` (mawk's own srand, default)
- Linux glibc: built on Ubuntu 24.04 = glibc 2.39
- Linux musl: built on alpine:3.20 docker, linked against musl libc
- macOS: system libc++/libSystem
- Windows: DLLs co-located in bin/ (deferred — see issue tracker)

No bundled libraries — mawk has no external dependencies. Only
libc + libm are required at runtime, both of which are part of
every standard Linux/macOS distribution.

## License

GPL-2.0-or-later — see LICENSE and NOTICE.
EOF

# ─── 6. Tar it up (xz compression, portable across GNU/BSD tar) ────────
tar -C "$DIST" -cJf "$STAGE.tar.xz" "mawk-$TARGET"

# Per-archive .sha256 (basename-keyed for portability).
( cd "$DIST" && sha256sum "$STAGE.tar.xz" ) | sed 's|^\([^ ]*\)  \./|\1  |' \
	> "$STAGE.tar.xz.sha256"

echo "==> packaged: $STAGE.tar.xz"
ls -la "$STAGE.tar.xz" "$STAGE.tar.xz.sha256"
echo
echo "==> Layout preview:"
( cd "$STAGE" && find . -maxdepth 3 | sort | sed 's/^/    /' )