#!/bin/bash
# ZS2 step 2 (resumable, one heavy job): Arcade identity (golden check), test build 2 from the committed fix head,
# smoke runs of the exports (Linux OpenGL, Linux OpenGL ES, Windows under wine64). Each step leaves "<step> <head> exit=…"
# in logs/zs2.log and is skipped when it already passed for this head.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
head=$(git rev-parse --short HEAD)
L=$S/logs/zs2.log
done_ok() { grep -q "$1 $head exit=0" $L 2>/dev/null; }
step() { # name, command…
	local n=$1; shift
	done_ok "$n" && return 0
	local t0=$SECONDS
	"$@" > $S/zs2/${n}_$head.log 2>&1 < /dev/null; local rc=$?
	echo "$(date +%T) $n $head exit=$rc $((SECONDS - t0)) s" >> $L
	return $rc
}
if [ -n "$(git status --porcelain)" ]; then echo "$(date +%T) zs2_build: Arbeitskopie nicht sauber – Abbruch" >> $L; exit 1; fi
export XDG_DATA_HOME=$S/xdg/zs2; mkdir -p $XDG_DATA_HOME
step golden_check nice -n 10 env KEEP=$S/zs2/golden_arcade tools/golden.sh check
step build nice -n 10 tools/build_testbuild.sh 0.8.0-zs2 ZS2 crossing-europe-zwischenstand
B=build/testbuild/ZS2
if done_ok build; then
	step smoke_linux nice -n 10 tools/smoke_modern.sh $B/CrossingEurope-ZS2.x86_64 $S/zs2/smoke_linux
	step smoke_gles nice -n 10 env DRIVER=opengl3_es tools/smoke_modern.sh $B/CrossingEurope-ZS2.x86_64 $S/zs2/smoke_gles
	step smoke_windows nice -n 10 tools/smoke_modern.sh $B/CrossingEurope-ZS2.exe $S/zs2/smoke_windows
fi
echo "ZS2 BUILD DONE $head $(date +%T)" >> $L
