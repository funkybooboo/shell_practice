#!/usr/bin/env bash

# Usage: ./month_convert.sh <input>
#        ./month_convert.sh march      => 03
#        ./month_convert.sh 3          => March
#        ./month_convert.sh 07         => July
#        ./month_convert.sh sep        => 09

# Array of month names (1-based)
months=(January February March April May June July August September October November December)

# Normalize input
input=$(echo "$1" | awk '{print tolower($0)}')

# Try converting name → number
for i in "${!months[@]}"; do
    name="${months[$i]}"
    abbr="${name:0:3}"
    num=$(printf "%02d" $((i + 1)))

    if [[ "$input" == "${name,,}" || "$input" == "${abbr,,}" ]]; then
        echo "$num"
        exit 0
    fi
done

# Try converting number → name
if [[ "$input" =~ ^[0-9]{1,2}$ ]]; then
    idx=$((10#$input)) # interpret leading zeros correctly
    if ((idx >= 1 && idx <= 12)); then
        echo "${months[idx - 1]}"
        exit 0
    fi
fi

echo "Invalid input: $1"
exit 1
