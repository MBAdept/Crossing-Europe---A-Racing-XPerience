# KRITIK-FAHRBAHN – Messprüfung von Fahrbahn, Reifen, Wind und Aufprall (AU-C1) und ihrer Auslösung im Spiel

**Prüfgegenstand:** Klangprofil „Modern“ auf Kopf `4209268` (`origin/wip/v080-au-c1`) – Schwerpunkt AU-C1 (`audio_feed.gd`,
`road_audio.gd`, `impact_audio.gd`, `modern_audio_pan.gd`, `vehicle_loops.py`, `sfx_modern.py`, `audio.modern.feed/road/impact`).
Gearbeitet auf einer Kopie des Arbeitsbaums (ohne `.git`/`build`, `.godot` aus dem Hauptarbeitsbaum, einmal importiert);
nichts gebaut, nichts eingecheckt, der Arbeitsbaum von AU-C1 nur gelesen.

**Kennzeichnung.** *gemessen* = auf dieser VM (Godot 4.7.2 ohne Bildschirm, Dummy-Audiotreiber, Aufnahme am Master bei
Standardreglern, Gesamtlautstärke 0,8 = −1,94 dB). *abgeleitet* = aus Dateien, Konfiguration, Code oder einem Modell
gerechnet. *Literatur* = bekannte Größenordnung aus der Fachliteratur, hier nicht gemessen. **Gehört hat hier niemand
etwas.** Ob etwas künstlich *klingt*, entscheidet der Nutzer; die Messungen sagen, wo es wahrscheinlich ist und warum.

---

## 0. Für heute Abend – das Wichtigste

1. **Das Rollgeräusch wiederholt sich im Sekundentakt** (gemessen). Jede Belag- und Windebene spielt *dieselbe*
   2-s-Schleife auf zwei Spielern, um die halbe Länge versetzt und mit gleicher Tonhöhe. Die Summe beider Kanäle ist
   damit exakt periodisch mit 0,97 s (bei 130 km/h); im ganzen Spielmix hat das Band 0,6–1,6 kHz dort eine
   Hüllkurven-Korrelation von **0,64** (Motor allein: 0,14). Über 400 Hz liegt das Rollgeräusch **6–10 dB über Motor +
   Wind** – es ist nicht verdeckt. Wahrscheinlich als „pumpendes Rauschen“ hörbar (abgeleitet), auf Lautsprechern stärker
   als im Kopfhörer.
2. **Kopfsteinpflaster ist je Stadt „alles oder nichts“** (gemessen, Fehler): `AudioFeed.unit_hash("<ziel>|<block>")`
   ändert sich zwischen den Blöcken einer Stadt praktisch nicht. Von 43 Zielstädten mit Pflaster-Stil sind 20 immer ganz
   gepflastert – **Hamburg darunter** (Kiel – Hamburg endet mit 39 s Pflaster bei +19 dB über Asphalt) –, 9 nie (Paris).
3. **Pflaster +19 dB über Asphalt** beim gleichen Tempo ist laut (Literatur: Pflaster in der Vorbeifahrt +3…+6 dB(A),
   RLS-90; im Auto mehr Tieftonanteil). Bei 50 km/h so laut wie Asphalt bei ~215 km/h. Vorschlag `surface_db.cobbles`
   19 → 12 (dann ≈ Asphalt bei 125 km/h).
4. **Betonplatten dominieren den Beton:** Fahrbahnebene +5,4 dB lauter als Asphalt, Spitzen +4,6 dB (gemessen), ein
   8-Platten-Akzentmuster (6–7 dB Spannweite) wiederholt sich alle 1,11 s (Korrelation 0,86, gemessen), und zwischen
   110 und 150 km/h laufen nach jedem Tempowechsel zwei Schleifen ohne gemeinsamen Takt (Doppelschläge, abgeleitet aus
   dem Code). Vorschlag `slabs.db` 3 → −3, Kreuzblende enger oder phasengleich.
5. **Brückenfugen alle 24 m auf jeder Brücke** (gemessen: Köhlbrandbrücke 12 Fugen auf 261 m). Stahl-Schrägseil- und
   Steinbogenbrücken haben physikalisch keine Zwischenfugen (Literatur). Vorschlag: Fugenabstand je Deck.
6. **Kleine Lautsprecher kippen die Balance** (Modell, abgeleitet): bei 130 km/h verliert der Motor ~12 dB, das
   Rollgeräusch nichts – auf dem Steam Deck wären Reifen und Motor etwa gleich laut. Der Rüttelstreifen verliert seinen
   Grundton (−18 dB), bleibt aber über 2./4. Oberton hörbar (−3,8 LU). Wummern, Betonfugen und Plattenschläge
   verschwinden fast ganz.
7. **Pegel:** Ein einzelner schwerer Aufprall (130 km/h Schließgeschwindigkeit) erreicht bei Gesamtlautstärke 1,0
   **−0,7 dBTP** (gemessen) und Dauerfahrt bei Höchsttempo **−0,9 dBTP** (gemessen −2,8 bei 0,8) – D29 verlangt ≤ −1.
   Vorschlag für die Leitung: ein eigener Begrenzer auf `MMaster` mit **−2,0 dB** Obergrenze (Arcade unberührt).
8. **Glas klingt wie Weinglas** (gemessen: Töne 3,0–8,8 kHz mit 21–27 dB Überhöhung, eine einzige Variante, in jedem
   schweren Aufprall), **Quietschen ist ein Ton** (812 Hz ± 1 %, 26 dB Überhöhung). Beides wirkt wahrscheinlich
   synthetisch (abgeleitet).

Was funktioniert (gemessen): Tunnel, Brückenenden, Zonen und Belag werden auf vier Etappen richtig ausgelöst; die
Pegelgesetze treffen ihre Ziele (Asphalt bei 130 km/h −29,7 LUFS, Gesetz −29,95); Rüttelstreifen-Grundton genau
v / 0,30 m (120 Hz bei 130 km/h); Nähte sauber; Rechenzeit 0,2 ms je Bild; Arcade lädt kein Modern-Skript.

---

## 1. Befunde nach Rang

Rang = wie oft und wie deutlich der Spieler es hört (Autobahn 100–200 km/h zuerst), dann Schwere.

| Nr | Gewicht | Befund | Beleg | Korrektur (Datei → Parameter → Wert) |
|---|---|---|---|---|
| B1 | hoch | Rollgeräusch und Wind wiederholen sich exakt alle L/2 (0,97 s Asphalt bei 130 km/h) in der Kanalsumme, alle L (1,95 s) je Kanal | gemessen, 2.3 | `road_audio.gd` `Layer`: je Seite eine **eigene** Schleife (zweiter Seed) mit anderer Länge, oder Seite R mit Tonhöhe × 1,023 und zufälligem Startversatz; dazu langsame Pegelschwankung je Seite (±1,5 dB, 0,2–2 Hz, wie die Böen). `vehicle_loops.py`: Rauschschleifen länger (≥ 6 s, Ogg q4 statt WAV, siehe 2.3) |
| B2 | hoch | Pflaster-Entscheidung je Stadt konstant (djb2-Hash ändert nur das letzte Zeichen) | gemessen, 2.4 | `audio_feed.gd` `unit_hash()`: Hash mischen (z. B. murmur-`fmix32` auf `key.hash()`), oder Schlüssel `"%d|%s" % [block, to_id]` |
| B3 | hoch | Pflaster +19 dB über Asphalt bei gleichem Tempo; bei 50 km/h so laut wie Asphalt bei ~215 km/h | abgeleitet aus Gesetz + Datei, gemessen −22,9 LUFS (nur Fahrbahn, 50 km/h) | `audio.modern.road.tyres.surface_db.cobbles` 19 → **12**; `feed.cobble_share` 0,6 → 0,35 (nach B2) |
| B4 | mittel-hoch | Beton: Plattenschläge lauter als das Rollen, 8-Platten-Akzentmuster alle 40 m, zwei Plattenschleifen ohne gemeinsamen Takt zwischen 110 und 150 km/h | gemessen (Pegel, Spitzen, Autokorrelation 0,86 bei 1,11 s), abgeleitet (Takt) | `road.slabs.db` 3 → **−3**; `road.slabs.crossfade_kmh` [110, 150] → [125, 135] oder im Code den gestoppten Spieler an der Position des anderen starten; besser: Plattenfugen als Feed-Ereignisse alle 5 m (Variante und ±2 dB zufällig je Fuge) |
| B5 | mittel | Brückenfugen alle 24 m auf allen Brückentypen; Steinbögen spielen Betonfugen | gemessen (12 / 9 / 17 / 6 Fugen auf vier Brücken), Literatur | `audio.modern.feed.joint_every_m` als Tabelle je Deck: `{"steel": 0, "stone": -1, "concrete": 32}` (−1 = auch keine Endfugen); `audio_feed.gd` liest sie |
| B6 | mittel | Kleine Lautsprecher: Motor −11,6 dB, Reifen +0,8 dB bei 130 km/h → Reifen ≈ Motor; Wummern −9,7, Betonfuge −8,8, Plattenschleife −3,7 dB | gemessen (Aufnahme) + Modell (abgeleitet) | Entscheidung AU-E/Leitung: Mischung für kleine Lautsprecher (2.5); für AU-C1: `sfx_modern.py` `joint_hit()` einen Klack bei 300–1500 Hz, `slab_loop()` den „tack“ +4 dB |
| B7 | mittel | Pegel: schwerer Aufprall und Höchsttempo über −1 dBTP bei Gesamtlautstärke 1,0 | gemessen | Leitung: Begrenzer auf `MMaster`, Obergrenze −2,0 dB (2.6); AU-C1: `impact.collision.heavy.layers` je −2 dB oder `impact.collision.max_db` 4 → 2 |
| B8 | mittel | Glas: klingende Sinustöne (3,0/3,2/4,0/5,8/8,8 kHz, +21…+27 dB), eine Variante, in jedem schweren Aufprall | gemessen | `sfx_modern.py` `glass()`: statt `decay_sine` dichte Rauschkörner (0,2–1 ms, 2–10 kHz) mit abnehmender Dichte (Sicherheitsglas zerfällt in Krümel), ≥ 4 Varianten; `impact_audio.gd`: Glas erst ab ~80 km/h oder mit Wahrscheinlichkeit 0,4 |
| B9 | mittel | Quietschen = ein Ton 812 Hz ± 1 % mit 2 Obertönen | gemessen | `vehicle_loops.py` `squeal()`: 2–3 Stimmen (z. B. 0,78 / 0,95 / 1,21 kHz) mit eigenem schnellem Zittern (±4 %), nicht harmonische Teiltöne, Amplituden zufällig moduliert, Haft-Gleit-Stöße |
| B10 | niedrig-mittel | Leitplanke und Lkw-Schlag klingen wie Glocke/Gong (reine Sinus, τ bis 0,6 s; 207 Hz mit 58 dB Überhöhung) | gemessen | `sfx_modern.py` `rail_hit()` τ ×0,3, Moden als schmale Rauschbänder; `truck_boom()` τ ×0,5 |
| B11 | niedrig | Reifenhohlraum-Resonanz (218 Hz) wandert mit der Tonhöhe (171 Hz bei 60, 281 Hz bei 250 km/h) | abgeleitet, Literatur (fest, ~190–250 Hz) | `vehicle_loops.py` `tyre_asphalt()` Spitze 7 → 3 dB, oder eigene Ebene mit Tonhöhe 1 |
| B12 | niedrig | Wind: Tunnel −3 dB (Eigenwind bleibt im Tunnel gleich); Wind erst ab 0,91 × Höchsttempo lauter als die Reifen, bei 130 km/h 16–20 dB unter dem Motor und in allen Bändern über 100 Hz verdeckt | gemessen (Bänder), abgeleitet (Gesetz) | `road.wind.zone_db.tunnel` −3 → 0 (Böen bleiben 0); wer mehr Fahrtwind will: `road.wind.slope_db` 55 → 45 (+2,8 dB bei 130 km/h, Höchsttempo gleich) |
| B13 | niedrig | Rüttelstreifen 1 s beim Einfädeln in die Tankspur (km 13,81) | gemessen | `audio_feed.gd` `wheel_surface()`: rechts kein „rumble“, solange `seg.fuel_lane > 0` |
| B14 | niedrig | Schnee nutzt die Schotter-Schleife mit metallischen Steinschlägen (2,1–5,6 kHz) | abgeleitet aus Code + Datei | eigene Schnee-Schleife oder Schotter ohne „pings“ (`tyre_gravel()` Parameter) |
| B15 | niedrig | Gleichförmigkeit über Stunden: Vorbeifahrten streng a/b im Wechsel; Glas, Kleinteile, Lkw-Schlag je nur eine Variante | abgeleitet aus Code/Manifest | `road_audio.gd` `_pass()` und `impact_audio.gd` `_layer()`: Variante zufällig (nicht reihum), je Schicht ±2 dB und ±10 ms; mehr Varianten |

Nicht beanstandet (gemessen): Nähte, Fortsetzungsframes, Kanalkorrelation der geschwenkten Paare ohne Kammfilter in
Mono, Rüttelstreifen-Physik, Feed-Zonen, Tunnel- und Brückengrenzen, Rechenzeit, Arcade-Unberührtheit – siehe 2.7.

---

## 2. Messungen im Einzelnen

### 2.1 Aufbau

| Lauf | Werkzeug (Arbeitsordner) | Inhalt |
|---|---|---|
| Konstantfahrt | `const_capture.gd` | Limousine, Kiel – Hamburg (echte Strecke, echter Feed), 15 Abschnitte à 10–20 s, Master nach dem Begrenzer, Gruppen stumm geschaltet je Abschnitt; Gas 0,35 (130 km/h), 0,6 (200), 1,0 (Höchsttempo 245) |
| Auslösung | `trigger_log.gd` | Etappe mit Autopilot, ohne Bildschirm, Profil Modern, Zeitraffer 8; je Sekunde Feed-Zustand + Wahrheit aus `Track`/Plan, jedes Feed-Ereignis |
| Aufprall | `impact_check.gd` | 7 Kollisionen + 2 Leitplankenschläge im laufenden Profil, vor dem Begrenzer (`AudioEffectCapture` an Index 0) und dahinter |
| Dateien | `ana_assets.py`, `ana_impacts.py` | alle 17 Schleifen und 17 Einmalklänge von AU-C1; Stapel der Aufprall-Schichten nach Konfiguration |
| Hash | `hash_check.gd` | `AudioFeed.unit_hash` in der Engine (gleich Python-djb2: `"hamburg|0".hash()` = 2101806231) |
| Rechenzeit | `perf_auc1.gd` (Kopie von AU-C1 `perf.gd`) | 900 Bilder, Wiedergabe an |

Wichtig für die Lesart: Die Motorlautheit bei 130 km/h hängt stark am Gas: mit Gas 0,35 gemessen **−17,1 LUFS**, AU-B
maß mit Gas 0,22 −21,6 LUFS. Die Fahrbahn hängt nicht am Gas. Das Verhältnis Reifen : Motor bei 130 km/h liegt also je
nach Fahrweise bei −12,6 dB (hier) bis etwa −8 dB (AU-B-Reisetempo).

### 2.2 Plausibilität je Schicht

Spektren: Abb. 1 (Spielmix 130 km/h), Abb. 6 (Beläge, wie die Laufzeit sie spielt), Abb. 5 (Aufprall).

| Schicht | gemessen (Datei / Spiel) | Physik der echten Quelle (Literatur) | Urteil |
|---|---|---|---|
| Asphalt | Buckel 0,6–1,6 kHz (Schwerpunkt 1,1 kHz), Neigung −0,6 dB/Okt., 4 % Energie < 180 Hz; Hüllkurve fast stationär (Schwankung cv 0,19 bei 10 ms, nur 10 % langsame AM); im Spiel −29,7 LUFS bei 130 km/h | Reifen-Fahrbahn-Geräusch: breites Maximum 0,8–1,25 kHz, Anstieg 30–40 dB je Dekade (Gesetz: 30), Pegel schwankt mit Textur und Flicken um 1–3 dB auf 1–10 m | Hauptband und Anstieg plausibel; **zu gleichmäßig** (gefiltertes Dauerrauschen) – langsame zufällige Pegel- und Klangfarbenschwankung fehlt (B1). Hohlraumton wandert mit dem Tempo (B11) |
| Beton | heller (Schwerpunkt 1,6 kHz), +2,5 dB, 1,15-kHz-Singen (+6 dB, nicht tonal auffällig); mit Platten im Spiel −24,3 LUFS (+5,4 dB zu Asphalt), True Peak −5,7 statt −10,3 dBTP im Spielmix | Waschbeton etwa so laut wie Asphalt (RLS-90: beide −2 dB(A) gegen Gussasphalt); Fugenschlag bei verdübelten Fugen dezent, bei alten Decken deutlich; Plattenlänge typ. 5 m (ZTV Beton) | Plattenlänge und Achstakt richtig; Schläge **zu dominant** und mit Muster (B4) |
| Stahldeck | Dröhnen 68/104 Hz + Metall-Teiltöne 410/655/1180 Hz; 25 % < 180 Hz | orthotrope Platte: hohles Dröhnen, Eigenfrequenzen fest | plausibel; Teiltöne wandern mit der Tonhöhe (klein) |
| Pflaster | Schlagfolge v / 11,5 cm (121/s je Rad bei 50 km/h), Schlag 180–260 Hz + Klick, Karosserie 25–90 Hz; Schleife 2,5 s; im Spiel −22,9 LUFS bei 50 km/h, Wiederholung 1,25 s (Korrelation 0,98 im Band 2,5–8 kHz) | Rate = Tempo / Steinlänge stimmt; Pflaster in der Vorbeifahrt +3…+6 dB(A) (RLS-90), im Auto stärker tieffrequent | Mechanik gut, **Pegel zu hoch** (B3), Wiederholung deutlich (B1) |
| Rüttelstreifen | Grundton 100 Hz bei Tonhöhe 1 (108 km/h, 30 cm), Obertöne 201/300/400 Hz (+24…+12 dB); im Spiel 120 Hz bei 130 km/h, Fahrbahn +8,9 dB, Mix +1,1 dB | f = v / Rillenabstand; Innenraum +10–15 dB(A) | **richtig** (Grundton um 100–120 Hz bei Autobahntempo) |
| Bankett (Schotter) | Knirschen 1,1–7,5 kHz, Grollen 20–95 Hz, 9 Steinschläge/s; +14 dB; sehr hell (Abb. 6) | Schotter: lautes Prasseln, Steinschlag im Radhaus | plausibel; 2,5-s-Schleife mit 22 erkennbaren „pings“ wiederholt sich (B1) |
| Gras | Rauschen + 5,5 dumpfe Schläge/s (32–58 Hz) + Grollen; 79 % < 180 Hz; +14 dB | weicher Grund: Rollgeräusch *leiser*, dafür Stöße und Bewuchs | als Spielsignal in Ordnung; Schläge auf kleinen Lautsprechern weg (−2,7 dB) |
| Nässe | Sprühzischen 0,9–7 kHz (Schwerpunkt 4 kHz) +6 dB, 40 dB/Dekade | nass +5…+15 dB über 1 kHz | plausibel |
| Schnee | Schotter-Schleife × 0,35, −3 dB, Tiefpass 3 kHz | Schnee dämpft, knirscht; keine Steine | Steinschläge unpassend (B14) |
| Quietschen | ein Ton 803–821 Hz, Überhöhung 26 dB, 2 Obertöne, langsames ±3 %- und schnelles ±1,2 %-Zittern | Haft-Gleit-Schwingung mehrerer Profilblöcke und Reifen: mehrere unharmonische, springende Teiltöne, 0,6–2 kHz | **künstlich wahrscheinlich** (B9) |
| Radieren | Rauschen 0,3–3,5 kHz mit Körnung (70/s) | breitbandig | plausibel |
| Wind | drei Bänder (22–190 Hz / 0,24–1,9 kHz / 2,3–8,5 kHz + Pfeifton 3,15 kHz), Böen ±1,5 dB, 55 dB/Dekade | Strömungsgeräusch ~v⁶ (≈ 60 dB/Dekade), Spektrum wandert ∝ v | Gesetz plausibel; bei 130 km/h in allen Bändern über 100 Hz 3–27 dB unter dem Rest, also verdeckt (gemessen, B12) |
| Wummern | 28–120 Hz, AM 4–9 Hz, 92 % < 180 Hz, ab 0,82 × vmax | offenes Fenster: Helmholtz-Wummern 15–25 Hz bei 40–80 km/h | Stilmittel, physikalisch eher Fenster offen bei Stadttempo; auf kleinen Lautsprechern weg (−9,7 dB) |
| Brückenfugen | Doppelschlag mit Achsabstand/Tempo (Variante + Tonhöhe), Beton 89 % < 100 Hz, Stahl mit Klingeltönen 519–2191 Hz (+18…+28 dB) | Fugen an den Widerlagern; Fingerfuge klappert; Zwischenfugen nur bei Einfeldträger-Viadukten (20–40 m) | Schlag gut, **Ort/Abstand** falsch für Stahl und Stein (B5); Betonfuge auf kleinen Lautsprechern weg |
| Vorbeifahrten | Rauschschwall 0,18–0,6 s, Pegel nach Größe und Abstand; im Spiel meist 15–25 dB unter dem Auto (abgeleitet aus Gesetz und gemessenen Abständen: Median 7,5–12,7 m) | Reflexion des eigenen Klangs (Kammfilter-Wischer), Dauer ≈ 2·Abstand/Tempo | Größenordnung plausibel, leise; Dauer wächst nicht mit dem Abstand (klein) |
| Aufprall | Schichten nach Schließgeschwindigkeit und Partner, Versatz 4/9/40 ms; schwer: 32 % Energie < 100 Hz | Aufprall: Knall, Blech, Kunststoff; Seitenglas (ESG) zerfällt in Krümel (Rieseln), Frontscheibe (VSG) reißt | Schichtung gut; **Glas** und **Leitplanke** zu tonal (B8, B10) |

### 2.3 Wiederholung bei konstantem Tempo

![Abb. 2](abb2_wiederholung_autokorrelation.png)

*Abb. 2 – Autokorrelation der Hüllkurve im Band 0,6–1,6 kHz (Monosumme), 20 s Spielmix je Kurve (gemessen). Die
Spitzen bei 0,97 / 1,95 / 2,92 / 3,89 s sind die Asphalt-Schleife; Pflaster (Gelb) wiederholt sich alle 1,25 s.*

Mechanik (abgeleitet aus `road_audio.gd`, `Layer`): Jede Belagebene (und Nässe und die vier Windebenen) hat zwei
`AudioStreamPlayer2D` mit **derselben Monoschleife**, gestartet bei Anteil 0 und 0,5 der Länge, mit derselben Tonhöhe.
Links ≈ 1,33·x(t) + 0,49·x(t + L/2), rechts umgekehrt. Folge: Kanalkorrelation 0,65 (Reifen, gemessen 0,65) bzw. 0,45
(Wind, gemessen 0,45) – und die Summe x(t) + x(t + L/2) ist **exakt periodisch mit L/2** (aus den Dateien: Korrelation
1,00 für alle sieben Paare).

| Messung (gemessen, Spielmix) | Lag | Korrelation |
|---|---|---|
| Asphalt, nur Fahrbahn, 130 km/h, Monosumme, 0,6–1,6 kHz | 0,97 s (L/2) / 3,89 s (2 L) | 0,81 / 0,98 |
| Asphalt, **ganzer Mix**, 130 km/h, Monosumme, 0,6–1,6 kHz | 0,97 s / 3,89 s | **0,64** / 0,76 |
| Asphalt, ganzer Mix, je Kanal (Kopfhörer), 0,6–1,6 kHz | 1,95 s (L) bzw. 3,89 s | 0,78 / 0,76 |
| Motor allein, 130 km/h, 0,6–1,6 kHz (Vergleich) | beliebig | ≤ 0,14 |
| Beton, ganzer Mix, 2,5–8 kHz | 0,97 s | 0,89 |
| Beton, nur Fahrbahn, Hüllkurve breitbandig | 1,11 s (8 Platten = 40 m) | 0,86 |
| Pflaster 50 km/h, ganzer Mix, 2,5–8 kHz | 1,25 s (L/2) | 0,98 |
| Asphalt, ganzer Mix, 200 km/h, je Kanal | 1,67 s (L) | 0,54–0,56 |
| Wind allein, 130 km/h (Böen dämpfen die Wiederholung) | 1,06 / 2,13 s | 0,48 / 0,57 |

Hörbarkeit (abgeleitet): Das Rollgeräusch liegt in den kritischen Bändern 400 Hz–2,3 kHz 6–10 dB über allem anderen
(Tab. 2.5), ist also nicht verdeckt. Wiederholtes Rauschen mit 0,5–2 s Periode erkennen aufmerksame Hörer zuverlässig
(Literatur: Guttman & Julesz 1963; Kaernbach 2004; Agus et al. 2010 – bei Wiederholung über Minuten auch längere
Perioden). Am wahrscheinlichsten hörbar: Pflaster (Ereignisse, 1,25 s), Asphalt und Beton auf Lautsprechern (0,97 s),
Plattenmuster (1,11 s). Am wenigsten: Wind (Böen).

Was die Wiederholung verdeckt (Vorschlag, nach Aufwand):
1. **Sofort, ohne neue Dateien** (`road_audio.gd`): den zweiten Spieler mit Tonhöhe × 1,023 laufen lassen (der Versatz
   wandert in 2 / 0,023 ≈ 87 s einmal durch die Schleife; die Summe ist nicht mehr periodisch) und je Seite eine langsame
   Pegelschwankung (Ornstein-Uhlenbeck wie `_gust`, ±1,5 dB, τ 0,8 s). Beseitigt die L/2-Periode der Summe, nicht die
   L-Periode je Kanal.
2. **Mit neuen Dateien** (`vehicle_loops.py`): je Seite eine eigene Schleife (anderer Seed) mit teilerfremden Längen,
   z. B. 5,3 s und 7,1 s (gemeinsame Periode > 37 s). Größe als WAV ~0,47 + 0,63 MB je Belag – für Asphalt, Beton, Nässe
   und Wind-mittel/hoch zusammen ~5,5 MB, mehr als das freie Budget (5,1 MB, mit AU-C2 geteilt). Daher Rauschschleifen als
   **Ogg Vorbis q4** (wie Ambiente; ~10-fach kleiner); Vertrag §4.7.3 nennt WAV nur für *tonale* Schleifen.
3. Für Ereignis-Texturen (Pflaster, Bankett, Gras, Platten): granular abspielen – alle 0,3–0,7 s an eine zufällige
   Stelle der Schleife springen (zwei Spieler, 30 ms Überblendung), oder Ereignisse aus dem Feed erzeugen.

### 2.4 Auslösung im Spiel

Vier Etappen mit Autopilot, Zeitraffer 8, je Sekunde Feed gegen Wahrheit (gemessen, `logs/trig_*.log`):

| Etappe | Abschnitt | Zeilen | Befund |
|---|---|---|---|
| Kiel – Hamburg | ganz (95 km, 316 s, Ø 108 km/h) | 316 | Beton km 0,04–12,3 und 40,4–60,5 (68 s = 37 % der Autobahnzeit); City Limits ab 75,3; Stahldeck 78,1–80,7 und 84,2–86,1; **Pflaster 87,1–94,9 (39 s, 97 % der Innenstadt)**; Fugen 12 auf der Köhlbrandbrücke (261 m) und 9 auf den Elbbrücken (201 m), je an Anfang/Ende und alle 24 m; Rüttelstreifen nur 1 s an der Tankspur (km 13,81); keine Fuge abseits einer Brücke |
| Mailand – Venedig | km 220–275 | 204 | Damm (causeway, 378 m) 17 Betonfugen; Venedig nie Pflaster (Hash); Zonen richtig |
| Lüttich – Paris | km 340–395 | 194 | Tunnel 385,0–386,3 richtig; Steinbogenbrücke (129 m): Pflaster richtig, aber **6 Betonfugen**; Paris nie Pflaster (Hash); Wald-Zone in `forest_hills` |
| Bern – Mailand | km 95–215 | 311 | drei Tunnel genau (106,0/107,5, 130,0/139,3, 185,0/201,9); Zone `valley` in den Alpen; `cutting` 2 Zeilen (Felsen beidseitig); 2 Leitpfosten (Landstraße fast nur im Tunnel); Beton 26 Zeilen (CH) |

Geprüft und richtig (gemessen): Tunnel-, Brücken- und Dach-Ereignisse an den Grenzen der Daten; Fugen nur auf Brücken,
die Endfugen genau bei z0/z1; Pflaster nur in Innenstadt-Blöcken und auf Steinbrücken; Rüttelstreifen nur auf
`autobahn` (City Limits sind `road = "city"`); Beton nur auf Autobahnabschnitten; kein Tunnel/Einschnitt ohne Daten.
Die Zeilen hinken dem Feed um ein Bild nach (Lesereihenfolge), daher je eine Zeile „Mismatch“ an jeder Grenze.

**Pflaster-Hash (Fehler, gemessen).** `unit_hash(key) = (key.hash() & 0xFFFFFF) / 2^24`; `String.hash()` ist djb2
(geprüft: Engine = Python). Im Schlüssel `"<ziel>|<block>"` ändert sich nur das letzte Zeichen – der Hash ändert sich
um wenige Einheiten, die Entscheidung `< cobble_share` ist für alle Blöcke einer Stadt gleich:

| Zielstädte mit Pflaster-Stil | immer Pflaster (Blöcke 0–11) | nie | gemischt (erst ab Block 10) | erwartet bei p = 0,6 und ~9 Blöcken |
|---|---|---|---|---|
| 43 | **20** (u. a. Hamburg, Würzburg, Nürnberg, Wien, Prag, Madrid, Tours) | **9** (u. a. Paris, Lüttich, Budapest, Warschau) | 14 | „immer“ 1 %, „nie“ 0,03 % je Stadt |

Beton (Schlüssel ändert sich in der Mitte, besser gemischt): wirksamer Anteil DE 0,42 (eingestellt 0,35), BE 0,47
(0,30), PL 0,36 (0,25), AT 0,21 (0,15) – im Rahmen der Stichprobe, aber nach der Hash-Korrektur neu würfeln.

**Brückenfugen (Physik).** Der Feed setzt Fugen alle `joint_every_m` = 24 m (sichtbare Meter) auf *jede* Brücke. Auf
der Köhlbrandbrücke (Schrägseil, Stahl) klappert bei Stadttempo 47 km/h alle 1,8 s eine Fingerfuge, bei 100 km/h alle
0,9 s. Durchlaufträger aus Stahl haben Dehnfugen nur an den Enden; Mauerwerksbögen gar keine; Zwischenfugen alle
20–40 m gibt es bei alten Betonviadukten aus Einfeldträgern (Literatur). Vorschlag `joint_every_m` je Deck:
Stahl 0 (nur Enden), Stein −1 (keine), Beton 32 m.

**Tankspur.** Beim Einfädeln in die Tankspur verbreitert sich der befestigte Rand; das rechte Rad liegt 1 s in der
„rumble“-Zone (km 13,81). Echte Ausfahrten haben dort eine unterbrochene Linie ohne Profil (B13).

**Bankett auf der Autobahn.** Der Standstreifen ist im Arcade-Bild asphaltgrau (`SHOULDER_PAVED`), die Physik behandelt
ihn als Bankett (Haftung 0,51, max. 90 km/h). Der Klang folgt der Physik (Schotter). Kein AU-C1-Fehler; R1/Leitung
sollten wissen, dass Bild und Klang dort auseinandergehen.

### 2.5 Kleine Lautsprecher und Mono

![Abb. 1](abb1_spielmix_130_terzen.png)

*Abb. 1 – Spielmix bei 130 km/h, Schicht für Schicht (gemessen). Der Motor sitzt fast ganz im 125-Hz-Terzband
(Zündfrequenz); über 400 Hz bestimmt das Rollgeräusch das Spektrum.*

Kritische Bänder bei 130 km/h (gemessen; Pegel der Schicht gegen die Summe der anderen):

| Band | Motor | Reifen | Wind | Reifen/Rest | Wind/Rest |
|---|---|---|---|---|---|
| 20–100 Hz | −46,1 | −51,0 | −42,7 dBFS | −10,0 | +2,2 |
| 100–200 Hz | −18,9 | −48,4 | −45,7 | −29,6 | −26,9 |
| 300–400 Hz | −49,4 | −46,9 | −53,5 | +1,0 | −8,5 |
| 630–920 Hz | −54,2…−52,3 | −43,3…−42,5 | −54,6…−55,2 | **+8,0…+8,1** | −11,6…−13,2 |
| 1,08–1,48 kHz | −54,8…−57,4 | −42,6…−43,9 | −55,7…−56,1 | **+9,6…+9,7** | −12,3…−13,3 |
| 2,32–3,15 kHz | −57,8…−58,1 | −50,0…−51,5 | −59,3…−59,1 | +5,5…+4,1 | −9,9…−8,5 |
| 5,3–7,7 kHz | −63,3…−64,1 | −56,9…−58,7 | −61,0…−61,9 | +2,1…+1,1 | −5,0…−4,3 |

Bei 200 km/h liegen Reifen + Wind in fast allen Bändern über 300 Hz 10–18 dB über dem Motor (gemessen).

![Abb. 3](abb3_kleinlautsprecher_pegelverlust.png)

*Abb. 3 – Lautheitsänderung durch einen 180-Hz-Hochpass (4. Ordnung) und durch ein Kleinlautsprecher-Modell
(Hochpass 200 Hz 4. Ordnung, +3 dB bei 3 kHz, Tiefpass 14 kHz – abgeleitet, kein gemessenes Steam Deck).*

| Frage | Ergebnis |
|---|---|
| Bleibt die Fahrbahn hörbar? | Ja: das Rollgeräusch verliert nichts (−0,1 / +0,8 dB), der Motor bei 130 km/h −9,9 / **−11,6 dB**, bei 200 km/h −5,6 / −7,6 dB. Auf kleinen Lautsprechern wären Reifen und Motor bei 130 km/h etwa gleich laut, bei 200 km/h Reifen + Wind ~6 dB lauter (abgeleitet) |
| Verschwindet der Rüttelstreifen? | Nein: Grundton 120 Hz −17,6 dB, 2. und 4. Oberton (240/480 Hz) bleiben (−0,9/+0,1 dB); gesamt −3,8 LU. Über den fehlenden Grundton wird die Tonhöhe weiter gehört (Literatur), das „Gewicht“ fehlt (Abb. 4) |
| Wird der Wind zu Zischen? | Ja, teilweise: das tiefe Band (78 % < 180 Hz) und das Wummern (92 %) fallen weg; übrig bleiben Rauschen und Zischen. Lautheit −1,3…−2,1 dB, die Klangfarbe kippt nach oben |
| Was verschwindet? | Wummern −9,7 dB, Betonfuge −8,8 dB (89 % < 100 Hz), Plattenschleife −3,7 dB (86 % < 180 Hz), Lkw-Schlag −1,9 dB (62 % < 100 Hz). Schwerer Aufprall: Lautheit nur −0,8 LU, aber der Schlag (52–60 Hz) fehlt |
| Mono | Kein Kammfilter (die Paare sind bei kurzen Versätzen unkorreliert). Monosumme gegen Stereo: Reifen −0,8 dB, Wind −1,4 dB, Mix −0,1 dB (gemessen). Schwenkgesetz: Mitte = gewöhnlicher Player (0 dB), Schwenk 0,7 → lauter Kanal +2,8 dB, leiser −9,6 dB; in Mono verliert ein Klang bei Schwenk 0,7 1,4 dB, ganz außen 3 dB (abgeleitet) |

![Abb. 4](abb4_ruettelstreifen_kleinlautsprecher.png)

*Abb. 4 – Rüttelstreifen bei 130 km/h (nur Fahrbahn, gemessen) und dasselbe durch das Kleinlautsprecher-Modell.*

### 2.6 Pegel und Sicherheit

Spielmix (gemessen, Limousine, Gesamtlautstärke 0,8; True Peak bei 1,0 = Wert + 1,94 dB, weil der Begrenzer vor der
Lautstärke sitzt):

| Zustand | LUFS | Kurzzeit max | True Peak bei 0,8 | bei 1,0 |
|---|---|---|---|---|
| 130 km/h Asphalt (Gas 0,35) | −17,2 | −16,7 | −10,3 | −8,4 |
| 130 km/h Beton | −16,6 | −15,8 | −5,7 | −3,8 |
| 130 km/h Rüttelstreifen | −16,1 | −15,9 | −6,4 | −4,5 |
| 200 km/h | −17,8 | −17,5 | −8,6 | −6,7 |
| Höchsttempo 245 km/h | **−14,9** | −14,6 | **−2,8** | **−0,9** |
| Höchsttempo, Motor allein | −17,1 | −16,5 | −12,0 | −10,1 |
| Pflaster 50 km/h | −19,0 | −18,7 | −7,7 | −5,8 |

Aufprall im laufenden Profil (gemessen, nur `MImpact` hörbar, lauterer Kanal, `impact_check.gd`):

| Ereignis | vor dem Begrenzer, bei 0,8 | True Peak danach | bei 1,0: Spitze / True Peak |
|---|---|---|---|
| Rempler 6 km/h | −11,2 dBFS | −10,7 | −9,2 / −8,8 |
| Auffahren 30 km/h (mittig) | −7,8 | −7,7 | −5,8 / −5,8 |
| schwer 70 km/h | −3,8 | −3,7 | −1,9 / −1,8 |
| **schwer 130 km/h** | **−2,8** | −2,6 | **−0,9 / −0,7** |
| schwer 130 km/h mittig | −5,3 | −5,2 | −3,4 / −3,2 |
| Lkw 40 km/h | −5,3 | −5,2 | −3,3 / −3,3 |
| Lkw 110 km/h | −3,8 | −3,6 | −1,8 / −1,7 |
| Leitplanke 2 m/s | −8,0 | −8,0 | −6,1 / −6,1 |
| Leitplanke 5 m/s | −5,1 | −5,0 | −3,1 / −3,1 |

Der Begrenzer hat in diesem Lauf keinen Frame berührt (Schwelle −0,8 dBFS vor der Lautstärke). Die Werte bestätigen
die Tabelle von AU-C1 auf ±0,6 dB. **Streuung:** Derselbe Stapel aus den Dateien mit allen Tonhöhen = 1 (die Laufzeit
würfelt 0,96–1,04 je Schicht) erreicht mittig −2,9 dBFS statt −5,3 (abgeleitet, `ana_impacts.py`) – mit Schwenk bis etwa
−0,1 dBFS bei 0,8, also +1,8 dBFS vor der Lautstärke: Dann arbeitet der Begrenzer ~2,6 dB. Schwere Aufpralle sitzen
damit genau an der Grenze; welche Realisierung kommt, ist Zufall.

**Vorschläge an die Leitung (Arcade und seine Konfiguration bleiben, wie sie sind):**

1. **Eigener Begrenzer für Modern** auf `MMaster` (hinter dem Summenkompressor): `AudioEffectHardLimiter`,
   `ceiling_db` **−2,0**, `release` 0,12 s (wie Arcade), neu in `audio.modern.limiter`. Wirkung (abgeleitet): bei
   Gesamtlautstärke 1,0 Abtastspitzen ≤ −2,0 dBFS, True Peak ≤ −1,3 dBTP (Überschwingen 0,1–0,7 dB, von AU-C1 gemessen) –
   D29 bei jeder Lautstärke. Fahren bei 130–200 km/h bleibt unberührt (−8,4…−3,8 dBTP bei 1,0); Höchsttempo bei 1,0
   ~1 dB auf Spitzen; schwere Aufpralle 1–4 dB. Der geteilte Master-Begrenzer (−0,8) greift für Modern dann nie mehr.
   Datei-Eigner: AU-A/AU-E (`modern_buses.gd`).
2. **Höchsttempo-Zeile von D29:** „Höchsttempo (Motor + Fahrbahn + Wind): −15 ± 1 LUFS“; „Vollgas durch die Gänge
   −16 ± 1,5“ bleibt. Gemessen auf dem Endstand: Limousine −14,9 (Motor allein −17,1, Summe +2,2 dB). Plan „Wind −3,
   Reifen −4 unter dem Motor“ und −16 gehen nur zusammen, wenn die Motoren bei Höchsttempo ~1,5 dB leiser werden. Wenn
   der Nutzer Höchsttempo heute als zu laut oder ermüdend empfindet: `road.wind.under_engine_db` 3 → 6 und
   `road.tyres.under_engine_db` 4 → 6 senken die Summe um 1,0 dB (abgeleitet; je dB Wind −0,24, je dB Reifen −0,19 dB).
3. **Aufprall schwer −2 dB** (`impact.collision.heavy.layers` je −2 oder `impact.collision.max_db` 4 → 2): ein einzelner
   schwerer Aufprall bei 1,0 dann ~−2,7 dBTP statt −0,7 (abgeleitet) – auch ohne Begrenzer D29-fest.
4. **Verkehr und Martinshorn** (Platzhalter, AU-C2): Im schlimmsten Fall von AU-C1 liegt die Summe vor dem Begrenzer bei
   +3,6 dBFS (bei 0,8, also +5,5 dBFS vor der Lautstärke); der heutige Begrenzer nimmt dort 6,3 dB weg, ein −2-dB-Begrenzer
   nähme 7,5 dB (abgeleitet, Pumpen). AU-C2 muss die Platzhalter-Pegel um ~4 dB senken (ohne `MWorld` blieben +0,8 dBFS),
   am besten bevor der Begrenzer kommt.

### 2.7 Rechenzeit und Hygiene

| Prüfung | Ergebnis |
|---|---|
| GDScript je Bild (Wiedergabe an, Regen, Querbewegung, Leitplanke) | Feed 0,054 ms (p95 0,076, max 0,45), `road` 0,137 ms (p95 0,19, max 1,0), `impact` 0,008 ms – zusammen ~0,2 ms von 16,7 ms (gemessen auf der belasteten VM; Steam Deck abgeleitet ähnlich) |
| Zuweisungen je Bild | `road`: wiederverwendete `PackedFloat32Array` (`_t1`, `_t2`), keine neuen Objekte; Feed: einige Strings je Bild (`str(seg.get("road"))`, Wetter) und je überfahrenem Objekt ein Dictionary – unkritisch (Code gelesen) |
| Spieler | 12 laufende `AudioStreamPlayer2D` für Fahrbahn + Wind bei Regen (gemessen); jede Ebene hält 2 Spieler auch bei Stille gestoppt |
| „leaked at exit“ / „still in use“ | in keinem der 10 Läufe (4 Etappen ohne Wiedergabe, 3 mit Wiedergabe, Hash, Aufzählung, Arcade-Prüfung) |
| Arcade spielt nichts Neues | `check_arcade_lean.gd`: „0 von 35 Skripten des Modern-Klangs, des Modern-Renderers und der Modell-Datenbank geladen“; alle eingefrorenen Dateien (Regel 1) gleich zu Tag v0.7.0 (`git diff v0.7.0 4209268`); Konfiguration nur `audio.profile` und `audio.modern.*` neu |
| Nähte | alle 17 Schleifen: Sprung- und Knickverhältnis < 0,7 (QC-Grenze 2), 16 Fortsetzungsframes = Schleifenanfang |

---

## 3. Stellknöpfe (Daten, `config/game_config.json` → `audio.modern…`)

Pegel in dB wirken 1 : 1 auf die Lautheit der Ebene (gemessen: Asphalt bei 130 km/h −29,7 LUFS, Gesetz −29,95; AU-C1:
±0,1 dB). „Mix“ = Wirkung auf den ganzen Spielmix.

| Knopf | jetzt | Wirkung einer Änderung |
|---|---|---|
| `road.tyres.under_engine_db` | 4 | +1 → alle Beläge −1 dB bei jedem Tempo; Summe bei Höchsttempo −0,19 dB je dB (abgeleitet) |
| `road.wind.under_engine_db` | 3 | +1 → Wind −1 dB; Summe bei Höchsttempo −0,24 dB je dB (abgeleitet); beide auf 6 → Summe −1,0 dB |
| `road.tyres.slope_db` | 30 | Pegel bei v: (30 − s)·log10(vmax/v) dB höher; bei 130 km/h (Limousine) 0,275 dB je dB Steigung |
| `road.wind.slope_db` | 55 | dito; 55 → 45: +2,8 dB Wind bei 130 km/h, Höchsttempo gleich; Kreuzung Reifen = Wind bei vmax·10^(−1/(55−30)) = 0,91 vmax |
| `road.tyres.surface_db.cobbles` | 19 | 19 → 12: Pflaster −7 dB (bei 50 km/h dann ≈ Asphalt bei 125 km/h). Gemessen jetzt: −22,9 LUFS nur Fahrbahn, Mix −19,0 |
| `road.tyres.surface_db.rumble` | 7 | Streifen gemessen +8,9 dB über Asphalt (eine Seite), Mix +1,1 dB |
| `road.tyres.surface_db.shoulder` / `grass` | 14 / 14 | 1 : 1 |
| `road.slabs.db` | 3 | 3 → −3: Plattenebene −6 dB; Beton-Fahrbahn gesamt von −24,3 auf ~−26,4 LUFS (abgeleitet aus Ebenenanteilen: Platten ≈ Rollen ≈ −27,3 LUFS bei 130 km/h) |
| `road.slabs.crossfade_kmh` | [110, 150] | Bereich, in dem zwei Plattenschleifen (ohne gemeinsamen Takt nach Tempowechsel) zugleich laufen; [125, 135] verkleinert ihn auf ±5 km/h |
| `road.wind.zone_db.tunnel` | −3 | 0 empfohlen (Eigenwind bleibt; Hall von `env` kommt dazu) |
| `road.wind.buffet_from` | 0,82 | Wummern ab 82 % vmax; auf kleinen Lautsprechern unhörbar (−9,7 dB) |
| `road.wind.gust_db` | 1,5 | Böen-Streuung; dämpft die Wiederholung des Winds (Korrelation 0,48 statt ~1) |
| `road.joints.lufs` / `steel_db` / `end_db` | −29 / 1,5 / 1,0 | 1 : 1 je Fuge (Momentanlautheit) |
| `feed.joint_every_m` | 24 | Fugenabstand auf **jeder** Brücke; 0 = nur Enden (Vorschlag: je Deck, B5) |
| `feed.cobble_share` | 0,6 | wirkt erst nach der Hash-Korrektur (B2); vorher je Stadt 0 oder 1 |
| `feed.cobble_block_m` | 90 | Blocklänge (sichtbare m) |
| `feed.concrete_share.DE` | 0,35 | wirksam 0,42 (Hash); Beton = Plattenrhythmus |
| `feed.rumble_in_m` / `rumble_out_m` | 0,3 / 0,5 | Breite der Rüttelzone um den Rand: 0,8 m |
| `road.passes.lufs` / `floor_lufs` | −31 / −58 | Vorbeifahrten bei 3 m, Größe 1, 100 km/h; im Spiel meist 15–25 dB unter dem Auto |
| `impact.collision.<stufe>.layers.<id>` | s. Konfig. | Abtastspitze der Schicht am Master (mittig); Schwenk 0,7 addiert +2,8 dB auf dem lauten Kanal |
| `impact.collision.max_db` / `slope_db` | 4 / 10 | schwer 130 km/h: +2,7 dB über der Bezugsstufe (70 km/h) |
| `impact.pan` | 0,7 | lauter Kanal +2,8 dB; 0,5 → +2,3 dB (abgeleitet) |
| `impact.rail.hit_peak_db` | −9 | Leitplanke 5 m/s gemessen −5,1 dBFS |
| `snapshots.impact.gain_db` | Musik −5, Ambiente −3, Auto −3, Welt −4 | Kopfraum beim Aufprall |

Generator-Knöpfe (Klangfarbe, `vehicle_loops.py` / `sfx_modern.py`): Schleifenlänge (Sekunden in `loops()`),
`tyre_asphalt` Hohlraumspitze (`peak(f, 218, 9, 7)`), Modulation (`0.10 * slow(...)`), `squeal(n, 820)`,
`glass()` Klingeltöne, `W_BEAM` τ, `slab_loop` Akzent-Streuung (`rng.normal(0, 2.2)` dB je Platte).

---

## 4. Was ein Mensch beurteilen muss (heute Abend, Kopfhörer)

1. Asphalt bei konstant 130 km/h, 20 s: Hört man ein „Pumpen“ im Sekundentakt? (Erwartung nach Messung: eher ja,
   auf Lautsprechern deutlicher.)
2. Ende von Kiel – Hamburg: Ist Pflaster bei 50 km/h zu laut, zu gleichmäßig, wiederholt es sich (1,25 s)?
3. Asphalt → Beton bei 170 km/h: Wird der Plattentakt als Rhythmus gehört, nervt er nach 30 s?
4. Köhlbrandbrücke: Wirkt ein Klappern alle 1,8 s glaubhaft oder zu viel?
5. Schwerer Aufprall: Klingt das Glas nach Weinglas? Ist der Aufprall ohne Bass (Steam-Deck-Lautsprecher) noch „schwer“?
6. Untersteuern: Klingt das Quietschen nach Reifen oder nach Pfeifen?
7. Steam Deck ohne Kopfhörer: Sind Motor und Reifen bei 130 km/h noch im richtigen Verhältnis?

---

## 5. Hinweise an die Leitung und andere Pakete

- **Vertrag D29 / Abnahme AU-C1** „schlimmster Fall ≤ −0,5 dBTP“ wurde nur bei Gesamtlautstärke 0,8 geprüft; D29 sagt
  ≤ −1 dBTP ohne Lautstärke-Bedingung. Bei 1,0 gemessen: ein schwerer Aufprall −0,7 dBTP, Dauerfahrt Höchsttempo
  −0,9 dBTP. Vorschlag 2.6.1.
- **Kleine Lautsprecher** (AU-B/AU-E): Der Motor v3 trägt seine Lautheit fast ganz im Zündfrequenz-Band (~120 Hz bei
  130 km/h) und verliert auf kleinen Lautsprechern ~12 dB (Modell). Für das Steam Deck eine Entscheidung nötig: eigene
  Mischung für eingebaute Lautsprecher (z. B. Obertöne des Motors anheben oder Fahrbahn/Wind −4 dB), sonst kippt die
  Balance zu Reifen und Wind.
- **Werkzeug:** `capture_mix.gd` sendet keinen Fahrzeugzustand (AU-C1 Befund 4). `const_capture.gd`, `trigger_log.gd`
  und `impact_check.gd` aus diesem Arbeitsordner sind Kandidaten für `tools/audio/modern/` (Eigner AU-A/AU-E).
- **Bild/Klang Standstreifen:** Arcade zeichnet den rechten Autobahn-Standstreifen asphaltgrau, die Physik ist Bankett
  (Schotter, max. 90 km/h) – der Modern-Renderer (R1) sollte wissen, dass der Klang der Physik folgt.

### Grenzen dieser Prüfung

- Die Konstantfahrten senden den Fahrzeugzustand per Skript über die echte Strecke (wie AU-C1s Hörproben), nicht aus
  der laufenden Rennsitzung; die Auslösung wurde dagegen in der echten Rennsitzung (Autopilot) geprüft, ohne Wiedergabe.
- Rüttelstreifen, Bankett und Leitplanke hat der Autopilot kaum berührt; ihre Auslösung ist aus dem Code und aus
  AU-C1s Tests belegt, nicht aus einer Fahrt.
- Das Kleinlautsprecher-Modell ist eine Annahme (kein gemessenes Steam Deck). Godots Mischung wurde mit dem
  Dummy-Treiber aufgenommen; eine echte Soundkarte ist nicht geprüft.
- Leck-Meldungen beim Beenden: geprüft in Modern-Läufen mit und ohne Wiedergabe; Arcade nur über `check_arcade_lean`
  (Laden), nicht mit laufender Arcade-Wiedergabe beim Beenden.

---

## 6. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-FAHRBAHN/`:
`const_capture.gd`, `trigger_log.gd`, `impact_check.gd`, `hash_check.gd`, `enum_stages.gd`, `perf_auc1.gd`,
`dsp.py`, `plotlib.py`, `ana_assets.py`, `ana_capture.py`, `ana_impacts.py`, `ana_trigger.py`, `make_figs.py`;
Ergebnisse `results/*.json`, Protokolle `logs/*.log|txt` (u. a. `trig_kiel_hamburg.log`, `ana_capture.txt`,
`ana_assets.txt`, `ana_impact_check.txt`, `hash_check.log`). Die Aufnahmen `cap/*.wav` (Spielmix) sind gelöscht, sobald
der Bericht steht (Platz).

Abbildungen in diesem Ordner: `abb1_spielmix_130_terzen.png`, `abb2_wiederholung_autokorrelation.png`,
`abb3_kleinlautsprecher_pegelverlust.png`, `abb4_ruettelstreifen_kleinlautsprecher.png`, `abb5_aufprall_terzen.png`,
`abb6_belaege_terzen.png`.

![Abb. 5](abb5_aufprall_terzen.png)

*Abb. 5 – Aufprall-Schichten, wie die Laufzeit sie stapelt (abgeleitet aus Dateien + Konfiguration). Über 4 kHz ist der
schwere Aufprall fast nur Glas.*

![Abb. 6](abb6_belaege_terzen.png)

*Abb. 6 – Rollgeräusch je Belag mit Tonhöhe und Pegel der Laufzeit (abgeleitet). Pflaster bei 50 km/h liegt 19 dB über
Asphalt bei 50 km/h.*
