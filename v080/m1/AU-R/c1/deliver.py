"""AU-C1 delivery: MP3s, spectrograms and short descriptions in deliver/AU-C1 (German names).
The marks of the recordings lag the audio by about one block of the dummy audio driver: they are shifted by LEAD_S."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import media  # noqa: E402
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402

S = os.path.dirname(os.path.abspath(__file__))
CAP = os.path.join(S, "cap")
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-C1"
LEAD_S = 0.09
os.makedirs(OUT, exist_ok=True)

ITEMS = [
    ("drive", "fahrt_kiel_hamburg_spielmix", "Probefahrt Kiel – Hamburg im Spielmix (Limousine, Motor v3 + Fahrbahn + Wind + Aufprall, ohne Musik und Verkehr)",
     "Die Abschnitte sind Ausschnitte der echten Strecke nacheinander (Sprünge zwischen ihnen). Autobahn 170 km/h auf Asphalt, ab etwa 5 s "
     "Beton (A7 Holstein, Plattenfugen) – Köhlbrandbrücke mit 120 km/h: Stahldeck und Dehnfugen – A7 mit 125 km/h: nach rechts auf die "
     "profilierte Randlinie und zurück – Bankett rechts (Schotter) – an die Leitplanke: Schlag und Schleifen, von 100 auf 85 km/h – "
     "Hamburger Innenstadt mit 50 km/h über Kopfsteinpflaster (Blöcke wechseln mit Asphalt)."),
    ("drive_road", "fahrt_kiel_hamburg_nur_fahrbahn_und_wind", "Dieselbe Fahrt ohne Motor: nur Fahrbahn, Wind, Fugen, Leitplanke",
     "Gleiche Fahrt und Pegel wie im Spiel, nur die Busse MEngine und MEngineFx stumm – so ist zu hören, was AU-C1 beiträgt."),
    ("layer_belaege", "schicht_belaege_nacheinander", "Beläge nacheinander, Pegel wie im Spiel ohne Motor und Wind",
     "Asphalt 100 km/h – Beton 100 km/h mit Plattenfugen – Stahldeck 100 km/h (mit Brückenfugen) – Kopfsteinpflaster 50 km/h – Bankett "
     "rechts 100 km/h – Gras am Rand 60 km/h – nasser Asphalt 100 km/h – Schnee 80 km/h. Leise Stellen sind auch im Spiel leise "
     "(Asphalt liegt bei 100 km/h etwa 13 dB unter dem Motor)."),
    ("layer_ruettel", "schicht_ruettelstreifen_und_fugen", "Rüttelstreifen, Brückenfugen und Betonplatten bei drei Tempi (ohne Motor und Wind)",
     "Rüttelstreifen rechts bei 60, 120, 200 km/h – Stahlbrücke (Köhlbrandbrücke) mit Fugen bei 60, 120, 200 km/h – Betonplatten bei 90, "
     "140, 200 km/h (der Takt von Vorder- und Hinterachse bleibt bei jedem Tempo exakt)."),
    ("layer_wind", "schicht_wind_50_bis_250", "Wind von 50 bis 250 km/h (ohne Motor und Fahrbahn), dann 250 km/h auf einer Brücke",
     "Drei Bänder mit Böen, ab etwa 200 km/h das Wummern wie bei offenem Fenster; auf der Brücke stärker und böiger. Unter 60 km/h ist "
     "der Wind fast unhörbar (so geplant: 55 dB je Dekade Tempo)."),
    ("layer_quietschen", "schicht_reifenquietschen", "Reifenquietschen und Radieren (ohne Motor und Wind, mit Rollgeräusch)",
     "Untersteuern 0,3 – 0,6 – 1,0 bei 120 km/h – scharfer Spurwechsel – Untersteuern auf nasser Fahrbahn (radiert statt zu quietschen) – "
     "Rutschen beim Unfall."),
    ("layer_aufprall", "schicht_aufprall_nach_tempo_und_partner", "Aufprall nach Schließgeschwindigkeit und Partner, Leitplanke, Leitpfosten (Spielmix mit Motor, 110 km/h)",
     "Rempler (6 km/h) – Auffahren (30 km/h) – schwerer Aufprall 70 und 130 km/h – Lkw 40 und 110 km/h – Leitplanke gestreift, getroffen, "
     "hart – an der Leitplanke entlang schleifen (110 → 60 km/h) – Leitpfosten umgefahren. Seitenrichtig: rechts/links nach Seite des "
     "anderen Fahrzeugs."),
]


def marks_of(name):
    meta = json.load(open(os.path.join(CAP, name + ".json"), encoding="utf-8"))
    raw = meta.get("phases") or meta.get("marks") or []
    out = []
    for m in raw:
        label = str(m.get("label", m.get("name", "")))
        if label in ("ende",):
            continue
        out.append((max(float(m["t"]) - LEAD_S, 0.0), label))
    return out


LABELS = {"autobahn": "Autobahn 170 (Asphalt → Beton)", "bruecke": "Köhlbrandbrücke 120", "ruettelstreifen": "Rüttelstreifen",
          "bankett": "Bankett", "leitplanke": "Leitplanke", "pflaster": "Pflaster Hamburg 50"}

report = {}
for name, stem, title, text in ITEMS:
    path = os.path.join(CAP, name + ".wav")
    x = media.read(path)
    sr = media.SR
    marks = [(t, LABELS.get(lab, lab)) for t, lab in marks_of(name)]
    media.mp3(os.path.join(OUT, stem + ".mp3"), x)
    media.spec(os.path.join(OUT, stem + "_spektrogramm.png"), x, marks, title)
    lufs = qc_lib.integrated_lufs(x, sr)
    tp = qc_lib.true_peak_db(x)
    lines = [title, "", text, "", f"Länge {len(x) / sr:.1f} s, integriert {lufs:.1f} LUFS, True Peak {tp:.1f} dBTP (gemessen, Master bei "
             "Standardreglern, Gesamtlautstärke 0,8).", "", "Zeitmarken:"]
    for t, lab in marks:
        lines.append(f"  {int(t // 60)}:{t % 60:05.2f}  {lab}")
    lines += ["", "Aufgenommen am Master-Bus des Spiels (Godot 4.7.2, Profil Modern, ohne Bildschirm, Dummy-Audiotreiber). "
              "Gehört hat es hier niemand – das Urteil über den Klang liegt beim Nutzer."]
    with open(os.path.join(OUT, stem + ".txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    report[stem] = {"seconds": round(len(x) / sr, 2), "lufs": round(lufs, 2), "true_peak_db": round(tp, 2)}
    print(f"{stem:44s} {len(x) / sr:5.1f} s  {lufs:6.1f} LUFS  {tp:6.1f} dBTP")
json.dump(report, open(os.path.join(OUT, "uebersicht.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
