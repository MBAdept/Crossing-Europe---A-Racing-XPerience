#!/bin/bash
# QA-RINT-SYSTEM third queue. Usage: q3.sh <job ...>. Do not edit while it runs.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
Q=$S/out/q
mkdir -p "$Q"
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa_q

# small <name> <stage> <km> <weather> <preset> [res]
small() {
	local res=${6:-640x360}
	local home=$S/xdg/probe_$1
	rm -rf "$home"
	mkdir -p "$home"
	(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 ${res}x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$res" -s "$S/sh/probe_race.gd" -- --shot="$S/pics/$1.png" --graphics=modern \
		--gfx-preset="$5" --stage="$2" --km="$3" --hour=12 --weather="$4" --run-s=4 > "$Q/probe_$1.log" 2>&1)
	echo "probe $1 rc=$?"
	grep "^PROBE " "$Q/probe_$1.log" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read()[6:])
p = d['perf']
print('$1', 'gfx_lowered=', d['gfx_lowered'], 'msgs=', d['messages'])
print('   watchdog', p.get('watchdog'), p.get('watchdog_median_ms'), p.get('watchdog_p95_ms'), 'preset', p.get('preset'), 'particles', p.get('particles'), 'quality_lowered', p.get('quality_lowered'), 'frame_med', p.get('frame_ms_median'))"
	grep -E "^PROBE-LEVELS|^PROBE-ERRORS|^  (WARN|ERR)" "$Q/probe_$1.log" | cut -c1-400
}

job() {
	case "$1" in
	wd_small)
		small wds_rain kiel_hamburg 2 rain high
		small wds_snow bern_mailand 60 snow high ;;
	quit_late)
		"$S/sh/quit_restart.sh" race_paused_late ;;
	texmem)
		for m in arcade modern; do
			home=$S/xdg/probe_tex_$m
			rm -rf "$home"; mkdir -p "$home"
			(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
				--audio-driver Dummy --resolution 1280x720 -s "$S/sh/probe_race.gd" -- --shot="$S/pics/tex_$m.png" --graphics=$m \
				--gfx-preset=high --stage=kiel_hamburg --km=2 --hour=12 --autopilot --nocd --run-s=20 > "$Q/probe_tex_$m.log" 2>&1)
			echo "tex $m rc=$?"
			grep '^PROBE ' "$Q/probe_tex_$m.log" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()[6:]); print('$m', 'tex_mem_mb', round(d['tex_mem_mb'],1), 'video', round(d['video_mem_mb'],1), 'buffer', round(d['buffer_mem_mb'],1), 'gfx', d['gfx'], 'stage_time', d['stage_time'])"
			grep -E '^PROBE-ERRORS' "$Q/probe_tex_$m.log"
		done ;;
	gmut2)
		M="python3 $S/sh/mutate.py"
		$M apply scripts/race/palette.gd 'const ROAD := Color("56585e")' 'const ROAD := Color("56585f")  # QA-MUTATION one LSB'
		(cd "$S/mut" && XDG_DATA_HOME=$S/xdg/gmut nice -n 10 tools/golden.sh check race_s1 > "$Q/gmut2_road.log" 2>&1; echo "golden arcade ROAD+1 race_s1 rc=$?")
		grep -E '^GOLDEN' "$Q/gmut2_road.log"
		$M restore scripts/race/palette.gd
		$M apply scripts/race/palette.gd "$(grep -m1 '^const ROAD_CITY' "$W/scripts/race/palette.gd")" "$(grep -m1 '^const ROAD_CITY' "$W/scripts/race/palette.gd" | sed -E 's/Color\("(.....)(.)"\)/Color("\1f")/')"
		$M diff scripts/race/palette.gd | grep '^[-+]const'
		(cd "$S/mut" && XDG_DATA_HOME=$S/xdg/gmut nice -n 10 tools/golden.sh check hamburg > "$Q/gmut2_city.log" 2>&1; echo "golden arcade ROAD_CITY hamburg rc=$?")
		grep -E '^GOLDEN' "$Q/gmut2_city.log"
		$M restore scripts/race/palette.gd ;;
	roadlight)
		"$S/sh/render_mut.sh" roadlight ;;
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
