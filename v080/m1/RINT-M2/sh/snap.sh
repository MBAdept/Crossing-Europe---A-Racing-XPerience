#!/bin/bash
# RINT-M2: a read-only copy of a commit of the worktree for measurements (git archive + the worktree's .godot).
#   snap.sh <commit> <name>   -> $S/snap_<name>   (replaced)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
D=$S/snap_$2
mkdir -p $D
find $D -mindepth 1 -maxdepth 1 ! -name .godot -exec rm -rf {} +
git -C $W archive $1 | tar -x -C $D
rm -rf $D/.godot
cp -a $W/.godot $D/.godot
echo "$1" > $D/SNAP_COMMIT
cd $D && XDG_DATA_HOME=$S/xdg nice -n 10 timeout 900 godot --headless --path . --import > $S/logs/snap_import_$2.log 2>&1
echo "snap $2 = $1 import exit $?"
