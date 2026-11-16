#!/usr/bin/env python3
"""KRITIK-R (R2): effective concrete share per country and cobble share per city centre from kr_shares.gd logs,
before and after, against the configured values (concrete_share per country, "_" = others; cobble_share 0.6).
Each stage counted once (its first direction; the second direction is checked to be the mirror image: PAIR lines).
usage: ana_shares.py <before.log> <after.log> <out.json>"""
import json
import sys

K = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R"


def parse(path):
    conc, cobb, pairs = [], [], []
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("CONC "):
            conc.append(json.loads(line[5:]))
        elif line.startswith("COBB "):
            cobb.append(json.loads(line[5:]))
        elif line.startswith("PAIR "):
            pairs.append(json.loads(line[5:]))
    return conc, cobb, pairs


def agg(conc, cobb):
    first = {}
    for r in conc + cobb:
        first.setdefault(r["stage"], r["from"])
    by_c = {}
    for r in conc:
        if r["from"] != first[r["stage"]]:
            continue
        d = by_c.setdefault(r["country"], [0.0, 0.0, 0])
        d[0] += r["km"]
        d[1] += r["concrete_km"]
        d[2] += 1
    cities = {}
    for r in cobb:
        if not r["cobble_style"] or r["samples"] == 0:
            continue
        key = r["to"]
        cities.setdefault(key, []).append((r["stage"], r["from"], r["share"], r["centre_km"], r["blocks_from_centre_to_finish"]))
    return by_c, cities


def main():
    cfg = json.load(open(f"{K}/res/cfg_new.json"))
    share = cfg["audio"]["modern"]["feed"]["concrete_share"]
    cshare = float(cfg["audio"]["modern"]["feed"]["cobble_share"])
    out = {}
    for label, path in (("before", sys.argv[1]), ("after", sys.argv[2])):
        conc, cobb, pairs = parse(path)
        by_c, cities = agg(conc, cobb)
        rows = {}
        hit = 0
        tot_km = tot_conc = tot_target = 0.0
        for c in sorted(by_c, key=lambda c: -by_c[c][0]):
            km, ck, n = by_c[c]
            target = float(share.get(c, share.get("_", 0.0)))
            eff = ck / km if km > 0 else 0.0
            ok = abs(eff - target) <= 0.05
            hit += 1 if ok else 0
            tot_km += km
            tot_conc += ck
            tot_target += target * km
            rows[c] = {"km": round(km, 1), "concrete_km": round(ck, 1), "share": round(eff, 3), "target": target, "ok": ok, "stage_rows": n}
        crow = {}
        chit = 0
        allc = []
        for city, lst in sorted(cities.items()):
            shares = [s for _st, _fr, s, _c, _p in lst]
            eff = sum(shares) / len(shares)
            ok = all(abs(s - cshare) <= 0.05 for s in shares)
            chit += 1 if ok else 0
            allc.extend(shares)
            crow[city] = {"stages": len(lst), "share_mean": round(eff, 3), "share_min": min(shares), "share_max": max(shares), "ok": ok,
                          "pattern": lst[0][4], "all_or_nothing": all(s in (0.0, 1.0) for s in shares)}
        pmis = sum(1 for p in pairs if p["diff"] > 4)
        out[label] = {"countries": rows, "countries_ok": hit, "countries_n": len(rows),
                      "concrete_total": round(tot_conc / max(tot_km, 1e-9), 3), "concrete_target_total": round(tot_target / max(tot_km, 1e-9), 3),
                      "cities": crow, "cities_ok": chit, "cities_n": len(crow),
                      "cities_full": sum(1 for v in crow.values() if v["share_min"] >= 0.999),
                      "cities_none": sum(1 for v in crow.values() if v["share_max"] <= 0.001),
                      "cobble_mean": round(sum(allc) / max(len(allc), 1), 3), "pairs_mismatch": pmis, "pairs": len(pairs)}
        o = out[label]
        print(f"== {label}: Beton {o['countries_ok']}/{o['countries_n']} Länder in ±0,05, gesamt {o['concrete_total']} (Soll {o['concrete_target_total']}); "
              f"Pflaster {o['cities_ok']}/{o['cities_n']} Altstädte in ±0,05, ganz {o['cities_full']}, nie {o['cities_none']}, Mittel {o['cobble_mean']}; "
              f"Richtungen ungleich {pmis}/{len(pairs)}")
        for c, r in rows.items():
            print(f"   {c}: {r['km']:7.1f} km, Beton {r['share']:.3f} (Soll {r['target']}) {'ok' if r['ok'] else 'NEIN'}")
        lo = sorted(crow.items(), key=lambda kv: kv[1]["share_mean"])
        print("   Altstädte niedrigste:", [(k, v["share_mean"]) for k, v in lo[:4]], "höchste:", [(k, v["share_mean"]) for k, v in lo[-4:]])
        if "hamburg" in crow:
            print("   Hamburg:", crow["hamburg"])
    json.dump(out, open(sys.argv[3], "w"), indent=1)


if __name__ == "__main__":
    main()
