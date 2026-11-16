## 1. Nachgestellt

Beide hohen Befunde habe ich auf R4s Kopf nachgestellt, bevor ich etwas änderte (`m1/FIX-R4/sh/mshot.sh`, Modern
allein, dieselben Argumente wie QA-R4: N2N = Dortmund – Frankfurt km 121, 22 Uhr, Regen, Gran Turismo, Saat 14,
Autopilot, Verkehr, „Hoch“). Meine Bilder bei 2 s und 4 s sind **bildpunktgleich** mit denen der Prüfung
(`compare -metric AE`: 0) – das Bild ist bestimmt, die Arcade-Bilder der Prüfung gelten also auch für meinen Stand
(Arcade ist eingefroren). Gemessen (Median der Leuchtdichte 0–255, x 560–720, y 380–440, 2 s): Arcade 61, R4 **108**;
bei 4 s und 6,2 s steht über dem Auto 300 m voraus die rote Säule (`m1/FIX-R4/shots/head_N2N_01_crop.png`,
`b1_cmp_02.png`). Beide Befunde: bestätigt.

## 2. B1 – Spiegelungen auf der Straße statt in der Luft (behoben)

**Ursache** (bestätigt): der Streifen war ein waagrechtes Viereck in der Höhe des Bodens unter der Lampe, bis zu
0,6 × des Weges zur Kamera lang (Spiegelpunkt-Gesetz: bei 300 m rund 180 m). Steigt die Straße zum Auto hin an, liegt
es zwischen Auto und Kamera in der Luft und steht über der Augenhöhe als Säule über dem Auto.

**Behebung** (`flare.gdshader` `CE_STREAK`, `layers/flares.gd`, `layers/vehicles.gd`):
- Der Streifen ist ein Band aus 12 Abschnitten (`flares.gd` `streak_mesh()`, `STREAK_SECTIONS`) statt eines Vierecks.
- Die bisher ungenutzte **Basis der Instanz** trägt das Höhenprofil der Straße vom Lampenfuß bis zum Fuß der Kamera:
  die Höhe bei 1/6 … 6/6 des Weges relativ zum Fuß (Spalten 0 und 1), Spalte 2 x = 1 = „Profil da“
  (`flares.gd` `road_profile()`, `put_profile()`, statisch, mit Einheitstest). Der Shader legt jeden Punkt des Bandes
  auf die Catmull-Rom-Kurve durch die sieben Stützpunkte, 3 cm + 0,6 mm je Meter Abstand zur Kamera darüber.
- Die Augenhöhe im Spiegelpunkt-Gesetz ist die Höhe der Kamera über ihrem **eigenen** Fuß (auf einer gleichmäßigen
  Steigung gilt das Gesetz der ebenen Straße dann in der Ebene der Straße; vorher setzte die Steigung `hc` auf 0,5 m).
- Fahrzeuge: ein Profil je Auto (vom Heck `car.z` zur `camera_z`; alle Rückleuchten des Autos teilen es – 7 Aufrufe
  `height_at()` je Auto mit Spiegelung, nur bei nasser Straße). Laternen: je Lampe von der Straßenstelle, an der
  `_drop_of()` ihre Höhe misst (die Stelle wird jetzt mit gemerkt).
- Ohne Profil (Spalte 2 x = 0) liegt der Streifen wie bisher eben – das ist die Mutation, mit der ich die Prüfung
  geprüft habe.

**Prüfung** (neu, `tests/race3d/render/check_night_nass.gd` → „spiegelung“): nasse Nacht, Kassel – Würzburg vor der
Kuppe T2; das Programm sucht die sichtbare Stelle 120–520 m voraus mit dem größten Anstieg über den Kamerafuß
(gefunden: 296 m voraus, **21,8 m** höher), setzt dort ein bremsendes Auto und vergleicht das Bild mit und ohne
Spiegelungen (dieselbe Sekunde, Zeit angehalten). Gemessen: **0 Bildpunkte über dem Dach** des Autos, 15 darunter auf
der Straße – OK. **Mit der Mutation** (Profil aus): **1.207 Bildpunkte über dem Dach**, 0 darunter – FEHLER. Die
Prüfung bewacht den Befund also wirklich.

**Bild**: `bilder/02_N2N_22Uhr_Regen_4s_Spiegelung.jpg` (Arcade | R4 | FIX-R4) und `bilder/12_B1_Saeule_4s_6s.jpg`
(Ausschnitt 2×, R4 gegen FIX-R4 bei 4 s und 6,2 s – die Stelle aus R4s Clip): die Säule ist weg, die Spiegelung des
fernen Autos liegt als schmaler roter Streifen unter ihm auf der nassen Fahrbahn. Arcade zeigt dort nur einen Punkt –
die längere Spiegelung ist eine Zutat über Arcade hinaus, physikalisch richtig (nasse Straße zieht Rücklichter in die
Länge) und liegt jetzt dort, wo sie hingehört.

## 3. B2 – Nasse Fahrbahn im Abblendlicht (behoben)

**Ursache** (bestätigt): der gespiegelte Himmel war Teil der Albedo (`asph = mix(asph, sky / ambient, mirror)`), und
Abblendlicht und Lichtkegel multiplizierten diese Albedo wie hellen, matten Asphalt.

**Behebung** (`road.gdshader`, nach dem Prüf-Prototyp von QA-R4, aber vollständig): neben `base` (Bodengesetz, mit
der Himmelsspiegelung) führt der Shader `lit` – Asphalt × (1 − Spiegel), Markierung × (1 − 0,07 nass) ×
(1 − 0,35 Spiegel), Schnee und Start/Ziel-Karo wie `base`, dasselbe Nachtgesetz (`night_lift`); `EMISSION` =
Bodengesetz(`base`) + Lichter × `lit`. Sonne/Mond und Umgebung bleiben, wie sie waren (das Bodengesetz zeigt den
gespiegelten Himmel als seine eigene Farbe); trocken (`wet` 0) ist `lit` = `base` – bitgleich für trockene Bilder.

**Gemessen** (dasselbe Bild N2N 2 s, „Hoch“): Kegel **54** (Arcade 61, R4 108) = 0,88 × Arcade; in Zeile 372
Markierung 160 / Asphalt 47 (Weber 2,40; Arcade 213 / 60 = 2,55; R4 192 / 117). Wie in Arcade wird die nasse Straße
im Scheinwerfer dunkler als die trockene; der cremefarbene Fleck ist weg, die ferne Himmelsspiegelung bleibt.

**Prüfung** (neu, `check_night_nass.gd` → „nass_kegel“): N2 22 Uhr Regen, „Mittel“, Arcade und Modern im selben
Simulationsschritt; je Halbmeter 16–34 m vor der Kamera die eigene Spur (±25 px um ihre Mitte, Median) und die
durchgehende Randlinie daneben (hellster Bildpunkt in ±30 px) – Fenster statt Punkte, weil die Kurvenkamera von Modern
ein wenig in die Biegung schaut (A-3). Grenzen: Fahrbahn 0,7 … 1,15 × Arcade, Randlinie ≥ 0,8 × Arcades
Weber-Kontrast. Gemessen: **0,88 ×**, Randlinie **3,56 gegen 2,99 (1,19 ×)**, 37 Zeilen – OK. **Mit der Mutation**
(Lichter wieder auf `base`): **1,73 ×** (QA-R4: 1,77 ×) und **0,42 ×** – FEHLER.
(Ein erster Ansatz mit Punkten auf den gestrichelten Linien traf in Arcades Bild die Lücken – die Kurvenkamera; daher
die Fenster und die durchgehende Randlinie.)

**Bilder**: `bilder/01_N2N_22Uhr_Regen_2s_Kegel.jpg`, `bilder/03_N2N_SteamDeck_1280x800.jpg` (dieselbe Behebung im
Steam-Deck-Preset).

## 4. B3 – Silberner Gran Turismo nachts im Regen grau (offen, teilweise)

Nachgemessen (`check_night spielerauto`, Karosserie, R4): Helligkeit 0,93 ×, Sättigung 0,73 ×. Versuch: nachts nimmt
der Himmel, den Lack, Metall und Glas spiegeln, den Ton des Umgebungslichts bei seiner eigenen Leuchtdichte an
(`layers/vehicles.gd` `ENV_NIGHT_TINT`, `night_tint()` – Arcades Gesetz Sprite × Umgebungsfarbe; der Regen verdeckt
den Nachthimmel mit grauen Wolken). Gemessen: mit 0,8 **0,92 × / 0,77 ×**, mit 1,0 0,92 × / 0,78 × – also kommt der
neutrale Anteil **nicht** aus dem gespiegelten Himmel. Der Lack ist `#b2b7bd`, Metall 0,9; der Mond-Glanz ist schon auf
8 % (`coat_sun`). Im Bild (`bilder/01…`, `bilder/13_Spielerautos_nachts.jpg`) liest sich der GT weiter hellsilbern,
sein Sprite marineblau-grau. Ich habe es bei 0,8 gelassen (kleine, gerichtete Verbesserung, kein Schaden an den
anderen Lacken) und die Schranke `CAR_SAT_MIN` nicht auf 0,85 gehoben (wäre rot). **Offen für FIX-M2 B-06 / R7**
(Lack-Look): vermutlich die Helligkeit der senkrechten Flächen des Metalls bei Nacht (das untere Heck liest sich hell)
– eine Hälfte der Antwort ist die Nacht-Abdunklung des Metalls, nicht sein Ton.

## 5. B4 – Prüflücken (behoben)

- B1 und B2 haben je eine Prüfung, die bei der Mutation anschlägt (oben). Eigene Datei `check_night_nass.gd` (erbt von
  `check_night.gd`, wie die Wettertabelle): `check_night.gd` bleibt unter den 900 s je Datei von
  `tools/run_render_checks.sh`.
- `schneewall` misst jetzt auch das gebaute Netz: `TerrainBuilder._snow_banks()` meldet den höchsten Wallpunkt über dem
  Boden unter ihm (`bank_max_m`, auch in `debug()`); `check_weather` „schneewall“ verlangt 0,05–0,45 m.
  Einheitstest `test_weather` → `test_snow_bank_mesh_height` baut drei Stücke mit Schnee und prüft dasselbe (fängt die
  Mutationen U8 und R3 der Prüfung: `BANK_MAX_M` 0,95 und Profilscheitel × 2,6).
- `test_exit_ramp`: Nachglühen stetig (< 0,02 bei 59,5 m, kein Sprung > 0,02 je halben Meter – fängt U5) und zeitlich
  begrenzt (B6).
- `test_weather_follows_the_watchdog` (B5), `test_streak_follows_the_road_profile` (B1: Profil auf einer
  synthetischen Steigung, Lage in der Instanz, Band mit Abschnitten).
- `check_night spielerauto`: DEV-Fall (Limousine, 21 Uhr), Obergrenze der Sättigung 1,25 × (B7), `-- --fall=<Text>`
  wählt einzelne Fälle (Messen in 90 s statt 270 s).

## 6. B5 – Wetter folgt dem Wächter (behoben)

`weather.gd` `quality_lowered(levels)`: Teilchenzahl der niedrigeren Stufe (die ersten n Instanzen – der Shader setzt
jede Instanz nur nach ihrer Nummer, kein neuer Puffer), ihr Kasten, ihre Gischt; der Schnappschuss meldet die
gezeichnete Zahl (`drawn`). Einheitstest: 4.000 → 1.500, Kasten der Stufe 1, Gischt der Stufe. **Teilweise
unzutreffend**: `lights.gd` hatte `quality_lowered()` schon (Punktlicht-Pool) – nichts zu tun.

## 7. B6 – Nachglühen zeitlich begrenzt (behoben)

`environment_rig.gd` `exit_after_timed(d, dt)`: klingt mit dem ab, was weiter ist – Weg (`d` / 60 m) oder Zeit seit dem
Portal (`dt` / `EXIT_AFTER_S` 2 s, aus `view.time`, also bestimmt mit `--gfx-sync`). Die Zeit am Portal schätzt das Rig
beim ersten Bild hinter einer Ausfahrt aus Weg und Tempo – eine Etappe, die hinter einer Ausfahrt beginnt, zeigt kein
Nachglühen. Über 108 km/h entscheidet der Weg: R4s Look bleibt. Bilder `bilder/09–11_Tunnelausfahrt…` (141 km/h):
gleich R4 (beabsichtigt). Am Portal bleibt das Draußen milchiger als Arcades sattes Gras – Geschmacksfrage aus R4,
nicht Teil des Befunds.

## 8. B7 – Limousine nachts zu satt (behoben, innerhalb der Grenze)

Der Nacht-Schimmer nahm den vollen Ton des Modell-Lacks; Arcades Sprites sind im Studiolicht gewaschen (FIX-M2 B-06
hat das bei Tag gemessen). Jetzt nimmt der Schimmer den Ton aus dem um 35 % zur Leuchtdichte gewaschenen Lack
(`vpbr` `sheen_wash`, in `ModernMaterials.VEHICLE_LOOK`). Gemessen (Ausschnitt des Autos, gleiches Verfahren für beide
Stände, `m1/FIX-R4/sh/carcrop.py`): DEV 21 Uhr Sättigung Arcade 0,56, R4 0,74 (1,32 ×), FIX-R4 **0,68 (1,21 ×)**;
`check_night spielerauto` DEV 21 Uhr **1,00 ×** bei 0,87 × Helligkeit (Grenze ≤ 1,25 ×). Im Bild
(`bilder/06_DEV_21Uhr_Limousine.jpg`) ist sie weiter etwas leuchtender blau als das marineblaue Sprite – die Grenze
der Prüfung hält.

## 9. B8 – Blendviereck zuerst (behoben)

`environment_rig.gd` `_glare_material()`: `render_priority = RENDER_PRIORITY_MIN` – das Viereck wird vor allen anderen
durchsichtigen Dingen gezeichnet, Lichtpunkte, Regen und Glas jenseits des Portals danach. Nicht im Bild geprüft (die
Prüfung leitete den Fehler aus dem Code ab; ein bremsendes Auto 20 m hinter der Ausfahrt in einem Tunnel-Bild hätte
einen eigenen Prüfaufbau gebraucht).

## 10. B9 – Dateibesitz (Vertragsfrage)

Geändert: nur Dateien von R4 in W3 (Shader `road`, `vpbr`, Kern `environment_rig.gd`, `layers/{flares,vehicles,weather}`,
`builders/terrain.gd`, `modern_materials.gd`, R4s Tests, `docs/renderer-modern.md`) und `assets/shaders/modern/flare.gdshader`,
das in §5 keinen W3-Besitzer hat (wie bei R4 – der Shader von `flares.gd`). Probe-Zusammenführung (`git merge-tree`):
mit FIX-M2, R6 und FIX-R6 nur Konflikte in `tests/golden/modern_slice.{md5,env}`, mit R5 in `modern_slice.md5` und
`docs/renderer-modern.md` – dieselben wie bei R4, kein neuer Code-Konflikt (`vehicles.gd` mischt sich mit FIX-M2
automatisch). Keine Schwester-Branch ruft die geänderten inneren Funktionen (`_ground_drop`, `_drop_of`) auf.
