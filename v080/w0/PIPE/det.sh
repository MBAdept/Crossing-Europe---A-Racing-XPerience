#!/bin/bash
# scratch: determinism of the bake
#  1  two bakes into the same, each time empty folder outside the project: every file byte-identical
#  2  the model folders of the repository deleted and baked again: byte-identical to what was there
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
export XDG_DATA_HOME=$D/xdg
cd $W
sums() { (cd "$1" && find . -type f -not -name manifest.json -not -name sets_default.json | sort | xargs md5sum); }
rm -rf $D/bake_x $D/bake_x1
for n in 1 2; do
	mkdir -p $D/bake_x
	nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --out=$D/bake_x 2>&1 | grep -v "^Godot\|^$" | tail -1
	sums $D/bake_x > $D/bake_run$n.md5
	if [ $n = 1 ]; then mv $D/bake_x $D/bake_x1; fi
done
if cmp -s $D/bake_run1.md5 $D/bake_run2.md5; then
	echo "BAKE 1 = BAKE 2: $(wc -l < $D/bake_run1.md5) Dateien byte-gleich (gleicher, jeweils leerer Zielordner)"
else
	echo "BAKE 1 != BAKE 2"; diff $D/bake_run1.md5 $D/bake_run2.md5 | head -20
fi
sums $W/assets/models > $D/repo_before.md5
rm -rf $W/assets/models/landmarks $W/assets/models/player $W/assets/models/props $W/assets/models/traffic
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd 2>&1 | grep -v "^Godot\|^$" | tail -7
sums $W/assets/models > $D/repo_after.md5
if cmp -s $D/repo_before.md5 $D/repo_after.md5; then
	echo "REPO: gelöscht und neu gebacken = vorher: $(wc -l < $D/repo_after.md5) Dateien byte-gleich"
else
	echo "REPO: neu gebacken != vorher"; diff $D/repo_before.md5 $D/repo_after.md5 | head -20
fi
git -C $W status --short assets/models
