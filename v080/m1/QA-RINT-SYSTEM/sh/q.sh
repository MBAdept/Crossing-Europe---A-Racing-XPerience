#!/bin/bash
# QA-RINT-SYSTEM job queue (heavy jobs, one at a time). Usage: q.sh <job ...>
# Each job writes S/out/q/<job>.log and S/out/q/<job>.done (skipped next time unless FORCE=1).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-RINT-SYSTEM
Q=$S/out/q
mkdir -p "$Q" "$D" "$S/pics"
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa_q
mkdir -p "$MESA_SHADER_CACHE_DIR"
XV=(xvfb-run -a -s "-screen 0 1280x720x24")
GX=(--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720)

# probe <name> <tree> <timeout> <args after -- …>
probe() {
	local name=$1 tree=$2 to=$3
	shift 3
	local home=$S/xdg/probe_$name
	rm -rf "$home"
	mkdir -p "$home"
	(cd "$tree" && XDG_DATA_HOME=$home nice -n 10 timeout "$to" "${XV[@]}" godot --path . "${GX[@]}" -s "$S/sh/probe_race.gd" -- \
		--shot="$S/pics/$name.png" "$@" > "$Q/probe_$name.log" 2>&1)
	echo "probe $name rc=$?"
	grep -E "^PROBE |^PROBE-ERRORS|^  (WARN|ERR|MSGERR)" "$Q/probe_$name.log" | cut -c1-1500
	ls "$home/godot/app_userdata/"*/logs/ 2>/dev/null | head -3
}

# xstage <name> <stage> <hour> <weather> <seed> <refuel> <preset> <ts> [extra]
xstage() {
	local name=$1 stage=$2 hour=$3 weather=$4 seed=$5 refuel=$6 preset=$7 ts=$8 extra=${9:-}
	local home=$S/xdg/xstage_$name
	rm -rf "$home"
	mkdir -p "$home"
	(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 3600 "${XV[@]}" godot --path . "${GX[@]}" -s "$S/sh/stage_hash.gd" -- \
		--stage="$stage" --hour="$hour" --weather="$weather" --seed="$seed" --autopilot-refuel="$refuel" --timescale="$ts" \
		--max-seconds=3300 --graphics=modern --gfx-preset="$preset" $extra > "$S/out/stages/xvfb_$name.log" 2>&1)
	echo "xstage $name rc=$? $(grep -E '^HASHES' "$S/out/stages/xvfb_$name.log")"
	grep -E "^RUN " "$S/out/stages/xvfb_$name.log"
	python3 - "$S/out/stages/xvfb_$name.log" <<'EOF'
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if line.startswith("PERF "):
        p = json.loads(line[5:])
        st = p.get("streamer", {})
        print("BUDGET preset=%s frames=%s render_ms_avg=%.2f render_ms_max=%.2f commit_ms_max=%.2f commit_ms_avg=%.2f collect_ms_max=%.2f collect_ms_avg=%.2f draw=%s prim=%s tex=%.1f frame_med=%.1f p95=%.1f" % (
            p.get("preset"), p.get("frames"), p.get("render_ms_avg", 0), p.get("render_ms_max", 0), st.get("commit_ms_max", 0), st.get("commit_ms_avg", 0),
            st.get("collect_ms_max", 0), st.get("collect_ms_avg", 0), p.get("draw_calls"), p.get("primitives"), p.get("tex_mem_mb", 0),
            p.get("frame_ms_median", 0), p.get("frame_ms_p95", 0)))
        print("COLLECT_BY " + json.dumps(st.get("collect_by", {}), sort_keys=True))
        print("HOOKS_MAX " + json.dumps(p.get("hooks_ms_max", {}), sort_keys=True))
        print("HOOKS_AVG " + json.dumps(p.get("hooks_ms_avg", {}), sort_keys=True))
EOF
}

job() {
	case "$1" in
	x_dev)   # Rule 3 under real rendering + budgets (deck): the radar stage with fuel, border, tunnel
		xstage dev_deck dev_testetappe 14 normal 5 always deck 16 --autopilot-speeding
		python3 "$S/sh/cmp_stages.py" "$S/out/stages/head_arcade_dev_testetappe_14_normal_5_always+speed.log" "$S/out/stages/xvfb_dev_deck.log" ;;
	x_kh)
		xstage kh_deck kiel_hamburg 12 normal 7 auto deck 16
		python3 "$S/sh/cmp_stages.py" "$S/out/stages/head_arcade_kiel_hamburg_12_normal_7_auto.log" "$S/out/stages/xvfb_kh_deck.log" ;;
	x_dev2)  # second budget run (variance of the maxima)
		xstage dev_deck2 dev_testetappe 14 normal 5 always deck 16 --autopilot-speeding
		python3 "$S/sh/cmp_stages.py" "$S/out/stages/head_arcade_dev_testetappe_14_normal_5_always+speed.log" "$S/out/stages/xvfb_dev_deck2.log" ;;
	rmut)
		"$S/sh/render_mut.sh" static eyespec nightglow spotspec tint ;;
	fail)
		probe gfxfail "$W" 400 --graphics=modern --gfx-preset=medium --gfx-debug=fail --stage=kiel_hamburg --km=2 --hour=12 --run-s=2 ;;
	manifest)
		mv "$S/mut/assets/models/manifest.json" "$S/mut/assets/models/manifest.json.qa_away"
		probe nomanifest "$S/mut" 400 --graphics=modern --gfx-preset=medium --stage=kiel_hamburg --km=2 --hour=12 --run-s=2
		mv "$S/mut/assets/models/manifest.json.qa_away" "$S/mut/assets/models/manifest.json"
		# broken manifest (truncated JSON)
		cp "$S/mut/assets/models/manifest.json" "$S/mut/assets/models/manifest.json.qa_keep"
		head -c 5000 "$S/mut/assets/models/manifest.json.qa_keep" > "$S/mut/assets/models/manifest.json"
		probe badmanifest "$S/mut" 400 --graphics=modern --gfx-preset=medium --stage=kiel_hamburg --km=2 --hour=12 --run-s=2
		mv "$S/mut/assets/models/manifest.json.qa_keep" "$S/mut/assets/models/manifest.json"
		cmp "$S/mut/assets/models/manifest.json" "$W/assets/models/manifest.json" && echo "manifest restored" ;;
	wd)
		probe wd_rain "$W" 600 --graphics=modern --gfx-preset=high --stage=kiel_hamburg --km=2 --hour=12 --weather=rain --run-s=3
		probe wd_snow "$W" 600 --graphics=modern --gfx-preset=high --stage=bern_mailand --km=60 --hour=12 --weather=snow --run-s=3
		probe wd_deck_snow "$W" 600 --graphics=modern --gfx-preset=deck --stage=bern_mailand --km=60 --hour=12 --weather=snow --run-s=3 ;;
	bench)
		home=$S/xdg/bench
		rm -rf "$home"
		mkdir -p "$home"
		(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 1800 "${XV[@]}" godot --path . "${GX[@]}" -- --graphics=modern \
			--bench=all --bench-out="$Q/bench_out.json" > "$Q/bench_run.log" 2>&1)
		echo "bench rc=$?"
		grep -E "^LEISTUNGSTEST|SCRIPT ERROR|^ERROR" "$Q/bench_run.log" | cut -c1-600
		find "$home" -name leistungstest.json -exec ls -l {} \; -exec cp {} "$Q/bench_user.json" \;
		python3 - "$Q/bench_out.json" "$Q/bench_user.json" <<'EOF'
import json, sys
for p in sys.argv[1:]:
    try:
        d = json.load(open(p))
    except Exception as e:
        print("BENCHJSON FEHLER", p, e); continue
    need = ["version", "date", "adapter", "api", "tier", "preset", "quality", "resolution", "scenes", "suggested_preset", "suggested_mode", "verdict"]
    miss = [k for k in need if k not in d]
    sk = ["id", "avg_fps", "low1_fps", "frame_ms_p95", "frame_ms_p99", "script_ms", "draw_calls", "primitives"]
    smiss = [(s.get("id"), [k for k in sk if k not in s]) for s in d.get("scenes", [])]
    print("BENCHJSON", p.split("/")[-1], "missing", miss, "scenes", [(s.get("id"), s.get("avg_fps"), s.get("frames"), s.get("draw_calls"), s.get("primitives"), s.get("script_ms")) for s in d.get("scenes", [])],
          "scene_missing", smiss, "verdict", d.get("verdict"), d.get("suggested_mode"), d.get("suggested_preset"), "aborted", d.get("aborted"), "fallback", d.get("fallback"), "error", d.get("error"))
EOF
		;;
	quit)
		"$S/sh/quit_restart.sh" ;;
	drive20)
		home=$S/xdg/drive20
		rm -rf "$home"
		mkdir -p "$home"
		(cd "$W" && XDG_DATA_HOME=$home nice -n 10 timeout 1260 "${XV[@]}" godot --path . "${GX[@]}" -- --graphics=modern \
			--stage=kiel_hamburg --autopilot --gfx-preset=medium > "$Q/drive20_stdout.log" 2>&1)
		echo "drive20 rc=$? (124 = timeout after 21 min, expected)"
		lf=$(find "$home" -path "*logs/godot.log" | head -1)
		echo "log: $lf"
		[ -n "$lf" ] && cp "$lf" "$Q/drive20_godot.log"
		grep -cE "ERROR|SCRIPT ERROR|WARNING" "$Q/drive20_stdout.log"
		grep -E "ERROR|SCRIPT ERROR|WARNING|leaked" "$Q/drive20_stdout.log" | sort | uniq -c | sort -rn | head -20 ;;
	gmut)
		M="python3 $S/sh/mutate.py"
		# Arcade golden: change one colour of the frozen palette in the scratch copy only
		$M apply scripts/race/palette.gd 'const ROAD := Color("56585e")' 'const ROAD := Color("56585f")  # QA-MUTATION one LSB'
		$M diff scripts/race/palette.gd | head -8
		(cd "$S/mut" && XDG_DATA_HOME=$S/xdg/gmut tools/golden.sh check hamburg > "$Q/gmut_arcade.log" 2>&1; echo "golden arcade mut rc=$?")
		grep -E "^GOLDEN" "$Q/gmut_arcade.log"
		$M restore scripts/race/palette.gd
		# Modern golden: placement tint off
		$M apply assets/shaders/modern/baked.gdshader "	a.rgb *= v_tint;" "	a.rgb *= vec3(1.0); /* QA-MUTATION */"
		(cd "$S/mut" && XDG_DATA_HOME=$S/xdg/gmut GLES_ID= tools/golden.sh modern-check > "$Q/gmut_modern.log" 2>&1; echo "golden modern mut rc=$?")
		grep -E "^GOLDEN" "$Q/gmut_modern.log"
		$M restore assets/shaders/modern/baked.gdshader ;;
	golden)
		(cd "$W" && XDG_DATA_HOME=$S/xdg/golden nice -n 10 tools/golden.sh check > "$Q/golden_check.log" 2>&1; echo "golden check rc=$?")
		grep -E "^GOLDEN" "$Q/golden_check.log" ;;
	gmodern)
		(cd "$W" && XDG_DATA_HOME=$S/xdg/golden nice -n 10 tools/golden.sh modern-check > "$Q/golden_modern.log" 2>&1; echo "golden modern rc=$?")
		grep -E "^GOLDEN" "$Q/golden_modern.log" ;;
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
	cat "$Q/$j.log" | cut -c1-400 | tail -40
done
