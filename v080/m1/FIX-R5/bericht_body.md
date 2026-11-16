## 1. Befunde der Prüfung QA-R5 – nachgestellt, behoben, abgelehnt

| ID | Schwere | Ergebnis | Kurz |
|---|---|---|---|
| QR5-01 | hoch | **behoben** (R5-Teil); R4-Teil offen | Portal-Mesh auf Renderlayer 2 – kein Spot des Abblendlichts, kein Lampen-Omni erreicht es (wie Arcade). Nachgestellt bitgleich mit QA-R5s Bildern; danach Stirnwand U1 22 Uhr 79 → 56 (Arcade 46), DEV 21 Uhr 107 → 57 (Arcade 47). Abblendkante bleibt R4s. |
| QR5-02 | mittel | **offen (R4)**, R5 liefert die Daten | Fahrbahn in der Röhre gehört R4 (`road.gd`/`road.gdshader`); R5 legt jetzt das Licht der Röhre in `tunnel_state["light"]`; genaue Änderung für R4 in Abschnitt 8. Bilder unverändert grau (gemessen). |
| QR5-03 | mittel | **von R4 gelöst** (nachgeprüft), Rest an R4 | Probe in einer Scratch-Kopie (dieser Kopf + `origin/wip/v080-fix-r4`): R4s Belichtungsfläche überstrahlt das Draußen wie Arcade. Sie steht aber bei `end_km` − 0,6 m vor dem wahren Röhrenende → R5s Ausfahrtsrahmen glüht mit. R5 liefert `tunnel_state["exit_z"]`; R4 setzt die Fläche dort an (Zeile in Abschnitt 8 Punkt 1, in der Scratch-Kopie gerendert: Abschnitt 3). |
| QR5-04 | mittel | **offen (R4 / Vertrag)** | Steinbrüstung liegt in R4s `roadside.gd`; R5 kann sie nicht ersetzen (eine Brüstung aus R5 stünde hinter der geschlossenen Wand). Vertragslücke „railings per type“ gemeldet. |
| QR5-05 | mittel | **behoben** | Neue/geschärfte Tests; die vier ungeschützten Mutationen (B10, B12, B14, T4) und eine neue für QR5-01 (P1) fängt jetzt je ein benannter Test, ohne Skriptfehler-Umweg (B10). |
| QR5-06 | niedrig | **behoben** | Netzlauf vergleicht genau mit Arcades Elementen; 122 Brücken, 28 Tunnel (Testetappe eingeschlossen), 0 Mängel, 180 s; fängt 5 von 5 eingebauten Teilverlusten. |
| QR5-07 | niedrig | **abgelehnt für FIX-R5** (Sache der Integration) | R5s Golden-Zeile bleibt; FIX-R5 ändert kein Modern-Bild der Liste (modern-check, Abschnitt 5) und fasst `tests/golden/**` nicht an. Beim RINT-M2-Merge die Liste mit `modern-make` neu erzeugen. |
| QR5-08 | niedrig | **offen (R4)** | Schiffe in R4s `props.gd` Z. 599; ohne R4s Zeile nicht lösbar (R5s Wasser bleibt 0,15 m über den Geländewasserzeilen, die R4 noch zeichnet). |
| QR5-09 | niedrig | **abgelehnt** (kein Code-Befund, gemessen) | Gotthard „deck“ 600 s: Commit-Maximum Basis 17,8 ms, FIX-R5 4,1 ms im selben Zustand → Last; headless (Minimum aus 3) Commit je Tunnelstück ≤ 0,25 ms, also 12 × unter dem deck-Budget 3 ms. |

### 1.1 QR5-01 – Nachtportal (hoch)

**Nachgestellt** (gemessen): `shots.sh repro u1_nacht dev` auf 5558bdc – die Bilder sind **bitgleich** (MD5) mit QA-R5s
Renderings (`u1_nacht_modern_00/01`, `dev_modern_00–02`).

**Ursache:** das Portal-Mesh `TunnelPortal` (Rahmen, Stirnwand, Flügelmauern, Hügel; vpbr) lag auf Renderlayer 1. Die
zwei Spots des Abblendlichts (R4 `layers/lights.gd`, 30° rundum, ohne Abblendkante) beleuchten alles auf Layer 1 bis
80 m, also auch eine senkrechte Wand 60–70 m voraus bis oben. Arcade beleuchtet sein Portal nie mit den Scheinwerfern
(`RoadRenderer._draw_portal` färbt mit `_rowc`: Farbe × Umgebungslicht + Nebel – ohne `_light()`), während es Requisiten,
Pylone und Fachwerk sehr wohl im Kegel aufhellt (`_oc(…, light)`). Darum ist die richtige Regel nur fürs Portal: aus
den Positionslichtern heraus.

**Behebung** (`builders/tunnel.gd`, eigene Datei): `const PORTAL_LAYERS := 2`, `pi.layers = PORTAL_LAYERS` im
`commit()`. Layer 2 ist die Bodenebene (Gelände, Fahrbahn, Wasser): `LIGHT_MASK` jedes Spots und Omnis = alles außer
Layer 2 (auch in R4s neuem Stand `0xFFFFF & ~2 & ~(1 << 19)`). Sonne, Mond, Umgebungslicht und Schatten bleiben
(Bilder bei Tag bitgleich mit R5, Abschnitt 4). Die Röhre (unbeleuchteter Shader mit eigenem Scheinwerferkegel) bleibt auf
Layer 1. Sobald R4 eine Abblendkante hat, darf der Fuß des Rahmens wieder auf Layer 1 (Kommentar an der Konstante).

**Gemessen** (PIL-Mittel 0–255, Rechtecke in 1280 × 720, „Hoch“):

| Stelle | Arcade | R5 5558bdc | FIX-R5 |
|---|---|---|---|
| U1 22 Uhr, Bild 00 (km 184,3) – Stirnwand über der Öffnung (560,268–720,284) | 39,47,63 (L 46) | 79,79,81 (L 79) | 50,57,68 (L 56) |
| U1 22 Uhr, Bild 00 – Flügelmauer links (515,320–540,342) | 36,44,59 (L 44) | 70,70,72 (L 70) | 45,50,61 (L 50) |
| U1 22 Uhr, Bild 00 – Hügel über dem Portal (605,180–650,230) | 16,31,23 (L 27) | 14,35,19 (L 30) | 14,35,19 (L 29) |
| DEV 21 Uhr, Bild 01 (km 48,8) – Stirnwand (560,238–650,254) | 39,47,63 (L 47) | 112,107,99 (L 107) | 51,58,69 (L 57) |
| DEV 21 Uhr, Bild 01 – Flügelmauer (440,300–460,318) | 36,44,58 (L 43) | 89,86,82 (L 86) | 46,52,62 (L 51) |

Die Stirnwand liegt jetzt im Blau der Nacht wie Arcade, ≈ 10 Stufen heller (Mondlicht auf hellem Beton; Arcade färbt
flach). Bilder, in denen der Kegel das Portal nicht erreicht (DEV 00/02, U1 01), sind bitgleich mit R5. Die senkrechten
hellen Streifen auf dem Hügel, die QA-R5 als „Lichtstreifen“ las, bleiben – sie kommen **nicht** vom Abblendlicht
(R5 und FIX-R5 dort gleich), sondern sind Mondschattierung der Hügelspalten (Arcades gesäte Höhenunterschiede je Spalte
geben jeder Spalte eine eigene Neigung) und die Mondschatten der Nadelbäume auf dem Grat; bei Tag fällt das nicht auf,
nachts schwach (Hinweis in 8).

**Wächter:** `test_tunnel.gd::test_portal_on_the_ground_layer_out_of_the_low_beam` (Portal auf Layer 2, `layers &
LIGHT_MASK == 0` mit R4s Konstante gelesen, Schatten an, Röhre auf Layer 1) – fängt die Mutation P1.

### 1.2 QR5-05 – Tests schützen alle R5-Regeln

| Mutation (wie QA-R5) | vorher | jetzt (gemessen, `mutate.py`, `mutations/results.json`) |
|---|---|---|
| B10 `night_albedo` des Pylons nicht gesetzt | nur `SCRIPT ERROR` (float(null)) | `test_dark_pylon_material_at_night` FAIL, 0 Skriptfehler (erst `!= null`, dann Wert 0,45 als Zahl) |
| B12 5 statt 7 Seile je Seite | grün | `test_koehlbrand_pylons_beacons_and_cables` FAIL (56 als Zahl, Arcades `for i in 7`) |
| B14 Brückenlampen nicht gebaut | grün | neuer `test_bridge_lamps_like_arcades_events` FAIL (Lampen = Arcades `bridge_lamp`-Ereignisse an Ludwigsbrücke und Ponte della Libertà, jede mit Lichteintrag) |
| T4 `set_zone` ohne `has_method` | grün | `test_set_zone_only_when_the_rig_has_it` FAIL (neues Rig `EnvWithoutZone`: kein Aufruf, `zone_calls` 0, `tunnel_state` folgt trotzdem dem Gesetz) |
| P1 (neu) Portal wieder auf Layer 1 | – | `test_portal_on_the_ground_layer_out_of_the_low_beam` FAIL |

Jede Mutation einzeln im Worktree, nur die zuständige Testdatei, Datei danach aus einer Sicherung zurück (`git status`
sauber geprüft). Grundlauf: `test_bridge` 11/11, `test_tunnel` 9/9.

### 1.3 QR5-06 – genauer Netzlauf

`check_tunnel_bridge.gd -- --full` vergleicht jetzt nach QA-R5s Verfahren genau mit Arcades Elementen derselben Strecke
(Einzelheiten im Dateikopf und in `docs/renderer-modern-tunnel-bruecken.md` §7): Pylone, Flugfeuer, 14 Seile je Pylon,
Fachwerkportale, Brückenlampen = Arcades Ereignisse; Wasser; Ufer an beiden Enden; Fachwerk/Bögen je Typ; nichts vom
Tragwerk über einer Spur zwischen 0,3 und 4,5 m; kein Seil näher als 1,5 m an einer Spur; ein Portal, ein
Ausfahrtsrahmen, Kappe wo Arcade die Röhre schließt, Nischen nach Arcades 150-m-Regel, mindestens Arcades zwei
Leuchtenreihen, jedes Tunnelsegment mit Röhre, nichts der Röhre über den Spuren, kein Hügelpunkt im Sichtkorridor der
Anfahrt (F7). Neu auch die Testetappe; `--only-stage=`, `--verbose`.

- **Ergebnis (gemessen):** `RENDER-CHECK tunnel_bridge_full OK – 122 Brücken {cable_stayed 12, canal 10, causeway 2,
  river 60, stone_arch 35, truss_arch 3}, 28 Tunnel exakt gegen Arcade geprüft (Pylone 44, Seile 616, Fachwerkportale 15,
  Brückenlampen 304, Nischen 72, Kappen 26), 0 mit Mängeln, 180 s` (`scan_full.log`).
- Der erste Lauf meldete 29 Flussbrücken ohne Pfeiler: Pfeiler sind Moderns eigene Zutat (Arcade zeichnet keine), eine
  kurze Flussbrücke überspannt ihr Wasser ohne – die Regel war meine, sie ist gestrichen (die Zahl steht in `--verbose`).
- **Wirkung** (gemessen, `mutate_scan.py`): Brückenlampen weg → „Ludwigsbrücke: Brückenlampen 0 statt 6“; 5 Seile →
  „Köhlbrandbrücke: Seile 40 statt 56“; Fachwerkportale weg → „Elbbrücken: 0 statt 5“; Nischen weg → „Sonnenbergtunnel:
  Nischen 0 statt 1“; Kappe weg → „Kappe 0 statt 1“ – jeweils Exit 1.

### 1.4 QR5-09 – Commit-Spitze am Gotthard (Leistung)

Nachgestellt mit QA-R5s Lauf (`run_stage.gd`, Bern – Mailand ab km 183, „deck“, 1280 × 800, Zeitraffer 4, 600 s
Wanduhr), Basis und FIX-R5 hintereinander (gemessen, Last 13–17):

PERF_U1_TABELLE

Lesart: Die Spitze ist Last, kein Code: im selben Lauf hatte die **Basis** 17,8 ms, FIX-R5 4,1 ms (die Simulation, die
R5 nicht berührt, hatte zugleich Spitzen von 452 bzw. 226 ms). Lastfest (A-11) gemessen, headless, Minimum aus 3
(`bench_r5.gd` von QA-R5, `perf/bench_new.log`): Commit je Tunnelstück höchstens **0,23 ms** (Gotthard) / **0,25 ms**
(Somport), Brückenstücke ≤ 0,61 ms (Elbbrücken) – weit unter dem deck-Budget 3 ms. Die Worker-Bauzeit am Tunnel
(Mittel 3,0 ms, max 4,2 ms) verzögert nur das Eintreffen eines Stücks (3,4 km Vorlauf). Darum keine Code-Änderung;
im Leistungstest des Nutzers bleibt `chunk_commit_ms_max` an Portalen zu beobachten (echte Hardware: abgeleitet).
