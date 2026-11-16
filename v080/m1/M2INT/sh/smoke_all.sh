#!/usr/bin/env bash
# M2INT: smoke runs of the exported builds (tools/smoke_modern.sh: Arcade + Modern start of Kiel – Hamburg, two
# pictures each, a Leistungstest scene in Modern) for Linux (Xvfb) and Windows (wine64), then the seed variants from
# the pck (export_olives.sh). One run after the other; wineserver -w between the Wine runs; TMPDIR unset for Wine.
# usage: smoke_all.sh <out_dir> [linux|windows|olives ...]
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
OUT=$1
shift
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(linux windows olives)
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
cd "$WT" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
WINESERVER=$(command -v wineserver || echo /usr/lib/wine/wineserver)
export WINEPREFIX=$S/wineprefix_m2int
for st in "${STEPS[@]}"; do
	t0=$(date +%s)
	case "$st" in
	linux)
		nice -n $NICE tools/smoke_modern.sh "$WT/build/CrossingEurope.x86_64" "$OUT/linux" > "$OUT/smoke_linux.log" 2>&1
		echo "smoke linux exit $? ($(( $(date +%s) - t0 )) s)"
		cat "$OUT/linux/smoke.txt" 2>/dev/null
		;;
	windows)
		(unset TMPDIR; nice -n $NICE tools/smoke_modern.sh "$WT/build/CrossingEurope.exe" "$OUT/windows") > "$OUT/smoke_windows.log" 2>&1
		code=$?
		"$WINESERVER" -w 2>/dev/null
		echo "smoke windows exit $code ($(( $(date +%s) - t0 )) s)"
		cat "$OUT/windows/smoke.txt" 2>/dev/null
		;;
	olives)
		(unset TMPDIR; nice -n $NICE bash "$S/sh/export_olives.sh" "$WT/build/CrossingEurope.x86_64" "$WT/build/CrossingEurope.exe" "$OUT/olives")
		"$WINESERVER" -w 2>/dev/null
		echo "olives ($(( $(date +%s) - t0 )) s)"
		;;
	esac
done
