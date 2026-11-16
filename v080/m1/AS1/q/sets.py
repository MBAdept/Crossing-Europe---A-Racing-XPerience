import json
import sys

W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1"
m = json.load(open(W + "/assets/sprites/manifest.json"))
keys = sys.argv[1:] or ["truck", "player/", "showroom/", "sedan", "hatch", "wagon"]
for k, v in m["sets"].items():
    if any(x in k for x in keys):
        vv = {kk: vvv for kk, vvv in v.items() if kk not in ("angles",)}
        print(k, json.dumps(vv)[:1200])
        print()
