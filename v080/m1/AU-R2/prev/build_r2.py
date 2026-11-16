#!/usr/bin/env python3
"""AU-R2: the listening samples that change in this round (AU-R's build_deliver.py, restricted): the drive Kiel –
Hamburg before/after and in the game mix; the eight crashes when given. MP3 + description (.txt) each, into the one
set of previews the user gets (deliver/AU-R). Times are audio times (script marks scaled by recording length /
script time – the headless recording runs a few per cent slower than the script under load).
usage: build_r2.py <final dir> <deliver dir> [crash]"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ana  # noqa: E402

FIN, OUT = sys.argv[1], sys.argv[2]
WITH_CRASH = len(sys.argv) > 3 and sys.argv[3] == "crash"
os.makedirs(OUT, exist_ok=True)
SR = ana.SR
GAP_S = 2.0
FOOT = ("Aufgenommen am Master-Bus des Spiels (Godot 4.7.2, Profil Modern, ohne Bildschirm, Dummy-Audiotreiber), "
        "Gesamtlautstärke 0,8 wie im Spiel voreingestellt. Gehört hat es hier niemand – das Urteil über den Klang liegt "
        "beim Nutzer.")


def mmss(t: float) -> str:
    m = int(t // 60)
    return f"{m}:{t - 60 * m:05.2f}"


def load(name: str):
    x = ana.load(os.path.join(FIN, name + ".wav"))
    meta = json.load(open(os.path.join(FIN, name + ".json"), encoding="utf-8"))
    k = (len(x) / SR) / max(float(meta.get("seconds", len(x) / SR)), 1e-6)
    return x, meta, k


def write_wav(path: str, x: np.ndarray) -> None:
    import wave
    y = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())


def mp3(x: np.ndarray, name: str) -> str:
    tmp = os.path.join(OUT, name + ".tmp.wav")
    write_wav(tmp, x)
    dst = os.path.join(OUT, name + ".mp3")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k", dst], check=True)
    os.remove(tmp)
    return dst


def stats(x: np.ndarray) -> str:
    return (f"Länge {len(x) / SR:.1f} s, integriert {ana.lufs(x):.1f} LUFS, True Peak {ana.tp(x):.1f} dBTP "
            f"(gemessen an der WAV vor dem MP3)")


def surfaces_text(meta: dict, k: float, t0: float, phase_from: float, phase_to: float) -> list[str]:
    out = []
    names = {"asphalt": "Asphalt", "concrete": "Beton", "cobbles": "Pflaster", "deck": "Stahldeck", "rumble": "Rüttellinie",
             "shoulder": "Bankett", "grass": "Gras"}
    for s in meta.get("surfaces", []):
        t = float(s["t"])
        if phase_from <= t < phase_to:
            l, r = str(s["surfaces"]).split("/")
            txt = names.get(l, l) if l == r else f"links {names.get(l, l)}, rechts {names.get(r, r)}"
            out.append(f"  {mmss(t0 + t * k)}  unter den Rädern: {txt} (km {float(s['km']):.2f})")
    return out


LABEL = {"autobahn": "Autobahn 170 km/h, Asphalt → Beton (A7 Holstein, Plattenfugen)",
         "bruecke": "Köhlbrandbrücke 120 km/h (Stahldeck, Dehnfugen)", "ruettelstreifen": "Rüttelstreifen (125 km/h)",
         "bankett": "Bankett rechts (Schotter)", "leitplanke": "Leitplanke: Schlag und Schleifen",
         "pflaster": "Hamburger Innenstadt 50 km/h", "ende": "Ende"}


def drive_lines(meta: dict, k: float, t0: float, mark_hamburg: bool) -> list[str]:
    lines = []
    ph = meta["phases"]
    for i, p in enumerate(ph):
        t = float(p["t"])
        lines.append(f"  {mmss(t0 + t * k)}  {LABEL.get(p['name'], p['name'])}")
        if p["name"] == "pflaster" and mark_hamburg:
            nxt = float(ph[i + 1]["t"]) if i + 1 < len(ph) else 1e9
            lines += surfaces_text(meta, k, t0, t - 0.05, nxt)
    return lines


xo, mo, ko = load("drive_old")
xn, mn, kn = load("drive_new")
gap = np.zeros((int(GAP_S * SR), 2))
mp3(np.concatenate([xo, gap, xn]), "fahrt_kiel_hamburg_vorher_nachher")
t_new = len(xo) / SR + GAP_S
txt = ["Fahrt Kiel – Hamburg: vorher (Stand AU-C1, die Fassung, die du gehört hast) – 2 s Stille – nachher (Stand AU-R2)",
       "",
       "Dieselbe geskriptete Fahrt zweimal (Limousine, Motor + Fahrbahn + Wind + Aufprall, ohne Musik und Verkehr): "
       "Autobahn auf Asphalt in den Betonabschnitt, Köhlbrandbrücke, Rüttelstreifen, Bankett, Leitplanke, Hamburger "
       "Innenstadt. Die Betonabschnitte sind in beiden Fahrten dieselben (wie in der Probefahrt von AU-C1).",
       "",
       "Neu in dieser Runde (AU-R2): Die Betonplatten bestehen wieder aus genau den Fugenschlägen, die du bei AU-C1 "
       "gehört hast (nur in längerer, gemischter Folge, damit sich das Muster nicht alle 40 m wiederholt); bei 170 km/h "
       "sind sie knapp 1 dB leiser als in der Runde davor (über 150 km/h werden die Platten langsamer lauter). Auf dem "
       "Hamburger Pflaster fehlen die zwei einzelnen lauten Steine, die rechts alle 7 s wiederkamen.",
       "",
       "Worauf achten: Rollen und Wind wiederholen sich nicht mehr im Sekundentakt (jede Seite eine eigene, längere "
       "Schleife); auf der Köhlbrandbrücke nur noch an den Enden und alle 100 m eine Fuge statt alle 24 m; in Hamburg "
       "wechseln nachher Pflaster und Asphalt (vorher war die ganze Altstadt gepflastert). Die Klangfarbe von Rollen, "
       "Platten und Wind soll gleich geblieben sein.",
       "",
       "Vorher – " + stats(xo), *drive_lines(mo, ko, 0.0, True), "",
       f"Nachher (ab {mmss(t_new)}) – " + stats(xn), *drive_lines(mn, kn, t_new, True), "",
       FOOT]
open(os.path.join(OUT, "fahrt_kiel_hamburg_vorher_nachher.txt"), "w", encoding="utf-8").write("\n".join(txt) + "\n")

xm, mm, km_ = load("drive_mix")
mp3(xm, "fahrt_kiel_hamburg_spielmix_neu")
txt = ["Fahrt Kiel – Hamburg im Spielmix, nachher (Stand AU-R2), mit Rennmusik",
       "",
       "Die Fahrt von „vorher_nachher“ (zweite Hälfte) mit der Rennmusik, wie sie im Spiel liegt (Ducking unter dem "
       "Auto, Renn-EQ). Musik unverändert. In Hamburg wechseln Pflaster und Asphalt (Zeiten unten).",
       "",
       stats(xm), *drive_lines(mm, km_, 0.0, True), "", FOOT]
open(os.path.join(OUT, "fahrt_kiel_hamburg_spielmix_neu.txt"), "w", encoding="utf-8").write("\n".join(txt) + "\n")

if WITH_CRASH:
    xc, mc, kc = load("crash_new")
    mp3(xc, "aufprall_abwechslung_neu")
    LAY = {"hit_heavy": "tiefer Schlag", "hit_light": "Stoßstange", "crunch": "Blech", "glass": "Glas", "debris": "Kleinteile",
           "truck_boom": "Lkw-Aufbau"}
    lines = []
    for m in mc["marks"]:
        if m["label"] == "ende":
            continue
        lay = m.get("layers", [])
        parts = []
        for l in lay:
            nm = LAY.get(str(l[0]), str(l[0]))
            if len(l) >= 6:
                parts.append(f"{nm} V{int(l[1]) + 1} {float(l[4]):+.1f} dB +{float(l[5]):.0f} ms")
            else:
                parts.append(nm)
        glass = any(str(l[0]) == "glass" for l in lay)
        lines.append(f"  {mmss(float(m['t']) * kc)}  {m['label']}: " + ", ".join(parts) + ("" if glass or not lay else " (kein Glas)"))
    txt = ["Acht Unfälle hintereinander, nachher (Stand AU-R2)",
           "",
           "Limousine mit 110 km/h, schwere und mittlere Aufpralle nach Schließgeschwindigkeit, einer gegen einen Lkw. "
           "Je Schicht eine zufällige Variante (V1–V4; V1 ist die Datei von AU-C1), ±2 dB und bis 20 ms später; Glas ab "
           "80 km/h Schließgeschwindigkeit, darunter in 40 % der Unfälle; der tiefe Schlag schwerer Unfälle 2,5 dB leiser "
           "als bei AU-C1, damit der Begrenzer des Modern-Klangs höchstens 3 dB nimmt.",
           "",
           "Neu in dieser Runde (AU-R2): Der Schlag des Lkw-Aufbaus bei schweren Unfällen hat wieder den Pegel von AU-C1 "
           "(in der Runde davor 1 dB leiser – nachgemessen über 60 Unfälle war das nicht nötig).",
           "",
           "Worauf achten: Kein Unfall klingt wie der vorige; die schweren bei 130 km/h haben weiter Wucht.",
           "",
           stats(xc), *lines, "", FOOT]
    open(os.path.join(OUT, "aufprall_abwechslung_neu.txt"), "w", encoding="utf-8").write("\n".join(txt) + "\n")
print("ok", sorted(os.listdir(OUT)))
