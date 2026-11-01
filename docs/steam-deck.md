# Steam Deck – Prüfung und Anpassungen

Kurz: **Das Spiel sieht auf dem Steam Deck ordentlich aus und lässt sich komplett mit dem eingebauten Controller
spielen.** Es wird im Maßstab 1:1 dargestellt (keine Unschärfe), die Menüs füllen jetzt den ganzen 16:10-Bildschirm,
im Rennen bleiben oben und unten 40 px schwarze Balken. Zu kleine oder zu kontrastarme Texte wurden vergrößert bzw.
aufgehellt, die Tastenhinweise zeigen auf dem Deck nur noch Gamepad-Tasten, und der Spielername lässt sich auch in den
Optionen per Gamepad eingeben. Geprüft wurde unter Linux mit einem virtuellen 1280×800-Bildschirm und echten
Gamepad-Ereignissen – **nicht auf einem echten Steam Deck**; die Leistung ist deshalb geschätzt (siehe unten).

## Ausgangslage

| | Steam Deck | Spiel |
|---|---|---|
| Bildschirm | 7 Zoll, 1280×800 (16:10), ca. 216 ppi, Abstand ca. 30–40 cm | entworfen für 1280×720 (16:9), Stretch `canvas_items`, Seitenverhältnis `keep` |
| Spielmodus | SteamOS zeigt Spiele unter *gamescope* im Vollbild | Linux-Build (x86_64, OpenGL 3.3), als Nicht-Steam-Spiel eingebunden |
| Eingabe | eingebauter Controller über Steam Input (Xbox-Belegung) | Tastatur und Gamepad |
| Valve-Richtlinie | kleinstes Textzeichen ≥ 9 px bei 1280×800; volle Controller-Unterstützung mit passenden Tastensymbolen; Texteingabe per Bildschirmtastatur oder Gamepad | |

## So wurde geprüft

- **Screenshots in 1280×800** von allen Bildschirmen und HUD-Situationen (Tag, Nacht, Regen, Countdown,
  Tutorial-Hinweis, Tanken, Polizei/Radarfeld, City Limits/Abschleppen, Ziel, Pausenmenü), vorher und nachher:
  `SCREEN=1280x800 tools/screenshot.sh <präfix> … --input=gamepad` (Xvfb-Bildschirm und Fenster 1280×800; die
  Screenshots zeigen jetzt das ganze Fenster samt Balken).
- **Skalierung**: Im 1280×800-Fenster ist der Inhalt 1280×720 groß, Maßstab 1,0, um 40 px nach unten versetzt
  (`Window.get_final_transform()`), darüber und darunter je 40 px Schwarz. Unter gamescope sollte das Rennen gleich
  aussehen, egal ob das Spiel im Fenster (1280×720, gamescope setzt die Balken) oder im Vollbild (1280×800, Godot
  setzt sie) läuft; die Menüs füllen den Bildschirm nur im Vollbild (siehe Änderungen).
- **Textgröße**: alle Schriftgrößen im Code (UiKit-Labels, `draw_string` in HUD und Widgets) gegen die Schriftmetrik
  gerechnet und im Screenshot nachgemessen (Pixelzeilen mit mindestens 50 % Deckung; Godot rendert wie FreeType:
  Share Tech Mono 17 px → x-Höhe 9 px, Ziffern 13 px; Barlow Condensed 16 px → x-Höhe 8 px, Versalien 11 px).
  Gerendert ergibt sich:

  | Schriftgröße | 13 | 14 | 15–16 | 17–18 | 19–20 | 22 |
  |---|---|---|---|---|---|---|
  | x-Höhe (Kleinbuchstaben) | 7 px | 7–8 px | 8 px | 9–10 px | 10–11 px | 11–12 px |
  | Versalhöhe | 9–10 px | 10–11 px | 11 px | 12–13 px | 13–15 px | 15–16 px |

  Strenge Lesart der Valve-Regel (auch Kleinbuchstaben ≥ 9 px): Text mit Kleinbuchstaben braucht mindestens 17 px,
  reine Versal-/Ziffernbeschriftung mindestens 13 px. Auf dem Deck sind 9 px ≈ 1,1 mm – so groß wie die x-Höhe einer
  6-pt-Druckschrift: lesbar, aber klein. Die meisten Texte des Spiels sind 19–26 px groß.
- **Kontrast**: WCAG-Kontrastverhältnis der Textfarben gegen die im Screenshot gemessenen Hintergründe
  (Ziel für kleine Texte: mindestens 4,5:1).
- **Gamepad**: ein Testskript schickt echte Gamepad-Ereignisse (`Input.parse_input_event`) durch das laufende Spiel:
  Titel → Abfrage „Gespeichertes Rennen überschreiben?“ → Rennen → Fahrzeug → Startzeit → Etappenbildschirm,
  Einzelne Etappe → Fahrzeug → Etappenbildschirm, Bestenlisten, Optionen mit Namenseingabe, Pausenmenü im Rennen.

## Ergebnisse vorher

### Bildformat 16:10

Nichts ist verzerrt oder abgeschnitten: Der 16:9-Inhalt erscheint unverändert in der Mitte, oben und unten je 40 px
Schwarz. In den Menüs wirkte das wie ein Fenster im Bildschirm – das ist jetzt behoben (siehe Änderungen), im Rennen
bleiben die Balken (das Straßenbild ist für 1280×720 berechnet).

### Zu kleine Texte (unter ca. 9–10 px)

| Bildschirm | Text | vorher | gerendert (x / Versal) |
|---|---|---|---|
| HUD | „CITY LIMITS“ auf dem Ortsschild | 13 px Versalien | – / 9 px |
| HUD | Polizei-Abstand „140 m hinter dir“ | 16 px | 8 / 11 px |
| HUD | Etappenname, Rekordzeile, km-Angaben am Fortschrittsbalken, „frei“, „km/h“ | 17 px | 9 / 12–13 px (Grenze) |
| Etappenbildschirm | Kachel-Unterzeilen („Abenddämmerung“, „2 Radar · 2 Tankst.“, „nach 1 Etappe“) – „Abenddämmerung“ ragte zudem 5 px über den Kachelrand | 16 px | 8 / 11 px |
| Routenwahl | „Nächste Etappe: Hamburg – Hannover, 150 km · 4 Etappen“ | 16 px | 8 / 11 px |
| Titel | Versionsnummer „v0.2.0“ | 16 px, gedämpft | 8 / 11 px |
| alle Menüs | Tastenkappen „Enter“, „Esc“ in den Hinweisen | 15 px | 8 / 11 px |

Unkritisch (nur Versalien/Ziffern ≥ 10 px oder ≥ 17 px): Tabellenköpfe und Kachel-Überschriften (15–16 px
Versalien), Tachoskala (15 px Ziffern), Stunden der Zeitleiste auf dem Startzeit-Bildschirm (14 px Ziffern),
Ländercodes in der Routenkarte, Etappenbeschreibung, Tutorial-Kasten, Fahrzeugspalte der Bestenlisten (17 px).
Nicht bewertet: Schilder in der Spielwelt (perspektivisch klein in der Ferne) und Debug-Anzeigen (FPS, Renderstatistik).

### Kontrast

| Stelle | vorher |
|---|---|
| km-Angaben unter dem Fortschrittsbalken (standen direkt auf dem Himmel) | Tag 3,0:1 (weiß) bzw. **1,5:1** („noch 128 km“), Regen 4,7:1 bzw. 2,4:1 |
| Gedämpfte Versal-Beschriftungen in Menüs (Tabellenköpfe, Kachel-Überschriften, „ZEIT“, Versionsnummer, Platzhalter) | 3,4–3,9:1 |
| HUD-Panels bei Tag (Etappenname, gedämpfte Farbe) | 5,5:1, über hellen Wolken deutlich weniger |
| alle übrigen Menütexte | 8:1 bis 17:1 |

### Gamepad und Tastensymbole

- Alle Bildschirme waren schon per Gamepad erreichbar und bedienbar (Steuerkreuz/Stick, A, B, Start), die
  Namenseingabe für die Bestenlisten hat eine eigene Bildschirmtastatur.
- **Ausnahme Optionen → Spielername**: nur mit Tastatur (auf dem Deck allenfalls über die Steam-Tastatur, STEAM + X).
- Die Fußzeilen zeigten immer Tastatur und Gamepad nebeneinander („Enter (A)“, Pfeiltasten als weiße Tastenkappen) –
  auf dem Deck halb unpassend.
- Das Tutorial nannte zuerst zwei Tastatur-Tipps („Lenken mit den Pfeiltasten …“), der Gamepad-Tipp kam erst etwa
  14 Sekunden nach dem Start.
- Das Spiel startete im Fenster (1280×720). Im Spielmodus zeigt gamescope auch ein Fenster bildschirmfüllend an, im
  Desktop-Modus passt ein 1280×720-Fenster mit Titelleiste aber nicht auf den 800 px hohen Bildschirm.

## Was geändert wurde

1. **Tastenhinweise passend zum Eingabegerät** – `scripts/core/input_mode.gd` (neu), `scripts/core/input_setup.gd`,
   `scripts/ui/widgets/key_hints.gd`: Sobald ein Gamepad benutzt wird (auf dem Deck von Anfang an, weil der Controller
   immer verbunden ist), zeigen alle Fußzeilen nur Gamepad-Symbole: A/B/X/Y, LT/RT, ein gezeichnetes Steuerkreuz mit
   den passenden Armen statt der Pfeiltasten, „LS“ für den linken Stick. Ein Tastendruck auf einer Tastatur schaltet
   zurück (Tastatur und Gamepad nebeneinander wie bisher); Maus, Touchscreen und Trackpads schalten nicht um.
2. **Tutorial**: Mit Gamepad kommt nur der Gamepad-Tipp („Stick lenkt, rechter Trigger Gas, linker Trigger Bremse“),
   ohne Gamepad wie bisher zuerst die Tastatur-Tipps (`scripts/race/tutorial_coach.gd`). Der „So geht's“-Kasten zeigt
   beim Lenken zusätzlich den Stick.
3. **Spielername per Gamepad in den Optionen** – `scripts/ui/widgets/name_entry_box.gd` (neu),
   `scripts/ui/screens/options_screen.gd`: A im Namensfeld öffnet dieselbe Bildschirmtastatur wie bei den
   Bestenlisten (A tippt, B löscht, OK übernimmt; Esc auf einer Tastatur schließt ohne Änderung). Eine Tastatur
   tippt weiter direkt ins Feld.
4. **HUD** (`scripts/ui/hud.gd`, `scripts/ui/ui_theme.gd`): Etappenname, Rekordzeile, km-Angaben und „frei“ 17 → 19 px,
   „km/h“ 17 → 18 px, Polizei-Abstand 16 → 18 px (der Fluchtbalken macht Platz), „CITY LIMITS“ 13 → 15 px, Zeitstrafe
   18 px. Die km-Angaben stehen jetzt mit auf dem Panel des Fortschrittsbalkens, die Zeitstrafe als Plakette mittig in
   dieser Zeile. HUD-Panels etwas dunkler (Deckkraft 0,62 → 0,72), ebenso die Tachoscheibe (0,70 → 0,78). Zu lange
   Etappennamen/Rekordhalter werden mit „…“ gekürzt statt über den Panelrand zu laufen.
5. **Menüs**: Kachel-Unterzeilen des Etappenbildschirms 16 → 18 px und unter dem Symbol beginnend (kein Überstand mehr),
   „Nächste Etappe …“ in der Routenkarte 16 → 17 px, Versionsnummer 16 → 18 px, Beschriftung der Pill-Tasten (LT/RT …)
   14 → 15 px; gedämpfte Textfarbe `TEXT_MUTED` heller (#626c9c → #7882b2).
6. **16:10-Bildschirm in den Menüs gefüllt** – `scripts/ui/game_flow.gd`, `scripts/ui/menu_shell.gd`,
   `scripts/ui/widgets/menu_background.gd`, `scripts/ui/widgets/confirm_box.gd`: In den Menüs gilt das
   Seitenverhältnis `expand`. Die Bildschirme bleiben 1280×720 groß in der Mitte, der animierte Hintergrund (Himmel,
   Sonne, Gitter, Straße) ist im selben 1280×720-Rahmen ausgelegt und läuft nach oben und unten weiter; Abfrage und
   Bildschirmtastatur dunkeln den ganzen Bildschirm ab. Im Rennen gilt wieder `keep` (Balken). Bei 16:9 ändert sich
   nichts. Voraussetzung ist ein 1280×800 großes Fenster, also Vollbild (siehe nächster Punkt).
7. **Vollbild beim ersten Start auf kleinen Bildschirmen** – `scripts/core/settings.gd`: Solange in den Optionen nichts
   gespeichert ist, startet das Spiel auf Bildschirmen bis 800 px Höhe (Steam Deck) im Vollbild, auf größeren wie
   bisher im Fenster. Die Option „Vollbild“ schaltet es wie gehabt um und wird gespeichert.
8. **Werkzeuge**: `SCREEN=1280x800 tools/screenshot.sh …` rendert auf einem 1280×800-Bildschirm; der Screenshotter
   speichert das ganze Fenster samt Balken (`scripts/core/screenshotter.gd`). `--input=gamepad|keyboard` legt das
   Eingabegerät beim Start fest (Screenshots der Gamepad-Hinweise ohne angeschlossenes Gamepad).
9. **Tests**: `tests/unit/ui/test_steam_deck.gd` (Umschalten des Eingabegeräts, Gamepad-Hinweise, Tutorial-Tipps,
   Namenseingabe in den Optionen, Kürzen im HUD).

## Vorher – nachher

| | vorher | nachher |
|---|---|---|
| kleinste x-Höhe (Kleinbuchstaben) | 8 px (HUD-Polizei, Etappenkacheln, Routenkarte, Versionsnummer) | **9 px** überall¹ |
| kleinste Versalhöhe | 9 px („CITY LIMITS“) | **11 px** |
| HUD-Texte, die man beim Fahren liest | 16–17 px (x-Höhe 8–9 px) | 18–19 px (x-Höhe 9–10 px) |
| km-Angaben am Fortschrittsbalken, Tag | 3,0:1 / 1,5:1 auf dem Himmel | 12,2:1 / 6,2:1 auf dem Panel |
| km-Angaben, Regen | 4,7:1 / 2,4:1 | 13,7:1 / 7,0:1 |
| Etappenname im HUD, Tag | 5,5:1 | 6,5:1 |
| „km/h“ im Tacho über der Straße, Tag | 4,1:1 | 4,5:1 |
| gedämpfte Versal-Beschriftungen in Menüs | 3,4–3,9:1 | 4,7–5,3:1 |
| Fußzeilen-Hinweise auf dem Deck | „Enter (A) Auswählen“, Pfeil-Tastenkappen | „(A) Auswählen“, Steuerkreuz-Symbol |
| Tutorial-Start auf dem Deck | erst zwei Tastatur-Tipps | gleich der Gamepad-Tipp |
| Spielername in den Optionen | nur Tastatur | auch Gamepad (Bildschirmtastatur) |
| Menüs auf 16:10 | 40-px-Balken oben und unten | Hintergrund füllt den Bildschirm (im Vollbild) |
| erster Start auf dem Deck | Fenster 1280×720 | Vollbild |
| Rennen auf 16:10 | 40-px-Balken | unverändert |

¹ Ausnahme: die Tastenkappen „Enter“/„Esc“ (15 px, x-Höhe 8 px) – sie erscheinen nur, solange eine Tastatur benutzt
wird, auf dem Deck also nicht.

Screenshots (1280×800, vorher/nachher, Kontaktbogen) entstehen mit `SCREEN=1280x800 tools/screenshot.sh` und den
Argumenten aus [ui.md](ui.md) („Debug und Screenshots“); sie liegen nicht im Repository.

## Leistung (Schätzung, nicht auf dem Deck gemessen)

Gemessen mit `tests/race/bench_render.gd` (CPU-Zeit der Straßenzeichnung `RoadRenderer._draw`, fünf Positionen der
Testetappe) auf dem Entwicklungsrechner, einer VM mit Intel Xeon 2,1 GHz (4 Kerne):

| | Median | Spitzen (p90) |
|---|---|---|
| Tag | 5,5 ms | bis 10,8 ms |
| Nacht | 6,1 ms | bis 11,3 ms |
| Nacht mit Regen | 6,0 ms | bis 8,7 ms |

Dazu kommen die Simulation (≈ 0,3 ms je 1/60-s-Schritt, [renn-modul.md](renn-modul.md) §13), das HUD (ein
einziges `_draw`) und die Engine.
Der Steam Deck (AMD Zen 2, 4 Kerne/8 Threads bis 3,5 GHz) dürfte pro Kern etwa gleich schnell oder etwas schneller
sein; GDScript nutzt im Wesentlichen einen Kern. **Erwartung: meist 7–10 ms CPU-Zeit je Bild, also stabile 60 fps;
in seltenen Spitzen (dichter Verkehr, Nacht mit vielen Lichtern) knapp an 16,7 ms.** Die Grafik ist für die
RDNA-2-GPU (8 CUs) keine Last: 2D mit 2.500–4.300 Dreiecken je Bild bei 1280×720 über Mesa *radeonsi* (OpenGL 3.3;
die exportierten Texturen sind S3TC/BPTC-komprimiert, das unterstützt radeonsi). Shader-Ruckler sind kaum zu
erwarten – es gibt nur wenige 2D-Shader, und Mesa speichert übersetzte Shader zwischen.

Falls es doch ruckelt: im Schnellzugriffsmenü die Bildrate auf 40 begrenzen (mit 40 Hz Bildwiederholrate), das
läuft gleichmäßig und spart Akku. Die Rennsimulation läuft in festen 1/60-s-Schritten und bleibt dabei gleich.

## Titelbild und Attract-Modus (v0.5.0)

- **Titelbild** ([ui.md „Titelbildschirm“](ui.md)): füllt 16:10 per *cover fit* – links und rechts fallen je ~4 % des
  Bildes weg, oben und unten nichts; Logo, Milchglas-Menü und Tastenhinweise bleiben im 1280×720-Rahmen, das rote
  Auto bleibt links der Menükarte (auch beim stärksten Ken-Burns-Zoom, geprüft in `test_attract_mode.gd`). Der Shader
  (ein Bildzugriff je Pixel plus etwas Rechnung, Milchglas neun Zugriffe auf kleine Mip-Stufen) kostet auf der
  Deck-GPU praktisch nichts.
- **Attract-Modus** ([ui.md „Attract-Modus“](ui.md)): Die Demo läuft wie das Rennen mit 40-px-Balken; jede Taste des
  eingebauten Controllers, ein Stickausschlag, ein Fingertipp auf den Touchscreen oder ein Trackpad-Klick beendet sie
  und führt zurück zum Titel, ohne einen Menüpunkt auszulösen. Das Overlay zeigt dann das Ⓐ-Symbol.

## Verbleibende Grenzen

- **Rennen mit Balken**: Das Straßenbild ist für 1280×720 berechnet (Projektion, Hintergründe, Sprites); im Rennen
  bleiben deshalb oben und unten 40 px Schwarz. Die Menüs nutzen den ganzen Bildschirm.
- **Klein, aber im Rahmen**: Die kleinsten Texte (Etappenbeschreibung, Tutorial-Kasten, Tabellenköpfe) haben 9 px
  x-Höhe bzw. 11 px Versalhöhe – Valves Mindestmaß ist erfüllt, mehr Platz gibt das 1280×720-Layout ohne Umbau nicht her.
- **Tastensymbole im Xbox-Stil**: A/B/X/Y, LT/RT und LS als Schrift-Symbole; das Deck nennt die Trigger R2/L2 und
  hat statt „Start“ die Taste ≡ – Lage und Funktion sind gleich. Eigene Deck-Symbole gibt es nicht.
- **Steam-Menü pausiert nicht unbedingt**: Ob das Spiel beim Öffnen des Steam-Menüs oder des Schnellzugriffsmenüs
  den Fokus verliert (und dann pausiert), hängt von gamescope ab – vorher mit ≡ pausieren.
- **Fortschritt innerhalb einer Etappe** wird nicht gespeichert (gespeichert wird nach jeder Etappe). Der
  Standby des Decks behält das laufende Spiel.
- **Nicht auf echter Hardware geprüft**: Leistung, Akkulaufzeit, Verhalten unter gamescope und die
  Steam-Input-Belegung sind aus Messungen auf dem Entwicklungsrechner und den Eigenschaften des Decks abgeleitet.

## Empfohlene Einstellungen

**Einrichten** (im Desktop-Modus des Decks):

1. `CrossingEurope.x86_64` in einen Ordner im Home-Verzeichnis kopieren (z. B. `~/Spiele/CrossingEurope/`) und
   ausführbar machen (Dolphin: Rechtsklick → Eigenschaften → Berechtigungen → „Ausführbar“). Von einem
   USB-Stick mit FAT/exFAT geht das Ausführbar-Recht verloren – deshalb erst kopieren.
2. In Steam als Nicht-Steam-Spiel hinzufügen und das Bibliotheks-Artwork setzen – Schritt für Schritt in
   [marketing/steam/README.md](../marketing/steam/README.md).
3. Eigenschaften des Spiels → Kompatibilität: **kein Proton** bzw. kein Kompatibilitätstool erzwingen – es ist ein
   natives Linux-Spiel.

**Steuerung** (Spielmodus, Controller-Symbol auf der Spielseite):

- Steam Input eingeschaltet lassen, Controller-Layout bzw. Vorlage **„Gamepad“** (Xbox-Belegung). „Gamepad mit
  Maus-Trackpad“ geht ebenso – Trackpad und Touchscreen stören die Hinweise nicht.
- Belegung im Spiel: linker Stick oder Steuerkreuz lenkt, R2 (RT) oder A gibt Gas, L2 (LT) oder X bremst,
  ≡ pausiert; in Menüs A wählt, B geht zurück.

**Im Spiel**: Optionen → **Vollbild: An** – beim ersten Start auf dem Deck schon voreingestellt. Im Vollbild hat das
Fenster genau 1280×800: Die Menüs füllen den Bildschirm, keine Skalierung von gamescope kann das Bild strecken, und
im Desktop-Modus verdeckt keine Taskleiste das Spiel. Den Spielernamen am einfachsten gleich in den Optionen mit A im
Namensfeld eingeben.

**Schnellzugriffsmenü (Taste „…“) → Leistung**: Bildrate 60 (Standard). Skalierung so lassen bzw. nicht auf
„Strecken“ stellen (das Bild ist 16:9). Bei Rucklern oder für mehr Akku: 40 Hz und Bildrate 40.

**Spielstände sichern**: Steam Cloud gilt nicht für Nicht-Steam-Spiele. Einstellungen, Spielstand und Bestenlisten
liegen in `~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/` – diesen Ordner bei Bedarf
sichern. Eine `game_config.json` neben der ausführbaren Datei wirkt wie am PC (siehe [README](../README.md)).

**Angedockt** an einem 16:9-Monitor oder Fernseher: in den Eigenschaften des Spiels die Spielauflösung auf „Nativ“
stellen – dann läuft es in der Auflösung des Bildschirms, füllt ihn ohne Balken und wird scharf skaliert (1080p:
Faktor 1,5). Mit 1280×800 würde das 16:10-Bild samt Balken noch einmal in den 16:9-Bildschirm eingepasst.
