import json, sys, collections
root = sys.argv[1]
n = json.load(open(root + "/data/network.json"))
stages = n["stages"]
print("stages", type(stages), len(stages))
it = stages.items() if isinstance(stages, dict) else enumerate(stages)
cnt = 0
keys = collections.Counter()
lens = []
for sid, st in it:
    for t in st.get("tunnels", []):
        cnt += 1
        for k in t.keys():
            keys[k] += 1
        lens.append((t.get("length_km", t.get("length", None)), sid, t))
print("tunnels", cnt, dict(keys))
lens.sort(key=lambda x: float(x[0] or 0))
for l in lens[:8]:
    print("short", l)
for l in lens[-8:]:
    print("long", l)
# a sample stage keys
s0 = list(stages.values())[0] if isinstance(stages, dict) else stages[0]
print("stage keys", list(s0.keys()))
