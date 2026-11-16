# AU-C1 – Fahrbahn, Reifen, Wind, Aufprall (Klangprofil „Modern“) – Bericht

Zweig `worktree-wf_f5d01292-ef8-1`, gesichert als `origin/wip/v080-au-c1`, Endstand **`4209268`** (Ablauf in
Abschnitt 9). Arbeitsverzeichnis `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1`,
Basis `2f4f260` (Endstand AU-D2). Kein Vorgänger dieses Laufs.

**Niemand hat diese Klänge gehört.** Alle Zahlen sind *gemessen* (diese Entwicklungsmaschine, Godot 4.7.2, ohne
Bildschirm, Dummy-Audiotreiber, Aufnahme am Master bei Standardreglern; die Maschine war von anderen Paketen mit
belastet), sofern nicht *abgeleitet* dabeisteht. Wie es auf dem Steam Deck, einer echten Soundkarte oder für ein Ohr
klingt, ist nicht gemessen – das beurteilt der Nutzer mit den Hörproben in diesem Ordner.

## 1. Was gebaut wurde

| Teil | Datei | Inhalt |
|---|---|---|
| Feed v1 | `scripts/audio/modern/audio_feed.gd` | Belag je Rad und am Auto (Asphalt; Beton je Autobahnabschnitt nach Landesanteil – in beiden Fahrtrichtungen gleich –; Kopfsteinpflaster in Altstadtblöcken und auf Steinbrücken; Stahldeck), Deckmaterial an jeder Brückenfuge, profilierte Randlinie nur auf `rumble_roads`, befestigter Rand in Tunnel/Brücke/Stadt, Zone `cutting`, Leitpfosten der Straßen ohne Leitplanke samt Berührung (`contact`). Rein, nur am und hinter dem Auto, nur aus `Track`/Plan, nie aus dem Renderer |
| Baustein `road` | `scripts/audio/modern/road_audio.gd` | Rollgeräusch je Belag auf zwei geschwenkten Spielern (linke/rechte Räder), Nässe, Schnee, Betonplatten im Achstakt, Brückenfugen mit dem Achsabstand des Autos, Vorbeifahrten seitenrichtig, Quietschen und Radieren, Wind in drei Bändern + Wummern (offenes Fenster), Böen, Zonen; alle Pegel als Lautheit am Master aus Daten |
| Baustein `impact` | `scripts/audio/modern/impact_audio.gd` | beansprucht `collision` und `rail_hit`; Schichten nach Schließgeschwindigkeit und Partner, seitenrichtig; Leitplanke (Streifen/Schlag) und Schleif-Schleife bei `rail_contact`; umgefahrene Leitpfosten; ohne Modern-Datei bleibt der Arcade-Ersatz |
| Schwenken | `scripts/audio/modern/modern_audio_pan.gd` (neu) | `AudioStreamPlayer2D` in eigenem `SubViewport`, Gesetz gleicher Leistung (Godots 2D-Schwenk ist linear) |
| Schleifen | `tools/audio/modern/vehicle_loops.py` → `assets/audio/modern/vehicle/` | 17 nahtlose Mono-Schleifen, 2,95 MB, mit `ref_kmh`, `pitch_exp`, `lufs_pitch` im Manifest |
| Einmalklänge | `tools/audio/modern/sfx_modern.py` → `assets/audio/modern/sfx/` | 17 Klänge (Fugen, Vorbeifahrten, Aufprall-Schichten, Leitplanke, Leitpfosten), 1,57 MB, mit `lufs_m`, `gaps_s`, `lead_ms` |
| Konfiguration | `config/game_config.json` → `audio.modern.feed`, `.road`, `.impact`, `.snapshots.impact` | alle Pegel und Regeln; Mischzustand `impact` senkt zusätzlich Auto −3 / Welt −4 dB |
| Tests | `tests/unit/audio_modern/test_road_audio.gd` (neu, 10), `test_audio_feed.gd` (+5, jetzt 13) | Pegelplan, Gesetze, Beläge, Fugen-Takt, Vorbeifahrten, Zonen, Aufprall, Leitplanke, Feed-Regeln |
| Doku | `docs/audio-modern.md` Abschnitt 15 (neu), 8, 4.1, 10, 12, 13; `_doc_modern` in der Konfiguration | |

AU-C1 belegt 4,52 MB; alle Modern-Klänge zusammen 17,9 von 23 MB (5,1 MB frei für AU-C2).

## 2. Abnahme – Punkt für Punkt

| Punkt | Ergebnis | Beleg |
|---|---|---|
| Schleifennähte knackfrei (QC) | **bestanden**: 17 Schleifen „Naht ×0,00–0,56“ (erlaubt ×2), 16 Fortsetzungsframes hinter `loop_end` | `qc_determinismus.txt` |
| Pegel, Format, Determinismus (QC) | **bestanden**: `audio_qc.py --folders vehicle,sfx --determinism` → „45 Klänge geprüft, 0 mit Fehlern, 0 Probleme“; `vehicle_loops.py` (18 Dateien, 17 Einträge) und `sfx_modern.py` (30 Dateien, 17 Einträge) erzeugen zweimal dieselben Dateien | `qc_determinismus.txt` |
| Wind 3 dB, Reifen 4 dB unter dem Motor bei Höchsttempo, Parameter in Daten | **bestanden** im Test (`test_the_loudness_plan_at_top_speed`, ±0,05 dB) gegen den gemessenen Motor je Auto (`road.engine_top_lufs`); im Spiel nachgemessen trifft die Rechnung auf 0,1 dB (Reifen −19,98 bei Ziel −20,0, Wind −18,99 bei −19,0; Gran Turismo, damals mit Plan-Bezug) | Abschnitt 3 |
| Kollisionen nach Tempo und Partner geschichtet, seitenrichtig | **bestanden** (`test_collisions_by_closing_speed_and_partner`); Spitzen nur `MImpact`, lauterer Kanal: Rempler 6 km/h −11,2 → Auffahren 30 km/h −7,8 → schwer 70 / 130 km/h −3,8 / −2,8 dBFS; Lkw 40 / 110 km/h −5,3 / −3,8; Leitplanke 0,5 / 2 / 5 m/s −15,5 / −8,2 / −4,5; der andere Kanal 12,4 dB leiser | Abschnitt 3, `schicht_aufprall_…` |
| Schlimmster Fall ≤ −0,5 dBTP am Master | **bestanden**: −2,26 dBTP, auf dem Endstand wiederholt **−2,44 dBTP** (Tunnel, Lkw, Martinshorn, Crash, Leitplanke, Musik; Standardregler) | Abschnitt 4 |
| Arcade spielt nichts Neues | **bestanden** (keine eingefrorene Datei berührt, Identitätstests, Ladeprüfung, Golden-Bilder) | Abschnitt 6 |
| MP3 je Ebene, 45–60 s Fahrt im Spielmix, Spektrogramme | 7 MP3 + 7 Spektrogramme + Beschreibungen; Fahrt 46,7 s | Abschnitt 5 |
| `tools/run_tests.sh` grün | **bestanden**: „642 Tests, 0 fehlgeschlagen“, alle CHECK-Blöcke OK, „Tests bestanden (638 s)“ – ein Lauf, auf `82c73c0` | `pruefung_run_tests.txt` |
| `tools/golden.sh check` | **bestanden**: „GOLDEN arcade: 20 von 20 identisch (170 s)“ – ein Lauf, auf `82c73c0` | `pruefung_golden.txt` |

Nach den beiden Prüfläufen kam nur noch `4209268` (reine Doku, `docs/audio-modern.md`).

## 3. Pegelplan (gemessen)

Bezug: der **Motor allein bei Höchsttempo** (`capture_mix.gd` mit `--mute-bus=MRoad,MWind`): Kompakt −18,5, Kombi
−17,2, Limousine −17,7, Sportwagen −17,8, Gran Turismo −17,5 LUFS. Die Motoren erreichen dort die −16 LUFS des Plans
nicht (AU-B hatte bei Höchsttempo −15,0 bis −16,6 gemessen – mit dem Platzhalter-Wind, der allein etwa −19 LUFS
beitrug). Darum stehen Wind und Reifen 3 / 4 dB unter dem gemessenen Motor, nicht unter −16 (Vertrag: „under the
engine“).

Ganze Fahrt mit allem außer Musik/Verkehr (`capture_mix.gd`, mit Plan-Bezug vor der Umstellung; die Umstellung senkt
Wind und Reifen bei Höchsttempo um 1,2–2,5 dB, abgeleitet):

| Abschnitt | Gran Turismo | Kompakt | Plan |
|---|---|---|---|
| Leerlauf | −23,9 | −24,2 | ≈ −24 |
| Vollgas durch die Gänge | −15,3 | −15,3 | −16 ± 1,5 |
| Höchsttempo | −14,4 | −14,6 | −16 |
| 130 km/h | −21,5 (Motor allein −22,0) | −20,8 (−23,0) | ≈ −21 |
| True Peak | −2,9 dBTP | −3,3 dBTP | ≤ −1 |

Bei 130 km/h liegen die Reifen etwa 7–9 dB, der Wind etwa 12–16 dB unter dem Motor (abgeleitet aus den Gesetzen
– Reifen 30, Wind 55 dB je Dekade – und dem gemessenen Motor bei 130 km/h). Asphalt allein bei 100 km/h
(Limousine): −33,1 LUFS gemessen, −33,4 nach der Rechnung. Die Höchsttempo-Zeile liegt 1,6 dB über −16: Plan D29 und
die Beziehung „Wind −3, Reifen −4 unter dem Motor“ gelten bei Höchsttempo nicht zugleich (Abschnitt 8).

Probefahrt Kiel – Hamburg (Limousine), Fahrbahn+Wind allein gegen den ganzen Mix je Abschnitt: Autobahn 170 km/h
−5,6 dB, Köhlbrandbrücke −8,7, Rüttelstreifen −6,4, Bankett −3,4, Leitplanke −2,4, Pflaster 50 km/h −4,6 dB; die
ganze Fahrt −16,9 LUFS, True Peak −3,7 dBTP, der Begrenzer greift nirgends.

Aufprall (nur `MImpact` hörbar, Limousine 110 km/h, an den Einsätzen im Ton gemessen): siehe Abschnitt 2. Die Werte
treffen `peak_db` + Gesetz + Schwenk (+2,8 dB auf dem lauteren Kanal) auf etwa 1 dB; wo Schichten zugleich einsetzen
(schwerer Aufprall), liegt die Summe 2–3 dB über der lautesten Schicht. Leitpfosten −11,2, Schleifen −11,7 dBFS
(−10,8 dBTP).

Rechenzeit je Bild (Mittel / Maximum, belastete Maschine): Feed 0,06 / 3,0 ms, `road` 0,14 / 1,2 ms, `impact`
0,01 / 0,7 ms.

## 4. Der schlimmste Fall

`worst_case.gd` (Arbeitsordner): Gran Turismo 230 km/h im Tunnel (Hall), Untersteuern, zwei Lkw und ein Pkw dicht,
Polizei mit Martinshorn, Rennmusik, schwerer Crash in einen Lkw (140 km/h Schließgeschwindigkeit), harter
Leitplankenschlag mit Schleifen, zweiter Crash; 14 s. Aufnahme am Master hinter dem Begrenzer und davor
(Gesamtlautstärke 0,8):

| Fassung | vor dem Begrenzer | Frames über −0,8 dBFS | nach dem Begrenzer (True Peak) |
|---|---|---|---|
| alles (Endstand) | +3,57 dBFS | 4 087 | **−2,44 dBTP** |
| alles (Stand `54099de`, gleiche Klänge im Tunnel) | +4,06 | 3 919 | −2,26 |
| ohne Verkehr/Martinshorn (`MWorld` stumm) | +0,83 | 22 | −2,07 |
| ohne AU-C1 (`MImpact`, `MRoad`, `MWind` stumm) | +3,83 | 3 425 | −2,60 |
| nur AU-C1 | **+0,02** | 1 | −2,40 |
| nur AU-C1, vor der Korrektur (Stand nach `118f65b`) | +2,08 | 90 | −1,54 |

Die Last auf dem Begrenzer kommt von den Platzhaltern für Verkehr und Martinshorn (Arcade-Pegel, AU-C2). Meine Spitzen
habe ich gesenkt: gegen einen Lkw ersetzt dessen Schlag den eigenen, die Schichten setzen 4/9/40 ms versetzt ein,
die schwere Stufe −2 dB, das Schleifen 12 dB je Dekade bis höchstens −17 LUFS, Funken und Rüttelschläge in den
Schleifen weich begrenzt, der Mischzustand `impact` senkt Auto und Welt. Der Begrenzer arbeitet auf Abtastwerten
und überschwingt im True Peak um 0,1–0,7 dB (gemessen, Endstand; vor der Korrektur bis 1,5 dB). Bei
Gesamtlautstärke 1,0 statt 0,8 läge der schlimmste Fall darum bei etwa −0,5 bis −0,1 dBTP (abgeleitet: der
Begrenzer sitzt vor der Lautstärke des Masters).

## 5. Hörproben (dieser Ordner)

| Datei | Inhalt |
|---|---|
| `fahrt_kiel_hamburg_spielmix.mp3` (46,7 s) | Autobahn 170 km/h, Asphalt → Beton (A7 Holstein) – Köhlbrandbrücke 120 km/h (Stahldeck, Fugen) – Rüttelstreifen – Bankett – Leitplanke (Schlag, Schleifen) – Kopfsteinpflaster Hamburg 50 km/h; Motor v3 der Limousine, ohne Musik und Verkehr |
| `fahrt_kiel_hamburg_nur_fahrbahn_und_wind.mp3` | dieselbe Fahrt ohne Motor |
| `schicht_belaege_nacheinander.mp3` | Asphalt, Beton, Stahldeck, Pflaster, Bankett, Gras, nass, Schnee |
| `schicht_ruettelstreifen_und_fugen.mp3` | Rüttelstreifen, Stahlbrücke, Betonplatten je bei drei Tempi |
| `schicht_wind_50_bis_250.mp3` | Wind 50 → 250 km/h, dann auf einer Brücke |
| `schicht_reifenquietschen.mp3` | Untersteuern 0,3/0,6/1,0, Spurwechsel, nass, Rutschen beim Unfall |
| `schicht_aufprall_nach_tempo_und_partner.mp3` | Rempler bis schwerer Aufprall, Lkw, Leitplanke, Schleifen, Leitpfosten (Spielmix mit Motor) |

Zu jeder Datei ein Spektrogramm (`…_spektrogramm.png`) und eine Beschreibung mit Zeitmarken (`….txt`), dazu
`uebersicht.json` (Länge, LUFS, True Peak). Alle Pegel wie im Spiel; die Schichten ohne Motor sind darum zum Teil leise.
Die Zeitmarken folgen der Uhr des Skripts; der aufgenommene Ton läuft ihr bis 0,4 s voraus (Dummy-Treiber,
gemessen an den Einsätzen) – die Marken sind auf etwa ±0,2 s genau. Die Abschnitte der Fahrt sind Ausschnitte der
echten Strecke nacheinander (Sprünge dazwischen), nicht eine durchgehende Fahrt.

## 6. Arcade unverändert – Belege

1. **Keine eingefrorene Datei berührt**: `git diff --name-only 2f4f260..4209268` über alle Pfade von Regel 1
   (`scripts/race/…`, `scripts/gameplay/`, `scripts/data/`, `scripts/audio/{engine_audio,engine_bank,engine_gearbox,
   room_audio,sfx_synth,traffic_audio}.gd`, `assets/sprites/`, `assets/audio/{engines,traffic,music}/`,
   `tools/audio/{engine,traffic,music}_synth.py`, `data/`), dazu `audio_manager.gd` und `scripts/ui/`: **0 Dateien**.
   Außerhalb von `scripts/audio/modern`, `assets/audio/modern`, `tools/audio/modern`, `tests/unit/audio_modern`,
   `docs/audio-modern.md` und `config/game_config.json` ist nichts geändert. In der Konfiguration nur
   `audio.modern.*` und der Beschreibungstext `audio._doc_modern`.
2. **`test_arcade_identity.gd` grün** (6 Tests): Motor-Mischer byte-gleich zu v0.7.0 (auch mit laufendem Modern-Profil),
   alle SfxSynth-Klänge byte-gleich, Verkehrs- und Raummodell gleich, eingefrorene Klangdateien unverändert,
   Pegeltabelle der Einmalklänge = AudioManager (`LEVEL_DB` unverändert).
3. **`test_modern_checks.gd` grün**: `check_arcade_lean` (ein Start mit Profil Arcade lädt nichts aus
   `scripts/audio/modern` – also auch keinen der neuen Bausteine), `check_modern_audio` mit und ohne Wiedergabe
   (Ereignisse und `set_vehicle_state` im Profil Arcade ändern nichts; 20 Wechsel Arcade ↔ Modern ohne
   zurückbleibende Knoten; Busse wie in v0.7.0).
4. **Golden-Bilder**: 20 von 20 identisch.

Der Ersatz von `crash`/`rail` geschieht nur im Profil Modern: Dort nimmt der Baustein `impact` die Ereignisse
`collision`/`rail_hit` an, und ModernAudio verwirft den gleichzeitigen `play()` (AU-A-Mechanik).

## 7. Ehrliches Urteil

- **Was die Messungen sagen**: Pegel treffen ihre Ziele im Spiel auf 0,1 dB (Schleifen) bzw. etwa 1 dB
  (Aufprall-Spitzen); Nähte sind sauber; jede Ebene zeigt im Spektrogramm die vorgesehene Struktur (Achstakt der
  Platten, Brückenfugen als Doppelschlag von Vorder- und Hinterachse, Obertonband des Rüttelstreifens, Knirschen des
  Banketts, Schwingen der Leitplanke, dichtes Pflaster). Der Begrenzer greift auf der Probefahrt nie.
- **Was sie nicht sagen**: ob es nach Straße klingt oder nach gefiltertem Rauschen. Alles ist synthetisch (geformtes
  Rauschen, Ereignisketten, Resonanzen). Am ehesten künstlich wirken könnten (abgeleitet): das Asphalt-Rollen
  (gleichmäßiges Rauschen mit Hohlraumton), das Quietschen (ein Ton mit Zittern – echtes Quietschen ist
  chaotischer), die Glasschicht (hohe Klingeltöne), der Wind bei offenem Fenster.
- **Gewichtung**: Auf der Autobahn sitzen Reifen und Wind deutlich unter dem Motor. Wer mehr Fahrbahn will:
  `audio.modern.road.tyres.under_engine_db` kleiner. Kopfsteinpflaster, Rüttelstreifen, Bankett und Leitplanke sind
  nach der Probefahrt angehoben, Brückenfugen gesenkt.
- **Schwere Aufpralle sind heiß**: −2,8 dBFS auf dem lauteren Kanal bei Gesamtlautstärke 0,8 – im vollen Mix
  arbeitet dann kurz der Begrenzer. Gewollt (ein Crash darf alles überdecken), aber am fertigen Mix (AU-E) zu prüfen.
- **Kurze Schleifen** (0,8–3 s): Bei konstantem Tempo kann ein aufmerksames Ohr die Wiederholung im Rollen hören
  (abgeleitet); zwei versetzte Spieler je Ebene und die Tonhöhe mit dem Tempo verdecken es.
- **Zum Hören besonders**: Asphalt → Beton (wird der Plattentakt bei 170 km/h als Rhythmus gehört?), Brückenfugen
  (Doppelschlag glaubhaft?), Pflaster bei 50 km/h (zu laut?), Wind bei 250 km/h, schwerer Aufprall (Glas?).

## 8. Abweichungen und Befunde am Vertrag

Abweichungen:
1. Neue Datei `scripts/audio/modern/modern_audio_pan.gd` (+ `.uid`, geschwenkte Spieler für `road` und `impact`) –
   nicht in der Dateiliste von AU-C1, kein anderes Paket besitzt sie.
2. Zwei Stellen in Tests von AU-A angepasst, deren Platzhalter-Verhalten ich ersetzt habe: `test_modern_audio.gd`
   (Windgesetz; „crash/rail sofort beim Aufprall-Baustein“ → wartet 50 ms auf sein Ereignis) und
   `check_modern_audio.gd` (Delegation: der `play("crash")` fällt für sein Ereignis `collision` weg).
3. Bezug des Pegelplans ist der gemessene Motor je Auto (Daten `road.engine_top_lufs`), nicht
   `loudness.full_throttle_lufs`.
4. `audio.modern.snapshots.impact` um `MCar` −3 / `MWorld` −4 dB erweitert (Kopfraum beim Aufprall), und der
   Beschreibungstext `audio._doc_modern` (eine Ebene über `audio.modern`) ergänzt.
5. Leitpfosten-Positionen liest der Feed aus `road.delineator_every_m` (dieselbe Regel, nach der die Straße sie
   zeichnet) – eine Konfiguration der Straße, kein Renderer-Wert.
6. Die Zone „cutting“ ist eine Regel aus Felsen am Rand – die Daten kennen keine Einschnitte.
7. Die Hörproben entstehen mit eigenen Skripten im Arbeitsordner (Sprünge entlang der echten Strecke), nicht mit
   `capture_mix.gd` (Befund 4).

Befunde am Vertrag:
1. **D29 gegen die Beziehung der Studie**: „Vollgas −16 LUFS“ und „Wind −3 / Reifen −4 dB unter dem Motor bei
   Höchsttempo“ ergeben bei Höchsttempo gemessen −14,4 bis −14,6 LUFS (+2,8 dB Summe, abgeleitet). Beides zugleich
   geht nur, wenn der Motor bei Höchsttempo leiser wird. Entscheidung für AU-E/Leitung.
2. **Die Motoren erreichen bei Höchsttempo die −16 LUFS nicht** (−17,2 bis −18,5 allein) – AU-Bs Tabelle enthielt den
   Platzhalter-Wind.
3. **Schlimmster Fall nur bei Standardlautstärke sicher**: Verkehr und Martinshorn (Platzhalter mit Arcade-Pegeln)
   treiben den Begrenzer um bis 4 dB; der Begrenzer (Schwelle −0,8 dB aus der Arcade-Konfiguration, vor der
   Gesamtlautstärke) begrenzt Abtastwerte und überschwingt 0,1–0,7 dB. Bei Gesamtlautstärke 1,0 etwa −0,5 bis
   −0,1 dBTP statt ≤ −0,5 (abgeleitet). Gehört zu AU-C2 (Pegel) und AU-E/Leitung (Begrenzer).
4. **`capture_mix.gd` sendet keinen Fahrzeugzustand** – seine Fahrt rollt ohne Feed auf Asphalt; für Belag, Fugen und
   Leitplanke braucht es ein Werkzeug mit Strecke (meine liegen im Arbeitsordner, nicht im Repository).
5. **Kein Panorama am `AudioStreamPlayer`**: Der Vertrag verlangt seitenrichtige Klänge; das geht nur über
   `AudioStreamPlayer2D` in einem eigenen `SubViewport` (gelöst mit `ModernAudioPan`).

## 9. Ablauf und Prüfungen

Commits (alle sofort nach `origin/wip/v080-au-c1` geschoben, ohne Force):

| Commit | Inhalt |
|---|---|
| `36f2ff5` | AudioFeed v1 – Belag, Rüttellinie je Straße, Leitpfosten, Einschnitt (+ Tests, `audio.modern.feed`) |
| `063cd85` | Schleifen für Reifen, Fahrbahn, Wind und Leitplanke (`vehicle_loops.py`, 17 Dateien) |
| `1700749` | Einmalklänge für Fugen, Vorbeifahrten, Kollisionen, Leitplanke (`sfx_modern.py`, 17 Klänge) |
| `23fc4a9` | Bausteine `road` und `impact`, `ModernAudioPan`, `audio.modern.road/impact`, `test_road_audio.gd`, AU-A-Tests angepasst |
| `118f65b` | Bezug des Pegelplans: gemessener Motor bei Höchsttempo je Auto |
| `54099de` | Spitzen im schlimmsten Fall – Aufprall gestaffelt, Schleifen begrenzt |
| `a6cd6d0` | Pegel nach der Probefahrt Kiel – Hamburg |
| `be2f2af` | Rüttelstreifen und Brückenfugen bei hohem Tempo unter dem Begrenzer |
| `ef34418` | Doku (Abschnitt 15, Feed v1, `_doc_modern`) |
| `82c73c0` | `.uid` des neuen Tests |
| `4209268` | Doku: gemessene Aufprall-Spitzen, schlimmster Fall auf dem Endstand |

Prüfungen in dieser Reihenfolge (jede mit `nice -n 19`, nie zwei gleichzeitig, `XDG_DATA_HOME` absolut im
Arbeitsordner):
1. `audio_qc.py --folders vehicle,sfx --determinism` → OK (Exit 0) – `qc_determinismus.txt`
2. `tools/run_tests.sh` (einmal, voll) → 642 Tests, 0 fehlgeschlagen, alle Checks OK, Exit 0 – `pruefung_run_tests.txt`
3. `tools/golden.sh check` (einmal) → 20 von 20 identisch, Exit 0 – `pruefung_golden.txt`
4. Schlimmster Fall (vier Fassungen) und Aufprall-Aufnahme nur mit `MImpact` auf dem Endstand wiederholt (Abschnitte 2–4).

Während der Arbeit liefen die eigenen Tests einzeln (`test_road_audio`, `test_audio_feed`, `test_modern_audio`,
`check_modern_audio` mit und ohne `--live`), alle grün.

## 10. Hinweise für die Nächsten

- AU-C2: `feed.zone` (inkl. `cutting`), `feed.deck`, `feed.paving` und die Ereignisse stehen bereit; `ModernAudioPan`
  für eigene seitenrichtige Klänge; Verkehrs- und Martinshorn-Pegel senken (Abschnitt 4); 5,1 MB Klangbudget frei.
- AU-E: `road.engine_top_lufs` neu messen, wenn sich die Motoren ändern; Höchsttempo-Zeile entscheiden; Mischzustand
  `impact` und die heißen schweren Aufpralle am fertigen Mix abstimmen; Begrenzer-Schwelle bei Gesamtlautstärke 1,0.
- Kein eigener Schnee-Klang (Dämpfung und Knirschen aus dem Schotter); Radstand = 0,6 × Länge (keine Daten), die
  Betonplatten-Schleifen sind für 2,7 m entworfen.
- Werkzeuge im Arbeitsordner (`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-C1/`):
  `drive_demo.gd` (Probefahrt), `layers_demo.gd` (Szenarien), `worst_case.gd` (+ `worst_variants.sh`), `perf.gd`,
  `media.py`, `phases.py`, `peaks.py` – Kandidaten für `tools/audio/modern/` (dort AU-A/AU-E).
