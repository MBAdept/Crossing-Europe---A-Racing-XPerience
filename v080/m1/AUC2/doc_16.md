## 16. Welt, Ambiente, Verkehr (Paket AU-C2)

Vertrag D25–D29, §4.7, §4.11, Welle 6 (AU-C2), A-35. Alle Zahlen gemessen (Godot 4.7.2, ohne Bildschirm,
Dummy-Audiotreiber, aufgenommen am Master bei Standardreglern), sofern nicht „abgeleitet“ dasteht. **Gehört hat es hier
niemand** – das Urteil über den Klang liegt beim Nutzer (Hörproben unter `<scratch>/v080/deliver/AUC2/`).

### 16.1 Was zu hören ist

| Ebene | wann | Klang | Bus |
|---|---|---|---|
| Raumklang | immer, je Zone | frühe Reflexionen (zwei Taps, links/rechts verschieden spät) und Hall je Zone: offen, Wald, Tal (mit Echo von den Hängen), Einschnitt, Stadt, Brücke, Tunnel, Dach (Tankstelle, Grenze); Schnee dämpft | Effekte auf `MEnv` |
| Breite des Autos | immer | ein kurzer, diffuser Raum auf dem Auto, erst oberhalb von etwa 600 Hz – die tiefen Motortöne bleiben in der Mitte | Effekt auf `MCar` |
| Betten | nach Ort, Zeit, Wetter | Wind in Gras und Hecken, Blätterrauschen im Wald, Grillen in Sommernächten, Zikaden am Mittelmeer, Stadt bei Tag und Nacht, Wasser (Brücke über Wasser, Küste, Hafenstadt), Lüfter im Tunnel, Brummen unter dem Tankstellen- und Grenzdach, Regen | `MAmb` |
| Rufe | zufällig, nach Ort und Zeit | Amsel, Buchfink, Kohlmeise (Morgenchor), Krähe, Lerche, Buntspecht, Waldkauz, Hund in der Ferne, Spatzen und Tauben in der Stadt, eine Hupe einige Straßen weiter, Kirchenglocke in Altstädten, Motorroller, Möwen und Schiffshorn am Wasser – Variante, Seite, Entfernung und Tonhöhe je Ruf gewürfelt | `MAmb` |
| Verkehr | jedes Fahrzeug in der Nähe | Motor, Reifen, Fahrtwind (das Arcade-Modell `TrafficAudio`: Stimmen, Entfernung, Panorama, Doppler, Luftdämpfung) mit eigenen Modern-Klängen: je Pkw einer von fünf Motoren (Benziner und Diesel in zwei Gängen, Elektroauto), Sportwagen, Transporter, Lkw, Bus; bei Nässe sprühende Reifen | `MTrafficV0`–`7` |
| Luftstoß | ein fahrendes Fahrzeug zieht dicht vorbei | Pkw: kurzes Wusch; Lkw und Bus: Bugwelle und Verwirbelung | `MWorld` |
| Hupe | selten, zufällig | nach einem Zusammenstoß hupt der andere (Lkw mit Drucklufthorn, Kleinwagen hell); wer sehr knapp und viel schneller vorbeizieht, wird manchmal angehupt; die Polizei hupt nie | `MWorld` |
| Martinshorn | bei einer Verfolgung | Tonfolge wie in Arcade (a¹/d², je 0,62 s), neue Klangfarbe einer elektronischen Anlage mit Trichterlautsprecher; räumlich an der Polizei mit Doppler und Luftdämpfung | `MSiren` |

Kein Donner: Das Spiel kennt keine Blitze, und der Klang darf nichts aus dem Bild lesen (Regel 4). Eine
Martinshorn-Art für ganz Europa (Vertrag §1: keine Recherche der Landesmuster in v0.8.0).

### 16.2 Die Klänge

`assets/audio/modern/ambience/` (`ambience_synth.py`, Ogg Vorbis, 44,1 kHz; zusammen 1,85 MB):

- **zehn Betten**, Stereo-Schleifen von 6–11 s, q3 (die erste Qualität ab q3, deren Naht höchstens doppelt so rau
  ist wie ihr Umfeld): `breeze`, `leaves`, `crickets`, `cicadas`, `city_day`, `city_night`, `water`, `tunnel_fans`
  (der Hall der Röhre eingebacken: 2,6 s unter 1 kHz, 1,3 s darüber), `hum`, `rain`. Nur dichte Texturen ohne
  auffällige Einzelereignisse – ein einzelner Vogel in einer Schleife von 10 s wäre alle 10 s wieder da.
  Nahtlos durch die Bauart: periodisches Rauschen, kreisförmig gesetzte Ereignisse, periodische Modulation, ganze
  Schwingungen, Hall als kreisförmige Faltung.
- **15 Ruf-Arten mit 28 Varianten**, Mono-Einmalklänge q3, je mit seinem Raum (Freiland, Wald, Straße, Ferne) und
  der Luftdämpfung seiner Entfernung: Vogelgesang als Tonfolgen mit gleitender Tonhöhe und Obertönen, raue Rufe
  (Krähe, Möwe, Hund) als Pulsfolge durch Formanten, Specht als Holzschläge, Glocke als Teiltöne einer Moll-Terz-Glocke.
  Einträge tragen `category` (die Klasse des Planers) und `lufs_m` (Momentanlautheit je Variante).

`assets/audio/modern/traffic/` (`traffic_modern.py`; zusammen 1,34 MB):

- **15 Schleifen**, Ogg Vorbis ab q5 (Nahtprüfung wie `vehicle_loops.py`): die Motoren, Reifen und der Fahrtwind
  des Arcade-Modells (`traffic_synth.py` mit `engine_synth.py`, importiert, unverändert) – gerechnet mit 32 kHz,
  periodisch auf 44,1 kHz gebracht (das Spektrum der ganzen Schleife mit Nullen aufgefüllt: die Schleife bleibt
  nahtlos, Tonhöhenfehler unter 1e-5). Neu: `car_petrol_b` (130 km/h, 2950/min), `car_diesel_b` (150 km/h,
  2450/min), `car_ev` (Getriebeheulen 1,27 / 4,0 kHz, elektromagnetische Ordnungen), `tires_car_wet` und
  `tires_truck_wet` (Rollen + Sprühzischen der eigenen Nässe-Schleife von AU-C1, +4 / +6 dB, beim Lkw tiefer).
  Einträge tragen `layer`, `ref_kmh`, `pitch_exp`, `level_db_per_decade` und `lufs_pitch`.
- **`siren`**, 16-Bit-WAV mit 16 Fortsetzungsframes (Falle 13): zwei Zyklen a¹/d², Glissando 25 ms, Rechteck mit
  etwas Asymmetrie durch den Frequenzgang eines Trichterlautsprechers (Abschneidefrequenz 350 Hz, Resonanzen 1,15 /
  2,35 / 3,6 kHz) und eine leichte Verzerrung des Treibers.
- **Einmalklänge**, 16-Bit-WAV: `horn_car` (Zweiklang 412/508 Hz: lang; zweimal kurz), `horn_small` (470 Hz),
  `horn_truck` (Drucklufthorn, zwei Fanfaren 233/293 Hz), `whoosh_car` (2), `whoosh_truck` (2).

Budget (Vertrag §4.11): alle Modern-Klänge außer Musik **22,23 MB von 23 MB** (vorher 19,00). Abweichung von §4.7.3:
die Schleifen des Verkehrs als Ogg Vorbis (A-35) – als WAV hätten allein die neun Motoren 2,4 MB gebraucht.
Beide Generatoren sind deterministisch (zweimal erzeugt: bytegleich, gleich dem Repository).

### 16.3 Raumklang (`EnvAcoustics`)

Voreinstellungen je Zone (`audio.modern.env.presets` ersetzt einzelne Werte), Pegel der Taps nach dem Ausgleich des
Panoramas:

| Zone | Taps (ms) | Tap-Pegel | Echo | Hall: Raum / Dämpfung / Anteil |
|---|---|---|---|---|
| offen | 17 / 23 | −19 dB | – | 0,30 / 0,60 / 0,02 |
| Wald | 13 / 21 | −15 dB | – | 0,45 / 0,75 / 0,06 |
| Tal | 19 / 29 | −18 dB | 380 ms, −21 dB, Tiefpass 1,8 kHz | 0,60 / 0,65 / 0,04 |
| Einschnitt | 27 / 41 | −10 dB | – | 0,40 / 0,45 / 0,06 |
| Stadt | 47 / 71 | −12 dB | – | 0,55 / 0,50 / 0,09 |
| Brücke | 17 / 23 | −23 dB | – | 0,25 / 0,65 / 0,015 |
| Tunnel | 11 / 16 | −7 dB | – | 0,86 / 0,40 / 0,30 |
| Dach | 9 / 13 | −9 dB | – | 0,40 / 0,50 / 0,11 |

Die Zone kommt aus dem Feed; der Tunnel aus der Kamera (`frame.tunnel`, wie in Arcade) – fährt das Auto schon in die
Röhre, die Kamera aber noch nicht, gilt die Zone davor. Die Werte gleiten zu ihrer Voreinstellung (0,7 s; in den und
aus dem Tunnel 0,35 s). Schnee: Taps −4 dB, Hall × 0,6, Dämpfung +0,2.

Godot setzt Tap-Zeiten, die Rückkopplungszeit und das Predelay des Halls ohne Rampe (der Lesezeiger springt – im
Quelltext nachgelesen, Abschnitt 16.8). Die Taps wechseln ihre Zeiten deshalb nur stumm: 80 ms ausblenden, umstellen,
160 ms einblenden (geprüft: beim Umstellen höchstens −60 dB); das Predelay steht für alle Zonen fest (18 ms).

**Breite des Autos** ([motorsound.md](motorsound.md) 6.9): ein kurzer Raum auf `MCar` (Raum 0,1, Dämpfung 0,7,
Eingang ab etwa 600 Hz, Anteil 0,3, `env.car_width`). Gemessen mit `capture_mix.gd` (Fahrt ohne Feed, Zone offen):

| | Limousine | Gran Turismo | Kompakt |
|---|---|---|---|
| Kanalkorrelation Vollgas ohne / mit | 0,87 / 0,81 | 0,70 / 0,62 | 0,91 / 0,85 |
| … 130 km/h | 0,95 / 0,92 | 0,89 / 0,84 | 0,94 / 0,90 |
| … Leerlauf | 0,99 / 0,99 | 0,99 / 0,99 | 0,99 / 0,99 |
| Lautheit Vollgas ohne / mit (LUFS) | −16,45 / −16,03 | −15,90 / −15,30 | −15,82 / −15,43 |

Mit Anteil 0,5 (wie der Arcade-Motorbus) wäre das Auto noch breiter geworden (Vollgas 0,74 / 0,53), aber 1,0–1,5 dB
lauter – außerhalb des Plans. Im Leerlauf bleibt das Auto mittig: Dort liegt fast alles unter 500 Hz, und gerade das
bleibt absichtlich mono (sonst zöge der Raum das Bild je nach Drehzahl zu einer Seite, wie in Arcade gemessen).

### 16.4 Ambiente (`AmbienceAudio`)

Gewichte der Betten (0…1, weich überblendet in 1,5 s, in und aus dem Tunnel 0,5 s) aus: Zone und Dach des Feeds, der
Kamera im Tunnel, Stil, Klima und Merkmalen der Landschaft (`data/scenery.json`, neu im Feed: `style`, `climate`,
`features`, `water`), der Stunde gegen die Tageszeiten der Konfiguration (Nacht bis zur Morgendämmerung, die Vögel
wachen zwischen `dawn_start` und Sonnenaufgang, Morgenchor bis eine Stunde danach, Nacht ab Sonnenuntergang),
Regen und Schnee:

- Land: Wind (Einschnitt × 0,6, Brücke × 1,2, Wald × 0,4), Blätter (Wald 1, Tal 0,4, sonst 0,15); Stadt: `city_day`
  / `city_night` und ein Viertel Wind; Grillen nachts nach Klima (Norden × 0,5, Alpen × 0,6, Mittelmeer × 1,2),
  Zikaden nur am Mittelmeer am Tag; Wasser auf Brücken über Wasser (1), an der Küste (0,6), in Hafenstädten mit
  Kränen (0,4); Tunnel: nur die Lüfter; unter dem Dach das Brummen, alles andere × 0,6.
- Regen: das Regenbett, Insekten und Singvögel still; Schnee: Insekten und Vögel still, alles andere etwa 5 dB leiser.
- Rufe je Minute (Faktoren in `ambience.rates`): Singvögel am Tag 7 (Wald 12; Morgenchor × 1,6), Krähe 1,2, Lerche 0,8
  (offenes flaches Land), Specht 0,8 (Wald), Waldkauz nachts 1 (Wald) / 0,4, Hund 0,4 nachts / 0,15 am Tag, Spatzen 4
  und Tauben 1,5 in der Stadt am Tag, Hupe 1,2 / 0,4, Glocke 0,35 (Altstadt), Roller 0,8 (Mittelmeer × 2), Möwen
  5 × Wasser, Schiffshorn 0,25. Über 140 km/h kein Ruf.

Pegel: jedes Bett als Lautheit am Master bei Gewicht 1 im Stand (`ambience.beds.<id>.lufs`: Wind −39, Blätter −37,
Grillen −37, Zikaden −34, Stadt −33 / −37, Wasser −35, Tunnellüfter −34, Brummen −38, Regen −29 LUFS), jede Ruf-Art
als Momentanlautheit (`ambience.calls.<cat>.lufs_m`, −31 bis −42), je Ruf 0 bis −8 dB Entfernung. Über 30 km/h
werden Betten und Rufe leiser (8–12 dB je Dekade, Regen 3, höchstens 12 dB): Bei Reisetempo deckt das Auto sie
ohnehin zu, sie sollen dort nichts verschmieren. Pause: die Betten laufen 6 dB leiser weiter (der Mischzustand
`pause` dämpft `MAmb`), kein neuer Ruf.

### 16.5 Verkehr (`TrafficExtras`)

Das Modell bleibt Arcades `TrafficAudio` (Unterklasse `ModernTraffic`, die eingefrorene Datei ist unverändert). Klänge
und Klassen kommen aus dem Manifest und `audio.modern.traffic.classes` / `models` – nicht über `load_sounds()`, das
das Schleifenende ans Datenende setzt (die Modern-WAVs tragen Fortsetzungsframes). Pegel als Ziel am Master
(`traffic.levels`: eine Ebene eines Fahrzeugs innerhalb `traffic_ref_m` × Größe bei ihrem `ref_kmh`; Pkw-Motor und
-Reifen −27, Lkw-Motor −23, Lkw-Reifen −24,5, nasse Reifen −24 / −21,5, Fahrtwind −30, Elektroauto −38 LUFS):
`gain_db = Ziel − lufs − ref_path_db + 3,01` – `TrafficAudio` schwenkt eine Mono-Stimme mit gleicher Leistung, 3 dB
unter derselben Datei auf beiden Kanälen, wie das Manifest sie misst. Gemessen im Test auf 0,05 dB.

Luftstoß: ein Fahrzeug mit mindestens 30 km/h, das den Hörer mit mindestens 15 km/h Unterschied und höchstens 4,5 m
(Lkw/Bus 5,5 m) seitlich passiert; Pegel nach seinem eigenen Tempo (die Luft, die es schiebt; 20 dB je Dekade über
80 km/h) und 1 / Abstand, Tonhöhe nach dem Unterschied. Ein stehendes Auto wirft nichts.

Hupen: nach `collision` das nächste Fahrzeug innerhalb 15 m mit Wahrscheinlichkeit 0,8 nach 0,3–0,7 s; beim knappen
Vorbeiziehen (≤ 1,8 m, ≥ 30 km/h schneller) mit 0,25 zweimal kurz; höchstens eine Hupe je 8 s; −24 LUFS momentan in
10 m (Lkw −20), mit der Stimme mitgeführt (Seite, Doppler). Das Fahrzeug muss beim Hupen noch seine Stimme haben –
sonst hupt niemand aus dem Nichts.

Martinshorn: `siren_lufs` −17 LUFS innerhalb `siren_ref_m` (30 m), das Entfernungsgesetz von Arcade (Abfall 0,6,
mindestens 0,3); ohne Polizeiauto in der Liste mittig mit dem Pegel der Sitzung × diesem Bezug.

### 16.6 Gemessen

Probefahrt (`<scratch>/v080/m1/AUC2/tools/drive_c2.gd`: die Aufrufe der Rennsitzung auf echten Etappen, Verkehr
gesetzt, Limousine; Hörproben `deliver/AUC2/`):

MESS_TABELLE

Der schlimmste Fall (Abschnitt 15.5; Tunnel, zwei Lkw und ein Pkw dicht, Polizei 12 m hinten mit Martinshorn,
Rennmusik, Gran Turismo 230 km/h, schwerer Aufprall auf einen Lkw, Leitplanke, zweiter Aufprall): nach dem Begrenzer
MESS_WORST.

### 16.7 Rechenzeit

GDScript je Bild ohne Player (14 Fahrzeuge in der Liste, 6000 Bilder): `env` 0,017 ms, `ambience` 0,036 ms,
`traffic` 0,014 ms im Mittel (längstes Bild 0,16 / 0,97 / 0,16 ms). Mit Wiedergabe kommt das Setzen der Player
dazu (Arcade gemessen < 0,3 ms je Bild).

### 16.8 Fallen (gemessen bzw. im Quelltext nachgelesen, Godot 4.7.2)

1. **`AudioEffectDelay` setzt Tap- und Rückkopplungszeiten ohne Rampe**: Der Lesezeiger springt (Quelltext
   `audio_effect_delay.cpp`), bei laufendem Signal ein Knacken. Pegel wirken je Block von 256 Frames.
2. **Panorama der Taps**: links × (1 − p), rechts × (1 + p) – bei p = 1 rechts doppelt (+6 dB). Die Energie wächst
   mit 1 + p²; `EnvAcoustics` gleicht das aus.
3. **`AudioEffectReverb`**: Predelay-Änderungen springen ebenso; der Hallanteil wird intern mit 0,6 skaliert.
4. **Ein Zeichen U+0000 in einem GDScript-String** (`"\u0000"`) schreibt bei jedem Laden „Unicode parsing error …
   Unexpected NUL character“ ins Log.
5. **Eine Methode `_set(…)` in einem Skript** überschreibt `Object._set(StringName, Variant)` und bricht das Laden
   mit „function signature doesn't match the parent“ ab.

### 16.9 Offene Punkte

- **Hören**: alle Betten, Rufe, Verkehrsklänge, das Martinshorn und die Raumklänge. Die Vogelrufe sind Modelle
  (Tonfolgen mit gleitender Tonhöhe) – ob sie natürlich klingen, zeigt erst das Ohr. Pegel und Raten stehen in
  `audio.modern.ambience` / `traffic` / `env`.
- **Lautheit im Tunnel**: Hall und Reflexionen heben im Tunnel alles um 3–5 dB (gemessen im schlimmsten Fall); im
  gewöhnlichen Tunnel mit Lkw bei 80 km/h erreicht der Begrenzer seine Obergrenze in einem einzigen Frame.
- **Breite im Leerlauf**: bleibt mono (0,99), siehe 16.3.
- **Budget**: 22,23 von 23 MB – für weitere Klänge bleiben 0,77 MB (AU-E, Nacharbeit).
- **Donner und Länder-Martinshörner**: nicht in v0.8.0 (keine Blitze; Vertrag §1).
- **AU-E**: Ambiente- und Verkehrspegel gegen die ganze Mischung im Spiel nachhören; `check_audio_modern.gd`.
