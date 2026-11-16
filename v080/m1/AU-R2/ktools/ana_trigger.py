#!/usr/bin/env python3
"""KRITIK-FAHRBAHN: analyse a trigger_log.gd log: feed state per second against the Track/plan truth."""
import json
import sys
from collections import Counter, defaultdict

path = sys.argv[1]
rows, evs, summary, result = [], [], None, None
for line in open(path, encoding="utf-8", errors="replace"):
    if line.startswith("ROW "):
        rows.append(json.loads(line[4:]))
    elif line.startswith("EV "):
        evs.append(json.loads(line[3:]))
    elif line.startswith("SUMMARY "):
        summary = json.loads(line[8:])
    elif line.startswith("ERGEBNIS "):
        result = json.loads(line[9:])

print(f"== {path}: {len(rows)} rows, {len(evs)} events printed")
if result:
    print(f"stage {result.get('stage_id')} time {result.get('time_s'):.0f} s avg {result.get('avg_speed_kmh'):.1f} km/h collisions {result.get('collisions')}")
if summary:
    print("counts", json.dumps(summary["counts"], sort_keys=True))
    print("bridges", summary["bridges"])
    zk = Counter(z["kind"] for z in summary["zones"])
    print("track zones", dict(zk))

valid = [r for r in rows if r["f"].get("valid")]
print(f"valid feed rows {len(valid)} / {len(rows)}")
# surfaces
sc = Counter()
for r in valid:
    sc[(r["f"]["surface_l"], r["f"]["surface_r"])] += 1
print("surfaces (l,r):", dict(sc.most_common()))
# paving by truth road / city / centre
pc = defaultdict(Counter)
for r in valid:
    t = r.get("truth", {})
    key = f"{t.get('road')}{'/centre' if t.get('center') else ''}{'/bridge:' + t['bridge'] if t.get('bridge') else ''}{'/tunnel' if t.get('tunnel') else ''}"
    pc[key][r["f"]["paving"]] += 1
for k, c in sorted(pc.items()):
    print(f"paving at {k:30s}: {dict(c)}")
# zones vs truth
zc = defaultdict(Counter)
for r in valid:
    t = r.get("truth", {})
    tz = "tunnel" if t.get("tunnel") else ("bridge" if t.get("bridge") else ("city" if t.get("city") else "other:" + str(t.get("scenery"))))
    zc[tz][r["f"]["zone"]] += 1
for k, c in sorted(zc.items()):
    print(f"zone at truth {k:34s}: {dict(c)}")
# mismatches
mm = Counter()
examples = defaultdict(list)
for r in valid:
    f, t, s = r["f"], r.get("truth", {}), r.get("seg", {})
    checks = {
        "tunnel": (f["tunnel"], t.get("tunnel")),
        "bridge": (f["bridge"] != "", t.get("bridge", "") != ""),
        "city": (f["city"], t.get("city")),
        "road": (f["road"], t.get("road")),
        "rumble_road": (f["rumble_road"], t.get("road") == "autobahn"),
    }
    for k, (a, b) in checks.items():
        if a != b:
            mm[k] += 1
            if len(examples[k]) < 4:
                examples[k].append((r["km"], a, b))
    if f["paving"] == "cobbles" and not (t.get("center") or t.get("bridge") == "stone_arch"):
        mm["cobbles_outside_centre"] += 1
        examples["cobbles_outside_centre"].append(r["km"])
    if f["zone"] == "cutting":
        mm["cutting_rows"] += 1
        if len(examples["cutting"]) < 8:
            examples["cutting"].append((r["km"], t.get("scenery")))
    if "rumble" in (f["surface_l"], f["surface_r"]):
        mm["rumble_rows"] += 1
        if len(examples["rumble"]) < 8:
            examples["rumble"].append((r["km"], r["x"], f["surface_l"], f["surface_r"], t.get("road")))
    if "shoulder" in (f["surface_l"], f["surface_r"]) or "grass" in (f["surface_l"], f["surface_r"]):
        mm["shoulder_rows"] += 1
        if len(examples["shoulder"]) < 8:
            examples["shoulder"].append((r["km"], r["x"], r["off"], f["surface_l"], f["surface_r"]))
    if f["cover"] != "":
        mm["cover_rows"] += 1
        if len(examples["cover"]) < 8:
            examples["cover"].append((r["km"], f["cover"], s.get("cover"), r.get("zone_border"), r.get("zone_fuel_canopy")))
print("mismatch / special counts:", dict(mm))
for k, v in examples.items():
    print(f"  {k}: {v}")
# speeds
vs = [r["v"] for r in valid]
if vs:
    import statistics
    print(f"speed median {statistics.median(vs):.0f} km/h, max {max(vs):.0f}")
# events
ec = Counter(e["name"] for e in evs)
print("events printed:", dict(ec))
br = summary["bridges"] if summary else []
joints = [e for e in evs if e["name"] == "joint"]
for b in br:
    js = [e for e in joints if b["z0"] - 0.01 <= e["z"] <= b["z1"] + 0.01]
    zs = [round(e["z"] - b["z0"], 1) for e in js]
    print(f"bridge {b['type']} z {b['z0']}..{b['z1']} ({b['z1'] - b['z0']:.0f} m): {len(js)} joints at +{zs}  decks {Counter(e.get('deck') for e in js)}")
stray = [e for e in joints if not any(b["z0"] - 0.01 <= e["z"] <= b["z1"] + 0.01 for b in br)]
print("joints off any bridge:", stray[:5], len(stray))
for nm in ("tunnel_in", "tunnel_out", "bridge_in", "bridge_out", "cover_in", "cover_out"):
    es = [e for e in evs if e["name"] == nm]
    if es:
        print(nm, [(e["km"], e.get("kind"), e.get("truth_tunnel"), e.get("truth_bridge")) for e in es][:12])
# pass objects by kind and side, in city or not
pk = Counter()
for e in evs:
    if e["name"] == "pass_object":
        pk[(e["kind"], "city" if e.get("truth_city") else "open", e.get("set", "")[:22])] += 1
print("pass objects (kind, where, set):")
for k, v in sorted(pk.items(), key=lambda kv: -kv[1])[:30]:
    print(f"   {v:4d}  {k}")
dist = [e["dist_m"] for e in evs if e["name"] == "pass_object" and e.get("side", 0) != 0]
if dist:
    dist.sort()
    print(f"pass distance (side objects): min {dist[0]:.1f} median {dist[len(dist)//2]:.1f} max {dist[-1]:.1f} m")
