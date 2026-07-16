# Security Policy

## Reporting a vulnerability

**Please DO NOT open a public GitHub issue for security vulnerabilities.**

### Issues in the ljh-sh/mawk wrapper itself

For issues in the wrapper (build scripts, CI, packaging, distribution
metadata), report privately to:

- Email: ljh-sh-security@duck.com
- Expected response time: best-effort, usually within 7 days

### Issues in upstream mawk (the `mawk` binary itself)

For issues in upstream mawk's source code, report to the maintainer:

- Mailing list: <dickey@invisible-island.net> (Thomas E. Dickey)
- Project page: <https://invisible-island.net/mawk/>
- Bug tracker: <https://invisible-island.net/mawk/#bugs>
- Source archive: <https://invisible-island.net/datafiles/release/mawk.tar.gz>

**ljh-sh/mawk carries no source modifications to upstream mawk 1.3.4**
(byte-for-byte vendor from the official tarball). Almost all mawk
security issues should be reported to upstream first.

## Threat model

`mawk` is a **script interpreter**. Its primary job is to execute
user-provided AWK programs — so by design, any AWK script is
attacker-controlled code running inside the `mawk` process with the
caller's UID. The trust boundary is **NOT** "mawk filters AWK input";
it's **"the operator trusts the AWK program enough to run it as their
own user"**.

### Operator requirements

**DO:**

- Run untrusted AWK scripts in a sandbox (separate UID, no network,
  tmpdir-only filesystem).
- Sanitize `MAWK_PATH`, `AWKPATH`, `MAWK_READ_TIMEOUT`, and other
  `MAWK_*` env vars before invoking mawk.

**DO NOT:**

- Invoke `mawk` with `sudo`, `setuid`, or as a privileged service
  binary. mawk is **not setuid-safe**.
- Run AWK scripts from untrusted sources with your user credentials.

### Known threats in mawk 1.3.4 (per `AUDIT-2026-07-16.md`)

| Area | Risk | Status |
|------|------|--------|
| Regex engine (built-in) | Memory safety, no known issues | Audited |
| Math library (built-in) | IEEE 754 float ops, no known issues | Audited |
| File I/O (getline, print) | Standard `FILE *` operations | Audited |
| Script execution | No sandboxing by design | Documented |

## CVE history

As of 2026-07-16, mawk has **no known unpatched security
advisories** in version 1.3.4. Historical advisories (if any) are
listed at <https://invisible-island.net/mawk/#bugs>.

This wrapper does not introduce new vulnerabilities beyond the
documented AWK language features. See [`AUDIT-2026-07-16.md`](AUDIT-2026-07-16.md)
for the source-level audit.