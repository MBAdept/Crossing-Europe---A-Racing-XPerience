
## 6. Motor v3 – Klangprofil „Modern“ (v0.8.0)

Mit dem Klangprofil „Modern“ ([audio-modern.md](audio-modern.md)) bekommt jedes der fünf Autos einen zweiten Motorklang.
Der Motorklang v2 der Abschnitte 1–5 bleibt der Klang des Profils „Arcade“ – Dateien, Klassen und Werkzeug sind
eingefroren. Motor v3 verwendet dasselbe physikalische Modell (das Werkzeug `engine_synth.py` wird importiert, nicht
geändert) und dasselbe zyklussynchrone Verfahren; neu sind Stereo, getrennte Ebenen für Auspuff und Ansaugung, ein
Pegel, der Last und Drehzahl folgt, Bewegung im stehenden Klang, Sättigung unter Last, nativ gemischte
Fahrzeugebenen und ein Mischer, der in einem eigenen Thread läuft (Vertrag D27).

Hören konnte während der Entwicklung niemand. Alles Folgende ist gemessen (auf der Entwicklungsmaschine, ohne
Bildschirm, mit dem Dummy-Audiotreiber) oder ausdrücklich als abgeleitet gekennzeichnet; was die Messungen nicht
sagen, steht in 6.9.

| | Arcade (v2) | Modern (v3) |
|---|---|---|
| Bank | mono, 32 kHz, Float, zwei Lasten je Drehzahlpunkt | stereo, 32 kHz, int16, drei Ebenen je Punkt: Schub, Last (Auspuff), Ansaugung |
| Stereo | ein kurzer Hall auf dem Motorbus | in der Bank: Endrohre bzw. Zylinderbänke an ihrem Platz, Strömungsrauschen je Kanal unabhängig |
| Pegel über Drehzahl und Last | wie die Bank ihn hergibt (Volllast wird beim Kompakten und der Limousine nach oben leiser) | Zielkurven: Volllast steigt mit der Drehzahl, Schub 6–9 dB darunter, Leerlauf und Reisetempo nach dem Pegelplan |
| stehender Klang | 8 Zyklusvarianten, sonst starr (1-s-Pegel ± 0,01–0,04 dB) | dazu schnelle und langsame Zufallsbewegung von Drehzahl, Pegel und Last (± 0,5–0,6 dB im 1-s-Pegel) |
| Turbo | Sinuston im Mischer | Schmalbandton und Strömungsrauschen als nativ gemischte Schleifen (ein Lader mono, zwei Lader links/rechts) |
| Antrieb, Lastwechsel | – | Achs- und Getriebeheulen, Gasannahme, Lastwechselschlag beim Schalten |
| Mischen | im Hauptthread, 0,32 ms je Bild | eigener Thread (0,7–1,0 ms je 1/60 s Klang), synchron für Tests und Movie Maker |

### 6.1 Dateien

`assets/audio/modern/engines/<auto>.json` + `<auto>.i16` (rohes verschachteltes int16, 32 kHz Stereo), dazu der
Eintrag des Autos in `assets/audio/modern/engines/manifest.json` (Art `bank`). Format `ce-engine-bank-2`, gelesen
von `EngineBank2` (`scripts/audio/modern/engine_bank2.gd`):

```json
{
  "format": "ce-engine-bank-2", "car": "gran_turismo", "sample_rate": 32000, "channels": 2, "data": "gran_turismo.i16",
  "engine": { … }, "gearbox": { … },          // wie in Abschnitt 1 – dasselbe Getriebe in beiden Profilen
  "banks": [
    {"rpm": 699.9, "layer": "off", "period": 5486.0, "overlap": 128, "gain": 0.52, "lufs": -15.2, "xrpm": 0.0, "xload": 0.75,
     "cycles": [[0, 5614, 0], [5614, 5614, 0], …]},
    {"rpm": 699.9, "layer": "on", …}, {"rpm": 699.9, "layer": "in", …}, …
  ],
  "clips": {"crackle": [[offset, length, mode], …], "shift": […], "start": […]},
  "layers": {"limiter": {…}, "crackle": {…}, "shift": {…}, "saturation": {…}, "turbo": {…}, "blowoff": {…},
             "driveline": {…}, "tipin": {…}, "thump": {…}},
  "mix": {"gain": 0.4661, "off_gain": 1.0, "in_gain": 1.0, "idle_load": 0.2, "load_curve": 0.55,
          "clip_gain": {"crackle": 1.08, "shift": 1.08, "start": 1.08}},
  "synth": { … }                              // informativ: Abstimmung, Messwerte, Erklärung der Felder
}
```

- **Drei Ebenen je Drehzahlpunkt** (`layer`), alle am selben Zyklusanfang geschnitten:
  `off` = Gas zu (Schub, Leerlauf; Stereo), `on` = Volllast **ohne** Ansaugung (Auspuffstöße, Ventilrauschen,
  Mündungsrauschen, Mechanik, Nageln; Stereo), `in` = die Ansaugung bei Vollgas allein (Ansaugstöße,
  Verdichterrauschen; mono). Jeder Punkt braucht alle drei.
- `cycles`: `[offset, length, mode]` in Frames der Rohdaten; `length = round(period) + overlap`. `mode` 0 = Stereo,
  1 = mono in den linken, 2 = mono in den rechten Abtastwerten desselben Blocks (zwei Mono-Ausschnitte teilen sich
  einen Stereoblock). 8 Varianten für `off` und `on` (unterhalb von 1,35 × Leerlauf 4 für `on`), 4 für `in`.
- `gain`: Jede Bank ist voll ausgesteuert gespeichert (16 Bit); × `gain` ergibt ihren Entwurfspegel. `lufs` =
  K-bewertete Lautheit beim Entwurfspegel (vor `mix.gain`) – der Mischer rechnet damit die Leistung beim Überblenden.
- `xrpm` = Kohärenz mit dem nächsttieferen Drehzahlpunkt derselben Ebene, `xload` = Kohärenz zwischen `off` und `on`
  (je −1…1, gemessen an den gemittelten Zyklen). Damit hält der Mischer beim Überblenden die Leistung (6.3).
- `clips`: `crackle` (12 Varianten), `shift` (2), `start` (1) wie in v2; bei Motoren mit einem Auspuffbild mono zu
  zweit in einem Block (der Mischer verteilt sie im Stereobild, `layers.<clip>.pan`), beim Gran Turismo stereo mit
  einem fernen Echo. `mix.clip_gain` je Clipgruppe.
- `layers`: Parameter für Mischer und Fahrzeugebenen – `limiter` (`cut_cycles`, `on_cycles`, `pop` = Anteil der
  Zündunterbrechungen mit einem leisen Knall), `crackle`, `shift`, `saturation` (`amount`, `floor`, `bias`, `comp`),
  `turbo` (`whistle_hz`, `spool_s`, `boost_rpm`, `depth`, `tone`, `tone_level`, `hiss`, `hiss_level`), `blowoff`
  (`min_boost`, `level`, `sound`), `driveline` (`wheel_m`, `final_ratio`, `pinion_teeth`, `mesh_teeth`, `sound`,
  `fd_level`, `gm_level`), `tipin`, `thump` (`sound`, `level`). Fehlt eine Ebene, hat das Auto sie nicht.
- `mix`: `gain` (Pegel des Autos, nach der Sättigung), `off_gain`, `in_gain`, `idle_load` (Anteil der Lastebene im
  Leerlauf), `load_curve` (Exponent, mit dem die Motorlast in die Überblendung eingeht: unter 1 klingt Teillast
  „lastiger“ als ihr Pedalweg).

`EngineBank2` lehnt ab (kein Motorklang, das Getriebe läuft weiter): falsches Format, andere Kanalzahl, fehlende
Ebene an einem Punkt, Ausschnitte außerhalb der Daten oder mit falscher Länge, `period` ≠ `120 / rpm · sample_rate`,
`gain` ≤ 0. Es vermerkt nur: andere Abtastrate als 32 kHz, Punkte weiter als Faktor 1,25 auseinander, tiefster Punkt
über dem Leerlauf, unbekannte Clips.

**Fahrzeugklänge** (`assets/audio/modern/vehicle/`, 16-Bit-WAV, 44,1 kHz, Bus `MEngineFx`; im Manifest mit
`generator: tools/audio/modern/engine_synth3.py`): `turbo_single` (ein Lader, mono) und `turbo_twin` (zwei Lader,
links/rechts leicht verstimmt) – je 2 s Schleife, ein Schmalbandton um 3000 Hz mit Phasenrauschen und schwachen
Obertönen, kein Sinus; `turbo_hiss` (Strömungsrauschen 2,6–9,5 kHz); `driveline_whine` (Zahneingriffston um
1000 Hz); `tipin` (2 Varianten), `shift_thump` (2), `blowoff_hatch` (2, mit Verdichterflattern), `blowoff_soft`,
`blowoff_gt`. `gain_db` im Manifest führt einen Pegel 1 der Laufzeit-Gesetze auf die Vollaussteuerung des Motors.
Die vier Schleifen tragen hinter ihrem Schleifenende 16 Frames Fortsetzung (die ersten Frames der Schleife noch
einmal): Godot 4.7.2 spielt an der Naht einer Schleife, die mit ihren Daten endet, einen falschen Abtastwert
(gemessen, [audio-modern.md](audio-modern.md) Abschnitt 11).

Größe (gemessen): Banken 1,84–2,89 MB je Auto, zusammen 10,94 MB (v2: 10,16 MB); zwölf Fahrzeugklänge 1,22 MB.

### 6.2 Synthese (`tools/audio/modern/engine_synth3.py`)

```
python3 tools/audio/modern/engine_synth3.py              # alle fünf Autos und die Fahrzeugklänge ins Repository (≈ 45 s)
python3 tools/audio/modern/engine_synth3.py --out DIR    # dasselbe unter DIR (ohne .import-Dateien)
python3 tools/audio/modern/engine_synth3.py --car kombi --only banks --jobs 1
python3 tools/audio/modern/engine_synth3.py --info       # Drehzahlpunkte und Größen, ohne zu rendern
godot --headless --path . --import                       # danach einmal, wenn WAV-Dateien neu sind
python3 tools/audio/qc/audio_qc.py --determinism         # Prüfung: Manifest, Pegel, zweimal rendern = gleiche Bytes
```

Deterministisch (feste Seeds je Auto, Bank und Kanal). Was das Werkzeug dem Modell von Abschnitt 5 hinzufügt:

- **Ebenen statt zweier Lasten.** Die Bauteile des Modells (`exh`, `rasp`, `jet`, `intake`, `hiss`, `whoosh`, `mech`,
  `inj`, `comb`, `knock`) werden je Betriebspunkt einmal gerechnet und dann getrennt gemischt: `off` = alles bei
  geschlossener Drossel, `on` = Volllast ohne `intake`/`whoosh`/`hiss`, `in` = `intake` + `whoosh` allein. Die
  Laufzeit bewegt `in` mit dem Gaspedal und `on`/`off` mit der Motorlast – beim Schalten unter Vollgas bleibt die
  Ansaugung stehen, während der Auspuff kurz aussetzt.
- **Ansaugebene phasengerecht geschnitten** (`align_induction`): Auspuffbanken beginnen ihren Zyklus mit der Ankunft
  des Stoßes von Zylinder 1; die Ansaugung läuft einen anderen Weg. Zum selben Zeitpunkt geschnitten, lag die
  Kohärenz benachbarter Ansaugbanken zwischen +0,9 und −0,6 – zwei überblendete Punkte löschten sich teilweise aus.
  Jeder Punkt wird jetzt innerhalb seines Zyklus so verschoben, dass sein mittlerer Zyklus zum Punkt darunter passt
  (Sportwagen: 0,87–0,99; wo die Ebene bei hohen Drehzahlen vor allem aus Rauschen besteht, bleibt sie bei ≈ 0,1 –
  Rauschen ist nicht kohärent, und der Mischer rechnet damit).
- **Stereo aus einem Hörpunkt** (mono-verträglich, keine Laufzeitunterschiede): Leistungsgleiches Pan je Schallquelle,
  Strömungsrauschen (Ventil, Mündung, Drossel) je Kanal mit einem unabhängigen Anteil (`noise`). Drei Arten (`pan`):
  `centre` – ein Auspuffbild in der Mitte (Reihenmotoren mit einer Anlage: Kompakt, Kombi, Limousine), die Breite kommt
  aus dem Rauschen; `tailpipe` – jedes Endrohr an seinem Platz (Gran Turismo: zwei getrennte Bänke mit je zwei
  Rohren, die beiden Kanäle hören verschiedene Stoßfolgen), unterhalb von 150 Hz tragen beide Kanäle ihr Mittel
  (`mono_below_hz`); `group` – jede Zylinderbank auf einer Seite (Sportwagen), aber erst oberhalb von 300 Hz
  (`pan_from_hz`). Grund für die beiden Grenzen, gemessen: Die Bänke eines Boxers zünden abwechselnd, ihre halben
  Ordnungen stehen zwischen den Bänken in Gegenphase und tragen im Schub den größten Teil der Leistung – voll
  ausgelenkt hatte der Sportwagen im Schub eine Kanalkorrelation von −0,49 und verlor in Mono 5 dB; beim V8
  klangen im Schub die ungleich langen Anlagen bis zu 6 dB verschieden laut und zogen das Bild zur Seite.
  Die Kanäle jeder Bank werden gegeneinander abgeglichen (Mittel aus K-bewerteter und unbewerteter Leistung).
- **Abstimmung je Auto** (Tabelle `CHAR`, siehe 6.5): Pegel der Nebengeräusche über dem Arcade-Profil (`retune`),
  stärkere Aufsteilung der Stöße (`nl`), **Stimme des Auspuffs** (`voice`: Formanten als Glockenfilter auf allen
  Impulsantworten der Anlage – feste Resonanzen, durch die die Motorordnungen wandern; gegen das Loch zwischen dem
  Grundton und dem Rauschen bei niedriger Drehzahl), Sättigung, Ebenen.
- **Pegelform**: Jede Bank wird auf eine Ziellautheit gebracht (K-bewertet, in dB unter der Volllast des Autos):
  gemeinsame Kurven für `on` und `off` über der Drehzahl, je Auto `idle_db` (Leerlauf) und `low_db` (Lastebene im
  unteren Drehzahldrittel). Die Hälfte der Abweichung jeder Bank von einer glatten Kurve bleibt erhalten (Resonanzen).
  `mix.gain` = Entwurfslautheit des Autos (`INTERNAL_LUFS` + `loudness`), gemessen an den Volllastbanken **mit** der
  Sättigung der Laufzeit. Diese Werte sind mit Aufnahmen aus dem Spiel abgestimmt (6.6).
- **Clips**: die Generatoren von v2 mit denselben Seeds; beim Gran Turismo je Kanal gerechnet (jeder Nachbrenner
  sitzt an seinem Schalldämpfer) und mit zwei tiefpassgefilterten Echos (187 und 311 ms, das zweite
  seitenvertauscht); sonst mono.
- Die Datei ist ein Behälter von Ausschnitten und wird trotzdem wie ein Klang geprüft: Ihr True Peak wird auf
  −1,1 dBTP begrenzt (die `gain`-Werte gleichen es aus).

### 6.3 Laufzeit

```
EngineAudio3 (Baustein „engine“, Bus MEngine)            scripts/audio/modern/engine_audio3.gd
└─ je klingendem Motor eine Unit: EngineBank2 + EngineGearbox (unverändert) + EngineMixThread
VehicleLayers (Baustein „layers“, Bus MEngineFx)         scripts/audio/modern/vehicle_layers.gd
```

**`EngineMixThread`** (`engine_mix_thread.gd`) ist der Mischer von Abschnitt 4 in Stereo und mit drei Ebenen: Eine
Zyklusphase läuft mit der Drehzahl; je Abtastwert werden die beiden benachbarten Drehzahlpunkte × `off`, `on`
(Stereo) und `in` (mono) an der Stelle Phase × Periode gelesen, am Zyklusanfang wechselt jede Bank auf eine andere
Variante und blendet über `overlap − 4` Frames aus der alten über. Dazu:

- **Auspuff und Ansaugung getrennt**: `on`/`off` folgen der Motorlast (Anstieg 22 ms, Abfall 60 ms, vom Begrenzer
  geschnitten), `in` folgt dem Pedal (12 / 45 ms) und beim Turbomotor dem Ladedruck; die Lastebene eines
  Turbomotors wächst mit dem Ladedruck (`layers.turbo.depth`).
- **Leistungstreues Überblenden**: zwischen zwei Drehzahlpunkten mit ihrer gemessenen Kohärenz (`xrpm`), zwischen
  den Lasten mit `xload` und den Leistungen der Banken. Ohne das sinkt der Pegel dort ein, wo zwei Banken sich
  nicht phasengleich addieren (bei Kohärenz 0 um 3 dB), oder er steigt, wo sie es tun.
- **Bewegung** – der Klang steht nie wie eine Schleife: Drehzahl, Pegel der Auspuffebenen und Last schwanken
  zufällig, je als schnelle Unruhe (Zeitkonstanten 0,12–0,25 s) und als langsames Atmen (2,5 s); dazu ein kleiner
  Pegelsprung je Arbeitsspiel. Stärken in `audio.modern.engine.motion`.
- **Sättigung** nach der Mischung: `y = (tanh(x·d + b) − tanh b) / d^comp` mit
  `d = 1 + amount · Last · (floor + (1 − floor) · Drehzahl / Nenndrehzahl)` – das Bellen eines Motors, dem man
  Drehmoment abverlangt; sie füllt bei niedriger Drehzahl die Mitten mit Obertönen des Grundtons.
- **Clips** nach der Sättigung: Schubknallen (zufällig verteilt nach dem Gaswegnehmen oberhalb von `min_rpm`),
  Schaltknall beim Hochschalten unter Last, Startclip (Anlasser, erste Zündungen), ein leiser Knall bei einem Teil
  der Zündunterbrechungen am Begrenzer (`limiter.pop`). Mono-Clips werden zufällig im Bild verteilt.
- **Begrenzer**: Muster aus `cut_cycles` Schub- und `on_cycles` Lastzyklen wie in v2, die Drehzahl sackt dabei um
  3 % ab.
- Ausgang: `mix.gain` × `engine.level_db`, Blenden, weiche Begrenzung (linear bis 0,9).

**Thread.** Der Spielthread schreibt nur einen kleinen Steuerblock unter einem Mutex (`drive()` je Bild,
`fade_to()`, `start()`, `play_clip()`, `lift()`); gemischt wird in einem eigenen Thread, der im Generator
`latency_s` (50 ms) Vorlauf hält – mehr, wenn der Audiotreiber größere Blöcke auf einmal holt: dann einen
Treiberblock plus Reserve (ein Viertel des Blocks, mindestens 40 ms); der größte gesehene Block gilt für den
ganzen Prozess. Ein Wiedergabestart beginnt nie leer: Der erste Vorlauf wird gerendert, bevor der Player startet,
und sofort danach übergeben; in der ersten Sekunde einer Etappe ist der Vorlauf `start_latency_s` lang. Meldet
sich der Spielthread 0,75 s nicht, blendet der Thread den Motor aus, bis wieder Steuerwerte kommen. `reset()` und
`detach()` beenden den Thread (join), bevor der Player freigegeben wird; der Generator-Stream geht vorher an
`ModernAudioContext.keep_alive()`.
**Synchron** (`--audio-sync` oder `audio.modern.engine_thread = false`): derselbe Mischer im Hauptthread, mit
festem Seed – zwei Läufe mit gleicher Steuerung geben dieselben Abtastwerte.

**`EngineAudio3`** führt je klingendem Motor eine `Unit` und um sie herum, was im Bildtakt entschieden wird:
Getriebe (`EngineGearbox`, dieselben Gänge und Drehzahlen wie in Arcade), Ladedruck und Laderdrehzahl, Gas weg
(Knallen, Schubumluft), Hochschalten unter Last (Schaltknall), Motorstart. Die Bank eines Autos wird bei
`set_vehicle()` geladen (22–75 ms) und im Speicher gehalten (höchstens drei); für den Gasstoß in der Fahrzeugwahl
(`preview()`) lädt sie ein Hintergrund-Task. Der Motor startet mit dem ersten Bild einer Etappe, in dem die Sitzung
ihn fährt: im Stand mit dem Startclip (Anlasser, Hochlaufen, Leerlauf – das ist der Klang des Countdowns, Gasstöße
im Stand eingeschlossen), bei einer Etappe, die im Fahren beginnt, ohne. `state()` liefert `{rpm, gear, load,
boost}` und für die Fahrzeugebenen `shaft`, `limiter`, `shifting`, `throttle` sowie Zähler, die nur wachsen
(`upshifts`, `downshifts`, `blowoffs` mit `blowoff_level`, `starts`). `frame.engine.load` steuert das Ducking der
Musik. Ein Auto ohne v3-Bank bleibt still; sein Getriebe läuft weiter.

**Ein langes Bild ist kein Sitzungsende.** `ModernAudio` betrachtet die Sitzung als weg, wenn sie 0,35 s nicht
ruft – ein einzelnes Bild, das so lange dauert, sieht genauso aus. Der Mischer-Thread spielt durch einen solchen
Hänger hindurch; Motor und Fahrzeugebenen blenden dafür nicht aus (`EngineAudio3.driven()`: ein Bild ≥ 0,25 s, das
auf ein gefahrenes folgt und keine Pause ist, zählt noch). Eine Sitzung, die wirklich weg ist, fällt ein Bild
später auf.

**`VehicleLayers`** – Godot mischt, das Skript stellt je Bild nur Pegel und Tonhöhe (keine Skriptzeit je
Abtastwert). Pegel in der Skala des Motors (1 = Vollaussteuerung der Bank vor `mix.gain`), `mix.gain` des Autos
gilt auch für die Ebenen:

| Ebene | Tonhöhe | Pegel |
|---|---|---|
| Laderton (`turbo.tone`) | `whistle_hz` über der Laderdrehzahl (`shaft^0,8`) | `tone_level · shaft^1,6 · (0,35 + 0,65 · Last)` |
| Laderrauschen (`turbo.hiss`) | fest | `hiss_level · Ladedruck^1,5 · (0,4 + 0,6 · shaft)` |
| Achsheulen | Tempo / Radumfang × Achsübersetzung × Ritzelzähne (130 km/h ≈ 676 Hz) | `fd_level · (v / 250)^1,2 · (0,45 + 0,55 · Last)`, blendet bis 25 km/h ein |
| Getriebeheulen | Drehzahl / 60 × `mesh_teeth` | `gm_level · (n / Nenndrehzahl)^1,5 · (0,3 + 0,7 · Last)`, nur mit eingelegtem Gang |
| Gasannahme (`tipin`) | – | einmal, wenn das Pedal binnen 0,25 s von ≤ 0,35 auf ≥ 0,9 geht (in Fahrt, Gang eingelegt) |
| Lastwechselschlag (`thump`) | – | bei jedem Gangwechsel; beim Hochschalten stärker mit dem Pedal |
| Schubumluft (`blowoff`) | – | wenn der Motor-Baustein sie meldet (Gas weg mit Ladedruck ≥ `min_boost`) |

Anlasser, Leerlauf, Begrenzer, Schaltknall und Schubknallen gehören zum Zyklenmischer – sie müssen im Takt seiner
Arbeitsspiele bleiben.

### 6.4 Konfiguration (`config/game_config.json` → `audio.modern`)

| Schlüssel | Wert | Bedeutung |
|---|---|---|
| `engine_thread` | `true` | Mischer im eigenen Thread (`false` oder `--audio-sync`: im Hauptthread) |
| `engine.level_db` | 0,0 | Pegel des Motors zusätzlich zu `mix.gain` (gilt auch für die Fahrzeugebenen) |
| `engine.preview`, `engine.preview_db` | `true`, −2,0 | Gasstoß in der Fahrzeugwahl |
| `engine.latency_s` | 0,05 | Vorlauf des Mischer-Threads im Generator |
| `engine.sync_latency_s`, `engine.start_latency_s`, `engine.buffer_s` | 0,07 · 0,2 · 0,3 | Vorlauf im Hauptthread-Betrieb, in der ersten Sekunde einer Etappe, Puffergröße |
| `engine.motion` | `rpm` 0,0012 · `level_db` 0,6 · `load` 0,05 · `cycle_db` 0,5 · `rpm_slow` 0,003 · `level_slow_db` 0,5 · `load_slow` 0,07 | Bewegung als Standardabweichungen (schnell / langsam / je Arbeitsspiel); 0 schaltet einen Anteil ab |
| `layers.enabled`, `layers.level_db`, `layers.turbo_db`, `layers.driveline_db`, `layers.shots_db` | `true`, 0 … | Fahrzeugebenen an/aus und ihre Pegel |
| `levels.MSfx` | 0,0 | war −3 dB, solange der Platzhalter die lautere Arcade-Bank spielte (6.6) |

### 6.5 Die fünf Motoren im Profil Modern

| | Kompakt | Kombi | Limousine | Sportwagen | Gran Turismo |
|---|---|---|---|---|---|
| Stereobild | Mitte, Rauschen breit | Mitte | Mitte, Rauschen breit | Zylinderbänke links/rechts ab 300 Hz – die breitesten Mitten | Endrohre links/rechts, darunter Mitte ab 150 Hz |
| Stimme (Formant) | 520 Hz, +5 dB | – (das Nageln ist seine Stimme) | 420 Hz, +4 dB, breit | – (freie Anlage, schon reich an Mitten) | 330 Hz, +5 dB |
| Nebengeräusche über Arcade | Ventil +4, Mündung +5, Ansaugung +4, Verdichter +5 dB | +2 / +3 / +3 / +6, Nageln +1 dB | +2,5 / +4 / +3 / +3 dB | Ventil −1, Mündung 0, **Ansaugung +6 dB** | +3 / +4 / +5 / +5 dB |
| Sättigung (`amount`) | 1,0 | 0,5 | 0,6 | 1,35 | 1,25 |
| Lader | ein Lader, lauter Ton (0,060), Rauschen | ein Lader (0,050), viel Rauschen | ein Lader, dezent (0,022) | – | zwei Lader links/rechts (0,036) |
| Gas weg | leichtes Knallen, Schubumluft mit Flattern | – | weiches Knallen, dezente Schubumluft | scharfes Knallen | Schläge mit fernem Echo, Schubumluft |
| Schalten unter Last | DSG-Knall | Lastwechselschlag | Lastwechselschlag | scharfer Knall | Schlag |
| Antriebsheulen (Achse / Getriebe) | 0,011 / 0,008 | 0,012 / 0,006 | 0,008 / 0,005 | 0,012 / 0,012 | 0,012 / 0,008 |

### 6.6 Pegel (Pegelplan, Vertrag D29)

Jede Bank bringt ihren Pegel mit (`mix.gain`); `audio.modern.levels.MSfx` steht deshalb auf 0 dB (es stand auf
−3 dB, solange der Platzhalter die 3 dB lautere Arcade-Bank spielte). Abgestimmt und gemessen mit
`tools/audio/modern/capture_mix.gd` (feste Fahrt in Echtzeit: Leerlauf, Vollgas durch die Gänge, Höchsttempo, vom
Gas, 130 km/h; aufgenommen wird der Master-Bus bei Standardreglern – Motor, Fahrzeugebenen und der Wind des
Platzhalter-Bausteins `road`, ohne Musik und Verkehr) und `measure_mix.py` (BS.1770). Lautheit je Abschnitt in
LUFS, gemessen mit den ausgelieferten Dateien:

| Auto | Leerlauf | Vollgas durch die Gänge (Kurzzeit höchstens / Median) | Höchsttempo | vom Gas | 130 km/h | True Peak |
|---|---|---|---|---|---|---|
| Kompakt | −23,9 | −16,0 (−14,8 / −16,0) | −16,6 | −21,9 | −21,9 | −6,1 dBTP |
| Kombi | −25,1 | −16,1 (−15,1 / −16,0) | −15,8 | −21,9 | −21,5 | −6,0 |
| Limousine | −24,2 | −17,1 (−16,2 / −17,2) | −15,0 | −20,4 | −21,6 | −6,5 |
| Sportwagen | −24,2 | −16,3 (−15,1 / −16,6) | −16,2 | −20,1 | −20,9 | −5,9 |
| Gran Turismo | −23,5 | −16,2 (−15,5 / −16,2) | −15,3 | −20,6 | −22,3 | −6,1 |
| **Plan** | ≈ −24 | −16 ± 1,5 | −16 | – | ≈ −21 | ≤ −1 |

Dieselbe Fahrt mit dem Profil Arcade (gemessen): Leerlauf −17,2 (Gran Turismo) bis −28,4 (Kombi), Vollgas −13,2
bis −19,7, 130 km/h −19,9 bis −29,0 – die Autos liegen dort bis zu 11 dB auseinander, in Modern höchstens 1,6 dB.

| Auto (Arcade) | Leerlauf | Vollgas durch die Gänge | Höchsttempo | 130 km/h |
|---|---|---|---|---|
| Kompakt | −23,5 | −18,0 | −17,3 | −23,0 |
| Kombi | −28,4 | −19,7 | −19,0 | −24,6 |
| Limousine | −23,1 | −18,6 | −16,0 | −29,0 |
| Sportwagen | −24,2 | −15,6 | −14,1 | −24,7 |
| Gran Turismo | −17,2 | −13,2 | −13,5 | −19,9 |

Zur Einordnung:

- Von Lauf zu Lauf schwanken die Abschnittswerte um etwa ± 0,3 dB, das Kurzzeit-Maximum um bis zu ± 0,4 dB (die
  langsame Bewegung des Klangs ist im Thread-Betrieb nicht reproduzierbar), der Leerlauf des Kombi um ± 0,3 dB und
  das Reisetempo des Gran Turismo zwischen −21,5 und −22,3 (drei Läufe). Kombi und Sportwagen sind deshalb zuletzt
  um 0,4 und 0,3 dB zurückgenommen worden: Ihr Kurzzeit-Maximum lag in einem von drei Läufen bei −14,2 und −14,5.
- Im Fenster −16 ± 1,5 liegen bei allen fünf der Abschnittswert, der Median und das Maximum der Kurzzeit-Lautheit.
  Einzelne 3-s-Fenster liegen beim Hochdrehen darunter: Die Limousine läuft von −18,2 in den unteren Gängen bis
  −14,8 bei Höchsttempo (dort trägt der Wind bei 250 km/h mit) – sie liegt beim Hochdrehen 1,1 dB unter dem Ziel,
  das leise Auto der fünf.
- Leerlauf und Reisetempo sind **mit dem Platzhalter-Wind** abgestimmt. Wenn Fahrbahn und Wind von AU-C1 kommen,
  ändert sich die Summe; die Stellgrößen des Motors sind `engine.level_db` (alle Autos) und im Werkzeug `loudness`,
  `idle_db`, `low_db` je Auto.
- Pegel addieren sich in dieser Kette nicht genau: Bei Vollgas arbeitet der Summenkompressor (Schwelle −9 dB), und
  der Wind trägt je nach Tempo bei. Mehrere Aufnahmerunden waren nötig; wer die Banken ändert, misst neu.

### 6.7 Prüfungen

`tests/unit/audio_modern/` (mit `tools/run_tests.sh audio_modern`):

| Datei | prüft |
|---|---|
| `test_engine3_bank.gd` | `EngineBank2`: Kunstbank wird richtig aufgelöst; 22 kaputte Beschreibungen werden abgelehnt; Abweichungen werden vermerkt; die fünf ausgelieferten Banken und die Fahrzeugklänge (Manifest, Schleifenpunkte, Fortsetzung hinter dem Schleifenende, Import-Einstellungen) |
| `test_engine3_mix.gd` | `EngineMixThread` ohne Thread: endlich und begrenzt, Varianten wechseln, Zykluslänge, **keine Knackser an den Zyklusgrenzen auf beiden Kanälen**, Drehzahlfahrt stetig, Leistung beim Überblenden zwischen Drehzahlen und Lasten, Ansaugung folgt dem Pedal, Begrenzermuster, Clips und ihr Platz im Bild, gleicher Seed = gleiche Abtastwerte, Bewegung, **ausgelieferte Banken: Kanalabgleich ≤ 0,5 dB und Monosumme ≥ −3 dB über eine Drehzahlfahrt**, Größe, Rechenzeit je Bild |
| `test_engine3_slot.gd` | `EngineAudio3` und `VehicleLayers` ohne Szenenbaum: der Baustein fährt die v3-Bank, Startclip nur aus dem Stand, **synchroner Betrieb zweimal abtastgleich**, Gasstoß in der Fahrzeugwahl, ein langes Bild ist kein Sitzungsende, die Ebenen folgen dem Motor |
| `test_engine3_checks.gd` | startet `check_engine3.gd` als eigene Prozesse (ganzer Lauf, zweimal Beenden bei laufendem Thread) |
| `test_engine3_fixture.gd` | keine Tests: die Kunstbank (16 kHz, vier Drehzahlpunkte, bekannte Signale) für die anderen |

`check_engine3.gd` prüft im laufenden Spiel mit Wiedergabe (Dummy-Treiber):

```
godot --headless --path . -s res://tests/unit/audio_modern/check_engine3.gd -- --graphics=arcade [--only=thread,sync,switch,quit] [--trace]
```

| Szenario | prüft | gemessen |
|---|---|---|
| `thread` | Gran Turismo 7,5 s Vollgas, dabei **sechs Hänger des Hauptthreads von 400 ms**: Thread läuft, kein Leerlauf des Generators, der Player spielt, kein stilles Bild | 0 Aussetzer |
| `sync` | dasselbe mit `engine_thread = false`: Der Generator **muss** leerlaufen – sonst misst die Prüfung nichts | 348–427 Aussetzer |
| `switch` | 10 × Arcade ↔ Modern bei laufendem Thread und Vorschau: keine hängenden Threads, Knoten, Streams | sauber |
| `quit` | das Spiel endet bei laufendem Thread | Rückgabewert 0 |

Weitere Messungen (Entwicklungsmaschine, ohne Bildschirm):

- **20 Prozessenden bei laufendem Mischer-Thread**: 20 von 20 mit Rückgabewert 0 in 1,5–1,7 s, keine Meldung außer
  den beiden Hinweisen, die Godot immer ausgibt, wenn ein Prozess endet, während ein Klang spielt (auch ein
  einfacher `AudioStreamPlayer` ohne jeden Modern-Code – nachgestellt).
- **Synchroner Betrieb**: zwei Läufe abtastgleich in den Unit-Tests (Mischer und Baustein) und im Movie-Maker-Modus
  mit `--audio-sync` (Tonspur 480 000 Frames bei 48 kHz, zwei Läufe mit gleichem SHA-256). Der Thread-Betrieb ist
  nicht reproduzierbar – das ist so gewollt (D27).
- **Rechenzeit**: 0,73–0,99 ms Mischzeit je 1/60 s Klang im Spiel (im Thread, also nicht in der Bildzeit), 0,77–0,82 ms
  im Unit-Test (Gran Turismo, sechs Stimmen); der Arcade-Mischer braucht mono 0,32 ms im Hauptthread. Im Hauptthread
  bleiben je Bild das Getriebe und ein Steuerblock (unter 0,02 ms, abgeleitet aus der Zahl der Operationen). Laden
  einer Bank 22–75 ms.
- **Stereo**: Kanalabgleich über eine Drehzahlfahrt ≤ 0,42 dB (ungewichteter Effektivwert, schlechtester Fall Gran
  Turismo im Schub), Monosumme höchstens 0,51 dB unter dem lauteren Kanal.
- `python3 tools/audio/qc/audio_qc.py --determinism`: alle Dateien bestehen, zweimal rendern ergibt dieselben Bytes.

### 6.8 Arcade und Modern in Zahlen

Gemessen an Renderings der beiden Mischer (derselbe Fahrzustand, je 5 s bei fester Drehzahl und Last; der Motor
allein, ohne Fahrzeugebenen, Busse und Hall). **HNR** = Verhältnis der Leistung auf den Motorordnungen zur Leistung
dazwischen (für Modern ohne die Bewegung des Mischers gemessen – die wandernde Drehzahl verschmiert sonst die
Obertöne aus den schmalen Messbändern); **Pegelbewegung** = Standardabweichung des 50-ms-Pegels.

Volllast (Arcade → Modern):

| Auto | Drehzahl | Spektraler Schwerpunkt Hz | HNR dB | Pegelbewegung dB | Anteil ab 1 kHz dB | Kanalkorrelation Modern (ganz / ab 1 kHz) |
|---|---|---|---|---|---|---|
| Kompakt | 2050 | 84 → 84 | 28,1 → 27,5 | 0,30 → 0,63 | −31,3 → −29,7 | 1,00 / 0,63 |
|  | 3750 | 153 → 170 | 18,3 → 17,2 | 0,14 → 0,44 | −20,1 → −17,0 | 0,99 / 0,68 |
|  | 5800 | 267 → 350 | 14,6 → 11,7 | 0,11 → 0,47 | −13,9 → −10,8 | 0,97 / 0,71 |
|  | 6450 | 399 → 501 | 10,7 → 9,1 | 0,21 → 0,44 | −10,2 → −8,4 | 0,94 / 0,71 |
| Kombi | 1400 | 298 → 331 | 10,1 → 10,4 | 0,49 → 1,07 | −9,2 → −8,7 | 1,00 / 1,00 |
|  | 2550 | 238 → 244 | 17,8 → 16,3 | 0,24 → 0,68 | −12,0 → −11,8 | 1,00 / 0,99 |
|  | 3900 | 523 → 576 | 12,6 → 9,4 | 0,22 → 0,63 | −8,6 → −7,9 | 0,99 / 0,97 |
|  | 4350 | 487 → 569 | 13,4 → 9,9 | 0,17 → 0,64 | −9,1 → −8,0 | 0,99 / 0,97 |
| Limousine | 2100 | 113 → 119 | 27,0 → 24,3 | 0,17 → 0,73 | −30,7 → −27,7 | 1,00 / 0,60 |
|  | 3850 | 199 → 205 | 22,0 → 19,6 | 0,07 → 0,66 | −24,6 → −21,9 | 1,00 / 0,62 |
|  | 5950 | 421 → 470 | 11,0 → 10,0 | 0,12 → 0,67 | −11,9 → −11,1 | 0,95 / 0,60 |
|  | 6650 | 511 → 564 | 9,8 → 8,3 | 0,13 → 0,56 | −10,6 → −9,9 | 0,94 / 0,61 |
| Sportwagen | 2700 | 182 → 194 | 19,6 → 20,6 | 0,09 → 0,65 | −20,0 → −19,8 | 0,97 / 0,50 |
|  | 4950 | 315 → 393 | 16,7 → 17,3 | 0,08 → 0,64 | −14,0 → −10,7 | 0,93 / 0,58 |
|  | 7650 | 1185 → 1429 | 6,4 → 5,0 | 0,16 → 0,42 | −2,1 → −1,1 | 0,64 / 0,70 |
|  | 8550 | 978 → 1478 | 8,9 → 5,5 | 0,11 → 0,46 | −3,4 → −1,0 | 0,61 / 0,59 |
| Gran Turismo | 2100 | 144 → 154 | 25,9 → 22,7 | 0,08 → 0,68 | −28,1 → −24,5 | 0,99 / 0,46 |
|  | 3850 | 348 → 422 | 13,7 → 11,2 | 0,18 → 0,65 | −12,2 → −9,2 | 0,90 / 0,60 |
|  | 5950 | 675 → 792 | 12,8 → 9,7 | 0,14 → 0,58 | −4,1 → −4,1 | 0,75 / 0,72 |
|  | 6650 | 776 → 869 | 11,6 → 8,3 | 0,13 → 0,51 | −3,1 → −3,5 | 0,75 / 0,63 |

Lesart: Der Schwerpunkt steigt in beiden Profilen mit der Drehzahl, in Modern um 5–50 % höher (mehr Obertöne und
Strömungsrauschen unter Last); die HNR liegt 1–4 dB tiefer (mehr Rauschen zwischen den Ordnungen); der Pegel bewegt
sich drei- bis achtmal so stark. Bei Teillast (22 %) ist der Unterschied am größten, weil `load_curve` die
Lastebene früher einblendet – Kombi bei 2550/min: Schwerpunkt 138 → 281 Hz, HNR 22,5 → 16,9 dB; Kompakt bei
3750/min: 146 → 192 Hz, 22,3 → 15,6 dB. Im Schub sind beide Profile fast gleich (Schwerpunkt ± 10 %, HNR ± 3 dB).

Eine Minute konstantes Tempo (Arcade → Modern; **Wiederholung** = höchste Autokorrelation der Pegelkurve bei
Verschiebungen von 0,2 bis 10 s – eine Schleife zeigte sich als Wert nahe 1):

| Auto | Tempo | Pegel 50 ms (Std, dB) | Pegel 1 s (Std, dB) | Spektrum (Std je Terz, dB) | Wiederholung | lauteste Terz über dem Median, A-bewertet (dB) |
|---|---|---|---|---|---|---|
| Kompakt | 130 km/h | 0,16 → 0,92 | 0,01 → 0,65 | 0,23 → 1,44 | 0,86 → 0,12 | 12,8 → 11,5 |
|  | 196 km/h | 0,11 → 0,83 | 0,02 → 0,58 | 0,68 → 1,12 | 0,38 → 0,11 | 12,5 → 9,4 |
| Kombi | 130 km/h | 0,07 → 0,83 | 0,02 → 0,50 | 0,36 → 1,17 | 0,25 → 0,06 | 16,1 → 14,9 |
|  | 200 km/h | 0,14 → 0,84 | 0,02 → 0,53 | 0,54 → 1,16 | 0,53 → 0,09 | 9,0 → 7,7 |
| Limousine | 130 km/h | 0,18 → 0,79 | 0,03 → 0,46 | 1,19 → 0,83 | 0,32 → 0,07 | 17,7 → 18,5 |
|  | 200 km/h | 0,10 → 0,83 | 0,02 → 0,59 | 0,49 → 1,16 | 0,41 → 0,19 | 23,1 → 21,2 |
| Sportwagen | 130 km/h | 0,09 → 0,88 | 0,02 → 0,62 | 0,44 → 1,11 | 0,17 → 0,16 | 11,9 → 10,1 |
|  | 200 km/h | 0,11 → 0,83 | 0,02 → 0,60 | 0,48 → 0,95 | 0,18 → 0,08 | 17,4 → 15,3 |
| Gran Turismo | 130 km/h | 0,11 → 0,86 | 0,01 → 0,56 | 0,55 → 1,09 | 0,57 → 0,15 | 15,8 → 13,0 |
|  | 200 km/h | 0,24 → 0,81 | 0,04 → 0,56 | 0,78 → 1,09 | 0,53 → 0,07 | 13,4 → 13,3 |

Der Arcade-Klang steht bei konstantem Tempo (1-s-Pegel ± 0,01–0,04 dB) und wiederholt sich messbar (Kompakt bei
130 km/h: 0,86); Modern bewegt sich um ± 0,5–0,65 dB und wiederholt sich nicht (≤ 0,19). Die tonale Dominanz der
lautesten Terz sinkt um 0–3 dB – die Bewegung macht den Ton lebendiger, nicht breiter.

Dieselbe Fahrt im Spiel, nur der Motor mit seinen Ebenen über die Busse des jeweiligen Profils (Arcade | Modern):

| Auto | ganze Fahrt LUFS | Lautheitsbereich LU | Vollgas durch die Gänge | 200 km/h | Gas weg | 130 km/h | Leerlauf |
|---|---|---|---|---|---|---|---|
| Kompakt | −20,6 \| −19,7 | 5,4 \| 8,5 | −18,6 \| −16,6 | −22,1 \| −20,8 | −21,0 \| −24,5 | −23,0 \| −22,1 | −24,1 \| −24,2 |
| Kombi | −23,2 \| −19,4 | 5,3 \| 9,2 | −21,2 \| −16,9 | −24,8 \| −21,3 | −26,0 \| −25,6 | −25,3 \| −21,9 | −28,7 \| −25,0 |
| Limousine | −21,4 \| −19,8 | 9,2 \| 6,1 | −19,6 \| −17,4 | −24,3 \| −20,6 | −28,0 \| −25,4 | −25,9 \| −21,0 | −23,2 \| −24,3 |
| Sportwagen | −18,3 \| −19,2 | 10,3 \| 6,2 | −16,0 \| −16,9 | −16,3 \| −17,3 | −27,4 \| −24,1 | −21,9 \| −20,7 | −24,1 \| −24,0 |
| Gran Turismo | −16,2 \| −20,1 | 7,2 \| 8,1 | −13,4 \| −17,1 | −17,2 \| −20,4 | −22,4 \| −27,5 | −19,0 \| −21,7 | −17,8 \| −25,0 |

Über die ganze Fahrt liegen die fünf Autos in Arcade 7,0 dB auseinander, in Modern 0,9 dB. Der Lautheitsbereich
wächst bei Kompakt und Kombi um 3–4 LU (Volllast hebt sich jetzt vom Rollen ab) und sinkt bei Limousine und
Sportwagen um 3–4 LU (ihr Reisetempo war in Arcade 4–5 dB leiser). Im Spiel ist der Arcade-Motor der drei
Turbo-Reihenmotoren bei Vollgas **heller** als der von Modern (Schwerpunkt Kompakt 904 gegen 457 Hz, Anteil ab
5 kHz −9,4 gegen −17,1 dB): Das ist das Turbopfeifen von Arcade, ein Sinus bei 5–6 kHz, der dort ein Zehntel der
Leistung trägt. In Modern liegt der Anteil ab 5 kHz 8 dB tiefer, der Laderton ist dort ein Schmalbandton mit
Rauschen statt eines Sinus; die Bank selbst ist heller als die von Arcade (Tabelle oben).

### 6.9 Grenzen – was die Messungen nicht sagen

- **Niemand hat den Motor gehört.** Gemessen sind Pegel, Spektren, Bewegung, Stetigkeit, Stereo und Rechenzeit. Ob
  das nach einem Motor unter Last klingt, ob die fünf Charaktere gefallen und ob etwas auf Dauer nervt, entscheidet
  erst das Ohr. Die A/B-Dateien je Auto sind dafür gemacht.
- **Dasselbe physikalische Modell wie Arcade.** Ordnungen, Resonanzen und Clips kommen aus demselben Werkzeug; im
  Spektrogramm sehen beide Profile verwandt aus. v3 fügt Stereo, Lastverhalten, Bewegung, Sättigung und Ebenen hinzu –
  keinen neuen Motor.
- **Der Motor ist trocken, und bei drei Autos sitzt er in der Mitte.** Kompakt, Kombi und Limousine haben ein
  Auspuffbild in der Mitte (eine Anlage – so klingt eine Punktquelle hinter dem Auto); ihre Breite steckt im
  Strömungsrauschen oberhalb von 1 kHz (Korrelation dort 0,6–0,7, beim Kombi fast 1 – sein Nageln sitzt in der
  Mitte). Über das ganze Band sind ihre Kanäle im Spiel zu 0,97–1,00 korreliert. Der Arcade-Motor ist mono, aber
  sein Bus hat einen kurzen Hall, der die Kanäle entkoppelt (im Spiel 0,80–0,99): **Gemessen an der Korrelation
  ist der Arcade-Motor im Spiel bei diesen drei Autos breiter als der von Modern**; bei Vollgas gleichauf sind
  Sportwagen (0,72 gegen 0,75) und Gran Turismo (0,78 gegen 0,77), deren Kanäle in Modern wirklich Verschiedenes
  spielen. Das ist Absicht des Aufbaus – in Modern kommen Raum und Breite vom Baustein `env` (AU-C2) und von
  Fahrbahn und Wind (AU-C1), der Motor steht davor in der Mitte –, aber es ist das Erste, was man mit Kopfhörern
  prüfen sollte. Zwei Stellen, falls es zu schmal ist: ein kurzer Raum auf `MEngine` wie in Arcade (ändert die
  Pegel um einige Zehntel dB, neu messen) oder im Werkzeug zwei Endrohre mit leicht verschiedenen Längen für die
  Reihenmotoren (`pan: tailpipe`, neue Banken).
- **Niedrige Drehzahl unter Volllast bleibt basslastig**: Bis etwa 30 % der Nenndrehzahl liegen die Oktaven um 500 Hz
  bis 2 kHz 20–35 dB unter dem Grundton; ein Hochpass bei 180 Hz (kleine Lautsprecher) nimmt dem Kompakten dort
  13–14 dB, der Limousine bei 1400/min 14 dB und dem Gran Turismo bei 1400/min 14,5 dB (Arcade: 8 dB – seine
  Oktave um 250 Hz liegt dort 8 dB höher). Wie das auf dem Steam Deck klingt, ist abgeleitet, nicht gehört.
- **Die Limousine bei 200 km/h bleibt ein Ton**: Die lauteste Terz (157 Hz) steht A-bewertet 21 dB über dem Median
  der anderen (Arcade 23 dB). Die Bewegung lockert ihn, ein Brummen kann es trotzdem sein.
- **Der Sportwagen ist oben rauschiger als in Arcade** (HNR 5,0–5,5 dB gegen 6,4–8,9 dB bei 7650–8550/min, schon nach
  einer Rücknahme des Strömungsrauschens). Schreien oder Zischen – das zeigen die Zahlen nicht.
- **Leerlauf**: Das Ticken von Einspritzung und Ventiltrieb (beim Kombi das Nageln) ist das des Modells wie in
  Arcade, mit ähnlichen Spitzen oberhalb von 5 kHz (Limousine und Gran Turismo 2–3 dB niedriger, Kombi 6 dB höher).
  In Modern steht es trockener da: Zwischen den Ticks ist es dort 4–17 dB leiser, weil kein Hall sie auffüllt.
- **Fahrzeugebenen sind nach Gesetz und Bild gesetzt, nicht nach Gehör**: Laderton, Rauschen, Antriebsheulen und
  Schläge haben je einen dB-Regler in `audio.modern.layers`. Der Laderton des Kompakten ist im Spektrogramm als
  Linie bei 5–6 kHz zu sehen (so gewollt), das Achsheulen im Schub als dünne Linie um 1 kHz.
- **Thread-Messungen stammen vom Dummy-Treiber** dieser Maschine (Blöcke von 93 ms). Echte Treiber holen kleinere
  Blöcke; dass der Vorlauf dort bei 50 ms bleibt und auch auf dem Steam Deck kein Aussetzer entsteht, ist
  abgeleitet.
- **Pegelplan mit Platzhaltern**: Leerlauf und Reisetempo sind gegen den Wind des Platzhalters abgestimmt (6.6).
