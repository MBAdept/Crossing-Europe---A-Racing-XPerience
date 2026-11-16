#!/bin/bash
# NACH-M2: headless props probe (QA-M2-BILD probe/qa_props.gd) on head 515dd51 at T4 and S0 (B-01).
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
P=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_props.gd
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6
mkdir -p $N/fair
pp() {
	local name=$1
	shift
	local x=$N/xdg/props_$name
	rm -rf "$x"; mkdir -p "$x"
	(cd $WT && XDG_DATA_HOME=$x nice -n 19 timeout 900 godot --headless --path . -s $P -- --graphics=modern \
		--gfx-preset=high "$@" 2>&1 | grep -E "QA-|FEHLT|OK  " | grep -v "seg=-" > $N/fair/props_$name.txt)
	echo "$(date -u +%H:%M:%S) props $name: $(grep -c FEHLT $N/fair/props_$name.txt) fehlen, $(grep -c 'OK  ' $N/fair/props_$name.txt) da"
	rm -rf "$x"
}
pp T4 --stage=saragossa_pau --from=saragossa --km=199.7 --vehicle=kompakt --seed=4 --hour=11 --ahead=150
pp S0 --stage=kiel_hamburg --from=kiel --km=0 --vehicle=limousine --seed=11 --hour=12 --ahead=150
