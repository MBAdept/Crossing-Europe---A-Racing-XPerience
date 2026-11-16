# KRITIK-R2-CODE – Abnahmeprüfung des Modern-Fahrbahnklangs: Code, Auslösung, Regressionen

**Prüfgegenstand:** AU-R3-Kopf `b6339ad4` (`origin/wip/v080-au-r3`), Änderung `4209268..b6339ad4` (AU-C1 → AU-R →
AU-R2 → AU-R3) über `scripts/audio/**`, `tools/audio/**`, `config/game_config.json` (`audio.*`),
`tests/unit/audio_modern/**`, `docs/audio-modern.md`.
**Rolle:** unabhängige Abnahme, nur lesend – keine Commits, kein Zweig, kein Arbeitsbaum eines anderen Pakets. Geprüft
in Kopien (`git archive` + `.godot` des Hauptbaums, einmal importiert): `heads/r3` (unverändert, für Gates und Läufe) und
`heads/mut` (für die Mutationsläufe; jede Datei danach zurückgeschrieben). Jeder Lauf mit absolutem `XDG_DATA_HOME`,
`nice -n 19`, ein schwerer Lauf nach dem anderen; die Maschine war von QA1 (A/B-Clip), einem Modellpaket und
KRITIK-R2-MESS belastet.
**Lesart:** *gemessen* = auf dieser VM (Godot 4.7.2, ohne Bildschirm bzw. Xvfb/llvmpipe, Dummy-Audiotreiber). *abgeleitet*
= aus Code oder Rechnung – dazu gehört alles über das Steam Deck, eine echte GPU und wie etwas klingt. Pegel und
Spektren misst KRITIK-R2-MESS; dieser Bericht doppelt das nicht.

---------------------------------------------------------------------------------------------------------------------

## 0. Kurzfassung

1. **Kein Blocker.** Alle Gates grün (gemessen): `tools/run_tests.sh` „656 Tests, 0 fehlgeschlagen“, 83 CHECK-Zeilen OK,
   „Tests bestanden (617 s)“; `check_arcade_lean` OK (0 von 35 Modern-Skripten); `tools/golden.sh check` „GOLDEN
   arcade: 20 von 20 identisch (195 s)“; Regel-1-Dateien `v0.7.0..b6339ad4` unverändert; Motor-v3- und Musikdateien
   bitgleich zu AU-C1; alte Werte von `mischung.json` unverändert; `ERGEBNIS` auf zwei Etappen in drei Modi
   (Bild/Klang Arcade/Arcade, Arcade/Modern, Modern/Modern) gleich; `vehicle_loops.py` und `sfx_modern.py` erzeugen die
   eingecheckten Dateien und Manifest-Einträge bitgleich; Klänge ohne Musik 18,95 von 23 MB.
2. **Auslösung über alle 64 Etappen in beiden Richtungen (128 Pläne, echte `Track`) ohne Fehler** (gemessen):
   Pflaster nur in Altstadtstraßen und auf Steindecks, nie auf Beton- oder Stahldecks, `deck` nur auf Stahl, Beton nur
   auf Autobahnabschnitten außerhalb der Städte; Fugen auf allen 122 Brücken genau nach der Regel je Deck, keine
   abseits einer Brücke; 0 Meter Rüttellinie an 410 Tankspuren; Betonanteil in 13 von 13 beurteilten Ländern (V2) im
   Band, keine Abschnittsentscheidung je Richtung verschieden; Tunnel-Zone und Regen/Schnee ohne Abweichung.
3. **Code ohne Korrektheitsfehler, der hörbar wäre** (gemessen mit Laufzeitproben): Plattenabgleich stellt richtig nach,
   im Pausenmenü verstummen alle Schleifen nach 47 Bildern bei höchstens 2 Sperren des Audioservers, `stop_all` hält
   alles an, kein NaN/INF in 819 Fällen (0 km/h, 400 km/h, alle Beläge, Wetter, Untersteuern), Tonhöhe des Quietschens
   je hörbarem Quietschen konstant, keine Bildratenabhängigkeit bei 30/40/60/90 Bildern je Sekunde (600-s-Läufe), kein
   Leck beim Beenden (Lauf mit echten Spielern unter Xvfb), kein globaler Zufall (das `ERGEBNIS` kann sich nicht ändern).
4. **Hoch – die Tests schützen mehrere neue Regeln nicht** (gemessen, 32 Mutationen, 20 gefangen, 12 nicht): Quietschen
   „je Ereignis“ (neue Tonhöhe in jedem Bild bleibt grün), Aufprall-Varianten „zufällig“ (streng reihum wie bei AU-C1
   bleibt grün), Pegel- und Einsatzzufall je Aufprallschicht (ganz entfernt bleibt grün), Nachstellen der Plattenmuster
   (falsche Schleife oder nie nachstellen bleibt grün). Der Code ist dort heute richtig (Proben) – ungeschützt ist nur
   die nächste Änderung.
5. **Mittel:** Altstadtanteil 0,6 ± 0,05 verfehlt in 10 Altstädten (20 Ankünfte) – alle mit Steinbrücke (9) bzw.
   Tunnel – wie AU-R3 selbst als offen meldet; Barcelona liegt mit 0,549 am Rand. Kiel – Hamburg ist nicht betroffen
   (Hamburg 0,551). Vorbeifahrt-Zufall (±2 dB, Variante) hat keinen Test, obwohl der AU-R-Bericht Tests nennt.
6. **Niedrig:** an der Tankspur spielt ein Rad 0,1–0,45 m **außerhalb** des Außenrands Asphalt statt Bankett;
   drei Doku-Fehler (Plattengesetz „8 statt 20 dB“ – die Konfiguration sagt 4; veraltete Größenzeile; „gestrichelte
   Linie“ an der Tankspur); Tunnelwind-Regel und Glas-Schwelle ungeschützt; toter Code.

---------------------------------------------------------------------------------------------------------------------

## 1. Befunde nach Rang

Schwere nach Auftrag: Blocker = Gate verfehlt, hörbarer Fehler, Arcade oder `ERGEBNIS` gebrochen; hoch = falsche
Auslösung an einer befahrenen Stelle, Leck, Bildratenabhängigkeit oder ein Test, der seine Regel nicht schützt;
mittel/niedrig = der Rest.

### H1 (hoch) – `test_squeal_pitch_per_event` schützt „je Ereignis“ nicht
- **Regel** (AU-R, KRITIK-FAHRBAHN B12; Doku Abschnitt 15.1 und Testtabelle: „Quietschen mit eigener Tonhöhe je
  Ereignis“): die Tonhöhe eines Quietschens wird beim Einsetzen gewürfelt und bleibt dann.
- **Beleg (gemessen):** Mutation M01 in `scripts/audio/modern/road_audio.gd` `_update_squeal()`:
  `if sq > 0.002 and squeal.level < ModernAudioPan.SILENT:` → `if sq > 0.002:` (neue Tonhöhe in jedem Bild – ein
  hörbares Trillern) – `test_road_audio.gd` bleibt grün (`logs/mut_M01.log`). Der Test prüft nur, dass 12 Quietscher am
  Ende 10+ verschiedene Faktoren in ±5 % haben.
- **Code heute richtig:** Probe T5 – 0 Wechsel der Tonhöhe während eines hörbaren Quietschens (10 Quietscher).
- **Korrektur:** im Test innerhalb eines Quietschens `squeal_factor` je Bild aufzeichnen und Gleichheit prüfen, sobald
  `squeal.level >= ModernAudioPan.SILENT` (wie Probe T5 in `tools/kc_probe.gd`).

### H2 (hoch) – `test_collision_variety` schützt „zufällig“ nicht
- **Regel** (AU-R, KRITIK-FAHRBAHN B15; Docstring des Tests: „the variants come at random (never the same one twice in a
  row …)“): Varianten zufällig statt reihum.
- **Beleg (gemessen):** M03 – `RoadAudio.pick_variant()` für n ≥ 3 durch `return (last + 1) % n` ersetzt (genau das
  Reihum von AU-C1) – grün. Geprüft wird nur „alle vier kommen vor“ und „nie zweimal hintereinander“, beides erfüllt
  auch das Reihum.
- **Korrektur:** z. B. 400 Ziehungen mit n = 4: Übergangshäufigkeiten (last → next) müssen mehr als eine Folge je
  `last` zeigen, oder die Folge darf nicht periodisch sein (`seq[i] != seq[i+4]` mindestens einmal).

### H3 (hoch) – Pegel- und Einsatzzufall je Aufprallschicht ungeschützt
- **Regel** (AU-R R6; Testtabelle der Doku: „±2 dB, späterer Einsatz“; Meldungen in
  `test_collisions_by_closing_speed_and_partner`: „Pegel der Schicht zufällig, höchstens ±2 dB“, „Einsatz der Schicht bis
  20 ms später“).
- **Beleg (gemessen):** M15 `var jitter := 0.0` (kein Pegelzufall) – grün; M16 `var delay_s := 0.0` (kein späterer
  Einsatz) – grün; M14 Bereich verdoppelt (±4 dB) – grün (der Test prüft die Grenze an nur einem Unfall mit vier
  Schichten; mit dem festen Seed liegen alle vier zufällig in ±2 dB).
- **Korrektur:** über ≥ 50 Unfälle Spannweite und Streuung prüfen (z. B. max |jitter| > 1,5 dB und ≤ 2 dB, Anteil
  delay > 0 ms über 90 %, max delay ≤ 20 ms).

### H4 (hoch) – das Nachstellen der Plattenmuster hat keinen Test
- **Regel** (AU-R R3 „Plattenmuster nie gegenphasig“, AU-R2: der leisere wird bei mehr als `slabs.align_ms` auf die
  Stelle des lauteren gesetzt).
- **Beleg (gemessen):** M11 (der lautere statt des leiseren wird neu gestartet) und M12 (Schwelle 10⁹ ms – nie
  nachstellen) – beide grün. `test_slab_loops_lock_the_mixer_only_to_start` benutzt stehende Platzhalter-Spieler und
  prüft nur `slab_realigned == 0`.
- **Code heute richtig:** Probe T2 – Platzhalter-Spieler, das schnelle Muster 5·10⁻⁴ zu schnell: in 60 s 4-mal
  nachgestellt, größter Versatz 6,2 ms (Schwelle 6 ms), direkt danach 0,01 ms.
- **Korrektur:** im Test einem `FakePlayer` eine Drift geben (`advance(dt)` mit `skew`), wie `tools/kc_probe.gd` T2, und
  `slab_realigned > 0`, den leiseren als neu gestarteten und den Versatz danach < 0,5 ms prüfen.

### M1 (mittel) – Altstadtanteil 0,6 ± 0,05 in 10 Altstädten verfehlt (Steinbrücken, Tunnel)
- **Beleg (gemessen, `tools/kc_trigger.gd`, 1-m-Schritte durch jede Altstadt, alle 128 Ankünfte):** Anteil der
  Straßen (Altstadt ohne Brücken und Tunnel) außerhalb 0,55–0,65: Warschau 0,456/0,458, Lüttich 0,491/0,492, Prag
  0,492–0,494, Saragossa 0,501, Burgos 0,521, Ljubljana 0,526/0,527, San Sebastián 0,530, Paris 0,677 (aus Tours) und
  0,745 (aus Lüttich, 130 m Tunnel), Lyon 0,677/0,679; Barcelona 0,549 (zugeteilt genau 0,550, Rand). Wer die
  Steinbrücke als gepflasterte Straße mitzählt (so klingt sie), bekommt dafür Bordeaux, Dresden, Toulouse, Tours 0,70,
  Lyon 0,71, Paris 0,72/0,78 außerhalb. Unter beiden Lesarten liegen also 10–14 Ankünfte außerhalb.
- Altstädte nur mit Brücke ohne Steindeck (54 Ankünfte): 0,569–0,646 – im Band (AU-R3 wirkt). Altstädte ohne Brücke
  (12 Ankünfte): 0,549–0,561 – alle am unteren Rand (Zuteilung in Hashfolge ohne Nachrücken; ein 800-m-Zentrum kann
  480 m nur als 440/450 oder 520–540 m treffen).
- **Kein falscher Auslöser:** Pflaster liegt überall nur, wo es darf (Abschnitt 2.2). Kiel – Hamburg: Hamburg 0,551,
  Muster `P--PP-P-P` – unverändert.
- **Korrektur:** `AudioFeed.cobbled_blocks()` – Steinbrücken-Meter als schon gepflasterte Straße einrechnen (Ziel um sie
  mindern) und Tunnel der Altstadt (`plan.tunnels`) wie Brücken ohne Steindeck in `skip` geben; `_closer()` dann für jede
  Altstadt laufen lassen, nicht nur bei `cut_all > 0`. Vorher die Definition „Straße“ entscheiden (Vertragsfrage 1).

### M2 (mittel) – Zufall der Vorbeifahrten ohne Test
- **Regel** (AU-R R6: „Zufall ±2 dB … (Unfall, Vorbeifahrten)“, Variante zufällig; der AU-R-Bericht nennt dafür „Tests in
  `test_road_audio.gd` / `test_audio_feed.gd`“).
- **Beleg (gemessen):** M17 (`var jitter := 0.0` in `_pass()`) und M18 (`var variant := 0`) – beide grün; kein Test liest
  `last_pass["jitter_db"]` oder die Variante.
- **Korrektur:** in `test_passed_objects` 50 Vorbeifahrten: |jitter| ≤ `passes.jitter_db`, Spannweite > 1,5 dB, jede
  Variante kommt vor, nie zweimal dieselbe (bei n ≥ 3).

### L1 (niedrig) – an der Tankspur Asphalt bis 0,45 m außerhalb des Außenrands
- **Beleg (gemessen, `tools/kc_fuel_edge.gd`, Kiel – Hamburg, erste Tankspur):** rechtes Rad 0,1 / 0,3 / 0,45 m
  außerhalb des befestigten Rands: mit Tankspur `asphalt`, 300 m davor (ohne Tankspur) `rumble`; ab 0,6 m beide
  `shoulder`. `wheel_surface(raw, inside, plain_edge)` gibt bei `plain_edge` den Belag zurück, auch wenn das Rad außen
  ist (`inside` = false) – dort liegt Schotter.
- **Abgeleitet:** selten befahren (nur wer die Tankspur verfehlt), Unterschied glatt/Schotter auf 0,5 m Breite.
- **Korrektur:** `scripts/audio/modern/audio_feed.gd` `wheel_surface()`: `if plain_edge: return paving if (inside or
  paved_shoulder) else "shoulder"` (wie eine Randlinie ohne Profil).

### L2 (niedrig) – Doku widerspricht der Konfiguration bzw. ist veraltet
- `docs/audio-modern.md` Zeile 1063 (Tabelle 15.1, Betonplatten): „über 150 km/h … nur noch um 8 statt 20 dB je Dekade“
  – `audio.modern.road.slabs.high_slope_db` ist **4** (so auch 15.8 und 15.10). → „4 statt 20“.
- Zeile 1125 (15.2): „Größe: AU-C1 zusammen 4,52 MB; alle Modern-Klänge außer Musik 17,9 MB von 23 MB“ – Stand AU-R3:
  Schleifen 3,00 + Einmalklänge 2,57 = 5,57 MB, alle Klänge ohne Musik 18,95 MB (gemessen, Blob-Größen).
- Zeile 382 (Abschnitt 8) und Kopf von `audio_feed.gd`: der Rand der Tankspur sei „eine gestrichelte Linie ohne Profil“ –
  Arcade zeichnet die Trennlinie durchgezogen (1,6-fach breit) und am Außenrand der Tankspur eine durchgezogene
  Randlinie (`road_renderer.gd` `_draw_markings`, Zeilen 2000–2003; `_line` zeichnet ohne Lücken). Die Regel „rechts
  keine Rüttellinie, solange das Segment eine Tankspur hat“ stimmt; nur die Begründung nicht (Kommentar auch in
  `audio_feed.gd` Zeilen 13 und 623).
- 15.11, Zeile „Begrenzer beim Reisen (V3)“: „erfüllt“ beruht auf vier Läufen à 57 s bei 200 km/h; 130 und 170 km/h nur
  „in kürzeren Läufen“ – V3 verlangt je Lauf 60 s und mindestens vier Läufe für 130–200 km/h (Vertragsfrage 2; Messung ist
  Sache von KRITIK-R2-MESS).

### L3 (niedrig) – schwache oder fehlende Wächter kleinerer Regeln
- Tunnelwind 0 dB (AU-R): M31 (`zone_db.tunnel` zurück auf −3) – grün, weil `test_wind_zones_gusts_and_fades` gegen den
  Konfigurationswert vergleicht; die Meldung „im Tunnel leiser“ ist seit AU-R falsch. → festen Wert 0 prüfen, Meldung
  „im Tunnel nicht leiser“.
- Glas ab genau 80 km/h: M32 (`>` statt `>=`, + 0,5 km/h) – grün; der Test nimmt `from_kmh + 1`.
- Drift „mittlere Leistung des Plans“: M05 gefangen, aber nur um 0,04 dB (−29,42 gegen −29,96 ± 0,5 LUFS); der
  50-s-Mittelwert schwankt laut Probe um ±0,15 dB. → längerer Lauf oder engere Toleranz (0,2 dB über 300 s).

### L4 (niedrig) – Kleinigkeiten im Code (kein hörbarer Effekt)
- `RoadAudio.Layer.start_at` wird nie gesetzt (nur zurückgesetzt) – entfernen.
- `_update_squeal()` würfelt `squeal_factor` in jedem Bild neu, solange das Quietschen unter `SILENT` bleibt (Probe:
  600 Ziehungen in 10 leisen Ansätzen) – harmlos, aber Zufall ohne Zweck.
- `_slab_check` wird auf 0 gesetzt statt um 0,5 s vermindert: Abstand der Prüfsperren 0,50–0,53 s je nach Bildrate
  (gemessen 1,88–2,00 Sperren/s bei 30–90 fps) – harmlos.
- `AudioFeed._closer()` gibt `got` zurück, der Wert wird nicht benutzt.

---------------------------------------------------------------------------------------------------------------------

## 2. Was geprüft wurde und in Ordnung ist

### 2.1 Regressionen und Gates (alles gemessen)

| Prüfung | Ergebnis |
|---|---|
| Regel 1: `git diff v0.7.0..b6339ad4` über alle eingefrorenen Pfade | leer |
| Dateien `4209268..b6339ad4` außerhalb des AU-Bereichs | keine (131 Dateien, alle in `scripts/audio/modern`, `assets/audio/modern/{sfx,vehicle}`, `tools/audio/{modern,qc}`, `tools/audio/music/{music_lib.py,mischung.json}`, `tests/unit/audio_modern`, `docs/audio-modern.md`, `config/game_config.json`) |
| Motor v3, Musik, Ambiente, UI, Verkehr (`assets/audio/modern/{engines,music,ambience,ui,traffic}`, `assets/audio/music`) | bitgleich zu AU-C1 |
| Konfiguration | 47 Schlüssel geändert, alle unter `audio.modern.*` / `audio._doc_modern`; `music`, `duck`, `snapshots`, `engine`, `levels`, `glue` unverändert |
| `mischung.json` | alle 7 alten Werte gleich; neu `low_shelf_db` 0 / `low_shelf_hz` 120; `music_lib.py` hängt den Filter nur bei ≠ 0 an (Code) |
| `tools/run_tests.sh` (einmal, Kopie r3) | „656 Tests, 0 fehlgeschlagen“, 83 CHECK OK, 0 FEHLER, „Tests bestanden (617 s)“ |
| `check_arcade_lean` | OK: 0 von 35 Skripten des Modern-Klangs, -Renderers und der Modell-Datenbank geladen |
| `test_arcade_identity` (6 Tests), `check_modern_audio` | grün: Motor-Mischer, SfxSynth, Verkehr/Raum, eingefrorene Klänge byte-gleich zu v0.7.0; „nach allem: Profil Arcade, 12 Busse … wie in v0.7.0“ |
| `tools/golden.sh check` (einmal) | „GOLDEN arcade: 20 von 20 identisch (195 s)“ |
| `ERGEBNIS` (`tests/race/run_stage.gd`, Autopilot, Zeitraffer 40, Seed 7): Kiel – Hamburg und Nürnberg – Regensburg, je Bild/Klang Arcade/Arcade, Arcade/Modern, Modern/Modern | alle 27 Felder außer `gfx` gleich (Kiel – Hamburg mit einer Tankung); `gfx` „modern“ ohne `gfx_fallback` |
| Determinismus `vehicle_loops.py`, `sfx_modern.py` (je zweimal nach `--out`, wie `audio_qc.py --determinism`) | beide Läufe gleich und gleich den eingecheckten Dateien und Manifest-Einträgen (32 Dateien / 31 Einträge; 39 / 17) |
| Import und Schleifenpunkte | 26 Ogg-Schleifen `loop=true`, `loop_offset=0`, `loop` = ganze Datei; 5 WAV-Schleifen `loop_mode=2`, `loop_end` = Manifest, 16 Fortsetzungsframes; jedes `pair` vorhanden; Längen 4,1–7,6 s, Verhältnis 1,21–1,29 |
| Klangbudget | Klänge ohne Musik 17,90 → 18,95 MB von 23 MB (Blob-Größen); Schleifen 3,00 MB, Einmalklänge 2,57 MB |
| Export | importierte Modern-Klänge 27,0 MB (+ 11,0 MB Motorbänke roh); Zuwachs durch diese Änderung etwa +1,1 MB (abgeleitet aus den Blob-Größen) |
| Kosten des Mischers (abgeleitet für das Deck) | 14 Schleifen gleichzeitig, Tonhöhe 1,03, Dummy-Treiber: Ogg 2,2 %, WAV 0,55 % eines Kerns (gemessen, Mischer-Faden) – die Ogg-Umstellung kostet etwa 0,12 % eines Kerns je Schleife |
| Lecks | Lauf mit echten Spielern (Xvfb, `--sound=modern`, Schnee, km 74 bis Hamburg): Exit 0, kein „leaked“, „still in use“, kein ERROR |

### 2.2 Auslösung über alle Etappen (`tools/kc_trigger.gd`, alle 64 sichtbaren Etappen × 2 Richtungen, echte `Track` mit ihren Segmenten, Fenster wie im Rennen; 1-m-Schritte in den City Limits und auf Brücken, sonst 3 m; Wetter abwechselnd Regen/Schnee)

| Regel | Ergebnis (gemessen) |
|---|---|
| Pflaster nur in einer Altstadtstraße (Zentrum, kein Deck, kein Tunnel) oder auf einem Steindeck; nie auf Stahl- oder Betondeck | 0 Verstöße |
| `deck` nur auf Stahl; Stahl immer `deck`, Stein immer Pflaster; Tunnel immer Asphalt | 0 Verstöße |
| Beton nur auf `concrete_roads` außerhalb der City Limits, nicht im Tunnel, nicht auf Stahl/Stein | 0 Verstöße |
| `feed.deck` = Deck der Brücke der `Track` | 0 Abweichungen |
| Fugen je Brücke = Regel (Enden + alle N m, keine näher als N/2 vor dem Ende; Stahl 100, Beton 32, Stein keine) | 122 befahrene Brücken (15 Stahl, 72 Beton, 35 Stein): 0 Abweichungen; 0 Fugen abseits einer Brücke |
| Fugen in beiden Richtungen | Stadtbrücken liegen nur in der Ankunftsrichtung der Zielstadt; jede Ankunft fährt sie gleich – dieselben Fugen an denselben Stellen |
| Pflastermuster je Stadt | bei jeder Ankunft dasselbe (0 Städte mit verschiedenen Mustern) |
| Betonanteil je Land (V2, je Abschnittsschlüssel, km-gewichtet) | beurteilt (≥ 10 Abschnitte): DE 0,349 (Soll 0,35), FR 0,104, ES 0,085, PL 0,238 (0,25), RS 0,060, HU 0,125, RO 0,094, CZ 0,418 (0,40), BE 0,296 (0,30), CH 0,096, IT 0,075, NL 0,103, AT 0,155 (0,15) – 13 von 13 im Band; genannt: HR 0,141 (8), SI 0,190 (5), LT 0 (3), BG 0 (1), LV 0 (1) |
| Beton „wie gehört“ (gefahrene Meter, beide Richtungen) | alle 13 ebenfalls in ±0,05 (NL 0,061, CH 0,080, AT 0,121, RS 0,063 am weitesten weg) |
| Abschnittsentscheidung in beiden Richtungen | 419 Schlüssel, 0 verschieden |
| Rüttellinie an der Tankspur (rechtes Rad 0,1 m innerhalb des Rands, ganze Tankspur mit Verjüngung) | 410 Tankspuren, 78 171 m: 0 m Rüttellinie; Gegenprobe 200 m davor: 79 400 von 82 000 m Rüttellinie (Probe wirkt) |
| Zone „tunnel“ genau im Tunnel; Nässe/Schnee aus im Tunnel, sonst an | 0 Abweichungen |
| Altstadtanteil 0,6 ± 0,05 | verfehlt in 10 Altstädten → Befund M1 |

### 2.3 Code (gelesen, mit Proben belegt)

- **`road_audio.gd`:** je Seite eigene Schleife (`pair`), eigene Lautheitskurve je Seite bei eigener Tonhöhe
  (`_gain(…, i)` mit `ratios[i]`), Zufallsstart, OU-Drift mit Leistungsausgleich, rechte Seite × 1,02 außer
  Rüttelstreifen; Plattenmuster: Start unter Sperre mit der Stelle des laufenden, Prüfung alle 0,5 s, Nachstellen des
  leiseren; Gesetz über 150 km/h stetig (`slab_lufs`); Schnee-Schleife mit eigenem Pegel; Quietschen je Ereignis;
  Vorbeifahrten mit Variante und ±2 dB; `stop_all` / `teardown` erfassen die neue Schnee-Ebene (`_all_layers`).
  Zustände zwischen Etappen: `track_changed` setzt die Böen zurück; Drift, `_slab_check`, `squeal_factor` laufen
  weiter – ohne hörbare Folge. Kein Wert kann bei 0 km/h oder Rückwärtsfahrt NaN werden (`_speed` ≥ 0, alle log/pow mit
  Untergrenzen; Probe T4: 0 von 819 Fällen).
- **`audio_feed.gd`:** `unit_hash` = djb2 + MurmurHash3-fmix32 (in Python nachgerechnet: die drei Bezugswerte des Tests
  stimmen bitgenau); `_mul32` ohne Überlauf; `cobbled_blocks` + `_closer` + `_merged_stretches` richtig (Blöcke ganz auf
  einer Brücke nie gepflastert); `bridge_stretches` aus dem Plan, vom Ziel aus gezählt; `concrete_threshold_for` gilt
  nur für den kalibrierten Anteil; `section_key` richtungsunabhängig; Fugen je Deck mit `joint_spacing`; Tankspur über
  `plain_edge` (siehe L1); Deck-Regel AU-R3 `city and deck == ""`.
- **`impact_audio.gd`:** Variante über `pick_variant` (nie dieselbe bei n ≥ 3), ±2 dB und 0–20 ms nur für
  Kollisionsschichten, aus dem Vorlauf der Datei genommen (Schichten ohne Zufall springen genau über den Vorlauf: Zeit
  wie AU-C1); Glas-Regel nur in der schweren Stufe wirksam (nur sie hat Glas). Kein anderes Modul spielt die Dateien mit
  20 ms Vorlauf direkt (`sfx_bank.gd` geprüft).
- **`modern_buses.gd`:** Begrenzer nur auf `MMaster` (Index 1 hinter dem Kleber), mit dem Bus entfernt; auf `MMaster`
  sitzt sonst nichts (kein Fader, kein Tiefpass), `levels.MMaster` 0 dB; Arcade-Busse unberührt (`check_modern_audio`).
- **Kein globaler Zufall** in `scripts/audio/modern` (nur eigene `RandomNumberGenerator`) – die Simulation kann nichts davon
  sehen; `ERGEBNIS` gleich (2.1).

### 2.4 Laufzeitproben (`tools/kc_probe.gd`, ModernAudio ohne Szenenbaum, Platzhalter-Spieler für die Plattenmuster)

| Probe | Ergebnis (gemessen) |
|---|---|
| T1 Bildrate 30/40/60/90 fps, je 600 s Beton 130 km/h | Seitendrift-Streuung 2,01 / 1,98 / 2,03 / 2,03 dB; mittlere Leistung −12,61 / −12,59 / −12,65 / −12,62 dB; Böen-Streuung 1,48–1,49 dB; Sperren 1,88 / 2,00 / 1,94 / 2,00 je s – keine Bildratenabhängigkeit (60-s-Läufe streuen um ±0,2 dB, das ist Stichprobe) |
| T2 Nachstellen (schnelles Muster 5·10⁻⁴ zu schnell) | 4-mal in 60 s, größter Versatz 6,2 ms, danach 0,01 ms |
| T3 Pause | alle 10 laufenden Schleifen nach 47 Bildern still; 2 Sperren des Audioservers in 10 s Pause (beide beim Ausblenden) |
| T6 `stop_all` | 0 Spieler laufen weiter |
| T4 NaN/INF | 0 in 819 Fällen (13 Tempi von 0 bis 400 km/h × 7 Beläge × 3 Wetter × 3 Untersteuern, Fugen und Vorbeifahrten bei 0 km/h, Kollisionen mit 0 / −50 / 1000 km/h) |
| T5 Quietschen | 0 Tonhöhenwechsel während hörbarer Quietscher |

### 2.5 Tests gegen ihre Regeln (`tools/mutate.py`, je eine Zeile gebrochen, nur die zuständige Testdatei)

| Nr | Regel | Zuständiger Test | gefangen |
|---|---|---|---|
| M01 | Quietschen je Ereignis | `test_squeal_pitch_per_event` | **nein** (H1) |
| M02 | Quietschen ±5 % zufällig | dito | ja |
| M03 | Varianten zufällig statt reihum | `test_collision_variety` | **nein** (H2) |
| M04 | nie zweimal dieselbe Variante | dito | ja |
| M05 | Drift hält die mittlere Leistung | `test_each_side_has_its_own_loop_and_drift` | ja (Rand 0,04 dB, L3) |
| M06 | Drift je Seite vorhanden | dito | ja |
| M07 | Rüttelstreifen ohne Tonhöhenversatz | dito | ja |
| M08 | Plattengesetz über 150 km/h | `test_concrete_slabs_keep_their_rhythm` | ja |
| M09 | Sperre nur beim Start und alle 0,5 s | `test_slab_loops_lock_the_mixer_only_to_start` | ja |
| M10 | Start an der Stelle des laufenden Musters | dito | ja |
| M11 | Nachstellen: der leisere | – | **nein** (H4) |
| M12 | Nachstellen ab `align_ms` | – | **nein** (H4) |
| M13 | Glas unter 80 km/h nur zu 40 % | `test_collision_variety` | ja |
| M14 | Schichtpegel höchstens ±2 dB | `test_collisions_by_closing_speed_and_partner` | **nein** (H3) |
| M15 | Schichtpegel zufällig | dito | **nein** (H3) |
| M16 | späterer Einsatz je Schicht | dito | **nein** (H3) |
| M17 | Vorbeifahrt ±2 dB | – | **nein** (M2) |
| M18 | Vorbeifahrt: Variante zufällig | – | **nein** (M2) |
| M19 | keine Rüttellinie an der Tankspur | `test_no_rumble_at_the_fuel_lane` | ja |
| M20 | Fugen je Deck | `test_joints_per_deck` (+2) | ja |
| M21 | kein Altstadtpflaster auf Brücken ohne Steindeck | `test_no_old_town_cobbles_on_a_concrete_deck` (+1) | ja |
| M22 | Anteil über die Straßen | `test_old_town_share_on_its_streets_around_a_bridge` | ja |
| M23 | Nachrücken ins Band | `test_cobbled_blocks_count_only_the_streets` | ja |
| M24 | Steinbrücken zählen als Straße | dito | ja |
| M25 | fmix32 | `test_unit_hash_mixes_neighbouring_keys` | ja |
| M26 | Schwelle nur für den kalibrierten Anteil | `test_concrete_threshold_per_country` (+1) | ja |
| M27 | genaue Zuteilung je Altstadt | `test_cobbled_blocks_hit_the_share_per_centre` (+1) | ja |
| M28 | Begrenzer hinter dem Kleber | `test_base_effects` (+1) | ja |
| M29 | Obergrenze −2 dB ohne Eintrag | `test_limiter_from_config` | ja |
| M30 | Schnee-Knirschen mit `snow_crunch` | `test_surfaces_per_side_wet_and_snow` | ja |
| M31 | Tunnelwind 0 dB | `test_wind_zones_gusts_and_fades` | **nein** (L3) |
| M32 | Glas ab genau 80 km/h | `test_collision_variety` | **nein** (L3) |

Die drei AU-R3-Tests, die beiden Bus-Tests und `test_top_speed_row_of_the_plan` schützen ihre Regeln (die beiden
Damm-Tests sind laut AU-R3 auf dem Stand davor rot – hier mit M21/M22 bestätigt).

### 2.6 Doku und `_doc`-Einträge gegen Code

In Ordnung: alle neuen Schlüssel von `audio._doc_modern` (`limiter`, `joint_every_m` als Tabelle mit 0 = nur Enden /
< 0 = keine, `concrete_threshold`, `cobble_share` als Anteil der Straßen, `sides`, `slabs.align_ms/high_kmh/high_slope_db`,
`squeal.pitch_spread`, `passes.jitter_db`, `impact.variation`, `collision.glass`, `surface_db.snow`) stimmen mit Code und
Voreinstellungen überein; 15.2 (Längen, Seeds + 50 / Pflaster + 64, q8 für `wind_buffet` links, Größen 3,00 / 2,57 MB);
15.11 V1–V3 geben die Leitungsentscheide richtig wieder. Abweichungen: L2.

---------------------------------------------------------------------------------------------------------------------

## 3. Vertragsfragen

1. **„Straße“ einer Altstadt** (M1): Steinbrücken klingen immer nach Pflaster, Tunnel immer nach Asphalt; die
   Zuteilung zählt beide als Straße. Vorschlag für §11.2 (wie AU-R3): Straße = Altstadt ohne Brücken und Tunnel,
   Steinbrücken werden als schon gepflasterte Straße eingerechnet; Kriterium 0,6 ± 0,05 auf „wie gehört“ beziehen.
2. **V3 beim Reisen**: „130–200 km/h … in jedem von mindestens vier Läufen à 60 s“ – belegt sind vier Läufe à 57 s bei
   200 km/h auf Beton; 130 und 170 km/h nur in kürzeren Läufen. Die Leitung sollte sagen, ob 200 km/h auf Beton als
   schärfster Fall für den ganzen Bereich genügt.
3. **„Gleiche Entscheidungen in beiden Richtungen“** gilt für Beton (je Abschnitt, erfüllt); Fugen und Pflaster sind
   Merkmale der Zielstadt und werden in jeder Ankunft gleich gefahren – eine Gegenrichtung gibt es dort nicht.

## 4. Für die nächste Runde

- H1–H4 und M2: die fehlenden Wächter nachrüsten (Vorlagen in `tools/kc_probe.gd` T2/T5).
- M1 nach Entscheid der Vertragsfrage 1: Steinbrücken und Tunnel in `cobbled_blocks`, `_closer` für alle Altstädte.
- L1 (`wheel_surface` außen an der Tankspur), L2 (drei Doku-Stellen), L4 (toter Code).

## 5. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE/`:
`tools/kc_trigger.gd` + `tools/ana_trigger.py` (Auslösung, `res/trigger_all.log`, `res/trigger_all.json`),
`tools/kc_probe.gd` (`logs/probe.log`, `logs/probe_long.log`), `tools/mutate.py` (`res/mutations.json`,
`logs/mut_M*.log`), `tools/det.py` (`logs/det.log`), `tools/ergebnis.sh` (`res/ergebnis/*.log`), `tools/kc_fuel_edge.gd`,
`tools/kc_mixcost.gd` (`logs/mixcost.log`), `identity.sh`; Protokolle `logs/run_tests_r3.log`, `logs/golden.log`,
`logs/leak_live.log`. Die Kopien der Köpfe sind nach dem Bericht gelöscht (Platz).
