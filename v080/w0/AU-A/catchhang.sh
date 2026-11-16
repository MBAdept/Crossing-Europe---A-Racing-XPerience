#!/usr/bin/env bash
# Repeats the live check until one run hangs, then dumps gdb information of the hung process and kills it.
# Usage: catchhang.sh <max runs> [extra user args…]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
N="${1:-20}"
shift || true
export XDG_DATA_HOME="$W/xdg_check"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
for i in $(seq 1 "$N"); do
	nice -n 10 godot --headless --path . -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade --live "$@" >"$W/logs/hang_$i.log" 2>&1 &
	PID=$!
	for t in $(seq 1 "${LIMIT:-40}"); do
		sleep 1
		if ! kill -0 "$PID" 2>/dev/null; then
			break
		fi
	done
	if kill -0 "$PID" 2>/dev/null; then
		echo "Lauf $i hängt (PID $PID) – Protokoll:"
		tail -6 "$W/logs/hang_$i.log" | cut -c1-300
		gdb -p "$PID" -batch \
			-ex "thread apply all bt 14" \
			-ex "thread 3" -ex "info registers rip rsp rbp rax rbx rcx rdx rsi rdi r8 r9 r10 r11 r12 r13 r14 r15" \
			-ex "x/60i \$pc-90" \
			-ex "echo \n--- generator object memory (pointer at this+0x608)\n" \
			-ex "x/2gx \$rbx+0x608" -ex "x/72wx *(long*)(\$rbx+0x608)" \
			-ex "echo \n--- playback object memory around 0x5e0\n" -ex "x/16wx \$rbx+0x5e0" \
			-ex "echo \n--- rate returned by the call at 0x3b93c9d\n" \
			-ex "break *0x3b93ca2" -ex "continue" -ex "p \$xmm0.v4_float[0]" -ex "p \$r13" -ex "delete" \
			-ex "echo \n--- frame 1\n" -ex "frame 1" -ex "x/90i \$pc-200" -ex "info registers" >"$W/logs/hang_gdb_$i.txt" 2>&1
		kill -9 "$PID"
		echo "gdb: $W/logs/hang_gdb_$i.txt"
		exit 1
	fi
	wait "$PID"
	echo "Lauf $i: Exit $?"
done
echo "kein Hänger in $N Läufen"
