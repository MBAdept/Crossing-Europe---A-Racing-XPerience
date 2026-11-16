#!/usr/bin/env bash
# Scratch (GEO): debug renders of the kernel at the reference positions (chase view through the real Camera3D + top view).
set -u
G=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/GEO
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4
cd "$W" || exit 1
export XDG_DATA_HOME=$G/xdg_r
export MESA_SHADER_CACHE_DIR=$G/mesa
mkdir -p "$G/shots"
shot() {  # name, screen, args...
	local name=$1; shift
	local screen=$1; shift
	nice -n 10 xvfb-run -a -s "-screen 0 ${screen}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution ${screen} \
		-s "$G/scratch/render_debug.gd" -- --out="$G/shots/$name" "$@" 2>&1 | grep -E "CAMERA3D|ERROR"
}
shot s1_kh2 1280x720 --stage=kiel_hamburg --km=2
shot t1_kw46 1280x720 --stage=kassel_wuerzburg --km=46.5
shot t2_kw62 1280x720 --stage=kassel_wuerzburg --km=61.9
shot t3_sp172 1280x720 --stage=saragossa_pau --km=172.8
shot t4_sp198 1280x720 --stage=saragossa_pau --km=198.8 --threaded
shot t4_sp198_1610 1280x800 --stage=saragossa_pau --km=198.8
shot t4_sp198_219 1680x720 --stage=saragossa_pau --km=198.8
shot t4_sp198_hoch 1280x720 --stage=saragossa_pau --km=198.8 --details=1000 --top-size=3000
shot loop_ek87 1280x720 --stage=erfurt_kassel --km=86.9 --top-size=2400
echo done
