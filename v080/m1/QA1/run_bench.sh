#!/bin/bash
# QA1: Leistungstest through the real runner (--bench=all --bench-out) per preset on llvmpipe (Xvfb), real time.
# usage: run_bench.sh [low medium high auto deck_s3c1]
#   auto       no --gfx-preset (the preset this machine picks)
#   deck_s3c1  preset deck at the contract's budget positions S3 and C1 (QA1 acceptance): the scene list is replaced
#              through user://game_config.json (deep merge, arrays replace) – the runner itself is unchanged
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
OUT=$S/m1/QA1/bench
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/m1/QA1/mesa_bench
mkdir -p "$MESA_SHADER_CACHE_DIR"
cd "$WT" || exit 1
for p in ${*:-low medium high}; do
	X=$S/m1/QA1/xdg_bench_$p
	rm -rf "$X"; mkdir -p "$X"
	UD="$X/godot/app_userdata/Crossing Europe – A Racing Xperience"
	G=(--gfx-preset=$p)
	case $p in
	auto) G=() ;;
	deck_s3c1)
		G=(--gfx-preset=deck)
		mkdir -p "$UD"
		cat > "$UD/game_config.json" <<'EOF'
{"graphics": {"benchmark": {"scenes": [
 {"id": "s3_autobahn", "name": "S3 Kiel – Hamburg km 60", "stage": "kiel_hamburg", "from": "kiel", "km": 60.0, "hour": 12.0,
  "weather": "normal", "vehicle": "limousine", "speed_kmh": 120, "cruise_kmh": 130, "seed": 11},
 {"id": "c1_city_limits", "name": "C1 Dortmund – Frankfurt km 221", "stage": "dortmund_frankfurt", "from": "dortmund",
  "km": 221.0, "hour": 19.5, "weather": "normal", "vehicle": "sportwagen", "speed_kmh": 90, "cruise_kmh": 100, "seed": 15}
]}}}
EOF
		;;
	esac
	t0=$SECONDS
	XDG_DATA_HOME=$X nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -- --graphics=modern --no-chooser "${G[@]}" --bench=all \
		--bench-out="$OUT/leistungstest_$p.json" > "$OUT/bench_$p.log" 2>&1
	echo "bench $p exit=$? $((SECONDS - t0)) s load=$(cut -d' ' -f1-3 /proc/loadavg)"
	cmp -s "$UD/leistungstest.json" "$OUT/leistungstest_$p.json" && echo "  user://leistungstest.json = --bench-out" || echo "  user file differs or missing"
	grep -E "Config: Overrides" "$OUT/bench_$p.log" | head -2
	grep -E "SCRIPT ERROR|^ERROR" "$OUT/bench_$p.log" | sort | uniq -c | head -5
done
echo ALLDONE
