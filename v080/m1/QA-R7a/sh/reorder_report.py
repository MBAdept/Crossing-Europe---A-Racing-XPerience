#!/usr/bin/env python3
"""QA-R7a: put the sections of bericht.md in order (1, 2, 3, 4, 4b, 4c, 5, 5b, 6, 7, 8, 9, 10) and add the summary."""
import re
p = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7a/bericht.md"
s = open(p).read()
s = s.replace("(Abschnitte 1–4 stehen fest; 5–8 werden ergänzt, sobald die Läufe fertig sind.)\n\n", "")
head, rest = s.split("\n## 1. ", 1)
rest = "## 1. " + rest
parts = re.split(r"\n(?=## )", rest)
sec = {}
order = []
for part in parts:
    m = re.match(r"## (\d+[a-z]?)\.", part)
    key = m.group(1)
    sec[key] = part.rstrip() + "\n"
    order.append(key)
# the roof paragraph was appended after section 10: move it into 5
if "**Grenzdächer mit neuem rechten Endpfeiler**" in sec["10"]:
    a, b = sec["10"].split("\n**Grenzdächer mit neuem rechten Endpfeiler**", 1)
    sec["10"] = a.rstrip() + "\n"
    sec["5"] = sec["5"].rstrip() + "\n\n**Grenzdächer mit neuem rechten Endpfeiler**" + b.rstrip() + "\n"
want = ["1", "2", "3", "4", "4b", "4c", "5", "5b", "6", "7", "8", "9", "10"]
assert set(want) == set(order), order
summary = """
## Kurzfassung

- **Gates grün (gemessen):** `run_tests.sh` 811/0, alle Schritte OK; Render-Prüfungen 28/28 (Geländedeckung T1–T4, S1,
  C1, K1 0,000 %, `start_km0`, `light_base`); `golden.sh check` Arcade 20/20 und 17/17 identisch; `modern_sight --full`
  F1–F3, F7 grün (F2 0,593/0,596/0,555, Hülle 0 von 388.907 Seiten nicht abgedeckt); `modern_path_check --full` grün.
  Alle zehn Regeln des Pakets werden von Tests bewacht (zehn Mutationen, alle rot). Keine Arcade-Datei berührt.
- **Funktion (echte Bauten, 128 Richtungen):** 22.435 Requisiten zurück, 0 neu weg, Stadtzäune 75,3 % statt 64,3 % von
  Arcade, Grenzdach Belgrad → Sofia wieder auf Pfeilern. R7a's Zahlen bestätigt; Bilder byte-gleich nachgerendert.
- **Bild:** deutlich besser als die Basis an T2, S0, München, Hannover, Belgrad, T4, T3, R1 – auch auf „Steam Deck“ und
  nachts; nirgends schlechter als die Basis. Gegen Arcade: gleichwertig bis besser an T2, S0, Städten, R1; schlechter
  bleiben Kurveninnenseiten in den Bergen (T1, T3, T4, Clip) und Stadtkurven (C1-Parkbaum, Belgrads Mauer) – nach A-17
  richtig.
- **Hauptbefund QR7a-01 (hoch):** das strenge Lesen von A-17 (nichts > 0,5 m in der Hülle) hält nach dem Zusammenführen
  nicht: der Requisiten-Builder (R7c) prüft nur den Fuß, 5.630 Requisiten reichen mit Krone/Fassade in die Hülle (Basis
  974), C1 bei 270 m verdeckt in einer Spur mehr. R7a's vorgeschlagene Zeile heilt es (67 Restfälle, C1 6/16/18 px),
  nimmt aber München's Häuserzeile, T4's Felsgruppe und 1.218 Basis-Stücke wieder weg. Vorschlag: hinausschieben statt
  weglassen (97 % der Bäume ≤ 5 m tief) – Entscheidung der Leitung beim Zusammenführen.
- **QR7a-02 (mittel):** Konflikt mit FIX-RINT in `chunk_streamer.gd`; Auflösung mit `_frame_commit_us == 0`.
- Leistung (Deck, Bergstrecke, ×4): `render()` +0,17 ms im Mittel, Vorrechnen 0,18 ms; Laden `collect` bis 21,5 ms.
"""
out = head.rstrip() + "\n" + summary + "\n" + "\n".join(sec[k] for k in want)
out += """
## Stand

Fertig 2026-11-23 ~01:45 UTC. `queue2` (Gates, Bilder) lief in das 2-h-Limit der Hintergrundaufgaben; die Reste liefen
einzeln (`sh/golden.sh`, `sh/rest.sh`, `sh/queue3.sh`). Weggelassen aus Zeitgründen: Deck-Bilder von S0, R1 und
Nachtbilder von T2/R1 (die Tag-/Hoch-Bilder und die echten Bauten decken diese Stellen ab). Große Zwischenstände
(Basis-Kopie, Mutationskopie, Caches, Rohbilder der Verdeckungssonde) gelöscht; Protokolle, Sonden und Ausschnitte
bleiben in `m1/QA-R7a/`.
"""
open(p, "w").write(out)
print("ok", len(out))
