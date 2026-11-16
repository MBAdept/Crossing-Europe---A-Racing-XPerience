#!/bin/bash
# scratch helper of the PIPE package (not part of the repository): one entry point for the usual steps
# usage: p.sh export <glob> [--force] | bake [glob] | import | manifest | sheet <name> [args] | inspect | all <glob> | gd <script> [args] | xgd <script> [args]
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
export XDG_DATA_HOME=$D/xdg
export MESA_SHADER_CACHE_DIR=$D/mesa
mkdir -p $D/mesa
cd $W
cmd=$1; shift
case "$cmd" in
	export)
		nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$1" --jobs=${JOBS:-1} "${@:2}" 2>&1 | grep -E "EXPORT|Export|Traceback|Error|error|File \"|^\s+[a-zA-Z_]+.*\(|raise" | grep -v CUEW
		;;
	bake)
		nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="${1:-*}" 2>&1 | grep -v "^Godot\|^$"
		;;
	import)
		nice -n 10 godot --headless --path . --import >/dev/null 2>&1
		python3 tools/models/set_model_import.py --check
		;;
	manifest)
		python3 tools/blender/export_models.py --manifest-only
		;;
	all)
		$0 export "$@" && $0 bake "$1" && $0 import && $0 manifest
		;;
	sheet)
		name=$1; shift
		nice -n 10 tools/models_contact_sheet.sh $D/$name.png "$@" 2>&1 | grep -v "AudioManager" | grep -E "contact_sheet|ERROR|SCRIPT|error|at:" | head -20
		;;
	inspect)
		godot --headless --path . -s res://tools/models/inspect_models.gd -- --out=$D/inspect.json 2>&1 | grep -v "^Godot\|^$" | head -5
		;;
	gd)
		nice -n 10 godot --headless --path . -s "$@" 2>&1 | grep -v "^Godot\|^$"
		;;
	xgd)
		nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s "$@" 2>&1 | grep -v "^Godot\|^$\|AudioManager\|^OpenGL"
		;;
	*)
		echo "unknown command $cmd"; exit 1;;
esac
