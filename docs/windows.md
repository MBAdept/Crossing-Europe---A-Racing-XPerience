# Windows-Version

*Crossing Europe* läuft unter Windows 10 und 11 (64 Bit) als einzelne Programmdatei – dasselbe Spiel wie unter Linux,
aus demselben Projekt mit Godot 4.7.2 gebaut. Diese Seite beschreibt Start, Speicherorte und Prüfsummen, den Bau und
was an der Windows-Fassung geprüft ist (ohne Windows-PC, unter Wine) und was nicht.

## Download und Start

1. `CrossingEurope-windows-x86_64.zip` (rund 120 MB) herunterladen und entpacken – Rechtsklick → „Alle
   extrahieren …“, z. B. nach `C:\Spiele\Crossing Europe\`.
2. `CrossingEurope.exe` (rund 420 MB) starten. Die Datei enthält das ganze Spiel; es wird nichts installiert und
   nichts in die Registrierung geschrieben.

Zum Entfernen die `.exe` löschen, bei Bedarf auch den Ordner mit Spielständen und Einstellungen (siehe unten).

### Warnung „Der Computer wurde durch Windows geschützt“

Die `.exe` ist nicht digital signiert. Windows SmartScreen zeigt deshalb beim ersten Start der heruntergeladenen
Datei einen blauen Hinweis: auf **„Weitere Informationen“** klicken, dann auf **„Trotzdem ausführen“**. Danach
startet das Spiel ohne Nachfrage. Wer sicher sein will, dass die Datei unverändert ist, vergleicht vorher die
Prüfsumme (unten). Den ersten Start kann der Virenscanner um einige Sekunden verzögern, weil er die große Datei prüft.

## Voraussetzungen

- Windows 10 oder 11, 64 Bit (x86_64). Windows auf ARM ist nicht geprüft.
- Grafik mit **OpenGL 3.3** – jede halbwegs aktuelle Grafikkarte oder Prozessorgrafik mit dem Treiber des Herstellers
  (NVIDIA, AMD, Intel).
- **Ohne OpenGL 3.3** schaltet das Spiel von selbst auf **ANGLE** um, OpenGL ES über **Direct3D 11**. ANGLE steckt in
  der `.exe` (Godot 4.7.2, Projekteinstellung `rendering/gl_compatibility/fallback_to_angle` ist an). Godot nimmt ANGLE
  außerdem von vornherein auf älteren Grafikchips mit als fehlerhaft bekannten OpenGL-Treibern (u. a. ältere Intel HD
  Graphics und AMD Radeon HD). Das Bild über ANGLE ist noch nicht geprüft (siehe „Geprüft – und was nicht“).
- Ton über WASAPI (Windows-Standard). Ohne Audiogerät läuft das Spiel stumm.
- Tastatur oder Gamepad (Xbox-Belegung); Steuerung wie unter Linux, Tabelle im [README](../README.md#spielen).

## Bildschirm

- Beim ersten Start richtet sich das Spiel nach dem Bildschirm: Wo ein 1280×720-Fenster samt Titelleiste nicht passt,
  startet es im Vollbild, sonst im Fenster. Die Grenze liegt bei 800 Bildpunkten Höhe, gemessen mit der
  Windows-**Skalierung** (Einstellungen → Anzeige): 1920×1080 bei 150 % zählt wie 1280×720 und startet im Vollbild,
  bei 100 % und 125 % im Fenster.
- Das Fenster wächst mit der Skalierung – 1280×720 bei 100 %, 1600×900 bei 125 %, 2560×1440 bei 200 %, höchstens so
  groß, wie es auf den Bildschirm passt. Ohne das wäre es auf hochauflösenden Notebook-Bildschirmen winzig.
- Optionen → **Vollbild** schaltet um und wird gespeichert. Das Vollbild ist randlos (kein exklusiver Modus).
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
| `settings.json` | Optionen: Lautstärken, Vollbild, Spielername, Filter der Bestenlisten |
| `savegame.json` (+ `.bak`) | laufendes Rennen, nach jeder Etappe gespeichert; `.bak` ist der vorige Stand |
| `leaderboards.json` (+ `.bak`) | Bestenlisten aller Etappen und Rennen |
| `logs\godot.log` | Protokoll des letzten Starts, ältere mit Datum daneben – bei Fehlern mitschicken |
| `shader_cache\` | zwischengespeicherte Shader, darf gelöscht werden |

Zum Sichern den ganzen Ordner kopieren, zum Zurücksetzen löschen. Die Dateien sind dieselben wie unter Linux
(`~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/`) und lassen sich zwischen beiden kopieren.

## Werte und Strecken anpassen

Wie unter Linux: Eine `game_config.json` neben der `CrossingEurope.exe` überschreibt einzelne Werte, eine
`network.json` daneben oder in einem Ordner `data\` daneben ersetzt das Streckennetz (Format im
[README](../README.md#werte-und-strecken-anpassen-ohne-neubau)). Mit dem Windows-Editor gespeicherte Dateien werden
gelesen (UTF-8, auch mit BOM, Zeilenenden CRLF). Unter `C:\Program Files` braucht das Anlegen dieser Dateien
Administratorrechte – ein eigener Ordner wie `C:\Spiele\Crossing Europe\` ist einfacher.

## Prüfsumme kontrollieren

Zu jeder Version gehört die Datei `SHA256SUMS` mit den SHA-256-Prüfsummen aller Downloads. In der PowerShell im
Download-Ordner:

```powershell
Get-FileHash .\CrossingEurope-windows-x86_64.zip -Algorithm SHA256
```

Der angezeigte `Hash` muss mit der Zeile für `CrossingEurope-windows-x86_64.zip` in `SHA256SUMS` übereinstimmen
(PowerShell schreibt Großbuchstaben, `SHA256SUMS` Kleinbuchstaben – das zählt gleich). Automatisch verglichen:

```powershell
$soll = (Select-String -Path .\SHA256SUMS -SimpleMatch 'CrossingEurope-windows-x86_64.zip').Line.Split(' ')[0]
(Get-FileHash .\CrossingEurope-windows-x86_64.zip -Algorithm SHA256).Hash -eq $soll
```

`True` heißt: Die Datei ist unverändert. Für die entpackte `CrossingEurope.exe` steht ebenfalls eine Zeile in
`SHA256SUMS`. Ohne PowerShell geht es in der Eingabeaufforderung mit `certutil -hashfile <Datei> SHA256`.

## Selbst bauen

Gebaut wird unter Linux (auch WSL), ein Windows-PC ist nicht nötig:

```bash
tools/build_windows.sh
```

```bash
tools/build_release.sh
```

`build_windows.sh` schreibt `build/CrossingEurope.exe` und `build/CrossingEurope-windows-x86_64.zip`;
`build_release.sh` baut Linux und Windows, packt dazu `CrossingEurope-linux-x86_64.tar.gz` und schreibt
`build/SHA256SUMS` (prüfen mit `cd build && sha256sum -c SHA256SUMS`). Voraussetzungen: Godot 4.7.2 mit den
Export-Templates (`linux_release.x86_64` und `windows_release_x86_64.exe` in
`~/.local/share/godot/export_templates/4.7.2.stable/`), Python 3, `zip`.

Was dabei passiert:

- **Export** mit der Vorgabe „Windows Desktop“ (`export_presets.cfg`): x86_64, Texturen S3TC/BPTC, dieselben Filter wie
  unter Linux, das PCK in die `.exe` eingebettet (eigener Abschnitt `pck`), Release ohne Konsolenfenster. Eine einzige
  Datei wie unter Linux – es gibt keine `.pck`, die beim Entpacken oder Verschieben verloren gehen könnte.
- **Versionsangaben** der `.exe` (`application/modify_resources`): Datei- und Produktversion bleiben in der Vorgabe leer,
  Godot nimmt dann `application/config/version` aus `project.godot` (aus `0.5.0` wird `0.5.0.0`). Produktname
  „Crossing Europe – A Racing Xperience“, Beschreibung „Crossing Europe – Arcade-Racer quer durch Europa“ (die zeigt
  der Task-Manager). Firma und Copyright bleiben leer.
- **Icon** `assets/icons/app_icon.ico`: 16, 24, 32, 48, 64, 128 und 256 px, die kleinen Größen eigens vereinfacht;
  erzeugt aus `marketing/steam/icon.ico` mit `tools/windows/make_app_icon.py` (bis 128 px als BMP, 256 px als PNG).
  `project.godot` nennt dieselbe Datei als `application/config/windows_native_icon` – so zeigen Fenster und Taskleiste
  das Icon; der Export packt die Datei dafür automatisch ins PCK.
- **Icon-Nacharbeit**: Godot 4.7 übernimmt aus der `.ico` nur 16/32/48/64/128/256 px (die 24 px für die Taskleiste von
  Windows 11 fehlen) und gibt der Icon-Gruppe einen kaputten Namen. `tools/windows/set_exe_icon.py` setzt danach alle
  sieben Größen als Gruppe `GODOT_ICON` ein; Versionsangaben und Manifest bleiben unverändert, die Abschnitte dahinter
  (samt eingebettetem PCK) rücken nach, die Prüfsumme der `.exe` wird neu berechnet.
- **Prüfung**: `tools/windows/inspect_exe.py` kontrolliert Icon, Versionsangaben, GUI-Subsystem und eingebettetes PCK
  (braucht das Python-Modul `pefile`; ohne `pefile` überspringt `build_windows.sh` diesen Schritt).

Ein Export aus dem Godot-Editor unter Windows (Projekt → Exportieren → „Windows Desktop“) funktioniert ebenso, nur fehlen
ohne die Icon-Nacharbeit die 24 px.

## Geprüft – und was nicht

Geprüft ohne Windows-PC – unter Linux mit Wine 9.0 (64-Bit-Präfix), virtuellem Bildschirm (Xvfb) und Software-OpenGL
(Mesa llvmpipe), mit genau der ausgelieferten `.exe` (wegen eines Wine-Fehlers mit abgeschaltetem DirectInput, siehe
„Hinweise zu Wine“):

- Aufbau der `.exe`: x86-64, GUI-Programm ohne Konsolenfenster, Icon mit allen sieben Größen, Versionsangaben,
  eingebettetes PCK; Godot unter Linux startet das Spiel auch aus dem PCK der `.exe` (`--main-pack`).
- Start ohne Fenster (`--headless`) und mit Fenster: keine Skriptfehler, kein `ERROR` in der Ausgabe und in
  `logs\godot.log` – außer der Meldung zum fehlenden Audiogerät (siehe unten).
- Grafik: OpenGL 4.5 über WGL, ANGLE war nicht nötig. Titelbildschirm, Optionen, Rennwahl, Fahrzeug, Startzeit,
  Abfrage „Gespeichertes Rennen überschreiben?“, Etappenbildschirm, Rennen mit Gas und Lenken (auch bei Regen),
  Pausenmenü, Vollbild ein und aus.
- Bedienung über die Tastatur; den Spielernamen tippt man nach Enter auf dem Namensfeld (wie unter Linux).
- `settings.json` und `savegame.json` entstehen im genannten `%APPDATA%`-Ordner (Name mit „–“ und Leerzeichen), ein
  zweiter Start liest sie (Vollbild, Spielername, „Rennen fortsetzen“). Ein neues Rennen ersetzt den Spielstand und
  hinterlässt den alten als `savegame.json.bak`; Umlaute und „–“ in den Dateien bleiben erhalten.
- `game_config.json` und `data\network.json` neben der `.exe` werden geladen (Pfad `C:\Spiele\Crossing Europe\`,
  Dateien mit BOM und CRLF).
- Fenstertitel mit „–“, Fenster-Icon aus der `.ico`; Fenstergröße und Vollbild-Vorgabe bei 100, 125, 150 und 200 %
  Skalierung (in Wine eingestellte DPI 96, 120, 144, 192).
- Ton: Mit Audiogerät startet WASAPI ohne Fehler. Ohne Audiogerät meldet Godot einmal „WASAPI: init_output_device
  error“ und spielt stumm weiter.
- Beenden über das Menü und mit Alt+F4: Rückgabewert 0.

Nicht geprüft:

- ein echter Windows-10/11-PC: SmartScreen-Dialog, Icon im Explorer und in der Taskleiste, Virenscanner, echte
  Skalierung und mehrere Bildschirme;
- echte Grafikkarten und Treiber (NVIDIA, AMD, Intel), Leistung und Bildrate;
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
- Mit einer Sprache ohne UTF-8 (`LANG=C`) kann Wine den Ordner mit „–“ im Namen nicht anlegen; dann z. B.
  `LANG=C.UTF-8` setzen.
- Harmlose Meldungen nur unter Wine: „Failed to enable screen_keep_on“, „Failed to get SDR white level“.
