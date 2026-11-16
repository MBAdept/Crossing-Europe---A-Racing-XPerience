#!/usr/bin/env bash
# AS2a: render lod2 of sedan / hatch / sports with the committed (HEAD) lod2 meshes for a before/after comparison;
# the rebuilt files are put back afterwards (md5 checked).
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
mkdir -p "$S/out/newres"
cd "$WT"
for m in sedan:traffic/sedan_red hatch:traffic/hatch_green sports:traffic/sports_yellow; do
	n=${m%%:*}; s=${m#*:}
	f=assets/models/traffic/$n/lod2_body.res
	cp "$f" "$S/out/newres/$n.res"
	git show "HEAD:$f" > "$f"
	"$S/bin/sheet.sh" "$S/out/r6_${n}_lod2_old.png" --only="traffic/$n" --chase=25 --lods=lod2 --set=$s --day --tile=480x300 --cols=1 | tail -1
	cp "$S/out/newres/$n.res" "$f"
	md5sum "$f" "$S/out/newres/$n.res"
done
git status --short assets/models/traffic
