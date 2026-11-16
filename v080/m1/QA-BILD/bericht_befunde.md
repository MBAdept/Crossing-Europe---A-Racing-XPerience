## 1. Befunde (Schwere: Blocker / hoch / mittel / niedrig)

Jeder Befund: wo – was – Beleg (gemessen/abgeleitet) – Nachstellen – Abhilfe. Bildpfade relativ zu diesem Ordner.

### B1 hoch – Tunnel sind in Modern offenes Gelände (andere Etappen des Testbuilds)
- Wo: jede Tunnelstrecke, z. B. U1 (Bern–Mailand km 186, Gotthard) und DEV (dev_testetappe km 48–50). Kein
  `builders/tunnel.gd` (R5, Welle 3); `builders/terrain.gd` legt auch in Tunnelreihen Gras an.
- Was: keine Röhre, keine Wände, kein Portal, kein Hügel – grünes Gelände unter schwarzem Himmel, das HUD meldet
  „TUNNEL“. Arcade zeigt Röhre, Lampen, Notgehweg. Wirkt kaputt, nicht wie ein Platzhalter.
- Beleg (gemessen, Bild): `ab_mittel/U1_ab_00.jpg`, `U1_ab_01.jpg`, `DEV_ab_00.jpg` (Portal und Hügel fehlen), `DEV_ab_01.jpg`.
- Nachstellen: `m1/QA-BILD/tools/ab.sh <ordner> medium U1 DEV -- --shot-times=2,6`.
- Abhilfe: vor dem Testbuild eine Minimalröhre (Kasten aus Wänden und Decke in Arcades Tunnelfarbe je Tunnelreihe,
  Gelände dort weglassen, Portal als Wand mit Öffnung) – oder Modern im Testbuild auf Etappen ohne Tunnel beschränken
  und es in den Hinweisen sagen. Kiel–Hamburg selbst hat keinen Tunnel. In der Lückenliste der Zusammenführung fehlt
  dieser Punkt.

### B2 hoch – Tankstelle an S2 liest sich nicht (Tutorial-Moment von Kiel–Hamburg)
- Wo: Kiel–Hamburg km 13,6–15 (Tankspur); fehlender Builder `station.gd` (R6).
- Was: kein Dach mit „TANKSTELLE“, keine Insel mit Bordstein, keine gelbe Linie; Zapfsäulen stehen im Gras; nachts
  dunkler Vorplatz ohne Dachbeleuchtung. Gerade hier zeigt das Tutorial „in 1,4 km kommt die Tankstelle“.
- Beleg: `ab_mittel/S2_ab_00.jpg`, `ab_varianten/S2H22_ab_00.jpg` (gemessen, Bild).
- Abhilfe: für den Testbuild Arcades Dach als Ersatz (Kasten mit Arcades Dachflächen wie bei den Kasten-Fahrzeugen,
  Lampen über `add_lamps`), Insel/Bordstein und gelbe Linie im Fahrbahn-Shader; sonst R6 vorziehen.

### B3 hoch – Köhlbrandbrücke ohne Geländer, Wahrzeichen Hamburgs fehlen
- Wo: Kiel–Hamburg km 80–82 (S4).
- Was: (a) keine Brückengeländer, dunkles Wasser beidseits – liest sich als Damm (bekannt); (b) **neu**: Elbphilharmonie
  und Michel stehen in Arcade bei 6 s am Horizont, in Modern fehlen sie ganz. Arcade zeichnet Wahrzeichen bis
  Sichtweite × 2 (hier 1.800 m, `RoadRenderer.landmark_fade`, voll deckend bis 1.296 m, ohne Aufpoppen); in Modern setzt
  sie nur der Requisiten-Builder in geladenen Stücken, `builders/landmarks.gd` (R7) fehlt. Gemessen (Sonde
  `probe/landmarks.gd`, ab km 80): die Elbphilharmonie wird bei 1.018 m Weg gesetzt, der Michel bei 1.012 m – jenseits
  des Nebelendes (900 m), wo die Requisiten-Shader sie ausdithern; sichtbar werden sie erst unter etwa 765 m und dann
  stark vernebelt (voller Tiefennebel, B7).
- Beleg: `ab_mittel/S4_ab_00.jpg`, `S4_ab_01.jpg`, `details/crop_s4_landmarks.jpg` (Bild),
  `pruefungen/wahrzeichen_hamburg.log` (gemessen).
- Abhilfe: Geländer als einfacher Zaun im Randausstattungs-Builder auf Brückensegmenten; Wahrzeichen jenseits der
  Stücke als Ersatzbild am Pfad bis Arcades Reichweite (Haken der Ebene `backdrop` oder ein kleiner `landmarks.gd` mit
  Sprite-Ersatz), Dunst nach `RoadRenderer.landmark_fade`.

### B4 hoch – Ziel- und Starttor fehlen
- Wo: S5 (Ziel Hamburg), C1 (Ziel Frankfurt voraus); `builders/gantry.gd` (R6) fehlt.
- Was: nur das Schachbrett auf der Fahrbahn; Arcades Brücke „ZIEL“ fehlt (bekannt).
- Beleg: `ab_mittel/S5_ab_00.jpg`, `details/crop_c1_far.jpg`.
- Abhilfe: Minimal-Tor (zwei Pfosten + Banner mit Arcades Bild) vor dem Testbuild.

### B5 hoch – Spielerauto nachts mit weißen Glanzflecken (Mond im Klarlack)
- Wo: `assets/shaders/modern/vpbr.gdshader` `light()`, Klarlack-Spitze `dr = d_ggx(ndh, mix(0.001, 0.1, coat_roughness))`
  ohne Bezug zur Lichtstärke; nachts ist das gerichtete Licht der Mond.
- Was: zwei weiße Flecken auf Dach und Kofferraum der Limousine, sobald der Mond vor dem Wagen steht.
- Beleg (gemessen): DEV 21 Uhr, Wagenausschnitt 560–720 × 490–600: p95-Leuchtdichte 193 gegen Arcade 51, Mittel 39 gegen
  34 (`details/crop_dev_car.jpg`); S1 22 Uhr: p95 112 gegen 50 (`details/crop_s1h22.jpg`).
- Nachstellen: `ab.sh <ordner> medium DEV S1H22`.
- Abhilfe: Klarlack-Spitze nachts dämpfen (Faktor `mix(1.0, 0.08, ce_night)`) oder ihre Spitzenhelligkeit auf die
  Anzeige-Helligkeit der Mondscheibe begrenzen; danach `paintcmp.py` bei 22 Uhr erneut.

### B6 hoch – kein Wetter in der Luft (bekannt, R4)
- N1 ohne Schneefall, N2 ohne Regen und Gischt; Fahrbahn wird nass bzw. bekommt Schneeränder (`ab_mittel/N1_ab_*`,
  `N2_ab_*`). Für Nacht-/Wetter-Etappen ist Modern damit sichtbar schwächer als Arcade.

### B7 mittel – Nebel: Requisiten und Fahrzeuge anders als Boden und als Arcade
- Wo: `baked`, `leaves`, `billboard`, `vpbr`, `sign` nehmen den vollen Tiefennebel der Engine; nur `terrain.gdshader`
  schreibt `FOG` mit Arcades 0,7 × t.
- Was: (a) ferne Bäume als graublaue „Geisterbäume“ auf grünen Feldern, mit dunklem Kontaktschatten darunter; (b)
  Fahrzeuge an der Sichtgrenze verlieren Kontrast gegen Arcade (siehe 3.2, abgeleitet ≈ (1 − t): 30 % bei 0,839 × Sicht).
- Beleg: `details/crop_s1_far.jpg`, `crop_s1_far_nofog.jpg` (mit `--gfx-debug=cover` sind es grüne Bäume), Werte
  129/137/145 gegen Arcade 26/37/19 (gemessen); Kontrast (abgeleitet aus den Mischformeln).
- Abhilfe: dasselbe `FOG`-Gesetz wie das Gelände in `baked/leaves/billboard`; für `vpbr`/`sign` Arcades Gesetz
  (multiplikative Tönung, kein zusätzlicher Dunst über der F5-Ausblendung) und die Pflicht-Render-Prüfung
  „Objekt an der Sichtgrenze < 3 % Kontrast“ (§4.9.2) nachziehen.

### B8 mittel – Sichtkorridor räumt Straßenränder leer
- Wo: `builders/props.gd` `drop_reason()` → „corridor“ (F7 + A-3).
- Was: an T1/T2 fehlen Baumgruppen, Kiefern und ein Findling links der Straße, ersetzt durch 0,5-m-Grasbüschel;
  Modern wirkt dort kahl gegen Arcade.
- Beleg (gemessen): Sonde `m1/QA-BILD/probe/drops.gd` an T2 nach 2 s: in den Stücken 63–70 (−205 … +560 m) 35
  Requisiten als „corridor“ weggelassen, 47 gesetzt; `details/crop_t2_left.jpg`, `crop_t2_far.jpg`.
- Abhilfe: Entscheidung der Leitung (A-3 sieht sie für Zwischenstand 2 vor): Korridor aus der echten Sehne statt der
  stärksten Krümmung rechnen und/oder weggelassene Bäume quer nach außen hinter den Korridor versetzen statt durch
  Büschel zu ersetzen; danach `modern_sight.gd -- --full`.

### B9 mittel – Spielerautos sehen anders aus als ihr Sprite
- Limousine: steile Heckscheibe mit sichtbarem Innenraum statt Arcades Fließheck – wirkt wie ein anderes Auto
  (`details/crop_s1_car01.jpg`); Kompakt mit schwarzem Dach (T3/T4). Lackfarbe dagegen gut (Kofferraum mittags
  Farbton −2,3 … −2,7°, Helligkeit +1 … +3 %, gemessen). Abhilfe: AS1R-Nacharbeit gegen die Sprite-Silhouette.

### B10 mittel – Leistungsbudgets nur kopflos belegt; GL-Pfad und Einzelspitzen
- Wo: `tests/race3d/check_modern_stage.gd` (`kern_zeit`, `renderer_zeit`), `check_vehicles` (`leistung`) – alle
  kopflos; `ChunkStreamer` (Einhängen), `layers/vehicles.gd`.
- Was (gemessen unter Xvfb, ganze Etappe Kiel–Hamburg, Last 4–14): `render()` im Mittel 2,10 / 1,92 / 2,23–2,67 ms
  (Niedrig / Mittel / Hoch; Budgets 1,2 / 1,5 / 2,0), Median 1,6 ms; Stück-Einhängen bis 9,5 / 20,4 ms (Budget 3; kopflos
  4,8–5,1 ms); Einzelbilder mit 45–479 ms `render()` in 7 von 11 Fahrten an wechselnden Stellen, meist in der
  Fahrzeug-Ebene, ohne Bau/Rückschnitt im selben Bild – wahrscheinlich Rechenzeitentzug der VM, aber nicht bewiesen.
  Laden 15–37 s (RINT-B 5,2–5,6 s), davon 12–28 s Aufwärmen.
- Beleg: Tabelle in Abschnitt 5, `pruefungen/kh_*`, `spikes_*`.
- Abhilfe: Budget-Prüfungen zusätzlich unter Xvfb mit Referenzuhr (perf_clock) laufen lassen; die Zeitstempel je Haken
  (wie `probe/qa_spikes.gd`) in `perf_stats` aufnehmen, damit der Leistungstest des Decks zeigt, welche Ebene eine
  Spitze trägt; auf einer ruhigen Maschine die 45–479-ms-Bilder nachstellen.

### B11 mittel – Pflicht-Render-Prüfungen aus §4.9.2 fehlen noch
- „Objekt an der Sichtgrenze unter 3 % Kontrast“ (F4/F5), „mittlere Helligkeit und kein schwarzes/NaN-Bild je Wetter ×
  Stunde“ und „OpenGL ES = OpenGL“ gibt es nicht als Prüfung. Die ES-Gleichheit habe ich von Hand gemessen (max 2/255,
  PSNR 71,8 / 88,0 dB – bestanden); die Kontrastprüfung ist wegen B7 wichtig. Aufgabe für QA1 (Welle 2).

### B12 niedrig – Kleinigkeiten
- Blattkarten-Kronen mit gezackten Kanten (Alpha-Schnitt ohne Glättung) – `details/crop_s3_tree.jpg`.
- Fernes Straßenstück jenseits einer Kuppe in reiner Nebelfarbe mit Dither-Punkten der ausblendenden Bäume
  (`details/crop_t2_rock.jpg`).
- N1: Fernboden-Bahn unter dem Horizont 75/82/94 gegen Arcades 37–40 – wirkt wie eine Nebelbank
  (`details/crop_n1_horizon.jpg`).
- Fahrbahn: vergossene Fuge neben der Spurlinie als lange dunkle Linie (wie ein Riss), Flicken als harte dunkle
  Rechtecke, nahe Randlinie weich/fleckig (`details/crop_t1_traffic.jpg`, `crop_s1_edge.jpg`, `crop_s1_car01.jpg`).
- Keine Sonnenscheibe mittags (Designentscheidung, bekannt).
- Lkw-Heck nachts im eigenen Abblendlicht fast weiß überstrahlt (30 m, `pruefungen/save/occlusion_lkw.png`); bei
  40–60 m liest sich das Konturband gut (`details/crop_s2h22_truck.jpg`).
- Blick in die Kurve schiebt an T3 ein Winkelschild unter den Tacho (`ab_mittel/T3_ab_01.jpg`).
