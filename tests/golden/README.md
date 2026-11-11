# Referenzbilder („Goldens“)

Seit v0.8.0 hat das Spiel zwei Grafikmodi. **„Arcade“ muss bildgleich mit v0.7.0 bleiben** – das prüft
`tools/golden.sh` (ARCHITECTURE.md §15.6, Bauplan docs/dev/v080_contract.md Regel 2 und §4.9.3).

| Datei | Inhalt |
|---|---|
| `arcade_frames.txt` | die 13 Läufe der Rennszene, aus denen die 20 Bilder entstehen: 7 Attract-Szenen (je 4 s und 12 s) und 6 Rennbilder mit vollem HUD an Referenzpositionen. Eine Zeile = Kennung, Aufnahmezeiten, Argumente der Rennszene. |
| `arcade_v070.md5` | MD5-Summen der 20 PNG-Dateien, gerendert mit dem Git-Tag `v0.7.0` (`tools/golden.sh make`) |
| `arcade_v070.env` | womit die Liste entstand: Tag und Commit, Godot-Version, OpenGL-Treiber |
| `modern_*.md5` | (ab Welle 2) Änderungsmelder für „Modern“ – keine Bildgleichheit, sondern Toleranzstufen |

```
tools/golden.sh check            # rendert die 20 Bilder mit der Arbeitskopie, vergleicht: „20 von 20 identisch“
tools/golden.sh check race_      # nur die Läufe, deren Kennung „race_“ enthält
KEEP=/tmp/bilder tools/golden.sh check   # Bilder und Protokolle behalten
tools/golden.sh make             # Liste neu aus dem Tag v0.7.0 erzeugen (jedes Bild wird berechnet, rund 12 Minuten)
tools/golden.sh compare <a> <b>  # verschiedene Pixel je Bild zweier behaltener Ordner
```

- Gerendert wird unter Xvfb mit Software-OpenGL (Mesa llvmpipe), 1280×720, feste 60 Bilder/s, feste Startwerte,
  mit eigenem leerem `XDG_DATA_HOME`. `check` nutzt `--shot-fast` (das Bild wird erst 0,1 s vor der Aufnahme wieder
  berechnet) – dieselben Bilder, auf der Test-VM gemessen 153 s statt 725 s.
- **`--shot-fast` gilt so nur für „Arcade“.** Dort entsteht jedes Bild allein aus dem Spielzustand. In „Modern“
  steht ohne Bild still, was der `RenderingServer` beim Zeichnen selbst fortschreibt, vor allem GPU-Partikel
  (gemessen mit einem Prüfaufbau: 1.307 statt 20.191 helle Pixel nach 114 ausgelassenen Bildern). Die
  Änderungsmelder für „Modern“ (ab Welle 2) rendern deshalb ohne `--shot-fast` oder mit
  `--shot-fast-lead=<s>` von mindestens der längsten Lebensdauer solcher Effekte (ARCHITECTURE.md §13).
- Die Summen hängen vom Godot-Build und vom OpenGL-Treiber ab. Nach einem Wechsel von Godot oder Mesa: `make` –
  die Liste entsteht immer aus dem Tag, nie aus der Arbeitskopie. `check` weist darauf hin, wenn die Umgebung eine
  andere ist als in `arcade_v070.env`.
- Ein Bild weicht ab: Das Arbeitspaket ist nicht fertig. Die Ursache liegt in einer geteilten Datei (Rennsitzung,
  HUD, Einstellungen, GameFlow, AudioManager) – die eingefrorenen Dateien des Arcade-Renderers ändert niemand.
- Die Bildliste ändern heißt die Summen neu erzeugen: beides gehört zusammen in einen Commit.
