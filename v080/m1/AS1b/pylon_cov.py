import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2/tools/blender")
from ce3d import leafatlas as LA  # noqa: E402

im = Image.open("/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2/assets/models/props/power_pylon/albedo.png")
a = np.array(im)
# without halo: alpha binarised at 0.5
base = a.copy()
base[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
b = Image.fromarray(base, "RGBA")
print("ohne Halo     ", LA.coverage(b, 7, scissor=0.5))
for px in (2, 3, 4):
    h = LA.halo(b, alpha=0.33, px=px, scissor=0.5)
    print("Halo %d px     " % px, LA.coverage(h, 7, scissor=0.5))
