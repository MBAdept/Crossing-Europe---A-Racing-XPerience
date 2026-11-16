
## 17. Montage RINT-M2 (FIX-M2, R4, R5, R6, AS5aR1)

Die zweite Montage des Schubs M2 führt FIX-M2 (§14.10) mit den Bauabschnitten R4 (§15), R5 (§16), R6
(renderer-modern-bauten.md) und der Nacharbeit AS5aR1 der Stadtgebäude (docs/modelle.md) zusammen und setzt die
Entscheidungen der Leitung aus Vertrag §11.3 (A-18 bis A-22) um. Was sich dabei am Renderer änderte:

### 17.1 Abblendlicht: Glanz bleibt, Fahrzeuge dämpfen ihn im Material (A-20)

`layers/lights.gd` `SPOT_SPECULAR` ist wieder 0,5 (wie die Lampen-Omnis). Die Glanzkeulen eines Punkt- oder
Spotlichts, das von neben dem Auge kommt, nehmen `vpbr` und `glass` selbst heraus: `eye_lamp_spec` (Renn-Look der
Fahrzeuge 0, Studio und Kontaktbogen 1) über den Winkel zwischen Licht- und Blickrichtung (`eye_lamp_cos` 0,85 … 0,95:
volle Keulen unter x, keine über y; das Abblendlicht liegt ab etwa 18 m vor der Kamera innerhalb y, eine Laterne über
der Straße weit außerhalb). Gemessen, roter Lkw im Abblendlicht, 22 Uhr (Sonde, mittlere Leuchtdichte Arcade / neu):
20 m 57,0 / 63,0 (+10 %), 60 m 44,1 / 44,1; Mutation `eye_lamp_spec` 1 → 60 m 171,5 (48 % weiß).
Die Fahrbahn nahm dieses Licht nie (Ebene 2): die nasse Fahrbahn N2 22 Uhr ist mit `SPOT_SPECULAR` 0 und 0,5
pixelgleich – ihr Glanz kommt aus `inc/headlight.gdshaderinc` und `road.gdshader` (§15.4).

### 17.2 Bremsschein nach Tageslicht und Abstand (A-20)

`VehiclePose3D.model_glow_gain(role, a, lights, dist_m)`: der Zuschlag `MODEL_BRAKE_GAIN` 2,2 der Modell-Bremsleuchten
gilt bei Tag; nachts fällt er mit den Lichtern der Palette auf einen Anteil, der vom Abstand des Autos zur Kamera
abhängt (`brake_night_share`: 0,6 bis 22 m, 0,15 ab 60 m, dazwischen `smoothstep`). Ein Anteil für alle Abstände ging
nicht (0,35: Sportwagen 60 m +22 %, Limousine 20 m −32 %; 0,15: −1 % / −46 %). Das Blaulicht behält seinen Zuschlag
(nachts ohnehin etwa halb so viel Blau wie Arcade). Sonde 22 Uhr, rote Pixel Arcade / neu: Sportwagen 60 m 95 / 94,
Limousine 20 m 539 / 476, Sportwagen 20 m 567 / 454. Prüfung `check_vehicle_lights` „bremsschein“ (17.10).

### 17.3 Tönung der Platzierung auch für Modelle (A-19)

`builders/props.gd` legt jeder Instanz die Tönung der Platzierung bei (`tint` × `fallback_tint`, sonst Weiß);
`baked`, `vpbr` (statisch), `leaves` und `billboard` multiplizieren die Albedo damit wie Arcade das Sprite, Lampen
behalten ihre Farbe. Keine Instanz-Uniform. **Jedes MultiMesh der Requisiten trägt Farbe UND Custom-Daten**
(`INSTANCE_FLOATS` = 20: Transformation, Farbe, Custom): ein Modell Weiß als Farbe (`MODEL_COLOR`) und die Tönung als
Custom-Daten (r, g, b, 1), eine Vertretung die Tönung als Farbe und `NO_CUSTOM` (a = 0). Grund, mit Sonden gemessen
(Godot 4.7.2, Compatibility, llvmpipe): `INSTANCE_CUSTOM` liest bei Farbe ohne Custom-Daten (0, 1, 0, 1) und bei
Custom-Daten ohne Farbe, über `MultiMesh.buffer` gesetzt, Müll auf den echten Modellnetzen (über
`set_instance_custom_data()` richtig, aber je Instanz zu teuer) – der erste Stand dieser Montage zeigte leuchtend grüne
Fensterrahmen, Garagentore, Bäume und Windräder. Ohne Instanzdaten liest es (0, 0, 0, 0), ein `MeshInstance3D` 0:
a < 0,5 lässt die Albedo, wie sie ist (Fahrzeuge, `builders/city.gd`). Wer neue MultiMeshes mit diesen Shadern baut,
gibt ihnen beides oder keins.

### 17.4 Instanzbudget unter Last (A-19)

`check_instance_budget.gd` kann Verkehr einspeisen (`_inject_n()`, Testautos über
`tests/race3d/fixtures/vehicle_probe_renderer.gd`, Abstände wandern 20–540 m, jedes Auto durchläuft jede Stufe); dann
muss die Fahrzeug-Ebene 90 % ihres `INSTANCE_BUDGET` erreichen („nicht belastet“ sonst FEHLER). 48 gezeigte Autos
brauchen mehr Stufen, als das Budget fasst – die Ebene gibt nur Pool-Autos und verborgene Stufen frei –, darum gelten
mit eingespeistem Verkehr die Grenze der ganzen Szene (230) und die Ablehnung der Engine, und die Szene wird alle 10
Bilder gezählt. `instanzen_wald`: Dortmund – Frankfurt ab km 40, „Hoch“, 48 Autos, 20 s Sicht (Kopfzeit 2400 s);
neu `instanzen_stadt`: Würzburg – Nürnberg ab km 106 in die Stadt; `instanzen`: Kiel – Hamburg. Messwerte §17.10.

### 17.5 Tankstellendach ohne Stütze, Entscheid auf einem Arbeitsfaden (A-18)

An den drei Dächern, deren Stützen alle wegfielen (prag_leipzig km 148,08, sibiu_timisoara km 148,98, prag_nuernberg
km 233,13), stand eine Notstütze auf der Insel, die Arcade nicht hat. Jetzt hängt das Dach an einem Mast
(`station.gd`, Arten „mast“ / „mast_l“): zuerst rechts jenseits der Tafeln (Balken unter der Dachkante, Zugstangen über
dem Dach), sonst links jenseits des Seitenstreifens mit Zugstangen 7–9 m über den Spuren; an allen drei Dächern links.
`scan_f1` über das ganze Netz: Paare an Tankstellen-Endstützen 38 → 3, keines ≥ 6 px.
`ChunkStreamer.stats()` → `collect_by` misst die Hauptfadenzeit von `collect()` je Baustein. Gemessen (DEV, „Steam
Deck“, llvmpipe unter Last): Tankstelle bis 3,4 ms in einem Bild, über dem Budget von 2 ms. Der Entscheid der Stützen
läuft darum als `StationBuilder.CanopyJob`: der Hauptfaden sammelt nur, was er aus Strecke und Geländeprofil liest,
die Sichtlinien rechnet ein Arbeitsfaden (gestartet, wenn `collect()` ein Dach vorausschaut), auf einem eigenen Pfad
ab dem ersten Segment, das er braucht – deckungsgleich mit dem des Streamers, also unabhängig vom Startort (`startdep`:
1909 Dächer, 0 abweichende Entscheide; vorher 43). Netzweit dieselben Stützen (`scan_f1`: 3486).

### 17.6 Lichtebenen (A-18)

- `layers/lights.gd` liest die Stärke statischer Lampen jedes Bild aus dem Eintrag des Bausteins (`entry_energy`).
- `layers/flares.gd`: Lampen mit Stärke 0 kosten keine Instanz; optionale Schlüssel `"halo"` (Nahanteil statt
  `STATIC_HALO`) und `"glow": false` (kein Laternenschein). Das Straßenprofil der Spiegelung einer Laterne wird je Lampe
  gehalten, solange die Kamera sich weniger als 3 m bewegt (`PROFILE_KEEP_M`); `snapshot()` meldet
  `lamp_streak_profiles`, `lamp_streak_profile_max_m`, `lamp_streak_profiles_computed`.
- `builders/radar.gd`: der Blitz nutzt `halo` 1 statt des Ausgleichs in `FLASH_GAIN` (gleiches Bild) und wirft nachts
  einen Lichtkegel von 9 m auf die Fahrbahn.

### 17.7 Tunnel und Brücken (A-18)

- Die Blendfläche der Ausfahrt steht am wahren Röhrenende (`tunnel_state.exit_z` − 0,05 m, sonst die Segmentgrenze
  nach `end_km`); `check_tunnel_bridge` „U1_ausfahrt“ prüft die Überstrahlung gegen Arcade (mindestens 0,6 × Arcades
  Leuchtdichte 0,89 draußen) und dass der Rahmen nicht mitglüht.
- Die Fahrbahn in der Röhre zeigt von außen Arcades Tunnellicht: `builders/road.gd` liest `tunnel_state.light` jedes
  Bild und setzt `tunnel_out`, `tunnel_ambient`, `tunnel_fog`, `tunnel_darkness_m` in `road.gdshader`.
- Steinbrücken haben Arcades Balustrade (`roadside.gd` `stone_arch`): fünf Docken je Segment (0,14 m) zwischen Sockel
  und Handlauf, ein Pfeiler alle vier Segmente.
- Hausboote und Schiffe schwimmen auf dem Wasser des Brückenbausteins (+0,15 m, `BRIDGE_WATER_LIFT`).

### 17.8 Lack der Spielerautos (Leitungsnotiz 10)

Gemessen gegen Arcade (`check_night` „spielerauto“, Sättigung neu / Arcade): Limousine S1 0,95×, Testetappe 1,00×,
Kompakt N1 (Schnee, 22 Uhr) 1,23×, Gran Turismo N2 (Regen) 0,77× (Leuchtdichte 0,92×). Die Abweichungen gehen in
beide Richtungen und hängen am Lack des Modells (Asset): keine Konstante des Renderers bringt beide in ±15 %; offen
für die Modellnacharbeit.

### 17.9 Bekannte Lücken (Stand RINT-M2)

- Lack: Kompakt nachts satter, Gran Turismo im Regen blasser als Arcade (17.8).
- Abblendlicht: keine Hell-Dunkel-Grenze wie Arcades Kegel (Lichtkegel weich).
- Grenzstation Amsterdam – Lüttich km 210,175: eine Endstütze verdeckt die Tafel „town_ahead“ zu 22 % (keine
  Spieltafel nach A-18, gemeldet).
- Geländewasser unter Brücken (FIX-R5 8.6) und Mondlichtstreifen am Portalhügel (NACH-R5 N-01) offen.
- Kurveninnenseiten in Bergetappen: Sichtkorridor nach A-17 kommt mit R7.
- Lackflackern des weißen Autos (Testbuild 1): pausiert (A-21).

### 17.10 Prüfungen

