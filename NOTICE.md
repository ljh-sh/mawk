# NOTICE

This repository (`ljh-sh/mawk`) provides self-contained, multi-platform
builds of **mawk 1.3.4** (continuously versioned as `1.3.4-YYYYMMDD`)
plus the build/packaging layer around it.

## License (wrapper)

The wrapper files (scripts/, .github/workflows/, README.md, NOTICE.md,
AUDIT-*.md, LICENSE) are:

    Copyright (c) 2026 Li Junhao
    Licensed under the GNU General Public License, version 2 or later.
    See LICENSE for the full GPL-2.0 text.

## License (upstream mawk)

`upstream/` is an unmodified copy of mawk 1.3.4, vendored from
the official source archive at
[`https://invisible-island.net/datafiles/release/mawk.tar.gz`](https://invisible-island.net/datafiles/release/mawk.tar.gz)
(maintained by Thomas E. Dickey <dickey@invisible-island.net>).

Upstream mawk is:

    Copyright (C) 2008-2024,2026 Thomas E. Dickey
    Copyright (C) 1991-1994,1995 Michael D. Brennan

Licensed under the GNU General Public License, version 2 or later.
See `upstream/COPYING` for the full GPL-2.0 text.

## Why wrapper license matches upstream

ljh-sh/mawk deliberately uses **GPL-2.0** (matching upstream) rather
than the more permissive **MIT** (used by some other ljh-sh wrapper
repos like `ljh-sh/lhasa`, `ljh-sh/wdiff`, `ljh-sh/dwdiff`).

The reasoning:
- mawk's LICENSE is GPL-2.0. Using a different wrapper license
  (e.g. MIT) creates a multi-license distribution which adds
  complexity without benefit.
- GPL-2.0 grants explicit redistribution rights for binary forms
  provided that the GPL-2.0 text accompanies the binary and source
  is made available — both of which ljh-sh/mawk does.
- A single-license distribution is simpler for downstream packagers
  to reason about ("this whole thing is GPL-2.0").

This is not a contamination risk because:
- The wrapper is original work by ljh-sh (not derived from mawk).
- GPL-2.0 does not require *incoming* code to be GPL-2.0 — it's
  an outbound license. The wrapper can be any license; we choose
  GPL-2.0 for consistency.

## Vendor integrity

This repository vendors upstream mawk **byte-for-byte** from the
official tarball. No source patches are applied.

To verify the upstream tarball before vendoring:

```sh
curl -L -O https://invisible-island.net/datafiles/release/mawk.tar.gz
# Mawk is maintained by Thomas E. Dickey <dickey@invisible-island.net>
# Source archives are served over HTTPS; no detached signature file
# is published (the project relies on TLS + server-controlled
# distribution rather than PGP-signed releases).
# Verify checksums (e.g. via known-good comparison with the
# maintainer's published MD5/SHA256 if available) before committing.
tar -xzf mawk.tar.gz
# Compare the extracted tree to the git vendor:
diff -r upstream/ mawk-1.3.4-YYYYMMDD/ | head
```

After vendoring, record the upstream commit-equivalent (tarball
SHA256 + extraction timestamp) in the audit log.

## Distribution channels

| Channel | Repository |
|---------|-----------|
| GitHub source + releases | `github.com/ljh-sh/mawk` |
| Pre-built binaries (xz tarball per target) | GitHub Releases `v*` tags |
| Convenience one-liner | `x eget ljh-sh/mawk` (via x-cmd's `eget` wrapper) |