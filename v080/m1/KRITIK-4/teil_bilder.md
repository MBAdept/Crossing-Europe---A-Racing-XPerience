## 8. Für die Nacharbeit (AS4-N) und die anderen Pakete – in dieser Reihenfolge

1. **M1 Pylon** vor dem Kiel–Hamburg-Testbuild: Seile an die Deckkante, Fächer ≤ 60 m, eine Stufe; besser Pylon ohne
   Seile + Seile vom Renderer (R2 jetzt, R5 später). Danach Bild 01 mit denselben Argumenten wiederholen
   (`tools/ab_shot.sh … --stage=kiel_hamburg --from=kiel --start-km=77.4 --start-speed=50 --shot-times=1,2.5,4,6`).
2. **M2** R2: Schiffe auslassen, solange es kein Wasser gibt.
3. **M3/M6** Shader-Besitzer: Tagesfarbe für Kanal 12; danach AS4-N: Scheiben-Leuchtfarbe Sprite-Licht × 0,7–0,8,
   alle Scheiben einer Fassade gleiche Tagesfarbe. Messen wie hier: Bildpixel der Scheiben bei Tag, Fensterleuchtdichte
   nachts gegen Arcade an Paris–Tours km 131,3.
4. **M4** Fabrik-Glasbänder, **M5** Pylon eine Stufe, **M7** Mühlenflügel zweite Stufe, **M8–M10** Kleinteile.
5. Werkzeuge für die nächste Runde (nicht eingecheckt): `m1/KRITIK-4/tools_kritik/`
   (`k4_scene.gd` mit `dist2`, `outline2`, `close`, `approach`; `mesh_probe.gd`; `texel_probe.gd` – Achtung: Godot
   wickelt Vorderseiten im Uhrzeigersinn, die Normalen des Kreuzprodukts zeigen nach innen). `prop_scene.gd` mit
   `--look=race` liegt nur auf dem AS3-Zweig – beim Zusammenführen mitnehmen.

## 9. Bilder und Filme (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `01_rennen_pylon_seile_in_der_fahrbahn.jpg` | M1/M2: Kiel–Hamburg km 77,9 / 78,3 / 79,0, Arcade \| Modern |
| `02_rennen_dorf_tag.jpg`, `03_rennen_dorf_nacht.jpg` | Paris–Tours km 129–131: Haus und Kirche, Mittag und 23 Uhr |
| `04_rennen_altstadt_abend.jpg` | Kassel–Würzburg km 201,6–204,8, 21 Uhr |
| `05_rennen_stadt_steamdeck.jpg` | Hannover-Einfahrt, Steam-Deck-Voreinstellung, 1280×800 |
| `06_rennen_bueroturm.jpg`, `07_rennen_fabrik_nacht.jpg` | Dresden–Leipzig km 111–113; Bremen–Dortmund km 2–3 nachts |
| `10`–`14_*_abstaende_tag_daemmerung_nacht.jpg` | Spielkamera 30/50–400 (600) m, Modell über Arcade-Sprite, 12 / 19:30 / 23 Uhr |
| `20_umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera (IoU-Tabelle 5.1) |
| `21_nahansichten_tag.jpg`, `22_nahansichten_nacht.jpg` | je Modell: Anfahrt, schräg, Straßenseite, oben, Rückseite |
| `23_fenster_tag_braun_blau.jpg` | M3 |
| `24_fabrik_dreiecke_nacht.jpg` | M4 |
| `25_stufenwechsel.jpg`, `27_pylon_stufenwechsel.jpg` | Stufenwechsel Mittel/Hoch/Nacht; M5 |
| `26_flimmern.jpg` | Viertelpixel-Test Modell gegen Sprite |
| `28_nachtfenster_arcade_gegen_modern.jpg` | M6 |
| `29_kirche_hell_im_rennen.jpg` | Kirche im Rennen heller als das Sprite (M10) |
| `30_film_pylon.mp4`, `31_film_portal.mp4`, `32_film_muehle.mp4` | Anfahrt mit 120 km/h, 30 Bilder/s, Spielkamera, Stufenwahl mit Hysterese |

## 10. Prozess und Werkzeuge (was die Prüfung von AS4 verfehlen ließ)

- Die Renn-A/B-Bilder von AS4 endeten 120–260 m vor dem Pylon; die Vorbeifahrt (≤ 40 m, auf der Brücke) wurde nie
  gezeigt – genau dort liegt M1. Brückenteile und Straßenmöbel brauchen ein Rennbild **auf** dem Bauwerk.
- `prop_scene.gd --look=race` gibt es nur auf dem AS3-Zweig (`be866d2`); die Prüfbilder von AS4 entstanden im kleinen
  Prüf-Rig (überstrahlte Putzwände). Das Werkzeug sollte vor den nächsten Modellpaketen zusammengeführt werden.
- Weder Kontaktbogen noch Prüfszene haben Wasser: die Wasserlinie der Schiffe ließ sich nur mit einer eigenen
  Prüf-Wasserfläche beurteilen (Vorschlag: Option `--water` in `prop_scene`).
- Der Prüfer sieht keine lageabhängigen Fehler: eine Prüfung „kein Teil eines `bridge`-Requisits unter 2,5 m Höhe
  innerhalb der halben Deckbreite“ hätte M1 gefunden.
- Messwerte des Stufenwechsels hängen vom Ausschnitt ab (Pylon: 3,2 % bei AS4, 58,5 % an der echten Lage x 7,5 m):
  an der seitlichen Lage aus der Zählung messen.
- `ab_shot.sh` mit Autopilot beschleunigt (50 → 141 km/h in 6 s, nachts bis 200 km/h): Stellen werden schneller
  passiert als geplant; Startgeschwindigkeit nahe der Reisegeschwindigkeit wählen.
