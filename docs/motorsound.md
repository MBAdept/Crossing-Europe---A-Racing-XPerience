# Motorklang v2 – Vertrag zwischen Offline-Synthese und Laufzeit

Anlass (Playtest): Der Motor klingt synthetisch (eine additiv erzeugte Schleife, nur in der Tonhöhe verschoben) und
für alle fünf Autos gleich. Ziel: realistischer, für jedes Auto eigener Motorklang – vom Leerlauf über
Vollgas-Hochdrehen mit Schaltvorgängen bis zum Schiebebetrieb mit Knallen.

Lösung in zwei Teilen:

1. **Offline-Synthese** (`tools/audio/engine_synth.py`, Python 3 + numpy, physikalisch angelehnt): rendert je Auto
   eingeschwungene Motorsignale bei mehreren Drehzahlen und zwei Lastzuständen und schneidet sie in einzelne
   **Arbeitsspiele** (ein Arbeitsspiel = 720° Kurbelwinkel = zwei Umdrehungen). Ergebnis: eine **Zyklusbank** je
   Auto in `assets/audio/engines/`.
2. **Laufzeit** (`scripts/audio/engine_audio.gd`, Klasse `EngineAudio`): erzeugt den Klang per
   `AudioStreamGenerator`, indem sie Arbeitsspiele lückenlos aneinanderreiht (zyklussynchrones Overlap-Add),
   jedes auf die aktuelle Periodendauer umgerechnet. Drehzahl und Gang kommen aus einem Getriebemodell je Auto.
   Weil alle Quellen am selben Zyklusanfang ausgerichtet sind, lassen sich Drehzahlstufen und Lastzustände
   phasengleich überblenden (kein Kammfilter-/Chorus-Effekt wie bei überblendeten Schleifen).

Messung (GDScript, diese Maschine): vier interpolierte Quellen + Mischung kosten 0,25 ms pro Frame bei 32 kHz.

## 1. Dateien

`assets/audio/engines/<auto>.json` (Metadaten) und `assets/audio/engines/<auto>.f32` (Rohdaten: Mono-Samples,
32-Bit-Float little endian, alle Ausschnitte hintereinander). `<auto>` = `kompakt`, `kombi`, `limousine`,
`sportwagen`, `gran_turismo`. Die Laufzeit liest die Rohdaten mit `FileAccess.get_buffer()` +
`PackedByteArray.to_float32_array()`; damit `*.f32` im Export landet, steht `*.f32` in `include_filter` von
`export_presets.cfg`.

```json
{
  "format": "ce-engine-bank-1",
  "car": "gran_turismo",
  "sample_rate": 32000,
  "data": "gran_turismo.f32",
  "engine": {"label": "4,0 l V8 Biturbo", "cylinders": 8, "layout": "v_crossplane", "fuel": "petrol",
             "aspiration": "turbo", "idle_rpm": 700, "redline_rpm": 7000, "limiter_rpm": 7200},
  "gearbox": {"kmh_per_1000rpm": [9.0, 14.5, 21.0, 28.5, 35.5, 43.0, 52.0], "final_note": "…",
              "upshift_rpm": [3000, 6800], "downshift_rpm": [1300, 4200], "shift_time_s": 0.18,
              "launch_rpm": 2600},
  "banks": [
    {"rpm": 700, "load": "off", "period": 5485.7, "overlap": 96,
     "cycles": [[0, 5582], [5582, 5582], …]},
    {"rpm": 700, "load": "on", …}, …
  ],
  "clips": {"crackle": [[offset, length], …], "blowoff": [[offset, length]], "shift": [[…]], "start": [[…]]},
  "layers": {
    "turbo": {"whistle_hz": [1800, 5200], "level": 0.10, "spool_s": 0.55, "boost_rpm": 2200},
    "crackle": {"min_rpm": 3200, "rate_hz": 7.0, "duration_s": 1.4, "level": 0.6},
    "blowoff": {"min_boost": 0.55, "level": 0.5},
    "limiter": {"cut_cycles": 2, "on_cycles": 3}
  },
  "mix": {"gain": 1.0, "off_gain": 0.42}
}
```

| Feld | Bedeutung |
|---|---|
| `banks[]` | je Drehzahlpunkt `rpm` und Last `load` (`"on"` = Vollgas, `"off"` = Schub/geschlossene Drosselklappe) eine Bank. Für **jeden** Drehzahlpunkt gibt es **beide** Lasten. Drehzahlpunkte von Leerlauf bis `limiter_rpm`, aufsteigend, Abstand höchstens Faktor 1,25. |
| `period` | Länge eines Arbeitsspiels bei `rpm` in Samples: `120 / rpm · sample_rate` (Gleitkomma). |
| `cycles` | mindestens 8 Varianten (`[offset, length]` in Samples, Offset in die `.f32`-Daten). `length = round(period) + overlap`: das Arbeitsspiel plus `overlap` Samples Fortsetzung des Signals über das Zyklusende hinaus (für das Überblenden). |
| Zyklusanfang | alle Zyklen aller Banken eines Autos beginnen am **selben akustischen Ereignis**: Eintreffen des Auslassimpulses von Zylinder 1 beim Hörer (nicht am Kurbelwinkel – die Laufzeit im Auspuff ist in Sekunden konstant). So mischen sich Drehzahl- und Laststufen phasengleich. |
| `clips` | Einmalklänge (optional je Auto): `crackle` (mehrere kurze Knall-/Patsch-Varianten im Schiebebetrieb), `blowoff` (Schubumluftventil, Turbo), `shift` (Schaltknall, z. B. Doppelkupplung), `start` (Anlasser + Anspringen). |
| `layers` | Parameter der Laufzeit-Ebenen (fehlende Ebene = aus): `turbo` (Pfeifen, Frequenzbereich, Pegel, Ladedruckaufbau `spool_s`, ab `boost_rpm`), `crackle` (ab Drehzahl, Rate, Dauer nach dem Gaswegnehmen, Pegel), `blowoff`, `limiter` (Zündunterbrechung: `cut_cycles` Schubzyklen nach `on_cycles` Lastzyklen). |
| `gearbox` | Getriebe des Autos: Geschwindigkeit je 1000/min pro Gang (`kmh_per_1000rpm`), Hochschaltdrehzahl bei wenig bzw. Vollgas (`upshift_rpm`), Rückschaltdrehzahl bei wenig bzw. Vollgas (`downshift_rpm`, Hysterese), Schaltzeit, Anfahrdrehzahl. Im höchsten Gang liegt `vmax_kmh` des Autos (config `vehicles.types`) unter `limiter_rpm`. |
| `mix` | Grundpegel des Autos (`gain`, Gran Turismo lauter, Kompakt leiser) und Pegel der Schubbank relativ zur Lastbank. |

Mindestens 32 kHz Abtastrate (Nyquist 16 kHz reicht für Diesel-Nageln und Sägen). Pegel: Lastbank bei mittlerer
Drehzahl mit Spitzen um −3 dBFS vor `gain`; keine Gleichspannung; Banken frei von Klicks an den Zyklusgrenzen.

## 2. Fünf Motoren (Charakter)

| Auto | Motor | Klang |
|---|---|---|
| `kompakt` (230 km/h, 0–100 in 4,6 s) | 2,0-l-Reihenvierzylinder Turbo („Hot Hatch“), DSG 7 Gänge, Leerlauf ~850, rot ~6800 | kerniges Brummen (2. Ordnung), Turbopfeifen und Schubumluftzischen, leichtes Blubbern und Knistern im Schub |
| `kombi` (235 km/h, 7,0 s) | Turbodiesel (Reihenvierzylinder oder V6), Automatik 8 Gänge, Leerlauf ~780, rot ~4600 | Diesel-Nageln (harte Verbrennungsschläge), tiefes, gedämpftes Grollen, deutliches Turbopfeifen, kein Knallen |
| `limousine` (245 km/h, 5,6 s) | 3,0-l-Reihensechszylinder Turbo, Automatik 8 Gänge, Leerlauf ~650, rot ~7000 | seidig und gleichmäßig (3. Ordnung), oben leicht sägend, dezentes Turbo, leises Blubbern im Schub |
| `sportwagen` (255 km/h, 3,8 s) | 4,0-l-Sechszylinder-Boxer Saugmotor, Doppelkupplung 7 Gänge, Leerlauf ~950, rot ~9000 | metallisch-rau, Ansaugröhren, kreischt oben heraus, scharfes Knallen beim Gaswegnehmen und Schaltknall |
| `gran_turismo` (270 km/h, 4,6 s) | 4,0-l-V8 Biturbo mit Cross-Plane-Kurbelwelle, Automatik 7–9 Gänge, Leerlauf ~700, rot ~7000 | tiefes, unregelmäßiges Blubbern (ungleiche Zündabstände je Bank), Grollen bis Brüllen, laute Fehlzündungen im Schub |

## 3. Synthese (Richtlinien für `engine_synth.py`)

Physikalisch angelehnt, nicht additiv: Auslassimpulse je Zylinder mit echter Zündfolge und echten
Zündabständen (Cross-Plane-V8: je Bank ungleichmäßig, beide Bänke getrennt bis zum Zusammenführen), Impulsform
(steiler Anstieg, Abklingen), Last- und Drehzahlabhängigkeit, Zyklus-zu-Zyklus-Streuung (Amplitude, Zeitpunkt; im
Leerlauf stärker), Auspuffanlage als Wellenleiter bzw. Resonatoren (Krümmer-/Rohrlängen, Schalldämpfer als
Tief-/Bandsperre, Endrohrabstrahlung), Ansaugrauschen bei Last, Ventiltrieb/Mechanik, beim Diesel kurze
Verbrennungsschläge mit Körperschall-Resonanzen. Hörer = Verfolgerkamera hinter dem Auto (Auspuff dominiert, etwas
Fahrbahnreflexion). Turbopfeifen entsteht zur Laufzeit (hängt vom Ladedruck ab, nicht nur von der Drehzahl).

## 4. Laufzeit (`EngineAudio`)

- `AudioStreamGenerator` mit `mix_rate = sample_rate` der Bank, Puffer ≈ 0,25 s, je Frame auf ≈ 60–80 ms Vorlauf
  füllen; Bus `SFX`. Ohne Bank (Datei fehlt) bleibt der bisherige Klang aus `SfxSynth` (Rückfall).
- Je Ausgabesample: die beiden benachbarten Drehzahlbanken × beide Lasten, jede auf die aktuelle Periode
  umgerechnet (Leseschritt `rpm / bank_rpm`), Gewichte logarithmisch zwischen den Drehzahlpunkten und
  gleichleistungs-überblendet nach Last; Zyklusübergänge mit Überblendung über `overlap`; Variante je Zyklus
  zufällig (nicht zweimal dieselbe hintereinander).
- Getriebemodell je Auto aus `gearbox`: Gangwahl wie eine Automatik (Hochschalten lastabhängig zwischen den beiden
  `upshift_rpm`, Rückschalten mit Hysterese, Rückschalten beim Bremsen mit Zwischengas bei sportlichen Autos),
  Schaltvorgang = Lastunterbrechung + Drehzahlsprung, Anfahren mit Schlupf (`launch_rpm`), Stand = Leerlauf, Gasstöße
  im Stand (Countdown) mit Trägheit bis zum Begrenzer (Zündunterbrechung nach `limiter`), Turbo-Ladedruck mit
  Verzögerung, Knallen und Schubumluft nach dem Gaswegnehmen.
- API: `AudioManager.set_vehicle(id)` (Rennsitzung beim Start), `set_engine(speed_kmh, throttle, vmax_kmh, active)`
  wie bisher; Zustand für Tests/HUD über `AudioManager.engine_state()` → `{rpm, gear, load, boost}`.
- Fahrzeugwahl: beim Wechsel des Autos ein kurzer Gasstoß dieses Motors (Probehören).
- Pause und Szenenwechsel: weich ausblenden, Generator nicht weiter befüllen.
