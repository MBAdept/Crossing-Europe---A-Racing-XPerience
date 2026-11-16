#!/usr/bin/env bash
# Scratch (GEO): D3 experiment – run_stage ERGEBNIS with and without the race3d kernel forcing the generation ahead.
set -u
G=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/GEO
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4
cd "$W" || exit 1
export XDG_DATA_HOME=$G/xdg_d3
mkdir -p "$XDG_DATA_HOME" "$G/out"
run() {  # name, script, args...
	local name=$1; shift
	local script=$1; shift
	nice -n 10 godot --headless --path . -s "$script" -- "$@" > "$G/out/d3_$name.log" 2>&1
	grep -E "^ERGEBNIS|^D3|^RUN " "$G/out/d3_$name.log" > "$G/out/d3_$name.txt"
}
run base_dev res://tests/race/run_stage.gd --stage=dev_testetappe --hour=21 --weather=rain
run kernel_dev "$G/scratch/d3_run_stage.gd" --stage=dev_testetappe --hour=21 --weather=rain --streamer
run ahead_dev "$G/scratch/d3_run_stage.gd" --stage=dev_testetappe --hour=21 --weather=rain --force-ahead=4500
run base_sp res://tests/race/run_stage.gd --stage=saragossa_pau --weather=snow
run kernel_sp "$G/scratch/d3_run_stage.gd" --stage=saragossa_pau --weather=snow --streamer
run base_kh res://tests/race/run_stage.gd --stage=kiel_hamburg
run kernel_kh "$G/scratch/d3_run_stage.gd" --stage=kiel_hamburg --streamer
for n in dev sp kh; do
	a=$(grep "^ERGEBNIS" "$G/out/d3_base_$n.txt" | md5sum | cut -d' ' -f1)
	b=$(grep "^ERGEBNIS" "$G/out/d3_kernel_$n.txt" | md5sum | cut -d' ' -f1)
	echo "$n: base $a kernel $b $([ "$a" = "$b" ] && echo IDENTISCH || echo VERSCHIEDEN)"
done > "$G/out/d3_summary.txt"
a=$(grep "^ERGEBNIS" "$G/out/d3_base_dev.txt" | md5sum | cut -d' ' -f1)
b=$(grep "^ERGEBNIS" "$G/out/d3_ahead_dev.txt" | md5sum | cut -d' ' -f1)
echo "dev force-ahead 4500: base $a ahead $b $([ "$a" = "$b" ] && echo IDENTISCH || echo VERSCHIEDEN)" >> "$G/out/d3_summary.txt"
echo done >> "$G/out/d3_summary.txt"
