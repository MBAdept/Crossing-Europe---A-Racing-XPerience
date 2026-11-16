import json, sys
W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2/"
m = json.load(open(W + "assets/sprites/manifest.json"))
print("keys", list(m.keys()), "sets", len(m["sets"]))
groups = {}
for k in m["sets"]:
    groups[k.split("/")[0]] = groups.get(k.split("/")[0], 0) + 1
print(groups)
for k in sys.argv[1:]:
    s = m["sets"].get(k)
    if s is None:
        print(k, None)
        continue
    print(k, json.dumps({kk: v for kk, v in s.items() if kk not in ("frames", "layers", "angles", "yaw_deg")})[:900])
