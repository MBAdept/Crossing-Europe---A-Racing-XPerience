#!/usr/bin/env python3
"""Pictures of the review KRITIK-MISCHUNG (German captions). usage: figures.py <K> <deliver dir>"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib  # noqa: E402
import masking as mk  # noqa: E402
from plot import Chart, PAL  # noqa: E402

K, D = sys.argv[1], sys.argv[2]
R = json.load(open(os.path.join(K, "res", "files.json")))
FC = list(alib.THIRD_CENTERS)
PIECES = [("REF_title_v050", "Titelmelodie v0.5.0 (Referenz)", PAL[0], False),
          ("titel_remaster", "Titel-Remaster", PAL[1], False),
          ("linke_spur", "Linke Spur", PAL[2], False),
          ("nachtfahrt", "Nachtfahrt", PAL[3], False),
          ("rueckenwind", "Rückenwind", PAL[4], False),
          ("zwischenspiel", "Zwischenspiel", PAL[7], True)]


def seg(n):
    r = R[n]
    return r.get("loop") or r["all"]


def at_m14(n):
    s = seg(n)
    return np.array(s["thirds_db"]) - (s["lufs_i"] + 14.0)


def fig_spectrum():
    ref = at_m14("REF_title_v050")
    off = ref[FC.index(1000)]
    c = Chart(title="Langzeit-Terzspektrum bei gleicher Lautheit (−14 LUFS)", yr=(-40, 15), xr=(20, 20000),
              xlabel="Frequenz (Hz)", ylabel="Pegel je Terz (dB, Referenz bei 1 kHz = 0)",
              caption="Gemessen an den ausgelieferten Dateien (Ogg Vorbis), bei Schleifenstücken nur die Schleife. Alle Stücke auf "
                      "dieselbe Lautheit gebracht. Gegenüber der Titelmelodie von v0.5.0 haben alle neuen Stücke mehr Tiefbass "
                      "(40–60 Hz), weniger tiefe Mitten (200–800 Hz) und deutlich mehr Höhen über 4 kHz – die „Lächelkurve“ des "
                      "neuen Masters. Das Zwischenspiel ist absichtlich weicher.", legend_cols=1)
    for n, lab, col, dash in PIECES:
        c.line(FC, list(at_m14(n) - off), col, lab, 4 if n == "REF_title_v050" else 3, dash)
    c.save(os.path.join(D, "bild_1_terzspektrum_gegen_referenz.png"), "bl")


def fig_delta():
    ref = at_m14("REF_title_v050")
    c = Chart(title="Abweichung von der Titelmelodie v0.5.0 je Terz (gleiche Lautheit)", yr=(-10, 14), xr=(20, 20000),
              xlabel="Frequenz (Hz)", ylabel="dB gegenüber der Referenz", yticks=list(range(-10, 15, 2)), cap_lines=4,
              caption="Positiv = das neue Stück hat dort mehr Energie als die Titelmelodie, die der Nutzer liebt. Unter 31 Hz "
                      "schneidet der neue Master (Hochpass 24 Hz). Über 5 kHz liegen alle neuen Stücke 3–7 dB höher – auf "
                      "Kopfhörern über Stunden die wahrscheinlichste Quelle für „zu schrill“ (abgeleitet). Die Terz um 50 Hz liegt "
                      "10–11 dB höher (gefalteter Sub-Bass und Sub-Kick), 63–80 Hz +0,5 bis +1,5 dB, 40 Hz −8 dB – die "
                      "wahrscheinlichste Quelle für „zu viel Bass“ auf Kopfhörern (abgeleitet).")
    c.hline(0, "#444")
    for n, lab, col, dash in PIECES[1:]:
        c.line(FC, list(at_m14(n) - ref), col, lab, 3, dash)
    c.save(os.path.join(D, "bild_2_abweichung_zur_referenz.png"), "tl")


def fig_stereo():
    bands = ["lt120", "120_500", "500_2k", "2k_5k", "5k_10k", "gt10k"]
    labels = ["< 120 Hz", "120–500", "0,5–2 k", "2–5 k", "5–10 k", "> 10 k"]
    series = [(lab, [seg(n)["stereo"][b]["corr"] for b in bands]) for n, lab, _c, _d in PIECES]
    c = Chart(title="Stereo: Korrelation links/rechts je Band", xlog=False, xr=(0, 6), yr=(0, 1.0),
              ylabel="Korrelation (1 = mono, 0 = unabhängig)", yticks=[0, 0.2, 0.4, 0.6, 0.8, 1.0], xticks=[],
              caption="Unter 120 Hz sind alle Stücke mono (1,00) – kein gegenphasiger Bass, gut für Kopfhörer und Lautsprecher. "
                      "Zwischen 2 und 10 kHz sind die neuen Stücke viel breiter als die Referenz (0,19–0,29 gegen 0,45–0,61): "
                      "der Seitenanteil liegt nur 1,6–2,6 dB unter der Mitte. Auf Kopfhörern wirkt das breit und luftig, kann "
                      "über Stunden aber „zischelig“ wirken (abgeleitet).", legend_cols=2)
    c.bars(labels, series, [p[2] for p in PIECES], ymin=0)
    c.save(os.path.join(D, "bild_3_stereo_korrelation.png"), "tr")


def fig_game_levels():
    ph = ["idle", "v80", "v130", "v130_full", "v200_full", "v250_full"]
    labs = ["Leerlauf", "80 km/h", "130 km/h", "130 Vollgas", "200 Vollgas", "250 Vollgas"]
    car = json.load(open(os.path.join(K, "cap", "gt_car.wav.phases.json")))["phases"]
    sw = json.load(open(os.path.join(K, "cap", "sw_car.wav.phases.json")))["phases"]
    mus = json.load(open(os.path.join(K, "cap", "gt_music.wav.phases.json")))["phases"]
    wind = json.load(open(os.path.join(K, "cap", "gt_wind.wav.phases.json")))["phases"]
    c = Chart(title="Spielmix am Master: Auto und Rennmusik je Fahrzustand", xlog=False, xr=(0, 6), yr=(-32, -12),
              ylabel="Lautheit (LUFS, Standardregler)", xticks=[], yticks=list(range(-32, -11, 2)),
              caption="Gemessen im Spiel (Godot 4.7.2, Dummy-Treiber, echte Strecke Kiel – Hamburg, Asphalt, ohne Verkehr). "
                      "Musik = „Linke Spur“ allein über die Kette (Renn-EQ, Ducking). Bei 80 km/h liegt die Musik 2,6 dB ÜBER dem "
                      "Auto, bei 130 km/h gleichauf, unter Vollgas 7,4–8,0 dB darunter (Plan D29: 8 dB). Wind allein bei 80/130 km/h "
                      "unter −38 LUFS (nicht gezeichnet).", legend_cols=2)
    series = [("Auto Gran Turismo", [car[p]["lufs"] for p in ph]), ("Auto Sportwagen", [sw[p]["lufs"] for p in ph]),
              ("Musik (Linke Spur)", [mus[p]["lufs"] for p in ph]),
              ("nur Wind (GT)", [wind[p]["lufs"] if wind[p]["lufs"] > -32 else None for p in ph])]
    c.bars(labs, series, [PAL[0], PAL[7], PAL[2], PAL[3]], ymin=-32)
    c.save(os.path.join(D, "bild_4_spielmix_pegel.png"), "tl")


def fig_masking_bands():
    M = json.load(open(os.path.join(K, "res", "masking.json")))
    sec = M["sections"]["linke_spur"]["B1"]["phases"]
    fcb = list(mk.FC)
    c = Chart(title="Hook „Linke Spur“ (B1) gegen das Auto: Abstand zur Mithörschwelle je Frequenzgruppe",
              yr=(-30, 30), xr=(50, 16000), xlabel="Frequenz (Mitte der Frequenzgruppe, Hz)",
              ylabel="Musik über (+) / unter (−) der Mithörschwelle (dB, Median)", yticks=list(range(-30, 31, 10)),
              caption="Maskierungsmodell (Johnston/MPEG-1 Modell 1, vereinfacht, besseres Ohr) mit dem gemessenen Auto "
                      "(Gran Turismo, Motor + Reifen + Wind) und der Musik so, wie die Kette sie spielt. Über 0 dB ist die "
                      "Musik in diesem Band hörbar. Melodiebereich 510 Hz – 3,2 kHz grau markiert. Bei 130 km/h Teillast liegt "
                      "der Hook dort 6–13 dB über der Schwelle, unter Vollgas bis 2 kHz 2–9 dB darunter; Kick/Bass (< 200 Hz) "
                      "und Hi-Hats (> 5 kHz) bleiben hörbar (abgeleitet aus Messwerten).", legend_cols=1, cap_lines=4)
    x0, x1 = c.px(510), c.px(3150)
    c.d.rectangle([x0, c.T + 1, x1, c.B - 1], fill="#f1f1f1")
    c.hline(0, "#444")
    for (ph, lab, col) in (("v80", "80 km/h", PAL[3]), ("v130", "130 km/h (Teillast)", PAL[2]),
                           ("v130_full", "130 km/h Vollgas", PAL[1]), ("v200_full", "200 km/h Vollgas", PAL[4]),
                           ("v250_full", "250 km/h Vollgas", PAL[0])):
        c.line(fcb[:-1], sec[ph]["gt_car"]["0.0"]["smr_band_hp"][:-1], col, lab, 3)
    c.save(os.path.join(D, "bild_5_maskierung_hook_je_band.png"), "bl")


def fig_sweep():
    M = json.load(open(os.path.join(K, "res", "masking.json")))
    S = M["sections"]
    offs = ["-6.0", "-4.0", "-2.0", "0.0", "2.0", "4.0", "6.0"]
    c = Chart(title="Welcher Musikpegel? Hörbarkeit der Melodie und des Motors", xlog=False, xr=(-6, 6), yr=(0, 104),
              xlabel="Musik im Rennen gegenüber heute (dB)", ylabel="hörbarer Anteil (%)",
              xticks=[-6, -4, -2, 0, 2, 4, 6], xticklabels=["−6", "−4", "−2", "0 (heute)", "+2", "+4", "+6"],
              yticks=list(range(0, 101, 10)),
              caption="Durchgezogen: Anteil der Melodie-Energie (510 Hz – 3,2 kHz) über der Mithörschwelle des Autos, Mittel über "
                      "alle Abschnitte der drei Rennstücke (Gran Turismo). Gestrichelt: Anteil der Motor-Energie (< 1,1 kHz) über "
                      "der Mithörschwelle der Musik. Unter Vollgas ist heute nur gut ein Viertel bis zwei Fünftel der Melodie "
                      "hörbar; +3 dB unter Vollgas heben das auf etwa die Hälfte, der Motor bleibt zu ≥ 99 % hörbar (abgeleitet).",
              legend_cols=1)
    for ph, lab, col in (("v130", "130 km/h Teillast", PAL[2]), ("v130_full", "130 km/h Vollgas", PAL[1]),
                         ("v200_full", "200 km/h Vollgas", PAL[4]), ("v250_full", "250 km/h Vollgas", PAL[0])):
        mel, car = [], []
        for o in offs:
            vals, cv = [], []
            for piece in S:
                for sname, v in S[piece].items():
                    if sname == "Einzähler":
                        continue
                    r = v["phases"][ph]["gt_car"][o]
                    vals.append(r["mel_hp"])
                    cv.append(r["car_aud_hp"])
            mel.append(100 * float(np.mean(vals)))
            car.append(100 * float(np.mean(cv)))
        c.line([float(o) for o in offs], mel, col, "Melodie " + lab, 4)
        c.line([float(o) for o in offs], car, col, "Motor " + lab, 3, True)
    c.save(os.path.join(D, "bild_6_pegel_sweep.png"), "br")


def fig_knobs():
    kn = json.load(open(os.path.join(K, "res", "knobs.json")))
    c = Chart(title="Gemessene Wirkung der Knöpfe in mischung.json (Skizze „Linke Spur“, 16 Takte)", yr=(-6, 6),
              xr=(20, 20000), xlabel="Frequenz (Hz)", ylabel="Änderung je Terz bei gleicher Lautheit (dB)",
              yticks=list(range(-6, 7, 1)),
              caption="Jede Kurve: dieselbe Skizze mit einem geänderten Wert, gerendert mit der Kette des Projekts (in einer "
                      "Kopie), auf −14 LUFS normiert, minus die Skizze mit allen Werten 0. Der Master gleicht die Lautheit nach: "
                      "was unten weggenommen wird, kommt in der Mitte leicht dazu. sub_db wirkt nur auf 40–50 Hz, bass_db fast gar "
                      "nicht; der Basshöcker bei 63 Hz (Kick) hat keinen Knopf. Schwarz: ein Kuhschwanzfilter im Master, den es "
                      "in mischung.json noch nicht gibt (in der Kopie gemessen).", legend_cols=1, cap_lines=4)
    c.hline(0, "#444")
    names = [("sub_m3", "sub_db −3", PAL[2]), ("sub_p3", "sub_db +3", PAL[5]), ("bass_m3", "bass_db −3", PAL[3]),
             ("hs_m2_6k", "high_shelf_db −2 (6 kHz)", PAL[4]), ("hs_m3_4k", "high_shelf_db −3 (4 kHz)", PAL[1]),
             ("sub_m6", "sub_db −6", PAL[6]), ("ls120_m3", "Vorschlag low_shelf −3 dB bei 120 Hz (Experiment)", PAL[0])]
    for v, lab, col in names:
        if v in kn and "delta_thirds_db" in kn[v]:
            c.line(FC, kn[v]["delta_thirds_db"], col, lab, 3)
    c.save(os.path.join(D, "bild_7_knopf_wirkung.png"), "tr")


def fig_shortterm():
    c = Chart(title="Kurzzeit-Lautheit (3 s) über die Datei", xlog=False, xr=(0, 210), yr=(-26, -10),
              xlabel="Zeit (s)", ylabel="LUFS (Datei)", xticks=list(range(0, 211, 30)), yticks=list(range(-26, -9, 2)),
              caption="Gemessen an den Dateien (−14 LUFS integriert). Jedes Rennstück hat einen Breakdown (D), der für etwa 10 s "
                      "5–6 LU unter die Schleife fällt (Linke Spur, Rückenwind bis −20,5, Nachtfahrt −19,3 LUFS); sonst liegen "
                      "„Linke Spur“ und „Rückenwind“ sehr gleichmäßig um −14 (LRA 2,2 LU), „Nachtfahrt“ schwankt mehr (LRA 3,6 LU). "
                      "Die Titelmelodie v0.5.0 (LRA 4,6 LU) atmet stärker.", legend_cols=2, cap_lines=4)
    for n, lab, col, dash in PIECES:
        x = alib.read_audio(os.path.join(K, "copy", R[n]["file"]))
        st = alib.Loud(x).short_term(0.5)
        t = np.arange(len(st)) * 0.5 + 1.5
        c.line(list(t), list(st), col, lab, 2 if n != "REF_title_v050" else 3, dash)
    c.save(os.path.join(D, "bild_8_kurzzeitlautheit.png"), "br")


if __name__ == "__main__":
    which = sys.argv[3:] or ["spectrum", "delta", "stereo", "game", "maskbands", "sweep", "knobs", "shortterm"]
    for w in which:
        {"spectrum": fig_spectrum, "delta": fig_delta, "stereo": fig_stereo, "game": fig_game_levels,
         "maskbands": fig_masking_bands, "sweep": fig_sweep, "knobs": fig_knobs, "shortterm": fig_shortterm}[w]()
        print("Bild", w, flush=True)
