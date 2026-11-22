#!/bin/bash
# QA-RINT-SYSTEM second queue (builds, smoke, golden). Usage: q2.sh <job ...>. Do not edit while it runs.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
Q=$S/out/q
B=$S/build
mkdir -p "$Q" "$B"
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa_q
mkdir -p "$MESA_SHADER_CACHE_DIR"

job() {
	case "$1" in
	build)
		# own XDG for the export (Godot reads export templates from ~/.local/share/godot/export_templates: link them)
		home=$S/xdg/build
		mkdir -p "$home/godot"
		[ -e "$home/godot/export_templates" ] || ln -s /root/.local/share/godot/export_templates "$home/godot/export_templates"
		(cd "$W" && XDG_DATA_HOME=$home OUT=$B nice -n 10 tools/build_testbuild.sh 0.8.0-qa QA crossing-europe-qa > "$Q/build_run.log" 2>&1)
		echo "build rc=$?"
		grep -E "MB|MiB|==>|FEHLER|Error|ERROR" "$Q/build_run.log" | head -60
		ls -la "$B"
		cd "$W" && git status --porcelain | head -5 && echo "(git status after build: empty = clean)" ;;
	pck)
		python3 "$W/tools/pck_report.py" "$B/CrossingEurope-QA.exe" --archive "$B/CrossingEurope-QA-windows-x86_64.zip" --top 12 > "$Q/pck_windows.txt" 2>&1
		echo "pck windows rc=$?"
		python3 "$W/tools/pck_report.py" "$B/CrossingEurope-QA.x86_64" --archive "$B/CrossingEurope-QA-linux-x86_64.tar.gz" > "$Q/pck_linux.txt" 2>&1
		echo "pck linux rc=$?"
		cat "$Q/pck_windows.txt" | head -60
		tail -20 "$Q/pck_linux.txt" ;;
	smoke)
		(cd "$W" && nice -n 10 tools/smoke_modern.sh "$B/CrossingEurope-QA.x86_64" "$S/smoke/linux" > "$Q/smoke_linux.log" 2>&1; echo "smoke linux rc=$?")
		(cd "$W" && DRIVER=opengl3_es nice -n 10 tools/smoke_modern.sh "$B/CrossingEurope-QA.x86_64" "$S/smoke/gles" > "$Q/smoke_gles.log" 2>&1; echo "smoke gles rc=$?")
		(cd "$W" && nice -n 10 tools/smoke_modern.sh "$B/CrossingEurope-QA.exe" "$S/smoke/windows" > "$Q/smoke_windows.log" 2>&1; echo "smoke windows rc=$?")
		cat "$S/smoke/linux/smoke.txt" "$S/smoke/gles/smoke.txt" "$S/smoke/windows/smoke.txt"
		ls "$S/smoke/linux" "$S/smoke/windows" | head -40
		ls -la /root/.local/share/ | head; ls -la "/root/.local/share/crossing-europe-qa" 2>&1 | head -3 ;;
	golden)
		(cd "$W" && XDG_DATA_HOME=$S/xdg/golden KEEP=$S/golden_keep nice -n 10 tools/golden.sh check > "$Q/golden_check.log" 2>&1; echo "golden check rc=$?")
		grep -E "^GOLDEN" "$Q/golden_check.log" ;;
	gmodern)
		(cd "$W" && XDG_DATA_HOME=$S/xdg/golden KEEP=$S/golden_modern_keep nice -n 10 tools/golden.sh modern-check > "$Q/golden_modern.log" 2>&1; echo "golden modern rc=$?")
		grep -E "^GOLDEN" "$Q/golden_modern.log" ;;
	*) echo "unknown job $1" ;;
	esac
}

for j in "$@"; do
	if [ -e "$Q/$j.done" ] && [ -z "${FORCE:-}" ]; then
		echo "$(date +%T) skip $j (done)"
		continue
	fi
	echo "$(date +%T) start $j"
	job "$j" > "$Q/$j.log" 2>&1
	date +%T > "$Q/$j.done"
	echo "$(date +%T) end $j"
	cut -c1-400 "$Q/$j.log" | tail -60
done
