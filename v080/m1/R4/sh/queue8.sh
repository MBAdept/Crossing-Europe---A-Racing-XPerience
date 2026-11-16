#!/bin/bash
# queue8.sh – successor 2: leistung head/base alternating, then the audio unit tests (filter audio_modern) on head
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
L=$R4/queue8.log
N=19
[ -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && N=10
echo "== queue8 start $(date -u +%T) nice $N" >> "$L"
for i in 1 2 3 4; do
	NICE=$N "$R4/sh/leistung.sh" "q8head$i" "$WT"
	NICE=$N "$R4/sh/leistung.sh" "q8base$i" "$R4/base"
	echo "   leistung $i $(date -u +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> "$L"
done
grep -a "q8" "$R4/leistung.log" | cut -c1-140 >> "$L"
echo "== audio_modern $(date -u +%T)" >> "$L"
mkdir -p "$R4/data/q8_audio"
cd "$WT" || exit 2
XDG_DATA_HOME=$R4/data/q8_audio nice -n $N tools/run_tests.sh audio_modern > "$R4/q8_audio.log" 2>&1
echo "   exit=$? $(date -u +%T)" >> "$L"
grep -a -E "^FAIL|Tests,|bestanden|FEHLGESCHLAGEN" "$R4/q8_audio.log" | head -20 >> "$L"
echo "QUEUE8_DONE $(date -u +%T)" >> "$L"
