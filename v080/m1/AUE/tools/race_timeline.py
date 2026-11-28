#!/usr/bin/env python3
"""AU-E: analysis of a whole-race recording (tools/audio/record_race.sh) with ffmpeg's ebur128 filter (BS.1770,
momentary 0.4 s / short-term 3 s every 100 ms, true peak per 100-ms frame at 4x): loudness per screen segment
(gated like BS.1770 over the momentary blocks of the segment), short-term max/median, true peak, silent stretches,
sudden jumps, and a PNG of the short-term curve with the screens marked.
  race_timeline.py <race_x.flac> <race_x.log> <out prefix> [title]"""
import json
import math
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

LINE = re.compile(r"t:\s*([0-9.]+)\s+TARGET.*?M:\s*(-?[0-9.]+|-inf)\s+S:\s*(-?[0-9.]+|-inf).*?FTPK:\s*(-?[0-9.]+|-inf)\s+(-?[0-9.]+|-inf)")


def num(s):
    return -120.0 if "inf" in s else float(s)


def frames(path):
    p = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-v", "verbose", "-i", path, "-af",
                        "ebur128=peak=true:framelog=verbose", "-f", "null", "-"], capture_output=True, text=True)
    out = []
    for line in p.stderr.splitlines():
        m = LINE.search(line)
        if m:
            out.append((float(m.group(1)), num(m.group(2)), num(m.group(3)), max(num(m.group(4)), num(m.group(5)))))
    return out


def segments(log_path, total_s):
    marks = []
    for line in open(log_path, encoding="utf-8", errors="replace"):
        if line.startswith("ZEIT "):
            p = line.split()
            marks.append((float(p[1]), p[2] if len(p) > 2 else "?"))
    segs = []
    for i, (t, name) in enumerate(marks):
        t1 = marks[i + 1][0] if i + 1 < len(marks) else total_s
        segs.append({"screen": name, "t0": round(t, 2), "t1": round(t1, 2)})
    return segs


def gated(ms):
    """BS.1770 integrated loudness from momentary block loudnesses (0.4-s blocks every 0.1 s)."""
    p = [10 ** ((m + 0.691) / 10) for m in ms if m > -70.0]
    if not p:
        return -70.0
    rel = -0.691 + 10 * math.log10(sum(p) / len(p)) - 10.0
    p2 = [10 ** ((m + 0.691) / 10) for m in ms if m > -70.0 and m > rel]
    return round(-0.691 + 10 * math.log10(sum(p2) / len(p2)), 2) if p2 else -70.0


def median(a):
    s = sorted(a)
    n = len(s)
    return s[n // 2] if n % 2 else 0.5 * (s[n // 2 - 1] + s[n // 2])


def main():
    flac, log, prefix = sys.argv[1:4]
    title = sys.argv[4] if len(sys.argv) > 4 else flac.split("/")[-1]
    fr = frames(flac)
    total = fr[-1][0] if fr else 0.0
    segs = segments(log, total)
    out = {"seconds": round(total, 1), "integrated": gated([f[1] for f in fr]),
           "true_peak": round(max(f[3] for f in fr), 2), "segments": []}
    for s in segs:
        ms = [f[1] for f in fr if f[0] - 0.4 >= s["t0"] - 1e-6 and f[0] <= s["t1"] + 1e-6]
        st = [f[2] for f in fr if f[0] - 3.0 >= s["t0"] - 1e-6 and f[0] <= s["t1"] + 1e-6]
        tp = [f[3] for f in fr if f[0] - 0.1 >= s["t0"] - 1e-6 and f[0] <= s["t1"] + 1e-6]
        if not ms:
            continue
        s["lufs"] = gated(ms)
        if st:
            s["short_term_max"] = round(max(st), 2)
            s["short_term_median"] = round(median(st), 2)
        s["true_peak"] = round(max(tp), 2) if tp else None
        out["segments"].append(s)
    # stretches under −60 LUFS momentary for longer than 0.5 s, and rises of more than 12 dB within 0.2 s
    silent, run = [], None
    for t, m, _s, _p in fr:
        if m < -60.0:
            run = t if run is None else run
        elif run is not None:
            if t - run > 0.5:
                silent.append([round(run, 1), round(t, 1)])
            run = None
    out["silent_stretches"] = silent
    jumps = []
    for i in range(2, len(fr)):
        if fr[i][1] - fr[i - 2][1] > 12.0 and fr[i][1] > -40.0:
            jumps.append([round(fr[i][0], 1), fr[i - 2][1], fr[i][1]])
    out["jump_count"] = len(jumps)
    out["jumps"] = jumps[:300]
    json.dump(out, open(prefix + ".json", "w"), indent=1, ensure_ascii=False)
    # picture
    w, h, l, r, top, bot = 1800, 520, 70, 20, 50, 60
    img = Image.new("RGB", (w, h), (252, 252, 250))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 14)
        small = ImageFont.truetype("DejaVuSans.ttf", 11)
    except OSError:
        font = small = ImageFont.load_default()
    ymin, ymax = -60.0, -5.0

    def xp(t):
        return l + (w - l - r) * t / max(total, 1.0)

    def yp(v):
        return top + (h - top - bot) * (ymax - max(ymin, min(ymax, v))) / (ymax - ymin)

    for s in segs:
        if s["screen"] != "race":
            d.rectangle([xp(s["t0"]), top, xp(s["t1"]), h - bot], fill=(245, 226, 170))
    for v in range(-60, -4, 5):
        d.line([l, yp(v), w - r, yp(v)], fill=(225, 225, 225))
        d.text((8, yp(v) - 7), f"{v}", fill=(90, 90, 90), font=small)
    for v, lab in [(-16, "Vollgas −16"), (-20, "Menü −20"), (-24, "Leerlauf −24")]:
        d.line([l, yp(v), w - r, yp(v)], fill=(160, 160, 160))
        d.text((l + 4, yp(v) - 14), lab, fill=(110, 110, 110), font=small)
    pts = [(xp(t), yp(s)) for t, _m, s, _p in fr[::5] if s > -120.0]
    if len(pts) > 1:
        d.line(pts, fill=(40, 90, 160), width=1)
    for m in range(0, int(total / 60) + 1, 5):
        d.text((xp(m * 60) - 6, h - bot + 8), f"{m}", fill=(90, 90, 90), font=small)
    d.text((w // 2 - 40, h - 22), "Minuten", fill=(60, 60, 60), font=font)
    d.text((l, 12), f"{title}: integriert {out['integrated']} LUFS, True Peak {out['true_peak']} dBTP – Kurzzeit-Lautheit"
           " (3 s); gelb: Bildschirme außerhalb der Fahrt", fill=(30, 30, 30), font=font)
    img.save(prefix + ".png")
    print(json.dumps({k: v for k, v in out.items() if k not in ("segments", "jumps")}, ensure_ascii=False))
    for s in out["segments"]:
        print(f"  {s['t0']:8.1f}–{s['t1']:8.1f}  {s['screen']:16s} {s.get('lufs', 0):7.2f} LUFS  "
              f"Kurzzeit max {s.get('short_term_max', float('nan')):7.2f} Median {s.get('short_term_median', float('nan')):7.2f}"
              f"  TP {s.get('true_peak')}")


if __name__ == "__main__":
    main()
