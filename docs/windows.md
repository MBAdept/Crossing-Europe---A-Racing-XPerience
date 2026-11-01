# Windows-Version

*Crossing Europe* läuft unter Windows 10 und 11 (64 Bit) als einzelne Programmdatei – dasselbe Spiel wie unter Linux,
aus demselben Projekt mit Godot 4.7.2 gebaut. Diese Seite beschreibt Start, Speicherorte und Prüfsummen, die Hilfe bei
Grafikproblemen, den Bau samt Release und was an der Windows-Fassung geprüft ist (ohne Windows-PC, unter Wine) und was
nicht.

## Download und Start

1. `CrossingEurope-windows-x86_64.zip` (rund 120 MB) herunterladen und entpacken – Rechtsklick → „Alle
   extrahieren …“, z. B. nach `C:\Spiele\Crossing Europe\`.
2. `CrossingEurope.exe` (rund 420 MB) starten. Die Datei enthält das ganze Spiel; es wird nichts installiert. Das Spiel
   legt nur den Ordner für Spielstände und Einstellungen unter `%APPDATA%` an (siehe unten).

Neben der `.exe` liegt `LIZENZEN.txt` mit den Lizenzhinweisen der Godot Engine, der Schriften und der Kartendaten. Zum
Entfernen den Spielordner löschen, bei Bedarf auch den Ordner mit Spielständen und Einstellungen.

### Warnungen beim Herunterladen und beim ersten Start

Die `.exe` ist nicht digital signiert und neu – Windows und Browser sind bei solchen Dateien vorsichtig:

- **Browser:** Edge oder Chrome melden eventuell, die Datei werde selten heruntergeladen. In Edge über „…“ →
  **„Behalten“** (falls nötig „Mehr anzeigen“ → „Trotzdem behalten“), in Chrome **„Behalten“**.
- **SmartScreen** zeigt beim ersten Start „Der Computer wurde durch Windows geschützt“: auf **„Weitere
  Informationen“** klicken, dann auf **„Trotzdem ausführen“**. Danach startet das Spiel ohne Nachfrage.
- **Intelligente App-Steuerung** (Smart App Control, nur Windows 11): Ist sie eingeschaltet, blockiert sie
  unsignierte Programme ohne Ausnahme – einen „Trotzdem ausführen“-Knopf gibt es dann nicht. Sie lässt sich unter
  Windows-Sicherheit → App- & Browsersteuerung → Intelligente App-Steuerung abschalten. Das entscheidet jeder selbst:
  Bei vielen Windows-11-Versionen lässt sie sich danach nur durch Zurücksetzen von Windows wieder einschalten.
- **Virenscanner:** Microsoft Defender oder andere Scanner können eine neue, große, unsignierte `.exe` fälschlich
  melden und in Quarantäne verschieben. Dann zuerst die Prüfsumme vergleichen (unten). Stimmt sie, die Datei unter
  Windows-Sicherheit → Viren- & Bedrohungsschutz → Schutzverlauf wiederherstellen und als Fehlalarm melden:
  <https://www.microsoft.com/wdsi/filesubmission>. Den ersten Start kann der Scanner um einige Sekunden verzögern,
  weil er die große Datei prüft.

Auf Dauer hilft nur eine Code-Signatur (siehe „Release“).

## Voraussetzungen

- Windows 10 oder 11, 64 Bit (x86_64). Windows auf ARM ist nicht geprüft.
- Grafik mit **OpenGL 3.3** – jede halbwegs aktuelle Grafikkarte oder Prozessorgrafik mit dem Treiber des Herstellers
  (NVIDIA, AMD, Intel).
- **Ohne OpenGL 3.3** – alter oder fehlender Grafiktreiber, „Microsoft Basic Display Adapter“, manche virtuelle
  Maschinen – schaltet Godot beim Start von selbst auf **ANGLE** um: OpenGL ES über **Direct3D 11**, das Windows 10/11
  immer mitbringt (notfalls als Software-Grafik). ANGLE steckt in der `.exe`; die Projekteinstellung
  `rendering/gl_compatibility/fallback_to_angle` ist an (Vorgabe von Godot 4.7.2).
- Godot nimmt ANGLE außerdem von vornherein auf Grafikchips, deren OpenGL-Treiber als fehlerhaft bekannt sind (Godots
  Liste `rendering/gl_compatibility/force_angle_on_devices`, u. a. Intel HD Graphics und Iris der Jahre 2011–2017,
  AMD Radeon HD und Radeon R5/R7/R9). Das Bild über ANGLE ist noch nicht auf echtem Windows geprüft (siehe „Geprüft –
  und was nicht“); bei Problemen hilft „Fehlerbehebung: Grafik“.
- Ton über WASAPI (Windows-Standard). Ohne Audiogerät läuft das Spiel stumm.
- Tastatur oder Gamepad (Xbox-Belegung); Steuerung wie unter Linux, Tabelle im [README](../README.md#spielen).

### Fehlerbehebung: Grafik

Welcher Weg genutzt wird, steht in den ersten Zeilen von `logs\godot.log` (Ordner siehe „Spielstände und
Einstellungen“): `OpenGL API 4.6 … NVIDIA …` ist das OpenGL des Grafiktreibers, `OpenGL API OpenGL ES 3.0 (ANGLE …)
… Direct3D11 …` ist ANGLE.

- **Meldung „Unable to initialize video driver“** (englisch, von Godot): Den Grafiktreiber des Herstellers installieren
  (NVIDIA, AMD oder Intel) – der Treiber aus Windows Update oder der „Microsoft Basic Display Adapter“ bringt oft kein
  brauchbares OpenGL mit.
- **Bild fehlerhaft oder schwarz mit OpenGL** (Zeile ohne „ANGLE“): ANGLE erzwingen. Rechtsklick auf
  `CrossingEurope.exe` → „Verknüpfung erstellen“, Rechtsklick auf die Verknüpfung → „Eigenschaften“, im Feld **Ziel**
  hinter `…\CrossingEurope.exe"` ein Leerzeichen und `--rendering-driver opengl3_angle` anfügen, dann das Spiel über die
  Verknüpfung starten.
- **Bild fehlerhaft oder schwarz mit ANGLE** (Zeile mit „ANGLE“, z. B. auf älterer Intel-HD-Grafik): ANGLE
  abschalten. Neben die `.exe` eine Textdatei `override.cfg` legen mit diesem Inhalt:

  ```ini
  [rendering]
  gl_compatibility/fallback_to_angle=false
  ```

  Godot liest diese Datei beim Start und nimmt dann das OpenGL des Grafiktreibers. Wie bei `game_config.json` (unten)
  vorher die Dateinamenerweiterungen einblenden – die Datei darf nicht `override.cfg.txt` heißen. Löschen der Datei
  stellt den Normalzustand wieder her.

## Bildschirm

- Beim ersten Start richtet sich das Spiel nach dem Bildschirm: Wo ein 1280×720-Fenster samt Titelleiste nicht passt,
  startet es im Vollbild, sonst im Fenster. Die Grenze liegt bei 800 Bildpunkten Höhe, gemessen mit der
  Windows-**Skalierung** (Einstellungen → Anzeige): 1920×1080 bei 150 % zählt wie 1280×720 und startet im Vollbild,
  bei 100 % und 125 % im Fenster.
- Das Fenster wächst mit der Skalierung – 1280×720 bei 100 %, 1600×900 bei 125 %, 2560×1440 bei 200 % –, ohne das wäre
  es auf hochauflösenden Notebook-Bildschirmen winzig. Es bleibt samt Titelleiste in der Arbeitsfläche über der
  Taskleiste: Wo 1280×720 nicht hineinpasst (z. B. 1366×768 nach „Vollbild aus“), wird es kleiner, das Bild skaliert
  mit. Ein Fenster, das passt, bleibt, wo der Spieler es hingeschoben hat.
- Optionen → **Vollbild** schaltet um und wird gespeichert – wie alle Optionen auch dann, wenn man das Spiel direkt aus
  den Optionen heraus schließt (X oder Alt+F4). Das Vollbild ist randlos (kein exklusiver Modus).
- Das Rennbild ist 16:9; auf 16:10-Bildschirmen bleiben im Rennen schmale Balken, die Menüs füllen den Bildschirm.

## Spielstände und Einstellungen

Alles, was das Spiel speichert, liegt in

```text
%APPDATA%\Godot\app_userdata\Crossing Europe – A Racing Xperience\
```

also `C:\Users\<Name>\AppData\Roaming\Godot\app_userdata\…`. Am einfachsten Windows-Taste + R drücken,
`%APPDATA%\Godot\app_userdata` eingeben, Enter, dann den Ordner *Crossing Europe – A Racing Xperience* öffnen.

| Datei | Inhalt |
|---|---|
| `settings.json` (+ `.bak`) | Optionen: Lautstärken, Vollbild, Spielername, Filter der Bestenlisten; `.bak` ist der vorige Stand |
| `savegame.json` (+ `.bak`) | laufendes Rennen, nach jeder Etappe gespeichert; `.bak` ist der vorige Stand |
| `leaderboards.json` (+ `.bak`) | Bestenlisten aller Etappen und Rennen |
| `logs\godot.log` | Protokoll des letzten Starts, ältere mit Datum daneben – bei Fehlern mitschicken |
| `shader_cache\` | zwischengespeicherte Shader, darf gelöscht werden |

Alle drei JSON-Dateien werden sicher geschrieben (erst eine Temp-Datei, dann ersetzt); ist eine beschädigt, liest das
Spiel den vorigen Stand aus der `.bak`. Zum Sichern den ganzen Ordner kopieren, zum Zurücksetzen löschen – nur die
Optionen: `settings.json` und `settings.json.bak` löschen. Die Dateien sind dieselben wie unter Linux
(`~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/`) und lassen sich zwischen beiden kopieren.

## Werte und Strecken anpassen

Wie unter Linux: Eine `game_config.json` neben der `CrossingEurope.exe` überschreibt einzelne Werte, eine
`network.json` daneben oder in einem Ordner `data\` daneben ersetzt das Streckennetz (Format im
[README](../README.md#werte-und-strecken-anpassen-ohne-neubau)). Mit dem Windows-Editor gespeicherte Dateien werden
gelesen (UTF-8, auch mit BOM, Zeilenenden CRLF).

- Vorher im Explorer **Dateinamenerweiterungen** einblenden (Windows 11: Ansicht → Anzeigen →
  Dateinamenerweiterungen; Windows 10: Ansicht → Dateinamenerweiterungen). Sonst speichert der Editor leicht
  `game_config.json.txt`, und das Spiel übersieht die Datei.
- Ob die Datei gelesen wurde, steht in `logs\godot.log`: `Config: Overrides geladen aus …` für `game_config.json`,
  `GameData: Streckennetz aus …` für `network.json`.
- Unter `C:\Program Files` braucht das Anlegen dieser Dateien Administratorrechte – ein eigener Ordner wie
  `C:\Spiele\Crossing Europe\` ist einfacher.

## Prüfsumme kontrollieren

Ab v0.5.0 gehört zu jeder Version die Datei `SHA256SUMS` mit den SHA-256-Prüfsummen aller Downloads. In der
PowerShell im Download-Ordner:

```powershell
Get-FileHash .\CrossingEurope-windows-x86_64.zip -Algorithm SHA256
```

Der angezeigte `Hash` muss mit der Zeile für `CrossingEurope-windows-x86_64.zip` in `SHA256SUMS` übereinstimmen
(PowerShell schreibt Großbuchstaben, `SHA256SUMS` Kleinbuchstaben – das zählt gleich). Automatisch verglichen:

```powershell
$soll = (Select-String -Path .\SHA256SUMS -SimpleMatch 'CrossingEurope-windows-x86_64.zip').Line.Split(' ')[0]
(Get-FileHash .\CrossingEurope-windows-x86_64.zip -Algorithm SHA256).Hash -eq $soll
```

`True` heißt: Die Datei ist unverändert. Für die entpackte `CrossingEurope.exe` und `LIZENZEN.txt` stehen ebenfalls
Zeilen in `SHA256SUMS`. Ohne PowerShell geht es in der Eingabeaufforderung mit `certutil -hashfile <Datei> SHA256`.

## Selbst bauen

Gebaut wird unter Linux (auch WSL), ein Windows-PC ist nicht nötig:

```bash
tools/build_windows.sh
```

```bash
tools/build_release.sh 0.5.0
```

`build_windows.sh` schreibt `build/CrossingEurope.exe`, `build/LIZENZEN.txt` und
`build/CrossingEurope-windows-x86_64.zip` (beide Dateien darin) – für Test-Builds. `build_release.sh <Version>` baut
Linux und Windows für ein Release und schreibt zusätzlich `CrossingEurope-linux-x86_64.tar.gz` (Programm und
`LIZENZEN.txt`), `build/SHA256SUMS` (prüfen mit `cd build && sha256sum -c SHA256SUMS`) und `build/BUILDINFO.txt`
(Version, Commit, Godot-Version – für die eigenen Unterlagen, nicht zum Hochladen). Es bricht ab, wenn

- die angegebene Version nicht `config/version` in `project.godot` ist,
- die Arbeitskopie nicht committete Änderungen hat oder der Build Projektdateien ändert (z. B. ein nicht committeter
  Import) – nur dann passen Programme und Commit zusammen; `ALLOW_DIRTY=1` erlaubt Test-Builds,
- das Python-Modul `pefile` fehlt (`pip install pefile`) – ohne es prüft `build_windows.sh` die `.exe` nicht und
  meldet das nur.

Voraussetzungen: Godot 4.7.2 mit den Export-Templates (`linux_release.x86_64` und `windows_release_x86_64.exe` in
`~/.local/share/godot/export_templates/4.7.2.stable/`), Python 3, `zip`, `tar`, `gzip`, `git`.

Was dabei passiert:

- **Export** mit der Vorgabe „Windows Desktop“ (`export_presets.cfg`): x86_64, Texturen S3TC/BPTC, dieselben Filter wie
  unter Linux (`tests/`, `tools/`, `docs/` und `build/` bleiben draußen), das PCK in die `.exe` eingebettet (eigener
  Abschnitt `pck`), Release ohne Konsolenfenster. Eine einzige Datei wie unter Linux – es gibt keine `.pck`, die beim
  Entpacken oder Verschieben verloren gehen könnte.
- **Versionsangaben** der `.exe` (`application/modify_resources`): Datei- und Produktversion bleiben in der Vorgabe leer,
  Godot nimmt dann `application/config/version` aus `project.godot` (aus `0.5.0` wird `0.5.0.0`). Produktname und
  Beschreibung sind der Spielname „Crossing Europe – A Racing Xperience“ – die Beschreibung zeigt Windows als
  Programmnamen im Task-Manager und im Lautstärkemixer. Firma und Copyright bleiben leer; die Sprache der Angaben ist
  bei Godot fest „Englisch (USA)“.
- **Icon** `assets/icons/app_icon.ico`: 16, 24, 32, 48, 64, 128 und 256 px, die kleinen Größen eigens vereinfacht;
  erzeugt aus `marketing/steam/icon.ico` mit `tools/windows/make_app_icon.py` (bis 128 px als BMP, 256 px als PNG).
  `project.godot` nennt dieselbe Datei als `application/config/windows_native_icon` – so zeigen Fenster und Taskleiste
  das Icon; der Export packt die Datei dafür automatisch ins PCK.
- **Icon-Nacharbeit**: Godot 4.7 übernimmt aus der `.ico` nur 16/32/48/64/128/256 px (die 24 px für die Taskleiste von
  Windows 11 fehlen) und gibt der Icon-Gruppe einen kaputten Namen. `tools/windows/set_exe_icon.py` setzt danach alle
  sieben Größen als Gruppe `GODOT_ICON` ein; Versionsangaben und Manifest bleiben unverändert, die Abschnitte dahinter
  (samt eingebettetem PCK) rücken nach, die Prüfsumme der `.exe` wird neu berechnet.
- **Prüfung**: `tools/windows/inspect_exe.py` kontrolliert Icon, Version (bei `build_release.sh` die angegebene),
  Produktname, Beschreibung, GUI-Subsystem und eingebettetes PCK.
- **Lizenzen**: `tools/write_licenses.gd` schreibt `LIZENZEN.txt` – Lizenz der Godot Engine (MIT) und die Hinweise
  ihrer Bestandteile von Dritten, beides aus der Engine selbst, dazu die SIL Open Font License der vier Schriften
  (`assets/fonts/OFL-*.txt`) und den Hinweis zu den Kartendaten (`data/map/LICENSE-world-atlas.txt`). Diese Lizenzen
  verlangen, dass die Hinweise jeder Kopie beiliegen; deshalb liegt die Datei in beiden Archiven.
- **Reproduzierbar**: Gleicher Commit, gleiche Werkzeuge – gleiche Bytes. Die Exporte sind es von selbst, die Archive,
  weil alle Dateizeiten auf die Zeit des letzten Commits gesetzt werden (`SOURCE_DATE_EPOCH`, `zip -X`,
  `tar --sort=name --mtime`, `gzip -n`). So lässt sich jede veröffentlichte Prüfsumme nachbauen.

Ein Export aus dem Godot-Editor unter Windows (Projekt → Exportieren → „Windows Desktop“) funktioniert ebenso, nur fehlen
ohne die Icon-Nacharbeit die 24 px.

## Release

1. Alle Zweige zusammenführen, `config/version` in `project.godot` und das README auf die neue Version bringen,
   committen.
2. Auf genau diesem Commit `tools/build_release.sh 0.5.0` aufrufen (Version wie in `project.godot`).
3. Den Tag `v0.5.0` auf diesen Commit setzen. Zeigt ein schon veröffentlichter Tag auf einen anderen Commit, passen
   Quelltext-Archive und Programme nicht zusammen: den Tag dann nach Absprache verschieben (`git tag -f`, danach
   `git push -f origin v0.5.0`) oder das Release bis zum Hochladen als Entwurf führen.
4. Hochladen – alles aus demselben Lauf, Namen unverändert (die PowerShell-Befehle oben erwarten `SHA256SUMS`):
   `CrossingEurope-windows-x86_64.zip`, `CrossingEurope-linux-x86_64.tar.gz`, `CrossingEurope.x86_64`,
   `CrossingEurope.exe`, `LIZENZEN.txt`, `SHA256SUMS`.
5. Die `.exe` vorher bei VirusTotal prüfen lassen; Fehlalarme von Microsoft Defender bei
   <https://www.microsoft.com/wdsi/filesubmission> melden.
6. Wenn möglich einmal auf einem echten Windows-10/11-PC starten, normal und mit `--rendering-driver opengl3_angle`
   (Titel, Optionen, Etappe 1 bei Tag und bei Nacht mit Regen), und das Ergebnis unten unter „Geprüft“ eintragen.

Auf Dauer: die `.exe` nach `set_exe_icon.py` signieren (das Werkzeug lehnt bereits signierte Dateien ab), mit einem
Code-Signing-Zertifikat oder einem Signaturdienst wie Microsofts Trusted Signing. Dann lässt die intelligente
App-Steuerung das Spiel zu, und die SmartScreen-Warnung verschwindet mit der Zeit.

## Geprüft – und was nicht

Geprüft ohne Windows-PC – unter Linux mit Wine 9.0 (64-Bit-Präfix), virtuellem Bildschirm (Xvfb) und Software-OpenGL
(Mesa llvmpipe), mit genau der ausgelieferten `.exe` (wegen eines Wine-Fehlers mit abgeschaltetem DirectInput, siehe
„Hinweise zu Wine“):

- Aufbau der `.exe`: x86-64, GUI-Programm ohne Konsolenfenster, Icon mit allen sieben Größen, Versionsangaben samt
  Produktname und Beschreibung, eingebettetes PCK; Godot unter Linux startet das Spiel auch aus dem PCK der `.exe`
  (`--main-pack`). Beide Archive enthalten Programm und `LIZENZEN.txt`; zwei Builds desselben Commits ergeben dieselben
  Prüfsummen.
- Start ohne Fenster (`--headless`) und mit Fenster: keine Skriptfehler, kein `ERROR` in der Ausgabe und in
  `logs\godot.log` – außer der Meldung zum fehlenden Audiogerät (siehe unten).
- Grafik: OpenGL 4.5 über WGL. Titelbildschirm, Optionen, Rennwahl, Fahrzeug, Startzeit, Abfrage „Gespeichertes Rennen
  überschreiben?“, Etappenbildschirm, Rennen mit Gas und Lenken (auch bei Regen), Pausenmenü, Vollbild ein und aus.
  Den OpenGL-ES-3-Weg, den ANGLE nach Direct3D 11 übersetzt, zeichnet das Spiel unter Linux (Mesa, OpenGL ES 3.2)
  fehlerfrei – Menü und Rennen bei Nacht mit Regen.
- Bedienung über die Tastatur; den Spielernamen tippt man nach Enter auf dem Namensfeld (wie unter Linux).
- `settings.json` und `savegame.json` entstehen im genannten `%APPDATA%`-Ordner (Name mit „–“ und Leerzeichen), ein
  zweiter Start liest sie (Vollbild, Spielername, „Rennen fortsetzen“). Ein neues Rennen ersetzt den Spielstand und
  hinterlässt den alten als `savegame.json.bak`; Umlaute und „–“ in den Dateien bleiben erhalten. Optionen, die man
  ändert und dann mit Alt+F4 das Spiel schließt, sind beim nächsten Start noch da.
- `game_config.json` und `data\network.json` neben der `.exe` werden geladen (Pfad `C:\Spiele\Crossing Europe\`,
  Dateien mit BOM und CRLF), ebenso eine `override.cfg` neben der `.exe`.
- Fenstertitel mit „–“, Fenster-Icon aus der `.ico`; Fenstergröße und Vollbild-Vorgabe bei 100, 125, 150 und 200 %
  Skalierung (in Wine eingestellte DPI 96, 120, 144, 192); nach „Vollbild aus“ auf 1280×720 und 1366×768 liegt das
  Fenster samt Titelleiste ganz auf dem Bildschirm (auf 1280×720 verkleinert).
- Ton: Mit Audiogerät startet WASAPI ohne Fehler. Ohne Audiogerät meldet Godot einmal „WASAPI: init_output_device
  error“ und spielt stumm weiter.
- Beenden über das Menü und mit Alt+F4: Rückgabewert 0.

Nicht geprüft:

- ein echter Windows-10/11-PC: Warnungen von Browser, SmartScreen, intelligenter App-Steuerung und Virenscanner,
  Icon im Explorer, in der Taskleiste und bei Alt+Tab (Godot gibt Windows dafür das 256-px-Bild, das Windows
  herunterrechnet – unter Wine wirkt es auf 32 px grob), echte Skalierung, Taskleiste und mehrere Bildschirme;
- echte Grafikkarten und Treiber (NVIDIA, AMD, Intel), Leistung und Bildrate, das automatische Umschalten auf ANGLE;
- das Bild über **ANGLE/Direct3D 11**: ANGLE startet unter Wine (mit dessen Direct3D 11), zeichnet dort aber nur
  Schwarz, weil Wines Shader-Compiler die Geometrie-Shader von ANGLE nicht übersetzt; unter Windows übersetzt sie
  Microsofts Compiler;
- Gamepads (DirectInput war unter Wine abgeschaltet, siehe unten) und Ton auf echter Hardware;
- Umlaute über die Tastatur: Das Testwerkzeug konnte sie unter Wine nicht tippen.

### Hinweise zu Wine

Unter Linux ist die Linux-Version die richtige Wahl. Wer die Windows-Fassung trotzdem mit Wine startet:

- **Wine 9.0 stürzt beim Start jedes Godot-4.7.2-Windows-Programms ab** („Unhandled page fault“, schon bei
  `--version`): Godot passt beim Start die Importtabelle von `dinput8.dll` an und ruft dabei `VirtualProtect` ohne
  Zeiger für den alten Speicherschutz auf. Windows lehnt das nur ab, Wine 9.0 greift auf den Zeiger zu. Abhilfe:
  DirectInput abschalten – `WINEDLLOVERRIDES="dinput8=d" wine CrossingEurope.exe`.
- Unter Wine überspringt Godot die Wahl von ANGLE (Treiberliste und Umschalten ohne OpenGL 3.3): Ohne OpenGL 3.3 vom
  Linux-Treiber endet der Start dort mit „Unable to initialize video driver“, und `--rendering-driver opengl3_angle`
  zeigt nur ein schwarzes Bild (siehe oben).
- Mit einer Sprache ohne UTF-8 (`LANG=C`) kann Wine den Ordner mit „–“ im Namen nicht anlegen; dann z. B.
  `LANG=C.UTF-8` setzen.
- Harmlose Meldungen nur unter Wine: „Failed to enable screen_keep_on“, „Failed to get SDR white level“.
