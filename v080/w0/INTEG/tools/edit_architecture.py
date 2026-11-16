#!/usr/bin/env python3
"""Integration helper (not part of the repository): replaces the status paragraph of ARCHITECTURE.md §15 with the
state of the merged wave 0 (pointers to the documentation of the three other packages)."""
import sys

PATH = sys.argv[1]
OLD = """**Stand Welle 0 (Gerüst):** Einstellungen, Modus-Auflösung, die Naht in der Rennsitzung, Werkzeuge und Prüfungen sind
fertig; der Modern-Renderer ist ein Gerüst (Kamera mit Arcades Projektion, Himmelsfarbe über eine Canvas-Ebene, eine
graue Ebene). Auswahlbildschirm, Optionen, Showroom, Klangprofil „Modern“ und der eigentliche Renderer folgen in
den nächsten Wellen und halten sich an die Schnittstellen dieses Abschnitts.
"""
NEW = """**Stand Welle 0 (Gerüst):** Einstellungen, Modus-Auflösung, die Naht in der Rennsitzung, Werkzeuge und Prüfungen sind
fertig; der Modern-Renderer ist ein Gerüst (Kamera mit Arcades Projektion, Himmelsfarbe über eine Canvas-Ebene, eine
graue Ebene). Daneben stehen die Kerne der drei anderen Bereiche, jeder mit eigener Dokumentation:

- **Geometrie-Kern des Renderers** (`scripts/race3d/`: Pfad der Straße im Raum, Kamera, Geländeprofil,
  Stück-Streamer, Fairness-Prüfungen des ganzen Netzes) – [docs/renderer-modern.md](docs/renderer-modern.md). Das
  Renderer-Gerüst benutzt ihn noch nicht.
- **Modell-Pipeline** (`ModelDB`, `ModernMaterials`, `ModelFactory`, Shader in `assets/shaders/modern/`) mit sechs
  Referenzmodellen; jedes Sprite-Set außer `ui/*` hat in `assets/models/manifest.json` einen Eintrag (Modell oder
  Platzhalter) – [docs/modelle.md](docs/modelle.md).
- **Audio-Kern des Klangprofils „Modern“** (`ModernAudio` hinter dem `AudioManager`, eigene Busse, Pegelplan; die
  Bausteine spielen vorerst den Arcade-Klang über die Modern-Busse) – [docs/audio-modern.md](docs/audio-modern.md).
  Bis `GameFlow` das gespeicherte Profil setzt (Welle 2), ist es nur über `--sound=modern` oder den
  Konfigurationswert `audio.profile` zu hören.

Auswahlbildschirm, Optionen, Showroom, die Klänge und die Musik von „Modern“ und der eigentliche Renderer folgen in
den nächsten Wellen und halten sich an die Schnittstellen dieses Abschnitts.
"""

text = open(PATH, encoding="utf-8").read()
if text.count(OLD) != 1:
    print("Absatz nicht (genau einmal) gefunden: %d" % text.count(OLD))
    sys.exit(1)
open(PATH, "w", encoding="utf-8", newline="\n").write(text.replace(OLD, NEW))
print("ersetzt")
