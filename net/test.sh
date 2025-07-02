#!/usr/bin/env bash
set -euo pipefail

SCRIPT=./netadmin.sh
fail=0

echo "Running netadmin.sh self-tests…"
echo

# Strip ANSI colors (BSD/GNU compatible)
strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*[mK]//g'
}

test_subnet() {
  echo -n "1. Subnet calculation… "
  out=$($SCRIPT subnet 192.168.1.130/26 | strip_ansi)
  grep -q '^[[:space:]]*Network[[:space:]]\+192\.168\.1\.128/26$' <<<"$out" \
    && grep -q '^[[:space:]]*Broadcast[[:space:]]\+192\.168\.1\.191$' <<<"$out" \
    && grep -q '^[[:space:]]*First host[[:space:]]\+192\.168\.1\.129$' <<<"$out" \
    && grep -q '^[[:space:]]*Usable[[:space:]]\+62$' <<<"$out" \
    && { echo "PASS"; return; }
  echo "FAIL"; echo "$out"; fail=1
}

test_split() {
  echo -n "2. Split into 4 subnets… "
  out=$($SCRIPT split 192.168.1.0/24 4 | strip_ansi)
  # fixed-string match for the header line
  if printf '%s\n' "$out" | grep -F -q "Splitting 192.168.1.0/24 into 4 subnets (/26):" \
     && grep -q '^[[:space:]]*1[)] 192\.168\.1\.0/26$' <<<"$out" \
     && grep -q '^[[:space:]]*4[)] 192\.168\.1\.192/26$' <<<"$out"; then
    echo "PASS"
  else
    echo "FAIL"
    echo "$out"
    fail=1
  fi
}

test_dns_example_mx_fallback() {
  echo -n "3. DNS MX→A fallback (example.com)… "
  out=$($SCRIPT dns example.com --type MX --json)
  if grep -q '"type":"A"' <<<"$out"; then
    echo "PASS"
  else
    echo "FAIL"; echo "$out"; fail=1
  fi
}

test_dns_gmail_mx() {
  echo -n "4. DNS MX records (gmail.com)… "
  out=$($SCRIPT dns gmail.com --type MX --json)
  if grep -q '"type":"MX"' <<<"$out"; then
    echo "PASS"
  else
    echo "FAIL"; echo "$out"; fail=1
  fi
}

test_dns_csv() {
  echo -n "5. DNS CSV output… "
  out=$($SCRIPT dns gmail.com --type MX --csv)
  if [[ $(head -n1 <<<"$out") == "type,data" ]]; then
    echo "PASS"
  else
    echo "FAIL"; echo "$out"; fail=1
  fi
}

test_scan_json() {
  echo -n "6. Port scan JSON format… "
  out=$($SCRIPT scan 127.0.0.1 --ports 80 --json)
  if [[ $out == \[*\] ]]; then
    echo "PASS"
  else
    echo "FAIL"; echo "$out"; fail=1
  fi
}

test_scan_csv() {
  echo -n "7. Port scan CSV format… "
  out=$($SCRIPT scan 127.0.0.1 --ports 80 --csv)
  if [[ $(head -n1 <<<"$out") == "port,state" ]]; then
    echo "PASS"
  else
    echo "FAIL"; echo "$out"; fail=1
  fi
}

main() {
  test_subnet
  test_split
  test_dns_example_mx_fallback
  test_dns_gmail_mx
  test_dns_csv
  test_scan_json
  test_scan_csv

  echo
  if (( fail )); then
    echo "Some tests FAILED."
    exit 1
  else
    echo "All tests passed! 🎉"
    exit 0
  fi
}

main
