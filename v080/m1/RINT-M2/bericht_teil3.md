
### Notiz 7 – Dächer ohne Stütze hängen wie die Grenzdächer; scan_f1 0 Paare ≥ 6 px (A-18): **erfüllt**

- Die drei Tankstellendächer, deren Stützen alle wegfielen (prag_leipzig km 148,08, sibiu_timisoara km 148,98,
  prag_nuernberg km 233,13), hingen bisher an einer Notstütze auf der Insel (Arcade hat keine; sie verdeckte eine
  Kurventafel aus 210 m zu 89 %). Jetzt Mast mit Zugstangen (`station.gd`, „mast“ rechts jenseits der Tafeln, sonst
  „mast_l“ links jenseits des Seitenstreifens bei −9,625 m, Zugstangen 7–9 m über den Spuren); an allen drei links.
- `scan_f1` über das ganze Netz: Paare an Tankstellen-Endstützen 38 → 3, **keines ≥ 6 px auf einer Spieltafel**. Das
  einzige verbliebene Nicht-Arcade-Paar ≥ 6 px: Grenzstation Amsterdam – Lüttich km 210,175 Endstütze gegen die Tafel
  „town_ahead“ (22 %, keine Spieltafel nach A-18) – gelistet.
- Unit-Test (Mast verdeckt keine Tafel, steht außerhalb des Korridors).

### Notiz 8 – collect() je Baustein ≤ 2 ms auf „Deck“ (A-18): **erfüllt im Messlauf – Sichtlinien auf dem Arbeitsfaden, Vorwärmen in Stücken; Tankstelle höchstens 1,36 ms (Mittel 0,11)**

@@NOTE8@@

### Notiz 9 – Lichtebenen: **erfüllt**

- `lights.gd` liest die Stärke statischer Lampen jedes Bild (`entry_energy`, Unit-Test
  `test_static_lamp_energy_is_read_every_frame`); `flares.gd` überspringt Stärke 0 (Blitzer zwischen den Blitzen,
  dunkle Countdown-Lampen kosten keine Instanz); Schlüssel `"halo"` und `"glow": false`; der Blitzer nutzt `halo` 1
  statt des Ausgleichs in `FLASH_GAIN` (gleiches Bild) und wirft nachts einen 9-m-Lichtkegel. Unit-Tests der Schlüssel.

### Notiz 10 – Lack ±15 % zu Arcade, wo eine Konstante es löst: **gemessen, keine Konstante löst es → gelistet**

Sättigung neu / Arcade (`check_night` „spielerauto“ auf dem Merge-Stand): Limousine S1 0,95×, Limousine Testetappe
1,00×, **Kompakt N1 (Schnee, 22 Uhr) 1,23×**, **Gran Turismo N2 (Regen) 0,77×** (Leuchtdichte 0,92×). Die zwei
Ausreißer gehen in entgegengesetzte Richtungen; eine Renderer-Konstante (`paint_desat`, `paint_base`) bringt den
einen nur auf Kosten des anderen und der beiden passenden in ±15 %. Der Gran Turismo ist im Modell silbern, Arcades
Sprite dunkel blaugrau (Sonde 22 Uhr Regen, Bild in den A/B-Bögen N2) – ein Asset-Befund. Offen für die
Modellnacharbeit (§7).

### Notiz 11 – Tunnel, Brücken, Kleinkram: **erfüllt**

- (a) Blendfläche der Ausfahrt bei `tunnel_state.exit_z − 0,05 m`; `check_tunnel_bridge` „U1_ausfahrt“ misst gegen
  Arcade (mindestens 0,6 × Arcades 0,89 draußen, Rahmen glüht nicht mit) – grün (§4).
- (b) Fahrbahn der Röhre von außen in Arcades Tunnellicht (`road.gd` liest `tunnel_state.light`, `road.gdshader`
  `tunnel_out/ambient/fog/darkness_m`).
- (c) Steinbrücken mit Arcades Balustrade: fünf Docken je Segment (0,14 m, 0,24–0,92 m hoch) zwischen Sockel und
  Handlauf, ein Pfeiler (0,56 × 1,32 m) alle vier Segmente – nach Arcades `_balustrade`, nicht 0,35 m wie im Auftrag
  (Abweichung, §6).
- (d) Hausboote und Schiffe +0,15 m (`BRIDGE_WATER_LIFT`), schwimmen jetzt auf dem Brückenwasser.
- (e) Laternen-Spiegelung (NACH-R4 N1): Profil je Lampe gehalten, solange die Kamera < 3 m fährt; Schnappschuss
  meldet Streifen, größte Profilhöhe, neu gerechnete Profile. Prüfung (N2) `check_night_nass` „laternen“ auf der
  Steigung Kassel – Würzburg km 61,6 (die Köhlbrandbrücke ist im Profil eben, gemessen 0 an jeder Startstelle): Profil
  bis 15,8 m, 4 von 160 Profilen gerechnet; mit flachem Profil (Mutation) FEHLER.

### Notiz 12 – kein Eingriff gegen das Flackern: **befolgt** (A-21).
