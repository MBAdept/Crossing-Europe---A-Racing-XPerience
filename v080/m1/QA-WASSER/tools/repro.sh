#!/usr/bin/env bash
# QA-WASSER: export the game data (PCK) of the clean worktree at 0ad9012 and compare it file by file (md5 of the PCK
# directory) with the PCK inside the delivered Linux and Windows programs. Expected difference: project.binary only
# (the test build patches version and user folder for the export).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-2
cd "$W" || exit 1
echo "HEAD $(git rev-parse HEAD)"
git status --short
export XDG_DATA_HOME=$S/xdg/repro
mkdir -p "$XDG_DATA_HOME/godot/export_templates" "$S/repro"
[ -e "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable" ] || ln -s /root/.local/share/godot/export_templates/4.7.2.stable "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable"
rm -f "$S/repro/linux.pck" "$S/repro/windows.pck"
t0=$SECONDS
nice -n 5 timeout 900 godot --headless --path . --export-pack "Linux" "$S/repro/linux.pck" > "$S/repro/export_linux.log" 2>&1
echo "export-pack Linux exit $? ($((SECONDS - t0)) s)"
nice -n 5 timeout 900 godot --headless --path . --export-pack "Windows Desktop" "$S/repro/windows.pck" > "$S/repro/export_windows.log" 2>&1
echo "export-pack Windows exit $? ($((SECONDS - t0)) s)"
git status --short
python3 -I "$S/tools/pck_diff.py" "$S/repro/linux.pck" "$S/lin/CrossingEurope-ZS1.x86_64"
python3 -I "$S/tools/pck_diff.py" "$S/repro/windows.pck" "$S/win/CrossingEurope-ZS1.exe"
