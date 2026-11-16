`tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand` aus dem Schluss-Commit `10d836f` (sauberer Baum),
174 s, mit `tools/build_linux.sh` und `tools/build_windows.sh`. Nur für den Build eingetragen und danach
wiederhergestellt (nicht committet): `config/version="0.8.0-zs1"`, `config/use_custom_user_dir=true`,
`config/custom_user_dir_name="crossing-europe-zwischenstand"`, in `export_presets.cfg` Datei- und Produktversion
`0.8.0.1` (Windows braucht vier Zahlen). Nach dem Build: `project.godot` wieder 0.7.0, `git status` leer.

| Datei | Größe (gemessen) | SHA-256 |
|---|---|---|
| `CrossingEurope-ZS1-linux-x86_64.tar.gz` (`CrossingEurope-ZS1.x86_64` 440,7 MB + `LIZENZEN.txt`) | 146,9 MB (140 MiB) | `e7e2f5e1…e922` |
| `CrossingEurope-ZS1-windows-x86_64.zip` (`CrossingEurope-ZS1.exe` 476,5 MB + `LIZENZEN.txt`) | 156,6 MB (149 MiB) | `b22f1405…a3d7` |

Beide unter 400 MiB (Lieferweg) und unter dem Größentor von `pck_report.py` (Warnung 300, Abbruch 330 MB); Teile des
Windows-Archivs: Vorlage 37,95, Arcade-Sprites 71,07, Arcade-Klang 14,72, UI/Skripte/Daten 3,77, Modern-Modelle 4,64,
-Texturen 5,59, -Klang 11,14, -Musik 7,54 MB. Die `.exe` trägt Icon und Versionsressource (FileVersion/ProductVersion
0.8.0.1, Produktname = Spielname; `inspect_exe.py`). Die Archive sind reproduzierbar (Dateizeiten = Commit-Zeit).
`SHA256SUMS` nennt Archive, Programme und `LIZENZEN.txt` (`sha256sum -c --ignore-missing SHA256SUMS` im Lieferordner: OK).

**Rauchtests** (`tools/smoke_modern.sh`, Echtzeit, Kiel – Hamburg über GameFlow mit `-- --stage=…`, Bilder bei 6 s und
14 s, danach Leistungstest-Szene „autobahn“ 8 s; Belege in `rauchtest/`):

| Plattform | Arcade | Modern | Leistungstest | Nutzerordner |
|---|---|---|---|---|
| Linux-Export, Xvfb, OpenGL 4.5 | OK, 21 s | OK, 96 s | OK, 5,7 fps, Voreinstellung „low“ (selbst gewählt, Stufe software), `game_version` 0.8.0-zs1, Vorschlag Arcade | `$XDG_DATA_HOME/crossing-europe-zwischenstand/` (leistungstest.json, logs, shader_cache) |
| Linux-Export, OpenGL ES 3.2 (`--rendering-driver opengl3_es`, Weg von ANGLE) | OK, 19 s | OK, 106 s; der Wächter senkte im Countdown von Mittel auf Niedrig (richtig für Software-Grafik) | OK, 6,5 fps | wie oben |
| Windows-Export unter wine64 (OpenGL über Mesa; ANGLE/Direct3D hier nicht prüfbar) | OK, 21 s | OK, 97 s | OK, 7,1 fps, 0.8.0-zs1 | `drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand/` = `%APPDATA%\crossing-europe-zwischenstand\` |

**Erster Start wie ein Spieler** (Linux-Export ohne Argumente auf einem 1280 × 800-Xvfb, Tastatur über xdotool,
`chooser_walk.sh`): Auswahl „GRAFIK WÄHLEN“ (Untertitel für neue Spieler – der eigene Ordner ist leer; empfohlen Arcade mit
Warnung „Software-Grafik“) → ▶ Modern → Enter → Titel mit **„v0.8.0-zs1“** unten rechts → Rennen starten → Kiel –
Nürnberg → Limousine → 08:00 → Etappe 1 → Start → Ladebild mit Balken → Kiel – Hamburg in Modern füllt 16:10 → Pause
geht. `settings.json` im eigenen Ordner mit `graphics_mode: "modern"`, `savegame.json` geschrieben. Im Rennen ohne Gas
steht das Auto bei km 0 – und ist **nicht zu sehen** (QA1-B1, Bild `rauchtest/linux_modern_start_km0_ohne_auto.png`).
Die Rauchtestbilder verschiedener Läufe sind nicht pixelgleich vergleichbar (Echtzeit, keine feste Bildrate); den
Vergleich OpenGL ES = OpenGL macht `golden.sh modern-check` mit fester Bildrate (2/255, 73,2 dB).
