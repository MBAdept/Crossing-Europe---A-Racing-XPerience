## 2. Neue Daten für R4 (duck-typed, R5s Datei)

Beide Befunde, die an R4 hängen (QR5-02 Fahrbahn in der Röhre, QR5-03 Ausfahrt), brauchen Werte, die nur R5 kennt.
Ohne eine fremde Datei anzufassen, legt `builders/tunnel.gd` sie jetzt in seine Eigenschaft `tunnel_state` (lesbar über
`renderer.builder("tunnel")`, dokumentiert in `docs/renderer-modern.md` §15.1 und `renderer-modern-tunnel-bruecken.md` §2.4,
Unit-Tests in `test_tunnel.gd`):

- `tunnel_state["light"]` – das Licht der Röhre in diesem Bild, genau die Uniforms von `tunnel.gdshader`:
  `ambient_in`, `ambient_out` (Arcades Tunnelumgebung, von außen × (0,5 + 0,5 × Lichter)), `fog` (`Palette.TUNNEL_FOG`),
  `darkness_m`, `peek_m`, `cam_tunnel_z`, `lights`. Damit kann R4s Fahrbahn in der Röhre Arcades warmes Tunnellicht zeigen.
- `tunnel_state["exit_z"]` – Straßen-z, an dem die Röhre wirklich endet (Segmentgrenze nach `end_km`, wie Arcades
  Tunnelsegmente; INF draußen). `exit_m` misst wie bisher bis `end_km`.

Ohne Leser ändert beides nichts (Bilder bitgleich, Abschnitt 4).

## 3. Probe mit R4s Stand (QR5-03) – gemessen in einer Scratch-Kopie

Damit die Leitung weiß, was nach RINT-M2 an der Ausfahrt zu sehen ist, habe ich R4s Code (`git diff 6e48405
origin/wip/v080-fix-r4` ohne `docs/` und `tests/golden/`, sauber angewendet) auf diesen Kopf gelegt – nur in
`m1/FIX-R5/r4mix` (danach gelöscht), nichts davon ist committet – und U1 bei Tag und Nacht gerendert:

| U1 Ausfahrt 12 Uhr, Bild 01 (km 201,7) | Arcade | FIX-R5 allein | FIX-R5 + R4 (fix-r4) | + R4-Fläche an `exit_z` − 0,05 |
|---|---|---|---|---|
| Rahmen der Ausfahrt, oberer Balken (500,265–680,269) | (Arcade: kein Rahmen) L 157 | 166,130,86 (L 134) | 253,247,185 (L **244**, ausgebrannt) | 166,130,86 (L 134) |
| Gras jenseits der Öffnung (470,285–530,325) | 181,248,160 (L 227) | 59,77,24 (L 69) | 137,166,86 (L 154) | 134,161,82 (L 150) |

- **R4s Belichtungsrampe löst QR5-03**: das Draußen ist überstrahlt (L 69 → 150; Arcade 227), das „Licht am Ende des
  Tunnels“ ist da (`bilder/u1_ausfahrt_12uhr_01.jpg`, `ausschnitt_u1_ausfahrt_mit_r4.jpg`).
- **Aber** R4 setzt die Fläche bei `end_km` − 0,6 m; die Röhre endet erst an der Segmentgrenze danach. Dadurch liegt die
  Fläche vor R5s Ausfahrtsrahmen und den letzten Röhrenmetern – der Rahmen glüht als heller Ring (L 244). Mit der Fläche
  bei `exit_z` − 0,05 m (eine Zeile in R4s `environment_rig.gd`, Abschnitt 8 Punkt 1) bleibt der Rahmen Beton (L 134, gleich
  FIX-R5 allein) und das Draußen überstrahlt. Das ist die genaue Änderung für R4.
- Nachts mit R4s Stand: das Portal bleibt dunkel wie bei FIX-R5 allein (R4s neue `LIGHT_MASK` schließt Layer 2 weiter
  aus); die Fahrbahn in der Röhre bleibt grau (QR5-02 bei R4 offen).

## 4. Bilder – angesehen, ehrlich gegen Arcade

`bilder/` (Bögen Arcade | R5 5558bdc | FIX-R5 bzw. Arcade | FIX-R5; Ausschnitte `ausschnitt_*`), 1280 × 720 „Hoch“,
Steam Deck 1280 × 800 „deck“. Arcade-Bilder und R5-Bilder sind QA-R5s Renderings (meine Nachstellung des R5-Kopfs war
mit ihnen bitgleich, Abschnitt 1.1); FIX-R5-Bilder aus `m1/FIX-R5/shots/{fix1,fix2}` mit dem Code-Endstand (spätere
Commits ändern nur `tunnel_state` – ohne Bildwirkung, belegt durch bitgleiche Tagbilder).

**Bitgleich mit R5** (gemessen, MD5, `cmp.py`): U1 Anfahrt 12 Uhr (2 Bilder), U1 innen (2), U1 Ausfahrt (3), Somport
12 Uhr (3), Köhlbrandbrücke 22 Uhr (3), DEV 21 Uhr Bild 00/02, U1 22 Uhr Bild 01 – überall dort, wo der Abblendkegel das
Portal nicht erreicht. Der Fix ändert also nur, was er soll. Für alle übrigen Orte (Köhlbrand Rampe/Ende/Pylonspitzen,
Holtenau, B1, Elbbrücken, Stein, Kanal) gelten R5s und QA-R5s Bilder unverändert: FIX-R5 ändert dort keine Zeile Code.

| Ort | Bild | gegen Arcade | gegen R5 | Beobachtung |
|---|---|---|---|---|
| U1 22 Uhr, 60–70 m vor dem Portal | `u1_nacht_00/01`, `ausschnitt_u1_nacht_portal` | **gleich bis besser** (vorher schlechter) | besser | Stirnwand und Flügelmauern im Nachtblau wie Arcade statt bis oben angestrahlt; Rahmen, Laibung und Gesims bleiben als Form lesbar (Arcade: flache Fläche). Die Röhre leuchtet warm. Fahrbahn in der Röhre grau (R4, QR5-02). |
| U1 22 Uhr, Anfahrt bis in die Röhre | `u1_nacht_nah_fix` | – | – | Portal dunkel bis zur Einfahrt, innen Paneele, Gehwege, Leuchten; kein Himmel. |
| DEV 21 Uhr | `dev_21uhr_00–02`, `ausschnitt_dev_portal_21uhr` | **gleich bis besser** (vorher schlechter) | besser | Bild 01: Stirnwand L 107 → 57 (Arcade 47); die Wand liest sich nicht mehr wie bei Tag. |
| Somport 22 Uhr | `somport_22uhr_00–02` | **besser** | (R5 hatte kein Nachtbild) | Rahmen dunkel wie Arcades Portal, Röhre mit Paneelen, SOS-Nische, Notausgang; Fahrbahn in der Röhre grau statt Arcades warm (R4). |
| U1 12 Uhr | `u1_anfahrt_12uhr_00` | besser (wie R5) | bitgleich | Tag unverändert. |
| U1 Ausfahrt 12 Uhr | `u1_ausfahrt_12uhr_01`, `ausschnitt_u1_ausfahrt_mit_r4` | allein gleich; mit R4 + `exit_z` gleich bis besser | bitgleich | siehe Abschnitt 3. |
| Steam Deck 22 Uhr / 12 Uhr | `deck_u1_nacht_00/01`, `deck_u1_anfahrt_00/01` | Nacht gleich bis besser, Tag besser | – | Modern füllt 16:10, Arcade mit Balken; Portal nachts dunkel auch in „deck“. |

**Ehrliches Urteil:** Wo R5 baut, ist Modern jetzt auch **nachts am Portal** nicht mehr schlechter als Arcade, sondern
gleich bis besser (Form des Portals lesbar, dunkel wie Arcade, ≈ 10 Stufen heller durch Mondlicht). **Klar besser als
Arcade** sind weiter Röhre, Wasser, Ufer, Seile, Fachwerk. **Nicht besser** bleiben die drei Stellen, die an R4 hängen:
Fahrbahn in der Röhre von außen (grau statt warm, QR5-02), Ausfahrt ohne Überstrahlung, solange R4 nicht gemergt ist
(mit R4 + der Zeile aus Abschnitt 8 Punkt 1 gelöst, Abschnitt 3), Steinbrüstung (QR5-04). Schwach sichtbar nachts: Spaltenstreifen
auf dem Portalhügel im Mondlicht (Abschnitt 8).
