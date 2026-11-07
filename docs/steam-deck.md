# Steam Deck – Prüfung und Anpassungen

Kurz: **Das Spiel sieht auf dem Steam Deck ordentlich aus und lässt sich komplett mit dem eingebauten Controller
spielen.** Es wird im Maßstab 1:1 dargestellt (keine Unschärfe), die Menüs füllen jetzt den ganzen 16:10-Bildschirm,
im Rennen bleiben oben und unten 40 px schwarze Balken. Zu kleine oder zu kontrastarme Texte wurden vergrößert bzw.
aufgehellt, die Tastenhinweise zeigen auf dem Deck nur noch Gamepad-Tasten, und der Spielername lässt sich auch in den
Optionen per Gamepad eingeben. Geprüft wurde unter Linux mit einem virtuellen 1280×800-Bildschirm und echten
Gamepad-Ereignissen – **nicht auf einem echten Steam Deck**; die Leistung ist deshalb geschätzt (siehe unten).

Zweite Prüfung an v0.5.1 (Padsteuerung): ein Stick-Stoß = ein Schritt in Auswahlwerten, jedes Gamepad fährt (nicht nur
das erste), Bildschirmtastatur und Halten von Steuerkreuz/Stick verbessert, gleichmäßiger Bildtakt bei 40/45 fps und
90 Hz, keine Nachladeruckler mehr, Vibration neu – Abschnitt [Prüfung v0.5.1](#prüfung-v051-padsteuerung-und-steam-deck).

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

## Leistung (Schätzung von v0.3.0, nicht auf dem Deck gemessen)

Stand v0.3.0 – die Messungen an v0.5.1 und die korrigierte Einschätzung stehen unter
[Prüfung v0.5.1](#leistung-stand-v051). Gemessen mit `tests/race/bench_render.gd` (CPU-Zeit der Straßenzeichnung
`RoadRenderer._draw`, fünf Positionen der Testetappe) auf dem Entwicklungsrechner (damals als Intel Xeon 2,1 GHz
eingeschätzt; gemessen läuft ein Kern mit 3,3 GHz – Abschnitt v0.5.1):

| | Median | Spitzen (p90) |
|---|---|---|
| Tag | 5,5 ms | bis 10,8 ms |
| Nacht | 6,1 ms | bis 11,3 ms |
| Nacht mit Regen | 6,0 ms | bis 8,7 ms |

Dazu kommen die Simulation (≈ 0,3 ms je 1/60-s-Schritt, [renn-modul.md](renn-modul.md) §13), das HUD (ein
einziges `_draw`) und die Engine.
Der Steam Deck (AMD Zen 2, 4 Kerne/8 Threads bis 3,5 GHz) wurde damals pro Kern etwa gleich schnell eingeschätzt;
GDScript nutzt im Wesentlichen einen Kern. *Erwartung von v0.3.0: meist 7–10 ms CPU-Zeit je Bild, also stabile 60 fps;
in seltenen Spitzen knapp an 16,7 ms.* Die Prüfung v0.5.1 korrigiert das: Ein Deck-Kern ist geschätzt 1,4–1,7-mal
langsamer als der der Messmaschine, in dichten Szenen reichen 60 fps wahrscheinlich nicht immer. Die Grafik ist für die
RDNA-2-GPU (8 CUs) keine Last: 2D mit 2.500–4.300 Dreiecken je Bild bei 1280×720 über Mesa *radeonsi* (OpenGL 3.3;
die exportierten Texturen sind S3TC/BPTC-komprimiert, das unterstützt radeonsi). Shader-Ruckler sind kaum zu
erwarten – es gibt nur wenige 2D-Shader, und Mesa speichert übersetzte Shader zwischen.

Die damalige Empfehlung „Bildrate 40 bei 40 Hz läuft gleichmäßig“ stimmte in v0.5.1 nicht (die Straße ruckelte im
Wechsel von einem und zwei Simulationsschritten); seit der Render-Interpolation stimmt sie – siehe *Empfohlene
Einstellungen*.

## Titelbild und Attract-Modus (v0.5.0)

- **Titelbild** ([ui.md „Titelbildschirm“](ui.md)): füllt 16:10 per *cover fit* – links und rechts fallen je ~5 % des
  Bildes weg, oben und unten nichts; Logo, Milchglas-Menü und Tastenhinweise bleiben im 1280×720-Rahmen, das rote
  Auto bleibt links der Menükarte (auch beim stärksten Ken-Burns-Zoom, geprüft in `test_attract_mode.gd`). Der Shader
  (ein Bildzugriff je Pixel plus etwas Rechnung, Milchglas neun Zugriffe auf kleine Mip-Stufen) kostet auf der
  Deck-GPU praktisch nichts.
- **Attract-Modus** ([ui.md „Attract-Modus“](ui.md)): Die Demo läuft wie das Rennen mit 40-px-Balken; jede Taste des
  eingebauten Controllers, ein Stickausschlag, ein Fingertipp auf den Touchscreen oder ein Trackpad-Klick beendet sie
  und führt zurück zum Titel, ohne einen Menüpunkt auszulösen. Das Overlay zeigt dann das Ⓐ-Symbol.

## Prüfung v0.5.1: Padsteuerung und Steam Deck

Auftrag: „bitte auf Padsteuerung und Steam Deck-Tauglichkeit prüfen“. Geprüft wurde v0.5.1 (Build `eabb121`) in vier
Durchgängen – Menüs, Fahren, Darstellung, Leistung –, danach wurden die echten Probleme behoben. Auch diesmal gab es
**kein echtes Steam Deck und kein echtes Gamepad**; bei jedem Punkt steht, ob er gemessen oder abgeleitet ist.

**Kurz:** Mit dem Gamepad war das Spiel bedienbar, aber an mehreren Stellen hakelig: Ein Stick-Stoß verstellte
Auswahlwerte mehrfach, nur das erste Gamepad konnte bestätigen und fahren, die Bildschirmtastatur löschte mit dem ersten
B den ganzen Namen, lange Listen ließen sich nicht durch Halten durchlaufen. Auf dem Deck kamen ein ungleichmäßiger
Bildtakt bei 40 und 45 fps sowie bei 90 Hz (Deck OLED) und kurze Ruckler beim Nachladen von Gebäuden, Lkw und
Wahrzeichen dazu. Das alles ist behoben; neu sind Vibration (abschaltbar), LB/RB zum Blättern und ein paar
Komfortpunkte. Offen bleibt die CPU-Reserve für 60 fps in dichten Szenen auf dem Deck – das ist eine Schätzung und
muss auf dem Gerät gemessen werden.

### So wurde geprüft

- **Gamepad im laufenden Spiel** (gemessen): Testskripte schicken `InputEventJoypadButton`/`InputEventJoypadMotion`
  über `Input.parse_input_event` durch das echte Spiel – headless und unter Xvfb mit 1280×800 –, Stick-Stöße
  realistisch als Folge von Bewegungsereignissen (eines je Bild, gehalten mit ±0,01 Rauschen), auch von Gerät 1.
  Alle Menüflüsse (Titel, Rennen, Einzelne Etappe, Bestenlisten, Optionen, Etappen- und Rennergebnis mit
  Namenseingabe, echte Fähre, Pausenmenü) und die Rennszene.
- **Fahren** (gemessen + modelliert): Lenk-, Gas- und Bremswerte in der echten Rennszene (`--fixed-fps 60`); dazu ein
  modellierter Fahrer (Reaktion 0,17–0,25 s, Daumen mit 7–25 % Überschwingen, Zittern 0,02–0,05, Tipp-Mindestdauer
  40–100 ms) für je 30 Spurwechsel trocken und im Schnee mit Stick, Steuerkreuz und Tastatur, gegen die echte Szene
  validiert (Abweichung ≤ 0,03 m).
- **Darstellung** (gemessen): Screenshots 1280×800 mit Gamepad-Symbolen, WCAG-Kontrast gegen die im Bild gemessenen
  Hintergründe, angedockt 1920×1080 (nur die Fensterwahl des Spiels; was gamescope daraus macht, ist abgeleitet).
- **Leistung** (gemessen auf der Messmaschine, Deck geschätzt): CPU-Zeit je Bild des Release-Builds ohne GPU-Arbeit in
  elf Szenen (je 1080 Bilder), GL auf llvmpipe, Bildtakt bei festen Bildraten, Fokusverlust und angehaltener Prozess
  unter Xvfb, Ladezeiten. Die Messmaschine ist – anders als im Abschnitt *Leistung* unten von v0.3.0 angenommen – kein
  2,1-GHz-Xeon: ihr Kern läuft gemessen mit 3,3 GHz (Emerald Rapids). Ein Deck-Kern (Zen 2) ist geschätzt
  1,4–1,7-mal langsamer.
- **Nach den Änderungen** (gemessen): `tests/race/check_menu_pad.gd` (Teil von `tools/run_tests.sh`) wiederholt die
  wichtigsten Abläufe mit Gamepad-Ereignissen im echten Spiel, `tests/unit/ui/test_gamepad.gd` prüft die Teile
  einzeln, `check_session.gd` (Szenario `preload`) das Nachladen; Bildtakt und Ladezeit wie unten.

### Befunde und Änderungen

| Befund an v0.5.1 (gemessen, sofern nicht anders vermerkt) | Änderung | nachher (gemessen) |
|---|---|---|
| **Stick bei Auswahlwerten** (hoch): Jedes Stick-Ereignis über der Totzone zählte als neuer Tastendruck. Ein Stoß wechselte das Fahrzeug 3–5-mal, ein gehaltener Stick (0,75 ± 0,01, 0,4 s) stellte die Startzeit von 09:30 auf 23:30, die Gesamtlautstärke von 0,7 auf 0, blätterte die Rennergebnis-Tabelle ~10 Schritte. Das Steuerkreuz und die Menülisten waren in Ordnung. | `UiKit.ui_step` in allen fünf eigenen ◀▶/▲▼-Handlern: ein Stick zählt nur in dem Bild, in dem er die Aktion betritt, höchstens einmal je Bild – wie Godots Fokussuche. | 1 Schritt je Stoß (Fahrzeug, Startzeit ±30 min, ▲ +1 h, Lautstärke 8 → 7); gehaltener, rauschender Stick: 1 Schritt |
| **Nur Gamepad 0** (mittel): Die Belegungen von `InputSetup` galten nur für Gerät 0. Ein zweites Gerät bewegte den Fokus, konnte aber nicht bestätigen, zurück, lenken, Gas geben oder pausieren. Abgeleitet: Am angedockten Deck mit externem Controller ist dieser meist Gerät 1. | alle Gamepad-Belegungen für alle Geräte (`device` −1); den Stick liest das Rennen nur am zuletzt benutzten Pad (siehe *Nachprüfung*) | Gerät 1: A bestätigt, B geht zurück, Lenkung 1,0, Gas 1,0, Start pausiert |
| **Bildschirmtastatur** (mittel): Das erste B löschte den ganzen vorausgewählten Namen („Jörg“ → „“); per Pad ließ sich die Optionen-Tastatur nicht abbrechen; A im leeren Feld trug „Unbekannt“ ein und merkte es sich als Spielernamen; B, dann A in den Optionen speicherte einen leeren Namen. | B löscht immer nur das letzte Zeichen, im leeren Feld der Optionen-Tastatur schließt es ohne Änderung; A oder Start im leeren Feld springen auf die Tasten; Start = Fertig; „Unbekannt“ (OK im leeren Feld) wird nicht als Name gemerkt; die Hinweise folgen dem Fokus („Tippen“/„Eintragen“, „Löschen“/„Schließen“). | „Anke“ → B → „Ank“; leer → B schließt, Name bleibt „Anke“ |
| **Halten wiederholt nicht** (mittel): Steuerkreuz oder Stick 1,5–2 s gehalten = 1 Schritt (Godot wiederholt Tasten, keine Gamepad-Knöpfe); Etappenliste 51, Bestenlisten 106 Einträge. | `PadRepeat`: nach 0,5 s alle 0,1 s ein Schritt (`input.repeat_*`; ein kürzerer Stick-Stoß bleibt ein Schritt); LB/RB springen 8 Einträge (auch Bild ↑/↓, die Fußzeilen nennen beide) | 1 s gehalten = 7 Einträge, 0,4-s-Stoß = 1; RB +8, LB −8 |
| **Namensfeld der Optionen nimmt keine Tasten** (mittel): Ein per Pfeil/Steuerkreuz erreichtes `LineEdit` ist in Godot 4.7 nicht im Bearbeitungsmodus; getippte Zeichen – auch die der Steam-Tastatur (STEAM + X) – wurden verworfen. | die erste getippte Taste startet die Bearbeitung | „Anke“ + Q, x → „AnkeQx“ |
| **Bildtakt** (hoch): Die Simulation läuft in festen 1/60-s-Schritten, gezeichnet wurde der Stand des letzten Schritts. Bei 40 fps sprang die Kamera abwechselnd 1 und 2 Schritte, bei 45 fps 1-2-1, bei 90 Hz (Deck OLED, Standard laut Gerätespezifikation) stand jedes dritte Bild still. | Render-Interpolation: jedes Bild zeigt den Stand zwischen den letzten zwei Schritten (`Engine.get_physics_interpolation_fraction`) – Kamera, Spielerauto, Verkehr, Polizei, Hintergrund; die Simulation selbst bleibt unverändert | ungleiche Bildpaare 0 % bei 30/40/45/60/90 fps (Tabelle unten) |
| **Nachladeruckler** (mittel): Ein Sprite-Blatt wurde beim ersten Zeichnen synchron geladen: Gebäude 13–20 ms, Lkw 16 ms, Frankfurter Skyline 33,5 ms bei 7,4 ms Median – auf dem Deck mehr (Kartenleser, GPU-Upload; abgeleitet). | alle Blätter der Etappe vor dem Start laden (Verkehr, Polizei der Länder, Requisiten aller Landschaften, Wahrzeichen, Skyline, HUD-Symbole) | Dortmund – Frankfurt ab km 200: 69 Blätter vorab, 0 nachgeladen (vorher 29); längstes Bild 79–82 → 31 ms; Aufbau +0,23–0,30 s |
| **CPU-Reserve für 60 fps** (mittel, Schätzung): Hauptthread im Median 6–9,5 ms, p99 10–16 ms je Bild auf der Messmaschine; auf dem Deck geschätzt Feierabendverkehr Median 11–16 ms, p99 16–21 ms. | nicht geändert (siehe *Nicht geändert*) | – |
| Lenken mit dem Stick (niedrig): Totzone 0,2 ohne Außensättigung – kleine Korrekturen unter 20 % wirkungslos (Modell: 11 von 30 Spurwechseln endeten ≥ 0,5 m neben der Spurmitte), 30° schräg nur 83 %, 45° 63 % | eigene Stickkurve auf dem Rohwert: Totzone 0,12, volle Lenkung ab 0,92 (`input.stick_deadzone`, `input.stick_full`); Tasten und Steuerkreuz unverändert 1,0 | 0,10 → 0; 0,20 → 0,10; 0,50 → 0,48; 30° → 0,93; 45° → 0,73. Modell der Prüfung mit Totzone 0,12 (ohne Außensättigung): 0 von 30, Einschwingen trocken 1,32 → 1,10 s |
| keine Vibration (niedrig) | Vibration im Rennen (Optionen „Vibration“, Standard An): Kollision, Leitplanke (Treffer und Schleifen), Bankett/Gras ab 30 km/h, Untersteuern ab 0,15 („Gas weg“), Radarblitz; aus bei Pause, Ziel, Autopilot/Demo und wenn eine Tastatur fährt; höchstens 15 Befehle je Sekunde, jeder gilt 0,25 s | Kollision → schwach 0,5 / stark 0,9 am benutzten Gerät, Pause → 0. Gespürt wurde nichts (kein Gerät) |
| Pause-Taste nirgends genannt (niedrig) | „Start Pause“ (Tastatur: „Esc Start Pause“) unter der Startampel, solange der Countdown läuft; Tutorial-Tipp „Start pausiert – Gas geht auch mit A, Bremse mit X“ | Screenshot |
| Tankfenster „Gas = Weiterfahren“ ohne Pad-Symbol (niedrig) | mit Gamepad die Symbole RT und Ⓐ: „RT Ⓐ Weiterfahren“ | Screenshot |
| Titel: „Beenden“ ohne Rückfrage (niedrig) | Abfrage „Spiel beenden?“, Standard „Abbrechen“ | B bricht ab |
| Abfragen ohne eigene Hinweise (niedrig): dahinter stand die Fußzeile des Titels mit ▲▼, B fehlte | Hinweiszeile in der Box: ◀▶ Wählen, Ⓐ Bestätigen, Ⓑ Abbrechen | Screenshot |
| Zurück verliert die Auswahl (niedrig) | Rennauswahl fokussiert das gewählte Rennen, der Titel nach Einzelne Etappe, Bestenlisten, Optionen diesen Eintrag (nach einem Rennen weiter „Rennen fortsetzen“; „Beenden“ wird nicht gemerkt) | QA-Ablauf: B → „München – Bremen“, Titel → „Optionen“ |
| Gamepad getrennt mitten im Rennen (niedrig, abgeleitet: das Signal lässt sich nicht echt auslösen) | Rennen pausiert, wenn es das benutzte Pad war oder noch eine Taste, einen Stick oder Trigger hielt; seine Eingaben gibt Godot beim Trennen selbst frei – nur seine (siehe *Nachprüfung*) | Aufruf des Handlers: benutztes Pad → Pause; ruhendes Pad eines Tastaturspielers → keine Pause, die gehaltene Taste gibt weiter Gas |
| Fokusverlust im Countdown startete das Rennen ohne den Spieler; nach Standby lief das Rennen weiter (niedrig) | Pause auch im Countdown; nach Standby (Wanduhr sprang > 2 s weiter als die monotone Uhr) pausiert das Rennen | Regel geprüft; echter Standby nicht (abgeleitet: Linux zählt die monotone Uhr im Schlaf nicht) |
| Leerlauf und Akku (niedrig): Pausenmenü und Fenster ohne Fokus zeichneten mit voller Bildrate (Pause: weiter 290 Zeichenbefehle je Bild), Attract-Demos liefen endlos, der Bildschirm blieb an | 30 fps im Pausenmenü und ohne Fokus (`FrameCap`); nach 10 min ohne Eingabe keine Demos mehr (`attract.max_idle_s`), dann darf sich der Bildschirm abschalten – im Rennen nie | – |
| Etappenstart ohne Rückmeldung, Menü stand 0,3–0,8 s (niedrig) | „Etappe wird geladen …“ | Screenshot |
| Motorklang-Aussetzer in den ersten 0,3 s (niedrig, mit dem Dummy-Treiber gemessen, auf dem Deck abgeleitet) | in der ersten Sekunde nach dem Motorstart 0,2 s Vorlauf statt 0,07 s (`audio.engine_start_latency_s`) | – |
| „frei“ unter dem Aufhebungsschild ohne Panel (niedrig): Schnee mittags 1,87:1 | kleines HUD-Panel | 10,4:1 |
| Attract: Hof des Logos über „DEMO“ und Szenenname, beide ~23 % dunkler (niedrig) | Hof hinter dem Overlay (`show_behind_parent`) | Schnee-Szene: Name 5,5:1 → 9,6:1, „DEMO“ 4,2:1 → 5,1:1 (hellstes Glyphenpixel gegen die Pille) |
| Angedockt mit „Nativ“ (niedrig): auf 1920×1080 startete das Spiel im 1280×720-Fenster, gamescope skaliert es weich hoch (abgeleitet); einmal angedockt gespeichert, blieb der Deck auch im Handbetrieb im Fenster | unter gamescope Vollbild; „Vollbild“ wird nur gespeichert, wenn der Spieler es umgeschaltet hat (`settings_version` 2). Dateien von v0.5.0/v0.5.1 enthielten den Wert immer – dort zählt nur ein gespeichertes „An“ als Wahl, ein „Aus“ gilt als nicht gewählt (siehe *Nachprüfung*) | Regel geprüft, auch mit Dateien beider Fassungen; gamescope-Erkennung nicht am Gerät (abgeleitet) |
| Titel: Fußzeile auf hellem Asphalt an den hellsten Stellen 3,4:1 (niedrig) | weicher Schatten unter allen Fußzeilen-Beschriftungen | Screenshot |
| Doku: Titelbild-Beschnitt „je ~4 %“ (niedrig) | korrigiert: je ~5 % (83 von 1672 px) | – |

### Nachprüfung der Änderungen

Eine Durchsicht der Änderungen fand sieben kleinere Punkte (alle niedrig); behoben vor v0.6.0, geprüft mit
`test_gamepad.gd` und `check_menu_pad.gd` (Prüfungen `drift`, `trennen`, `beenden`; gegen den Stand davor schlagen alle
drei fehl).

| Befund | Änderung | nachher (gemessen) |
|---|---|---|
| Jedes getrennte Gamepad pausierte das Rennen und ließ Lenkung, Gas und Bremse aller Geräte los (`Input.action_release` löscht den Zustand jedes Geräts) – auch die gehaltene Taste eines Tastaturspielers, dessen ruhendes Funk-Pad sich abschaltete | Pause nur, wenn das getrennte Pad das benutzte war (`InputMode.device`, solange ein Gamepad das Eingabegerät ist) oder noch eine Taste, einen Stick oder Trigger über 0,2 hielt (`InputMode.pad_lost`, gemeldet von `InputSetup.pad_disconnected`). Die Rennsitzung gibt nichts mehr frei: Godot 4.7 verwirft beim Trennen selbst die Eingaben dieses Pads, nur seine (`Input::joy_connection_changed`) | ruhendes Pad: keine Pause, die Taste gibt weiter Gas (vorher 0); Pad hält RT: Pause, die Taste gibt weiter Gas; benutztes Pad: Pause |
| Drift eines zweiten Pads: Der Stick jedes Pads lag in den Lenkaktionen, der größte Wert zählte, die Totzone liegt bei 0,12 – ein herumliegendes Pad mit 0,16 Drift lenkte 5 % und minderte eine Lenkung in die Gegenrichtung | Das Rennen liest den Stick nur am zuletzt benutzten Pad (`Input.get_joy_axis(InputMode.device, …)` durch die Stickkurve, `SessionRules.pad_steer`); Tasten und Steuerkreuz jedes Pads lenken voll. Eine Taste oder ein Ausschlag ≥ 0,5 macht ein Pad zum benutzten, auch mitten im Rennen | Drift 0,16 → Lenkung 0 (vorher 0,05); Wechsel im Rennen: Pad 0 übernimmt (−1,0, vorher hoben sich die Sticks auf: 0), Pad 1 zurück (0,6) |
| Titel merkte sich „Beenden“: nach einer abgebrochenen Abfrage stand jeder spätere Titel, auch nach einer Demo, auf „Beenden“ | nur Einzelne Etappe, Bestenlisten und Optionen werden gemerkt (`TitleScreen.remembered_choice`) | nach dem Abbrechen: Titel auf dem Standardeintrag |
| Fußzeilen von Einzelne Etappe und Bestenlisten: „LB RB Seite“ ohne Tasten, obwohl Bild ↑/↓ blättern | mit Tastatur „Bild↑ Bild↓ LB RB Seite“ (Tastenkappen mit gezeichnetem Pfeil – die Schriften haben keine Pfeile), mit Gamepad „LB RB Seite“ | Breite mit Tastatur 822 / 670 px, mit Gamepad 594 / 492 px von 1152 px; Screenshots bei 1280×720 und 1280×800 |
| Vollbild: Dateien von v0.5.0/v0.5.1 enthielten „fullscreen“ immer – ein einmal angedockt gespeichertes „Aus“ galt als Wahl, der Deck startete im Spielmodus weiter im Fenster | `settings_version` 2; ohne Version zählt nur ein gespeichertes „An“ als Wahl | Unit-Test mit Dateien beider Fassungen |
| Kleinigkeiten: Beschreibung von „Optionen“ im Titel ohne Vibration; `--no-sprite-preload` lud anders als v0.5.1 auch das eigene Auto nicht vor; ein Doku-Kommentar in `track.gd` stand über der falschen Funktion | „Lautstärke, Vollbild, Vibration, Spielername und Steuerung.“; das eigene Auto wird immer vorab geladen; Kommentar zurück an `events_for_segment` | – |

### Bildtakt

Gemessen headless mit `--fixed-fps N` (und gegengeprüft in Echtzeit mit `--max-fps 40` und `90`: gleiche Ergebnisse),
Feierabendverkehr vor Frankfurt, 240 Bilder; „ungleich“ = der Kamera-Vorschub zweier aufeinanderfolgender Bilder
weicht um mehr als 25 % ab. „Ohne“ entspricht v0.5.1 (die Ansicht zeigt den letzten Simulationsschritt).

| Bildrate | Schritte je Bild | ungleiche Bildpaare ohne / mit Interpolation | Streuung des Vorschubs ohne / mit |
|---|---|---|---|
| 60 | 1 | 0 % / 0 % | 0,5 % / 0,5 % |
| 40 | 1, 2, 1, 2 | **100 %** / 0 % | 33 % / 0,5 % |
| 45 | 2, 1, 1 | **67 %** / 0 % | 35 % / 0,5 % |
| 90 (Deck OLED) | 1, 1, 0 | **67 %** / 0 % | 71 % / 0,6 % |
| 30 | 2 | 0 % / 0 % | 0,4 % / 0,4 % |

Die Interpolation zeigt jedes Bild höchstens einen Simulationsschritt (16,7 ms) hinter dem neuesten Stand, im Mittel
einen halben. Rangliste, Autopilot und alle Prüfungen bleiben gleich, weil nur die Darstellung interpoliert wird (die
Attract-Szenen ergeben auf den Meter dieselben Werte wie vorher).

### Leistung (Stand v0.5.1)

Gemessen von der Leistungsprüfung am Release-Build v0.5.1 auf der Messmaschine (CPU-Zeit je Bild ohne GPU-Arbeit,
1080 Bilder je Szene), Deck-Werte geschätzt (Faktor 1,4–1,7):

| Szene | Median | p99 | max | Deck geschätzt (Median / p99) |
|---|---|---|---|---|
| Attract-Demo Feierabendverkehr 18:48 | 9,52 ms | 16,20 ms | 33,47 ms | 14–19 / 24–31 ms |
| Feierabendverkehr Frankfurt 17 Uhr | 7,40 ms | 10,46 ms | 20,13 ms | 11–16 / 16–21 ms |
| Paris nachts bei Regen | 5,95 ms | 9,46 ms | 11,77 ms | |
| Würzburg nachts bei Regen (22 Lichter) | 6,09 ms | 10,76 ms | 12,53 ms | |
| Schnee im Berufsverkehr A7 | 6,39 ms | 10,66 ms | 13,26 ms | |
| Gotthard mit Lkw | 3,76 ms | 5,97 ms | 14,65 ms | |
| Titel, Pause | 0,12 ms | | | |

Der Straßenrenderer (`RoadRenderer._draw`) kostet davon 4–7,5 ms (Requisiten 2,4 ms, Boden 0,9 ms im
Feierabendverkehr), die Simulation 0,4–1,6 ms. Seit v0.3.0 ist der Median dieser Szene um etwa 19 % gestiegen (7,3 →
8,8 ms im Editor). Etappe laden 0,29–0,81 s (Release; jetzt +0,2–0,3 s für die vorab geladenen Blätter, beim ersten
Mal), Texturspeicher im Rennen 247–259 MB. **Auf dem Deck dürften 60 fps in dichten Szenen und Städten nicht immer
reichen** – geschätzt, nicht gemessen. Seit der Render-Interpolation laufen 40 und 45 fps gleichmäßig; die Empfehlungen
unten berücksichtigen das.

### Nicht geändert

- **CPU-Reserve** (mittel, Schätzung): Den Hauptthread spürbar zu entlasten (Requisiten je Scheibe zwischenspeichern,
  Projektion und Boden auf typisierte Packed-Arrays oder eine GDExtension, das Render-Thread-Modell „Separate“
  erproben) ist ein eigenes Vorhaben und sollte erst nach einer Messung auf dem Deck angegangen werden. Billige
  Stellschrauben bringen wenig (gemessen: `render.lod_merge_px` 4 spart 4 % von `_draw`, `render.draw_distance_m` 700
  spart 8 % je Bild, ändert aber Sichtweite und Fairness). Messen auf dem Deck: im Schnellzugriffsmenü unter Leistung
  die Overlay-Stufe 3 oder 4 (Frametime-Graph) einschalten; eine `game_config.json` neben der ausführbaren Datei mit
  `{"hud": {"show_fps": true}, "debug": {"show_render_stats": true}}` blendet Bildrate und Renderzeiten im Spiel ein.
  Szenen: die erste Attract-Demo (Titel eine Minute liegen lassen) und Feierabendverkehr vor Frankfurt.
- **Analoges Gas hält kein Tempo** (niedrig): Halb gedrückter RT verlängert nur die Beschleunigung, am Ende steht
  trotzdem die Höchstgeschwindigkeit. Das ist eine Entscheidung zum Fahrmodell (gegenüber der Tastatur kein Nachteil);
  ein Zieltempo je Trigger-Stellung würde das Fahrgefühl ändern und sollte vorher entschieden werden.
- **Schnee mit Steuerkreuz oder Tastatur** (niedrig, modelliert): Wer die Taste wie im Trockenen hält, pendelt (19 von
  30 nach 8 s nicht ruhig), getippt geht es. Das ist die gewollte Schwierigkeit („früh gegenlenken“); der Wetterhinweis
  ist mit 22 px und 1023 von 1080 px schon an der Breitengrenze, ein gerätebezogener Zusatz passt nicht hinein.
  Lenkhilfen nur für digitale Eingaben würden die Balance zwischen den Geräten verschieben.

### Was abgeleitet bleibt

- **Steam Input**: ob der eingebaute Controller Gerät 0 ist, die eigene Totzone der Deck-Sticks (deshalb reicht im
  Spiel 0,12; ein driftender Stick am benutzten Pad braucht in einer `game_config.json` z. B.
  `{"input": {"stick_deadzone": 0.2}}` – ein zweites, nur herumliegendes Pad lenkt seit der Nachprüfung nicht mit)
  und wie Rumble auf die Haptik des Decks umgesetzt wird. Die Vibrationsstärken sind gewählt, nicht gespürt
  (einstellbar unter `input.vibration`).
- **gamescope**: die Erkennung über `XDG_CURRENT_DESKTOP=gamescope` bzw. `GAMESCOPE_WAYLAND_DISPLAY`, ob das Steam-Menü
  dem Spiel den Fokus nimmt (dann pausiert es), Standby (die Regel ist geprüft, ein echter Schlafzustand nicht).
- **Leistung, Akku und Ton auf dem Gerät**: CPU-Zeiten auf dem Deck, PipeWire-Aussetzer beim Motorstart.

## Verbleibende Grenzen

- **Rennen mit Balken**: Das Straßenbild ist für 1280×720 berechnet (Projektion, Hintergründe, Sprites); im Rennen
  bleiben deshalb oben und unten 40 px Schwarz. Die Menüs nutzen den ganzen Bildschirm.
- **Klein, aber im Rahmen**: Die kleinsten Texte (Etappenbeschreibung, Tutorial-Kasten, Tabellenköpfe) haben 9 px
  x-Höhe bzw. 11 px Versalhöhe – Valves Mindestmaß ist erfüllt, mehr Platz gibt das 1280×720-Layout ohne Umbau nicht her.
- **Tastensymbole im Xbox-Stil**: A/B/X/Y, LT/RT und LS als Schrift-Symbole; das Deck nennt die Trigger R2/L2 und
  hat statt „Start“ die Taste ≡ – Lage und Funktion sind gleich. Eigene Deck-Symbole gibt es nicht.
- **Steam-Menü pausiert nicht unbedingt**: Ob das Spiel beim Öffnen des Steam-Menüs oder des Schnellzugriffsmenüs
  den Fokus verliert (und dann pausiert, seit der Prüfung v0.5.1 auch im Countdown), hängt von gamescope ab – vorher
  mit ≡ pausieren.
- **Fortschritt innerhalb einer Etappe** wird nicht gespeichert (gespeichert wird nach jeder Etappe). Der
  Standby des Decks behält das laufende Spiel; nach dem Aufwachen ist das Rennen pausiert (abgeleitet, siehe oben).
- **CPU-Reserve**: In dichten Szenen und Städten reichen 60 fps auf dem Deck wahrscheinlich nicht immer (Schätzung,
  Abschnitt *Prüfung v0.5.1*); dann hilft eine Bildrate von 40 oder 45.
- **Nicht auf echter Hardware geprüft**: Leistung, Akkulaufzeit, Verhalten unter gamescope, die
  Steam-Input-Belegung und die Vibration sind aus Messungen auf dem Entwicklungsrechner und den Eigenschaften des
  Decks abgeleitet.

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
  ≡ pausiert; in Menüs A wählt, B geht zurück, gehaltenes Steuerkreuz oder gehaltener Stick laufen durch Listen,
  L1/R1 (LB/RB) blättern 8 Einträge weiter. Ein angedockter Deck mit externem Controller wird mit jedem der beiden
  Controller gesteuert; gelenkt wird mit dem Stick des zuletzt benutzten.
- Vibration im Rennen: Optionen → „Vibration“ (Standard An); Steam Input setzt sie in die Haptik des Decks um
  (abgeleitet, nicht am Gerät gespürt).

**Im Spiel**: Optionen → **Vollbild: An** – auf dem Deck schon voreingestellt (im Spielmodus immer, solange „Vollbild“
nicht ausgeschaltet wurde). Im Vollbild hat das Fenster genau 1280×800: Die Menüs füllen den Bildschirm, keine
Skalierung von gamescope kann das Bild strecken, und im Desktop-Modus verdeckt keine Taskleiste das Spiel. Den
Spielernamen am einfachsten gleich in den Optionen mit A im Namensfeld eingeben.

**Schnellzugriffsmenü (Taste „…“) → Leistung**: Skalierung so lassen bzw. nicht auf „Strecken“ stellen (das Bild ist
16:9). Bildrate:

- **Deck LCD** (60 Hz): Bildrate 60 (Standard). Bei Rucklern in dichtem Verkehr oder für mehr Akku: 40 Hz
  Bildwiederholrate und Bildrate 40, oder Bildrate 30.
- **Deck OLED** (90 Hz): Bildwiederholrate 60 Hz mit Bildrate 60, oder 90 Hz mit Bildrate 45 (Akku: 30). Volle
  90 fps schafft das Spiel in dichten Szenen voraussichtlich nicht (Schätzung).

Seit der Render-Interpolation (Prüfung v0.5.1) läuft die Straße bei 30, 40, 45, 60 und 90 fps gleichmäßig – gemessen
am Bildtakt der Simulation, nicht am Gerät.

**Spielstände sichern**: Steam Cloud gilt nicht für Nicht-Steam-Spiele. Einstellungen, Spielstand und Bestenlisten
liegen in `~/.local/share/godot/app_userdata/Crossing Europe – A Racing Xperience/` – diesen Ordner bei Bedarf
sichern. Eine `game_config.json` neben der ausführbaren Datei wirkt wie am PC (siehe [README](../README.md)).

**Angedockt** an einem 16:9-Monitor oder Fernseher: in den Eigenschaften des Spiels die Spielauflösung auf „Nativ“
stellen – dann läuft es in der Auflösung des Bildschirms, füllt ihn ohne Balken und wird scharf skaliert (1080p:
Faktor 1,5). Mit 1280×800 würde das 16:10-Bild samt Balken noch einmal in den 16:9-Bildschirm eingepasst. Im
Spielmodus startet das Spiel dabei im Vollbild (vor der Prüfung v0.5.1: als 1280×720-Fenster, das gamescope weich
hochskalierte); wer „Vollbild“ in den Optionen einmal ausgeschaltet hat, schaltet es dort wieder an. Ein „Aus“, das
v0.5.0 oder v0.5.1 gespeichert hat, zählt dabei nicht: Diese Fassungen schrieben den Wert immer mit, auch angedockt
ohne Wahl des Spielers.
