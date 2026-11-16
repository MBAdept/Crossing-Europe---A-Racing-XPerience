## 0. Kurzfassung

| Befund | Schwere | vorher (gemessen) | nachher (gemessen) | Stand |
|---|---|---|---|---|
| H1 Quietschen „je Ereignis“ ungeschützt | hoch | Mutation M01 grün | rot: 348 Tonhöhenwechsel in 612 hörbaren Bildern; ohne Bruch 0 | behoben (Test) |
| H2 Varianten „zufällig“ ungeschützt | hoch | M03 (streng reihum) grün | rot | behoben (Test) |
| H3 Pegel- und Einsatzzufall je Aufprallschicht ungeschützt | hoch | M14, M15, M16 grün | alle rot (240 Schichten aus 60 Unfällen) | behoben (Test) |
| H4 Nachstellen der Plattenmuster ungeschützt | hoch | M11, M12 grün | beide rot (laufende Platzhalter-Spieler mit Drift) | behoben (Test) |
| M2 Zufall der Vorbeifahrten ungeschützt | mittel | M17, M18 grün | beide rot | behoben (Test) |
| M1 (Code) Altstadtanteil mit Steinbrücke / Tunnel | mittel | 14 Ankünfte außerhalb 0,6 ± 0,05 wie gehört (1-m-Raster), 11 in genauen Metern | 3 im 1-m-Raster (0,549 – zugeteilt genau 0,550), 0 in genauen Metern | behoben, Lesart → Vertragsfrage |
| M1 (Messung) V3 beim Lkw knapp | mittel | 95 % 2,66 dB (Prüfung), nachgestellt 2,78 / 2,72 dB | `truck.heavy` −11,5: 2,13 / 2,51 dB, über 120 Unfälle 2,34 dB | behoben (Pegel), Vorschlag für §11.2 |
| L2 / L3 (nicht verlangt, nebenbei) | niedrig | Doku-Fehler; M31, M32 grün | Doku und Kommentare berichtigt; M31, M32 rot | erledigt |

Mutationen (Verfahren der Prüfung, je eine Zeile gebrochen, zuständige Testdatei): vorher 20 von 32 gefangen, nachher
**40 von 40** (die 32 der Prüfung – M22–M24 an den neuen Zeilen als M22b–M24b – und 8 neue für die Zuteilung des
Pflasters). Kiel – Hamburg klingt unverändert (Feed-Ausgabe beider Richtungen bitgleich, Hamburg `P--PP-P-P`).
Gates: <<GATES>>

## 1. Tests (H1–H4, M2; nebenbei L3)

`tests/unit/audio_modern/test_road_audio.gd`, ohne Szenenbaum. Werte der neuen Wächter ohne Bruch (gemessen):

| Test | Regel | gemessen | Mutation rot |
|---|---|---|---|
| `test_squeal_pitch_per_event` (erweitert) | Tonhöhe beim Einsetzen gewürfelt, gleich solange hörbar | 12 Quietscher, 612 hörbare Bilder, 0 Wechsel, 12 verschiedene Tonhöhen | M01, M02 |
| `test_collision_variety` (erweitert) | Varianten zufällig, nicht reihum; Glas genau ab 80 km/h | Lkw-Schlag: auf jede Variante folgen verschiedene; `pick_variant` 400 Ziehungen bei 4 Varianten, jede Folge 20–47 % | M03, M04, M13, M32 |
| `test_collision_layers_vary_in_level_and_onset` (neu) | ±2 dB je Schicht, bis 20 ms später | 240 Schichten: −2,00 … +2,00 dB, Streuung 1,13 dB (gleich verteilt 1,15), Mittel −0,09 dB; später in 100 %, Mittel 10,4 ms, höchstens 20,0 ms | M14, M15, M16 |
| `test_slab_loops_are_put_back_in_step` (neu) | der leisere wird ab `align_ms` auf den lauteren gesetzt | 120 km/h, schnelles Muster 5·10⁻⁴ zu schnell: in 60 s 4-mal nachgestellt, jedes Mal bei 6,18–6,20 ms (Schwelle 6), danach 0,00 ms; das lautere 0-mal neu gestartet; 30 s im Gleichschritt: 0-mal | M11, M12 |
| `test_pass_by_variants_and_levels_at_random` (neu) | Vorbeifahrt ±2 dB im gespielten Pegel, Variante zufällig | 60 Vorbeifahrten: −1,92 … +1,98 dB, beide Varianten, 35 Wiederholungen (zwei Varianten: kein Wechselschritt) | M17, M18 |
| `test_wind_zones_gusts_and_fades` (L3) | Fahrtwind im Tunnel 0 dB (AU-R) | 0 dB | M31 |

## 2. Altstadtpflaster (M1, Code)

**Ursache:** `cobbled_blocks` zählte Steinbrücken und Tunnel als freie Straße; der Feed spielt dort aber immer Pflaster
bzw. Asphalt. **Änderung** (`scripts/audio/modern/audio_feed.gd`): Der Anteil gilt **wie gehört** – Straße = Altstadt
ohne Brücken und Tunnel; eine Steinbrücke ist Straße, die schon gepflastert ist (`stone_stretches`, zählt in der Basis
und als Pflaster); ein Tunnel der Etappe (`tunnel_stretches`) ist keine Straße und Daten der Etappe: Die Blöcke der
Stadt bleiben, solange der Anteil dieser Ankunft im Band liegt, sonst rücken einzelne nach; `_closer` läuft für jede
Altstadt. Ohne Brücke und Tunnel in der Altstadt bitgleich wie vorher.

Nachgestellt mit `kc_trigger.gd` der Prüfung (alle 64 sichtbaren Etappen × 2 Richtungen, echte `Track`, 1-m-Schritte):

| | vorher (AU-R3, laut Prüfung, derselbe Commit) | nachher |
|---|---|---|
| außerhalb 0,6 ± 0,05 wie gehört | 14 Ankünfte | 3 (Barcelona 2 ×, Ljubljana 1 ×: 0,549 im Raster, zugeteilt genau 0,550) |
| genaue Meter aus dem Plan (`cobble_alloc.gd`) | 11 von 100 | 0 von 100, 0,550–0,645 |
| Straßen allein ohne Steinbrücke (Lesart AU-R3) | 22 | 26 (Lesart verlassen, siehe Vertragsfrage) |
| Verstöße der Auslösung (Pflaster/Deck/Beton/Fugen/Zonen/Tankspur) | 0 | 0 |
| Städte mit verschiedenen Mustern je Ankunft | 0 | 0 |
| Prüfskript-Ausgabe je Plan gleich | – | 114 von 128, Kiel – Hamburg beide Richtungen |

Anders klingen nur Bordeaux 0,70 → 0,60, Dresden 0,70 → 0,59, Lyon 0,71 → 0,61, Paris 0,72 / 0,78 → 0,60 / 0,64,
Toulouse 0,70 → 0,60, Tours 0,70 → 0,60 (wie gehört, 1-m-Raster); in Saragossa wechselt nur das Kennzeichen eines Blocks,
der ganz auf der Steinbrücke liegt (1 m am Brückenende). Die Tunnel von Hannover – Hamburg (330 m) und Lüttich – Paris
(130 m) lassen den Anteil im Band (0,617 / 0,644): kein Block verschoben. Neue Tests in `test_audio_feed.gd`:
Steinbrücke als gepflastert (30 Städte × 8 Fälle), Tunnel der Etappe (bleibt / rückt nach), echte Etappe mit
Steinbrücke und Tunnel im 1-m-Raster (0,58; mit den Blöcken der Stadt wären es 0,42). 8 neue Mutationen (M33–M40) rot.

## 3. Lkw-Aufprall (M1, Messung)

`kr_crash.gd` der Prüfung, je 60 schwere Lkw-Unfälle, 130 km/h Schließgeschwindigkeit, Gesamtlautstärke 1,0; Bootstrap
(abgeleitet) = Anteil der Abnahmen mit 60 Unfällen, deren 95-%-Wert über 3 dB käme:

| `truck.heavy` | Folge | 95 % | > 3 dB | True Peak max | Bootstrap |
|---|---|---|---|---|---|
| −11, Prüfung | 9312 | 2,66 dB | 3 / 60 | −1,21 dBTP | 35 % |
| −11, nachgestellt | 9312 · 9313 · beide | 2,78 · 2,72 · 2,78 dB | 2 · 2 · 4 / 120 | −1,23 dBTP | 14 % |
| **−11,5 (neu)** | 9312 · 9313 · beide | **2,13 · 2,51 · 2,34 dB** | 1 · 1 · 2 / 120 | **−1,39 dBTP** | **2 %** (120 Unfälle: 0,5 %) |
| Pkw `hit_heavy` −11,5 (Prüfung) | 9311 | 2,05 dB | 1 / 60 | −1,38 dBTP | 1,5 % |

Option (b) der Prüfung umgesetzt: `config/game_config.json` → `audio.modern.impact.collision.truck.heavy` −11 → −11,5
(wie der tiefe Schlag der Pkw-Unfälle). Eine Schicht von vieren, deren Pegel je Unfall ohnehin ±2 dB gewürfelt wird –
eine hörbare Änderung des Charakters ist nicht zu erwarten (abgeleitet). Option (a) bleibt als Vorschlag für §11.2.

## 4. Gates

<<GATESDETAIL>>

## 5. Hörproben (`deliver/AU-R/`)

Keine neu aufgenommen: Kiel – Hamburg, Köhlbrandbrücke und Schnee sind unverändert (Hamburg ohne Steinbrücke und
Tunnel, kein Pegel dort geändert). `aufprall_abwechslung_neu`: ein Lkw-Unfall (0:16) liegt 0,5 dB über dem Spiel –
weniger als der ±2-dB-Zufall jeder Schicht; Nachtrag in der `.txt`, die MP3 bleibt.

## 6. Vertragsfragen (für §11.2)

1. **Altstadtanteil „wie gehört“**: gepflasterte Straße + Steinbrücken über Straße + Steinbrücken, Straße = Altstadt
   ohne Brücken und Tunnel; beurteilt in genauen Metern der Zuteilung (das 1-m-Raster misst ±1 m je Blockgrenze:
   0,549 bei genau 0,550). Beide Lesarten zugleich gehen nicht: Für Dresden, Tours, Saragossa und Toulouse bringt
   keine Wahl der Blöcke (alle Teilmengen durchgerechnet) Straßen allein und „wie gehört“ zugleich ins Band.
2. **V3 über ≥ 120 Unfälle aus zwei Folgen** (Option a der Prüfung) zusätzlich zur Pegelsenkung: der 95-%-Wert aus
   60 Unfällen streut um 0,3–0,4 dB (Bootstrap).

## 7. Offen / für später

- L1: rechtes Rad bis 0,5 m außerhalb der Randlinie der Tankspur hört Belag statt Schotter (`wheel_surface`, eine
  Zeile; nicht in diesem Auftrag). L4: toter Code (`Layer.start_at`, Rückgabe von `_closer`, `_slab_check`).
- M05 (Drift hält die mittlere Leistung) wird nur mit 0,04 dB Rand gefangen (L3 der Prüfung).
- KRITIK-R2-MESS N1–N3 unverändert (Marken der Hörprobe, Nachstellen als harter Schnitt, Überblendungsmulde −3 dB).
- Altstädte mit genau 0,550 (Hamburg, Barcelona, Rostock …) liegen am Rand des Bandes, aber darin.

## 8. Dateien und Werkzeuge

Geändert: `scripts/audio/modern/audio_feed.gd`, `tests/unit/audio_modern/{test_road_audio,test_audio_feed}.gd`,
`config/game_config.json` (`audio.modern.impact.collision.truck.heavy`, Beschreibung von `cobble_share` in
`audio._doc_modern`), `docs/audio-modern.md` (8, 12, 15.1, 15.2, 15.4, 15.8, 15.11, neu 15.12).
Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R4/`: `tools/mutate.py` (+ `mutations_extra.json`; Ergebnisse
`res/mutations_{before,final}.json`), `tools/verbose_tests.gd` / `verbose_feed.gd` (Werte der Tests),
`tools/kc_trigger.gd` + `ana_trigger.py` (Prüfung, `res/trigger_after.{log,json}`), `tools/cobble_alloc.gd`
(genaue Meter, `res/cobble_alloc_after.log`), `tools/both_bands.py`, `mess/kr_crash.gd` + `ana_crash.py` + `boot.py`
(`mess/truck_*.json`), `logs/`.
