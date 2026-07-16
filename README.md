# mawk — full-featured, single-binary multi-platform builds of mawk 1.3.4

[Vendored](upstream/) [mawk 1.3.4](https://invisible-island.net/mawk/)
(a GPL-2.0-or-later AWK interpreter maintained by Thomas E. Dickey)
with a native per-OS packaging layer that produces **single-binary**
distributables. No external library dependencies — only libc + libm,
both of which are part of every standard Linux/macOS distribution.

This is a **distribution repo** (mawk source + build/packaging
scripts + CI). See `NOTICE.md` for the upstream GPL-2.0 terms that
apply to the `mawk` binary.

## Binary

Built into each release archive under `bin/`:

| binary | purpose |
|---|---|
| `mawk` | the CLI — AWK interpreter |

> **No `awk` symlink.** The user requirement is a single `mawk`
> binary in the archive; the traditional `awk` → `mawk` symlink
> is created at deployment time (by the `x eget` wrapper or your
> package manager), not embedded in the build artifact. This
> matches the ljh-sh vendored-C convention.

## Install

Each release publishes multi-architecture xz-compressed tarballs.
The fastest cross-platform one-line install uses x-cmd:

```bash
x eget ljh-sh/mawk    # auto-detects arch, verifies SHA256, adds to PATH
```

If you want a traditional `awk` symlink:

```bash
sudo ln -s /usr/local/bin/mawk /usr/local/bin/awk
```

## Platform matrix

Six targets via GitHub Actions on native runners. mawk has no
external library dependencies (libc + libm only), so there's no
bundled `lib/` directory — just `bin/mawk` + man pages.

| target | runner | linkage | archive |
|---|---|---|---|
| `x86_64-linux-glibc` | `ubuntu-latest` | glibc dynamic | `.tar.xz` |
| `aarch64-linux-glibc` | `ubuntu-24.04-arm` | glibc dynamic | `.tar.xz` |
| `x86_64-alpine-musl` | `ubuntu-latest` + `alpine:3.20` docker | musl dynamic | `.tar.xz` |
| `aarch64-alpine-musl` | `ubuntu-24.04-arm` + `alpine:3.20` docker | musl dynamic | `.tar.xz` |
| `aarch64-macos` | `macos-14` | dynamic, system libc | `.tar.xz` |
| `x86_64-macos` | `macos-14` (cross from aarch64) | dynamic, system libc | `.tar.xz` |
| `x86_64-windows` | `windows-latest` + MSYS2 + mingw64 | dynamic | `.zip` *(deferred)* |
| `aarch64-windows` | `windows-11-arm` + MSYS2 + mingw64 | dynamic | `.zip` *(deferred)* |

> Windows builds are currently deferred (tracked in issue tracker).
> MSYS2 ships its own `mingw-w64-x86_64-mawk` package, so Windows
> users already have access to a working build via `pacman -S mawk`.

## Build configuration

The wrapper scripts apply the following configure flags unconditionally:

| Flag | Reason |
|------|--------|
| `--disable-echo` | cleaner configure output |
| `--enable-builtin-regex` | mawk's own regex engine (default; no system libpcre/regex dep) |
| `--enable-builtin-srand` | mawk's own srand (default; no system getrandom dep) |

## Build from source (vendoring update)

This repo ships `upstream/` as a byte-for-byte copy of the official
mawk 1.3.4 source archive from
`https://invisible-island.net/datafiles/release/mawk.tar.gz`. To
refresh the vendoring:

```sh
curl -L -O https://invisible-island.net/datafiles/release/mawk.tar.gz
tar -xzf mawk.tar.gz
rm -rf upstream
mv mawk-1.3.4-YYYYMMDD upstream
```

Verify byte-for-byte upstream match after the update:

```sh
git diff HEAD~1..HEAD -- upstream/ | head -20
```

(Repository layout follows ljh-sh/lhasa, ljh-sh/gawk, ljh-sh/wdiff,
ljh-sh/dwdiff convention.)

## Repository layout

```
upstream/              # git tree copy of mawk 1.3.4 source (no patches)
scripts/
  build.sh            # POSIX build, cross-compile aware
  package.sh          # stage bin/ + man/, xz + sha256
  smoke.sh            # 10-step E2E test (--version, BEGIN/END, fields, regex, etc.)
.github/workflows/
  build-and-test.yml  # push + PR: 6-target matrix + artifact upload
  release.yml         # v* tag + dispatch: same matrix + softprops release
AUDIT-2026-07-16.md   # source-level security audit
README.md             # this file
NOTICE.md             # wrapper + upstream license split
SECURITY.md           # vulnerability reporting policy
LICENSE               # GPL-2.0 (upstream copy)
```

## Security

See [`SECURITY.md`](SECURITY.md) for the vulnerability reporting
policy and [`AUDIT-2026-07-16.md`](AUDIT-2026-07-16.md) for the
source-level audit of vendored mawk 1.3.4.

## License

- **Wrapper** (this repo's own files: scripts, .github, README,
  NOTICE, AUDIT, LICENSE): **GPL-2.0-or-later** (matches upstream).
- **Vendored upstream/**: **GPL-2.0-or-later** (same license;
  this is intentional consistency, not violation of GPL terms).

The `mawk` binary is GPL-2.0; redistribution in binary form requires
keeping the LICENSE and source-available.