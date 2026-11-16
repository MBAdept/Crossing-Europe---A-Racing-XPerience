import json, sys
W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2/"
m = json.load(open(W + "assets/models/manifest.json"))
args = sys.argv[1:]
for k in args:
    if k in m["sets"]:
        print("SET", k, json.dumps(m["sets"][k]))
    if k in m["models"]:
        e = m["models"][k]
        print("MODEL", k, json.dumps({kk: v for kk, v in e.items() if kk not in ("lods", "lights")}))
        for l in e.get("lods", []):
            print("   lod", json.dumps(l))
        for l in e.get("lights", []):
            print("   light", json.dumps(l))
