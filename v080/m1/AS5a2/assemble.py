"""AS5a2 scratch: assemble deliver/AS5a2/bericht.md from the report parts."""
import os
import re
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2/"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a2/"
HEAD = sys.argv[1]
CLIP = open(S + "cliptext.md").read().strip()


def part(n):
    return open(S + n).read().strip()


kopf = part("bericht_kopf.md").replace("HEADCOMMIT", HEAD).replace("ZUSAMMENFASSUNG", part("zusammenfassung.md"))
ein = part("einordnung_draft.md").replace("### Ehrliche Einordnung", "## 8. Ehrliche Einordnung und schwächster Punkt")
ab = part("bericht_ab.md") + "\n\n" + CLIP

LIEFER = """## 10. Lieferliste (`deliver/AS5a2/`)

| Datei | Inhalt |
|---|---|
| `bericht.md` | dieser Bericht |
| `kontaktbogen_tag.jpg`, `kontaktbogen_nacht.jpg` | alle zwölf Modelle, lod0 und lod1, Tag und Nacht (`tools/models_contact_sheet.sh`) |
| `spielkamera_<stil>_mittag/nacht.jpg` (french, belgian, dutch, swiss, paris) | Spielkamera neben der Straße bei 10 / 30 / 100 / 250 m, darunter das Arcade-Sprite |
| `nahansichten_<stil>_mittag/nacht.jpg` | Fassaden aus der Nähe: Straßenflanke, schräg, vorn (lod0, „Hoch“) |
| `spielkamera_runde5_*.jpg`, `nahansichten_runde5_*.jpg` | Grachtenhäuser B, Eckhaus und Maashaus nach der Korrektur der Runde 5 (ersetzen diese drei in den Stilbildern dutch, belgian, paris; die übrigen Häuser dort sind unverändert) |
| `stufen_G1..G3_mittag/nacht.jpg` | Stufenwechsel lod0 / lod1 bei 60 m, lod1 bei 200 m, Sprite („Mittel“) |
| `toenung_reihenhaeuser_ruhr.jpg` | Tönung `#ead6cc`: Modell, Modell × Tönung, getöntes Sprite, Sprite |
| `umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera, Deckung je Stufe (grün beide, blau nur Sprite, orange nur Modell) |
| `flimmern_messbild.jpg` | Flimmern bei Viertelpixel-Schritten, Modell und Sprite |
| `rennen_<stadt>_<voreinstellung>_<zeit>_00/01.jpg` (26) | A/B im Rennen: links Arcade, rechts Modern, 2 s und 4 s nach dem Start |
| `fahrt_paris_50kmh.mp4` (+ zwei Logs), `fahrt_paris_50kmh_standbilder.jpg` | 10-s-Clip A/B bei 50 km/h, 60 fps, Paris; vier Standbilder daraus |
"""

COMMITS = """## 11. Commits (alle auf `origin/wip/v080-as5a2` gesichert, kein Force-Push)

""" + open(S + "commits.txt").read().strip()

out = "\n\n".join([kopf, part("bericht_pipeline.md"), part("bericht_runden.md"), part("bericht_mess.md"),
                   part("bericht_gates.md"), ab, ein, part("bericht_andere.md"), LIEFER.strip(), COMMITS]) + "\n"
left = re.findall(r"\b(HEADCOMMIT|ZUSAMMENFASSUNG|DOCTABELLE|UMRISS|MESS_LODS|GEOMFINAL|KEYS|DET|TESTS|GOLDEN|MODERN|ABFEHLER|ERGAENZEN|ABTABELLE|ABBEFUND)\b", out)
open(D + "bericht.md", "w").write(out)
print("bericht.md", len(out), "Zeichen; offene Platzhalter:", sorted(set(left)))
