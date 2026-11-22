#!/bin/bash
# QA-RINT-SYSTEM fourth queue: 20 min Modern drive with progress (stage_hash.gd under Xvfb), budget variance run.
# Usage: q4.sh <job ...>. Do not edit while it runs.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
Q=$S/out/q
mkdir -p "$Q"
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa_q

job() {
	case "$1" in
	drive20p)
		# Bern – Mailand from km 120 (Gotthard area: tunnels, mountain bends, border) at 18:30 into dusk/night, Modern
		# "Mittel", time scale 4 (the session steps the simulation per physics tick), 20 min wall clock
		home=$S/xdg/drive20p
		rm -rf "$home"
		mkdir -p "$home"
		(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
			--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 -s "$S/sh/stage_hash.gd" -- \
			--stage=bern_mailand --start-km=120 --hour=18.5 --weather=normal --seed=21 --timescale=4 --max-seconds=1200 \
			--graphics=modern --gfx-preset=medium > "$Q/drive20p.out" 2>&1)
		echo "drive20p rc=$? (1 = stopped by the 1200 s wall limit, expected unless the stage ended)"
		grep -E "^\.\.\. km" "$Q/drive20p.out" | sed -n '1p;$p'
		grep -E "^RUN |^HASHES|FEHLER" "$Q/drive20p.out" | cut -c1-300
		echo "error/warning lines:"
		grep -nE "ERROR|SCRIPT ERROR|WARNING|leaked|Parse Error|Too many instances" "$Q/drive20p.out" | grep -v "V-Sync" | head -20
		echo "(end of error lines)" ;;
	*) echo "unknown job $1" ;;
	esac
}

for j in "$@"; do
	if [ -e "$Q/$j.done" ] && [ -z "${FORCE:-}" ]; then
		echo "$(date +%T) skip $j (done)"
		continue
	fi
	echo "$(date +%T) start $j"
	job "$j" > "$Q/$j.log" 2>&1
	date +%T > "$Q/$j.done"
	echo "$(date +%T) end $j"
	cut -c1-400 "$Q/$j.log" | tail -40
done
