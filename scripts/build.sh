#!/usr/bin/env sh
# Build mawk as a static, self-contained binary. Linux gnu + macOS + MinGW.
# Out-of-tree build into BUILD_DIR (default ./build) — leaves upstream/
# untouched.
#
# Used by:
#   - .github/workflows/build-and-test.yml + release.yml on:
#       ubuntu-latest        (glibc direct)
#       ubuntu-24.04-arm     (glibc direct)
#       ubuntu-latest + alpine:3.20 docker (musl)
#       ubuntu-24.04-arm + alpine:3.20 docker (musl)
#       macos-14             (host)
#   - Local development on any POSIX host.
#
# mawk has NO external dependencies (no readline/mpfr/gmp/intl). It
# only links against libc + libm. No RPATH bundling needed.
#
# License: GPL-2.0-or-later (matches upstream).
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="${MAWK_SRC:-$ROOT/upstream}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
PREFIX="${PREFIX:-/usr/local}"

[ -f "$SRC/configure.in" ] || [ -f "$SRC/configure.ac" ] \
	|| { echo "error: $SRC missing configure.in/configure.ac" >&2; exit 1; }
[ -x "$SRC/configure" ] \
	|| { echo "error: $SRC/configure not found (re-extract tarball?)" >&2; exit 1; }
command -v make >/dev/null 2>&1 \
	|| { echo "error: make not found in PATH" >&2; exit 1; }
command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 \
	|| { echo "error: no C compiler in PATH" >&2; exit 1; }

JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.nproc 2>/dev/null || echo 4)"

# Configure args.
#   --disable-echo           cleaner configure output
#   --prefix                 where make install would put files
#                            (we use it as a hint, but we copy from
#                            $BUILD_DIR directly — see package.sh)
#   --enable-builtin-regex    mawk's own regex (default; keep)
#   --enable-builtin-srand    mawk's own srand (default; keep)
CONFIGURE_ARGS="--disable-echo --prefix=$PREFIX --enable-builtin-regex --enable-builtin-srand"

# Cross-compile: MAWK_TARGET_ARCH + MAWK_TARGET_OS, etc.
HOST_ARCH="$(uname -m 2>/dev/null || echo unknown)"
TARGET_ARCH="${MAWK_TARGET_ARCH:-$HOST_ARCH}"
TRIPLET="${MAWK_TRIPLET:-}"
if [ -n "${MAWK_TARGET_OS:-}" ]; then
	TRIPLET="${TRIPLET:-${MAWK_TARGET_ARCH}-${MAWK_TARGET_OS}}"
fi

if [ "$TARGET_ARCH" != "$HOST_ARCH" ] || [ -n "${MAWK_TARGET_OS:-}" ]; then
	[ -z "$TRIPLET" ] && TRIPLET="$TARGET_ARCH"
	case "${MAWK_OS_HINT:-}" in
	darwin)
		export CC=clang
		export CFLAGS="-arch $TARGET_ARCH -O2"
		export LDFLAGS="-arch $TARGET_ARCH"
		;;
	windows)
		case "$TARGET_ARCH" in
		x86_64)
			export CC="${TARGET_ARCH}-w64-mingw32-gcc"
			TRIPLET="${TARGET_ARCH}-w64-mingw32"
			;;
		aarch64)
			export CC=clang
			export CFLAGS="-target ${TARGET_ARCH}-w64-windows-gnu -O2"
			export LDFLAGS="-target ${TARGET_ARCH}-w64-windows-gnu"
			TRIPLET="${TARGET_ARCH}-w64-mingw32"
			;;
		esac
		;;
	*)
		echo "error: unknown MAWK_OS_HINT '$MAWK_OS_HINT' (expected 'darwin' or 'windows')" >&2
		exit 1
		;;
	esac
	CONFIGURE_ARGS="$CONFIGURE_ARGS --host=$TRIPLET"
fi

# Out-of-tree build.
mkdir -p "$BUILD_DIR"

echo "==> configure: $SRC/configure $CONFIGURE_ARGS"
echo "    CC=${CC:-cc}  CFLAGS=${CFLAGS:-default}  LDFLAGS=${LDFLAGS:-default}"
( cd "$BUILD_DIR" && "$SRC/configure" $CONFIGURE_ARGS )

echo "==> make -j$JOBS"
make -C "$BUILD_DIR" -j"$JOBS"

# Verify the binary exists and is executable.
BIN="$BUILD_DIR/mawk"
[ -x "$BIN" ] || BIN="$BUILD_DIR/mawk.exe"
[ -x "$BIN" ] || { echo "error: $BIN not built" >&2; exit 1; }
echo "==> built: $BIN"
"$BIN" --version 2>&1 | head -1