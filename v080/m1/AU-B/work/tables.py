"""Scratch (AU-B): markdown tables for the docs and the report from the final measurements.
    python3 tables.py <steady-dir> <cruise.json> <ab_zahlen.json>"""
import json
import sys

CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
DE = {"kompakt": "Kompakt", "kombi": "Kombi", "limousine": "Limousine", "sportwagen": "Sportwagen", "gran_turismo": "Gran Turismo"}


def de(x, nd=1):
    s = ("%." + str(nd) + "f") % x
    return s.replace("-", "−").replace(".", ",")


def main():
    sdir, cruise, ab = sys.argv[1], sys.argv[2], sys.argv[3]
    print("#### Volllast: Schwerpunkt, Harmonische-zu-Rauschen, Bewegung (Arcade → Modern)\n")
    print("| Auto | Drehzahl | Spektraler Schwerpunkt Hz | HNR dB | Pegelbewegung dB (50 ms) | Anteil ab 1 kHz dB | Kanalkorrelation Modern (ganz / ab 1 kHz) |")
    print("|---|---|---|---|---|---|---|")
    for car in CARS:
        d = json.load(open(f"{sdir}/steady_{car}.json", encoding="utf-8"))
        a = [r for r in d["arcade"] if r["load"] == 1.0]
        m = [r for r in d["modern"] if r["load"] == 1.0]
        for i in (1, 3, 5, 6):
            ra, rm = a[i], m[i]
            # share above 1 kHz from the octave bands 1k..8k (indices 4..7 of 63..8000)
            import math
            sa = 10 * math.log10(sum(10 ** (v / 10) for v in ra["oct"][4:]))
            sm = 10 * math.log10(sum(10 ** (v / 10) for v in rm["oct"][4:]))
            print("| %s | %d | %d → %d | %s → %s | %s → %s | %s → %s | %s / %s |" % (
                DE[car] if i == 1 else "", ra["rpm"], ra["centroid"], rm["centroid"], de(ra["hnr"]), de(rm["hnr"]), de(ra["mod_std"], 2), de(rm["mod_std"], 2),
                de(sa), de(sm), de(rm["corr"], 2), de(rm["corr_hf"], 2)))
    print("\n#### Teillast 22 % und Schub: Schwerpunkt und HNR (Arcade → Modern)\n")
    print("| Auto | Drehzahl | Teillast: Schwerpunkt Hz | Teillast: HNR dB | Schub: Schwerpunkt Hz | Schub: HNR dB |")
    print("|---|---|---|---|---|---|")
    for car in CARS:
        d = json.load(open(f"{sdir}/steady_{car}.json", encoding="utf-8"))
        for i in (1, 3, 5):
            pa = [r for r in d["arcade"] if abs(r["load"] - 0.22) < 1e-6][i]
            pm = [r for r in d["modern"] if abs(r["load"] - 0.22) < 1e-6][i]
            oa = [r for r in d["arcade"] if r["load"] == 0.0][i]
            om = [r for r in d["modern"] if r["load"] == 0.0][i]
            print("| %s | %d | %d → %d | %s → %s | %d → %d | %s → %s |" % (DE[car] if i == 1 else "", pa["rpm"], pa["centroid"], pm["centroid"],
                  de(pa["hnr"]), de(pm["hnr"]), oa["centroid"], om["centroid"], de(oa["hnr"]), de(om["hnr"])))
    print("\n#### Kleine Lautsprecher: Lautheitsverlust mit Hochpass 180 Hz (Volllast, Arcade → Modern)\n")
    print("| Auto | " + " | ".join("%d %%" % p for p in (20, 30, 40, 55, 70, 85, 95)) + " |")
    print("|---|---|---|---|---|---|---|---|")
    for car in CARS:
        d = json.load(open(f"{sdir}/steady_{car}.json", encoding="utf-8"))
        a = [r for r in d["arcade"] if r["load"] == 1.0]
        m = [r for r in d["modern"] if r["load"] == 1.0]
        print("| %s | " % DE[car] + " | ".join("%s → %s" % (de(x["hp180"]), de(y["hp180"])) for x, y in zip(a, m)) + " |")
    c = json.load(open(cruise, encoding="utf-8"))
    print("\n#### Eine Minute konstantes Tempo (Arcade → Modern)\n")
    print("| Auto | Tempo | Pegel 50 ms (Std, dB) | Pegel 1 s (Std, dB) | Spektrum (Std je Terz, dB) | Wiederholung (AKF 0,2–10 s) | lauteste Terz über dem Median, A-bewertet (dB) |")
    print("|---|---|---|---|---|---|---|")
    for car in CARS:
        for ph in ("cruise_130", "cruise_200"):
            a, m = c[car]["arcade"][ph], c[car]["modern"][ph]
            print("| %s | %d km/h | %s → %s | %s → %s | %s → %s | %s → %s | %s → %s (%d Hz) |" % (
                DE[car] if ph == "cruise_130" else "", round(a["speed"]), de(a["mod50_std"], 2), de(m["mod50_std"], 2), de(a["mod1s_std"], 2), de(m["mod1s_std"], 2),
                de(a["spectrum_move_db"], 2), de(m["spectrum_move_db"], 2), de(a["repeat_ac"], 2), de(m["repeat_ac"], 2),
                de(a["dominance_a_db"]), de(m["dominance_a_db"]), m["dominant_band_a_hz"]))
    z = json.load(open(ab, encoding="utf-8"))
    print("\n#### Fahrt im Spiel, nur der Motor (Arcade | Modern)\n")
    print("| Auto | ganze Fahrt LUFS | Lautheitsbereich LU | True Peak dBTP | Vollgas durch die Gänge LUFS | 200 km/h | Gas weg | 130 km/h | Leerlauf |")
    print("|---|---|---|---|---|---|---|---|---|")
    for car in CARS:
        a, m = z[car]["arcade"], z[car]["modern"]

        def p(name):
            return "%s \\| %s" % (de(a["phases"][name]["lufs"]) if name in a["phases"] else "–", de(m["phases"][name]["lufs"]) if name in m["phases"] else "–")
        print("| %s | %s \\| %s | %s \\| %s | %s \\| %s | %s | %s | %s | %s | %s |" % (
            DE[car], de(a["integrated_lufs"]), de(m["integrated_lufs"]), de(a["lra"]), de(m["lra"]), de(a["true_peak_db"]), de(m["true_peak_db"]),
            p("pull"), p("cruise_hi"), p("lift"), p("cruise_130"), p("idle")))
    print("\n#### Fahrt im Spiel: Stereo und Spektrum je Abschnitt (Modern; Arcade in Klammern)\n")
    print("| Auto | Abschnitt | Kanalkorrelation | Monosumme unter dem lauteren Kanal dB | Schwerpunkt Hz | Anteil ab 2 kHz dB | Anteil ab 5 kHz dB |")
    print("|---|---|---|---|---|---|---|")
    for car in CARS:
        a, m = z[car]["arcade"], z[car]["modern"]
        for k, name in enumerate(("pull", "cruise_hi", "lift", "cruise_130")):
            if name not in m["phases"]:
                continue
            pa, pm = a["phases"][name], m["phases"][name]
            print("| %s | %s | %s (%s) | %s (%s) | %d (%d) | %s (%s) | %s (%s) |" % (DE[car] if k == 0 else "", {"pull": "Vollgas", "cruise_hi": "200 km/h", "lift": "Gas weg", "cruise_130": "130 km/h"}[name],
                  de(pm["corr"], 2), de(pa["corr"], 2), de(pm["mono_db"], 2), de(pa["mono_db"], 2), pm["centroid_hz"], pa["centroid_hz"],
                  de(pm["share_2k_db"]), de(pa["share_2k_db"]), de(pm["share_5k_db"]), de(pa["share_5k_db"])))
    print("\nMischzeit im Spiel (ms je 1/60 s Klang): " + ", ".join("%s %s" % (DE[c_], de(z[c_]["modern"]["engine_perf"].get("ms_per_frame", 0.0), 2)) for c_ in CARS))
    print("Aussetzer: " + ", ".join("%s %s" % (DE[c_], z[c_]["modern"]["engine_perf"].get("skips", "?")) for c_ in CARS))


if __name__ == "__main__":
    main()
