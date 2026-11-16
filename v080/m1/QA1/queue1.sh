#!/bin/bash
# QA1 job queue (one heavy job at a time): waits for the Modern goldens, then the start diagnostic, the A/B sheets,
# the clips and the Leistungstest. Log: queue1.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
Q=$S/queue1.log
log() { echo "$(date +%H:%M:%S) $*" >> "$Q"; }
log "queue start"
until grep -q ALLDONE "$S/golden_modern.out" 2>/dev/null; do sleep 10; done
log "modern goldens done: $(grep -E 'GOLDEN' "$S/golden_modern.out" | tr '\n' ' ')"
# start of a stage at km 0 (countdown): is the player car drawn in Modern?
mkdir -p "$S/diag"
cd "$WT" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
mkdir -p "$MESA_SHADER_CACHE_DIR"
t0=$SECONDS
GFX_ARGS="--gfx-preset=medium" tools/ab_shot.sh "$S/diag/start_km0" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1,3.3,3.7,4.5 > "$S/diag/start_km0.tool.log" 2>&1
log "diag start_km0 exit=$? $((SECONDS - t0)) s"
if [ -z "${SKIP_SHEETS:-}" ]; then
	"$S/run_sheets.sh" >> "$Q" 2>&1
	log "sheets done"
fi
"$S/run_clips.sh" >> "$Q" 2>&1
log "clips done"
"$S/run_bench.sh" low medium high deck_s3c1 >> "$Q" 2>&1
log "bench done"
log "queue end"
