#!/bin/bash
# note 11: re-render one city sprite sheet (sprite path, final quality) in a scratch copy of tools/blender, compare with
# the committed PNG byte for byte and by pixels; 20-minute cap
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_a71eeb2e-3b7-1
C=$S/sprite_check
SET=${1:-props/city_hanse_gabled}
mkdir -p $C/out
cd $C || exit 2
export XDG_DATA_HOME=$S/xdg/sprite
export CE_THREADS=3
t0=$SECONDS
nice -n 10 timeout 1200 /home/user/tools/bpyenv/bin/python tools/blender/render_all.py --only $SET --force --out $C/out
echo "render exit $? $((SECONDS - t0)) s"
f=$(basename $SET).png
ls -la $C/out/props/$f $W/assets/sprites/props/$f
cmp $C/out/props/$f $W/assets/sprites/props/$f && echo "CMP byte-gleich" || echo "CMP verschieden"
python3 - $C/out/props/$f $W/assets/sprites/props/$f <<'PY'
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGBA')).astype(int)
b = np.asarray(Image.open(sys.argv[2]).convert('RGBA')).astype(int)
if a.shape != b.shape:
    print('PIXEL Größe verschieden', a.shape, b.shape)
else:
    d = np.abs(a - b)
    print('PIXEL max diff %d, Pixel mit diff > 2: %d von %d' % (d.max(), int((d.max(axis=2) > 2).sum()), d.shape[0] * d.shape[1]))
PY
