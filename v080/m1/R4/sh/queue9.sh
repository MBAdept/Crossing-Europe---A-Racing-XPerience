#!/bin/bash
# queue9.sh – successor 3: every remaining gate and measurement one after the other (nice 19 until QA_M2_FERTIG).
# Resumable: a step that logged "DONE <step>" in queue9.log is skipped on a restart.
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
L=$R4/queue9.log
nicev() {
	if [ -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
		echo 10
	else
		echo 19
	fi
}
run() {   # run <step> <command…>
	local s=$1
	shift
	grep -q "^DONE $s " "$L" 2>/dev/null && return 0
	echo "== $s start $(date -u +%T) head $(cd "$WT" && git rev-parse --short HEAD) load $(cut -d' ' -f1 /proc/loadavg) nice $(nicev)" >> "$L"
	NICE=$(nicev) "$@" >> "$L" 2>&1
	echo "DONE $s $(date -u +%T) exit=$?" >> "$L"
}
G=$R4/sh/gates.sh
O=$R4/shots/v8
mkdir -p "$O"
for step in ${QUEUE9:-sight path render_checks run_tests modern_check pic_N1 pic_N2N warm bench_head bench_base stage_head stage_base clips golden_check}; do
	case "$step" in
	sight|path|render_checks|run_tests|modern_check|golden_check) run "$step" "$G" "$step" ;;
	pic_N1) run pic_N1 env SCREEN=1280x720 "$R4/sh/ab.sh" "$O" N1 N1 high --shot-times=2 ;;
	pic_N2N) run pic_N2N env SCREEN=1280x720 "$R4/sh/ab.sh" "$O" N2N N2N high --shot-times=2 ;;
	warm) run warm "$R4/sh/warm.sh" ;;
	bench_head) run bench_head "$R4/sh/bench.sh" head "$WT" medium deck low high ;;
	bench_base) run bench_base "$R4/sh/bench.sh" base "$R4/base" medium ;;
	stage_head) run stage_head "$R4/sh/stage.sh" head "$WT" ;;
	stage_base) run stage_base "$R4/sh/stage.sh" base "$R4/base" ;;
	clips) run clips "$R4/sh/clips.sh" N2N N1 TEXIT ;;
	esac
done
echo "QUEUE9_DONE $(date -u +%T)" >> "$L"
