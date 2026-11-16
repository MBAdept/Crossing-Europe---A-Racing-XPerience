import json
import sys

R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3"
d = json.load(open(R + "/data/network.json"))
want = sys.argv[1] if len(sys.argv) > 1 else "dev_testetappe"


def find(o):
    if isinstance(o, dict):
        if o.get("id") == want:
            return o
        for v in o.values():
            r = find(v)
            if r:
                return r
    elif isinstance(o, list):
        for v in o:
            r = find(v)
            if r:
                return r
    return None


s = find(d)
for k, v in s.items():
    if k != "sections":
        print(k, json.dumps(v, ensure_ascii=False)[:300])
km = 0
for sec in s["sections"]:
    print(" ", km, "->", km + sec["length_km"], {k: v for k, v in sec.items() if k != "length_km"})
    km += sec["length_km"]
