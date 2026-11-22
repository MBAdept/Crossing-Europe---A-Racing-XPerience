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

## 4. Umsetzung der Offline-Synthese (`tools/audio/traffic_synth.py`)

Stand der Schleifen in `assets/audio/traffic/`: Modell 1 (`synth.model` im JSON). Hören war während der Entwicklung
nicht möglich; abgesichert ist die Qualität durch Messungen (§4.6) und eine Vorbeifahrt-Simulation mit einem
Referenzmodell für Raumklang und Doppler (§4.7). Die Demos liegen zum Anhören bereit.

### 4.1 Dateien

| Schleife | Inhalt | Bezugspunkt | Länge |
|---|---|---|---|
| `car_petrol` | 1,5-l-Reihenvierzylinder-Turbobenziner, höchster Gang, Teillast | 120 km/h, 2 500/min | 62 Arbeitsspiele = 2,976 s |
| `car_diesel` | 2,0-l-Reihenvierzylinder-Turbodiesel | 120 km/h, 1 900/min | 48 = 3,031 s |
| `car_sport` | 3,0-l-Reihensechszylinder-Turbo mit Sportauspuff (auch Polizei) | 140 km/h, 3 200/min | 80 = 3,000 s |
| `van_diesel` | 2,0-l-Turbodiesel im Transporter/SUV, höhere Last | 110 km/h, 2 200/min | 55 = 2,999 s |
| `truck_diesel` | 12,8-l-Reihensechszylinder-Diesel (Sattelzugmaschine) | 85 km/h, 1 250/min | 31 = 2,976 s |
| `bus_diesel` | 10,7-l-Reihensechszylinder-Diesel, Heckmotor (Reisebus) | 90 km/h, 1 300/min | 32 = 2,954 s |
| `tires_car` | Abrollgeräusch von 4 Pkw-Reifen 205/55 R16 | 120 km/h | 3,000 s |
| `tires_truck` | Abrollgeräusch von 12 Lkw-Reifen (Lenk-, Antriebs-, 3 Aufliegerachsen) | 85 km/h | 3,000 s |
| `air` | Umströmung der Karosserie („Wusch“) | 120 km/h | 3,000 s |

- **WAV:** Mono, 16 Bit PCM, 32 kHz, ohne Zusatz-Chunks. Die ganze Datei ist die Schleife.
- **Godot-Import** (`<name>.wav.import`, vom Werkzeug geschrieben, Godot ergänzt uid/Pfade): `compress/mode=0`
  (unkomprimiert; Godot 4.7 nimmt sonst QOA – verlustbehaftet, und `data.size()` ist dann keine Samplezahl),
  `edit/loop_mode=2` (vorwärts), `edit/loop_begin=0`, `edit/loop_end=<Samplezahl>`. Gemessen (Movie Maker,
  Testton): Godot spielt `[loop_begin, loop_end)` und interpoliert über den Umlauf hinweg sauber; das
  Import-Standardende −1 würde zu N−1 (ein Sample zu kurz: kleiner Phasensprung je Umlauf, beim 100-Hz-Testton
  −39 dB). Die geladenen Streams loopen also bereits richtig. Setzt die Laufzeit die Schleife selbst: `loop_end = data.size() / 2` (nur bei 16-Bit-PCM-Mono
  richtig), nicht `N − 1`.
- **JSON:** Laufzeitfelder wie §1 (Pegel von Lkw und Bus geändert, §4.10). `synth` ist rein informativ (Generator,
  Lautheitsbezug, je Schleife Bezugspunkt, Komponentenanteile und die Messwerte aus §4.6) – die Laufzeit ignoriert es.

### 4.2 Motoren

`traffic_synth.py` importiert das physikalisch angelehnte Modell aus `engine_synth.py` (nicht kopiert, siehe
[motorsound.md](motorsound.md) §5) und erweitert `CarModel` in der Unterklasse `TrafficEngine`:

- **Lastzustand `cruise`** (Teillast im höchsten Gang, eingeschwungen) aus `profile.cruise`: Saugrohrdruck `p_im`,
  Druckverhältnis bei „Auslass öffnet“ (Verbrennung) `ratio`, Temperaturen bei „Auslass öffnet“ und im Krümmer,
  Streuung, Abgasgegendruck; beim Benziner teilweise geöffnete Drosselklappe (`throttle_r`, Widerstand × ρc/S) mit
  etwas Drosselzischen, beim Diesel Nageln (`knock`). Auslassstoß, Krümmer-Wechselwirkung, Aufsteilung,
  Auspuffnetzwerk, Strömungsrauschen, Ansaugung und Mechanik rechnet `engine_synth` unverändert.
- **Hörer in der Nachbarspur:** 3,5 m seitlich der Fahrzeugachse, 1,6 m hoch (Höhe der Verfolgerkamera), längs auf
  Höhe von Motor und Auspuff (`profile.listener`, Fahrzeugkoordinaten x quer, y nach vorn ab Heck, z hoch). Dafür wird
  `engine_synth.LISTENER` während der Synthese umgesetzt (nur in diesem Prozess). Von der Seite hört man neben dem
  Endrohr den Motorraum (Verbrennungs- und Mechanikgeräusch durch Radhäuser und Unterboden, Abschattung
  `profile.shadow`) und die Ansaugung.
- **Zahnradrasseln** (zusätzliche Komponente `rattle`, Lkw und Bus): Jeder Verbrennungsstoß entlastet Steuer- und
  Nebentriebsräder, die Zähne heben im Flankenspiel ab und schlagen wieder an – 1–3 Anschläge in den ersten ~180°
  nach OT, Stärke mit dem Verbrennungsdruck, metallische Moden 2,3–5,9 kHz, Weg Motorraum → Hörer wie die übrige
  Mechanik.
- **Komponentenpegel** (`profile.levels`) werden am Reisepunkt selbst eingestellt, als K-bewerteter Pegel jeder
  Komponente in dB relativ zum Auspuff. K- statt A-Bewertung, weil Auspuff und Ansaugung fast nur tiefe Ordnungen
  haben (die A-Bewertung unterschätzt deren Lautheit um 15–20 dB). Der Motorraum ist von der Seite bei Teillast
  wesentlich: Abstand K−A der Schleifen 4,2–7,5 dB statt 15–16 dB bei reinem Auspuffklang.
- **Schleife:** K ganze Arbeitsspiele (Periode in ganzen Samples, K·Periode ≈ 3 s), geschnitten an der leisesten
  Kurbelstellung (geringste Energie über 2 kHz im Mittel aller Zyklen – nicht auf einer Stoßfront). **Naht:** die
  eigene Fortsetzung des Signals nach dem letzten Arbeitsspiel wird über 40 ms in den Schleifenanfang überblendet;
  die Wiedergabe springt vom letzten Sample in das natürlich folgende. Weil die Fortsetzung zur selben Kurbelstellung
  gehört, ist der periodische Anteil kohärent; die Gewichte halten die Leistung trotz des unkorrelierten
  Rauschanteils konstant (w_a² + w_b² + 2 w_a w_b ρ = 1, gemessene Korrelation ρ 0,73–0,96).

| Schleife | Motor | Auspuff | Reisepunkt | Pegel (LU re Auspuff) | Charakter |
|---|---|---|---|---|---|
| `car_petrol` | 1,5 l R4 Turbo, 74,5 × 85,9 mm, 1-3-4-2 | Krümmer im Kopf, Turbine, motornaher Kat, Mittelschalldämpfer (Absorption), Endschalldämpfer mit Anti-Dröhn-Resonator, ein Endrohr | p_im 0,68 bar, Drosselklappe teilweise offen | Verbrennung −3, Mechanik −5, Ansaugung −8, Einspritzung −12, Verdichter −12, Zischen −14, Ventilstrahl −14, Endrohrstrahl −16 | weiches Brummen (2. Ordnung 83 Hz), Surren aus dem Motorraum |
| `car_diesel` | 2,0 l R4 TDI (Profil `kombi`), 1-3-4-2 | wie Kombi: VTG-Turbine, Oxi-Kat, Partikelfilter, zwei Schalldämpfer, Resonator | p_im 1,25 bar, Nageln 0,4 | Nageln −4, Verbrennung −6, Mechanik −7, Ansaugung −8, Einspritzung −9 | Brummen 63 Hz, leichtes Nageln |
| `car_sport` | 3,0 l R6 Turbo (Profil `limousine`), 1-5-3-6-2-4 | Twin-Scroll, Kat, Durchgangsresonator, zwei Sport-Endtöpfe (Klappen offen), vier Endrohre | p_im 0,80 bar | Verbrennung −5, Ventilstrahl −6, Ansaugung −6, Endrohrstrahl −7, Mechanik −7 | 3. Ordnung 160 Hz, obertonreich, leicht sägend |
| `van_diesel` | 2,0 l R4 TDI (Profil `kombi`) | VTG-Turbine, Kat, Partikelfilter, langes Rohr, ein Endtopf | p_im 1,55 bar (mehr Last), Nageln 0,5 | Nageln 0, Mechanik −4, Verbrennung −4, Einspritzung −6, Ansaugung −6 | rauer, deutliches Nageln, Motor weniger abgeschirmt (Abschattung 0,6) |
| `truck_diesel` | 12,8 l R6, 132 × 156 mm, 1-5-3-6-2-4, Krümmer in zwei Hälften | Twin-Entry-Turbine, Fallrohr, 2,6 m Rohr am Rahmen, Schalldämpferbox mit Oxi-Kat, Partikelfilter und SCR (drei Kammern), Endrohr seitlich nach unten | p_im 1,9 bar, Nageln 0,5 | Ansaugung −6, Verdichter −10, Verbrennung −12, Nageln −12, Rasseln −12, Mechanik −14, Einspritzung −16 | schwer: 3. Ordnung 62,5 Hz mit 1,5. Ordnung (31 Hz) aus den Krümmerhälften, Nageln, Rasseln |
| `bus_diesel` | 10,7 l R6 Heckmotor, 125 × 145 mm | kurze Rohrführung, Querschalldämpferbox, Endrohr hinten links | p_im 1,75 bar, Nageln 0,4 | Ansaugung −8, Verdichter −12, Verbrennung −13, Mechanik −15, Nageln −15, Einspritzung −19, Rasseln −19 | weicher: gekapselter Motorraum (Abschattung 0,3 ab 1,2 kHz) |

### 4.3 Reifen (Abrollgeräusch)

Je Reifen, alles zyklisch über genau die Schleifenlänge (Filter als FFT über N Samples, Impulse auf einem Ring) –
periodisch per Konstruktion:

1. **Profilblöcke:** Teilungsfolge (Pitch Sequencing) aus drei Blocklängen in Zufallsfolge, die sich jede Umdrehung
   wiederholt. Jeder Block schlägt beim Einlauf in die Aufstandsfläche an; Stärke = Blockgröße × Straßentextur unter
   diesem Block (log-normal, σ 0,5 bzw. 0,45) × Rundlauf (einmal je Umdrehung) × langsame Belagsänderung;
   Blockantwort als gedämpfte Moden (Güte 4–6). Damit genau eine Schleife Ereignisse enthält, wird das Muster über
   die Schleife um weniger als eine halbe Teilung gestreckt. Jeder Reifen hat eigenen Abrollumfang (±0,6 %:
   Verschleiß, Druck, Last) und Startwinkel – die Muster schweben gegeneinander.
2. **Luftpumpen:** Profilrillen werden beim Einlauf zusammengedrückt (Luft entweicht) und beim Auslauf wieder
   geöffnet (Luft wird angesaugt) – kurze Rauschstöße 0,8–4,5 kHz (Lkw 0,6–3,8 kHz), zufällige Variante je Ereignis.
3. **Texturanregung des Gürtels:** Rauschen mit dem Spektrum der vom Profil eingehüllten Fahrbahn-Makrotextur
   (Maximum bei 50 mm Wellenlänge → 667 Hz bei 120 km/h; Lkw 65 mm → 363 Hz bei 85 km/h), Gürtelresonanz,
   Rundlauf.
4. **Hornverstärkung** im Keil zwischen Reifen und Fahrbahn für 1–3: +3 dB um 1,5 kHz (Lkw +4 dB um 1,1 kHz).
5. **Reifenhohlraum-Resonanz:** der Luftring im Reifen, Pkw 218 Hz, Lkw 141/138/128 Hz (Lenk-, Antriebs-,
   Aufliegerreifen; je Reifen ±1,2 %), durch die Drehung in vor- und rücklaufende Welle aufgespalten
   (±0,6 · v/Umfang), Güte 28–38, angeregt von den Kräften in der Aufstandsfläche. Beim Lkw ergeben 12 Reifen ein
   Bündel schwebender Linien („singend“).
6. **Fahrbahnunebenheit:** tieffrequentes Rumpeln (Maximum 70 bzw. 55 Hz, schwankend).
7. **Belagsänderung:** langsame Pegeländerung (gemeinsam ±1,0/1,2 dB, je Reifen ±0,6 dB, 0,25–3 Hz).

| | `tires_car` | `tires_truck` |
|---|---|---|
| Reifen | 4 × 205/55 R16, Umfang 1,93 m (17,2–17,3 U/s) | 2 Lenkachse 315/70 R22.5 (Rillen), 4 Antriebsachse (Block, Zwillingsreifen), 6 Auflieger 385/65 R22.5 (Rillen); 7,0–7,5 U/s |
| Teilung | 30 mm, Längen 0,82/1,0/1,18 → 1,11 kHz | 42 mm ±10 % → 562 Hz, 58 mm ±16 % → 407 Hz, 40 mm ±8 % → 590 Hz |
| Aufstandslänge | 0,14 m | 0,22–0,24 m |
| Anteile (dB, relativ) | Textur 0, Profil −7, Hohlraum −8, Rumpeln −8, Luftpumpen −15 | Textur 0, Profil −4, Hohlraum −7, Rumpeln −8, Luftpumpen −17 |
| Tiefpass | 6 kHz | 5 kHz |
| Terzspektrum (rel. Maximum) | Maximum 1 kHz; 500 Hz −3,4; 250 Hz −3,6 (Hohlraum); 125 Hz −8,4; 2 kHz −6,2; 4 kHz −13,6; 8 kHz −26,7 dB | Maximum 630 Hz; Hohlraum-Buckel 125 Hz −3,2; 250 Hz −4,6; 2 kHz −9,6; 4 kHz −20,2 dB |
| Tonalität (stärkste Linie über dem Terz-Median) | 13,6 dB | 10,5 dB |

Das Pkw-Spektrum folgt dem typischen Verlauf von Reifen-Fahrbahn-Geräusch auf dichtem Asphalt (Maximum 0,8–1,25 kHz,
darüber etwa −8 bis −10 dB/Oktave; Sandberg/Ejsmont), das Lkw-Spektrum liegt tiefer und hat mehr Tieftonanteil.
Tonalität: reines Rauschen erreicht mit diesem Maß 8 dB (Zufall), die Reifen liegen wenig darüber – die
Wiederholung je Umdrehung ist als leichte Rauigkeit da, ohne Profilpfeifen.

### 4.4 Fahrtwind (`air`)

Drei Bänder turbulenten Rauschens mit langsamen Böen (periodisch aus Schleifenharmonischen): Nachlauf (Maximum 90 Hz,
Böen ±3 dB bei 1,5–6 Hz), Ablösung an A-Säule, Spiegeln und Radhäusern (350 Hz, −3 dB, Böen ±2 dB bei 2–9 Hz),
Spalte und Kanten (2,8 kHz, −24 dB). Ergebnis: flach von 125 bis 500 Hz, darüber etwa −4,5 dB/Oktave (1 kHz −4,
2 kHz −8, 4 kHz −12 dB), keine Linien (Tonalität 8 dB = Zufallsniveau), Hüllkurve schwankt um bis zu 10 dB (Böen).

### 4.5 Pegel und Kalibrierung

Jede Schleife: Gleichanteil entfernt, auf **−20 LUFS** gebracht (K-Bewertung nach ITU-R BS.1770 ohne Gating, über
die ganze Schleife). Alle Schleifen sind damit gleich laut; die Verhältnisse zwischen Motor, Reifen und Fahrtwind und
zwischen den Klassen kommen nur aus `gain_db` und `level_db_per_decade`. Spitzen −5,7 bis −9,7 dBFS (Reserve für
positive `gain_db` und Tonhöhe).

| Schleife | Lautheit | A-bewertet | K−A | Spitze | RMS |
|---|---|---|---|---|---|
| `car_petrol` | −20,0 LUFS | −25,7 dB(A) | 5,7 | −8,9 dBFS | −19,8 dBFS |
| `car_diesel` | −20,0 | −25,7 | 5,7 | −9,5 | −19,0 |
| `car_sport` | −20,0 | −24,2 | 4,2 | −9,7 | −20,7 |
| `van_diesel` | −20,0 | −24,4 | 4,4 | −9,6 | −19,9 |
| `truck_diesel` | −20,0 | −25,4 | 5,4 | −6,7 | −19,3 |
| `bus_diesel` | −20,0 | −27,5 | 7,5 | −9,2 | −18,5 |
| `tires_car` | −20,0 | −22,6 | 2,6 | −6,8 | −21,1 |
| `tires_truck` | −20,0 | −23,6 | 3,6 | −7,0 | −20,5 |
| `air` | −20,0 | −24,7 | 4,7 | −5,7 | −20,3 |

`gain_db`: Werte des Vertrags, außer `truck_diesel` +3,0 (statt 0,0), `tires_truck` +1,0 (statt 0,0) und
`bus_diesel` 0,0 (statt −1,0) – Begründung in §4.10.

### 4.6 Prüfungen und Ergebnisse

| Prüfung | Ergebnis |
|---|---|
| Sprung an der Naht (Schritt letztes → erstes Sample, Perzentil unter allen Schritten der Schleife; Sprung ≈ 100) | P9–P53 |
| HF-Energie an der Naht (über 4 kHz, 2-ms-Fenster, Perzentil unter allen Positionen; Klick ≈ 100) | P23–P86 |
| Pegelsprung der 50-ms-Hüllkurve über die Naht / größter Sprung sonst | 0,04–0,47 dB / 0,59–2,97 dB |
| Gleichanteil | < 0,01 LSB |
| Spitzen, Übersteuerung | −5,7 bis −9,7 dBFS, keine |
| Godot-Wiedergabe (Movie Maker, `truck_diesel` und `tires_car` je 7,5 s geloopt): Energie 10–15 kHz in 1-ms-Fenstern an den Umlaufpunkten | Perzentil 54–85 (Zufall: ~87 für das Maximum aus 5 Fenstern); der einzige Ausreißer ist der Start aus der Stille |
| Import in Godot | alle neun: 16 Bit, 32 kHz, Mono, `LOOP_FORWARD`, `loop_begin` 0, `loop_end` = Samplezahl |
| Determinismus | zweiter Lauf bitgleich (WAV und JSON) |
| Motorbanken der Spielerautos | unverändert (`engine_synth.py` und `assets/audio/engines/*` md5-gleich) |

### 4.7 Vorbeifahrt-Simulation (`tools/audio/traffic_preview.py`)

Spielt die Schleifen nach den Regeln aus §1 (Tonhöhe `(v/ref_kmh)^pitch_exp` mit Grenzen 0,6–1,6 × Streuung ±6 % je
Fahrzeug-ID, Pegel `gain_db + level_db_per_decade · log10(v/ref_kmh)`, Motor je ID aus der Klassenliste) und
verräumlicht sie mit einem einfachen, physikalisch exakten Referenzmodell:

- gerade Straße, Hörer (Spieler) 1,2 m hoch, Fahrzeuge 0,6 m, Spurabstand 3,75 m, ruhende Luft;
- **Laufzeit:** jede Ebene wird zur retardierten Zeit τ gelesen (t − τ = |L(t) − S(τ)| / c, c = 343 m/s) – der
  Doppler-Effekt von bewegter Quelle und bewegtem Hörer folgt daraus exakt;
- **Entfernung:** Motor und Reifen 1/r (Pegel 1 bei 7,5 m), Fahrtwind 1/r² (Pegel 1 bei 5 m) × `size`;
  ausgedehnte Quelle r_eff = √(r² + (1,5 m · size)²); Ausblenden 120–150 m;
- **Stereo:** Gleichleistungs-Panorama aus der Einfallsrichtung (0,85 × Sinus des Winkels zur Fahrtrichtung);
- **Luftdämpfung** nach ISO 9613-1 (20 °C, 70 % rel. Feuchte) frequenzabhängig je STFT-Rahmen.

Szenarien und Ergebnisse (Ausgabe −6 dB):

| Szenario | Fahrzeug | L−R Anfahrt / beim Passieren | Tonhöhe nach ÷ vor dem Passieren (gemessen / exakt) | Lautheit max | Schwerpunkt |
|---|---|---|---|---|---|
| `pkw_links`: Spieler 170 km/h überholt Pkw links | Pkw (Benziner) 120 km/h | +2,2 / +13,9 dB | 0,9230 / 0,9231 | −19,7 LUFS | 680 Hz |
| `lkw_rechts`: Spieler 130 km/h überholt Lkw rechts | Lkw 85 km/h | −2,2 / −14,4 dB | 0,9315 / 0,9313 | −16,3 LUFS | 489 Hz |
| `sport_von_hinten`: Sportwagen überholt den Spieler (130 km/h) links | Sportwagen 190 km/h | +2,2 / +12,9 dB | 0,9074 / 0,9074 | −15,0 LUFS | 867 Hz |
| `kolonne_rechts`: Spieler 160 km/h überholt rechts | Pkw 120 / Transporter 110 / Lkw 85 / Bus 90 km/h | −2,3…−2,0 / −11,6…−14,9 dB | 0,939 / 0,923 / 0,886 / 0,893 (Messfehler ≤ 0,31 %) | −19,9 / −19,8 / −17,2 / −17,6 LUFS | 606 / 681 / 484 / 386 Hz |

Die Tonhöhe wird gemessen (log-Frequenz-Kreuzkorrelation des Motorsignals gegen die trockene Schleife), nicht
angenommen; sie fällt beim Passieren wie erwartet (überholter Pkw −7,7 %, Sportwagen von hinten −9,3 %). Ein Lkw ist
2,7–3,4 LU lauter als ein Pkw und hat den tieferen Schwerpunkt. Die Seitenzuordnung stimmt schon auf der Anfahrt
(8–40 m vor dem Hörer kommt der Schall fast von vorn, daher nur ±2 dB) und erreicht 12–15 dB beim Passieren.

Hinweise für die Laufzeit (`TrafficAudio`): Startposition in der Schleife je Fahrzeug zufällig (sonst laufen gleiche
Fahrzeuge phasengleich); Fahrtwind nur nah am Hörer (steilerer Abfall als Motor/Reifen) und mit `size` gewichtet,
sonst dominiert bei Pkw das „Wusch“; die ausgedehnte Quelle (`size`) nimmt einem Lkw beim Passieren 1–3 dB.

### 4.8 Neu erzeugen

```bash
python3 tools/audio/traffic_synth.py                       # alle neun Schleifen + JSON -> assets/audio/traffic/ (~10 s)
python3 tools/audio/traffic_synth.py --only truck_diesel   # einzelne Schleifen (JSON behält die übrigen Einträge)
python3 tools/audio/traffic_synth.py --info                # Plan: Drehzahlen, Arbeitsspiele, Samplezahlen
python3 tools/audio/traffic_synth.py --check               # vorhandene Schleifen prüfen (Länge, Spitze, Naht, DC)
python3 tools/audio/traffic_preview.py --out /tmp/ce_traffic_demo   # Vorbeifahrten, Spektrogramme, MP4, checks.json (~1 min)
python3 tools/audio/traffic_preview.py --scenario lkw_rechts --gain truck_diesel=0 --no-media   # Abgleich ausprobieren
```

Nur Python 3 + numpy; ffmpeg (OGG, Spektrogramme, MP4) und ImageMagick (Beschriftung der Diagramme) nur für die
Demos. Die Ausgabe ist deterministisch (feste Zufallssamen je Schleife). Danach `godot --headless --import`
(macht `tools/run_tests.sh`); die `.import`-Dateien behalten ihre uid, nur `[params]` wird neu geschrieben.

### 4.9 Abstimmen

- **Motor:** `engine_profiles()` – Charakter der Anlage über `exhaust` (wie motorsound.md §5.6), Betriebspunkt über
  `cruise`, Anteil Motorraum/Ansaugung/Mechanik über `levels` (LU re Auspuff), Abschattung des Motorraums über
  `shadow`, Perspektive über `listener`.
- **Reifen:** `TIRES` – Teilung und Teilungsfolge (`pitch_mm`, `ratios`: kleiner Bereich = singender), Zufall der
  Anschläge (`impact_sigma`: größer = rauschiger, weniger Profilpfeifen), Textur (`peak_mm`, Flanken), Hohlraum
  (`cavity_hz`, `cavity_q`), Anteile `levels`, Horn, Tiefpass.
- **Fahrtwind:** `AIR` – Bänder (Maximum, Flanken, Pegel), Böen.
- **Gesamtpegel:** nicht an den Schleifen drehen (alle −20 LUFS), sondern an `gain_db` in `SOUNDS`.

### 4.10 Abweichungen vom Vertrag und bekannte Grenzen

- **Pegel Lkw/Bus:** `truck_diesel` +3,0 dB (Vertrag 0,0), `tires_truck` +1,0 dB (0,0), `bus_diesel` 0,0 dB (−1,0).
  Mit den Vertragswerten war ein Lkw in der Simulation beim Passieren nur 0,6–1,5 LU lauter als ein Pkw (gleich laute
  Schleifen; die ausgedehnte Quelle und das „Wusch“ des Pkw fressen den Abstand), §3 verlangt „hörbar lauter“.
  Am Straßenrand ist ein Lkw-Motor bei 85 km/h etwa 10 dB(A) lauter als ein Pkw-Motor bei 120 km/h, die Reifen nur
  3–5 dB – daher vor allem der Motor. Jetzt: Lkw +2,7…3,4 LU, Bus +2,3 LU über dem Pkw. Zurückdrehen: drei Zahlen in
  `SOUNDS`.
- **Zusätzliches JSON-Feld** `synth` (informativ).
- **Schleifenlängen** 2,954–3,031 s statt glatt 3 s: Motoren aus ganzen Arbeitsspielen.
- **Eine feste Perspektive** (Nachbarspur, Motor-/Auspuffhöhe): die Richtwirkung (vorn mehr Motorraum und Reifen,
  hinten mehr Auspuff) steckt nicht in der Schleife; die Laufzeit hat dafür nur Panorama, Entfernung und Tiefpass.
- **Tonhöhe:** die Laufzeit verschiebt mit `pitch` auch alle festen Resonanzen (Auspuff, Motorblock,
  Reifenhohlraum) mit – bei Motoren um bis zu −40/+60 % (Grenzen 0,6–1,6), beim Reifen nur mit Exponent 0,35. Beim
  echten Reifen wandern Profil- und Texturfrequenzen linear mit der Geschwindigkeit, der Hohlraum gar nicht; der
  Exponent 0,35 des Vertrags ist ein Kompromiss dazwischen.
- **Lautheitsmaß:** Gleiche K-bewertete Lautheit heißt für die tieftonreichen Motorschleifen nicht ganz gleich laut
  empfunden (bei leiser Wiedergabe wirken sie leiser); der Abgleich über `gain_db` wurde in der Simulation geprüft.
- **Polizei** nutzt wie im Vertrag `car_sport`; ein eigener Polizeimotor (Diesel-Kombi) wäre möglich.
