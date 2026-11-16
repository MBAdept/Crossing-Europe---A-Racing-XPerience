#!/usr/bin/env python3
"""AU-R3: markdown tables from res/enum.json for the report and the docs.
  1. every bridge without a stone deck inside an old-town centre (one row per city and bridge; metres and paving of
     the first arrival, the number of arrivals, and the spread of the metres over the arrivals),
  2. every old town of a cobble style: share on its streets before -> after,
  3. stone bridges in old towns (unchanged)."""
import json
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3"
NAMES = {"cobbles": "Pflaster", "asphalt": "Asphalt", "deck": "Stahldeck", "concrete": "Beton"}
CITY = {"amsterdam": "Amsterdam", "belgrad": "Belgrad", "bern": "Bern", "bremen": "Bremen", "bruessel": "Brüssel",
        "budapest": "Budapest", "bukarest": "Bukarest", "calais": "Calais", "frankfurt": "Frankfurt", "fulda": "Fulda",
        "hannover": "Hannover", "kassel": "Kassel", "kaunas": "Kaunas", "kiel": "Kiel", "koeln": "Köln", "linz": "Linz",
        "lyon": "Lyon", "magdeburg": "Magdeburg", "montpellier": "Montpellier", "nuernberg": "Nürnberg", "passau": "Passau",
        "pau": "Pau", "posen": "Posen", "regensburg": "Regensburg", "riga": "Riga", "sibiu": "Sibiu",
        "slavonski_brod": "Slavonski Brod", "timisoara": "Timişoara", "venedig": "Venedig", "wien": "Wien",
        "barcelona": "Barcelona", "bialystok": "Białystok", "bordeaux": "Bordeaux", "burgos": "Burgos", "dresden": "Dresden",
        "erfurt": "Erfurt", "hamburg": "Hamburg", "ljubljana": "Ljubljana", "luettich": "Lüttich", "madrid": "Madrid",
        "mailand": "Mailand", "muenchen": "München", "paris": "Paris", "prag": "Prag", "rostock": "Rostock",
        "san_sebastian": "San Sebastián", "saragossa": "Saragossa", "sofia": "Sofia", "toulouse": "Toulouse", "tours": "Tours",
        "warschau": "Warschau", "wuerzburg": "Würzburg", "berlin": "Berlin"}


def pv(d):
    parts = [f"{NAMES.get(k, k or '–')} {v:.0f}" for k, v in sorted(d.items(), key=lambda kv: -kv[1])]
    return ", ".join(parts)


def main():
    data = json.load(open(f"{S}/res/enum.json"))
    out = []
    out.append("| Altstadt | Brücke | Typ, Deck | Meter in der Altstadt | vorher (m) | nachher (m) | Fugen vorher → nachher | Ankünfte |")
    out.append("|---|---|---|---|---|---|---|---|")
    n_rows = 0
    for key, r in sorted(data["bridges"].items(), key=lambda kv: (CITY.get(kv[1]["to"], kv[1]["to"]), kv[1]["name"])):
        if r["deck"] == "stone":
            continue
        vs = [v for v in r["variants"] if v["in_centre_m"] > 0]
        if not vs:
            continue
        n_rows += 1
        v = vs[0]
        ms = sorted({round(x["in_centre_m"]) for x in vs})
        mtxt = f"{ms[0]}" if len(ms) == 1 else f"{ms[0]}–{ms[-1]}"
        if v["in_centre_m"] < v["length_m"] - 0.5:
            mtxt += f" (von {v['length_m']:.0f})"
        style = "" if r["cobble_style"] else " ¹"
        joints = sorted({tuple(x["joints"]) for x in vs})
        jtxt = ", ".join(f"{a} → {b}" for a, b in joints)
        out.append(f"| {CITY.get(r['to'], r['to'])}{style} | {r['name']} | {r['type']}, {r['deck']} | {mtxt} | {pv(v['old'])} | "
                   f"{pv(v['new'])} | {jtxt} | {len(set(r['arrivals']))} |")
    out.append("")
    out.append(f"({n_rows} Brücken; ¹ Baustil ohne Altstadtpflaster – dort war und bleibt alles Asphalt bzw. Stahldeck.)")
    out.append("")
    out.append("| Altstadt | geändert | Straßen (m) von Altstadt (m) | Brücken o. Steindeck / Stein / Tunnel (m) | Straßenanteil vorher → nachher | Pflaster auf Brücken o. Steindeck vorher → nachher (m) | Blöcke vorher → nachher (Block 0 am Ziel) | Ankünfte |")
    out.append("|---|---|---|---|---|---|---|---|")

    def rng(vals, fmt):
        lo, hi = min(vals), max(vals)
        txt = fmt % lo if abs(hi - lo) < 1e-9 else (fmt % lo) + "–" + (fmt % hi)
        return txt.replace(".", ",")     # German decimal comma

    for city, r in sorted(data["cities"].items(), key=lambda kv: CITY.get(kv[0], kv[0])):
        if not r["cobble_style"]:
            continue
        vs = r["variants"]
        tun = [v for v in vs if v["tunnel_m"] > 0]
        plain = [v for v in vs if v["tunnel_m"] <= 0] or vs
        groups = [plain] + ([tun] if tun and plain is not vs else [])
        for gi, g in enumerate(groups):
            so = [v["share_old"] for v in g]
            sn = [v["share_new"] for v in g]
            flag = " **außerhalb**" if (min(sn) < 0.55 - 1e-9 or max(sn) > 0.65 + 1e-9) else ""
            name = CITY.get(city, city) + (" (Ankunft mit Tunnel)" if gi == 1 else "")
            pats = sorted({(v["pattern_old"], v["pattern_new"]) for v in g})
            ptxt = "; ".join(f"`{a}` → `{b}`" for a, b in pats)
            out.append(f"| {name} | {'ja' if any(v['changed'] for v in g) else '–'} | {rng([v['street_m'] for v in g], '%.0f')} von "
                       f"{rng([v['centre_m'] for v in g], '%.0f')} | {rng([v['nonstone_m'] for v in g], '%.0f')} / "
                       f"{rng([v['stone_m'] for v in g], '%.0f')} / {rng([v['tunnel_m'] for v in g], '%.0f')} | "
                       f"{rng(so, '%.3f')} → {rng(sn, '%.3f')}{flag} | {rng([v['bridge_cob_old'] for v in g], '%.0f')} → "
                       f"{rng([v['bridge_cob_new'] for v in g], '%.0f')} | {ptxt} | {len(set(r['arrivals']))} |")
    open(f"{S}/res/tables.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("\n".join(out[:4]))
    print("...", len(out), "Zeilen ->", f"{S}/res/tables.md")


if __name__ == "__main__":
    main()
