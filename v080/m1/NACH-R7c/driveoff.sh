#!/bin/bash
# NACH-R7c: the standing camera and the drive-off after the countdown (QR7c-06) – Nürnberg – Fulda km 0 at Deck,
# shots in the countdown (1.5 s), just after GO (3.3, 3.8 s) and while accelerating (4.5, 6.0 s).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12
OUTD=$S/shots
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
until grep -q "PICS DONE" "$S/logs/pics.out" 2>/dev/null; do sleep 10; done
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
t0=$SECONDS
(cd "$WT" && SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" nice -n 10 tools/ab_shot.sh "$OUTD/driveoff_nu_deck" \
	--stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12 --weather=normal --vehicle=limousine --seed=11 \
	--autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5,3.3,3.8,4.5,6.0 > "$OUTD/driveoff_ab.out" 2>&1)
echo "$(date -u +%H:%M:%S) driveoff exit=$? $((SECONDS - t0)) s" >> "$S/logs/pics.out"
echo "DRIVEOFF DONE" >> "$S/logs/pics.out"
