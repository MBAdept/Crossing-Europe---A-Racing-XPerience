#!/bin/bash
# Export main (= v0.7.0) into a scratch folder as the reference game, reuse the imported textures.
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
REF=$S/ref070
cd "$WT" || exit 2
if [ -f "$REF/project.godot" ]; then echo "ref exists"; exit 0; fi
mkdir -p "$REF"
git archive main | tar -x -C "$REF"
mkdir -p "$REF/.godot"
cp -a "$WT/.godot/imported" "$REF/.godot/imported"
t0=$SECONDS
nice -n 10 godot --headless --path "$REF" --import > "$S/ref_import.log" 2>&1
echo "import exit $? $((SECONDS - t0)) s"
grep -ciE "error" "$S/ref_import.log"
grep -m1 'config/version' "$REF/project.godot"
du -sh "$REF"
