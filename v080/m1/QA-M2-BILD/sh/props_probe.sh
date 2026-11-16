#!/bin/bash
# QA-M2-BILD: headless props probe (probe/qa_props.gd) at the picture positions: which Arcade props near the camera
# does Modern leave out, and why. Output fair/props_<name>.txt
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
pp() {   # pp <name> <args...>
	local name=$1
	shift
	local x=$S/xdg/props_$name
	rm -rf "$x"; mkdir -p "$x"
	(cd $WT && XDG_DATA_HOME=$x nice -n 10 timeout 900 godot --headless --path . -s $S/probe/qa_props.gd -- --graphics=modern \
		--gfx-preset=${PRESET:-high} "$@" 2>&1 | grep -E "QA-|FEHLT|OK  " | grep -v "seg=-" > $S/fair/props_$name.txt)
	echo "$(date -u +%H:%M:%S) props $name: $(grep -c FEHLT $S/fair/props_$name.txt) fehlen, $(grep -c 'OK  ' $S/fair/props_$name.txt) da"
	rm -rf "$x"
}
pp T4 --stage=saragossa_pau --from=saragossa --km=199.7 --vehicle=kompakt --seed=4 --hour=11 --ahead=150
pp T1 --stage=kassel_wuerzburg --from=kassel --km=47.5 --vehicle=kombi --seed=12 --hour=15 --ahead=150
pp C1 --stage=dortmund_frankfurt --from=dortmund --km=221.8 --vehicle=sportwagen --seed=15 --hour=19.5 --ahead=150
pp S4 --stage=kiel_hamburg --from=kiel --km=80.4 --vehicle=limousine --seed=11 --hour=12 --ahead=150
pp T3 --stage=saragossa_pau --from=saragossa --km=173.5 --vehicle=kompakt --seed=4 --hour=11 --ahead=150
