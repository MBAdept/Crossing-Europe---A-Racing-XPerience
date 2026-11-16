#!/bin/bash
# Runs the v0.8.0 migration check on a fresh copy of the v0.7.0 user folder; then runs v0.7.0 again on the migrated
# folder (downgrade: does v0.7.0 still read a v3 settings file?).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
X=$S/xdg_mig
rm -rf "$X"; cp -a "$S/xdg_v070" "$X"
cd "$WT" || exit 2
XDG_DATA_HOME=$X nice -n 10 timeout 300 godot --headless --path . -s "$S/gd/v080_migration.gd" -- --graphics=arcade > "$S/migration.log" 2>&1
echo "migration exit=$?"
grep -E "^CHECK|ERGEBNIS-QA|V0[78]0 settings|SCRIPT ERROR|ERROR" "$S/migration.log"
