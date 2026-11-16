#!/usr/bin/env bash
# AS1R: contact sheet with own XDG / shader cache, niced.  usage: sheet.sh <out.png> [contact sheet args]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR"
cd "$WT"
nice -n 10 tools/models_contact_sheet.sh "$@" 2>&1 | tail -8
