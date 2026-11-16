#!/bin/bash
# Calibrate the masks of the UI list: vehicle / start_time arrows (wall clock), title version label at 1280x800.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
OUT=$S/calib
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/mesa_ui
mkdir -p "$MESA_SHADER_CACHE_DIR"
cd "$WT" || exit 1
shot() { # name res screen n
	local name=$1 res=$2 sc=$3 n=$4
	local X=$S/xdg_calib
	rm -rf "$X"; mkdir -p "$X"
	t0=$SECONDS
	XDG_DATA_HOME=$X nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 ${res}x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$res" --fixed-fps 60 -- --screen=$sc --screenshot="$OUT/${name}_$n" --shot-times=1.5 \
		--graphics=arcade > "$OUT/${name}_$n.log" 2>&1
	echo "$name $n exit=$? $((SECONDS - t0)) s $(md5sum < "$OUT/${name}_${n}_00.png" | cut -c1-8)"
}
for n in a b c; do
	shot vehicle 1280x720 vehicle $n
	shot start_time 1280x720 start_time $n
done
shot title800 1280x800 title a
shot title720 1280x720 title a
python3 - "$OUT" <<'EOF'
import sys, os
import numpy as np
from PIL import Image
d = sys.argv[1]
for name in ("vehicle", "start_time"):
    ims = [np.asarray(Image.open(os.path.join(d, "%s_%s_00.png" % (name, n))).convert("RGB")).astype(int) for n in "abc"]
    diff = np.zeros(ims[0].shape[:2], bool)
    for i in range(3):
        for j in range(i + 1, 3):
            diff |= (np.abs(ims[i] - ims[j]).max(axis=2) > 0)
    ys, xs = np.nonzero(diff)
    print(name, "pixels different:", int(diff.sum()))
    if len(xs):
        # split left / right half
        for side, sel in (("links", xs < 640), ("rechts", xs >= 640)):
            if sel.any():
                print("  %s: x %d..%d  y %d..%d" % (side, xs[sel].min(), xs[sel].max(), ys[sel].min(), ys[sel].max()))
EOF
