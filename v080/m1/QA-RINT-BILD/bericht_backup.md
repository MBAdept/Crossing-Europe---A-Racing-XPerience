# QA-RINT-BILD – unabhängige Prüfung der zweiten Montage M2 (`9b02f05`, wip/v080-rint-m2)

Stand: in Arbeit (wird laufend ergänzt). Linse: Bild in jeder Lage, Fairness, Leistung. Keine Commits, kein Push.

## 0. Rahmen und Messgüte

- Arbeitsbaum `wf_9927a373-337-2` auf `9b02f05` (ff), Basis `515dd51` als zweiter Arbeitsbaum (detached) – beide importiert.
- Alle Spielläufe mit absolutem `XDG_DATA_HOME` unter dem Arbeitsordner, `--graphics=` ausdrücklich, `nice -n 10`,
  `LP_NUM_THREADS=2`, ein schwerer Lauf zur Zeit (Sperrdatei `heavy.lock`).
- Die Maschine war während der ganzen Prüfung **stark belastet** (Last 8–14 auf 4 Kernen; andere Agenten mit nice 10
  und 19): ein Modern-Bild mit Ladephase brauchte 6 min statt 2–3 min. Bildzeiten sind darum nur zwischen Läufen
  derselben Stunde vergleichbar; Zähler (Draw-Calls, Primitive, Instanzen, Speicher) sind lastunabhängig.
- llvmpipe (Software-OpenGL): alles über echte GPU / Steam Deck ist **gefolgert**, nicht gemessen.
- Ein Vorgänger dieses Auftrags lief am 16.11. bis S1–S3 und wurde durch einen Containerneustart gestoppt; seine
  Bilder S1–S3 und die Sichtprüfungen (gleicher Stand `9b02f05`) sind übernommen, alles andere ist neu.

## 1. Fairness (F1–F7, §11.3)

### 1.1 Sichtprüfungen (gemessen, Kopf `9b02f05`)

`godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (146 s) und `modern_path_check.gd -- --full` (63 s):

| Kriterium (D14, §11.3) | Vertrag | gemessen | Urteil |
|---|---|---|---|
| F1 alles Arcade-Sichtbare ≤ 270 m im Kegel | 0 Fälle | 0 Fälle in 99.424.500 Stichproben (erster Fall bei 280 m); Außenspuren 0 bis 260 m in 326,7 Mio. | erfüllt |
| F2 Anhalteweg / Sichtweite | ≤ 0,60 | 0,593 trocken (Saragossa – Pau km 170,6), 0,596 Regen (Bukarest – Sibiu km 187,3), 0,555 Schnee | erfüllt (knapp, wie bisher) |
| F3 Kuppen | 0 später und im Anhalteweg | 0 von 5923 Zielen (Fahrzeug), 0 (Schild) | erfüllt |
| F7 Gelände im Sichtkorridor | 0 | 0 von 2.011.532 Querschnittsseiten | erfüllt |
| Modell der Sichtprüfung = ausgelieferte Kamera | 0 abweichend | 394.011 Stichproben, größte Abweichung 0,0002 px | erfüllt |
| Pfad: Abstand / Schleifen | ≥ 250 m / ≥ 2000 m | 267,6 m / 2064 m | erfüllt |

Was diese Tests **nicht** sehen: Verdeckung durch Bauten, Dächer, Häuschen, Brückenteile (sie rechnen nur Gelände).
Darum zusätzlich die Verdeckungssonde unten. A-17 (Hüllkurve statt Band) ist noch nicht gebaut (R7) – heute gilt
das alte Band d²/8R, das die Kurveninnenseiten zu weit leert (siehe Bild-Befunde).

### 1.2 Verdeckungssonde an neuen Bauten (gemessen)

Eigene Sonde (`qa_occl.gd`, nach dem Muster von `check_occlusion.gd`): echte Rennszene „Hoch“, stehend, ohne
Verkehr; ein Testauto (Limousine silber) in drei Spuren (−3,75 / 0 / +3,75 m) bei 20 … 260 m; Bild mit und ohne
Auto, geänderte Pixel in einem Kasten um die projizierte Wagenmitte, geteilt durch die erwartete Wagenfläche
(≥ 0,5 = sichtbar). „road“ = die Sichtlinie läuft unter der Fahrbahn (Kuppe) – nirgends der Fall.

| Stelle (12 Uhr bzw. Stellenzeit, „Hoch“) | neue Bauten im Blick | kleinster sichtbarer Anteil 20–260 m, 3 Spuren | Urteil |
|---|---|---|---|
| Kiel – Hamburg km 14,3 (Tankstelle km 14,6–14,9) | Dach, Säulen, Mast, Shop | 1,00 (alle 45 Stellungen voll sichtbar) | gut |
| Kiel – Hamburg km 77,4 (Köhlbrandbrücke) | Pylone, Seile, Geländer | 1,00 | gut |
| Kiel – Hamburg km 88,0 (Hamburg Mitte) | AS5a-Stadthäuser, Laternen | 0,76 (links, 230 m) | gut |
| Würzburg – Nürnberg km 102,6 (Altstadt) | Fachwerk, Bürgerhäuser | 0,83 | gut |
| Dresden – Leipzig km 110,9 (Augustusbrücke) | Balustrade, Kandelaber | 1,00 | gut |
| Bremen – Amsterdam km 139,5 (Grenze NL) | Dach, Häuschen | **0,00** – nur auf dem Standstreifen (+3,75 m) bei 70–100 m: das Testauto steht dort *im* bzw. direkt *hinter* dem Häuschen (Häuschen auf dem Standstreifen ≈ 65–80 m voraus); in den Fahrspuren 1,00 | Sondenartefakt (kein Verkehr fährt durch ein Häuschen); Arcades Häuschenlage s. Bild GRZ |
| Dortmund – Frankfurt km 221 (C1, Mainbrücke in die Stadt) | Stadthäuser in der Rechtskurve | rechte Spur: 230 m 0,76, **260 m 0,00** (Backsteinhaus auf der Kurveninnenseite) | s. Befund F-04 |
| Kassel – Würzburg km 46,5 (T1) | – (Kurvenkorridor) | 0,93 | gut |
| Kassel – Würzburg km 61,9 (T2, Kuppe) | – | 1,00 außerhalb der Kuppe | gut |
| Saragossa – Pau km 172,8 (T3) | – | 1,00 | gut |
| Saragossa – Pau km 198,8 (T4) | – | 1,00 im Bild (bei 260 m liegen die Punkte rechts außerhalb des Bildes, x > 1280 – kein Befund) | gut |
| Kiel – Hamburg km 0,05 (S0, Start) | Startportal | 1,00 | gut |
| Kiel – Hamburg km 80 (S4, Stadtgrenze) | Hansehäuser, Kran | 1,00 | gut |

Logs: `m1/QA-RINT-BILD/occl/struct.log`, `occl/akorr.log`; Bilder der verdeckten Stellungen daneben.
Die Sonde misst Modern allein; ob Arcade dieselbe Stellung zeigt, beantwortet das A/B-Bild derselben Stelle.

Zur Stelle C1 (Dortmund – Frankfurt km 221, Friedensbrücke): das A/B-Bild bei 12 Uhr (`bilder/C1T_00.jpg`) zeigt
dasselbe Backsteinhaus an derselben Stelle auch bei Arcade (Arcades Komposition, Sprite an derselben Position);
die Verdeckung der rechten Spur ab ≈ 250 m in der Rechtskurve ist damit keine neue Verdeckung durch Modern
(gefolgert – ein Arcade-Gegenstück der Sonde gibt es nicht). F2 verlangt dort bei 50 km/h-Stadtstrecke weit weniger.

## 2. Bild in jeder Lage – Arcade | Modern Kopf (| Modern Basis `515dd51`)

Werkzeug `tools/ab_shot.sh` (gleicher Simulationszustand, „Hoch“, 1280×720; Deck 1280×800), Basis-Modern mit
denselben Argumenten im Basis-Arbeitsbaum. Bögen in `bilder/` (`<ID>_<NN>.jpg`, links Arcade, Mitte Kopf, rechts
Basis, wo vorhanden). Jedes Bild angesehen; Urteile Kopf gegen Arcade, und Kopf gegen Basis (Rückschritt?).

### 2.1 Bezugsstellen und Sonderstellen („Hoch“)

| ID | Stelle, Lage | Kopf gegen Arcade | Kopf gegen Basis | Beobachtung |
|---|---|---|---|---|
| S1 | Kiel – Hamburg km 2, 12 Uhr | gleich | gleich | Gras mit Struktur, Rapsfeld, Stahl-Leitplanke, Birken – aber Arcades großer Busch links vorne fehlt (auch in der Basis; Kurvenband). Nicht „deutlich besser“. |
| S2 | km 13,6, 12 Uhr | besser | – | echtes Tankstellendach mit Säulen, Zapfsäulen, Shop |
| S3 | km 60, 12 Uhr | gleich | – | offene Autobahn wie Arcade, mehr Bodenstruktur |
| S4 | km 80, 12 Uhr | leicht besser | besser | Hansehäuser und Kran in 3D, Einfamilienhaus rosa wie Arcade; die Birke an der Laterne links vorne fehlt (auch Basis) |
| N1 | Hamburg – Hannover km 71, 22 Uhr, Schnee | gleich | besser | Kopf: Schneefall-Streifen im Abblendlicht (Basis: keine); Kegel und Rücklichter wie Arcade; Lack des Kompakt satter |
| N2N | Dortmund – Frankfurt km 121, 22 Uhr, Regen | gleich, Wagen schlechter | besser (Regen) | Regenstreifen, rote Spiegelung der Rücklichter unter dem Wagen; der Gran Turismo leuchtet hellgrau-silbern statt Arcades dunkel blaugrau (Sättigung Dach 0,33 statt 0,49) – heller als in der Basis |
| U1 | Bern – Mailand km 186 (Gotthard innen), 12 Uhr | gleich | – | Fliesen, Leuchten, Fahrbahn wie Arcade; Arcades grünes Notausgangslicht in der Ferne fehlt im Bild; Limousine dunkler |
| C1T | Dortmund – Frankfurt km 221 (Friedensbrücke), 12 Uhr | gleich | – | Brücke, Kai, Häuser, Bäume wie Arcade, Wasser und Kaimauer besser; **das Hochhaus rechts vorne (Arcade) fehlt** |
| KHH22 | Kiel – Hamburg km 88,2 (Hamburg Mitte), 22 Uhr | gleich (schärfer, aber dunkler) | gemischt | AS5a-Häuser in 3D mit Rahmen und Bögen – deutlich schärfer als die Sprites. Aber das nahe Haus rechts zeigt nur **0,46×** Arcades warm erleuchtete Fensterfläche (Basis 0,76×); im ganzen Bild 0,84 / 0,90× (gemessen, `warm2.py`) |
| TS15N | Kiel – Hamburg km 14,3 → Tankstelle, 21 Uhr (2 Bilder) | gleich, Dach dunkler | – | Blende leuchtet, Zapfsäulen grün, Preismast; aber unter dem Dach fehlen Arcades große weiße Deckenleuchten: Dachzone 0,77× Arcades Leuchtdichte (74,7 / 96,4), reines Weiß 1,9 % / 2,9 % (gemessen `region.py`) |
| GRZN | Bremen – Amsterdam km 139,55 (Grenze NL), 22 Uhr, Regen (2 Bilder) | besser | – | Häuschen mit warm erleuchteten, gerahmten Fenstern statt Arcades weißer Flächen; Dach mit Stützen; Regen und rote Spiegelungen. Häuschen stehen in beiden Modi an derselben Stelle auf dem Standstreifen (bestätigt den Sondenbefund an der Grenze als gleich wie Arcade) |
| VALN | Prag – Nürnberg km 87,3 (Tunel Valík), 22 Uhr, Regen: Portal 1 s, Röhre 2,5 s, nach der Ausfahrt 4 s | gleich bis besser | – | Portal mit Lampen und Hügel; in der Röhre Fliesen, Leuchten, Regen draußen in der Öffnung; nach der Ausfahrt Regen und Fichten. Kein Nach-Überstrahlen bei Nacht (Regel „by day only“ greift). Der rote Sportwagen wirkt bei Modern nachts deutlich heller/kräftiger als Arcades dunkelrotes Sprite; der Abblendkegel auf der Fahrbahn bei Modern etwas schwächer (Spurmarken 20–60 m dunkler) |
| STB | Dresden – Leipzig ab Leipzig km 111 (Augustusbrücke), 12 Uhr (2 Bilder) | gleich bis leicht besser | – | Balustrade mit Docken und Pfeilern, Kandelaber, Frauenkirche wie Arcade; Wasser mit Wellen, Gehweg mit Pflaster. Der kahle beige Stadtboden vor der Brücke ist Arcades Komposition (bei beiden gleich) |
| KBN | Kiel – Hamburg km 77,6 (Köhlbrandbrücke), 22 Uhr (2 Bilder) | gleich bis besser | – | Pylon, Laternen, Elbphilharmonie, Schiffe wie Arcade; die Schrägseile liegen nah als hellgraue, kräftige Linien über dem Nachthimmel (Arcade: dünne, blasse Linien) – plausibel (die echte Brücke hat weiße Seile), aber auffälliger; Fahrbahn durch die Laternen gleichmäßiger beleuchtet |
| S0 | Kiel – Hamburg km 0, Start, 12 Uhr (Countdown „3“ und 1 s nach „LOS!“) | gleich | – | Startportal als Fachwerkträger mit Ampeln statt zweier Pfosten (besser); **Arcades große Eiche links vorne fehlt** (auch in RINT-M2s Startbild; gerade Strecke, also nicht das Kurvenband – vermutlich vor km 0 bzw. im Vorlauf keine Requisiten); Tafel „Tankstelle 15 km“ gleich |
| ZIEL | Kiel – Hamburg km 94,3 → Ziel km 95, 12 Uhr (1,5 und 3,5 s) | gleich bis leicht besser | – | Zieltor als Fachwerkträger mit Banner, Hansehäuser in 3D, großer Baum rechts wie Arcade; Bremsleuchten mit dritter Leuchte; der kahle beige Stadtboden ist Arcades Komposition |
| S1_DECK | wie S1, Voreinstellung „Steam Deck“, 1280×800 | gleich, füllt den 16:10-Schirm | – | Arcade mit schwarzen Balken, Modern zeigt oben/unten mehr Bild (D13), HUD in den Ecken; Gras etwas glatter als „Hoch“; Arcades Busch links fehlt wie bei „Hoch“ |
| NUE12 | Würzburg – Nürnberg km 102,7 (Altstadt), 12 Uhr (2 und 4 s) | **deutlich besser** | – | Fachwerk- und Bürgerhäuser in 3D, scharf mit Fenstern, Bögen, Blumenkästen, Sockeln – Arcades nahe Sprites sind unscharf und flach; Laternen, Pflaster. Hier löst Modern den Anspruch ein |

### 2.2 Bewegung – zwei A/B-Clips zu je 10 s („Hoch“, 60 Bilder/s, `tools/ab_clip.sh`)

**`clips/hh_nacht_regen.mp4`** – Kiel – Hamburg ab km 87,6, 22 Uhr, Regen, durch Hamburg Mitte. Einzelbilder 1, 3, 5, 7,
9,5 s angesehen. **Besser:** nasse Fahrbahn spiegelt Laternen und Rücklichter in langen Streifen, Regenstreifen, rote
Spiegelung unter dem eigenen Wagen (Arcade: matte Straße). **Gleich:** Häuser, Laternenhöfe, Verkehr mit Rücklichtern.
**Etwas schlechter:** das große Bürohaus rechts bei 1 s hat kleinere, blassere Fenster als Arcades kräftig gelbe
(warm erleuchteter Anteil der Bildzone 0,81–1,1× Arcade, gemessen `warm.py`). Bewegung, gemessen (`popscan.py`,
mittlere Bild-zu-Bild-Änderung beider Hälften): Modern hat **keinen** Sprung, den Arcade nicht auch hat (auch mit
1,6× statt 3× Schwelle) – kein LOD-Springen, kein Stück-Aufpoppen, kein Flackern sichtbar in diesem Clip.

**`clips/valik_morgen_schnee.mp4`** – Prag – Nürnberg ab km 87,3, 8 Uhr, Schnee: Portal, Röhre, Ausfahrt, offene
Strecke. Portal mit Hügel, verschneite Fichten, Schneeflocken – vor und nach der Röhre besser als Arcade.
**Aber die Ausfahrt (Befund F-01):**
- 3 Bilder (4,027–4,060 s) direkt nach der Ausfahrt zeigt Modern eine **schneefreie, sandbraune Landschaft mit grünen
  Bäumen** (Szenenleuchtdichte 151–154), dann springt es auf Schnee – Arcade wechselt in einem Bild sauber auf Schnee.
- Ab 4,077 s **überstrahlt Modern das ganze Bild für gut 1 s**: 65–68 % der Szenenzone (Zeilen 25–80 %) reines Weiß
  (≥ 240), Arcade 0,1–0,3 %; ≥ 42 % bis 5,05 s, normal ab ≈ 5,25 s (gemessen, `lumtrace.py`). Leitlinien und
  Fahrbahnrand sind in dieser Zeit kaum zu sehen (Bild `bilder/clip_valik_schnee_modern_4.08_4.10_5.30.jpg`).
- Gegenprobe ohne Schnee: RINT-M2s Clip `gotthard_ausfahrt.mp4` (12 Uhr, trocken) mit demselben Messwerkzeug: Modern
  nach der Ausfahrt 15–19 % reines Weiß für ≈ 0,8 s (5,5–6,2 s), Arcade 1–3 % und sofort wieder normal. Die
  Nach-Überstrahlung (`environment_rig.gd` `EXIT_AFTER` 0,4 über `EXIT_AFTER_M` 60 m / `EXIT_AFTER_S` 2 s) hat Arcade
  nicht – Arcade überstrahlt nur, was man *aus der Röhre* sieht.

## 3. Arcade-Identität und eingefrorene Dateien (gemessen)

- `tools/golden.sh check` auf `9b02f05` (einmal, 11:44–11:53, eigenes `XDG_DATA_HOME`): **GOLDEN arcade: 20 von 20
  identisch**, **GOLDEN arcade-ui: 17 von 17 identisch**, Exit 0 (`m1/QA-RINT-BILD/logs/golden_check.log`). Im
  Arbeitsbaum lagen dabei nur die zwei unversionierten QA-Skripte `qa_perf.gd`/`qa_occl.gd` (von keinem Spielpfad
  geladen).
- `git diff 515dd51 9b02f05` über alle Dateien der Regel 1 (eingefrorene Arcade-Skripte, `scripts/gameplay`,
  `scripts/data`, `data/`, Sprites, Arcade-Audio, Synth-Werkzeuge): 0 Zeilen; `scripts/race/` gar nicht berührt.

## 5. Befunde (schwerste zuerst)

Schwere: blocker = nicht in den nächsten Testbuild; hoch = fällt dem Nutzer sofort auf; mittel = fällt auf; niedrig = Feinschliff.

### F-01 (hoch) Tunnelausfahrt bei Tag: ganzes Bild ≈ 1 s weiß überstrahlt (Schnee), davor 3 Bilder schneefreie Landschaft
- **Wo:** `scripts/race3d/environment_rig.gd` – Nach-Überstrahlung `EXIT_AFTER` (0,4) über `EXIT_AFTER_M` 60 m /
  `EXIT_AFTER_S` 2 s (`exit_after_timed`, `_after`-ColorRect); `ce_snow = snow × (1 − tunnel01)` (Zeile 385) und
  dasselbe für `ce_wet`.
- **Was:** Prag – Nürnberg, Tunel Valík, 8 Uhr, Schnee: nach dem Verlassen der Röhre zeigt Modern 3 Bilder lang eine
  sandbraune, schneefreie Landschaft mit grünen Bäumen und springt dann auf Schnee; zugleich wird das ganze Bild für
  gut 1 s überstrahlt – 65–68 % der Szenenzone reines Weiß, Leitlinien und Fahrbahnrand kaum zu sehen. Arcade: 0,1–0,3 %
  Weiß, sauberer Wechsel in einem Bild. Auch trocken (Gotthard, 12 Uhr) bleibt Modern ≈ 0,8 s überstrahlt (15–19 %
  Weiß gegen Arcades 1–3 %), was Arcade nicht tut. Regel 9 (Fahrbahnrand und Markierungen werden nie gedimmt oder
  ausgewaschen) ist in dieser Sekunde verletzt.
- **Beleg (gemessen):** `python3 m1/QA-RINT-BILD/sh/lumtrace.py clips/valik_morgen_schnee.mp4 3.96 6.0` → Modern
  `white 0.646–0.675` von 4,077 bis 4,85 s, 0,42 bei 5,05 s, 0,05 bei 5,25 s; Arcade ≤ 0,003. Bilder
  `bilder/clip_valik_schnee_ausfahrt_folge.jpg`, `bilder/clip_valik_schnee_modern_4.08_4.10_5.30.jpg`.
- **Nachstellen:** `GFX_ARGS=--gfx-preset=high CLIP_S=10 tools/ab_clip.sh out.mp4 --stage=prag_nuernberg --from=prag
  --vehicle=sportwagen --seed=22 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-km=87.3
  --hour=8 --weather=snow --start-speed=80`, Bilder bei 4,0–5,3 s.
- **Behebung:** (1) Nach-Überstrahlung an die Bildhelligkeit binden: Verstärkung so begrenzen, dass höchstens
  Arcades Anteil reiner Weißpixel + 5 Prozentpunkte entsteht (z. B. `EXIT_AFTER × (1 − snow)` und Deckel auf
  `display × (1 + gain) + lift ≤ 0,92` für Fahrbahn und Markierungen), oder ganz streichen – Arcade hat sie nicht.
  (2) `ce_snow`/`ce_wet` nicht über `tunnel01` der *Kamera* auf 0 ziehen, sondern Schnee/Nässe im Röhren-Shader
  ausblenden (die Welt draußen bleibt verschneit/nass); Prüfung: Bild 1–3 nach der Ausfahrt ohne Farbsprung.
  (3) Render-Prüfung „Ausfahrt Schnee“ in `check_tunnel_bridge.gd`: Anteil reines Weiß ≤ Arcade + 5 % in den 2 s nach
  der Ausfahrt, kein Bild mit Schnee-Anteil 0.

### F-02 (hoch) Auf offener Autobahn ist Modern nicht deutlich besser als Arcade
- **Wo:** Bezugsstellen S1 (km 2), S3 (km 60), der Großteil von Kiel – Hamburg; Gelände/Vegetation/Himmel
  (`builders/terrain.gd`, `builders/props.gd`, `layers/backdrop.gd`, `layers/far_ground.gd`).
- **Was:** Bei Tag zeigen S1 und S3 dieselbe Komposition wie Arcade mit etwas mehr Bodenstruktur, Stahl-Leitplanke
  und Rapsfeld – aber gleicher flacher Himmel (Arcades Backdrop), gleiche Baumgruppen in fast gleicher Form (die
  3D-Eiche bei S3 ist kaum von Arcades Sprite zu unterscheiden), Schatten wie Arcades Flecken, kein Dunst, keine
  Wolkenschatten, keine Fahrbahnstruktur über Arcades Grau hinaus. Ein Spieler,
  der den Modus umschaltet, sieht auf der Autobahn fast dasselbe Bild – der Wunsch „deutliche grafische Überarbeitung“
  ist dort nicht eingelöst. Deutlich besser ist Modern dagegen bei Bauten (S2, Grenze, Häuser in 3D), Regen/Nässe
  nachts und Schnee.
- **Beleg (angesehen):** `bilder/S1_00.jpg`, `bilder/S3_00.jpg`, `bilder/S1_busch_links.jpg` (Arcade | Kopf | Basis).
- **Nachstellen:** `tools/ab_shot.sh out S1` bzw. `S3` mit `GFX_ARGS=--gfx-preset=high`.
- **Behebung (Vorschläge, gefolgert):** Bäume und Büsche werfen sichtbare Schatten auf das Gras (Schatten „Hoch“
  bis 200 m), Höhenrelief/Wiesenvariation in Sichtweite, Fahrbahnverschleiß (Spurrinnen, Flickstellen, Teerfugen),
  Luftperspektive (Dunst zum Horizont), ein eigener 3D-Himmel mit Wolken statt der Arcade-Kulisse; Maßstab: in
  S1/S3 muss man den Modus auf den ersten Blick erkennen.

### F-03 (mittel) Kurveninnenseiten und Vordergrund ohne Arcades Büsche/Bäume (A-17 offen)
- **Wo:** Kurvenband der Vegetation (`builders/props.gd`, FIX-M2 B-01), Hüllkurve nach A-17 noch nicht gebaut (R7).
- **Was:** S1 – Arcades großer Busch links vorne fehlt (Kopf und Basis); S4 – die Birke an der Laterne links vorne
  fehlt (Kopf und Basis); S0 (Start Kiel – Hamburg) – Arcades große Eiche links vorne fehlt, obwohl die Strecke dort
  gerade ist (anderer Grund als das Kurvenband, vermutlich keine Requisiten im Startvorlauf/vor km 0 – zu klären);
  T1–T4 laut RINT-M2-Bögen und meinen Sondenbildern kahle Kurveninnenseiten. Zusammen wirkt Modern im Vordergrund
  leerer als Arcade – gerade am ersten Bild der Etappe.
- **Beleg:** `bilder/S1_busch_links.jpg`, `bilder/S0_00.jpg`, `bilder/S0_01.jpg`; Verdeckungssonde T1–T4: überall voll sichtbar (die Bäume dürften dort
  also wieder stehen, ohne F2 zu verletzen – gefolgert aus 0,93–1,00 sichtbarem Anteil bis 260 m).
- **Behebung:** A-17 (Hüllkurve der Sehnen statt Band) in R7 umsetzen; für S0 prüfen, ob `props.gd` Arcades
  Requisiten des Startvorlaufs (z < 0 bzw. die ersten Segmente) setzt; danach A/B S0, S1, S4, T1–T4 wiederholen.

### F-04 (mittel) Stadthäuser nachts: weniger erleuchtete Fenster als Arcade und als die Basis
- **Wo:** AS5a-Stadthausmodelle (Nachtfenster im Bake / `baked.gdshader`), Hamburg Mitte.
- **Was:** Kiel – Hamburg km 88,2, 22 Uhr: das nahe Hansehaus rechts zeigt fast nur dunkle Scheiben mit hellen
  Rahmen; warm erleuchtete Fensterfläche **0,46×** Arcade (Basis mit den Sprites 0,76×); im ganzen Bild 0,84× bzw.
  0,90× (zweites Bild). Die Häuser sind dafür in 3D deutlich schärfer (Rahmen, Bögen) – die Nachtstimmung leidet.
- **Beleg (gemessen):** `python3 sh/warm2.py 1000 160 1280 380 KHH22_{arcade,modern,base_modern}_00.png` → warm share
  0,0153 / 0,0071 / 0,0116; Bild `bilder/KHH22_fenster_rechts.jpg`, Bogen `bilder/KHH22_00.jpg`.
- **Nachstellen:** `tools/ab_shot.sh out --stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot
  --autopilot-refuel=never --traffic-warmup --no-countdown --start-km=88.2 --hour=22 --weather=normal --start-speed=50
  --shot-times=2,4` (`GFX_ARGS=--gfx-preset=high`).
- **Behebung:** Anteil der nachts erleuchteten Fenster je Modell an Arcades Sprite angleichen (≈ 35–45 % warm,
  Zufall je Haus fest), Fensterglas nachts mit Emission statt dunklem Spiegel; Abnahme: warm share je Haus
  0,85–1,15× Arcade.

### F-05 (mittel) Tankstelle nachts: unter dem Dach 0,77× Arcade, Arcades große Deckenleuchten fehlen
- **Wo:** `builders/station.gd` (Dachunterseite, Lichtquellen der Tankspur).
- **Was:** Kiel – Hamburg km 14,6, 21 Uhr: Arcade zeigt große weiße Leuchtflächen unter dem Dach und eine hell
  ausgeleuchtete Tankspur; Modern eine dunkle Dachunterseite mit kleinen Punkten. Dachzone (x 780–1280, y 250–460)
  mittlere Leuchtdichte 74,7 gegen 96,4 (0,77×), reines Weiß 1,9 % gegen 2,9 % (gemessen). Die Render-Prüfung
  `tankstelle` (≥ 0,85× auf der Spur) ist grün – sie misst die Fahrbahn, nicht das Dach.
- **Beleg:** `bilder/TS15N_00.jpg`; `python3 sh/region.py 780 250 1280 460 TS15N_{arcade,modern}_00.png`.
- **Behebung:** emissive Leuchtflächen (≈ 1,2 × 0,4 m) unter dem Dach in Arcades Raster, Lichtkegel der Spur auf
  Arcades Helligkeit; Prüfung um die Dachzone erweitern (≥ 0,85× Arcade).

### F-06 (mittel) Lack der Spielerautos nachts: Gran Turismo hellsilbern statt dunkel blaugrau, Sportwagen grell
- **Wo:** Fahrzeugmodelle/Lack (Asset) und die Fülllicht-Anhebung des Spielerautos (`modern_materials.gd` „fill“).
- **Was:** N2N (22 Uhr, Regen): Arcades Gran Turismo dunkel blaugrau, Moderns hell silbergrau – im Kopf heller als in
  der Basis (Dach-Leuchtdichte 51 / Basis 40 / Arcade 47, Sättigung 0,33 / 0,28 / 0,49). VALN (22 Uhr): der rote
  Sportwagen kräftig hellrot gegen Arcades dunkelrotes Sprite. Bekannt aus RINT-M2 (N2 0,77×), hier nachts bestätigt.
- **Beleg:** `bilder/N2N_wagen_kegel.jpg`, `bilder/VALN_00.jpg`, `bilder/VALN_02.jpg`.
- **Behebung:** Gran-Turismo-Lack im Modell auf Arcades Farbton (≈ #3a4660) setzen; das Fülllicht nachts begrenzen
  (Spielerauto nachts ≤ 1,15× Arcades Leuchtdichte, wie A-20 für Brems-/Blaulichter); Prüfung `spielerauto` um
  22 Uhr für alle fünf Wagen.

### F-07 (niedrig) Frankfurt (C1): Arcades Hochhaus rechts vorne fehlt in Modern
- **Wo:** Dortmund – Frankfurt km 221,2 (Friedensbrücke), 12 Uhr, Bild 1 s.
- **Was:** Arcade zeigt rechts am Bildrand ein nahes, helles Bürohochhaus; Modern zeigt dort Himmel und Bäume.
- **Beleg:** `bilder/C1T_hochhaus_rechts.jpg`, `bilder/C1T_00.jpg`.
- **Behebung:** prüfen, ob die Hochhaus-Requisite (Skyline/Nahbereich) in Modern ein Modell hat (R7 „Skyline“); sonst
  als Billboard mit Arcades Sprite stellen.

## 4. Leistung (Kopf `9b02f05` neben Basis `515dd51`)

**Methode.** Eigener Treiber `qa_perf.gd` (Kopie von `tests/race/run_stage.gd` mit Aufzeichnung je Bild: Bildzeit,
Draw-Calls und Primitive der sichtbaren und der Schattenpässe; alle 10 Bilder Zählung der Geometrie-Instanzen mit
Instanzuniforms in der ganzen Szene (A-19, wie `check_instance_budget.gd`); alle 20 Bilder die Höchstwerte der
Renderer-Haken mit Ort (km) ihres Anstiegs; Speicher alle 10–20 s; am Ende `perf_stats()`). Autopilot, Seed 7,
ganze Etappen. Auflösung 640×360 (Deck 640×400): Draw-Calls, Primitive, Instanzen, Speicherzähler und Skriptzeiten
hängen nicht von der Fenstergröße ab (gleiche Bildwinkel, gleiche Schattenatlanten); die Bildzeit der
Software-Rasterung schon – Bildzeiten sind darum **nicht** mit RINT-M2s 1280×720-Zahlen vergleichbar, nur Kopf gegen
Basis unter gleicher Last. Zwei Geschwindigkeiten: Zeitraffer 40 (ganze Etappe in 2–4 min, 1,33 s Simulation je Bild
= ≈ 470 m Strecke je Bild – für Zähler und Vergleiche; Stoßzeiten im Hauptfaden sind dabei aufgebläht) und
Zeitraffer 1 (0,133 s Simulation je Bild ≈ 47 m – für Haken-Zeiten, Spitzen und Speicher über 15 min).
Die Maschine war die ganze Zeit mit Last 8–14 belegt (andere Agenten); Höchstwerte einzelner Bilder sind darum mit
Vorsicht zu lesen (Verdrängung durch andere Prozesse zählt mit), Mittelwerte und Zähler nicht.

### 4.1 Ganze Etappen, Zeitraffer 40 (gemessen)

| Lauf (Stand, Etappe, Voreinst.) | Bilder | Bild p50 / p95 ms | Draw-Calls Ø / p95 / max | Primitive Ø / p95 / max (k) | Schatten-Primitive max (k) | `render()` Ø / max ms | Einhängen max ms | collect() max ms (Baustein) | Instanzuniform max | RSS Ende MB | Textur / Video MB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base_DN_modern_deck | 234 | 269 / 487 | 40 / 80 / 94 | 67 / 115 / 124 | 11 | 4.97 / 28.7 | 5.11 | – | 134 | 888 | 51 / 68 |
| base_KH_modern_deck | 259 | 540 / 916 | 110 / 163 / 167 | 121 / 162 / 177 | 13 | 5.28 / 108.1 | 7.25 | – | 134 | 1118 | 56 / 73 |
| base_KH_modern_high | 259 | 538 / 802 | 138 / 199 / 206 | 131 / 178 / 193 | 53 | 4.40 / 30.1 | 5.12 | – | 134 | 1050 | 59 / 76 |
| head_DN_modern_deck | 234 | 363 / 705 | 44 / 83 / 97 | 71 / 120 / 128 | 11 | 7.05 / 226.1 | 5.45 | 4.11 (station) | 134 | 1007 | 54 / 73 |
| head_KH_modern_deck | 259 | 503 / 741 | 126 / 199 / 212 | 144 / 225 / 244 | 30 | 4.39 / 17.9 | 2.19 | 1.03 (bridge) | 134 | – | 63 / 83 |
| head_KH_modern_high | 259 | 824 / 1483 | 162 / 259 / 273 | 157 / 244 / 261 | 182 | 6.11 / 54.0 | 5.34 | 6.11 (signs) | 134 | 1078 | 65 / 85 |
| head_KH_modern_low | 259 | 210 / 343 | 109 / 179 / 188 | 128 / 200 / 221 | 0 | 4.44 / 36.7 | 3.13 | 0.45 (bridge) | 134 | 1069 | 57 / 77 |
| head_KH_modern_medium | 259 | 458 / 773 | 134 / 217 / 227 | 144 / 225 / 244 | 82 | 4.79 / 47.2 | 2.17 | 0.42 (bridge) | 134 | 1060 | 62 / 82 |
| head_MEM_modern_high | 440 | 390 / 745 | 63 / 124 / 136 | 85 / 128 / 147 | 67 | 5.73 / 60.1 | 5.08 | 1.32 (station) | 135 | 1077 | 63 / 82 |

### 4.2 Zeitraffer 1 (≈ 47 m je Bild), Deck: Haken-Zeiten, Spitzen, Speicher (gemessen)

| Lauf | km / Wand | `render()` Ø | größte Haken-Mittel (ms) | Einhängen Ø / max | collect() max (Baustein) | Einzelspitzen ≥ 8 ms (Haken, km) | RSS Anfang → Ende |
|---|---|---|---|---|---|---|---|
| Kopf Kiel – Hamburg | 84,5 km / 900 s (Zeitlimit) | **2,50 ms** | Fahrzeuge 0,86, Streamer 0,45, Fernboden 0,23, Gelände 0,21, Umgebung 0,18 | 1,34 / **17,7** (km 74,6) | 4,10 (Brücke), sonst ≤ 1,14 | terrain 55,1 (30,8), vehicles 24,7 / 26,2 (49,2 / 84,1), flares 13,9 (48,2), streamer 17,8 (74,6) | 1082 → 1087 MB in 14 min |
| Basis Kiel – Hamburg | 86,9 km / 900 s (Zeitlimit) | 2,28 ms | Fahrzeuge 0,79, Streamer 0,43, Fernboden 0,19, Umgebung 0,18, Gelände 0,17 | 1,28 / 7,79 (km 77,8) | – | backdrop 16,6 / collect 14,5 / streamer 14,9 (alle km 30,8), tunnel 17,0 (km 74,6), sonst ≤ 13 | 1056 → 1058 MB |
| Kopf Testetappe 22 Uhr Regen | 131,6 km / 832 s (ganz) | **2,85 ms** | Fahrzeuge 0,72, Streamer 0,58, Lichter 0,34, Flares 0,24, Umgebung 0,19 | 1,10 / 3,24 | 2,02 (Tankstelle) | lights **159** (33,0), vehicles **138** (91,1), flares **143** (116,4), sonst ≤ 9,8 | 1078 → 1078 MB |
| Basis Testetappe 22 Uhr Regen | 131,6 km / 736 s (ganz) | 2,07 ms | Fahrzeuge 0,51, Streamer 0,50, Lichter 0,23, Gelände 0,18, Umgebung 0,16 | 1,00 / 9,13 | – (Basis ohne `collect_by`) | alle ≤ 11,9 ms (environment/lights km 125,7) | 989 → 989 MB |

### 4.3 Budgets (§4.10, A-18, A-19) und was echte Hardware braucht

- **Draw-Calls und Primitive (gemessen, Zähler):** Kopf gegen Basis auf Kiel – Hamburg ganz: Deck Ø 110 → 126
  (+15 %), Höchstwert 167 → 212; Primitive Ø 121 k → 144 k, max 177 k → 244 k (+38 %). Hoch: Draw-Calls max
  206 → 273, Primitive max 193 k → 261 k, **Schatten-Primitive max 53 k → 182 k (3,4×)** – die neuen Bauten
  (Tankstelle, Brücken, Stadthäuser, Tore) werfen auf „Hoch“ Schatten. Alles weit unter den Budgets (Deck 650 /
  450 k, Hoch 1500 / 1,5 M). Knapp nur „Niedrig“: Primitive max **221 k von 250 k (88 %)**, obwohl Details 0 die
  Dichte auf 0,6 senkt – Primitive fallen gegenüber „Mittel“ nur um 11 % (die Bauten haben keine Detailstufe nach
  Voreinstellung). Die Schatten-Draw-Calls meldet der Compatibility-Renderer als 0 – die Summe „inkl. Schatten“ des
  Budgets ist so nicht messbar (Vertragsfrage, s. Ergebnis).
- **`render()` im Hauptfaden (gemessen, Deck, Zeitraffer 1):** 2,50 ms (Kiel – Hamburg) und 2,85 ms (Testetappe
  nachts) gegen das Budget **1,5 ms** (§4.10 „render() GDScript avg (this VM)“). Größte Posten: Fahrzeuge
  0,72–0,86 ms, Streamer 0,45–0,58 ms, Lichter/Flares nachts 0,58 ms. Die Basis (gleiche Last, Zeitraffer 40) lag
  ebenfalls über dem Budget (5,28 / 4,97 ms gegen Kopf 4,39 / 7,05 ms) – das Überschreiten ist nicht neu, nachts aber
  gewachsen (Testetappe +42 % bei Zeitraffer 40).
- **Einhängen (commit) ≤ 3 ms Deck:** Kopf max 17,7 ms (Kiel – Hamburg km 74,6, kurz vor der Köhlbrandbrücke) bzw.
  3,24 ms (Testetappe), Mittel 1,1–1,3 ms. Einzelwert auf belasteter VM.
- **collect() je Baustein ≤ 2 ms Deck (A-18):** bei Zeitraffer 1 Tankstelle 0,12 / 2,02 ms, **Brücke 4,10 ms** (einmal,
  Mittel 0,08), alle anderen ≤ 1,14 ms. Bei Zeitraffer 40 auch Tankstelle 4,11 und Straße 4,09 ms – die Straße hat
  keinen teuren `collect()`, das spricht für Verdrängung durch die Last. Hart bestätigen lässt sich A-18 hier nicht.
- **Instanzuniforms (A-19, Grenze 230 bei „Hoch“):** gezählt wie `check_instance_budget.gd`, alle 10 Bilder über
  ganze Etappen: Kiel – Hamburg Hoch **134**, Deck 134 / 141 (Zeitraffer 1), Testetappe 134–135, Bern – Mailand Hoch
  (Gotthard, 215 km) 135. Die Fahrzeugebene füllt ihr Budget 128, der Rest sind 6–13. Keine Ablehnung im Log.
  Wald und Stadtziel mit 48 eingespeisten Autos (216 / 171 bei RINT-M2) nicht wiederholt.
- **Speicher (gemessen):** Kiel – Hamburg Deck 15 min Zeitraffer 1: RSS 1082 → 1087 MB, Knoten 362 → 513 (Stadt),
  Waisen 0, Ressourcen 346 konstant; Bern – Mailand km 150 → 365 Hoch: RSS 1075–1077 MB flach, Textur 62 MB. Kein
  Leck erkennbar. Texturspeicher Modern 54–95 MB (bei 640×360; Zeitraffer 1 lädt mehr Stufen als 40).
- **Bildzeiten:** auf llvmpipe 0,2–0,8 s je Bild – nur Kopf gegen Basis: Kiel – Hamburg Deck p50 540 → 503 ms (gleich),
  Hoch 538 → 824 ms (+53 %, passt zu den 3,4× Schatten-Primitiven), Testetappe Deck 269 → 363 ms (+35 %).

**Gefolgert für echte Hardware / Steam Deck:** Mit ≤ 220 Draw-Calls und ≤ 250 k Primitiven je Bild liegt die GPU-Last
auf dem Deck (RDNA2, 1280×800) im unkritischen Bereich; der Engpass ist der Hauptfaden: 2,5–2,9 ms `render()` hier
entsprechen auf dem Deck-Kern (≈ 1,5× langsamer, §4.10) etwa 4–4,5 ms – zusammen mit Simulation, HUD und
Draw-Call-Abgabe noch innerhalb von 16,7 ms, aber Einzelstöße von 15–55 ms (Gelände, Einhängen, Fahrzeuge) wären auf
dem Gerät als Ruckler sichtbar, *falls* sie nicht Verdrängung dieser VM sind. Das muss der Leistungstest auf dem Deck
klären (Bildzeit-Perzentile p99/max je Etappe, nicht nur Mittel). „Hoch“ wird durch die Schatten der neuen Bauten
GPU-seitig deutlich teurer (3,4× Schatten-Primitive) – auf schwachen GPUs zuerst „Schatten: Mittel“ empfehlen.

### F-08 (mittel, zu bestätigen) Hauptfaden nachts teurer, Einzelstöße 138–159 ms nur im Kopf
- **Wo:** Renderer-Haken `lights`, `flares`, `vehicles` (`layers/lights.gd`, `layers/flares.gd`, `layers/vehicles.gd`),
  Testetappe 22 Uhr Regen, Deck; Kiel – Hamburg: `terrain`, `commit`.
- **Was (gemessen, Zeitraffer 1, gleiche Last):** `render()` Ø Kopf 2,85 ms gegen Basis 2,07 ms (+38 %; Lichter
  0,34/0,23, Flares 0,24/0,09, Fahrzeuge 0,72/0,51, neu Wetter 0,09) – Budget Deck 1,5 ms (schon die Basis darüber).
  Einzelstöße im Kopf: `lights` 159 ms bei km 33,0, `vehicles` 138 ms bei km 91,1, `flares` 143 ms bei km 116,4;
  in der Basis derselben Fahrt höchstens 11,9 ms. Kiel – Hamburg Kopf: `terrain` 55 ms (km 30,8), `commit` 17,7 ms
  (km 74,6), `vehicles` 26 ms. Bildzeit p99 Testetappe 654 / Basis 502 ms.
- **Ort statt Zufall (Kiel – Hamburg):** Kopf und Basis stoßen an denselben Stellen – km 30,8 (Kopf `terrain`
  55 ms, Basis `backdrop`/`collect`/`streamer` 15–17 ms) und km 74,6–77,8 vor der Köhlbrandbrücke (Kopf `commit`
  17,7 ms, Basis `tunnel` 17,0 / `commit` 7,8 ms). Die Stöße hängen also am Inhalt, und der Kopf ist dort 2–3×
  schwerer (gemessen). `render()` Ø Kiel – Hamburg Kopf 2,50 / Basis 2,28 ms (+10 %).
- **Vorbehalt:** die VM lief mit Last 8–14; ein einzelner Stoß kann Verdrängung sein. Eine Wiederholung des
  Kopf-Laufs der Testetappe (DN1b) ist unten nachgetragen.
- **Nachstellen:** `sh/perf.sh <root> head DN1 modern deck --stage=dev_testetappe --vehicle=limousine --hour=22
  --weather=rain --seed=7 --timescale=1 --max-seconds=900` (Treiber `sh/qa_perf.gd`; JSON-Feld `spikes`).
- **Behebung:** die drei Haken mit `Time.get_ticks_usec()` je Abschnitt instrumentieren und bei > 8 ms den Abschnitt
  loggen (wie `STATDBG` in RINT-M2); Verdacht: Aufbau neuer Lampen-/Flare-Pools bzw. das Bauen von Fahrzeugstufen
  im Hauptfaden beim ersten Auftreten (Vorwärmen in `prepare()` oder in Stücken unter Zeitbudget wie `warm_step()`).
  Abnahme auf dem Deck: Bildzeit p99 ≤ 33 ms, kein Bild > 50 ms auf Kiel – Hamburg und der Testetappe nachts.

### F-09 (niedrig) „Niedrig“: Primitive bei 88 % des Budgets; Schatten-Draw-Calls nicht messbar
- **Was:** Kiel – Hamburg „Niedrig“ Primitive max 221 k von 250 k (gemessen); „Niedrig“ spart gegenüber „Mittel“ nur
  11 % Primitive. Die Schatten-Draw-Calls meldet `viewport_get_render_info(…SHADOW…)` im Compatibility-Renderer als 0,
  obwohl Schatten-Primitive gemeldet werden (Hoch 182 k) – das Budget „Draw-Calls inkl. Schatten“ ist so nicht prüfbar.
- **Behebung:** Bauten (Stadthäuser, Brücken, Tankstelle) eine zweite Detailstufe nach `Details` geben bzw. ihre
  lod-Distanz mit `details` skalieren; Budgetprüfung auf Primitive inkl. Schatten umstellen oder die Schatten-Draws
  aus `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` nehmen (gefolgert, nicht probiert).

## 6. Geprüft und in Ordnung

- Arcade-Goldens 20/20 und 17/17 identisch; Regel-1-Dateien unberührt (gemessen).
- F1, F1-Außenspuren, F2 (≤ 0,596), F3 (0/5923), F7 (Gelände), Modell der Sichtprüfung, Pfad: alle grün (gemessen).
- Keine neue Verdeckung von Fahrzeugen durch Tankstellendach, Köhlbrand-Pylone/Seile, Hamburger Stadthäuser,
  Nürnberger Altstadt, Augustusbrücke, Startportal, Stadtgrenze Hamburg, T1–T4 (Sonde, gemessen); die beiden
  Sondentreffer (Grenzhäuschen auf dem Standstreifen, Backsteinhaus Frankfurt) stehen bei Arcade an derselben Stelle.
- Grenze nachts (warme Häuschenfenster, Dach), Augustusbrücke (Balustrade, Kandelaber), Köhlbrandbrücke nachts,
  Tunnel Valík bei Nacht (Portal, Röhre, Ausfahrt ohne Überstrahlung), Gotthard innen, Start- und Zieltor:
  mindestens gleich, oft besser als Arcade (angesehen).
- Nasse Fahrbahn nachts in Hamburg: Spiegelungen von Laternen und Rücklichtern, Regenstreifen; in 10 s Bewegung kein
  Sprung, den Arcade nicht auch hat (gemessen, `popscan.py`).
- Schnee nachts (N1): Flocken im Kegel, Rücklichter wie Arcade; Regen nachts: Abblendkegel 0,92–0,93× Arcade auf
  der eigenen Spur 15–35 m (gemessen) – im Rahmen von A-20 (0,7–1,15×).
- Deck 1280×800: Modern füllt den Schirm, HUD in den Ecken (angesehen).
- Instanzuniforms bei „Hoch“ über ganze Etappen ≤ 135 (Grenze 230), keine Ablehnung (gemessen).
- Speicher über 15 min (Kiel – Hamburg, Zeitraffer 1) und 215 km Bern – Mailand: flach, Waisen 0 (gemessen).
- Draw-Calls/Primitive aller Voreinstellungen unter den Budgets (gemessen; „Niedrig“ knapp, F-09).

## 7. Nicht geschafft (Zeit; Maschine stark belastet)

Nicht selbst angesehen: T1–T4 als A/B (nur Sonde und RINT-M2-Bögen), S5, C1 19:30, DEV, N2 16 Uhr, Kiel-Stadtrand
19:30/22 Uhr Schnee, Hamburg 19:30, Nürnberg 08/19:30/22 Uhr, Steinbrücke nachts, Gotthard-Portal 22 Uhr und
Gotthard-Ausfahrt bei Tag als Einzelbild (über RINT-M2s Clip gemessen), Grenze bei Tag, „Niedrig“/„Mittel“-Bilder,
N2 auf dem Deck. Keine Render-Prüfungen (`run_render_checks.sh`) und kein `run_tests.sh` in dieser Prüfung – die
Montage meldete 803/0 und 27/28 → angepasst; das System-QA prüft diese Tore.
