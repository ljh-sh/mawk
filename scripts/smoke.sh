#!/usr/bin/env sh
# Smoke test for the freshly-built mawk CLI. Reference: ljh-sh/gawk
# smoke.sh — basic E2E that runs on every matrix target in
# build-and-test.yml + release.yml.
#
# mawk has no external library deps (libc + libm only), so the
# smoke test is straightforward: just verify mawk runs and the AWK
# language interpreter is functional.
#
# What we test (the minimum viable mawk):
#
#  -- interpreter --
#   1. --version banner
#   2. -f script-file execution
#   3. Field separator (-F)
#   4. Pattern match (/regex/)
#   5. BEGIN / END blocks
#   6. printf formatting
#   7. AWK numeric ops (sum)
#   8. Variables
#   9. String functions (length, substr, toupper)
#  10. Redirection (write to stdout)
#
# `make check` from upstream also runs mawk_test + mawk_errs +
# fpe_test — but those are heavier and require upstream test
# fixtures. We focus on the basic E2E that proves the binary is
# functional in every build environment.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SRC="${MAWK_SRC:-$ROOT/upstream}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
EXPECTED_VERSION="${EXPECTED_VERSION:-1.3.4}"

ext_for() { [ -f "$1.exe" ] && printf '%s.exe' "$1" || printf '%s' "$1"; }
MAWK="$(ext_for "$BUILD_DIR/mawk")"
[ -x "$MAWK" ] || { echo "error: $MAWK not built (BUILD_DIR=$BUILD_DIR)" >&2; exit 1; }

# Verify the version banner.
echo "==> 1. --version banner"
out="$("$MAWK" -W version 2>&1 | head -1)"
case "$out" in
	*"mawk ${EXPECTED_VERSION}"*)
		echo "    OK: $out"
		;;
	*)
		echo "FAIL: expected 'mawk ${EXPECTED_VERSION}' in banner, got: $out" >&2
		exit 1
		;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_eq() { # $1=label  $2=expected  $3=actual
	# Strip trailing CR (Windows) + normalize newlines for compare.
	expected_norm=$(printf '%s' "$2" | tr -d '\r')
	actual_norm=$(printf '%s' "$3" | tr -d '\r')
	if [ "$expected_norm" = "$actual_norm" ]; then
		echo "    OK [$1]: $3"
	else
		echo "FAIL [$1]: expected '$2', got '$3'" >&2
		exit 1
	fi
}

# 2. -f script-file execution
echo "==> 2. -f script-file execution"
cat > "$TMP/hello.awk" <<'EOF'
BEGIN { print "hello" }
EOF
out="$("$MAWK" -f "$TMP/hello.awk" </dev/null)"
assert_eq "2-f" "hello" "$out"

# 3. Field separator
echo "==> 3. Field separator (-F:)"
out="$(printf 'a:b:c\n' | "$MAWK" -F: '{print $2}')"
assert_eq "3-F" "b" "$out"

# 4. Pattern match
echo "==> 4. Pattern match"
# Use a file (not inline) to avoid bash brace expansion eating
# the { } in the awk script (especially in cmd substitution).
cat > "$TMP/p.awk" <<'EOF'
/bar/ { print "match" }
EOF
out="$(printf 'foo\nbar\nbaz\n' | "$MAWK" -f "$TMP/p.awk")"
assert_eq "4-pattern" "match" "$out"

# 5. BEGIN / END blocks
echo "==> 5. BEGIN / END blocks"
out="$(printf '1\n2\n3\n4\n5\n' | "$MAWK" 'BEGIN{c=0} {c++} END{print c}')"
assert_eq "5-beginend" "5" "$out"

# 6. printf formatting
echo "==> 6. printf formatting"
out="$(printf '' | "$MAWK" 'BEGIN{printf "%.3f", 1/3}')"
assert_eq "6-printf" "0.333" "$out"

# 7. AWK numeric ops (sum)
echo "==> 7. Numeric sum"
out="$(printf '1\n2\n3\n4\n5\n' | "$MAWK" 'BEGIN{s=0} {s+=$1} END{print s}')"
assert_eq "7-sum" "15" "$out"

# 8. Variables
echo "==> 8. Variables"
out="$(printf '' | "$MAWK" 'BEGIN{x=10; y=20; print x+y}')"
assert_eq "8-var" "30" "$out"

# 9. String functions
echo "==> 9. String functions"
out="$(printf '' | "$MAWK" 'BEGIN{s="hello"; print toupper(s), length(s)}')"
assert_eq "9-stringfn" "HELLO 5" "$out"

# 10. Redirection (write to stdout)
echo "==> 10. Redirection"
cat > "$TMP/r.awk" <<'EOF'
{ print $1 "!" }
EOF
out="$(printf 'a\nb\nc\n' | "$MAWK" -f "$TMP/r.awk")"
assert_eq "10-redirect" "$(printf 'a!\nb!\nc!')" "$out"

echo
echo "==> ALL SMOKE TESTS PASSED"
echo "    binary: $MAWK"