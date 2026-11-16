"""Listening material for the user (deliver/AU-D2): MP3 excerpts and complete pieces, stinger demos, UI demo,
spectrograms. usage: deliver.py ROOT OUTDIR WAVDIR"""
import json
import os
import subprocess
import sys

ROOT, OUT, WAV = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "qc"))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio"))
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402
import music_synth as ms  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
except OSError:
    FONT = None

SR = 44100
MUS = os.path.join(ROOT, "assets", "audio", "modern", "music")
os.makedirs(OUT, exist_ok=True)
man = json.load(open(os.path.join(MUS, "manifest.json"), encoding="utf-8"))["sounds"]


def rd(name):
    x, sr = qc_lib.read_audio(os.path.join(MUS, name))
    assert sr == SR
    return x


def mp3(x, name):
    path = os.path.join(OUT, name)
    x = np.asarray(x, np.float32)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libmp3lame", "-b:a", "192k", path], input=x.tobytes(), check=True)
    return path


def db(v):
    return 10.0 ** (v / 20.0)


def spectro(x, path, marks=(), labels=(), width=1400, title=""):
    mono = x.mean(axis=1)
    n, hop = 4096, max(512, len(mono) // 2400)
    frames = np.array([mono[i:i + n] * np.hanning(n) for i in range(0, max(1, len(mono) - n), hop)])
    S = 20 * np.log10(np.abs(np.fft.rfft(frames, axis=1)).T + 1e-9)
    f = np.fft.rfftfreq(n, 1 / SR)
    rows = 260
    fl = np.geomspace(30, 16000, rows)
    img = S[np.clip(np.searchsorted(f, fl), 0, len(f) - 1)][::-1]
    hi = np.percentile(img, 99.5)
    img = np.clip((img - (hi - 75)) / 75.0, 0, 1)
    rgb = np.stack([img ** 0.6 * 255, img ** 1.4 * 225, (1 - img) * 70 + img * 30], axis=2).astype(np.uint8)
    im = Image.fromarray(rgb).resize((width, rows * 2))
    canvas = Image.new("RGB", (width, rows * 2 + 40), (20, 20, 28))
    canvas.paste(im, (0, 40))
    dr = ImageDraw.Draw(canvas)
    dr.text((6, 4), title, fill=(240, 240, 240), font=FONT)
    dr.text((6, 20), "Frequenz logarithmisch 30 Hz (unten) bis 16 kHz (oben); Linien: Abschnitte", fill=(170, 170, 170), font=FONT)
    total = len(mono) / SR
    for k, (t, lab) in enumerate(zip(marks, labels)):
        xx = int(t / total * width)
        dr.line([(xx, 40), (xx, rows * 2 + 40)], fill=(255, 255, 255), width=1)
        dr.text((xx + 3, 44 + 16 * (k % 2)), lab, fill=(255, 255, 255), font=FONT)
    canvas.save(path)


report = {}
NAMES = {"nachtfahrt": "Nachtfahrt", "rueckenwind": "Rückenwind"}
pieces = [("nachtfahrt", "rennmusik_2_nachtfahrt"), ("rueckenwind", "rennmusik_3_rueckenwind")]
for pid, stem in pieces:
    e = man[pid]
    x = rd(pid + ".ogg")
    end = rd(pid + "_schluss.ogg")
    bar = 240.0 / e["bpm"]
    mp3(x[:45 * SR], stem + "_auszug_45s.mp3")
    full = np.concatenate([x, end])                     # the file plays once, the ending joins at its last bar line
    mp3(full, stem + "_komplett_mit_schluss.mp3")
    # sections for the spectrogram
    import importlib
    sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "music"))
    mod = importlib.import_module(pid)
    cls = next(v for v in vars(mod).values() if isinstance(v, type) and getattr(v, "PIECE", "") == pid)
    phrases = [p[0] for p in cls.PHRASES]
    marks = [0.0, bar] + [bar * (1 + 8 * i) for i in range(1, len(phrases) + 1)] + [len(x) / SR]
    labels = ["Einz.", phrases[0]] + phrases[1:] + [phrases[0] + "'", "Schluss"]
    spectro(full, os.path.join(OUT, stem + "_spektrogramm.png"), marks, labels,
            title=f"{NAMES[pid]} – {e['bpm']:g} bpm, {e['key']}, {len(full)/SR:.0f} s (einmal durch, dann der Schluss)")
    report[pid] = {"seconds_first_pass": round(len(x) / SR, 1), "with_ending": round(len(full) / SR, 1)}

# interlude: the whole file and 20 s more across the loop point
z = rd("zwischenspiel.ogg")
ze = man["zwischenspiel"]
lb = ze["loop"][0]
zz = np.concatenate([z, z[lb:lb + 20 * SR]])
mp3(zz, "zwischenspiel_komplett_plus_schleifennaht.mp3")
zbar = 240.0 / ze["bpm"]
spectro(zz, os.path.join(OUT, "zwischenspiel_spektrogramm.png"),
        [0, 2 * zbar, 10 * zbar, 18 * zbar, 26 * zbar, 32 * zbar, len(z) / SR],
        ["T", "A", "B", "A'", "B'", "T", "Naht -> A"], title="Zwischenspiel – 100 bpm, e-Moll, Schleife 76,8 s (hier: einmal + 20 s über die Naht)")

# stingers bare: every clip of the three pieces, 1.5 s apart
order = [("linke_spur", "Linke Spur"), ("nachtfahrt", "Nachtfahrt"), ("rueckenwind", "Rückenwind")]
clips = ["ziel", "schluss", "schluss_rekord", "schluss_finale", "polizei", "tank"]
parts, marks, labels, t = [], [], [], 0.0
gap = np.zeros((int(1.5 * SR), 2))
for pid, name in order:
    for c in clips:
        y = rd(f"{pid}_{c}.ogg")
        marks.append(t)
        labels.append(f"{pid[:2]}:{c.replace('schluss_', '')}")
        parts += [y, gap]
        t += (len(y) + len(gap)) / SR
demo = np.concatenate(parts)
mp3(demo, "stinger_alle_nacheinander.mp3")
spectro(demo, os.path.join(OUT, "stinger_spektrogramm.png"), marks, labels, width=2400,
        title="Alle Schlüsse und Stinger: je Stück Ziel-Schlag, Schluss, Rekord, Finale, Polizei, Tank (1,5 s Pause)")
report["stinger_demo_s"] = round(len(demo) / SR, 1)

# stingers in context: how the game plays them (race music ducked by 9 dB under the stinger, on the next beat;
# at the finish the stab, then the ending at the next bar line)
DUCK = -9.0


def duck_curve(n, start, hold_s, attack=0.05, release=1.0):
    t = (np.arange(n) - start) / SR
    up = np.clip(t / attack, 0, 1)
    down = np.clip((t - hold_s) / release, 0, 1)
    g = np.where(t < 0, 0.0, DUCK * (up - down * up))
    return db(g)


scenes = []
# 1. Nachtfahrt: 14 s of the hook phrase, then "busted" on the next beat
for pid, at_s, sting in (("nachtfahrt", 25.0, "polizei"), ("rueckenwind", 40.0, "tank")):
    e = man[pid]
    x = rd(pid + ".ogg")
    beat = 60.0 / e["bpm"]
    a = int((at_s - 8.0) * SR)
    t_ev = at_s + 0.13
    t_on = np.ceil(t_ev / beat) * beat
    st = rd(f"{pid}_{sting}.ogg")
    seg = x[a:a + int(8.0 * SR) + len(st) + int(1.0 * SR)].copy()
    on = int((t_on - (at_s - 8.0)) * SR)
    hold = man[f"{pid}_{sting}"]["bars"] * 4 * beat
    seg *= duck_curve(len(seg), on, hold)[:, None]
    seg[on:on + len(st)] += st[:len(seg) - on]
    scenes.append(seg)
# 2. Linke Spur: the finish 0.9 s before a bar line – the stab now, the record ending at the bar line
e = man["linke_spur"]
x = rd("linke_spur.ogg")
bar = 240.0 / e["bpm"]
fin_bar = 30
t_fin = fin_bar * bar - 0.9
a = int((t_fin - 8.0) * SR)
stab = rd("linke_spur_ziel.ogg")
rec = rd("linke_spur_schluss_rekord.ogg")
b_on = int(fin_bar * bar * SR) - a
seg = np.zeros((b_on + len(rec), 2))
seg[:b_on] = x[a:a + b_on]
f_on = int(8.0 * SR)
seg[:b_on] *= duck_curve(b_on, f_on, 0.87, release=0.03)[:, None]
seg[f_on:f_on + len(stab)] += stab[:len(seg) - f_on]
seg[b_on:] += rec
scenes.append(seg)
silence = np.zeros((int(2.0 * SR), 2))
ctx = np.concatenate([scenes[0], silence, scenes[1], silence, scenes[2]])
peak = np.max(np.abs(ctx))
if peak > 0.89:
    ctx *= 0.89 / peak
mp3(ctx, "stinger_im_rennen_nachtfahrt_polizei_rueckenwind_tank_linke_spur_ziel_rekord.mp3")
report["context_demo_s"] = round(len(ctx) / SR, 1)

# UI sounds
ui_wav = os.path.join(WAV, "ui_klaenge_demo.wav")
if os.path.exists(ui_wav):
    raw = np.fromfile(ui_wav, dtype="<f4", offset=44).reshape(-1, 2).astype(np.float64)
    mp3(raw, "ui_klaenge_demo.mp3")
    spectro(raw, os.path.join(OUT, "ui_klaenge_spektrogramm.png"), [], [], width=1200,
            title="UI-Klänge: 3 x Fokus, Wert ändern, Reiter, Bestätigen, Zurück, Geht nicht (je 0,8 s Pause)")
print(json.dumps(report, indent=1))
