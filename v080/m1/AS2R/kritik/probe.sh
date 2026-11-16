#!/usr/bin/env bash
# AS2R: LOD-swap probe of several sets.  usage: probe.sh <tag> <dist> <lodA> <lodB> <set> [<set> ...]
# -> out/<tag>/ tiles, sheets/<tag>_<set>.jpg, numbers on stdout
set -uo pipefail
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik
TAG=$1; D=$2; A=$3; B=$4
shift 4
python3 $K/bin/jobs_probe_multi.py "$D" "$A" "$B" "$K/jobs/$TAG.json" "$@"
$K/run_jobs.sh "$K/jobs/$TAG.json" "$K/out/$TAG" | tail -1
for sid in "$@"; do
	s=${sid#*/}
	python3 $K/bin/probe_sheet.py "$K/out/$TAG" "$s" "$D" "$A" "$B" "$K/sheets/${TAG}_$s.jpg" | head -2
done
