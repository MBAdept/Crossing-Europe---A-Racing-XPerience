#!/usr/bin/env python3
"""AU-R3: tables from enum_bridges.gd: every bridge touching an old-town centre (deduplicated per destination, with
the stages that arrive there), paving old -> new; the cobble share of every old town on its streets old -> new;
are all arrivals at a city the same? usage: ana_enum.py <enum.log> <out.json>"""
import json
import sys


def fmt_pv(d):
    return ", ".join(f"{k or '–'} {v:.0f}" for k, v in sorted(d.items(), key=lambda kv: -kv[1]))


def main():
    bridges, centres = [], []
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        if line.startswith("BRIDGE "):
            bridges.append(json.loads(line[7:]))
        elif line.startswith("CENTRE "):
            centres.append(json.loads(line[7:]))
    out = {"bridges": {}, "cities": {}, "notes": []}
    # bridges: one row per (destination, bridge), arrivals listed
    for b in bridges:
        key = f'{b["to"]}|{b["name"]}'
        row = out["bridges"].setdefault(key, {"to": b["to"], "name": b["name"], "type": b["type"], "deck": b["deck"],
                                              "style": b["style"], "cobble_style": b["cobble_style"], "arrivals": [], "variants": []})
        row["arrivals"].append(f'{b["stage"]} ab {b["from"]}')
        v = {"in_centre_m": b["in_centre_m"], "length_m": b["length_m"], "to_finish_m": b["to_finish_m"],
             "old": b["paving_old"], "new": b["paving_new"], "joints": [b["joints_old"], b["joints_new"]]}
        if v not in row["variants"]:
            row["variants"].append(v)
    # centres per city
    for c in centres:
        row = out["cities"].setdefault(c["to"], {"style": c["style"], "cobble_style": c["cobble_style"], "arrivals": [], "variants": []})
        row["arrivals"].append(f'{c["stage"]} ab {c["from"]}')
        v = {k: c[k] for k in ("centre_m", "street_m", "nonstone_m", "stone_m", "tunnel_m", "share_old", "share_new",
                               "street_cob_old", "street_cob_new", "bridge_cob_old", "bridge_cob_new", "stone_cob_new",
                               "pattern_old", "pattern_new", "changed", "diff_m", "surface_diff_m")}
        if v not in row["variants"]:
            row["variants"].append(v)
    # print: bridges with a non-stone deck inside a centre
    print("== Brücken ohne Steindeck in einer Altstadt (Ziel jeder Etappe, beide Richtungen)")
    n_ns = 0
    for key, r in sorted(out["bridges"].items()):
        if r["deck"] == "stone":
            continue
        for v in r["variants"]:
            if v["in_centre_m"] <= 0:
                continue
            n_ns += 1
            print(f'  {r["to"]:14s} {r["name"][:32]:32s} {r["type"]:12s} {r["deck"]:8s} Pflasterstil={"ja" if r["cobble_style"] else "nein"} '
                  f'{v["in_centre_m"]:4.0f} m in der Altstadt (von {v["length_m"]:.0f}), {v["to_finish_m"]} m vor dem Ziel | '
                  f'vorher {fmt_pv(v["old"])} -> nachher {fmt_pv(v["new"])} | Fugen {v["joints"][0]} -> {v["joints"][1]} | {len(r["arrivals"])} Ankunft(en)')
    print(f"  ({n_ns} Zeilen)")
    print("== Steinbrücken in einer Altstadt (unverändert Pflaster)")
    for key, r in sorted(out["bridges"].items()):
        if r["deck"] != "stone":
            continue
        for v in r["variants"]:
            if v["in_centre_m"] <= 0:
                continue
            print(f'  {r["to"]:14s} {r["name"][:32]:32s} {v["in_centre_m"]:4.0f} m | vorher {fmt_pv(v["old"])} -> nachher {fmt_pv(v["new"])} | Fugen {v["joints"]}')
    print("== Altstädte mit Pflasterstil: Anteil auf den Straßen vorher -> nachher")
    lo, hi, inside = [], [], 0
    nvar = 0
    for city, r in sorted(out["cities"].items()):
        if not r["cobble_style"]:
            continue
        if len(r["variants"]) > 1:
            out["notes"].append(f"{city}: {len(r['variants'])} verschiedene Ankünfte")
        for v in r["variants"]:
            nvar += 1
            flag = ""
            if v["share_new"] < 0.55:
                lo.append(city)
                flag = "  <0,55"
            elif v["share_new"] > 0.65:
                hi.append(city)
                flag = "  >0,65"
            else:
                inside += 1
            print(f'  {city:14s} Altstadt {v["centre_m"]:5.0f} m, Straßen {v["street_m"]:5.0f} m, Brücken o. Stein {v["nonstone_m"]:4.0f} m, '
                  f'Stein {v["stone_m"]:4.0f} m, Tunnel {v["tunnel_m"]:4.0f} m | Straßen {v["share_old"]:.3f} -> {v["share_new"]:.3f} | '
                  f'Pflaster auf Brücken {v["bridge_cob_old"]:.0f} -> {v["bridge_cob_new"]:.0f} m | {v["pattern_old"]} -> {v["pattern_new"]}'
                  f'{" GEÄNDERT" if v["changed"] else ""}{flag} | {len(r["arrivals"])} Ankunft(en)')
    print(f"  Altstädte (Varianten) {nvar}: in 0,6 ± 0,05: {inside}; unter 0,55: {lo}; über 0,65: {hi}")
    olds = [v["share_old"] for r in out["cities"].values() if r["cobble_style"] for v in r["variants"]]
    news = [v["share_new"] for r in out["cities"].values() if r["cobble_style"] for v in r["variants"]]
    print(f"  Mittel vorher {sum(olds)/len(olds):.3f}, nachher {sum(news)/len(news):.3f}; vorher außerhalb ±0,05: "
          f"{sum(1 for s in olds if abs(s-0.6) > 0.05 + 1e-9)}, nachher {sum(1 for s in news if abs(s-0.6) > 0.05 + 1e-9)}")
    ch = [c for c in out["cities"] if any(v["changed"] for v in out["cities"][c]["variants"])]
    print("  geändert:", len(ch), sorted(ch))
    sd = [c for c in out["cities"] if any(v["surface_diff_m"] != v["diff_m"] for v in out["cities"][c]["variants"])]
    print("  Radflächen anders als Belag:", sd)
    print("  Hinweise:", out["notes"])
    json.dump(out, open(sys.argv[2], "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
