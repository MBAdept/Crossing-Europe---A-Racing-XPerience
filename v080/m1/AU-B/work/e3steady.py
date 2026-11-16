"""Scratch (AU-B): steady-state comparison Arcade engine vs Modern engine v3 per car - spectral centroid over rpm,
harmonic-to-noise ratio, modulation depth, octave balance, loss on small speakers (high-pass 180 Hz).
    python3 e3steady.py <bank-dir> <out-dir> [car ...]
Writes <out-dir>/steady_<car>.json and prints the tables."""
from __future__ import annotations
import json, math, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import e3an  # noqa: E402

REPO = e3an.REPO
CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
FRACS = [0.2, 0.3, 0.4, 0.55, 0.7, 0.85, 0.95]
LOADS = [1.0, 0.22, 0.0]
SECONDS = 5.0


def render(car: str, profile: str, bank_dir: str, out: str, rpms: list, motion: bool = True) -> None:
    env = dict(os.environ, XDG_DATA_HOME=os.path.join(HERE, "..", "xdg"))
    env["XDG_DATA_HOME"] = os.path.abspath(env["XDG_DATA_HOME"])
    cmd = ["godot", "--headless", "--path", REPO, "-s", os.path.join(HERE, "e3render.gd"), "--", f"--car={car}", f"--profile={profile}",
           "--scenario=steady", "--rpms=" + ",".join(str(int(r)) for r in rpms), "--loads=" + ",".join(str(x) for x in LOADS),
           f"--seconds={SECONDS}", f"--bank-dir={bank_dir}", f"--out={out}"] + ([] if motion else ["--motion=0"])
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0 or "FEHLER" in r.stdout or "SCRIPT ERROR" in r.stdout + r.stderr:
        print(r.stdout[-2000:], r.stderr[-2000:])
        raise SystemExit("Render fehlgeschlagen")


def hp180(seg: np.ndarray, sr: int) -> np.ndarray:
    X = np.fft.rfft(seg, axis=0)
    f = np.fft.rfftfreq(len(seg), 1.0 / sr)
    X *= (1.0 / np.sqrt(1.0 + (180.0 / np.maximum(f, 1e-3)) ** 8))[:, None]
    return np.fft.irfft(X, len(seg), axis=0)


def octaves(seg: np.ndarray, sr: int) -> list:
    f, p = e3an.spectrum(seg, sr, 16384)
    tot = p.sum()
    return [round(10 * math.log10(max(p[(f >= c / 1.414) & (f < c * 1.414)].sum() / tot, 1e-12)), 1) for c in (63, 125, 250, 500, 1000, 2000, 4000, 8000)]


def analyse(path: str) -> list:
    x, sr, tr = e3an.read(path)
    rows = []
    for ph in tr["phases"]:
        seg = x[int(ph["t0"] * sr):int(ph["t1"] * sr)]
        mod = e3an.modulation_db(seg, sr)
        X = np.fft.rfft(seg, axis=0)
        f = np.fft.rfftfreq(len(seg), 1.0 / sr)
        X[f < 1000] = 0
        hb = np.fft.irfft(X, len(seg), axis=0)
        l = e3an.lufs(seg, sr)
        rows.append({"rpm": ph["rpm"], "load": ph["load"], "lufs": round(l, 2), "centroid": round(e3an.centroid_hz(seg, sr)),
                     "hnr": round(e3an.hnr_db(seg, sr, ph["rpm"], 4), 1), "mod_std": round(mod["std"], 2), "mod_range": round(mod["range"], 2),
                     "corr": round(e3an.corr(seg), 2), "corr_hf": round(e3an.corr(hb), 2), "oct": octaves(seg, sr),
                     "hp180": round(e3an.lufs(hp180(seg, sr), sr) - l, 1), "bal": round(e3an.balance_db(seg, sr), 2),
                     "mono": round(e3an.mono_drop_db(seg, sr), 2)})
    return rows


def main() -> None:
    bank_dir, out_dir = sys.argv[1], sys.argv[2]
    cars = sys.argv[3:] or CARS
    os.makedirs(out_dir, exist_ok=True)
    for car in cars:
        meta = json.load(open(os.path.join(REPO, "assets/audio/engines/%s.json" % car), encoding="utf-8"))
        red = float(meta["engine"]["redline_rpm"])
        rpms = [round(fr * red / 50.0) * 50 for fr in FRACS]
        res = {"car": car, "rpms": rpms}
        for prof in ("arcade", "modern"):
            wav = os.path.join(out_dir, f"steady_{car}_{prof}.wav")
            render(car, prof, bank_dir, wav, rpms)
            res[prof] = analyse(wav)
            os.remove(wav)
            if prof == "modern":
                # the harmonic-to-noise ratio of the bank itself: without the movement of the mixer (the drifting
                # rpm smears the upper harmonics out of the narrow bands of the measure)
                render(car, prof, bank_dir, wav, rpms, motion=False)
                still = analyse(wav)
                os.remove(wav)
                for row, st in zip(res[prof], still):
                    row["hnr_moving"] = row["hnr"]
                    row["hnr"] = st["hnr"]
                    row["mod_std_still"] = st["mod_std"]
        json.dump(res, open(os.path.join(out_dir, f"steady_{car}.json"), "w"), indent=1)
        print(f"== {car} (Nenndrehzahl {red:.0f}/min)")
        print("   Last   /min   | LUFS  alt / neu  | Schwerpunkt Hz | HNR dB      | Mod. dB (50 ms) | HP180 dB    | Korr / >1k neu | Oktaven 250/500/1k/2k alt -> neu")
        for i, (a, m) in enumerate(zip(res["arcade"], res["modern"])):
            print("   %4.0f%%  %5.0f  | %6.1f %6.1f  | %5d %5d    | %5.1f %5.1f | %5.2f %5.2f     | %5.1f %5.1f | %4.2f %4.2f      | %s -> %s" % (
                a["load"] * 100, a["rpm"], a["lufs"], m["lufs"], a["centroid"], m["centroid"], a["hnr"], m["hnr"], a["mod_std"], m["mod_std"],
                a["hp180"], m["hp180"], m["corr"], m["corr_hf"], "/".join("%.0f" % v for v in a["oct"][2:6]), "/".join("%.0f" % v for v in m["oct"][2:6])))


if __name__ == "__main__":
    main()
