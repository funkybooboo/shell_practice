#!/usr/bin/env bash
set -euo pipefail

# ─── Helpers & Globals ────────────────────────────────────────────────────────
: "${RED:=$(tput setaf 1 2>/dev/null||echo)}"
: "${YLW:=$(tput setaf 3 2>/dev/null||echo)}"
: "${BLU:=$(tput setaf 4 2>/dev/null||echo)}"
: "${RST:=$(tput sgr0 2>/dev/null||echo)}"

json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ip2num(){ IFS=.; read -r a b c d <<<"$1"; printf '%u\n' $((a<<24|b<<16|c<<8|d)); }
num2ip(){ local n=$1; printf '%d.%d.%d.%d' $((n>>24&255)) $((n>>16&255)) $((n>>8&255)) $((n&255)); }

# ─── Usage ───────────────────────────────────────────────────────────────────
show_usage(){
  cat <<EOF
${BLU}netadmin.sh${RST} — all-in-one network helper

Usage: $0 <command> [options...]

Commands:
  subnet <IP>/<prefix>            Subnet details
  split  <IP>/<prefix> <count>    Split into N subnets (N=power of 2)
  dns    <domain> [--type T]      DNS lookup (A,AAAA,MX,NS,TXT; default=A)
             [--json|--csv]
  scan   <host> [--ports P1,P2..] Port scan (nmap or /dev/tcp; default 22,80,443)
             [--json|--csv]

Examples:
  $0 dns example.com --type MX --json   # MX→A fallback if no MX exist
EOF
}

# ─── CIDR Validation ─────────────────────────────────────────────────────────
validate_cidr(){
  local raw=$1
  [[ "$raw" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]] || {
    echo "${RED}❌ Invalid CIDR${RST}" >&2; exit 1; }
  local ip="${raw%/*}" p="${raw#*/}"
  (( p>=0 && p<=32 )) || { echo "${RED}❌ Prefix must be 0–32${RST}" >&2; exit 1; }
  IFS=. read -r a b c d <<<"$ip"
  for oct in $a $b $c $d; do
    (( oct>=0 && oct<=255 )) || {
      echo "${RED}❌ Octet out of range: $oct${RST}" >&2; exit 1; }
  done
}

# ─── Subnet Details ──────────────────────────────────────────────────────────
calculate_subnet(){
  local cidr="$1"
  local ip="${cidr%/*}" prefix="${cidr#*/}"
  local ipnum mask wild net bcst first last hosts

  ipnum=$(ip2num "$ip")
  mask=$(( (0xFFFFFFFF<<(32-prefix)) & 0xFFFFFFFF ))
  wild=$(( ~mask & 0xFFFFFFFF ))
  net=$(( ipnum & mask )); bcst=$(( net | wild ))

  if (( prefix<31 )); then
    first=$(( net+1 )); last=$(( bcst-1 ))
    hosts=$(( (1<<(32-prefix)) - 2 ))
  elif (( prefix==31 )); then
    first=$net; last=$bcst; hosts=2
  else
    first=$net; last=$net; hosts=1
  fi

  echo "${YLW}Subnet ${cidr}:${RST}"
  printf "  %-12s %s/%s\n" Network   "$(num2ip $net)"  "$prefix"
  printf "  %-12s %s\n"    Broadcast "$(num2ip $bcst)"
  printf "  %-12s %s\n"    Netmask   "$(num2ip $mask)"
  printf "  %-12s %s\n"    Wildcard  "$(num2ip $wild)"
  printf "  %-12s %s\n"    "First host" "$(num2ip $first)"
  printf "  %-12s %s\n"    "Last host"  "$(num2ip $last)"
  printf "  %-12s %s\n"    Usable     "$hosts"
}

# ─── Split Subnet ────────────────────────────────────────────────────────────
split_subnet(){
  local cidr="$1" count="$2"
  validate_cidr "$cidr"

  local ip="${cidr%/*}" prefix="${cidr#*/}"
  local ipnum total bits newp size
  ipnum=$(ip2num "$ip"); total=$((1<<(32-prefix)))

  (( count>0 ))      || { echo "${RED}❌ count must be >0${RST}" >&2; exit 1; }
  (( count&(count-1) )) && { echo "${RED}❌ count must be power of two${RST}" >&2; exit 1; }
  (( count<=total )) || { echo "${RED}❌ too many subnets${RST}" >&2; exit 1; }

  bits=$(awk "BEGIN{printf \"%d\", log($count)/log(2)}")
  newp=$(( prefix + bits )); size=$(( total / count ))

  echo "${YLW}Splitting ${cidr} into ${count} subnets (/${newp}):${RST}"
  for ((i=0;i<count;i++)); do
    printf "  %2d) %s/%d\n" $((i+1)) \
      "$(num2ip $((ipnum + i*size)))" "$newp"
  done
}

# ─── DNS Lookup w/ MX→A Fallback ─────────────────────────────────────────────
do_dns(){
  local domain=$1 type=A fmt=text; shift
  while (($#)); do
    case $1 in
      --type) type=${2^^}; shift 2 ;;
      --json) fmt=json; shift       ;;
      --csv)  fmt=csv;  shift       ;;
      *) echo "${RED}Unknown dns option: $1${RST}" >&2; exit 1 ;;
    esac
  done

  local used_dig=0 out=()
  command -v dig &>/dev/null && used_dig=1

  fetch(){
    local t=$1; out=()
    if (( used_dig )); then
      while read -r _ _ _ R D; do out+=( "$R|$D" ); done \
        < <(dig +nocmd +noall +answer "$domain" "$t")
    else
      while read -r L; do
        [[ -z $L ]] && continue
        local R D
        case "$t" in
          A)    [[ $L =~ has[[:space:]]address[[:space:]]([0-9\.]+) ]] \
                   && { R=A; D=${BASH_REMATCH[1]}; out+=( "$R|$D" ); } ;;
          AAAA) [[ $L =~ has[[:space:]]IPv6[[:space:]]address[[:space:]]([0-9A-Fa-f:]+) ]] \
                   && { R=AAAA; D=${BASH_REMATCH[1]}; out+=( "$R|$D" ); } ;;
          NS)   [[ $L =~ name[[:space:]]server[[:space:]]([^ ]+)\.?$ ]] \
                   && { R=NS; D=${BASH_REMATCH[1]}; out+=( "$R|$D" ); } ;;
          MX)   [[ $L =~ handled[[:space:]]by[[:space:]][0-9]+[[:space:]]([^ ]+)\.?$ ]] \
                   && { R=MX; D=${BASH_REMATCH[1]}; \
                         [[ "$D" == "." ]] && continue; \
                         out+=( "$R|$D" ); } ;;
          TXT)  [[ $L =~ text[[:space:]]\"(.+)\"$ ]] \
                   && { R=TXT; D=${BASH_REMATCH[1]}; out+=( "$R|$D" ); } ;;
        esac
      done < <(host -t "$t" "$domain")
    fi
  }

  fetch "$type"
  if [[ $type == MX && ${#out[@]} -eq 0 ]]; then
    type=A; fetch A
  fi

  case $fmt in
    text)
      echo "${YLW}DNS ${type} for ${domain}:${RST}"
      for rec in "${out[@]}"; do IFS=\| read -r r d <<<"$rec"; printf "  %-6s %s\n" "$r" "$d"; done ;;
    csv)
      echo 'type,data'
      for rec in "${out[@]}"; do IFS=\| read -r r d <<<"$rec"; printf '%s,%s\n' "$r" "$d"; done ;;
    json)
      printf '[\n'; local first=1
      for rec in "${out[@]}"; do
        IFS=\| read -r r d <<<"$rec"
        (( first )) && first=0 || printf ',\n'
        printf '  {"type":"%s","data":"%s"}' "$r" "$(json_escape "$d")"
      done
      printf '\n]\n' ;;
  esac
}

# ─── Port Scan ───────────────────────────────────────────────────────────────
do_scan(){
  local host=$1 ports=() fmt=text; shift
  while (($#)); do
    case $1 in
      --ports) IFS=, read -ra ports<<<"$2"; shift 2 ;;
      --json)  fmt=json; shift       ;;
      --csv)   fmt=csv;  shift       ;;
      *) echo "${RED}Unknown scan option: $1${RST}" >&2; exit 1 ;;
    esac
  done
  [[ ${#ports[@]} -gt 0 ]] || ports=(22 80 443)

  local scan_out=()
  if command -v nmap &>/dev/null; then
    while read -r L; do
      [[ $L =~ ^([0-9]+)/tcp[[:space:]]+open ]]   && scan_out+=( "${BASH_REMATCH[1]}|open" )
      [[ $L =~ ^([0-9]+)/tcp[[:space:]]+closed ]] && scan_out+=( "${BASH_REMATCH[1]}|closed" )
    done < <(nmap -p$(IFS=,;echo "${ports[*]}") -Pn "$host")
  else
    for p in "${ports[@]}"; do
      if timeout 1 bash -c ">/dev/tcp/$host/$p" &>/dev/null; then
        scan_out+=( "$p|open" )
      else
        scan_out+=( "$p|closed" )
      fi
    done
  fi

  case $fmt in
    text)
      echo "${YLW}Port scan on ${host}:${RST}"
      printf "  %-6s %-6s\n" PORT STATE
      for rec in "${scan_out[@]}"; do IFS=\| read -r p s<<<"$rec"; printf "  %-6s %-6s\n" "$p" "$s"; done ;;
    csv)
      echo 'port,state'
      for rec in "${scan_out[@]}"; do IFS=\| read -r p s<<<"$rec"; printf '%s,%s\n' "$p" "$s"; done ;;
    json)
      printf '[\n'; local first=1
      for rec in "${scan_out[@]}"; do IFS=\| read -r p s<<<"$rec"
        (( first )) && first=0 || printf ',\n'
        printf '  {"port":%s,"state":"%s"}' "$p" "$s"
      done
      printf '\n]\n' ;;
  esac
}

# ─── Main Dispatch ───────────────────────────────────────────────────────────
if (( $#<1 )); then
  show_usage; exit 1
fi

cmd=$1; shift
case $cmd in
  subnet) (( $#>=1 )) || { show_usage; exit 1; }; validate_cidr "$1"; calculate_subnet "$1" ;;
  split ) (( $#>=2 )) || { show_usage; exit 1; }; validate_cidr "$1"; split_subnet "$1" "$2" ;;
  dns   ) do_dns "$@" ;;
  scan  ) do_scan "$@" ;;
  *)
    echo "${RED}Unknown command: $cmd${RST}" >&2
    show_usage; exit 1
    ;;
esac
