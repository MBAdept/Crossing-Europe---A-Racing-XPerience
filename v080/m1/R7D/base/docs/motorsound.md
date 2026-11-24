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

Die Abschnitte 1–5 beschreiben den Motorklang v2 – seit v0.8.0 der Klang des Profils **Arcade**, eingefroren. Der
Motor v3 des Klangprofils **Modern** steht in **Abschnitt 6**.

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
| Lastwechselschlag (`thump`) | – | bei jedem Gangwechsel, so stark wie sein Drehmomentsprung: Hochschalten `level · (0,3 … 1 mit Pedal oder Last)`, Zurückschalten `level · (0,2 im Schub … 0,6 beim Kick-down)` |
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
| Kompakt | −20,6 \| −19,4 | 5,4 \| 8,1 | −18,6 \| −16,4 | −22,1 \| −20,1 | −21,0 \| −24,2 | −23,0 \| −22,2 | −24,1 \| −23,7 |
| Kombi | −23,2 \| −19,4 | 5,3 \| 9,6 | −21,2 \| −16,7 | −24,8 \| −20,8 | −26,0 \| −25,1 | −25,3 \| −22,0 | −28,7 \| −24,6 |
| Limousine | −21,4 \| −20,0 | 9,2 \| 5,7 | −19,6 \| −17,7 | −24,3 \| −20,9 | −28,0 \| −26,3 | −25,9 \| −21,2 | −23,2 \| −24,0 |
| Sportwagen | −18,3 \| −19,3 | 10,3 \| 7,2 | −16,0 \| −16,7 | −16,3 \| −17,3 | −27,4 \| −24,2 | −21,9 \| −21,1 | −24,1 \| −24,3 |
| Gran Turismo | −16,2 \| −20,0 | 7,2 \| 8,0 | −13,4 \| −17,1 | −17,2 \| −21,0 | −22,4 \| −26,6 | −19,0 \| −21,5 | −17,8 \| −24,6 |

Über die ganze Fahrt liegen die fünf Autos in Arcade 7,0 dB auseinander, in Modern 0,6 dB (von Lauf zu Lauf
schwanken diese Werte um 0,3–0,6 dB). Der Lautheitsbereich
wächst bei Kompakt und Kombi um 3–4 LU (Volllast hebt sich jetzt vom Rollen ab) und sinkt bei Limousine und
Sportwagen um 3–3,5 LU (ihr Reisetempo war in Arcade 4–5 dB leiser). Im Spiel ist der Arcade-Motor der drei
Turbo-Reihenmotoren bei Vollgas **heller** als der von Modern (Schwerpunkt Kompakt 904 gegen 448 Hz, Anteil ab
5 kHz −9,4 gegen −17 dB): Das ist das Turbopfeifen von Arcade, ein Sinus bei 5–6 kHz, der dort ein Zehntel der
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
- **Schleifen**: Godot 4.7.2 spielt an der Naht einer WAV-Schleife, die mit ihren Daten endet, einen falschen
  Abtastwert (gemessen, [audio-modern.md](audio-modern.md) Abschnitt 11, Falle 13). Die vier Schleifen der
  Fahrzeugebenen tragen deshalb 16 Frames Fortsetzung hinter dem Schleifenende; `test_engine3_bank.gd` prüft das.
- **Schläge beim Schalten**: Ihr Pegel folgt einem Gesetz für den Drehmomentsprung (6.3), nicht einer Messung am
  Fahrzeug. In den Aufnahmen stand der Schlag beim Zurückschalten im Schub zunächst 10–15 dB über dem Mittenband
  des Motors und trug ein Ticken bis 16 kHz; beides ist zurückgenommen, gehört hat es niemand.
