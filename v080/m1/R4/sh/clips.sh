#!/bin/bash
# clips.sh [POS…] – A/B clips (tools/ab_clip.sh, 20 s, 60 fps, Modern "Hoch") one after the other into clips/<POS>.mp4
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
N=${NICE:-19}
mkdir -p "$R4/clips"
cd "$WT" || exit 2
export MESA_SHADER_CACHE_DIR=$R4/mesa
for p in "${@:-N2N N1 TEXIT}"; do
	for q in $p; do
		ARGS=$("$R4/sh/pos.sh" "$q") || continue
		echo "== $q $(date -u +%T)" >> "$R4/clips/clips.log"
		# shellcheck disable=SC2086
		GFX_ARGS="--gfx-preset=${PRESET:-high}" CLIP_S=${CLIP_S:-20} nice -n $N tools/ab_clip.sh "$R4/clips/$q.mp4" $ARGS \
			> "$R4/clips/$q.out" 2>&1
		echo "   exit=$? $(date -u +%T)" >> "$R4/clips/clips.log"
	done
done
echo CLIPS_DONE >> "$R4/clips/clips.log"
