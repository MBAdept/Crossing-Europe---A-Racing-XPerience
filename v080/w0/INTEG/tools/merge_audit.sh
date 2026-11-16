#!/usr/bin/env bash
# Integration helper (not part of the repository): for every package branch, the files the package changed
# (against the merge base with the integration base) that are NOT byte-identical in the merged tree.
# Expected: only config/game_config.json (two packages add different sections) and files a later integration
# commit changed. Usage: merge_audit.sh <base commit> <merged commit> <name=branch>...
set -uo pipefail
BASE=$1
MERGED=$2
shift 2
for pair in "$@"; do
	name=${pair%%=*}
	branch=${pair##*=}
	mb=$(git merge-base "$BASE" "$branch")
	own=$(git diff --name-only "$mb" "$branch" | sort)
	differ=$(git diff --name-only "$branch" "$MERGED" | sort)
	both=$(comm -12 <(echo "$own") <(echo "$differ"))
	echo "$name ($branch, Basis ${mb:0:7}): $(echo "$own" | grep -c .) eigene Dateien, im zusammengeführten Stand anders: $(echo "$both" | grep -c .) $(echo "$both" | tr '\n' ' ')"
done
