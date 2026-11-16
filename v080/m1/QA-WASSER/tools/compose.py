#!/usr/bin/env python3
"""QA-WASSER: put bericht.md together from the drafts (placeholders replaced)."""
import sys

S = sys.argv[1]
OUT = sys.argv[2]
head = open(S + "/bericht_draft.md", encoding="utf-8").read()
body = open(S + "/bericht_body.md", encoding="utf-8").read()
bef = open(S + "/bericht_befunde.md", encoding="utf-8").read()
ok = open(S + "/bericht_ok.md", encoding="utf-8").read()
rep = {
    "{{URTEIL_GATES}}": "Arcade-Identität 20 von 20 und 17 von 17, Geländesperre grün, der neue Unit-Test ist ein echter "
    "Wächter, und das gelieferte Spielpaket ist Datei für Datei der Commit `0ad9012` (bis auf die vorgesehenen "
    "Testbuild-Einstellungen). Kein Blocker, kein Befund an der Wasser-Behebung; fünf Befunde mittel/niedrig, alle schon im "
    "vorigen Build oder erst durch das jetzt sichtbare Wasser zu sehen – dazu sechs Sätze für die Nutzerdokumente.",
    "{{URTEIL_REPRO}}": "Ein frischer Export des Spielpakets aus dem sauberen `0ad9012` stimmt mit dem gelieferten in "
    "1.010 von 1.011 Dateien überein; anders ist nur `project.binary` (Version und Nutzerordner des Testbuilds).",
    "{{REPRO_ROW}}": "Nachbau: `godot --headless --export-pack` („Linux“ und „Windows Desktop“) aus dem sauberen Worktree "
    "auf `0ad9012`, verglichen mit den gelieferten Programmen (`tools/repro.sh`) | **1.010 von 1.011 Dateien MD5-gleich**, "
    "verschieden nur `project.binary` (1.667 → 1.812 B: Version 0.8.0-zs1 und Nutzerordner, die der Testbuild für den "
    "Export einsetzt) – der Build ist genau `0ad9012`",
    "{{BASELINE_SENK}}": "Gegenprobe aus dem Projekt mit derselben Bildfolge, einmal mit dem alten `far_ground.gd` "
    "(`3a23cb8`), einmal mit dem neuen (`tools/baseline.sh`, `oldnew.py`): Bilder 0,2–1,1 s **pixelgleich**, ab 1,2 s "
    "nur die Zeilen 329–333 (5 Zeilen am Horizont) verschieden, 0,10–0,21 % der Bildpunkte über 8/255, höchstens "
    "27–56/255; der Unterschied wächst über 0,3 s und bleibt dann gleich – **kein Sprung** "
    "(`bilder/projekt_fernboden_sinkt_alt_neu_differenz.jpg`: alt, neu, Unterschied × 4). (Projekt- und Exportbilder "
    "sind nicht pixelgleich, weil der Export über `--stage=` startet und das Projekt die Rennszene direkt – A-2; "
    "verglichen wird darum nur Projekt mit Projekt.)",
    "{{BASELINE_HOLT}}": "Alt gegen neu aus dem Projekt: nur die Zeilen 329–338 (10 Zeilen am Horizont), 0,12–0,23 % der "
    "Bildpunkte über 8/255, höchstens 26/255; vergrößert nicht zu unterscheiden "
    "(`bilder/projekt_holtenau_anfahrt_alt_neu_differenz.jpg`).",
    "{{COVER_SECTION}}": "### 2.8 Löcher? Debug-Ansicht des Geländes am Wasser (gemessen, aus dem Linux-Export)\n\n"
    "`--gfx-debug=cover,far` (Leinwand magenta, kein Nebel, Fernboden cyan, Kragen gelb; `tools/queue4.sh`, "
    "`cover_measure.py`): Köhlbrandbrücke km 77,6–79,0 mit der Steam-Deck-Stufe (1280 × 800, 4 Bilder) und „Hoch“ (4 "
    "Bilder), Holtenau-Anfahrt mit 12,3 m tieferer Scheibe (2 Bilder): **0 magenta Bildpunkte unter dem Horizont** in "
    "allen 10 Bildern (Horizontzeile 360 bzw. 324; an Holtenau verdecken Häuser den Himmel, dort mit fester "
    "Horizontzeile 324 und ohne die HUD-Kästen gemessen). Fernboden und Kragen nur als Linie am Horizont (an vier "
    "Bildern ohne HUD gemessen: cyan ≤ 0,09 %, gelb ≤ 0,29 %). (`bilder/linux_koehlbrand_deck_debug_cover_km78_1.jpg`, "
    "`bilder/linux_holtenau_anfahrt_debug_cover_km75_6.jpg`)",
    "{{COVER_NOTE}}": "meine Messung mit dem Export (2.8) zeigt den Weg: Position „Köhlbrandbrücke km 78,1“ in "
    "`check_terrain_cover.gd`, Grenze 0,2 % Magenta (B5).",
    "{{BEFUNDE}}": bef.strip(),
    "{{OK}}": ok.strip(),
}
text = head.replace("{{REST}}", body)
for k, v in rep.items():
    if k not in text:
        sys.exit("placeholder missing: " + k)
    text = text.replace(k, v)
if "{{" in text:
    sys.exit("unreplaced placeholder left")
open(OUT, "w", encoding="utf-8").write(text)
print("written", OUT, len(text.splitlines()), "lines")
