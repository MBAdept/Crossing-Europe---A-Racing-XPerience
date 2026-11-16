#!/usr/bin/env python3
"""Assembles deliver/QA-R4/bericht.md from the pieces (QA-R4)."""
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R4/bericht.md"
golden = sys.argv[1] if len(sys.argv) > 1 else "@@GOLDEN@@"

rd = lambda n: open(f"{S}/{n}", encoding="utf-8").read()
skel = open(D, encoding="utf-8").read() if "@@URTEIL@@" in open(D, encoding="utf-8").read() else rd("bericht_skel.md")
open(f"{S}/bericht_skel.md", "w", encoding="utf-8").write(skel)

URTEIL = """## Urteil

**Nicht unverändert in Testbuild 2 – zwei hohe Bildfehler nachts im Regen müssen vorher behoben werden; alles
andere hält.** R4 schließt die größte Lücke, die der Nutzer gesehen hat: Regen und Schneefall in der Luft auf jeder
„Effekte“-Stufe (auch „Steam Deck“), Gischt, nasse Fahrbahn mit Himmels- und Lichtspiegelungen, Schneewälle, Schnee auf
den Dingen, Sonnenscheibe, überstrahlte Tunnelausfahrt, Blaulicht-Kegel und ein Nachtgesetz, das die Limousine aus dem
Schwarz holt. Die Tore halten (gemessen): Fairness F1–F7 im ganzen Netz grün, Arcade @@GOLDENKURZ@@, alle
9 gefahrenen Render-Prüfdateien grün (darunter `check_start_km0`, `check_terrain_cover` mit K1, `check_light_base` und
F6 an N1), kalter Cache an N1 und N2 ohne Übersetzung während der Fahrt (die Basis übersetzte an N1 drei Varianten),
`run_tests.sh` bis auf zwei lastabhängige Fremdtests grün, Dateibesitz sauber bis auf die gemeldeten Grenzfälle.

**Aber:** (B1) die Rücklicht-Spiegelungen sind waagrechte Vierecke und stehen an jeder Steigung als rote Säule über
fernen Autos in der Luft – in meinem Bild bei 4 s und in R4s eigenem Clip bei 6 s; (B2) die nasse Fahrbahn im
Abblendlicht ist 1,77 × so hell wie bei Arcade und in der Basis, die Markierungen dort haben weniger als den halben
Kontrast – ein cremefarbener Fleck genau dort, wohin der Spieler schaut. Beides geht durch alle Prüfungen des Pakets.
Für B2 habe ich die Behebung in einer Kopie ausprobiert (Lichter nur auf den diffusen Anteil): Kegel 54 statt 108
(Arcade 61), Markierungskontrast 3,30 statt 1,31 (Arcade 2,93) – ein kleiner, gezielter Eingriff in `road.gdshader`.
Nachts im Regen ist Modern damit heute **in der Luft besser, auf der Straße schlechter** als Arcade; bei Tag, im Schnee,
in der Dämmerung und an der Tunnelausfahrt ist es gleichwertig bis klar besser. Offen bleibt der Lack (GT nachts grau,
Limousine nachts zu satt / in der Dämmerung blass) – teils schon in der Basis, teils FIX-M2 B-06.
"""

OK = """- Ownership: 42 Dateien, keine eingefrorene Arcade-Datei, `race_session.gd`/`race_renderers.gd`/Konfiguration unberührt.
- Fairness: `modern_sight.gd -- --full` und `modern_path_check.gd -- --full` grün (Zahlen in §3).
- Arcade-Gleichheit: @@GOLDENKURZ@@.
- `run_tests.sh` Vollauf: alle CHECK-Dateien grün, 760 von 762 Einheitstests (die zwei roten sind lastabhängig und nicht
  von R4, die Basis fällt beim selben Kern-Test ebenso).
- Render-Prüfungen: `check_night` 4/4, `check_weather` 5/5, beide Wettertabellen (24 Starts, 0,90–1,01 × Helligkeit,
  Kontrast ≥ 0,74 ×), `check_vehicle_lights` 4/4 (F6 an N1), `check_occlusion` 2/2, `check_start_km0` 3/3,
  `check_light_base` 2/2, `check_terrain_cover` 7/7 inkl. K1 – alle mit denselben Zahlen wie R4 (bestimmt).
- Geschützte Korrekturen des ersten Testbuilds halten: Start km 0, Fernboden/K1, Tageslicht, `test_far_ground_water`,
  `test_props`; `PYLON_BLINK`, `blink_lit`, `night_albedo`, `_dark_model_override` unverändert vorhanden.
- Kalter Shader-Cache „Steam Deck“: N1 443 Varianten vor dem Start, 0 während der Fahrt (Basis: 3 bei 4,6 s → R4s
  Aufwärm-Ebene wirkt); N2 22 Uhr Regen 459 / 0. Längstes Bild ≤ 1.546 ms bei Grenze 2.390–3.602 ms.
- Lichtdeckel: ≤ 8 Punktlichter, ≤ 2 Spots, ≤ 22 Kegel entlang dreier Nachtetappen; R5/R6 erzeugen keine eigenen
  Lichter (die Ebene 20 bleibt sauber).
- Netz: Schneewälle auf allen 64 Etappen ohne Fehler gebaut (≤ 0,351 m), alle 26 Tunnelausfahrten erkannt, keine
  Tunnel-Lücke < 60 m.
- Schnittstellen: `set_zone()` dokumentiert und von R5 richtig benutzt; `add_lamps()` unverändert; Zusammenführung
  mit FIX-M2/R5/R6 nur in Hash-Dateien und einer Doku-Datei im Konflikt.
- Mutationen: 9 von 12 sinnvollen Brüchen erkannt (U1–U4, U6, U7, R1, R2, R4).
- Bilder: N1 (Hoch, Deck), S1 bedeckt, S1 Morgen/Abend, C1, DEV, Tunnelausfahrt in der Röhre – gleichwertig bis besser
  als Arcade und nirgends schlechter als die Basis (außer B1/B2 nachts im Regen).
"""

PERF = """Gemessen auf llvmpipe unter Xvfb (Last 13–18), „Steam Deck“-Voreinstellung 1280×800, kalter Shader-Cache,
`tests/race3d/render/warmup_cold.gd` (30 s echte Fahrt mit Autopilot und Verkehr), Kopf und Basis nacheinander:

| Stelle | Stand | Varianten vor Start / in Fahrt | Vorbereitung | `render()` Mittel | Einhängen max | Zeichenaufrufe | Dreiecke | Bildzeit Median / max |
|---|---|---|---|---|---|---|---|---|
| N1 22 Uhr Schnee | Basis | 354 / **3** (FEHLER) | 54,7 s | 1,965 ms | 1,14 ms | 64 | 85.717 | 980 / 1.642 ms |
| N1 22 Uhr Schnee | Kopf | 443 / 0 | 64,1 s | 2,149 ms | 1,27 ms | 72 | 99.499 | 797 / 1.480 ms |
| N2 22 Uhr Regen | Basis | 360 / 0 | 59,3 s | 2,027 ms | 1,04 ms | 79 | 91.974 | 1.275 / 1.875 ms |
| N2 22 Uhr Regen | Kopf | 459 / 0 | 71,7 s | 1,928 ms | 1,01 ms | 82 | 91.789 | 1.201 / 1.546 ms |

Gelesen: R4 kostet im Skript nichts Messbares (±0,2 ms, Rauschen; `kern_zeit` im Vollauf 0,389 ms), keine Spitze beim
Einhängen (≤ 1,27 ms, Deck-Budget 3 ms), +3 bis +8 Zeichenaufrufe (Niederschlag, Gischt, zwei Spiegelungsebenen) und an
N1 +16 % Dreiecke (Schneewälle, Teilchen) – weit unter dem Deck-Budget (650 Aufrufe, 450.000 Dreiecke). Die Vorbereitung
mit kaltem Cache dauert hier 9–12 s länger (89–99 Shader-Varianten mehr, u. a. Teilchen, Gischt, Streifen,
Blendviereck, Schnee-Varianten) – auf echter Hardware abgeleitet wenige Sekunden beim allerersten Start. Bildzeiten auf
llvmpipe sagen über das Deck nichts (R4 maß in „Stadt bei Nacht im Regen“ +29 % Bildzeit durch die Füllrate der
Regenstriche in Software); ob 1.500 Teilchen auf dem Deck frei sind, zeigt nur der Leistungstest des Nutzers (abgeleitet:
ja, eine kleine Menge). Einen ganzen Etappenlauf habe ich nicht wiederholt (R4: 95 km ohne Fehler, gleiches Ergebnis wie
die Basis).
"""

VERTRAG = """1. §6 R4 nennt `GPUParticles3D`; mit Regel 10 (bestimmte Bilder, `--shot-fast`) und dem schwimmenden Ursprung ist
   R4s zustandsloses MultiMesh im Kamera-Raum die bessere Lösung – ich stimme R4s Vorschlag zu, §6 so zu ändern.
2. §4.10 „Effekte“: `spray` false bei „Aus“ und `wet_reflections` nur bei „Voll“ widersprechen „keine Stufe zeigt weniger
   als Arcade“ – R4 zeigt beides auf jeder Stufe; die Tabelle sollte das nachziehen.
3. §6 R4 Abnahme prüft die Nacht-Fahrbahn nur an N1 (trocken, Schnee). Die nasse Nacht – wo B2 sitzt – hat keine
   Abnahme; Vorschlag: „N2 22 Uhr Regen: Fahrbahn im Abblendlicht höchstens +15 % gegen Arcade, Markierungskontrast
   ≥ 0,8 ×“ und „keine Spiegelung über der Lampenzeile ihres Fahrzeugs“.
4. §5 W3: `flare.gdshader` hat keinen Besitzer, `tests/golden/modern_*` ebenfalls nicht, obwohl jedes Renderer-Paket
   die Modern-Bilder ändert – Vorschlag: Shader beim Besitzer von `flares.gd`; Modern-Hashes erzeugt nur die
   Zusammenführung (RINT), Pakete prüfen mit `modern-check` lokal.
"""

NEXT = """1. **R4-Nacharbeit (vor Testbuild 2)**: B1 (Streifen in die Fahrbahnebene, `vehicles.gd` + `flare.gdshader`
   `CE_STREAK`, auch Laternen) und B2 (Lichter nur auf den diffusen Anteil, Probe-Patch
   `deliver/QA-R4/b2_behebung_probe_road_gdshader.py`), je mit einer neuen Prüfung (B4).
2. **RINT-M2**: `tests/golden/modern_slice.{md5,env}` nicht von Hand mischen – nach dem Zusammenführen
   `golden.sh modern-make` (Bilder ansehen); `docs/renderer-modern.md` R4- und R5-Abschnitt hintereinander.
3. **FIX-M2 B-06 / R7**: GT nachts im Regen grau (B3), Limousine nachts zu satt (B7) und in der Dämmerung blass/lila;
   `check_night` „spielerauto“ mit Obergrenze der Sättigung und dem DEV-Fall.
4. **R4/R7**: `quality_lowered()` in `weather.gd` (und `lights.gd` für den Punktlicht-Pool), B5.
5. **R4**: Nachglühen zeitlich begrenzen oder weglassen (B6); `render_priority` des Blendvierecks (B8).
6. **Kern-Testbesitzer**: `test_chunk_services` „threaded“ ist ein Wettlauf (Basis 1 von 6 rot) – A-11 verlangt
   lastfeste Prüfungen.
7. **PERF**: Vorbereitung mit kaltem Cache +9–12 s auf llvmpipe durch ~95 neue Varianten – beim ersten Start auf dem Deck
   beobachten (Leistungstest).
"""

RCREST = """| `check_occlusion.gd` | 2/2 OK (33 s): Kuppe 0 von 921.600 Pixeln, Lkw 0 Pixel |
| `check_weather_tabelle.gd` | OK (414 s): klar/Regen × 6:36/12/19:12/22 Uhr 0,90–1,01 × Helligkeit, Kontrast 0,74–1,17 × – **Regen 22 Uhr 0,97 × / 1,17 ×**: das Mittel über den ganzen Boden verdeckt B2 |
| `check_weather_tabelle_schnee.gd` | OK (213 s): 0,98–1,00 × / 0,96–0,99 × |"""

MUTREST = """| R1 | N1-Fahrbahn nie dunkler als Arcade | `night_lift` 0 | **erkannt** (`check_night` fahrbahn −2,9 %) |
| R2 | Niederschlag im Tunnel aus | `_fade = 1.0` | **erkannt** (`check_weather` tunnel) |
| R3 | Schneewall-Netz ≤ 0,45 m | Profil-Scheitel 1,0 → 2,6 (Wall 0,78 m hoch im Netz) | **nicht erkannt** – „schneewall“ misst `bank_height()`, nicht die Ecken des Netzes |
| R4 | Schneewall-Höhe | `BANK_H_M` 0,8 und `BANK_MAX_M` 0,95 | **erkannt** (0,927 m) |
| (B1/B2) | Spiegelung in der Fahrbahn, Kegel auf nasser Fahrbahn | – (kein Bruch nötig: die Fehler sind im Kopf und alle Prüfungen grün) | **nicht bewacht** |

Fazit: die Einheits- und Render-Prüfungen bewachen die meisten Regeln wirklich (9 von 12 Brüchen rot); Lücken sind
das Netz des Schneewalls, die Stetigkeit des Nachglühens und – wichtiger – die beiden Bildfehler B1/B2 (B4)."""

bef = rd("bericht_befunde.md").replace("@@B3PLUS@@", rd("bericht_befunde2.md"))
bef = bef.replace("@@R3@@", "ebenso unerkannt (die Prüfung misst die Funktion `bank_height()`, nicht das Netz)")
rest = rd("bericht_rest.md").replace("@@RCREST@@", RCREST).replace("@@MUTREST@@", MUTREST)

out = skel
out = out.replace("@@URTEIL@@", URTEIL)
out = out.replace("@@BEFUNDE@@", bef)
out = out.replace("@@OK@@", OK)
out = out.replace("@@BILDER@@", rd("bericht_bilder.md"))
# sections 2-5 come as one block from bericht_rest.md (it carries its own headings)
for tag in ["## 2. Funktion im ganzen Netz\n\n@@FUNKTION@@\n\n", "## 3. Fairness\n\n@@FAIR@@\n\n",
            "## 4. Arcade-Gleichheit und Dateibesitz\n\n@@BESITZ@@\n\n"]:
    out = out.replace(tag, "")
out = out.replace("## 5. Tests, Render-Prüfungen und Mutationen\n\n@@TESTS@@", rest.rstrip())
out = out.replace("@@PERF@@", PERF.rstrip())
out = out.replace("@@VERTRAG@@", VERTRAG.rstrip())
out = out.replace("@@NEXT@@", NEXT.rstrip())
out = out.replace("@@GOLDEN@@", golden)
kurz = "20 von 20 und 17 von 17 identisch" if "20 von 20" in golden and "17 von 17" in golden else golden
out = out.replace("@@GOLDENKURZ@@", kurz)
open(D, "w", encoding="utf-8").write(out)
left = [l for l in out.splitlines() if "@@" in l]
print("written", D, len(out.splitlines()), "lines; placeholders left:", left)
