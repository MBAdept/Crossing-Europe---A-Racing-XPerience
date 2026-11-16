#!/usr/bin/env python3
"""KRITIK-FAHRBAHN: figures for the report (German captions) from results/*.json and the recordings."""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dsp  # noqa: E402
import plotlib as pl  # noqa: E402

DELIVER = os.path.join(os.path.dirname(os.path.dirname(HERE)), "deliver", "KRITIK-FAHRBAHN")
os.makedirs(DELIVER, exist_ok=True)
cap = json.load(open(os.path.join(HERE, "results/capture.json")))
assets = json.load(open(os.path.join(HERE, "results/assets.json")))
imp = json.load(open(os.path.join(HERE, "results/impacts.json")))
C = np.array(cap["third_octaves"]["centres"])
LV = {k: np.array(v) for k, v in cap["third_octaves"]["levels"].items()}
FT = [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]


def tob_chart(path, title, subtitle, series, ylim, note="", shade=True, vlines=()):
    c = pl.Chart(1400, 820, title, subtitle)
    c.axes((20, 20000), ylim, True, FT, list(range(int(ylim[0]), int(ylim[1]) + 1, 10)), "Frequenz (Hz, Terzbänder)",
           "Pegel je Terz (dBFS am Master)", xfmt=pl.freq_label)
    if shade:
        c.shade_x(20, 180, "Kleinlautsprecher:\nunter ~180 Hz kaum Wiedergabe")
        c.axes((20, 20000), ylim, True, FT, list(range(int(ylim[0]), int(ylim[1]) + 1, 10)), "Frequenz (Hz, Terzbänder)",
               "Pegel je Terz (dBFS am Master)", xfmt=pl.freq_label)
    for f, lab in vlines:
        c.vline(f, lab)
    for slot, (label, xs, ys) in enumerate(series):
        c.line(xs, ys, slot, 2, markers=False)
    c.legend([(k, s[0]) for k, s in enumerate(series)])
    if note:
        c.note(note)
    c.save(path)


# 1 -- the game mix at 130 km/h, layer by layer
tob_chart(os.path.join(DELIVER, "abb1_spielmix_130_terzen.png"),
          "Abb. 1 – Spielmix bei 130 km/h auf Asphalt, Schicht für Schicht (Limousine, Gas 0,35)",
          "Terzpegel am Master bei Gesamtlautstärke 0,8, je 20 s konstante Fahrt (gemessen, Kiel – Hamburg km 15). "
          "Über 400 Hz liegt das Rollgeräusch 6–10 dB über Motor + Wind.",
          [("Motor allein", C, LV["asph130_engine"]), ("Reifen/Fahrbahn allein", C, LV["asph130_road"]),
           ("Wind allein", C, LV["asph130_wind"]), ("ganzer Mix", C, LV["asph130_full"]),
           ("ganzer Mix über\nKleinlautsprecher-Modell", C, LV["asph130_full_small"])],
          (-100, -10), "Kleinlautsprecher-Modell (abgeleitet, kein gemessenes Steam Deck): Hochpass 4. Ordnung 200 Hz, +3 dB bei 3 kHz, Tiefpass 14 kHz.")

# 2 -- repetition: envelope autocorrelation in the 0.6-1.6 kHz band
cur = cap["curves"]
c = pl.Chart(1400, 820, "Abb. 2 – Wiederholung bei konstantem Tempo: Selbstähnlichkeit der Hüllkurve (0,6–1,6 kHz)",
             "Autokorrelation der Hüllkurve (10-ms-Rahmen, dB) der Monosumme, gemessen in 20 s Spielmix. Spitzen = der Klang wiederholt "
             "sich nach dieser Zeit.")
c.axes((0, 4), (-0.4, 1.0), False, [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4], [-0.4, -0.2, 0, 0.2, 0.4, 0.6, 0.8, 1.0],
       "Zeitversatz (s)", "Korrelation", xfmt=lambda v: pl.de_num(v, 1), yfmt=lambda v: pl.de_num(v, 1))
c.vline(0.972, "Asphalt L/2 = 0,97 s")
c.vline(1.945, "Asphalt L = 1,95 s")
for slot, (name, lab) in enumerate([("asph130_road", "Reifen allein, Asphalt 130"), ("asph130_full", "ganzer Mix, Asphalt 130"),
                                    ("asph130_engine", "Motor allein, 130"), ("cobbles50_full", "ganzer Mix, Pflaster 50")]):
    lags = np.array(cur[name]["lags"])
    band = np.array(cur[name]["band"])
    c.line(lags[5:], band[5:], slot, 2)
c.legend([(0, "Reifen allein,\nAsphalt 130 km/h"), (1, "ganzer Mix,\nAsphalt 130 km/h"), (2, "Motor allein,\n130 km/h"),
          (3, "ganzer Mix,\nPflaster 50 km/h\n(L/2 = 1,25 s)")])
c.note("Ursache: je Belag zwei Spieler mit derselben Schleife, um die halbe Länge versetzt, gleiche Tonhöhe – die Summe beider Kanäle "
       "ist exakt periodisch mit L/2.")
c.save(os.path.join(DELIVER, "abb2_wiederholung_autokorrelation.png"))

# 3 -- small speakers: loudness change per layer
S = cap["segments"]
rows = [("Motor allein 130 km/h", [S["asph130_engine"]["hp180_db"], S["asph130_engine"]["small_db"]]),
        ("Reifen allein 130 km/h", [S["asph130_road"]["hp180_db"], S["asph130_road"]["small_db"]]),
        ("Wind allein 130 km/h", [S["asph130_wind"]["hp180_db"], S["asph130_wind"]["small_db"]]),
        ("ganzer Mix 130 km/h", [S["asph130_full"]["hp180_db"], S["asph130_full"]["small_db"]]),
        ("Motor allein 200 km/h", [S["asph200_engine"]["hp180_db"], S["asph200_engine"]["small_db"]]),
        ("Reifen + Wind 200 km/h", [S["asph200_roadwind"]["hp180_db"], S["asph200_roadwind"]["small_db"]]),
        ("Rüttelstreifen (nur Fahrbahn) 130", [S["rumble130_road"]["hp180_db"], S["rumble130_road"]["small_db"]]),
        ("Pflaster (nur Fahrbahn) 50 km/h", [S["cobbles50_road"]["hp180_db"], S["cobbles50_road"]["small_db"]]),
        ("Betonplatten-Schleife slab_slow", [assets["loops"]["slab_slow"]["hp180_db"], assets["loops"]["slab_slow"]["small_db"]]),
        ("Wummern wind_buffet", [assets["loops"]["wind_buffet"]["hp180_db"], assets["loops"]["wind_buffet"]["small_db"]]),
        ("Brückenfuge Beton", [assets["oneshots"]["joint_concrete"][0]["hp180_db"], assets["oneshots"]["joint_concrete"][0]["small_db"]]),
        ("Lkw-Schlag truck_boom", [assets["oneshots"]["truck_boom"][0]["hp180_db"], assets["oneshots"]["truck_boom"][0]["small_db"]])]
pl.hbar_chart(os.path.join(DELIVER, "abb3_kleinlautsprecher_pegelverlust.png"),
              "Abb. 3 – Was auf kleinen Lautsprechern übrig bleibt: Lautheitsänderung je Schicht",
              "LUFS nach dem Filter minus LUFS davor (dB; Einmalklänge: Momentanlautheit). Gemessen an Spielmix-Aufnahmen und Dateien; "
              "das Lautsprecher-Modell ist abgeleitet.",
              rows, ["180-Hz-Hochpass 4. Ordnung", "Kleinlautsprecher-Modell"], (-14, 2), [-14, -12, -10, -8, -6, -4, -2, 0, 2],
              "Lautheitsänderung (dB)", note="Lesart: Der Motor verliert bei 130 km/h über kleine Lautsprecher ~12 dB, das Rollgeräusch nichts – "
              "die Balance kippt um etwa 12 dB zugunsten der Fahrbahn.")

# 4 -- rumble strip on small speakers
tob_chart(os.path.join(DELIVER, "abb4_ruettelstreifen_kleinlautsprecher.png"),
          "Abb. 4 – Rüttelstreifen bei 130 km/h (rechte Räder): Grundton 120 Hz und Obertöne",
          "Nur Fahrbahn, Spielmix-Aufnahme 10 s (gemessen); dazu dieselbe Aufnahme durch das Kleinlautsprecher-Modell (abgeleitet).",
          [("Rüttelstreifen, voll", C, LV["rumble130_road"]), ("über Kleinlautsprecher-Modell", C, LV["rumble130_road_small"])],
          (-100, -20), "Der Grundton (120 Hz) fällt um ~18 dB; 2. und 4. Oberton (240/480 Hz) bleiben – der Streifen bleibt hörbar, "
          "verliert aber sein Gewicht (−3,8 LU).", vlines=((120.4, "Grundton v / 0,30 m = 120 Hz"),))

# 5 -- impact layers
SR = 44100
stack130 = np.load(os.path.join(HERE, "results/impact_130_0.npy")).astype(np.float64)
truck110 = np.load(os.path.join(HERE, "results/impact_110_1.npy")).astype(np.float64)
light6 = np.load(os.path.join(HERE, "results/impact_6_0.npy")).astype(np.float64)
c1, L1 = dsp.third_octaves(np.concatenate([stack130, np.zeros(SR)]))
c2, L2 = dsp.third_octaves(np.concatenate([truck110, np.zeros(SR)]))
c3, L3 = dsp.third_octaves(np.concatenate([light6, np.zeros(SR)]))
gl, _ = dsp.load(os.path.join(HERE, "tree/assets/audio/modern/sfx/glass.wav"))
gl = dsp.mono(gl) * 10 ** ((imp["schwer 130 km/h"]["layers"][2][1] + 3.0) / 20.0)
c4, L4 = dsp.third_octaves(np.concatenate([gl, np.zeros(SR)]))
tob_chart(os.path.join(DELIVER, "abb5_aufprall_terzen.png"),
          "Abb. 5 – Aufprall-Schichten, wie die Laufzeit sie stapelt (Spitzenpegel des Plans, mittig)",
          "Terzspektren der gestapelten Dateien (abgeleitet aus Dateien + Konfiguration; Summe über die ganze Klangdauer).",
          [("schwer, 130 km/h\nSchließgeschwindigkeit", c1, L1), ("Lkw, 110 km/h", c2, L2), ("Rempler, 6 km/h", c3, L3),
           ("davon Glas-Schicht\nallein", c4, L4)],
          (-110, -20), "Schwer: 32 % der Energie unter 100 Hz; Glas: Töne 3,0/3,2/4,0/5,8/8,8 kHz mit 21–27 dB Überhöhung (klingende Sinus).")

# 6 -- surfaces as the runtime plays them at their speeds (from the loops, levels of the laws)
cfg = json.load(open(os.path.join(HERE, "tree/config/game_config.json")))["audio"]["modern"]["road"]
man = json.load(open(os.path.join(HERE, "tree/assets/audio/modern/vehicle/manifest.json")))["sounds"]
vmax = 245.0
tyre_top = cfg["engine_top_lufs"]["limousine"] - cfg["tyres"]["under_engine_db"]


def surface_level(s, v):
    slope = cfg["tyres"]["slope_by_surface"].get(s, cfg["tyres"]["slope_db"])
    return tyre_top + cfg["tyres"]["surface_db"].get(s, 0.0) + slope * np.log10(v / vmax)


series = []
for lab, sid, surf, v in [("Asphalt 130 km/h", "tyre_asphalt", "asphalt", 130), ("Beton 130 (ohne Fugen)", "tyre_concrete", "concrete", 130),
                          ("Stahldeck 100", "tyre_deck", "deck", 100), ("Bankett (Schotter) 90", "tyre_gravel", "shoulder", 90),
                          ("Kopfsteinpflaster 50", "tyre_cobbles", "cobbles", 50), ("Asphalt 50 km/h", "tyre_asphalt", "asphalt", 50)]:
    e = man[sid]
    x, _ = dsp.load(os.path.join(HERE, "tree/assets/audio/modern/vehicle", e["file"]))
    y = dsp.mono(x)[e["loop"][0]:e["loop"][1]]
    p = min(max((v / e["ref_kmh"]) ** e["pitch_exp"], 0.15), 3.5)
    z = dsp.resample_pitch(y, p, 4 * SR)
    target = surface_level(surf, v)
    z = z * 10 ** ((target - dsp.lufs_plain(z)) / 20.0)
    cc, LL = dsp.third_octaves(z)
    series.append((lab + f"\n({pl.de_num(target, 1)} LUFS)", cc, LL))
tob_chart(os.path.join(DELIVER, "abb6_belaege_terzen.png"),
          "Abb. 6 – Rollgeräusch je Belag, wie die Laufzeit es abspielt (Limousine, Tempo je Belag typisch)",
          "Schleifen mit der Tonhöhe und dem Pegel der Gesetze (road.tyres.*) gerechnet (abgeleitet aus Dateien + Konfiguration).",
          series, (-110, -30), "Pflaster bei 50 km/h liegt 19 dB über Asphalt bei 50 km/h und so laut wie Asphalt bei ~210 km/h.")
print("Abbildungen ->", DELIVER)
for f in sorted(os.listdir(DELIVER)):
    print("  ", f)
