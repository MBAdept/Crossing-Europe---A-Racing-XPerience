#!/usr/bin/env bash
# FIX-WASSER queue 5: waits for queue 3 (build + smokes + walk), then the gates on the clean head (gates.sh)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
until grep -q '^== fertig' "$S/queue3.log"; do sleep 5; done
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
if [ -n "$(git status --short)" ]; then
	git status --short
	echo "Arbeitskopie nicht sauber – Tore nicht gestartet"
	exit 1
fi
echo "== gates $(date -u +%T) HEAD $(git rev-parse --short HEAD)"
bash "$S/gates.sh" > "$S/gates_run.log" 2>&1
echo "gates exit $? $(date -u +%T)"
echo "== fertig $(date -u +%T)"
