# Verkehrsgeräusche und Raumklang – Vertrag zwischen Offline-Synthese und Laufzeit

Anlass (Playtest v0.3.0): Die Motoren sind gut, klingen aber „ein wenig flach“; Autos, an denen man vorbeifährt,
hört man nicht. Eine Aufnahme des Spiels (Movie-Maker-Modus) zeigt: Der gesamte Ton ist mono und trocken (linker und
rechter Kanal identisch, kein Raum).

Ziel:

1. **Vorbeifahrten hörbar**: Jedes Fahrzeug in der Nähe (Pkw, Transporter/SUV, Sportwagen, Lkw, Bus, Polizei)
   klingt räumlich – Motor, Abrollgeräusch der Reifen und Luftverwirbelung, im Stereobild links/rechts dort, wo es
   fährt, leiser und dumpfer mit der Entfernung, mit Doppler-Effekt (beim Überholen höher, danach tiefer).
2. **Raumklang**: Hall im Tunnel (Motor, Verkehr, Martinshorn), draußen dezente frühe Reflexionen, das eigene Auto
   leicht breiter im Stereobild statt punktförmig mono.
3. **Martinshorn räumlich**: die Polizei mit Position und Doppler statt einer Mono-Schleife.

## 1. Dateien (Offline-Synthese → Laufzeit)

`assets/audio/traffic/traffic_sounds.json` und die Schleifen `assets/audio/traffic/<name>.wav` (Mono, 16 Bit,
32 kHz, nahtlos schleifbar: Ende geht ohne Sprung in den Anfang über; 2–4 s; Godot importiert WAV, die Laufzeit
schaltet die Schleife ein).

```json
{
  "format": "ce-traffic-sounds-1",
  "sample_rate": 32000,
  "sounds": {
    "car_petrol":   {"file": "car_petrol.wav",   "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_diesel":   {"file": "car_diesel.wav",   "layer": "engine", "ref_kmh": 120, "pitch_exp": 1.0, "gain_db": -4.0},
    "car_sport":    {"file": "car_sport.wav",    "layer": "engine", "ref_kmh": 140, "pitch_exp": 1.0, "gain_db": -2.0},
    "van_diesel":   {"file": "van_diesel.wav",   "layer": "engine", "ref_kmh": 110, "pitch_exp": 1.0, "gain_db": -3.0},
    "truck_diesel": {"file": "truck_diesel.wav", "layer": "engine", "ref_kmh": 85,  "pitch_exp": 1.0, "gain_db": 0.0},
    "bus_diesel":   {"file": "bus_diesel.wav",   "layer": "engine", "ref_kmh": 90,  "pitch_exp": 1.0, "gain_db": -1.0},
    "tires_car":    {"file": "tires_car.wav",    "layer": "tires",  "ref_kmh": 120, "pitch_exp": 0.35, "gain_db": -3.0, "level_db_per_decade": 30.0},
    "tires_truck":  {"file": "tires_truck.wav",  "layer": "tires",  "ref_kmh": 85,  "pitch_exp": 0.35, "gain_db": 0.0, "level_db_per_decade": 30.0},
    "air":          {"file": "air.wav",          "layer": "air",    "ref_kmh": 120, "pitch_exp": 0.5, "gain_db": -6.0, "level_db_per_decade": 40.0}
  },
  "classes": {
    "car":    {"engine": ["car_petrol", "car_diesel"], "tires": "tires_car",   "air": "air", "size": 1.0},
    "sport":  {"engine": ["car_sport"],                "tires": "tires_car",   "air": "air", "size": 1.0},
    "van":    {"engine": ["van_diesel"],               "tires": "tires_car",   "air": "air", "size": 1.3},
    "truck":  {"engine": ["truck_diesel"],             "tires": "tires_truck", "air": "air", "size": 2.2},
    "bus":    {"engine": ["bus_diesel"],               "tires": "tires_truck", "air": "air", "size": 2.0},
    "police": {"engine": ["car_sport"],                "tires": "tires_car",   "air": "air", "size": 1.0}
  },
  "models": {"hatch": "car", "sedan": "car", "wagon": "car", "suv": "van", "van": "van", "sports": "sport",
             "truck": "truck", "bus": "bus", "police": "police"}
}
```

- `layer`: `engine` (Motor bei Reisetempo im höchsten Gang, Teillast), `tires` (Abrollgeräusch: Profil-/Luftpump-
  geräusch, Reifenhohlraum-Resonanz um 200–250 Hz, Rauschen; Lkw tiefer, „singender“ mit vielen Achsen),
  `air` (Luftverwirbelung/Fahrtwind des Fahrzeugs; wird nahe am Hörer hörbar: das „Wusch“).
- Wiedergabe-Tonhöhe = `(tempo / ref_kmh)^pitch_exp` (Grenzen 0,6–1,6) × Doppler × zufällige Streuung je Fahrzeug
  (±6 %, fest pro Fahrzeug-ID); Pegel `gain_db` + `level_db_per_decade · log10(tempo / ref_kmh)` (fehlt das Feld:
  0) + Entfernung.
- `models`: Modellname aus der Sprite-ID `traffic/<modell>_<farbe>`; `police/<land>` → `police`. Unbekannt → `car`.
- `size`: Ausdehnung der Quelle relativ zu einem Pkw (große Fahrzeuge klingen beim Vorbeifahren breiter, ihr
  Pegel fällt in der Nähe langsamer ab).

## 2. Laufzeit (`TrafficAudio`, Busse)

- Hörer an der Verfolgerkamera (leicht nach vorn versetzt, `audio.traffic_listener_ahead_m`), Quellen an den
  Fahrzeugpositionen relativ dazu (Querabstand, Längsabstand; Kurven vernachlässigt). Die nächsten
  `audio.traffic_voices` Fahrzeuge (z. B. 6) bekommen eine Stimme (Motor + Reifen + Luft), Zuteilung mit Hysterese,
  Ein- und Ausblenden ohne Knacken.
- Räumlich: Stereo-Panorama aus dem Winkel, Entfernungsdämpfung (Bezugsabstand, Maximalabstand ~150 m),
  Luftdämpfung (Tiefpass mit der Entfernung), Doppler aus der Relativgeschwindigkeit entlang der Sichtlinie
  (`c = 343 m/s`, Übertreibungsfaktor `audio.traffic_doppler`). Godot-3D-Audio in einer eigenen, nicht sichtbaren
  Welt (`AudioStreamPlayer3D`) oder eigene Rechnung – Hauptsache bestimmbar und testbar.
- Martinshorn: räumliche Stimme an der Polizeiposition mit Doppler (die Rennsitzung kennt Position und Tempo).
- Busse: Raum-/Tunnelhall als Effekt auf einem Bus für Motor, Verkehr und Horn; Hallanteil blendet beim Ein- und
  Ausfahren in Tunnel über (Kamera im Tunnel); draußen kurze, leise frühe Reflexionen. Das eigene Auto bekommt
  leichte Stereobreite (z. B. dekorrelierte Reflexionen), bleibt aber mittig.
- API: `AudioManager.set_traffic(vehicles, listener)` je Frame aus der Rennsitzung (Fahrzeuge mit `id`, Modell/Set,
  Querposition, Längsposition, Tempo), `AudioManager.set_environment({"tunnel": bool})`; Pause/Szenenwechsel blenden
  alles aus.
- Leistung: Mischen macht Godot; GDScript-Aufwand je Frame < 0,3 ms.

## 3. Prüfung

Movie-Maker-Aufnahme des echten Spiels mit Ton (Xvfb, `--write-movie <datei>.avi --fixed-fps 30`, Szenarien aus
`tests/race/shoot_vehicles.gd`): Beim Überholen eines Autos links muss der linke Kanal vorher lauter werden, die
Tonhöhe beim Passieren sinken, ein Lkw hörbar lauter und tiefer sein als ein Pkw, im Tunnel Hall hörbar werden.
