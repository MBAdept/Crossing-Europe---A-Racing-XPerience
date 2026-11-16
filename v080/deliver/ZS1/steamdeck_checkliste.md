# Zwischenstand 1 (v0.8.0-zs1) – Testanleitung für Steam Deck und Windows

Dieser Testbuild ist ein **Zwischenstand** von v0.8.0: Er bringt den neuen Grafikmodus „Modern“ (echtes 3D) neben dem
bekannten Modus „Arcade“. Er lässt deine installierte v0.7.0 **komplett in Ruhe**:

- eigener Name: `CrossingEurope-ZS1.x86_64` (Linux/Steam Deck) bzw. `CrossingEurope-ZS1.exe` (Windows),
- eigene Versionsnummer: unten rechts im Titelbild steht **v0.8.0-zs1**,
- **eigener Ordner für Bestzeiten, Einstellungen, Spielstand und Leistungstest** – deine Rekorde aus v0.7.0 sieht
  dieser Build nicht, und er schreibt nichts in den Ordner von v0.7.0:

| | Testbuild (Zwischenstand 1) | deine v0.7.0 (unverändert) |
|---|---|---|
| Steam Deck / Linux | `/home/deck/.local/share/crossing-europe-zwischenstand/` | `/home/deck/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/` |
| Windows | `%APPDATA%\crossing-europe-zwischenstand\` | `%APPDATA%\Godot\app_userdata\Crossing Europe – A Racing Xperience\` |

(`~/.local/share` ist im Dateimanager Dolphin ein versteckter Ordner: Strg+H blendet ihn ein. Unter Windows:
Windows-Taste + R, `%APPDATA%\crossing-europe-zwischenstand` eingeben, Enter.)

Dateien zum Download: `CrossingEurope-ZS1-linux-x86_64.tar.gz` (Steam Deck und Linux),
`CrossingEurope-ZS1-windows-x86_64.zip` (Windows), dazu `SHA256SUMS` (Prüfsummen) und `LIZENZEN.txt`.
Prüfen (Linux/Deck, im Download-Ordner): `sha256sum -c --ignore-missing SHA256SUMS` – jede heruntergeladene Datei
muss „OK“ melden (`--ignore-missing` überspringt nur die Dateien, die du nicht geladen hast, z. B. das Windows-Archiv).

---------------------------------------------------------------------------------------------------------------------

## A. Auf dem Steam Deck installieren (neben v0.7.0)

Alles im **Desktop-Modus** (Steam-Taste → Ein/Aus → „Zum Desktop wechseln“).

1. `CrossingEurope-ZS1-linux-x86_64.tar.gz` auf das Deck holen (Browser oder USB-Stick) und in einen **eigenen
   Ordner** im Home-Verzeichnis legen, z. B. `/home/deck/Spiele/CrossingEurope-ZS1/` – nicht in den Ordner von v0.7.0.
2. Entpacken: im Dateimanager Dolphin Rechtsklick auf die Datei → „Entpacken“ → „Archiv hierher entpacken“. Danach
   liegen dort `CrossingEurope-ZS1.x86_64` (das ganze Spiel, eine Datei) und `LIZENZEN.txt`.
   Das Archiv behält das Ausführbar-Recht. Nur falls die Datei von einem FAT/exFAT-USB-Stick kopiert wurde:
   Rechtsklick → Eigenschaften → Berechtigungen → „Ausführbar“ anhaken.
3. Steam (im Desktop-Modus) öffnen → unten links **„Spiel hinzufügen“** → **„Ein Nicht-Steam-Spiel hinzufügen …“**
   (englisch „Add a Non-Steam Game“) → „Durchsuchen …“ → `CrossingEurope-ZS1.x86_64` wählen → „Ausgewählte Programme
   hinzufügen“.
4. In der Bibliothek Rechtsklick auf den neuen Eintrag → Eigenschaften: Namen ändern, z. B. in **„Crossing Europe
   ZS1“**, damit er sich von v0.7.0 unterscheidet. Unter **Kompatibilität nichts erzwingen** – **kein Proton**: Der
   Linux-Build läuft nativ.
5. Zurück in den Spielmodus („Zurück zum Spielmodus“ auf dem Desktop). Der Eintrag steht unter Bibliothek →
   „Nicht-Steam“. v0.7.0 bleibt ein eigener Eintrag und bleibt, wie er ist.

Entfernen: den Eintrag in Steam löschen, den Ordner `CrossingEurope-ZS1` und den Ordner
`/home/deck/.local/share/crossing-europe-zwischenstand/` löschen.

## B. Unter Windows installieren (neben v0.7.0)

1. `CrossingEurope-ZS1-windows-x86_64.zip` in einen eigenen Ordner entpacken (Rechtsklick → „Alle extrahieren …“),
   z. B. `C:\Spiele\CrossingEurope-ZS1\`.
2. `CrossingEurope-ZS1.exe` starten. SmartScreen meldet die neue, unsignierte Datei: „Weitere Informationen“ →
   „Trotzdem ausführen“ (wie bei v0.7.0, Einzelheiten in `docs/windows.md`).
3. Zusätzlich einmal mit **ANGLE** starten (Direct3D statt OpenGL – das können wir hier nicht prüfen):
   Rechtsklick auf die `.exe` → „Verknüpfung erstellen“ → Rechtsklick auf die Verknüpfung → Eigenschaften → bei
   **Ziel** hinter die Anführungszeichen ` --rendering-driver opengl3_angle` anhängen → OK → über diese Verknüpfung
   starten.

## C. Was bitte ausprobieren (etwa 20–30 Minuten)

1. **Erster Start im Spielmodus**: Es erscheint einmal **„GRAFIK WÄHLEN“** mit zwei Karten (Arcade, Modern). Bitte
   notieren: Welche Karte ist vorgewählt und trägt „EMPFOHLEN FÜR DIESEN RECHNER“? (Erwartet auf dem Deck: Modern.)
   Mit ◀▶ wechseln, **A** übernimmt. Bitte **Modern** wählen. Danach in Optionen → Seite GRAFIK (mit **R1** blättern)
   nachsehen: Steht „Voreinstellung“ auf **„Steam Deck“**?
2. **Leistungstest**: Optionen → GRAFIK → „Leistungstest“ → „Leistungstest starten“. Er fährt drei feste Szenen von je
   20 s (Autobahn bei Tag, Stadt bei Nacht im Regen, Bergstrecke mit Tunnel); mit Ladezeiten dauert er einige Minuten.
   Die Ergebnisseite zeigt Bilder pro Sekunde und einen Vorschlag. **Bitte die Datei `leistungstest.json` schicken** –
   sie liegt hier:
   - Steam Deck: `/home/deck/.local/share/crossing-europe-zwischenstand/leistungstest.json`
   - Windows: `%APPDATA%\crossing-europe-zwischenstand\leistungstest.json`
   (Der Pfad steht auch auf der Ergebnisseite. Gern auch je einmal mit „Niedrig“, „Mittel“ und „Hoch“, die Datei wird
   bei jedem Lauf überschrieben – also nach jedem Lauf kopieren und umbenennen.)
3. **Kiel – Hamburg in Modern** (Einzelne Etappe oder „Rennen starten“ mit Kiel – Nürnberg) mit der Leistungsanzeige
   des Decks (Taste „…“ → Leistung → Leistungs-Overlay, Stufe 2 oder mehr): Bilder pro Sekunde auf der freien
   Autobahn, in dichtem Verkehr und in Hamburg (Köhlbrandbrücke, City Limits). Ruckelt es, wenn etwas zum ersten Mal
   auftaucht? Gefällt der Look – besser als Arcade, gleich, schlechter? Wo genau?
4. **Kurvenkamera**: In Modern dreht sich die Kamera in Kurven leicht mit (sie schaut ein Stück in die Kurve; in den
   engsten Kurven steht dein Auto dann etwas neben der Bildmitte). Arcade schaut immer stur geradeaus. Bitte nach ein
   paar Kurven entscheiden: **so lassen, stärker oder schwächer?**
5. **Eine Nacht- oder Regenetappe** (Einzelne Etappe, Uhrzeit Nacht, Wetter Regen): Scheinwerfer, Blendung, sind die
   Schilder lesbar, Bilder pro Sekunde. (Hinweis: Regentropfen und Gischt gibt es in Modern noch nicht – siehe
   „Was ist neu“.)
6. **Umschalten**: Optionen → GRAFIK → „Grafik“ auf Arcade und wieder zurück auf Modern. Gilt in den Menüs sofort,
   im Rennen ab der nächsten Etappe. Auf der Seite ALLGEMEIN: „Klang“ (Wie Grafik / Arcade / Modern) und „Musik im
   Rennen“ (An / Aus) – wie klingt Modern gegenüber Arcade, wie gefällt die Musik im Rennen und ihre Lautstärke?
7. **Qualität**: Optionen → GRAFIK → „Voreinstellung“ Niedrig / Mittel / Hoch ausprobieren (wirkt ab der nächsten
   Etappe). Sieht man Unterschiede, wie laufen sie?
8. Nur Steam Deck: **Bildrate 40 oder 45** (Taste „…“ → Leistung) – flüssiger? Akku und Lüfter im Vergleich zu Arcade.
   **Angedockt** an Fernseher/Monitor (1080p), falls möglich. **Standby** mitten in einer Modern-Etappe (Ein/Aus-Taste
   kurz), wieder aufwecken: läuft es weiter?
9. **Alles, was falsch aussieht**: Bildschirmfoto (Steam-Taste + R1) mit Etappe und km aus dem HUD notieren.

Windows zusätzlich: Titel, Fahrzeugwahl, eine Tagesetappe und eine Nacht-Regen-Etappe in Modern – einmal normal und
einmal über die ANGLE-Verknüpfung (Abschnitt B.3).

## D. Was zurückschicken

- `leistungstest.json` (Deck und/oder Windows, Pfade oben),
- die Antworten zu 1, 3, 4 (Kurvenkamera: so lassen / stärker / schwächer), 5 und 6,
- Bildschirmfotos mit Etappe und km,
- bei Abstürzen oder Fehlermeldungen: `logs/godot.log` aus dem Ordner des Testbuilds (Pfade oben) – und ob beim
  nächsten Start die Frage „Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“ kam.

Notfall: Startet Modern nicht oder bleibt schwarz, startet das Spiel beim nächsten Mal von selbst in Arcade und fragt
nach. Von Hand geht es mit dem Startargument `--graphics=arcade` – das Spiel liest es nur **hinter zwei Strichen**
`--` (Steam: Eigenschaften → Startoptionen `-- --graphics=arcade`; Windows: an das Ziel der Verknüpfung hinter die
Anführungszeichen ` -- --graphics=arcade` anhängen, mit den zwei Strichen davor wie bei Steam).
