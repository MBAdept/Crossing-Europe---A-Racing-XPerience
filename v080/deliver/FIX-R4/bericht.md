# FIX-R4 – Nacharbeit nach der Prüfung von R4 „Licht, Nacht, Wetter“

Paket FIX-R4, Basis `7f0eae2` (= `origin/wip/v080-r4`, R4s Kopf). Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5`, Zweig `worktree-wf_fd1de4ee-28b-5`,
gesichert als `origin/wip/v080-fix-r4`. Kein Vorgänger (weder `STAND.md` noch der Zweig existierten) – frisch mit
`git merge --ff-only 7f0eae2` begonnen. „gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte
Kerne, Last 10–17 durch andere Pakete); alles über Steam Deck, echte Grafikkarten und die Wirkung auf Menschen ist
**abgeleitet**. Alle Läufe mit absolutem `XDG_DATA_HOME`, `--graphics=` ausdrücklich, schwere Jobs nacheinander mit
`nice -n 10` (`QA_M2_FERTIG` lag vor).

## Urteil

Die beiden hohen Befunde der Prüfung sind behoben und jetzt bewacht: die Rücklicht- und Laternen-Spiegelungen liegen
auf der Straße (keine rote Säule mehr über fernen Autos an Steigungen), und Abblendlicht und Lichtkegel beleuchten auf
nasser Fahrbahn nur noch den matten Anteil (Kegel 0,88 × Arcade statt 1,77 ×, Randlinie 1,19 × Arcades Kontrast statt
0,42 ×). Beide neuen Prüfungen schlagen an, wenn man die Behebung zurücknimmt (Mutation gemessen). Die niedrigen
Befunde B5, B6, B8 sind behoben, B4 (Testlücken) geschlossen, B7 (Limousine nachts zu satt) innerhalb der von der
Prüfung vorgeschlagenen Grenze. **Offen bleibt B3**: der silberne Gran Turismo liest sich nachts im Regen weiter
hellgrau statt blaugrau – mein Versuch (Himmelston der Spiegelung nachts) hebt die Sättigung nur von 0,73 × auf
0,77 × Arcade; die Messung zeigt, dass der neutrale Anteil nicht aus dem gespiegelten Himmel kommt (Lack-Paket).
Nachts im Regen ist Modern damit jetzt in der Luft **und** auf der Straße mindestens gleichwertig zu Arcade
(Regen, Gischt, Spiegelungen, die auf der Fahrbahn liegen), nur das silberne Spielerauto ist heller und grauer als
sein Sprite.

## Befunde der Prüfung QA-R4

| Nr. | Schwere | Ergebnis | Kurz |
|---|---|---|---|
| B1 | hoch | **behoben, geprüft** | Spiegelungen folgen dem Höhenprofil der Straße (Band mit 12 Abschnitten, Profil in der Instanzbasis); Prüfung `check_night_nass` „spiegelung“: 0 Bildpunkte über dem Dach (Mutation: 1.207) |
| B2 | hoch | **behoben, geprüft** | `road.gdshader`: Lampen und Abblendlicht nur auf dem diffusen Anteil; Kegel 54 statt 108 (Arcade 61 von 255); Prüfung „nass_kegel“ 0,88 × / Randlinie 1,19 × (Mutation: 1,73 × / 0,42 ×) |
| B3 | mittel | **offen** (teilweise) | Himmelston der Spiegelung nachts (`ENV_NIGHT_TINT` 0,8): GT-Sättigung 0,73 × → 0,77 × (mit 1,0: 0,78 ×); Rest gehört ins Lack-Paket (FIX-M2 B-06 / R7) |
| B4 | mittel | **behoben** | neue Prüfungen für B1/B2 (eigene Datei `check_night_nass.gd`), Schneewall aus dem gebauten Netz (`bank_max_m`), Nachglühen stetig und zeitlich begrenzt (Einheitstest), Wetter-Wächter (Einheitstest) |
| B5 | niedrig | **behoben, geprüft** | `weather.gd quality_lowered()`: Teilchenzahl, Kasten und Gischt der niedrigeren Stufe (Einheitstest); `lights.gd` hatte den Haken schon (Befund dort unzutreffend) |
| B6 | niedrig | **behoben, geprüft** | Nachglühen höchstens `EXIT_AFTER_S` = 2 s nach dem Portal (`exit_after_timed`), über 108 km/h unverändert |
| B7 | niedrig | **behoben** (innerhalb der Grenze) | Schimmer aus dem um 35 % gewaschenen Lack (`sheen_wash`); DEV 21 Uhr Limousine: Sättigung 1,32 × → 1,21 × (Ausschnitt) bzw. 1,00 × (`check_night`); Obergrenze 1,25 × und DEV-Fall in `check_night spielerauto` |
| B8 | niedrig | **behoben** | Blendviereck der Ausfahrt `render_priority` −128 (vor allem Durchsichtigen) |
| B9 | niedrig | **Vertragsfrage** | `flare.gdshader` habe ich (wie R4) geändert – ohne W3-Besitzer; Modern-Hashes siehe Tore |

(Einzelheiten, Zahlen und Bilder unten.)

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

**Bild**: `bilder/02_N2N_22Uhr_Regen_4s_Spiegelung.jpg` (Arcade | R4 | FIX-R4) und `bilder/12_B1_Saeule_4s_oben_6s_unten_Arcade_R4_FIX.jpg`
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
8 % (`coat_sun`). Im Bild (`bilder/01…`, `bilder/13_Spielerautos_nachts_Arcade_links_FIX_rechts.jpg`) liest sich der GT weiter hellsilbern,
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

## 11. Bilder (angesehen; Arcade-Bilder = die der Prüfung QA-R4 am selben Simulationszustand)

Alle in `deliver/FIX-R4/bilder/` als Arcade | Modern R4 (`7f0eae2`) | Modern FIX-R4, „Hoch“ wenn nicht anders genannt.
Modern-Bilder mit `m1/FIX-R4/sh/mshot.sh` (dieselben Argumente wie `tools/ab_shot.sh`, nur der Modern-Lauf; die
Arcade-Bilder der Prüfung gelten, weil Arcade eingefroren und das Bild bestimmt ist – meine R4-Bilder waren
bildpunktgleich mit denen der Prüfung).

| Bild | Stelle | gegen Arcade (ehrlich) |
|---|---|---|
| `01_N2N_22Uhr_Regen_2s_Kegel.jpg` | Dortmund – Frankfurt km 121, 22 Uhr, Regen | **besser in der Luft, jetzt gleichwertig auf der Straße**: der cremefarbene Fleck im Abblendlicht ist weg (Kegel 54 gegen Arcade 61, R4 108), die Markierung im Kegel klar; Regen, Gischt, Himmelsspiegelung bleiben. Arcades Kegel liest sich als etwas hellerer, weicher Fleck – Moderns nasser Kegel ist dezenter (0,88 ×). **Schlechter**: der GT ist hellsilbern statt marineblau-grau (B3, offen) |
| `02_N2N_22Uhr_Regen_4s_Spiegelung.jpg`, `12_B1_Saeule_…jpg` | dieselbe Stelle, 4 s und 6,2 s | die rote Säule über dem Auto 300 m voraus ist weg; die Spiegelung liegt als schmaler roter Streifen unter dem Auto auf der Straße (Arcade: ein Punkt) |
| `03_N2N_SteamDeck_1280x800.jpg` | dieselbe, „Steam Deck“ | dieselbe Behebung im Deck-Preset; Regen sichtbar, 16:10 gefüllt |
| `04_N1_22Uhr_Schnee_2s.jpg`, `05_N1_SteamDeck_1280x800.jpg` | Hamburg – Hannover km 71, 22 Uhr, Schnee | wie R4 (trockene Straße: keine Änderung durch B2); Schneefall, Wälle, Kompakt gelb wie das Sprite – besser als Arcade |
| `06_DEV_21Uhr_Limousine.jpg` | Teststrecke km 48, 21 Uhr | Limousine etwas weniger leuchtend als bei R4 (Sättigung 1,32 → 1,21 × Arcade), weiter etwas blauer als das marineblaue Sprite; sonst gleichwertig |
| `07_C1_19Uhr30.jpg` | Frankfurt km 221, 19:30 | unverändert gegen R4 (gleichwertig bis besser als Arcade) |
| `08_S1_Abend_19Uhr12.jpg` | Kiel – Hamburg km 2, 19:12 | unverändert bis auf die Limousine (minimal blauer); Sonnenscheibe, Gegenlicht – besser als Arcade |
| `09/10/11_Tunnelausfahrt_Tag_….jpg` | Teststrecke km 52,8, 12 Uhr, 1,0 / 2,4 / 3,8 s | gleich R4 (141 km/h: der Weg entscheidet über das Nachglühen); in der Röhre gleichwertig, am Portal milchiger als Arcades sattes Gras (Geschmack, aus R4) |
| `13_Spielerautos_nachts_…jpg` | die vier Fälle von `check_night spielerauto` (Arcade links, FIX-R4 rechts) | GT: hell statt marineblau (offen); Kompakt gleichwertig; Limousine S1 und DEV gleichwertig bis etwas leuchtender |

Clip: `deliver/FIX-R4/clip_nacht_regen_verkehr_N2N.mp4` (A/B, 20 s, 60 fps, „Hoch“) – angesehen (`bilder/14_Clip_N2N_Bilder_4_6_10_14_18s.jpg`): in keinem Bild eine Säule über einem Auto (bei 6,2 s, wo R4s Clip sie bis an den oberen Bildrand zeigte, nichts), die Spiegelungen naher Autos liegen als lange rote Streifen auf der nassen Fahrbahn und wandern mit; der Kegel bleibt dezent; der GT hell (B3).
Nicht neu gerendert: Tunnelausfahrt- und Schneefall-Clip (meine Änderungen ändern dort nichts Sichtbares: Tunnel
bei 141 km/h nach dem Weg, Schnee ohne nasse Straße – R4s Clips gelten).

## 12. Tore (auf dem Endstand, Befehle und Ausgaben)

Endstand `b156763` (Code-Stand `3f00551`, danach nur die Hash-Zeile). Logs in `m1/FIX-R4/gates/`. Alle Läufe mit
absolutem `XDG_DATA_HOME`, `nice -n 10`, nacheinander (Skript `m1/FIX-R4/sh/gates.sh`; der erste Lauf der
Render-Prüfungen wurde nach drei Dateien vom Zeitlimit des Werkzeugs beendet, die übrigen 20 liefen einzeln mit
`m1/FIX-R4/sh/render_rest.sh` – dieselbe Datei-Liste, dieselben Einstellungen).

| Tor | Befehl | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, ohne Fehler (`m1/FIX-R4/import.log`) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **319 Skripte geprüft, 0 fehlerhaft** |
| Einheits- und Kopfprüfungen | `tools/run_tests.sh` (Vollauf 1 von 2) | **„Tests bestanden (1057 s)“: 765 Einheitstests, 0 fehlgeschlagen**; alle CHECK-Dateien grün (149 OK-Zeilen, 0 FEHLER), darunter `check_light_cap` „deckel“ (≤ 8 Punktlichter / 2 Spots / 18 Kegel), `kern_zeit` 0,284 ms, `renderer_zeit` 0,766 ms, `test_far_ground_water`, `test_props` |
| Arcade-Gleichheit | `tools/golden.sh check` (einmal, am Ende) | **GOLDEN arcade: 20 von 20 identisch**, **GOLDEN arcade-ui: 17 von 17 identisch** |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` | **5 von 6 identisch**, `modern_s1_nacht` ANDERS – gewollt (Nacht-Lack B3/B7); Bild angesehen (`gates/modern_keep/modern_s1_nacht_00.png`: Limousine marineblau, lesbar), Hash ersetzt (Commit `b156763`, gleich `modern-make`); **modern-gles OK** (max. 2/255, PSNR 73,2 dB) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **24 von 24 Dateien OK** (2 Arcade, 22 Modern), kein Shader-, Skript- oder Instanzfehler. Darunter: `check_night` 4/4 (Fahrbahn N1 +4,9 %, Spielerauto 4 Fälle, Verdeckung 0 Pixel, Blaulicht), **`check_night_nass` 2/2** (nass_kegel 0,88 × / 1,19 ×, spiegelung 0 Pixel über dem Dach), `check_weather` 5/5 (Schneewall im Netz ≤ 0,35 m), Tabellen (Regen 22 Uhr jetzt 0,89 × / Kontrast 0,84 ×, vorher 0,97 × / 1,17 × – B2 nimmt das falsche Licht aus dem Kegel; Grenzen 0,8 … 1,35 / ≥ 0,5), `check_start_km0` 3/3, `check_terrain_cover` 7/7 inkl. K1, `check_light_base` 2/2, `check_vehicle_lights` (F6 an N1), `check_occlusion`, `check_instance_budget_wald` (1.486 s, Grenze 2.700 s) |
| Fairness | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | **F1 0 Fälle bis 270 m** (99.424.500 Stichproben, 128 Etappenrichtungen), Außenspuren 0 bis 260 m, **F2 ≤ 0,593 / 0,596 / 0,555**, **F3 0 von 5.923**, **F7 0 von 2.011.532**, Modell 0 abweichend (150 s) |
| Weg | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | **kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000)** |
| Ganze Etappe | `tests/race/run_stage.gd` unter Xvfb, Kiel – Hamburg 21 Uhr Regen, Limousine, „Niedrig“, Zeitraffer 16 (`m1/FIX-R4/sh/stage.sh`, wie R4) | Kopf und Basis **ganz durchgefahren, 0 Skript-/Shaderfehler**, gleiches `ERGEBNIS` (95 km, Schnitt 123,4 km/h, 0 Zusammenstöße); Leistung unten |
| Geschützte Korrekturen des ersten Testbuilds | in den Läufen oben | `check_start_km0`, `check_terrain_cover` mit K1, `check_light_base`, `test_far_ground_water`, `test_props` grün |

## 13. Leistung (llvmpipe, gemessen; echte Hardware abgeleitet)

Ganze Etappe Kiel – Hamburg, 21 Uhr, Regen (nasse Straße: Spiegelungen, Gischt, Regen), Limousine, Saat 11,
„Niedrig“, Zeitraffer 16, unter Xvfb (`m1/FIX-R4/sh/stage.sh` = R4s Lauf), Kopf (`b156763`) dreimal und Basis
`7f0eae2` (Kopie `m1/FIX-R4/base`) zweimal, abwechselnd, Last 15–17 durch andere Pakete. Alle fünf: 95 km, gleiches
`ERGEBNIS` (Schnitt 123,38 km/h, 0 Zusammenstöße), 0 Skript- und Shaderfehler, 528 Bilder.

| Lauf | `render()` Mittel / max (ms) | Einhängen max (ms) | Zeichenaufrufe | Dreiecke | Bildzeit Median (ms) | `flares` / `vehicles` Mittel (ms) | Spitzen > 20 ms (Ebene: ms) | Simulation max (ms) |
|---|---|---|---|---|---|---|---|---|
| Basis 1 | 3,67 / 39,5 | 9,03 | 77 | 76.330 | 276 | 0,24 / 0,78 | streamer 23 | 110 |
| Basis 2 | 3,85 / 81,6 | 8,60 | 77 | 76.330 | 268 | 0,20 / 0,78 | streamer 80 | 74 |
| Kopf 1 | 4,21 / 228,6 | 5,25 | 77 | 76.902 | 283 | 0,28 / 0,84 | lights 226, weather 45, streamer 31 | 313 |
| Kopf 2 | 4,24 / 144,1 | 1,76 | 77 | 76.902 | 277 | 0,49 / 0,95 | streamer 142, flares 121, vehicles 78 | 61 |
| Kopf 3 | 4,31 / 167,1 | 6,21 | 77 | 76.902 | 270 | 0,26 / 0,81 | streamer 165, lights 96 | 246 |

Gelesen (gemessen, llvmpipe): das Mittel von `render()` liegt im Kopf 0,4–0,6 ms höher; der größte Teil davon sind
einzelne Bilder mit 100–230 ms in **unveränderten** Teilen (`lights`, `streamer`), zur selben Zeit wie Hänger der
ebenfalls unveränderten Simulation (bis 313 ms) – Last der Maschine. Ohne die Spitzen kosten die Profile der Streifen
`flares` +0,02–0,06 ms und `vehicles` +0,03–0,06 ms je Bild (7 Aufrufe `height_at()` je Auto mit Spiegelung, je
Laterne mit Spiegelung). Zeichenaufrufe gleich (77), Dreiecke +572 (+0,7 %: die Streifen sind Bänder aus 12
Abschnitten statt Vierecken), Einhängen unverändert klein. Auf dem Steam Deck abgeleitet: vernachlässigbar (≈ 0,1 ms
Skript, 24 statt 2 Dreiecke je Spiegelung). `kern_zeit` (0,284 ms) und `renderer_zeit` (0,766 ms) im Vollauf grün.

## 14. Vertragsfragen

1. `assets/shaders/modern/flare.gdshader` hat in §5 W3 keinen Besitzer; R4 und FIX-R4 haben ihn geändert (der Shader
   der Ebene `flares.gd`, die R4 gehört). Vorschlag: der Besitzer von `flares.gd` besitzt ihn.
2. `tests/golden/modern_slice.{md5,env}` (W3 „–“): `modern_s1_nacht` hat sich durch B3/B7 gewollt geändert; ich habe die
   eine Zeile mit dem Hash des von `modern-check` gerenderten Bildes ersetzt (gleich dem Ergebnis von `modern-make`,
   die übrigen fünf sind identisch). RINT-M2 erzeugt die Liste nach dem Zusammenführen ohnehin neu.
3. §6 R4 Abnahme kennt die nasse Nacht nicht (QA-R4 Vertragsfrage 3) – jetzt geprüft durch `check_night_nass.gd`
   (Kegel 0,7 … 1,15 × Arcade, Randlinie ≥ 0,8 ×, keine Spiegelung über dem Dach); Vorschlag, das in §6 aufzunehmen.
4. Die Instanzbasis der Streifen trägt Daten statt einer Drehung (Profil der Straße) – nur möglich, weil die Knoten der
   Ebene eine eigene `custom_aabb` haben und der Shader die Basis sonst nicht nutzt; bei einer Änderung des
   MultiMesh-Formats (z. B. 2D-Transform) muss das Profil umziehen. Nicht vertragsrelevant, aber eine Falle.

## 15. Für die nächsten Pakete

1. **FIX-M2 B-06 / R7 (Lack)**: der silberne Gran Turismo nachts im Regen (B3): Sättigung 0,77 × Arcade, hell statt
   marineblau-grau. Der gespiegelte Himmel ist es nicht (mit vollem Himmelston 0,78 ×). Zu prüfen: die Helligkeit der
   senkrechten Metallflächen nachts (das untere Heck liest sich hell), danach `CAR_SAT_MIN` in `check_night` auf
   0,85 heben. `check_night -- --only=spielerauto --fall=Turismo` misst in 90 s.
2. **RINT-M2**: Konflikte wie bei R4 nur in `tests/golden/modern_slice.{md5,env}` (alle) und `docs/renderer-modern.md`
   (R5); `vehicles.gd` mischt sich mit FIX-M2 automatisch (gemessen mit `git merge-tree`). Nach dem Zusammenführen
   `golden.sh modern-make` (Bilder ansehen). FIX-M2s `player_paint()` (Entsättigung bei Tag) und mein `sheen_wash`
   (Nacht) ergänzen sich – die Limousine in der Dämmerung danach ansehen (beide wirken dort zum Teil).
3. **Pakete mit eigenen Spiegelungen** (R5 Wasser, R6 Tankstelle): Streifen auf nasser Straße bekommen ihr
   Höhenprofil über `flares.gd` `road_profile()` / `put_profile()`; statische Lampen über `add_lamps()` bekommen es
   automatisch.
4. **PERF**: das Profil kostet je Auto mit Spiegelung 7 Aufrufe `height_at()` (gemessen +0,06 ms `vehicles`,
   +0,03 ms `flares` im Mittel der nassen Nachtetappe); auf dem Deck abgeleitet vernachlässigbar.
5. **QA**: `test_chunk_services` „threaded“ und `test_engine3_checks` „thread“ sind lastabhängig (QA-R4) – falls sie im
   Vollauf rot sind, nicht FIX-R4.


## 16. Commits und Dateien

Zweig `worktree-wf_fd1de4ee-28b-5` → `origin/wip/v080-fix-r4` (jeder Commit gepusht):
`259ec2d` Spiegelungen auf dem Straßenprofil, nasser Kegel nur diffus, Wetter folgt dem Wächter (WIP) ·
`c94eae6` Prüfungen nasse Nacht, Lack nachts (WIP) · `3f00551` Lack nachts gemessen, Fallfilter, Doku ·
`b156763` Modern-Änderungsmelder `modern_s1_nacht` neu – Bild angesehen.
Geändert (18 Dateien, +689 / −72, nur R4-Dateien in W3 und `flare.gdshader`): `assets/shaders/modern/{flare,road,vpbr}.gdshader`,
`scripts/race3d/{environment_rig,modern_materials}.gd`, `scripts/race3d/layers/{flares,vehicles,weather}.gd`,
`scripts/race3d/builders/terrain.gd`, `tests/race3d/render/{check_night,check_weather}.gd`, neu
`tests/race3d/render/check_night_nass.gd`, `tests/unit/race3d/{test_weather,test_environment_rig}.gd`,
`tests/golden/modern_slice.{md5,env}`, `docs/renderer-modern.md` (§15.2, 15.4, 15.6, 15.7, 15.9). Keine eingefrorene
Arcade-Datei, kein `race_session.gd`/`race_renderers.gd`/Konfiguration.
Arbeitsdateien: `m1/FIX-R4/` (Skripte `sh/`, Bilder `pics/`, Prüfbilder `rc/`, Tore `gates/`, Etappen `stage/`).
