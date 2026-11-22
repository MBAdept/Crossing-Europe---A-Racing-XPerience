#!/bin/bash
# R7a: second queue – base pictures where something changed, the roof R1 again (closer), occlusion, perf, clip.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start"
bash "$S/sh/shots.sh" mine high R1
bash "$S/sh/shots.sh" base high R1 S0 Lyon Muenchen Belgrad Hannover
bash "$S/sh/queue_occl.sh" T4 T3
for p in T1 T2 C1 S0 S4; do
	case "$p" in
	T1) a="--stage=kassel_wuerzburg --from=kassel --km=46.5 --hour=15 --vehicle=kombi --seed=12" ;;
	T2) a="--stage=kassel_wuerzburg --from=kassel --km=61.9 --hour=15 --vehicle=kombi --seed=12" ;;
	C1) a="--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15" ;;
	S0) a="--stage=kiel_hamburg --from=kiel --km=0 --hour=12 --vehicle=limousine --seed=11" ;;
	S4) a="--stage=kiel_hamburg --from=kiel --km=80 --hour=12 --vehicle=limousine --seed=11" ;;
	esac
	# shellcheck disable=SC2086
	bash "$S/sh/occl.sh" mine "$p" $a
done
bash "$S/sh/stage.sh" kh_mine mine modern medium kiel_hamburg kiel 12 normal 40
bash "$S/sh/stage.sh" kh_base base modern medium kiel_hamburg kiel 12 normal 40
mkdir -p "$D/clips"
(cd "$WT" && CLIP_S=20 GFX_ARGS="--gfx-preset=high" MESA_SHADER_CACHE_DIR=$S/mesa CLIP_TIMEOUT=3000 nice -n 10 tools/ab_clip.sh "$D/clips/saragossa_pau_bergkurven_km197.mp4" \
	--stage=saragossa_pau --from=saragossa --start-km=197.0 --hour=11 --weather=normal --vehicle=kompakt --seed=4 --autopilot \
	--autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=80 > "$S/clip.log" 2>&1)
echo "$(date -u +%H:%M:%S) clip exit=$?"
echo "$(date -u +%H:%M:%S) done"
