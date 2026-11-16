"""AS2a: which car sets of the manifest resolve to a model (and their showroom flags)."""
import json

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1"
m = json.load(open(WT + "/assets/models/manifest.json"))
sets = m["sets"]
car = sorted(k for k in sets if k.startswith("traffic/") and not k.startswith(("traffic/truck", "traffic/bus")))
with_model = [k for k in car if sets[k].get("model")]
print("traffic car sets: %d, with a model: %d" % (len(car), len(with_model)))
print("  without:", [k for k in car if not sets[k].get("model")])
pl = sorted(k for k in sets if k.startswith("player/"))
print("player sets: %d, with a model: %d" % (len(pl), sum(1 for k in pl if sets[k].get("model"))))
for k in pl + sorted(k for k in sets if k.startswith("showroom/")):
    e = sets[k]
    print("  %-28s model %-22s lod %-5s showroom %s" % (k, e.get("model"), e.get("lod", "-"), e.get("showroom")))
