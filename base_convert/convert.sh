#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<EOF
Usage: $0 <from_base> <to_base> <number> [OPTIONS]
       $0                     # interactive mode

Options:
  -P, --prefix           add 0b/0o/0x when converting to base 2/8/16
  -p N, --pad N          zero-pad integer part to width N
  -c, --copy             copy result to clipboard (xclip/pbcopy/wl-copy)
  -n N, --precision N    fraction digits (default 10), with rounding
  -l, --lowercase        output letters in lowercase
  -g N, --group N        group integer digits every N chars with "_"
EOF
}

add_prefix() {
  case "$1" in
    2)  printf '0b%s' "$2" ;;
    8)  printf '0o%s' "$2" ;;
    16) printf '0x%s' "$2" ;;
    *)  printf '%s'  "$2" ;;
  esac
}

validate_input() {
  local base=$1 raw="${2^^}" intp fracp pat
  raw="${raw/#0X/}"; raw="${raw/#0B/}"; raw="${raw/#0O/}"
  if [[ "$raw" == *.* ]]; then
    intp="${raw%%.*}"; fracp="${raw##*.}"
  else
    intp="$raw"; fracp=""
  fi

  if (( base <= 10 )); then
    pat="^[0-$((base-1))]+$"
  else
    local ma=$((55 + base - 1))
    local ml; ml=$(printf "\\$(printf '%03o' "$ma")")
    pat="^[0-9A-${ml}]+$"
  fi

  if ! [[ "$intp" =~ $pat ]]; then
    echo "❌ Invalid integer part '$intp' for base $base" >&2
    exit 1
  fi
  if [[ -n "$fracp" && ! "$fracp" =~ $pat ]]; then
    echo "❌ Invalid fractional part '$fracp' for base $base" >&2
    exit 1
  fi
}

convert_fractional() {
  local from=$1 to=$2 num="${3^^}" prec=$4
  num="${num/#0X/}"; num="${num/#0B/}"; num="${num/#0O/}"

  local intp fracp int_res f bpow N frac_digits
  if [[ "$num" == *.* ]]; then
    intp="${num%%.*}"; fracp="${num##*.}"
  else
    intp="$num"; fracp=""
  fi

  # integer part
  int_res=$(echo "obase=$to; ibase=$from; $intp" | bc)

  # no fraction?
  [[ -z "$fracp" ]] && { printf '%s\n' "$int_res"; return; }

  # decimal fraction f = .fracp in base 10 with extra precision
  f=$(echo "scale=$((prec+5)); obase=10; ibase=$from; .${fracp}" | bc -l)
  # B^prec
  bpow=$(echo "$to^$prec" | bc)
  # N = round(f * B^prec)
  N=$(echo "scale=0; ($f * $bpow + 0.5)/1" | bc)

  # carry to integer if needed
  if (( N >= bpow )); then
    N=0
    int_res=$(echo "obase=$to; ibase=$to; $int_res + 1" | bc)
  fi

  # convert N to base-$to and pad
  frac_digits=$(echo "obase=$to; ibase=10; $N" | bc)
  frac_digits=$(printf "%0${prec}s" "$frac_digits")
  frac_digits=$(echo "$frac_digits" | sed 's/0\+$//')

  if [[ -n "$frac_digits" ]]; then
    printf '%s.%s\n' "$int_res" "$frac_digits"
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
    echo "⚠️  No clipboard tool found; skipping copy" >&2
  fi
}

# — interactive mode —
if (( $# == 0 )); then
  read -rp "From base:       " from_base
  read -rp "To base:         " to_base
  if ! [[ "$from_base" =~ ^[0-9]+$ && "$to_base" =~ ^[0-9]+$ ]]; then
    echo "Aborting interactive mode." >&2
    exit 0
  fi

  read -rp "Number:          " number
  read -rp "Prefix? [y/N]:   " use_pref
  read -rp "Pad to N (opt):  " pad_w
  read -rp "Copy? [y/N]:     " do_copy
  read -rp "Precision (opt): " prec
  read -rp "Lowercase? [y/N]:" lc
  read -rp "Group every N:   " grp

  args=( "$from_base" "$to_base" "$number" )
  [[ "$use_pref" =~ ^[Yy]$ ]]   && args+=(--prefix)
  [[ "$pad_w"    =~ ^[0-9]+$ ]] && args+=(--pad "$pad_w")
  [[ "$do_copy"  =~ ^[Yy]$ ]]   && args+=(--copy)
  [[ "$prec"     =~ ^[0-9]+$ ]] && args+=(--precision "$prec")
  [[ "$lc"       =~ ^[Yy]$ ]]   && args+=(--lowercase)
  [[ "$grp"      =~ ^[0-9]+$ ]] && args+=(--group "$grp")
  exec "$0" "${args[@]}"
fi

# — CLI mode with short aliases —
from_base=$1; to_base=$2; number=$3; shift 3
prefix=0; pad_width=""; do_copy=0
precision=10; lowercase=0; group_size=""

while (( $# > 0 )); do
  case $1 in
    -P|--prefix)          prefix=1            ;;
    -p|--pad)             pad_width=$2; shift ;;
    -c|--copy)            do_copy=1           ;;
    -n|--precision)       precision=$2; shift ;;
    -l|--lowercase)       lowercase=1         ;;
    -g|--group)           group_size=$2; shift;;
    *) echo "Unknown option: $1" >&2; show_usage; exit 1 ;;
  esac
  shift
done

# handle sign
sign=""
if [[ "$number" == -* ]]; then
  sign="-"; number="${number#-}"
elif [[ "$number" == +* ]]; then
  number="${number#+}"
fi

# validate bases
(( from_base<2 || from_base>36 || to_base<2 || to_base>36 )) \
  && echo "❌ Bases must be between 2 and 36" >&2 && exit 1
validate_input "$from_base" "$number"

# perform conversion
raw=$(convert_fractional "$from_base" "$to_base" "$number" "$precision")

# split integer/fraction
intp="${raw%%.*}"; fracp="${raw#*.}"
[[ "$raw" != *.* ]] && fracp=""

# pad integer
[[ -n "$pad_width" ]] && intp=$(printf "%${pad_width}s" "$intp" | tr ' ' 0)

# group digits
if [[ -n "$group_size" ]]; then
  grouped=""; len=${#intp}
  fg=$(( len % group_size )); (( fg==0 )) && fg=$group_size
  grouped="${intp:0:fg}"
  for ((i=fg; i<len; i+=group_size)); do
    grouped+="_${intp:i:group_size}"
  done
  intp=$grouped
fi

# assemble and finalize
result="$intp"; [[ -n "$fracp" ]] && result+=".$fracp"
(( prefix   )) && result=$(add_prefix "$to_base" "$result")
result="$sign$result"
(( lowercase)) && result="${result,,}"
(( do_copy  )) && copy_to_clipboard "$result"

echo "$result"
