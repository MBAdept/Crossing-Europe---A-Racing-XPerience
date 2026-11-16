"""Scratch (AU-B): constant motorway speed for a minute - does the engine sound stand still? Offline renders of the
mixers (Arcade engine, Modern engine v3), 60 s at 130 km/h and 60 s at 200 km/h per car.
    python3 e3cruise.py <out-dir> [car ...]
Numbers per phase: movement of the level (std of the 50-ms and of the 1-s level), movement of the spectrum (mean std
over time of the 1/3-octave levels in 250-ms frames, bands within 30 dB of the loudest), dominance of the loudest
1/3-octave band over the median of the others, repetition (highest normalised autocorrelation of the 50-ms level
series at lags of 0.2 .. 10 s - a loop would show up as a peak near 1)."""
from __future__ import annotations
import json, math, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import e3an  # noqa: E402
from e3an import qc_lib  # noqa: E402

CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]


def render(car, profile, out):
    env = dict(os.environ, XDG_DATA_HOME=os.path.abspath(os.path.join(HERE, "..", "xdg")))
    cmd = ["godot", "--headless", "--path", e3an.REPO, "-s", os.path.join(HERE, "e3render.gd"), "--", f"--car={car}", f"--profile={profile}",
           "--scenario=cruise", "--no-start-clip", f"--out={out}"]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0 or "FEHLER" in r.stdout:
        print(r.stdout[-1500:], r.stderr[-1500:])
        raise SystemExit("Render fehlgeschlagen")


def numbers(seg, sr):
    xk = qc_lib.k_weight(seg, sr)
    n = int(0.05 * sr)
    lv = np.array([10 * math.log10(max(float(np.mean(np.sum(xk[a:a + n] ** 2, axis=1))), 1e-20)) for a in range(0, len(xk) - n, n)])
    n1 = sr
    lv1 = np.array([10 * math.log10(max(float(np.mean(np.sum(xk[a:a + n1] ** 2, axis=1))), 1e-20)) for a in range(0, len(xk) - n1, n1)])
    fc, bands = e3an.band_levels(seg, sr, 0.25)
    mean_b = bands.mean(axis=0)
    sel = mean_b > mean_b.max() - 30.0
    spec_move = float(np.mean(bands[:, sel].std(axis=0)))
    top = int(np.argmax(mean_b))
    others = np.delete(mean_b[sel], np.where(np.where(sel)[0] == top)[0])
    dom = float(mean_b[top] - np.median(others)) if len(others) else 0.0
    z = lv - lv.mean()
    ac = np.correlate(z, z, "full")[len(z) - 1:]
    ac = ac / max(ac[0], 1e-12)
    rep = float(np.max(ac[60:200])) if len(ac) > 200 else 0.0      # lags of 3 .. 10 s (beyond the slow movement)
    # the same dominance with A-weighted band levels (what the ear makes of the low fundamental)
    aw = 20.0 * np.log10(12194.0 ** 2 * fc ** 4 / ((fc ** 2 + 20.6 ** 2) * np.sqrt((fc ** 2 + 107.7 ** 2) * (fc ** 2 + 737.9 ** 2)) * (fc ** 2 + 12194.0 ** 2))) + 2.0
    mean_a = mean_b + aw
    sel_a = mean_a > mean_a.max() - 30.0
    top_a = int(np.argmax(mean_a))
    others_a = np.delete(mean_a[sel_a], np.where(np.where(sel_a)[0] == top_a)[0])
    dom_a = float(mean_a[top_a] - np.median(others_a)) if len(others_a) else 0.0
    return {"lufs": round(e3an.lufs(seg, sr), 2), "mod50_std": round(float(lv.std()), 2), "mod1s_std": round(float(lv1.std()), 2),
            "mod50_range": round(float(np.percentile(lv, 95) - np.percentile(lv, 5)), 2), "spectrum_move_db": round(spec_move, 2),
            "dominant_band_hz": round(float(fc[top])), "dominance_db": round(dom, 1), "repeat_ac": round(rep, 2),
            "bands_within_30db": int(sel.sum()), "dominance_a_db": round(dom_a, 1), "dominant_band_a_hz": round(float(fc[top_a])),
            "bands_within_30db_a": int(sel_a.sum())}


def main():
    out_dir = sys.argv[1]
    cars = sys.argv[2:] or CARS
    os.makedirs(out_dir, exist_ok=True)
    res = {}
    print("Auto          Tempo | LUFS alt/neu  | Pegel 50 ms (Std) | Pegel 1 s (Std) | Spektrum (Std je Terz) | lauteste Terz über Median | Wiederholung (AKF)")
    for car in cars:
        res[car] = {}
        for prof in ("arcade", "modern"):
            wav = os.path.join(out_dir, f"cruise_{car}_{prof}.wav")
            render(car, prof, wav)
            x, sr, tr = e3an.read(wav)
            res[car][prof] = {}
            for ph in tr["phases"]:
                if ph["name"].startswith("cruise"):
                    a, b = int((ph["t0"] + 2.0) * sr), int(ph["t1"] * sr)
                    res[car][prof][ph["name"]] = numbers(x[a:b], sr)
                    res[car][prof][ph["name"]]["speed"] = ph["v0"]
            if not (car == "gran_turismo"):
                os.remove(wav)
                os.remove(wav + ".json")
        for name in ("cruise_130", "cruise_200"):
            a, m = res[car]["arcade"][name], res[car]["modern"][name]
            print("%-12s %4.0f  | %6.1f %6.1f | %5.2f  %5.2f      | %5.2f  %5.2f    | %5.2f  %5.2f           | %5.1f  %5.1f (%d/%d Hz), A-bew. %5.1f %5.1f (%d/%d Hz, Terzen in 30 dB %d/%d) | %4.2f  %4.2f" % (
                car, a["speed"], a["lufs"], m["lufs"], a["mod50_std"], m["mod50_std"], a["mod1s_std"], m["mod1s_std"], a["spectrum_move_db"],
                m["spectrum_move_db"], a["dominance_db"], m["dominance_db"], a["dominant_band_hz"], m["dominant_band_hz"],
                a["dominance_a_db"], m["dominance_a_db"], a["dominant_band_a_hz"], m["dominant_band_a_hz"], a["bands_within_30db_a"], m["bands_within_30db_a"],
                a["repeat_ac"], m["repeat_ac"]))
    json.dump(res, open(os.path.join(out_dir, "cruise.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
