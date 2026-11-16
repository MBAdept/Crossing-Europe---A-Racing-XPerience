#!/usr/bin/env bash
# waitfor.sh <file> <regex> <max seconds>: waits until the file contains the regex (exit 0) or the time is up (exit 1)
F=$1; R=$2; M=${3:-540}; T0=$SECONDS
while [ $((SECONDS - T0)) -lt "$M" ]; do
  if [ -f "$F" ] && grep -qE "$R" "$F"; then echo "found after $((SECONDS - T0)) s"; exit 0; fi
  sleep 10
done
echo "timeout after $M s"; exit 1
