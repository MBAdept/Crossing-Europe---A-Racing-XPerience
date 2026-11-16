"""AS3 scratch: stages whose sections use the sceneries of the nature sets (km ranges per scenery)."""
import json

net = json.load(open("/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-1/data/network.json"))
want = {"mediterranean", "pyrenees", "alps", "heath", "coast", "lombardy", "karst", "meseta"}
for s in net["stages"]:
    km = 0
    hits = []
    for sec in s["sections"]:
        if sec.get("scenery") in want:
            hits.append("%s@%d-%d(%s)" % (sec["scenery"], km, km + sec["length_km"], sec.get("road")))
        km += sec["length_km"]
    if hits:
        print("%-28s %s->%s %d km: %s" % (s["id"], s["from"], s["to"], s["length_km"], ", ".join(hits)))
