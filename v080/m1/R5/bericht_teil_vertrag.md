## 9. Vertragsfragen (mit Beleg)

1. **Inventar B / §6 R5 nennt „bridge deck … railings per type“ als R5-Ausgabe** – in Welle 3 zeichnen Deck und Geländer
   `builders/road.gd` und `builders/roadside.gd` (R4, Tabelle §5 Spalte W3 mit A-8). R5 baut so, dass es mit beiden
   arbeitet (Tragwerk hinter `RAIL_BACK_M` 0,32 m der Geländerdicke), ändert sie aber nicht; die fehlende Balustrade
   der Steinbrücken (Bild `stein_01`) steht unter Abschnitt 8.2. Vorschlag: Geländer an Brücken in R5s Eigentum, oder
   §6 R5 streicht sie.
2. **Nachtrag „Boats … R5 sets them on the water surface“** – Schiffe und Hausboote setzt `builders/props.gd` (R4) mit
   `h` = −Tiefe auf die Wasserzeilen des Geländes; R5s Wasser liegt 0,15 m darüber (`WATER_LIFT`, gegen Z-Kampf mit den
   Geländezeilen). R5 kann die Schiffe ohne Zeile in `props.gd` nicht anheben; genaue Änderung Abschnitt 8.1.
3. **Inventar B: „tunnel ambient and fog, exposure ramp at the exit“ als R5-Ausgabe** – nach Entscheidung 4 der Leitung
   bei R4 (`EnvironmentRig.set_zone`). R5 liefert die Zone (`set_zone("tunnel", amount)`, `tunnel_state` mit `exit_m`,
   `exit_in_sight`); die Belichtungsrampe fehlt bis R4 sie baut (Ausfahrt 0,226 gegen Röhre 0,449, gemessen).
4. **Regel für „-s“-Skripte und feste Verweise auf den Arcade-Renderer** – `road.gd`, `roadside.gd`, `tunnel.gd`,
   `bridge.gd`, `lights.gd`, `flares.gd`, `vehicle_pose3d.gd` nennen `RoadRenderer.*` fest; ein „-s“-Skript, das eine
   davon per `preload` lädt, kompiliert nicht („Identifier not found: SpriteDB“, gemessen an `check_terrain_plan` mit
   R5s `far_ground.gd`, behoben). Der Vertrag sagt es nur für die Skripte selbst (§2), nicht für die Dateien, die sie
   vorladen; ein Satz in §4 (Konstanten Arcades als gepinnte Kopie, wie `GroundLook.GROUND_BLEND_M`) würde es klären.
