#!/bin/bash
# R7a: the 20-s clip Saragossa – Pau (mountain bends) and the "Mittel" pictures of the extra positions.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start"
mkdir -p "$D/clips" "$S/xdg/clip"
(cd "$WT" && XDG_DATA_HOME=$S/xdg/clip CLIP_S=20 GFX_ARGS="--gfx-preset=high" MESA_SHADER_CACHE_DIR=$S/mesa CLIP_TIMEOUT=3000 nice -n 10 tools/ab_clip.sh "$D/clips/saragossa_pau_bergkurven_km197.mp4" \
	--stage=saragossa_pau --from=saragossa --start-km=197.0 --hour=11 --weather=normal --vehicle=kompakt --seed=4 --autopilot \
	--autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=80 > "$S/clip.log" 2>&1)
echo "$(date -u +%H:%M:%S) clip exit=$?"
bash "$S/sh/shots.sh" mine medium S0 Muenchen Belgrad Hannover R1
echo "$(date -u +%H:%M:%S) done"
