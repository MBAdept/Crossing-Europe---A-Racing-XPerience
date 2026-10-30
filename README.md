# Crossing Europe – A Racing Xperience

Arcade-Racer in Pseudo-3D: Etappenrennen quer durch Europa auf Bestzeit – mit Verkehr in Fahrtrichtung,
Nachtankzwang, Radarfallen und Polizei, Tageszeit und Wetter. Vorbilder: *Enduro* (Atari VCS) und
*The Great American Cross-Country Road Race* (Activision).

- Design: [docs/Design-Dokument.md](docs/Design-Dokument.md)
- Technik: [ARCHITECTURE.md](ARCHITECTURE.md) und die Moduldokus in [docs/](docs/)
- Engine: Godot 4.7.2 (GDScript, Renderer „GL Compatibility“), alle Fahrzeuge, Bäume, Gebäude, Tankstellen und
  Symbole prozedural in Blender 5.2 modelliert und als Sprites gerendert

## Spielen

Linux (x86_64): `CrossingEurope.x86_64` herunterladen, ausführbar machen und starten – eine einzige Datei, keine
Installation nötig.

```bash
chmod +x CrossingEurope.x86_64
```

```bash
./CrossingEurope.x86_64
```

| Aktion | Tastatur | Gamepad |
|---|---|---|
| Lenken | ← → oder A D | linker Stick / Steuerkreuz |
| Gas | ↑ oder W | rechter Trigger / A |
| Bremse | ↓ oder S | linker Trigger / X |
| Pause | Esc oder P | Start |
| Menü: wählen / bestätigen / zurück | Pfeiltasten / Enter / Esc | Stick / A / B |

## Was drin ist

- **Pseudo-3D** aus kurzen Segmenten (Node2D mit `_draw`), Kurven, Hügel mit Kuppen, Tunnel mit Lichterreihen,
  Grenzübergänge mit EU-Schild, Zollhäuschen, neuer Landschaft und landestypischer Polizei.
- **Zeitraffer 12**: Die Straße scrollt mit Tachotempo, Kilometerzähler und Uhr laufen zwölfmal schneller
  (100 km bei 100 km/h = 5:00 min).
- **Fünf Fahrzeuge** (Kompakt, Kombi, Limousine, Sportwagen, Gran Turismo) mit den Werten aus dem Design-Dokument;
  Arcade-Fahrmodell ohne Übersteuern, Untersteuern bei zu hohem Kurventempo.
- **Verkehr** nur in Fahrtrichtung mit Tageskurve, Nachtbonus, Lkw rechts, Spurwechseln; Kollisionen nach den Regeln
  des Dokuments (3 s auf 10 km/h, seitlich schieben, blinken, Ein-Drittel-Regel für Überholer von hinten).
- **Tanken**: Verbrauch 14 + 0,00034·v², Tankstellen alle 60–90 km mit Ankündigung 30/15/5 km, Tankspur,
  „Volltanken? – Gas = Weiterfahren“, Abschleppdienst bei leerem Tank.
- **Radar und Polizei**: Warnung 10 km vorher, 5-km-Feld, 15 % Toleranz, Verfolgung mit Flucht ab 220 km/h,
  „Führerschein, bitte!“; City Limits in den letzten 20 km jeder Etappe.
- **Tageszeit und Wetter**: frei wählbare Startzeit, nächste Etappe 12 h Weltzeit nach dem Ende der vorigen,
  Dämmerung/Nacht/Sonnenaufgang während der Fahrt, Regen und Schnee.
- **Streckennetz** komplett in Datendateien: 50 Städte, 56 Etappen (in beide Richtungen fahrbar), Fähre
  Riga – Rostock, vier Rennen: Kiel – Nürnberg (Route über Kassel oder über Frankfurt), Dresden – Dortmund,
  München – Bremen und das Königsrennen (rund 9.200 km in 40 Etappen).
- **Etappenbildschirm** mit Karte (Natural Earth), Wetter, Rekord-Laufschrift und Top 10; Bestenlisten pro Etappe
  und Rennen mit Fahrzeug, Wetter- und Tageszeit-Symbol; Namenseingabe auch per Gamepad; Spielstand nach jeder Etappe.
- **Sound** komplett prozedural (Motor mit virtuellem Getriebe, Wind, Martinshorn, Blitzer, Tanken, Menümusik).

## Entscheidungen zu den offenen Punkten

Alle Werte stehen in `config/game_config.json` und lassen sich ohne Neubau ändern (siehe unten).

| Offener Punkt | Umsetzung (Startwert) |
|---|---|
| Fahrzeugtypen | Werte wie vorgeschlagen; Beschleunigung als Zeiten 0–100/0–200 je Stufe, Agilität als Lenk- und Kurvengriff |
| Bestenlisten gemeinsam oder getrennt? | beides: gespeichert je Fahrzeugtyp, angezeigt gemeinsam mit umschaltbarem Fahrzeugfilter |
| Wetter im Rennen | zufällig, gewichtet nach Klima der Region (alternativ `random` oder fest pro Etappe) |
| Tempo-Abzug Regen / Schnee / Nacht | −2,5 % / −12 % / −1 %; Regen + Nacht erlaubt jedem Auto noch 220 km/h |
| Zeitstrafe leerer Tank | 90 s Abschleppdienst, danach halber Tank |
| Straßenrand | Bankett bremst auf 90 km/h; Autobahn mit Leitplanke (abprallen), sonst Wiese (bremst auf 40 km/h) |
| Plattform und Eingabe | Linux x86_64, Tastatur und Gamepad |
| Sound, Musik, Sprache | prozeduraler Sound, Menümusik, alle Texte deutsch über `tr()` (übersetzbar) |

## Werte und Strecken anpassen ohne Neubau

- `game_config.json` **neben der ausführbaren Datei** überschreibt einzelne Werte der zentralen Konfiguration:

  ```json
  { "fuel": { "tow_penalty_s": 120 }, "traffic": { "chase_density_factor": 0.3 } }
  ```

- Ein `network.json` neben der ausführbaren Datei (oder in einem Ordner `data/` daneben) ersetzt das eingebaute
  Streckennetz – neue Städte, Etappen und Rennen ohne Codeänderung (Format: [ARCHITECTURE.md](ARCHITECTURE.md) §4).

## Entwicklung

```bash
tools/run_tests.sh
```

```bash
tools/build_linux.sh
```

- `tools/run_tests.sh [filter]` – kompiliert alle Skripte und startet die Headless-Tests.
- `tools/screenshot.sh <präfix> --stage=dev_testetappe --start-km=48 --hour=21 --autopilot --shot-times=2,4`
- `godot --headless --path . -s res://tests/race/run_race.gd -- --race=kiel_nuernberg --autopilot --no-countdown`
  fährt ein ganzes Rennen mit dem Autopiloten durch den echten Menüablauf.
- `tools/blender/render_all.py` rendert alle Sprites neu (Blender 5.2 als Python-Modul `bpy`),
  `tools/map/` erzeugt Karte und Streckennetz.

## Lizenzen der Fremddaten

Schriften: Orbitron, Exo 2, Barlow Condensed, Share Tech Mono (SIL Open Font License, siehe `assets/fonts/`).
Kartendaten: Natural Earth (gemeinfrei) über das npm-Paket `world-atlas` (ISC).
