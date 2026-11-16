# Debug: outline loops of a police word
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy  # noqa
from ce3d import police3d as P
from cesprites import catalog, designs
from cesprites import rig as RG

word = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "POLIZEI"
rig = RG.Rig(quick=True)
pol = P._Police("de", catalog.POLICE["de"], designs.TRAFFIC_MODELS["wagon"])
loops = pol._glyphs(rig, word, 0.16)
for lp, hole in loops:
    print("hole" if hole else "outer", len(lp), "x %.3f..%.3f y %.3f..%.3f" % (lp[:, 0].min(), lp[:, 0].max(), lp[:, 1].min(), lp[:, 1].max()))
