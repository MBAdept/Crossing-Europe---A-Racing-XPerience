## Befunde (neu in QA1)

### QA1-B1 hoch – Start jeder Etappe: Kamera 9 m zu weit vorn, Spielerauto im Countdown unsichtbar

Gemessen mit `tools/ab_shot.sh` (Kiel – Hamburg km 0, stehender Start mit Countdown, Mittel, Bilder bei 1 s, 3,3 s,
3,7 s, 4,5 s): Arcade zeigt das Auto im Countdown; **Modern zeigt kein Auto** – im Countdown nicht und auch 0,7 s nach
„LOS!“ (14 km/h) nicht. Bei 1,5 s (30 km/h) erscheint es, aber **viel zu groß und zu tief**: nur Dach und
Heckscheibe sind im Bild, das Heck liegt unter dem Bildrand (Ausschnitt `m1/QA1/diag/am3.png`). Das Starttor wirkt in Modern deutlich näher als in Arcade, und das große Schild
„Tankstelle 15 km“ rechts am Start fehlt im Bild. Die Modern-Bilder 00–02 sind bis auf HUD/Countdown gleich – die
Kamera bewegt sich in den ersten Metern nicht.

Ursache (Code gelesen): Beim Start steht das Auto bei `pos_z = 0`, die Kamera bei `camera_z = pos_z − 9 m = −9 m`
(`render.camera_distance_m`). `RoadPath3D` kennt nur z ≥ 0 (`first` ≥ 0, `_locate()` klemmt `_lt` auf 0 … 1):
`world()`/`frame_at()` für z < 0 liefern den Punkt bei z = 0 – die Kamera steht also 9 m zu weit vorn, bis das Auto 9 m
gefahren ist. `layers/vehicles.gd::_update_car` blendet ein Auto mit `z < z_lo` (Heck vor dem ersten Pfadpunkt) aus –
das Spielerauto (`z = pos_z − Länge/2 = −2,4 m`) fehlt deshalb im Countdown. Betroffen ist **jede Etappe** im normalen
Spiel (Start bei km 0); Attract-Demos, Leistungstest, Goldens und alle bisherigen A/B-Bilder starten bei km > 0 – darum
fiel es nicht auf.
Vorschlag für den Besitzer (Kern `road_path.gd` und `layers/vehicles.gd`, ab Welle 3 R4): den Pfad vor Punkt 0 gerade
fortsetzen (Arcade zeichnet die Straße hinter der Startlinie gerade weiter), die Straße der ersten Stücke ab z = −15 m
bauen und Autos zeigen, deren Körper hinter z_lo beginnt. Prüfung: ein Render-Check „Start bei km 0: Spielerauto an
Arcades Stelle“. Belege: `deliver/QA1/befund_start_km0_countdown_auto_fehlt.jpg`,
`deliver/QA1/befund_start_km0_nach_1_5s_auto_zu_nah.jpg`, `m1/QA1/diag/`.
Im Testbuild steckt der Fehler; er steht in `was_neu.md` als bekannter Fehler.
