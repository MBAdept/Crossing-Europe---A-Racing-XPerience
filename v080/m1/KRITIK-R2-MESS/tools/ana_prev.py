#!/usr/bin/env python3
"""KRITIK-R2-MESS: where things are audible in the user's previews (deliver/AU-R/*.mp3) against the times the .txt
files name. Decodes the MP3 (ffmpeg), then per event a detector in a search window around the named time:
  step   = largest rise (or fall) of a band level (20-ms RMS, dB) between 0.3 s before and 0.3 s after a frame
  onset  = transients of a band envelope (5-ms RMS) standing >= thr dB above the median of the 200 ms before
  slab   = the slab beat: power of the 2.5-8 kHz envelope at v/5 m (Hz) against 5-20 Hz, in 1-s windows
usage: ana_prev.py <out.json>"""
import json
import os
import subprocess
import sys

import numpy as np

SR = 44100
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-R"


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def band(m, lo, hi):
    n = len(m)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    h = np.ones_like(f)
    if lo:
        h *= 1.0 / np.sqrt(1.0 + (lo / f) ** 8)
    if hi:
        h *= 1.0 / np.sqrt(1.0 + (f / hi) ** 8)
    return np.fft.irfft(np.fft.rfft(m) * h, n)


def env_db(m, frame_s):
    k = int(frame_s * SR)
    n = len(m) // k
    e = np.sqrt(np.mean(m[:n * k].reshape(n, k) ** 2, axis=1) + 1e-20)
    return 20 * np.log10(e)


def silences(x, min_s=1.0):
    a = np.max(np.abs(x), axis=1)
    k = int(0.01 * SR)
    n = len(a) // k
    q = a[:n * k].reshape(n, k).max(axis=1) < 1e-4
    out, i = [], 0
    while i < n:
        if q[i]:
            j = i
            while j < n and q[j]:
                j += 1
            if (j - i) * 0.01 >= min_s:
                out.append((i * 0.01, j * 0.01))
            i = j
        else:
            i += 1
    return out


class Sig:
    def __init__(self, x):
        self.x = x
        self.m = x.mean(axis=1)
        self._b = {}

    def lev(self, lo, hi, frame_s=0.02):
        key = (lo, hi, frame_s)
        if key not in self._b:
            self._b[key] = env_db(band(self.m, lo, hi), frame_s)
        return self._b[key]


def step(sig, t, win, lo, hi, sign=+1, half=0.3):
    L = sig.lev(lo, hi, 0.02)
    h = int(half / 0.02)
    a, b = int((t - win) / 0.02), int((t + win) / 0.02)
    best, bt = -1e9, None
    for i in range(max(a, h), min(b, len(L) - h)):
        d = sign * (L[i:i + h].mean() - L[i - h:i].mean())
        if d > best:
            best, bt = d, i * 0.02
    return bt, best


def onsets(sig, t0, t1, lo, hi, thr=6.0, gap=0.25):
    L = sig.lev(lo, hi, 0.005)
    out = []
    i0, i1 = int(t0 / 0.005), int(t1 / 0.005)
    last = -9.0
    for i in range(max(i0, 41), min(i1, len(L))):
        ref = float(np.median(L[i - 40:i]))
        if L[i] - ref >= thr and i * 0.005 - last >= gap:
            # the peak of this transient within 30 ms
            j = i + int(np.argmax(L[i:i + 6]))
            out.append((round(j * 0.005, 3), round(float(L[j] - ref), 1)))
            last = i * 0.005
    return out


def slab_beat(sig, t0, t1, f_beat, win=1.0, hop=0.1):
    e = sig.lev(2500, 8000, 0.005)
    rows = []
    k = int(win / 0.005)
    for s in np.arange(t0, t1 - win, hop):
        i = int(s / 0.005)
        v = e[i:i + k]
        if len(v) < k:
            break
        v = (v - v.mean()) * np.hanning(len(v))
        sp = np.abs(np.fft.rfft(v, 4 * k)) ** 2
        f = np.fft.rfftfreq(4 * k, 0.005)
        pk = sp[(f > f_beat - 0.6) & (f < f_beat + 0.6)].max()
        ref = np.median(sp[(f > 4) & (f < 20)])
        rows.append((round(float(s + win / 2), 2), round(float(10 * np.log10(pk / ref)), 1)))
    return rows


def first_above(rows, thr, after=0.0, hold=3):
    for i in range(len(rows) - hold):
        if rows[i][0] >= after and all(r[1] >= thr for r in rows[i:i + hold]):
            return rows[i][0]
    return None


def main():
    out = {}
    # --- 1 drive before/after
    x = decode(os.path.join(D, "fahrt_kiel_hamburg_vorher_nachher.mp3"))
    sig = Sig(x)
    sil = silences(x)
    out["drive_len_s"] = len(x) / SR
    out["drive_silences"] = sil
    print("Fahrt vorher/nachher: Länge %.2f s, Stille %s" % (len(x) / SR, sil))
    halves = {"vorher": 0.0, "nachher": sil[0][1] if sil else 48.63}
    res = {}
    for nm, t0 in halves.items():
        r = {}
        # slab beat at 175 km/h: 48.6 m/s / 5 m = 9.72 Hz
        rows = slab_beat(sig, t0, t0 + 9.3, 175 / 3.6 / 5.0)
        r["slab_beat_rows"] = rows
        r["slab_onset_beat"] = first_above(rows, 10.0, t0)
        r["slab_step_hf"] = step(sig, t0 + 4.8, 2.0, 2500, 8000, +1)
        r["slab_step_mid"] = step(sig, t0 + 4.8, 2.0, 250, 1000, +1)
        # bridge: joints on the deck, transients 150-2000 Hz between the phase start and its end
        r["bridge_onsets"] = onsets(sig, t0 + 9.0, t0 + 20.5, 150, 2000, thr=6.0)
        r["bridge_onsets_hf"] = onsets(sig, t0 + 9.0, t0 + 20.5, 2000, 8000, thr=6.0)
        # guardrail hit (named phase time + 0.9 s script)
        r["rail_onsets"] = onsets(sig, t0 + 29.0, t0 + 33.0, 100, 4000, thr=10.0, gap=0.5)
        # Hamburg: phase start (fall), cobbles on (rise), cobbles off (fall) – 2.5-8 kHz
        r["hh_start_fall"] = step(sig, t0 + 35.4, 1.5, 100, 8000, -1)
        r["hh_cobbles_on"] = step(sig, t0 + 37.2, 2.0, 2500, 8000, +1)
        r["hh_cobbles_off"] = step(sig, t0 + 43.4, 2.0, 2500, 8000, -1)
        res[nm] = r
        print(f"== {nm} (ab {t0:.2f} s)")
        print("   Plattentakt 9,7 Hz ≥ 10 dB ab %s s; Stufe 2,5–8 kHz %s; 250–1000 Hz %s" % (r["slab_onset_beat"],
              r["slab_step_hf"], r["slab_step_mid"]))
        print("   Takt-Zeilen:", [rw for rw in rows if t0 + 3 <= rw[0] <= t0 + 7])
        print("   Brücke Transienten 150–2000 Hz:", r["bridge_onsets"])
        print("   Brücke Transienten 2–8 kHz:", r["bridge_onsets_hf"])
        print("   Leitplanke:", r["rail_onsets"])
        print("   Hamburg Phase (Fall):", r["hh_start_fall"], "Pflaster an:", r["hh_cobbles_on"], "aus:", r["hh_cobbles_off"])
    out["drive"] = res
    # --- 2 bridge A/B
    xb = decode(os.path.join(D, "koehlbrandbruecke_fugen_vorher_nachher.mp3"))
    sb = Sig(xb)
    silb = silences(xb)
    out["bridge_len_s"] = len(xb) / SR
    out["bridge_silences"] = silb
    out["bridge_onsets"] = onsets(sb, 0.0, len(xb) / SR, 150, 2000, thr=6.0)
    out["bridge_onsets_hf"] = onsets(sb, 0.0, len(xb) / SR, 2000, 8000, thr=6.0)
    print("Brücke A/B: Länge %.2f s, Stille %s" % (len(xb) / SR, silb))
    print("   Transienten 150–2000 Hz:", out["bridge_onsets"])
    print("   Transienten 2–8 kHz:", out["bridge_onsets_hf"])
    # --- 3 game mix with music
    xm = decode(os.path.join(D, "fahrt_kiel_hamburg_spielmix_neu.mp3"))
    sm = Sig(xm)
    rows = slab_beat(sm, 0.0, 9.3, 175 / 3.6 / 5.0)
    out["mix"] = {"len_s": len(xm) / SR, "slab_onset_beat": first_above(rows, 10.0, 0.0), "slab_beat_rows": rows,
                  "slab_step_hf": step(sm, 4.8, 2.0, 2500, 8000, +1),
                  "bridge_onsets": onsets(sm, 9.0, 20.5, 150, 2000, thr=6.0),
                  "rail_onsets": onsets(sm, 29.0, 33.0, 100, 4000, thr=10.0, gap=0.5),
                  "hh_start_fall": step(sm, 35.3, 1.5, 100, 8000, -1),
                  "hh_cobbles_on": step(sm, 37.4, 2.0, 2500, 8000, +1),
                  "hh_cobbles_off": step(sm, 43.6, 2.0, 2500, 8000, -1)}
    print("Spielmix: Länge %.2f s" % (len(xm) / SR))
    print("   ", {k: v for k, v in out["mix"].items() if k != "slab_beat_rows"})
    print("   Takt-Zeilen:", [rw for rw in rows if 3 <= rw[0] <= 7])
    json.dump(out, open(sys.argv[1], "w"), indent=1)


if __name__ == "__main__":
    main()
