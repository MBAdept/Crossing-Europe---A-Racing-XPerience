#!/usr/bin/env python3
"""KRITIK-R2-CODE: analysis of kc_trigger.gd output. python3 ana_trigger.py <log> <cfg.json> [out.json]"""
import json, sys
from collections import defaultdict

log, cfgp = sys.argv[1], sys.argv[2]
outp = sys.argv[3] if len(sys.argv) > 3 else None
cfg = json.load(open(cfgp))
feed = cfg["audio"]["modern"]["feed"]
styles = set(feed["cobble_styles"])
cshare = feed["concrete_share"]
plans, secs, done = [], [], None
for ln in open(log, encoding="utf-8", errors="replace"):
    if ln.startswith("PLAN "):
        plans.append(json.loads(ln[5:]))
    elif ln.startswith("SEC "):
        secs.append(json.loads(ln[4:]))
    elif ln.startswith("DONE "):
        done = json.loads(ln[5:])
res = {"plans": len(plans), "done": done}
# --- violations
tot = defaultdict(int)
ex = []
for p in plans:
    for k, v in p["viol"].items():
        tot[k] += v
    for e in p["ex"]:
        if len(ex) < 60:
            ex.append({"stage": p["stage"], "from": p["from"], **e})
res["violations"] = dict(tot)
res["violation_examples"] = ex
print("VIOLATIONS", dict(tot))
for e in ex[:25]:
    print("  ", e)
# --- joints
jbad, jcount, decks = [], 0, defaultdict(int)
per_bridge = defaultdict(dict)
for p in plans:
    for j in p["joints"]:
        jcount += 1
        decks[j["deck"]] += 1
        if not j["ok"]:
            jbad.append({"stage": p["stage"], "from": p["from"], **j})
        per_bridge[(p["stage"], j["name"])][p["from"]] = j
res["joints"] = {"bridges_driven": jcount, "by_deck": dict(decks), "mismatch": jbad}
print("JOINTS bridges driven", jcount, dict(decks), "mismatches", len(jbad))
for b in jbad[:10]:
    print("  ", b)
# both directions: physical positions of the intermediate joints
dir_diff = []
for (stage, name), d in per_bridge.items():
    if len(d) != 2:
        continue
    a, b = list(d.values())
    if a["deck"] == "stone":
        continue
    la, lb = a["len"], b["len"]
    pa = sorted(round(x, 0) for x in a["got"])
    pb = sorted(round(lb - x, 0) for x in b["got"])
    if pa != pb:
        dir_diff.append({"stage": stage, "bridge": name, "deck": a["deck"], "len": [la, lb], "fwd_m": pa, "rev_m_from_fwd_start": pb})
res["joints_direction_differs"] = dir_diff
print("JOINT POSITIONS differ between directions:", len(dir_diff), "of", sum(1 for d in per_bridge.values() if len(d) == 2))
for d in dir_diff[:6]:
    print("  ", d)
# --- old towns
rows = []
for p in plans:
    c = p["centre"]
    if c["centre_m"] <= 0:
        continue
    cob_style = p["style"] in styles
    st = c["street_m"]
    share_street = c["street_cob_m"] / st if st > 0 else None
    heard = (c["street_cob_m"] + c["stone_cob_m"]) / (st + c["stone_m"]) if (st + c["stone_m"]) > 0 else None
    whole = c["cob_m"] / c["centre_m"]
    keys = sorted(int(k) for k in p["pattern"].keys())
    pat = "".join("P" if p["pattern"][str(k)] else "-" for k in keys)
    rows.append({"stage": p["stage"], "from": p["from"], "to": p["to"], "style": p["style"], "cobble_style": cob_style,
                 "centre_m": c["centre_m"], "street_m": st, "stone_m": c["stone_m"], "nonstone_m": c["nonstone_m"],
                 "tunnel_m": c["tunnel_m"], "share_street": share_street, "share_heard": heard, "share_whole": whole,
                 "nonstone_cob_m": c["nonstone_cob_m"], "tunnel_cob_m": c["tunnel_cob_m"], "pattern": pat})
res["old_towns"] = rows
cs = [r for r in rows if r["cobble_style"]]
out_street = [r for r in cs if r["share_street"] is not None and abs(r["share_street"] - 0.6) > 0.05 + 1e-9]
out_heard = [r for r in cs if r["share_heard"] is not None and abs(r["share_heard"] - 0.6) > 0.05 + 1e-9]
non_style_cob = [r for r in rows if not r["cobble_style"] and r["share_street"] not in (None, 0.0)]
bridge_cob = [r for r in rows if r["nonstone_cob_m"] > 0 or r["tunnel_cob_m"] > 0]
print(f"OLD TOWNS arrivals {len(rows)} (cobble style {len(cs)}); street share out of 0.6±0.05: {len(out_street)}; "
      f"heard (stone bridge = cobbles) out: {len(out_heard)}; cobbles on non-stone bridge/tunnel: {len(bridge_cob)}; "
      f"cobbles in a style without: {len(non_style_cob)}")
for r in sorted(out_street, key=lambda r: r["share_street"]):
    print(f"   street {r['to']:16s} {r['share_street']:.3f} heard {r['share_heard']:.3f} stone {r['stone_m']:.0f} tunnel {r['tunnel_m']:.0f} non-stone {r['nonstone_m']:.0f} ({r['stage']} from {r['from']})")
for r in sorted(out_heard, key=lambda r: r["share_heard"]):
    if r in out_street:
        continue
    print(f"   heard  {r['to']:16s} street {r['share_street']:.3f} heard {r['share_heard']:.3f} stone {r['stone_m']:.0f} tunnel {r['tunnel_m']:.0f}")
res["old_out_street"] = [(r["to"], r["stage"], r["from"], round(r["share_street"], 3)) for r in out_street]
res["old_out_heard"] = [(r["to"], r["stage"], r["from"], round(r["share_heard"], 3)) for r in out_heard]
# patterns: the same city -> the same pattern at every arrival
pat_by_city = defaultdict(set)
for r in rows:
    pat_by_city[r["to"]].add(r["pattern"])
res["cities_with_varying_pattern"] = {k: sorted(v) for k, v in pat_by_city.items() if len(v) > 1}
print("cities with differing patterns between arrivals:", res["cities_with_varying_pattern"])
kh = [r for r in rows if r["to"] == "hamburg"]
for r in kh:
    print(f"   HAMBURG from {r['from']:12s} street {r['share_street']:.3f} pattern {r['pattern']} tunnel {r['tunnel_m']:.0f}")
# --- concrete per country (unique section keys, km-weighted)
by_c = defaultdict(lambda: [0, 0.0, 0.0])
dir_disagree = []
for s in secs:
    c = s["country"]
    by_c[c][0] += 1
    by_c[c][1] += s["km"]
    by_c[c][2] += s["km"] if s["dec"] else 0.0
    if len(set(s["decs"])) > 1:
        dir_disagree.append(s)
heard = defaultdict(lambda: [0.0, 0.0])
for p in plans:
    for c, v in p["conc_country"].items():
        heard[c][0] += v[0]
        heard[c][1] += v[1]
conc_rows = []
for c in sorted(by_c, key=lambda c: -by_c[c][1]):
    n, km, ckm = by_c[c]
    share = cshare.get(c, cshare.get("_", 0.0))
    got = ckm / km if km else 0.0
    h = heard[c][1] / heard[c][0] if heard[c][0] else 0.0
    judged = n >= 10
    conc_rows.append({"country": c, "sections": n, "km": round(km, 1), "share": share, "got": round(got, 3),
                      "heard": round(h, 3), "judged": judged, "ok": (abs(got - share) <= 0.05 + 1e-9) if judged else None})
res["concrete"] = conc_rows
res["concrete_direction_disagree"] = dir_disagree
print("CONCRETE per country (sections, km, share, got(km over keys), heard(metres driven both dirs), judged/ok):")
for r in conc_rows:
    print(f"   {r['country']:3s} {r['sections']:4d} {r['km']:8.1f} {r['share']:.2f} {r['got']:.3f} {r['heard']:.3f} "
          f"{'judged ' + ('OK' if r['ok'] else 'OUT') if r['judged'] else 'not judged'}")
print("section decisions differing between directions:", len(dir_disagree))
# --- fuel lanes
f_tot = defaultdict(int)
f_rows = []
for p in plans:
    for f in p["fuel"]:
        for k in ("rumble_with_lane", "with_lane", "rumble_before", "before"):
            f_tot[k] += f[k]
        f_rows.append({"stage": p["stage"], "from": p["from"], **f})
res["fuel"] = {"totals": dict(f_tot), "lanes": len(f_rows),
               "lanes_with_rumble": [r for r in f_rows if r["rumble_with_lane"] > 0],
               "autobahn_lanes_without_rumble_before": [r for r in f_rows if r["road"] == "autobahn" and r["rumble_before"] == 0]}
print("FUEL lanes", len(f_rows), dict(f_tot), "lanes with rumble:", len(res["fuel"]["lanes_with_rumble"]),
      "autobahn lanes without rumble before (probe sanity):", len(res["fuel"]["autobahn_lanes_without_rumble_before"]))
if outp:
    json.dump(res, open(outp, "w"), indent=1, ensure_ascii=False)
