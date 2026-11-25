# Zwischenstand 2 (v0.8.0-zs2) – Testanleitung für Steam Deck und Windows

Dieser Testbuild ist ein **Zwischenstand** von v0.8.0: Er bringt den neuen Grafikmodus „Modern“ (echtes 3D) neben dem
bekannten Modus „Arcade“. Er lässt deine installierte v0.7.0 **komplett in Ruhe**:

- eigener Name: `CrossingEurope-ZS2.x86_64` (Linux/Steam Deck) bzw. `CrossingEurope-ZS2.exe` (Windows),
- eigene Versionsnummer: unten rechts im Titelbild steht **v0.8.0-zs2**,
- **eigener Ordner für Bestzeiten, Einstellungen, Spielstand und Leistungstest** – deine Rekorde aus v0.7.0 sieht
  dieser Build nicht, und er schreibt nichts in den Ordner von v0.7.0:

| | Testbuild (Zwischenstand 1 und 2) | deine v0.7.0 (unverändert) |
|---|---|---|
| Steam Deck / Linux | `/home/deck/.local/share/crossing-europe-zwischenstand/` | `/home/deck/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/` |
| Windows | `%APPDATA%\crossing-europe-zwischenstand\` | `%APPDATA%\Godot\app_userdata\Crossing Europe – A Racing Xperience\` |

Zwischenstand 2 benutzt **denselben Ordner wie Zwischenstand 1**: Bestzeiten, Einstellungen (auch die gewählte Grafik
und Voreinstellung) und der letzte Leistungstest aus Zwischenstand 1 bleiben erhalten. Den Eintrag von Zwischenstand 1
in Steam kannst du löschen oder durch Zwischenstand 2 ersetzen.

(`~/.local/share` ist im Dateimanager Dolphin ein versteckter Ordner: Strg+H blendet ihn ein. Unter Windows:
Windows-Taste + R, `%APPDATA%\crossing-europe-zwischenstand` eingeben, Enter.)

Dateien zum Download: `CrossingEurope-ZS2-linux-x86_64.tar.gz` (Steam Deck und Linux),
`CrossingEurope-ZS2-windows-x86_64.zip` (Windows), dazu `SHA256SUMS` (Prüfsummen) und `LIZENZEN.txt`.
Prüfen (Linux/Deck, im Download-Ordner): `sha256sum -c --ignore-missing SHA256SUMS` – jede heruntergeladene Datei
muss „OK“ melden (`--ignore-missing` überspringt nur die Dateien, die du nicht geladen hast, z. B. das Windows-Archiv).

---------------------------------------------------------------------------------------------------------------------

## A. Auf dem Steam Deck installieren (neben v0.7.0)

Alles im **Desktop-Modus** (Steam-Taste → Ein/Aus → „Zum Desktop wechseln“).

1. `CrossingEurope-ZS2-linux-x86_64.tar.gz` auf das Deck holen (Browser oder USB-Stick) und in einen **eigenen
   Ordner** im Home-Verzeichnis legen, z. B. `/home/deck/Spiele/CrossingEurope-ZS2/` – nicht in den Ordner von v0.7.0.
2. Entpacken: im Dateimanager Dolphin Rechtsklick auf die Datei → „Entpacken“ → „Archiv hierher entpacken“. Danach
   liegen dort `CrossingEurope-ZS2.x86_64` (das ganze Spiel, eine Datei) und `LIZENZEN.txt`.
   Das Archiv behält das Ausführbar-Recht. Nur falls die Datei von einem FAT/exFAT-USB-Stick kopiert wurde:
   Rechtsklick → Eigenschaften → Berechtigungen → „Ausführbar“ anhaken.
3. Steam (im Desktop-Modus) öffnen → unten links **„Spiel hinzufügen“** → **„Ein Nicht-Steam-Spiel hinzufügen …“**
   (englisch „Add a Non-Steam Game“) → „Durchsuchen …“ → `CrossingEurope-ZS2.x86_64` wählen → „Ausgewählte Programme
   hinzufügen“.
4. In der Bibliothek Rechtsklick auf den neuen Eintrag → Eigenschaften: Namen ändern, z. B. in **„Crossing Europe
   ZS2“**, damit er sich von v0.7.0 unterscheidet. Unter **Kompatibilität nichts erzwingen** – **kein Proton**: Der
   Linux-Build läuft nativ.
5. Zurück in den Spielmodus („Zurück zum Spielmodus“ auf dem Desktop). Der Eintrag steht unter Bibliothek →
   „Nicht-Steam“. v0.7.0 bleibt ein eigener Eintrag und bleibt, wie er ist.

Entfernen: den Eintrag in Steam löschen, den Ordner `CrossingEurope-ZS2` und den Ordner
`/home/deck/.local/share/crossing-europe-zwischenstand/` löschen.

## B. Unter Windows installieren (neben v0.7.0)

1. `CrossingEurope-ZS2-windows-x86_64.zip` in einen eigenen Ordner entpacken (Rechtsklick → „Alle extrahieren …“),
   z. B. `C:\Spiele\CrossingEurope-ZS2\`.
2. `CrossingEurope-ZS2.exe` starten. SmartScreen meldet die neue, unsignierte Datei: „Weitere Informationen“ →
   „Trotzdem ausführen“ (wie bei v0.7.0, Einzelheiten in `docs/windows.md`).
3. Zusätzlich einmal mit **ANGLE** starten (Direct3D statt OpenGL – das können wir hier nicht prüfen):
   Rechtsklick auf die `.exe` → „Verknüpfung erstellen“ → Rechtsklick auf die Verknüpfung → Eigenschaften → bei
   **Ziel** hinter die Anführungszeichen ` --rendering-driver opengl3_angle` anhängen → OK → über diese Verknüpfung
   starten.

## C. Was bitte ausprobieren (etwa 30–45 Minuten)

1. **Start**: unten rechts im Titelbild steht **v0.8.0-zs2**. Hattest du Zwischenstand 1 noch nie gestartet, erscheint
   einmal **„GRAFIK WÄHLEN“** – bitte **Modern** wählen (welche Karte trägt „EMPFOHLEN FÜR DIESEN RECHNER“?). Sonst gilt
   deine Wahl aus Zwischenstand 1; Optionen → Seite GRAFIK (mit **R1** blättern) zeigt Grafik und Voreinstellung.
2. **Leistungstest – das Wichtigste**: Optionen → GRAFIK → „Leistungstest“ → „Leistungstest starten“ (drei feste
   Szenen: Autobahn bei Tag, Stadt bei Nacht im Regen, Bergstrecke mit Tunnel; mit Ladezeiten einige Minuten). **Bitte
   die Datei `leistungstest.json` schicken** – sie liegt hier:
   - Steam Deck: `/home/deck/.local/share/crossing-europe-zwischenstand/leistungstest.json`
   - Windows: `%APPDATA%\crossing-europe-zwischenstand\leistungstest.json`
   Gern je einmal mit „Steam Deck“, „Niedrig“, „Mittel“ und „Hoch“ – die Datei wird bei jedem Lauf überschrieben, also
   nach jedem Lauf kopieren und umbenennen. Der neue Wolkenhimmel ist auf unserer Testmaschine der teuerste Teil;
   genau dafür brauchen wir echte Zahlen.
3. **Ein Rennen in Modern** („Rennen starten“, Kiel – Nürnberg, oder einzelne Etappen) mit der Leistungsanzeige des
   Decks (Taste „…“ → Leistung → Leistungs-Overlay, Stufe 2 oder mehr): Bilder pro Sekunde auf der freien Autobahn,
   in dichtem Verkehr, im Elbtunnel (Hamburg – Hannover, gleich am Anfang), auf der Köhlbrandbrücke und in den Städten.
   Ruckelt es, wenn etwas zum ersten Mal auftaucht? Wo ist Modern schöner als Arcade, wo schlechter?
4. **Nacht, Regen, Schnee** (Einzelne Etappe → Uhrzeit Nacht oder Dämmerung, Wetter Regen oder Schnee): Regentropfen,
   Schneefall, Gischt, nasse Fahrbahn, Scheinwerfer. Sind Fahrbahn, Markierungen, Schilder und die anderen Autos immer
   gut zu erkennen? Ist die Regen- oder Schneenacht zu hell?
5. **Tunnel und Brücken**: Elbtunnel (Hamburg – Hannover km 4–7), Köhlbrandbrücke (Kiel – Hamburg kurz vor Hamburg);
   bei Schnee bitte auch eine Tunnelausfahrt ansehen.
6. **Kurvenkamera** (aus Zwischenstand 1): In Modern dreht sich die Kamera in Kurven leicht mit. **So lassen, stärker
   oder schwächer?**
7. **Umschalten und Klang**: Optionen → GRAFIK → „Grafik“ auf Arcade und zurück auf Modern (im Rennen ab der nächsten
   Etappe). Seite ALLGEMEIN: „Klang“ und „Musik im Rennen“ – wie gefallen die drei Rennstücke und ihre Lautstärke?
8. Nur Steam Deck: **Bildrate 40 oder 45** (Taste „…“ → Leistung) – flüssiger? Akku und Lüfter im Vergleich zu Arcade.
   **Angedockt** (1080p), falls möglich. **Standby** mitten in einer Modern-Etappe und wieder aufwecken: läuft es weiter?
9. **Alles, was falsch aussieht**: Bildschirmfoto (Steam-Taste + R1) und Etappe, km und Uhrzeit aus dem HUD notieren.

Windows zusätzlich: Titel, Fahrzeugwahl, eine Tagesetappe und eine Nacht-Regen-Etappe in Modern – einmal normal und
einmal über die ANGLE-Verknüpfung (Abschnitt B.3).

## D. Was zurückschicken

- `leistungstest.json` (Deck und/oder Windows, Pfade oben),
- die Antworten zu 1, 3, 4, 5, 6 (Kurvenkamera: so lassen / stärker / schwächer) und 7,
- Bildschirmfotos mit Etappe und km,
- bei Abstürzen oder Fehlermeldungen: `logs/godot.log` aus dem Ordner des Testbuilds (Pfade oben) – und ob beim
  nächsten Start die Frage „Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“ kam.

Notfall: Startet Modern nicht oder bleibt schwarz, startet das Spiel beim nächsten Mal von selbst in Arcade und fragt
nach. Von Hand geht es mit dem Startargument `--graphics=arcade` – das Spiel liest es nur **hinter zwei Strichen**
`--` (Steam: Eigenschaften → Startoptionen `-- --graphics=arcade`; Windows: an das Ziel der Verknüpfung hinter die
Anführungszeichen ` -- --graphics=arcade` anhängen, mit den zwei Strichen davor wie bei Steam).
