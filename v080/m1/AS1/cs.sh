#!/usr/bin/env bash
# contact sheet helper: cs.sh <out.png (relative to scratch)> [args of tools/models_contact_sheet.sh]
set -euo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
OUT="$1"; shift
case "$OUT" in
	/*) ;;
	*) OUT="$S/$OUT" ;;
esac
cd "$W"
nice -n 10 tools/models_contact_sheet.sh "$OUT" "$@" 2>&1 | grep -v "AudioManager\|^$" | tail -6
