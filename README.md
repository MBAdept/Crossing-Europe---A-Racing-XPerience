# Crossing Europe – A Racing Xperience

Arcade-Racer in Pseudo-3D: Etappenrennen quer durch Europa auf Bestzeit – mit Verkehr in Fahrtrichtung,
Nachtankzwang, Radarfallen und Polizei, Tageszeit und Wetter. Vorbilder: *Enduro* (Atari VCS) und
*The Great American Cross-Country Road Race* (Activision).

- Design: [docs/Design-Dokument.md](docs/Design-Dokument.md)
- Technik: [ARCHITECTURE.md](ARCHITECTURE.md)
- Engine: Godot 4.7.2 (GDScript), Grafiken aus Blender 5.2 (prozedural modelliert, als Sprites gerendert)

> Stand: Prototyp im Aufbau.

## Spielen

Linux (x86_64): `CrossingEurope.x86_64` ausführbar machen und starten.

```bash
chmod +x CrossingEurope.x86_64
./CrossingEurope.x86_64
```

| Aktion | Tastatur | Gamepad |
|---|---|---|
| Lenken | ← → oder A D | linker Stick / Steuerkreuz |
| Gas | ↑ oder W | rechter Trigger / A |
| Bremse | ↓ oder S | linker Trigger / X |
| Pause | Esc oder P | Start |

## Werte anpassen ohne Neubau

Alle Zahlen stehen in `config/game_config.json`. Eine Datei `game_config.json` **neben der ausführbaren Datei**
überschreibt einzelne Werte, z. B.:

```json
{ "fuel": { "tow_penalty_s": 90 }, "traffic": { "chase_density_factor": 0.3 } }
```

## Entwicklung

```bash
tools/run_tests.sh            # Headless-Tests
tools/screenshot.sh /tmp/s --stage=dev_testetappe --start-km=48 --hour=21 --autopilot --shot-times=2,4
tools/build_linux.sh          # build/CrossingEurope.x86_64
```
