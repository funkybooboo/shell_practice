#!/usr/bin/env bash
set -euo pipefail

SCRIPT=./convert.sh
fail=0

run_test() {
  name="$1"; expected="$2"; shift 2
  out=$("$SCRIPT" "$@" 2>/dev/null)
  if [[ "$out" == "$expected" ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "  Expected: $expected"
    echo "  Got:      $out"
    fail=1
  fi
}

run_test_err() {
  name="$1"; expected_err="$2"; shift 2
  if out=$("$SCRIPT" "$@" 2>err); then
    code=0
  else
    code=$?
  fi
  err=$(<err); rm err
  if (( code != 0 )) && grep -q "$expected_err" <<<"$err"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "  Expected error containing: $expected_err"
    echo "  Exit code: $code"
    echo "  Stderr: $err"
    fail=1
  fi
}

test_grep() {
  name="$1"; pattern="$2"; shift 2
  out=$("$SCRIPT" "$@" 2>/dev/null)
  if grep -qE "$pattern" <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    echo "  Pattern '$pattern' not found in output: $out"
    fail=1
  fi
}

echo "Running convert.sh self-tests…"
echo

# 1. Simple integer conversions
run_test "int dec→bin"                  "1111"           10 2 15
run_test "int dec→bin prefix"           "0b1111"         10 2 15 --prefix
run_test "int hex→dec lowercase prefix" "15"             16 10 0xF --prefix --lowercase
run_test "int hex→dec"                  "15"             16 10 0xF
run_test "int neg"                      "-1111"          10 2 -15

# 2. Padding, grouping & lowercase
run_test "pad"                          "00111"          10 2 7 --pad 5
run_test "group"                        "1111_1111"      10 2 255 --group 4
run_test "combined"                     "0x12_34_ab_cd"  10 16 305441741 --prefix --pad 8 --group 2 --lowercase

# 3. Fractional conversions
run_test "frac dec→oct"                 "15.5"           10 8 13.625
run_test "frac dec→hex"                 "1A.1"           10 16 26.0625
run_test "frac small"                   "0.1"            10 16 0.0625

# 4. Precision & rounding
run_test "prec round"                   "0.112"          10 3 0.5 --precision 3
run_test "prec bin→dec"                 "0.5"            2 10 0.1 --precision 5

# 5. Negative fractional (fast)
run_test "neg frac"                     "-0xf.6"         10 16 -15.375 --precision 1 --prefix --lowercase

# 6. Largest-base
run_test "base36→dec"                   "1679615"        36 10 ZZZZ

# 7. Fractional base-36→hex (prefix match)
test_grep  "frac36→hex"  '^23\.'         36 16 Z.Z

# 8. Invalid integer part
run_test_err "invalid int part"         "Invalid integer part" 2 10 2.01

# 9. Invalid bases
run_test_err "invalid base range"       "Bases must be between" 1 1 5

echo
if (( fail )); then
  echo "Some tests FAILED."
  exit 1
else
  echo "All tests passed! 🎉"
  exit 0
fi
