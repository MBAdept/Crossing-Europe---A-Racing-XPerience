# Referenzbilder („Goldens“)

Seit v0.8.0 hat das Spiel zwei Grafikmodi. **„Arcade“ muss bildgleich mit v0.7.0 bleiben** – das prüft
`tools/golden.sh check` mit zwei Listen (ARCHITECTURE.md §15.6, Bauplan docs/dev/v080_contract.md Regel 2, §4.9.3 und
A-6). Für **„Modern“** gibt es Änderungsmelder: Sie zeigen jede Änderung des Bildes an, sind aber kein Identitätstor
(Vertrag D38). Bedienung und Belege: [docs/qa-v080.md](../../docs/qa-v080.md).

| Datei | Inhalt |
|---|---|
| `arcade_frames.txt` | die 13 Läufe der Rennszene, aus denen die 20 Bilder entstehen: 7 Attract-Szenen (je 4 s und 12 s) und 6 Rennbilder mit vollem HUD an Referenzpositionen. Eine Zeile = Kennung, Aufnahmezeiten, Argumente der Rennszene. |
| `arcade_v070.md5` | MD5-Summen der 20 PNG-Dateien, gerendert mit dem Git-Tag `v0.7.0` (`tools/golden.sh make`) |
| `arcade_ui_frames.txt` | zweite Liste (A-6, seit QA1): 11 Menüs mit Beispieldaten, das Ladebild, ein Etappenstart über GameFlow, das Pausemenü über einer fahrenden Etappe und drei Bilder im Steam-Deck-Fenster 1280×800 – 17 Bilder. Eine Zeile = Kennung, Fenster, Aufnahmezeit, Ziel (`main`, `race`, `pause`, `loading`), Argumente, Maske. |
| `arcade_ui_v070.md5` | MD5 der RGB-Pixel dieser 17 Bilder nach der Maske, gerendert mit `v0.7.0` |
| `ui_shots.gd` | Bildhelfer für Pausemenü und Ladebild; läuft unverändert im Baum von `v0.7.0` (`make` kopiert ihn dorthin) |
| `arcade_v070.env` | womit die Arcade-Listen entstanden: Tag und Commit, Godot-Version, OpenGL-Treiber |
| `modern_frames.txt` | Änderungsmelder für Modern: 6 Bilder des Schnitts Kiel – Hamburg (Start mit Countdown, Tankstelle, freie Autobahn, Köhlbrandbrücke, Ziel, Nacht) in festen Voreinstellungen |
| `modern_slice.md5`, `modern_slice.env` | ihre MD5-Summen, erzeugt aus der Arbeitskopie (`tools/golden.sh modern-make`), und womit |

```
tools/golden.sh check            # beide Arcade-Listen: „GOLDEN arcade: 20 von 20 identisch“, „GOLDEN arcade-ui: 17 von 17 identisch“
tools/golden.sh check race_      # nur die Läufe, deren Kennung „race_“ enthält
KEEP=/tmp/bilder tools/golden.sh check   # Bilder und Protokolle behalten
tools/golden.sh make [race|ui]   # Arcade-Listen neu aus dem Tag v0.7.0 erzeugen (beide: rund 15 Minuten)
tools/golden.sh modern-check     # Modern gegen modern_slice.md5 + OpenGL ES gegen OpenGL („GOLDEN modern-gles“)
tools/golden.sh modern-make      # modern_slice.md5 neu aus der Arbeitskopie (gewollte Änderung von Modern)
tools/golden.sh list             # alle Läufe der drei Listen
tools/golden.sh compare <a> <b>  # verschiedene Pixel je Bild zweier behaltener Ordner
```

- Gerendert wird unter Xvfb mit Software-OpenGL (Mesa llvmpipe), feste 60 Bilder/s, feste Startwerte, mit eigenem leerem
  `XDG_DATA_HOME` je Lauf. Die Rennbilder der ersten Liste nutzen `--shot-fast` (das Bild wird erst 0,1 s vor der
  Aufnahme wieder berechnet) – dieselben Bilder, auf der Test-VM gemessen 153 s statt 725 s. Die zweite Liste und die
  Modern-Liste rendern **jedes** Bild.
- **`--shot-fast` gilt so nur für „Arcade“.** Dort entsteht jedes Bild allein aus dem Spielzustand. In „Modern“
  steht ohne Bild still, was der `RenderingServer` beim Zeichnen selbst fortschreibt, vor allem GPU-Partikel
  (gemessen mit einem Prüfaufbau: 1.307 statt 20.191 helle Pixel nach 114 ausgelassenen Bildern). Die
  Änderungsmelder für „Modern“ rendern deshalb ohne `--shot-fast` (ARCHITECTURE.md §13, Vertrag A-2).
- **Masken der zweiten Liste**: Die ◀▶-Pfeile von Fahrzeugwahl und Startzeit pulsieren mit der Wanduhr
  (`Time.get_ticks_msec()`), der Titel zeigt die Versionsnummer (ändert sich mit dem Release). Diese Rechtecke werden
  vor dem Hash schwarz übermalt; sonst zählt jedes Pixel. Gehasht werden die RGB-Pixel (ImageMagick `rgb:-`), nicht
  die PNG-Datei.
- Die Summen hängen vom Godot-Build und vom OpenGL-Treiber ab. Nach einem Wechsel von Godot oder Mesa: `make` –
  die Arcade-Listen entstehen immer aus dem Tag, nie aus der Arbeitskopie – und `modern-make`. `check` weist darauf
  hin, wenn die Umgebung eine andere ist als in `arcade_v070.env`.
- Ein Arcade-Bild weicht ab: Das Arbeitspaket ist nicht fertig. Die Ursache liegt in einer geteilten Datei
  (Rennsitzung, HUD, Einstellungen, GameFlow, AudioManager) – die eingefrorenen Dateien des Arcade-Renderers ändert
  niemand.
- Ein Modern-Bild weicht ab: Bilder ansehen (`KEEP=<Ordner> tools/golden.sh modern-check`); ist die Änderung gewollt,
  `tools/golden.sh modern-make` und die neue Liste mit der Änderung zusammen committen. Die OpenGL-ES-Stufe (größte
  Kanalabweichung ≤ 2, PSNR ≥ 60 dB gegen das OpenGL-Bild desselben Laufs) muss immer halten.
- Die Bildliste ändern heißt die Summen neu erzeugen: beides gehört zusammen in einen Commit.
