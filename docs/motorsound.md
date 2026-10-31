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

## 5. Umsetzung der Offline-Synthese (`tools/audio/engine_synth.py`)

Stand der Banken in `assets/audio/engines/`: Modell 2 (`synth.model` im JSON). Hören war während der Entwicklung
nicht möglich; die Qualität ist durch Messungen abgesichert (§5.8), die Demos liegen zum Anhören bereit.

### 5.1 Signalfluss je Bank

Für jede Bank (Auto, Drehzahl, Last) rendert das Werkzeug ein eingeschwungenes Signal von „Vorlauf + 8 + 1“
Arbeitsspielen (Vorlauf ≥ 0,3 s, damit alle Nachhallfahnen eingeschwungen sind) und schneidet daraus die Varianten.

1. **Ereignisse:** je Zylinder und Arbeitsspiel ein Ereignis mit echter Zündfolge und gleichmäßigem Zündabstand
   720°/Zylinderzahl. Streuung der Verbrennung (Druck bei „Auslass öffnet“) von Zyklus zu Zyklus (σ 2,5–4 % unter
   Last, 7–10 % im Leerlauf), feste Zylinderungleichheit (2–6 %), kleine Zündzeitpunkt-Streuung (nicht für
   Zylinder 1, der die Schnittpunkte festlegt).
2. **Krümmer-Wechselwirkung:** öffnet ein Zylinder kurz nach einem Nachbarn desselben Sammlers, trifft er auf
   dessen Druckwelle (höherer Gegendruck, mehr Restgas → schwächerer Stoß). Beim Cross-Plane-V8 sind die Abstände je
   Bank 90/180/180/270° – daraus entsteht das ungleichmäßige Blubbern. Weil das Restgas in der Ventilüberschneidung
   bei hohem Saugrohrunterdruck am stärksten zurückgedrückt wird, wächst der Effekt zum Leerlauf hin (`op.interact`).
3. **Auslassstoß (0-D-Modell):** Zylindervolumen aus dem Kurbeltrieb, Ventilhubkurve, kompressible Blendenströmung
   (kritisch/unterkritisch, Rückströmung), adiabate Entleerung, danach Ausschieben durch den Kolben bis
   „Auslass schließt“; integriert über den Kurbelwinkel (Zeitschritt ≤ 0,12 ms). Der Kanal ist die Mündung des
   Krümmerrohrs: `p_Kanal = p_Gegendruck + c/S · ṁ` (Wellenwiderstand). Das begrenzt die Spitze des Auslassstoßes
   und die Rückströmung in den Zylinder bei Schubabschaltung (Zylinderdruck 0,2 bar bei geschlossener Drosselklappe →
   Saugstoß statt Druckstoß). Last bestimmt den Druck bei „Auslass öffnet“ (Ladedruck, Füllgrad, Verbrennung oder
   Schubabschaltung), die Drehzahl das Verhältnis von Ventilöffnungs- zu Ausströmzeit.
4. **Aufsteilung:** starke Stöße steilen sich auf dem Weg bis zur ersten großen Querschnittsänderung auf
   (Ausbreitung mit c + (γ+1)/2·u, Länge `op.nl_len`, Stärke `op.nl`) – Stoßfronten unter Volllast, die die
   Obertöne bis 2–3 kHz tragen. Danach bandbegrenzte Dezimierung (Quelle mit 64 kHz gerechnet).
5. **Auspuffanlage:** eindimensionales akustisches Netzwerk (`profile.exhaust`, Knotenadmittanzverfahren je
   Frequenz): Krümmerrohre mit den toten Ästen der geschlossenen Kanäle, Sammler, Turbine/Kat/Partikelfilter als
   Widerstände, Rohre mit Wand- und Strömungsverlusten (kausal: Dämpfung ∝ √f mit passender Dispersion),
   Absorptionsschalldämpfer, Lochblech-/Prallblechwiderstände (dämpfen die tiefen Helmholtz-Moden), Helmholtz-
   Resonator, getrennte V8-Bänke mit H-Rohr, jedes Endrohr mit Abstrahlimpedanz und dem Strömungsverlust des
   Austrittsstrahls. Schallgeschwindigkeit je Abschnitt aus der Gastemperatur (Krümmer unter Last 900–1200 K, im Schub
   700–800 K, zum Endrohr hin kühler). Ergebnis: Übertragungsfunktion Kanal → Hörer je Zylinder, als Impulsantwort.
6. **Strömungsrauschen:** Ventilstrahl („Rasp“, Rauschen ∝ Durchfluss^1,5, läuft durch die Auspuffanlage) und
   Endrohrstrahl (Rauschen ∝ pulsierende Austrittsgeschwindigkeit², Band um die Strouhal-Frequenz) – das Brüllen
   bzw. Sägen bei hoher Last und Drehzahl.
7. **Ansaugung:** Saugimpuls je Zylinder (Einlass öffnet bis schließt) durch Saugrohr, Sammler, Drosselklappe
   (Schub: fast geschlossen, nur noch Drosselzischen), Ladeluftkühler und Verdichter (Turbo, dämpfen stark),
   Luftfilterkasten mit Filterwiderstand, Ansaugschnorchel; abgestrahlt an der Ansaugöffnung (Frontmotor:
   Karosserieschatten). Verdichter-Rauschen („Whoosh“) unter Last. Das Turbopfeifen fehlt absichtlich (Laufzeit).
8. **Mechanik:** Ventilaufsetzen (Amplitude ∝ Drehzahl^1,2), Injektorticken (direkteinspritzende Benziner; fehlt bei
   Schubabschaltung), Verbrennungsanregung des Motorblocks; Diesel: Verbrennungsschläge (Vor- und Haupteinspritzung)
   mit Körperschallresonanzen 1–5 kHz = Nageln, im Leerlauf am deutlichsten, im Schub aus. Modale Impulsantworten
   je Auto (`profile.mech`), Weg Motorraum → Hörer mit Abschattung.
9. **Hörer:** Verfolgerkamera 6 m hinter dem Heck, 1,6 m hoch; Direktschall + schwache Fahrbahnreflexion
   (Reflexionsfaktor 0,4, zu hohen Frequenzen fallend).
10. **Mischung:** Komponentenpegel (`profile.levels`, dB relativ zum Auspuff) werden über vier Volllast-Drehzahlen
    gemittelt kalibriert (eine Drehzahl allein hinge davon ab, wo Resonanzen liegen). Hochpass 22 Hz, Gleichanteil
    je Zyklus entfernt.

### 5.2 Die fünf Motoren (Profil und physikalische Entscheidungen)

| Auto | Motor, Zündfolge | Auspuff | Besonderheiten |
|---|---|---|---|
| `kompakt` | 2,0 l R4 Turbo, 1-3-4-2, 180° | kurzer integrierter Krümmer, Turbine, Kat, OPF, Mittel-Absorber, Sport-Endtopf, zwei Endrohre | 2. Ordnung dominiert (Brummen); Turbine glättet die Stöße; DI-Ticken im Leerlauf; leichtes Knistern, DSG-„Blat“ beim Hochschalten, Schubumluft mit kurzem Flattern |
| `kombi` | 2,0 l R4 Turbodiesel, 1-3-4-2 | VTG-Turbine (starke Dämpfung), Oxi-Kat + Partikelfilter, zwei Absorber mit Lochblechwiderständen, Anti-Dröhn-Resonator, abwärts gerichtetes Endrohr | Nageln (Vor-/Haupteinspritzung, Blockresonanzen 1–5 kHz), kein Drosselklappen-Schub (Diesel: Luftpumpen im Schub), stark gedämpft, tiefes Grollen; kein Knallen, keine Schubumluft |
| `limousine` | 3,0 l R6 Turbo, 1-5-3-6-2-4, 120° | Twin-Scroll (Zyl. 1–3 / 4–6), Kat, OPF, Mitteltopf, Y-Teilung auf zwei Endtöpfe | 3. Ordnung, seidig (stark gedämpfte Oberwellen), oben Endrohr-Strahlrauschen („leicht sägend“), leises Blubbern, dezente Schubumluft |
| `sportwagen` | 4,0 l Boxer-6 Sauger, 1-6-2-4-3-5 (je Bank 240°) | 3-in-1-Fächerkrümmer je Bank, Metallkats, Durchgangsrohre (Klappen offen), Querrohr, zwei Mittelrohre | 3. Ordnung, 1,5. Ordnung aus den getrennten Bänken, lange Aufsteilungsstrecke (scharfe Obertöne bis 9 000/min), Einzeldrosselklappen-Ansaugröhren am Heckmotor, metallischer Ventiltrieb, scharfe Cracks, PDK-Schaltknall |
| `gran_turismo` | 4,0 l V8 Biturbo Cross-Plane, 1-5-4-2-6-3-7-8, je Bank 90/180/180/270° | je Bank Turbolader, Fallrohr, Kat, ungleich lange Bankrohre bis zum H-Rohr, zwei Endtöpfe (Klappen offen), vier Endrohre | 4. Ordnung mit halben Ordnungen (Blubbern, im Schub dominierend), starke Krümmer-Wechselwirkung zum Leerlauf hin, tiefe Bangs, laute Schubumluft |

Getriebe (`gearbox`, Vertrag §1): Vmax liegt im höchsten Gang weit unter dem Begrenzer; 130 km/h im höchsten Gang:
Kompakt 2 650/min (7. Gang), Kombi 1 810/min (8.), Limousine 2 000/min (8.), Sportwagen 2 800/min (7.),
Gran Turismo 2 500/min (7.). Bei Vollgas wird Vmax im vorletzten Gang (Kompakt 6., ~6 000/min; Kombi 7., ~4 100/min;
Limousine 6., ~5 900/min; GT 6., ~6 300/min) bzw. beim Sportwagen im 5. Gang (~8 300/min) erreicht – der höchste
Gang ist ein Spargang. Die Hochschaltdrehzahl bei Vollgas liegt über der Vmax-Drehzahl des Vmax-Gangs, damit die
Automatik dort nicht pendelt.

### 5.3 Banken

- **Drehzahlpunkte:** vom Leerlauf (erster Punkt ≤ `idle_rpm`) bis zum Begrenzer (letzter Punkt ≥ `limiter_rpm`),
  Abstand Faktor 1,24–1,25 unten bis 1,14–1,20 oben (oben sind die Zyklen kurz und billig). 11–14 Punkte je Auto.
- **Ganzzahlige Perioden:** jede Bankdrehzahl ist `120 · 32000 / period` mit ganzzahligem `period`; deshalb stehen
  im JSON krumme Drehzahlen (z. B. 699,964 statt 700). Alle Schnittpunkte liegen exakt auf Samples.
- **Zyklusanfang:** Wellenfront des Auslassstoßes von Zylinder 1 beim Hörer = Öffnen des Auslassventils + Laufzeit
  über den kürzesten akustischen Weg (Rohrlängen / temperaturabhängige Schallgeschwindigkeit + Luftweg). Die
  Laufzeit steht je Bank in `delay_ms` (24–30 ms; im Schub ~1 ms länger, weil das Gas kühler ist).
- **Varianten:** 8 aufeinanderfolgende Arbeitsspiele aus dem eingeschwungenen Signal; `overlap` = 128 Samples
  (4 ms) Fortsetzung über das Zyklusende hinaus.
- **Schubbank** (`off`): geschlossene Drosselklappe. Im Leerlauf Leerlaufverbrennung, oberhalb `op.cut_rpm`
  Schubabschaltung, dazwischen zylinderselektiver Wiedereinsatz (jedes Ereignis zündet mit der Wahrscheinlichkeit
  des Übergangsanteils voll oder gar nicht) – halbstarke Stöße würden die Polarität kippen und beim Überblenden
  auslöschen.
- **Pegel:** A-bewertete Bankpegel werden je Last durch eine glatte Kurve über log(Drehzahl) angenähert; deren
  Drehzahlabhängigkeit wird gestaucht (`mix.rpm_compress` 0,45: der Leerlauf bleibt hörbar), der Abstand Schub zu Last
  ebenfalls (`mix.off_compress`), und die Hälfte der Abweichung jeder Bank von der Kurve (Resonanzen) bleibt erhalten.
  Dann wird die Lastbank bei halber Nenndrehzahl (0,5 × `redline_rpm`) auf −3 dBFS Spitze gebracht; überschreitet irgendeine Bank
  −0,3 dBFS, wird das ganze Auto abgesenkt (Kombi −1,8 dB, Limousine −3,9 dB, GT −0,9 dB). `level_db` je Bank =
  A-bewerteter Pegel in dBFS.
- **`mix.gain`:** aus der gemessenen K-bewerteten Volllast-Lautheit (Banken 0,4–0,9 × rote Linie, `synth.
  loudness_full_db`) und dem Zielabstand je Auto (`profile.mix.loudness_db`: GT 0, Sportwagen −1, Kompakt −4,
  Limousine −4,5, Kombi −8 dB), normiert auf 1,0 für den GT. **`mix.off_gain`** = 1,0, nur der Sportwagen 0,708
  (−3 dB): sein Saug-Schub ist bei 8 000–9 000/min physikalisch fast so laut wie Volllast.
- **Größe:** 1,8–2,3 MB je Auto, 9,7 MB gesamt (davon Startclip 1,75 s ≈ 220 KB je Auto).

### 5.4 Clips

| Clip | Autos | Erzeugung |
|---|---|---|
| `crackle` (8 Varianten) | Kompakt (leichtes Knistern), Limousine (weiches Blubbern), Sportwagen (scharfe Cracks), GT (tiefe Bangs) | Nachverbrennung im heißen Auspuff: schnelle Expansion mit turbulentem Brand als Volumenquelle an den Endtopf-Knoten (`crackle_nodes`), durch dieselbe Auspuffanlage gerechnet; Einzelknalle und Salven. Spitze der lautesten Variante 0,75 |
| `blowoff` | Kompakt, Limousine, GT | Strahlrauschen eines Ventils mit fallender Mittenfrequenz (Druckabbau), kurzer tiefer Druckstoß; Kompakt mit leichtem Verdichterflattern. Spitze 0,5 |
| `shift` (2) | Kompakt (DSG-„Blat“: kurze Fehlzündungssalve + Pop), Sportwagen (PDK-Crack + Echo), GT (Bang + Blubbern) | Zündunterbrechung beim Hochschalten unter Last, wie `crackle`. Spitze 0,7 |
| `start` | alle | Anlasser (Ritzel-/Zahnkranzheulen, Motorbrummen, Kompressionstakte bremsen die Kurbelwelle), erste Zündungen, Hochdrehen auf 1,45–1,7 × Leerlauf, Einpendeln; mit dem Ereignismodell als Drehzahlverlauf gerechnet. Endet im Leerlauf mit dem Pegel der Leerlaufbank (Überblenden in die Bank) |

### 5.5 Neu erzeugen

```bash
python3 tools/audio/engine_synth.py              # alle fünf Autos -> assets/audio/engines/ (~1 min)
python3 tools/audio/engine_synth.py --car kombi  # nur ein Auto (mix.gain aller Autos wird neu abgeglichen)
python3 tools/audio/engine_synth.py --info       # Drehzahlpunkte, Größen, Getriebe-Plausibilität
python3 tools/audio/engine_preview.py --out /tmp/ce_engine_demo   # Demos, Spektrogramme, Prüfungen (~30 s)
```

Nur Python 3 + numpy (kein scipy); ffmpeg nur für OGG und Spektrogramme. Die Ausgabe ist deterministisch
(feste Zufallssamen je Auto/Bank), ein erneuter Lauf erzeugt bitgleiche Dateien.

### 5.6 Abstimmen

- **Charakter einer Anlage:** `profile.exhaust` (Rohrlängen/-durchmesser verschieben Resonanzen; `absorb` dämpft
  Höhen; `res`-Elemente vor Schalldämpfern dämpfen Dröhnen; Turbine `res` glättet Stöße). Prüfen mit den Pegeln je
  Bank (`level_db`) und den Ordnungen aus `engine_preview.py`.
- **Rauigkeit/Obertöne:** `op.nl`/`op.nl_len` (Aufsteilung), `levels.rasp`/`levels.jet` (Strömungsrauschen).
- **Blubbern (V8):** `op.interact` (Stärke, Abklingwinkel), `geo.imbalance`, Bankrohr-Asymmetrie vor dem H-Rohr.
- **Leerlauf-Unruhe:** `op.sigma_idle`; **Schub:** `op.p_im_cut` (Saugstoß), `op.cut_rpm` (Wiedereinsatz).
- **Nebenkomponenten:** `levels` (dB relativ zum Auspuff), Mechanik-Moden `mech` (Frequenzen, Güte).
- **Pegel:** `mix.rpm_compress`, `mix.off_compress`, `mix.off_db` (→ `off_gain`), `mix.loudness_db` (→ `gain`).
- **Laufzeit-Ebenen:** `layers` wird unverändert ins JSON übernommen (Werte nach Vertrag §1).

### 5.7 Referenz-Player (`tools/audio/engine_preview.py`)

Spielt eine Bank genau wie §4 beschrieben (Phase += rpm/(120·Abtastrate), Lesestelle Phase·Periode je Quelle,
lineare Interpolation, log-Drehzahl- und Gleichleistungs-Lastblende, `off_gain`, `gain`, zufällige Variante ohne
Wiederholung, Überblendung über `overlap`, Begrenzer mit `on_cycles`/`cut_cycles`) und fährt eine Demo von ~28 s:
Start, Leerlauf, drei Gasstöße im Stand (der letzte bis in den Begrenzer), Vollgasstart mit Schlupf und Hochschalten
bis ~92 % Vmax, Gaswegnehmen bei hoher Drehzahl (Knallen/Schubumluft), Rollen, Bremsen mit Rückschalten (sportliche
Autos mit Zwischengas), Leerlauf. Die Beschleunigung folgt der Spielkurve (`VehicleModel.fit_accel_curve`), ist aber
zeitlich gerafft (jedes Auto erreicht ~92 % Vmax nach ~11 s). Das Turbopfeifen der Demo ist ein einfacher Platzhalter
für die Laufzeit-Ebene.

### 5.8 Prüfungen und Ergebnisse (Stand dieser Banken)

| Prüfung | Kompakt | Kombi | Limousine | Sportwagen | GT |
|---|---|---|---|---|---|
| Dominante Ordnung Last / Schub | 2 / 2 | 2 / 2 | 3 / 3 | 3 / 3 (1,5: −9 dB) | 4 / 4 (halbe Ordnungen −9 … −18 dB) |
| Bank-Spitze max. | 0,95 | 0,97 | 0,97 | 0,82 | 0,97 |
| Gleichanteil je Zyklus | 0 | 0 | 0 | 0 | 0 |
| HF-Energie an Übergängen ÷ natürliche Folge (Median / max) | 0,82 / 1,07 | 0,93 / 1,46 | 0,83 / 0,98 | 0,83 / 0,98 | 0,85 / 1,00 |
| Demo: Sprünge an Zyklusgrenzen ÷ an übrigen Zylinderimpulsen (P99) | 0,98 | 1,03 | 0,99 | 1,12 | 1,08 |
| Korrelation Nachbar-Drehzahlbanken bei 0° (Mittel / min) | 0,95 / 0,60 | 0,96 / 0,87 | 0,86 / 0,05 | 0,86 / 0,16 | 0,92 / 0,60 |
| Demo-Spitze (mit Clips und `gain`) | 0,71 | 0,80 | 0,67 | 0,75 | 0,86 |
| Demo Volllast, K-bewertet | −17,3 | −19,4 | −18,8 | −16,0 | −12,8 |
| Demo Vollgas / Schub / Leerlauf, A-bewertet (dBFS) | −24,5 / −31,8 / −41,4 | −24,0 / −36,5 / −32,0 | −25,4 / −37,4 / −41,6 | −18,8 / −26,7 / −37,7 | −15,9 / −25,9 / −34,9 |

Deutung: Übergänge erzeugen keine Klicks (keine HF-Überhöhung, Sprünge wie an jedem anderen Zylinderimpuls); der
Kombi-Leerlauf ist durch das Nageln lauter als der Schub; GT am lautesten, Kombi am leisesten und dumpfsten. Die
Korrelationswerte gelten für die gemittelten Zyklen benachbarter Banken nach Streckung auf dieselbe Periode
(1,0 = phasengleich); alle Lastbank-Paare liegen bei ≥ 0,84.

Unterschiede zwischen den Autos: Volllast-Spektren (Terzbänder 50 Hz–8 kHz) weichen paarweise um 6,3 dB
(Sportwagen–GT) bis 11,2 dB RMS (Kompakt–Sportwagen) voneinander ab; ähnliche Ordnungsmuster gibt es nur bei gleicher
Zylinderzahl (Kompakt/Kombi Korrelation 0,83, Limousine/Sportwagen 0,90), diese Paare unterscheiden sich dann im
Spektrum um 10,1 bzw. 9,2 dB, im Drehzahlbereich und in den Nebengeräuschen (Nageln, Ansaugröhren).

### 5.9 Abweichungen und bekannte Grenzen

- Bankdrehzahlen sind nicht rund (ganzzahlige Perioden, §5.3); `period` ist exakt `120 · sample_rate / rpm`.
- Zusätzliche JSON-Felder (`banks[].delay_ms`, `banks[].level_db`, `synth`) – rein informativ, die Laufzeit ignoriert
  sie.
- „Lastbank bei mittlerer Drehzahl mit Spitzen um −3 dBFS“: bei Kombi, Limousine und GT liegt sie 1–4 dB darunter,
  weil sonst einzelne Banken (Leerlauf mit Nageln, tieffrequente Lastbanken der Limousine) über −0,3 dBFS kämen;
  `mix.gain` gleicht die Lautheit aus.
- Nicht jedes Auto hat jeden Clip/jede Ebene: Kombi ohne `crackle`/`blowoff`/`shift` (Diesel: kein Knallen, keine
  Drosselklappe), Limousine ohne `shift` (Wandlerautomatik), Sportwagen ohne `turbo`/`blowoff` (Saugmotor).
- Schub-Übergang Wiedereinsatz/Schubabschaltung (etwa 1,2–1,6 × Leerlauf): Verbrennungs- und Saugstöße haben
  entgegengesetzte Polarität; trotz zylinderselektivem Wiedereinsatz korrelieren einzelne Schubbank-Paare dort nur
  schwach (Limousine 0,05) – beim Durchlaufen kann der Pegel kurz einsinken. Ebenso einzelne Sportwagen-Schubbanken
  bei 3 700–4 300/min (1,5. Ordnung trifft dort eine Phasendrehung der Anlage).
- Methodisch: Resonanzen, die in Hz fest sind (Auspuff, Motorblock), werden von der Laufzeit mit dem Leseschritt
  um bis zu ±12 % mitgestreckt; die dichten Drehzahlpunkte und die gedämpften Moden halten das unauffällig.
