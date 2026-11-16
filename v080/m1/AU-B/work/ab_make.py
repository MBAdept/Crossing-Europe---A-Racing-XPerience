"""Scratch (AU-B): builds the deliverables from the in-game engine captures of work/ab/<tag>/ (ab_capture.gd):
  <deliver>/motor_ab_<car>.mp3 + .txt   Arcade | Modern alternating per part of the drive, level-matched
  <deliver>/spektrogramm_<car>.png      both captures on one scale, with the parts of the drive
  <deliver>/ab_zahlen.json              loudness per phase, loudness range, stereo, spectrum numbers
    python3 ab_make.py <capture-dir> <deliver-dir>
"""
from __future__ import annotations
import json, math, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import e3an  # noqa: E402
from e3an import alib, qc_lib  # noqa: E402

CARS = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
NAMES = {"kompakt": "Kompakt (2,0 l R4 Turbo)", "kombi": "Kombi (2,0 l R4 Turbodiesel)", "limousine": "Limousine (3,0 l R6 Turbo)",
         "sportwagen": "Sportwagen (4,0 l B6 Saugmotor)", "gran_turismo": "Gran Turismo (4,0 l V8 Biturbo)"}
GROUPS = [("Start, Leerlauf, zwei Gasstöße im Stand", ["idle", "revs"]),
          ("Vollgas durch die Gänge", ["pull"]),
          ("Reisetempo 200 km/h, Gas weg, Bremsen mit Rückschalten", ["cruise_hi", "lift", "brake"]),
          ("130 km/h, Kick-down, Gas weg, Anhalten", ["cruise_130", "kickdown", "lift2", "stop"])]
PHASE_DE = {"idle": "Start/Leerlauf", "revs": "Gasstöße", "pull": "Vollgas durch die Gänge", "cruise_hi": "200 km/h", "lift": "Gas weg",
            "brake": "Bremsen", "cruise_130": "130 km/h", "kickdown": "Kick-down", "lift2": "Gas weg", "stop": "Anhalten"}


def load(path):
    x, sr = qc_lib.read_wav(path)
    x = np.asarray(x, np.float64)
    meta = json.load(open(path + ".json", encoding="utf-8"))
    return x, sr, meta


def fade(seg, sr, ms=20.0):
    n = int(ms * 1e-3 * sr)
    seg = seg.copy()
    seg[:n] *= np.linspace(0.0, 1.0, n)[:, None]
    seg[-n:] *= np.linspace(1.0, 0.0, n)[:, None]
    return seg


def write_wav(path, x, sr):
    import wave
    pcm = np.clip(np.rint(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def phase_numbers(x, sr, phases):
    out = {}
    for ph in phases:
        a, b = int(ph["t0"] * sr), min(int(ph["t1"] * sr), len(x))
        seg = x[a:b]
        if len(seg) < sr // 2:
            continue
        out[ph["name"]] = {"lufs": round(e3an.lufs(seg, sr), 2), "corr": round(e3an.corr(seg), 2), "balance_db": round(e3an.balance_db(seg, sr), 2),
                           "mono_db": round(e3an.mono_drop_db(seg, sr), 2), "centroid_hz": round(e3an.centroid_hz(seg, sr)),
                           "share_2k_db": round(e3an.share_db(seg, sr, 2000, 20000), 1), "share_5k_db": round(e3an.share_db(seg, sr, 5000, 20000), 1),
                           "mod_std_db": round(e3an.modulation_db(seg, sr)["std"], 2), "peak": round(float(np.max(np.abs(seg))), 3)}
    return out


def annotate(im, phases, dur, w=1500, ml=56, mt=22, h=380):
    from PIL import ImageDraw
    dr = ImageDraw.Draw(im)
    fnt = alib.font(11)
    for ph in phases:
        xx = ml + int(round(ph["t0"] / dur * (w - 1)))
        dr.line([(xx, mt), (xx, mt + h)], fill=(255, 255, 255, 90), width=1)
        dr.text((xx + 3, mt + 2), PHASE_DE.get(ph["name"], ph["name"]), fill=(255, 255, 255), font=fnt)
    return im


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    numbers = {}
    for car in CARS:
        pa, pm = os.path.join(src, f"{car}_arcade.wav"), os.path.join(src, f"{car}_modern.wav")
        if not (os.path.exists(pa) and os.path.exists(pm)):
            print("fehlt:", car)
            continue
        xa, sr, ma = load(pa)
        xm, sr2, mm = load(pm)
        assert sr == sr2
        phases = mm["phases"]
        ia, im_ = qc_lib.integrated_lufs(xa, sr), qc_lib.integrated_lufs(xm, sr)
        numbers[car] = {"arcade": {"integrated_lufs": round(ia, 2), "lra": round(qc_lib.loudness_range(xa, sr), 2),
                                   "true_peak_db": round(qc_lib.true_peak_db(xa), 2), "phases": phase_numbers(xa, sr, phases),
                                   "engine_perf": ma.get("engine", {})},
                        "modern": {"integrated_lufs": round(im_, 2), "lra": round(qc_lib.loudness_range(xm, sr), 2),
                                   "true_peak_db": round(qc_lib.true_peak_db(xm), 2), "phases": phase_numbers(xm, sr, phases),
                                   "engine_perf": mm.get("engine", {})}}
        # --- A/B file: Modern raised to the integrated loudness of Arcade (the plan plays Modern about 3 dB lower)
        g = 10.0 ** ((ia - im_) / 20.0)
        pk = max(float(np.max(np.abs(xa))), float(np.max(np.abs(xm))) * g)
        norm = min(1.0, 0.94 / pk)
        parts, marks, pos = [], [], 0.0
        gap_ab, gap_group = np.zeros((int(0.35 * sr), 2)), np.zeros((int(0.7 * sr), 2))
        by = {p["name"]: p for p in phases}
        for title, names in GROUPS:
            t0, t1 = by[names[0]]["t0"], by[names[-1]]["t1"]
            a, b = int(t0 * sr), min(int(t1 * sr), len(xa), len(xm))
            for label, x, gain in (("Arcade", xa, norm), ("Modern", xm, g * norm)):
                seg = fade(x[a:b] * gain, sr)
                marks.append((pos, pos + len(seg) / sr, label, title))
                parts += [seg, gap_ab if label == "Arcade" else gap_group]
                pos += (len(seg) + len(parts[-1])) / sr
        y = np.concatenate(parts, axis=0)
        wav = os.path.join(dst, f"motor_ab_{car}.wav")
        write_wav(wav, y, sr)
        mp3 = os.path.join(dst, f"motor_ab_{car}.mp3")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libmp3lame", "-q:a", "2", mp3], check=True)
        os.remove(wav)
        with open(os.path.join(dst, f"motor_ab_{car}.txt"), "w", encoding="utf-8") as fh:
            d_db = 20 * math.log10(g)
            fh.write(f"{NAMES[car]} – derselbe Fahrablauf, abwechselnd mit dem Motor des Profils Arcade und dem Motor v3 des Profils Modern,\n"
                     "jeweils im Spiel über die Busse des Profils aufgenommen (nur der Motor mit seinen Fahrzeugebenen, ohne Wind, Reifen, Verkehr).\n"
                     f"Für den Vergleich pegelgleich gemacht: Modern um {abs(d_db):.1f} dB {'angehoben' if d_db >= 0 else 'abgesenkt'} "
                     f"(im Spiel ist der Motor von Modern über die ganze Fahrt {'leiser' if im_ < ia else 'lauter'}:\n"
                     f"Arcade {ia:.1f} LUFS, Modern {im_:.1f} LUFS; Modern folgt dem Pegelplan, Vollgas −16 LUFS mit Wind).\n"
                     "Niemand hat diese Datei gehört; sie ist aus den Aufnahmen geschnitten und nur gemessen.\n\n")
            for t0, t1, label, title in marks:
                fh.write(f"{t0:6.1f} – {t1:6.1f} s  {label.upper():7s} {title}\n")
        numbers[car]["ab_gain_modern_db"] = round(20 * math.log10(g), 2)
        # --- spectrogram of both captures on one scale
        dur = len(xm) / sr
        img_a, ref = alib.spectrogram_img(xa * norm, sr, w=1500, h=380, fmin=30.0, fmax=16000.0, dyn_db=80.0)
        img_m, _ = alib.spectrogram_img(xm * g * norm, sr, w=1500, h=380, fmin=30.0, fmax=16000.0, dyn_db=80.0, ref_db=ref)
        alib.stack_images([("Arcade (Motorklang v2, mono, Breitenhall)", annotate(img_a, phases, len(xa) / sr)),
                           ("Modern (Motor v3: Stereobank, Ansaug- und Auspuffebene, Fahrzeugebenen), pegelgleich", annotate(img_m, phases, dur))],
                          os.path.join(dst, f"spektrogramm_{car}.png"), f"{NAMES[car]} – im Spiel aufgenommen, nur der Motor")
        print(car, "ok: Arcade %.1f LUFS, Modern %.1f LUFS, LRA %.1f / %.1f" % (ia, im_, numbers[car]["arcade"]["lra"], numbers[car]["modern"]["lra"]))
    json.dump(numbers, open(os.path.join(dst, "ab_zahlen.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
