#!/usr/bin/env bash
# AS2b: contact sheet with own XDG / shader cache, nice 19.  usage: sheet.sh <abs out.png> [contact sheet args]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR"
cd "$WT"
nice -n 19 tools/models_contact_sheet.sh "$@" 2>&1 | tail -8
