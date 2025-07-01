#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<EOF
Usage: $0 <from_base> <to_base> <number> [--prefix] [--pad N] [--copy]
       $0            # interactive mode
EOF
}

add_prefix() {
  local base=$1 val=$2
  case "$base" in
    2)  printf '0b%s' "$val" ;;
    8)  printf '0o%s' "$val" ;;
    16) printf '0x%s' "$val" ;;
    *)  printf '%s'  "$val" ;;
  esac
}

validate_input() {
  local base=$1 raw="$2"
  raw="${raw^^}"
  raw="${raw/#0X/}"; raw="${raw/#0B/}"; raw="${raw/#0O/}"
  local intp fracp
  if [[ "$raw" == *.* ]]; then
    intp="${raw%%.*}"
    fracp="${raw##*.}"
  else
    intp="$raw"
    fracp=""
  fi

  # build a regex for valid digits up to base
  if (( base <= 10 )); then
    local max=$((base-1))
    local pat="^[0-${max}]+$"
  else
    local max_ascii=$((55 + base - 1))
    local max_letter
    max_letter=$(printf "\\$(printf '%03o' "$max_ascii")")
    local pat="^[0-9A-${max_letter}]+$"
  fi

  if ! [[ "$intp"  =~ $pat ]]; then
    echo "❌ Invalid integer part '$intp' for base $base" >&2
    exit 1
  fi
  if [[ -n "$fracp" && ! "$fracp" =~ $pat ]]; then
    echo "❌ Invalid fractional part '$fracp' for base $base" >&2
    exit 1
  fi
}

convert_fractional() {
  local from=$1 to=$2 num="$3"
  # normalize & strip any 0x/0b/0o
  num="${num^^}"
  num="${num/#0X/}"; num="${num/#0B/}"; num="${num/#0O/}"

  local intp fracp
  if [[ "$num" == *.* ]]; then
    intp="${num%%.*}"
    fracp="${num##*.}"
  else
    intp="$num"
    fracp=""
  fi

  # 1) integer part
  local int_res
  int_res=$(echo "obase=$to; ibase=$from; $intp" | bc)

  # 2) if no fraction, we’re done
  if [[ -z "$fracp" ]]; then
    printf '%s\n' "$int_res"
    return
  fi

  # 3) build numerator/denominator for the fractional part
  local numerator
  numerator=$(echo "obase=10; ibase=$from; $fracp" | bc)
  local denom
  denom=$(echo "$from^${#fracp}" | bc)

  # 4) extract up to 10 digits in the target base
  local prec=10
  local frac_res=""
  for ((i=0; i<prec; i++)); do
    numerator=$(echo "$numerator * $to" | bc)
    # digit = floor(numerator/denom)
    local digit
    digit=$(echo "$numerator / $denom" | bc)
    # new remainder
    numerator=$(echo "$numerator % $denom" | bc)
    # map 10→A, 11→B, …, 35→Z
    if (( digit >= 10 )); then
      digit=$(printf "\\$(printf '%03o' $((digit + 55)))")
    fi
    frac_res+="$digit"
  done

  # 5) strip trailing zeros
  frac_res=$(echo "$frac_res" | sed 's/0\+$//')

  # 6) assemble
  if [[ -n "$frac_res" ]]; then
    printf '%s.%s\n' "$int_res" "$frac_res"
  else
    printf '%s\n'     "$int_res"
  fi
}

copy_to_clipboard() {
  local txt="$1"
  if   command -v xclip  &>/dev/null; then echo -n "$txt" | xclip  -selection clipboard
  elif command -v pbcopy &>/dev/null; then echo -n "$txt" | pbcopy
  elif command -v wl-copy &>/dev/null; then echo -n "$txt" | wl-copy
  else
    echo "⚠️ No clipboard tool found; skipping copy" >&2
  fi
}

# ——— Interactive mode ———
if (( $# == 0 )); then
  read -rp "From base: "       from_base
  read -rp "To base:   "       to_base
  read -rp "Number:    "       number
  read -rp "Prefix? [y/N]: "   use_pref
  read -rp "Pad to N (opt): "  pad_w
  read -rp "Copy? [y/N]: "     do_copy

  args=( "$from_base" "$to_base" "$number" )
  [[ "$use_pref" =~ ^[Yy]$ ]] && args+=(--prefix)
  [[ "$pad_w"    =~ ^[0-9]+$ ]] && args+=(--pad "$pad_w")
  [[ "$do_copy"  =~ ^[Yy]$ ]] && args+=(--copy)
  exec "$0" "${args[@]}"
fi

# ——— CLI mode ———
from_base=$1; to_base=$2; number=$3; shift 3
prefix=0; pad_width=""; do_copy=0

while (( $# > 0 )); do
  case $1 in
    --prefix) prefix=1    ;;
    --pad)    pad_width=$2; shift ;;
    --copy)   do_copy=1   ;;
    *)        echo "Unknown option: $1" >&2; show_usage; exit 1 ;;
  esac
  shift
done

# validate base ranges
if (( from_base<2 || from_base>36 || to_base<2 || to_base>36 )); then
  echo "❌ Bases must be between 2 and 36" >&2
  exit 1
fi

validate_input "$from_base" "$number"
result=$(convert_fractional "$from_base" "$to_base" "$number")

# apply zero-padding if requested
if [[ -n "$pad_width" ]]; then
  intp="${result%%.*}"
  fracp="${result#*.}"
  [[ "$result" != *.* ]] && fracp=""
  intp=$(printf "%${pad_width}s" "$intp" | tr ' ' 0)
  result="$intp"
  [[ -n "$fracp" ]] && result+=".$fracp"
fi

# apply prefix if requested
(( prefix )) && result=$(add_prefix "$to_base" "$result")

# copy to clipboard if requested
(( do_copy )) && copy_to_clipboard "$result"

# final output
echo "$result"
