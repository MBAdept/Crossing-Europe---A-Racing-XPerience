# Klangprofil „Modern“ – der Kern (v0.8.0, Paket AU-A)

Seit v0.8.0 hat das Spiel zwei Klangprofile. **Arcade** ist der Klang von v0.7.0 und bleibt, wie er ist: dieselben
Klassen, Dateien, Busse und Pegel. **Modern** ist ein zweiter, eigenständiger Klang daneben – neuer Motor, Fahrbahn,
Umgebung, Verkehr, Musik im Rennen. Dieses Dokument beschreibt den Kern, auf dem die Klangpakete AU-B bis AU-E
aufbauen: wer das Profil wählt, wie der `AudioManager` an `ModernAudio` übergibt, die Busse, den Pegelplan, die
Schnittstelle der Bausteine, das Format der Klangdateien, die Werkzeuge und die Prüfungen.

Vertrag: `docs/dev/v080_contract.md` (D25–D30, §4.7, Regeln 1, 3 und 4). Alle Zahlen in diesem Dokument sind als
**gemessen** (auf der Entwicklungsmaschine, Godot 4.7.2, ohne Bildschirm mit dem Dummy-Audiotreiber, sofern nichts
anderes dasteht) oder als **abgeleitet** gekennzeichnet.

## 1. Stand nach Welle 0

- Das Gerüst steht: `ModernAudio` besitzt Busse, Pegelplan, Klangdateien, den Strecken-Feed und neun Bausteine.
- Die Bausteine sind **Platzhalter, die funktionieren**: Sie spielen den heutigen Arcade-Inhalt (Motorbank,
  Verkehrsklänge, Wind, Regen, Einmalklänge, Titelmelodie) über die Modern-Busse. Modern klingt deshalb heute wie
  Arcade auf dem Pegel des neuen Plans – mit dem neuen Mischverhalten (Ducking, Mischzustände, Pause-Tiefpass).
  Die Pakete AU-B, AU-C1, AU-C2 und AU-D1 ersetzen je den Inhalt ihrer Bausteindatei; an `ModernAudio`, am
  `AudioManager` und aneinander müssen sie dafür nichts ändern.
- Unter `assets/audio/modern/` liegt je Ordner eine kleine erzeugte **Platzhalter-Datei** mit Manifest. Sie belegt
  Format, Import und Prüfwerkzeug; im Spiel klingt nie ein Platzhalter (Abschnitt 9).
- **Seit AU-B (Welle 2)** sind die Bausteine `engine` und `layers` keine Platzhalter mehr: Motor v3 mit eigenen
  Stereobanken, einem Mischer-Thread und nativ gemischten Fahrzeugebenen – beschrieben in
  [motorsound.md](motorsound.md), Abschnitt 6. `levels.MSfx` steht seitdem auf 0 dB (Abschnitt 6.1). Für die
  übrigen Bausteine gilt die Liste weiter.
- **Seit AU-D1** ist der Baustein `music` kein Platzhalter mehr: das Titel-Remaster in den Menüs, Rennstück 1
  „Linke Spur“ mit Einzähler auf „LOS!“, Schleife und Schluss am Taktstrich, die Musik-Kette unter
  `tools/audio/music/` – Abschnitt 14.
- Seit UI1 schaltet das Spiel das Profil selbst um: die Einstellung „Klang“ [Wie Grafik | Arcade | Modern], und
  `GameFlow` ruft `AudioManager.set_profile(Settings.sound())` beim Start und bei jeder Änderung. Für Tests bleiben
  `--sound=modern` und `audio.profile` (Abschnitt 2).
- **Seit AU-D2** spielen drei Rennstücke reihum („Linke Spur“, „Nachtfahrt“, „Rückenwind“), zwischen den Etappen das
  Zwischenspiel; das Ziel ist Musik (Ziel-Schlag, Schluss, „Rekord“, „Finale“), „Erwischt“ und „Tank leer“ haben
  Stinger in der Tonart des laufenden Stücks; die Menüklänge `ui_move`, `ui_ok`, `ui_back` sind Modern-Dateien
  (`assets/audio/modern/ui/`); Bass, Höhen und Musikpegel aller Stücke stehen in `tools/audio/music/mischung.json`
  – Abschnitt 14.
- **Seit AU-C1** sind die Bausteine `road` und `impact` keine Platzhalter mehr: Rollgeräusch je Belag und Seite,
  Nässe, Schnee, Betonplatten, Brückenfugen, Rüttelstreifen, Bankett, Gras, Vorbeifahrten, Quietschen, Wind mit
  Böen und Zonen, Kollisionen nach Schließgeschwindigkeit und Partner, Leitplanke, Leitpfosten; dazu der Feed v1
  (Belag, Deck, Rüttelstraßen, Leitpfosten, Einschnitt) – Abschnitt 15.
- **Stand nach AU-R3** (die letzte kleine Korrektur vor den Abnahmeprüfungen): Klangdateien, Pegel und Musik wie nach
  AU-R2; der Feed legt kein Altstadtpflaster mehr auf Brücken ohne Steindeck (der Damm nach Venedig ist Asphalt), und
  jede Altstadt mit einer solchen Brücke bekommt ihren Pflasteranteil auf ihren Straßen. Die Abnahmekriterien des
  Modern-Klangs (Leitungsentscheide V1–V3) stehen in Abschnitt 15.11.

## 2. Profil wählen

| Weg | Wirkung |
|---|---|
| `AudioManager.set_profile("arcade" \| "modern")` | schaltet um; ein zweiter Aufruf mit demselben Profil tut nichts. **Nie während einer Etappe** aufrufen (Vertrag §4.7.1) – laufende Klänge werden hart beendet. |
| `AudioManager.profile()` | das Profil in Kraft |
| Kommandozeile `--sound=arcade\|modern` | Profil beim Start; gewinnt gegen die Konfiguration |
| `audio.profile` in `config/game_config.json` oder `user://game_config.json` | Profil beim Start (`""` = keins erzwingen) |
| Einstellung „Klang“ [Wie Grafik \| Arcade \| Modern] | seit UI1: `GameFlow` ruft `set_profile(Settings.sound())` beim Start und bei jeder Änderung |

Ohne Vorgabe startet das Spiel mit Arcade. `set_profile("modern")` hält den Arcade-Klang an (`stop_all()`, Menümusik
aus), baut einen Knoten `ModernAudio` als Kind des `AudioManager`, startet ihn und übergibt, was die Menüs schon
gesetzt haben (Menümusik an/aus, Musik-Kontext, Schalter „Musik im Rennen“). `set_profile("arcade")` beendet
`ModernAudio` (Player, Threads, alle 22 Modern-Busse), gibt den Knoten frei und schaltet die Menümusik wieder auf
den Arcade-Player, wenn sie laufen soll.

Der `AudioManager` und alles unter `scripts/audio/` lesen weder den Grafikmodus noch etwas vom Renderer (Regel 4).

## 3. `AudioManager`: was dazukam, was delegiert wird

Neu (Vertrag §4.7.1): `set_profile(id)`, `profile()`, `set_race_music(on)`, `set_music_context(ctx, args)`,
`set_track(track, plan)`, `set_vehicle_state(state)`, `event(name, args)`. Die letzten fünf tun mit dem Profil Arcade
nichts; Musik-Kontext und der Schalter „Musik im Rennen“ werden für den nächsten Profilwechsel gemerkt.

Mit dem Profil Modern reicht jede bestehende Methode ihren Aufruf an `ModernAudio` weiter und kehrt zurück – der
Arcade-Teil läuft dann nicht (auch `_process` nicht):

| Methode | Modern |
|---|---|
| `set_engine`, `set_wind`, `set_siren`, `set_rain`, `set_skid`, `hud_hints` | Werte des Bildes, gesammelt in `ModernAudioFrame` |
| `set_traffic`, `set_environment` | Fahrzeugliste, Hörer, Tunnel – ebenso |
| `play(name, gain_db)` | Einmalklang an den ersten Baustein, der ihn nimmt (Abschnitt 7) |
| `stop_all()` | alle Bausteine sofort still; die Musik läuft weiter |
| `set_vehicle(id)`, `preview_engine(id)` | Baustein Motor |
| `engine_state()`, `engine_perf()`, `traffic_state()`, `traffic_perf()` | Antwort der Bausteine Motor / Verkehr, gleiche Schlüssel wie in Arcade |
| `set_music(on)` | Baustein Musik (Abschnitt 7) |
| `apply_volumes()` | „Gesamtlautstärke“ wie bisher auf `Master`, „Effekte“ auf `MSfx`, „Musik“ auf `MMusic` |

Signaturen und Arcade-Verhalten aller bestehenden Methoden sind unverändert; `gear_for()` und `bank_for()` sind
statisch bzw. profilunabhängig. Mit `--perf` gibt beim Beenden das Profil in Kraft seine Zeile `AUDIO_PERF` aus.

**Spätes Laden.** `AudioManager` nennt `ModernAudio` nicht als Typ: `_modern` ist untypisiert, das Skript wird erst
in `set_profile("modern")` über seinen Pfad geladen (`MODERN_SCRIPT`). Eine typisierte Variable ließ die Engine bei
**jedem** Spielstart alle 19 Skripte aus `scripts/audio/modern` übersetzen, auch mit dem Profil Arcade. Gemessen
auf dieser VM vor und nach der Korrektur (nach der Abnahme von Bauabschnitt 0): 19 geladene Skripte gegen keins;
„Load Autoloads“ im Engine-Benchmark (`godot --headless --benchmark --quit-after 3`, 15 Läufe abwechselnd) im
Median 536 ms gegen 448 ms; statischer Speicher nach dem Start 44,26 MiB gegen 40,69 MiB (je eine Messung mit
einer Sonde). Den Stand hält `check_arcade_lean.gd` fest (Abschnitt 12). Die Regel dahinter gilt für jede Datei, die ein Arcade-Start lädt
(Autoloads, `race_session.gd`, HUD): Wer dort eine Klasse aus `scripts/audio/modern`, `scripts/race3d` oder
`ModelDB` als Typ, in einem `preload` oder als Konstante nennt, lädt wieder den ganzen Ordner.

## 4. Aufbau

```
AudioManager (Autoload)
└─ ModernAudio (Knoten, nur solange das Profil „modern“ ist)      scripts/audio/modern/modern_audio.gd
   ├─ ModernBuses          die 22 Busse und ihre festen Effekte   modern_buses.gd
   ├─ ModernMix            Pegelplan, Ducking, Mischzustände      modern_mix.gd        (rein, ohne AudioServer)
   ├─ ModernAudioAssets    Manifeste und Klangdateien             modern_audio_assets.gd
   ├─ AudioFeed            was die Strecke am Auto hergibt        audio_feed.gd        (rein)
   ├─ ModernAudioContext   was jeder Baustein bekommt (ctx)       modern_audio_context.gd
   ├─ ModernAudioFrame     die Werte des Bildes                   modern_audio_frame.gd
   └─ neun Bausteine (ModernAudioModule)                          Abschnitt 4.1
```

Je Bild sammelt `ModernAudio.step()` die Aufrufe des `AudioManager` mit der Arcade-Semantik in einen
`ModernAudioFrame`: Aufrufe bei pausiertem Baum oder im Bild eines `stop_all()` zählen nicht; ruft die Rennsitzung
`set_engine()` 0,35 s lang nicht mehr auf, gilt sie als weg (`frame.alive = false`); ausdrückliche `set_rain()` /
`set_skid()` gewinnen eine Sekunde lang gegen die HUD-Hinweise. Danach laufen der `AudioFeed`, die Bausteine in
fester Reihenfolge und zuletzt die Mischung (Fader, Tiefpässe, Renn-EQ, Stummschaltung der Effekte).

Ohne Bildschirm (`--headless`) und in Unit-Tests gibt es keine Player (`ctx.live = false`), wie beim
Arcade-`AudioManager`: Die Bausteine führen dann nur ihren Zustand (Getriebe, Stimmen, Musik-Kontext).
`ModernAudio.force_live = true` spielt trotzdem (Prüfungen und Messwerkzeuge).

### 4.1 Bausteine

Ein Baustein ist eine Klasse, die von `ModernAudioModule` erbt. `ModernAudio` legt je Baustein ein Objekt an, ruft
seine Haken und gibt es beim Ende des Profils frei. Dateiname und Klassenname sind fest – ein Paket ersetzt den
Inhalt der Datei und behält beides.

| Baustein | Datei · Klasse | Busse | Platzhalter in Welle 0 | ersetzt durch |
|---|---|---|---|---|
| `env` | `env_acoustics.gd` · `EnvAcoustics` | Effekte auf `MEnv` | heutiger Raumklang: zwei frühe Reflexionen, Tunnelhall (`RoomAudio` nur als Rechenmodell) | AU-C2 |
| `engine` | `engine_audio3.gd` · `EngineAudio3` | `MEngine` | Arcade-Zyklenbank über die unveränderten Klassen `EngineAudio` / `EngineBank` / `EngineGearbox`, im Hauptthread, mit dem Breiten-Hall des Arcade-Motorbusses | AU-B – **erledigt**: Motor v3 (Stereobank `EngineBank2`, Mischer-Thread `EngineMixThread`, kein Hall auf dem Bus; [motorsound.md](motorsound.md) 6) |
| `layers` | `vehicle_layers.gd` · `VehicleLayers` | `MEngineFx` | still (die Arcade-Bank trägt ihr Turbopfeifen selbst) | AU-B – **erledigt**: Lader, Antriebsheulen, Gasannahme, Lastwechselschlag, Schubumluft |
| `road` | `road_audio.gd` · `RoadAudio` | `MRoad`, `MWind` | Wind und Reifenquietschen mit den Arcade-Formeln | AU-C1 – **erledigt**: Reifen je Belag und Seite, Nässe, Schnee, Fugen, Rüttelstreifen, Vorbeifahrten, Quietschen, Wind (Abschnitt 15) |
| `impact` | `impact_audio.gd` · `ImpactAudio` | `MImpact` | `crash` und `rail` als Einmalklänge mit den Arcade-Pegeln | AU-C1 – **erledigt**: beansprucht `collision` und `rail_hit`; Schichten nach Tempo und Partner, Leitplanke mit Schleifen, Leitpfosten (Abschnitt 15) |
| `ambience` | `ambience_audio.gd` · `AmbienceAudio` | `MAmb` | Regenschleife | AU-C2 |
| `traffic` | `traffic_extras.gd` · `TrafficExtras` | `MTrafficV0`–`7`, `MSiren` | das Arcade-Modell `TrafficAudio` unverändert (Unterklasse, die nur auf die Modern-Busse ausgibt), acht Stimmen, Arcade-Klänge | AU-C2 |
| `music` | `music_director.gd` · `MusicDirector` | `MMusic` | je Kontext ein Stück in Schleife, Überblenden mit zwei Playern | AU-D1 – **erledigt**: Titel-Remaster, Rennstück mit Einzähler, Schleife und Schluss über `AudioStreamInteractive`; AU-D2 – **erledigt**: drei Rennstücke reihum, Zwischenspiel, Schluss-Varianten, Ziel-Schlag, Stinger (Abschnitt 14) |
| `sfx` | `sfx_bank.gd` · `SfxBank` | `MUI`, `MSfx` | alle übrigen Einmalklänge; nimmt eine Modern-Datei, sobald ein Manifest sie nennt, sonst den `SfxSynth`-Klang | bleibt (Klänge: AU-C1; die Menüklänge in `ui/`: AU-D2, Abschnitt 14.9) |

Reihenfolge je Bild (`ModernAudio.SLOTS`): `env`, `engine`, `layers`, `road`, `impact`, `ambience`, `traffic`,
`music`, `sfx`. Nach dem Motor steht dessen Zustand als `frame.engine` (`rpm`, `gear`, `load`, `boost`) für die
folgenden Bausteine bereit – mit dem Motor v3 zusätzlich `shaft` (Laderdrehzahl 0…1), `limiter`, `shifting`,
`throttle` und Zähler, die nur wachsen (`upshifts`, `downshifts`, `blowoffs` mit `blowoff_level`, `starts`).

Haken (`scripts/audio/modern/modern_audio_module.gd`; was ein Baustein nicht braucht, lässt er weg):

| Haken | wann |
|---|---|
| `_setup()` | einmal, `ctx` ist gesetzt: Konfiguration lesen (`ctx.value("…")`, `ctx.number("…")` unter `audio.modern`), Klänge holen (`ctx.stream(ordner, id, arcade_ersatz)`), Player anlegen (`ctx.player(bus)`, liefert `null` ohne Wiedergabe) |
| `claims() -> PackedStringArray` | Sitzungsereignisse, die der Baustein selbst vertont (Abschnitt 7) |
| `set_vehicle(id)` | das Auto der nächsten Etappe |
| `track_changed(feed)` | eine Etappe beginnt (`feed.has_track()`) oder ist vorbei |
| `update(frame)` | jedes Bild – in den Menüs (`frame.alive` falsch), im Rennen, in der Pause (`frame.paused`) |
| `event(name, args)` | Ereignis der Sitzung (§4.7.2) oder des Feeds (`joint`, `pass_object`, `tunnel_in` …) |
| `play(sound, gain_db) -> bool` | Einmalklang nach seinem `AudioManager`-Namen; `true` = genommen |
| `stop_all()` | sofort still (neues Rennen, Szenenwechsel) |
| `teardown()` | das Profil endet: Threads beenden, Player mit `ModernAudioContext.free_player()` freigeben |
| `debug_state()` | einfache Daten für Tests |

Zusätzlich erwartet `ModernAudio` von einzelnen Bausteinen: `EngineAudio3.state()`, `.perf()`, `.preview(id)`;
`TrafficExtras.state()`, `.perf()`; `MusicDirector.set_context()`, `.set_legacy()`, `.set_race_music()`,
`.wanted()`, `.context`. Sie stehen im Kopf der jeweiligen Datei.

Regeln für Bausteine: nichts aus dem Renderer oder dem Grafikmodus lesen (Regel 4); nichts in die Simulation
zurückgeben (Regel 3); nicht in den `AudioManager` oder in einen anderen Baustein greifen; nur auf den eigenen
Bussen spielen; bewegte Pegel über einen Fader oder die Lautstärke des Players führen, nie über die Lautstärke
eines Busses (Abschnitt 11); Streams eines `AudioStreamGenerator` vor dem Freigeben an
`ModernAudioContext.keep_alive()` geben (Abschnitt 11).

Hilfsklassen: `ModernAudioLoop` (eine Schleife mit geglättetem Pegel und Tonhöhe: `attach`, `drive`, `silence`,
`release`), `ModernAudioVoices` (ein kleiner Vorrat an Playern für Einmalklänge).

## 5. Busse

`ModernBuses` legt die Busse beim Start des Profils hinter allen vorhandenen an und entfernt sie mit ihm. Die
Arcade-Busse (`Master`, `SFX`, `Music`, `Room`, `Engine`, `TrafficV<n>`, `Siren`) und ihre Effekte werden nie
angefasst; geteilt wird nur `Master` mit seinem Limiter.

```
Master
└─ MMaster                 Summenkompressor (audio.modern.glue), dahinter der Begrenzer (audio.modern.limiter, AU-R)
   ├─ MMusic               Musik: Renn-EQ, Pause-Tiefpass, Fader (Ducking, Mischzustände)
   └─ MSfx                 Effektgruppe: Regler „Effekte“, Pegel des Plans
      ├─ MUI               Menü- und Countdown-Klänge, Stinger
      ├─ MEnv              Umgebung: trocken + frühe Reflexionen + Hall, Pause-Tiefpass, Fader
      │  ├─ MCar           das eigene Auto, Fader
      │  │  ├─ MEngine     Motor
      │  │  ├─ MEngineFx   Turbo, Antriebsstrang
      │  │  ├─ MRoad       Reifen, Rüttelstreifen, Fugen
      │  │  └─ MWind       Wind
      │  ├─ MImpact        Kollisionen, Leitplanke
      │  └─ MWorld         andere Verkehrsteilnehmer, Fader
      │     ├─ MTrafficV0 … MTrafficV7     je Stimme ein Bus (Tiefpass = Luftdämpfung)
      │     └─ MSiren
      └─ MAmb              Ambiente-Betten (tragen ihren Raum selbst), Pause-Tiefpass, Fader
```

- **Reihenfolge der Indizes**: Ein Bus kann nur an einen Bus mit kleinerem Index senden – sonst sendet die Engine
  stillschweigend an `Master`. Die Busse werden deshalb in der Reihenfolge von `ModernBuses.GRAPH` angelegt, eine
  Gruppe vor ihren Mitgliedern. Das ist nicht die Reihenfolge, in der §4.7.3 die Namen aufzählt (dort steht `MEnv`
  zuletzt). `ModernBuses.verify()` prüft Namen, Sends und Indizes.
- **Ein Pfad für die Umgebung**: Ein Bus hat genau einen Send. `MEnv` trägt deshalb das trockene Signal, die frühen
  Reflexionen (`AudioEffectDelay`, trocken 1) und den Hall (`AudioEffectReverb`, trocken 1) in einer Kette.
- **Fester Pegel und bewegter Pegel**: Der feste Pegel eines Busses (Plan + Regler) ist seine Lautstärke. Alles,
  was sich bewegt, während Klang läuft (Ducking, Mischzustände), geht über einen `AudioEffectAmplify` am Ende der
  Kette („Fader“) auf `MMusic`, `MEnv`, `MCar`, `MWorld`, `MAmb`. Grund, gemessen: Eine geänderte Buslautstärke
  wirkt am Blockrand ohne Rampe – bei −6 dB an einem 100-Hz-Sinus ein Sprung vom 15- bis 33-fachen der
  Steilheit des Signals, also ein Knacken; `AudioEffectAmplify` blendet über den Block (1,0- bis 1,5-fach).
- **Effekte eines Bausteins**: `ctx.buses.effect(bus, klasse)` liefert den ersten Effekt dieser Klasse auf dem Bus
  und legt ihn bei Bedarf vor Tiefpass und Fader an (Beispiel: der Breiten-Hall des Platzhalter-Motors auf
  `MEngine`).

## 6. Pegelplan (Vertrag D29)

Ziele bei Standardreglern (Gesamt 0,8, Effekte 1,0, Musik 0,7), in `audio.modern.loudness`:

| Ziel | Wert |
|---|---|
| Vollgas (Kurzzeit-Lautheit) | −16 LUFS |
| Höchsttempo (Motor + Fahrbahn + Wind; AU-R) | −15 ± 1 LUFS (`top_speed_lufs`, `top_speed_tol_db`) |
| Reisetempo | ≈ −21 LUFS |
| Leerlauf | ≈ −24 LUFS |
| Musik im Rennen | 8 dB unter dem Auto bei Vollgas (≈ −24 LUFS), ≈ −19 LUFS im Leerlauf |
| Menümusik | −20 LUFS |
| Musikdateien | −14 LUFS, True Peak ≤ −1 dBTP |

### 6.1 Was die Kette heute liefert (gemessen)

Aufnahme des Master-Busses mit `tools/audio/modern/capture_mix.gd`, Lautheit mit `measure_mix.py` (BS.1770),
Gran Turismo, feste Fahrt (Leerlauf, Vollgas durch die Gänge, Höchsttempo, vom Gas, 130 km/h), Standardregler:

| Abschnitt | Arcade | Modern (Platzhalter-Bausteine) | Plan |
|---|---|---|---|
| Vollgas durch die Gänge | −13,1 LUFS (Kurzzeit höchstens −12,1) | −16,2 LUFS (Kurzzeit höchstens −15,3, Median −16,1) | −16 |
| Höchsttempo | −13,3 LUFS | −16,3 LUFS | −16 |
| Leerlauf | −17,2 LUFS | −20,4 LUFS | −24 |
| 130 km/h | −19,7 LUFS | −22,7 LUFS | −21 |
| ganze Fahrt, integriert | −14,2 LUFS | −17,2 LUFS | – |
| True Peak | −2,7 dBTP | −4,6 dBTP | ≤ −1 |
| Menümusik (erste 50 s der Titelmelodie) | −29,7 LUFS | −21,6 LUFS | −20 |

Einordnung: Vollgas trifft den Plan, weil `audio.modern.levels.MSfx` auf −3 dB steht – die Arcade-Bank ist bei
Vollgas 3 dB lauter als der Plan (gemessen −13,1 LUFS). Leerlauf und Reisetempo treffen ihn mit der Arcade-Bank
nicht (3,6 dB zu laut, 1,7 dB zu leise): Das ist das Lautstärkeverhältnis der alten Bank und Sache von AU-B. **AU-B
setzt `levels.MSfx` neu**, sobald der Motor v3 seine eigenen Pegel mitbringt. Die Menümusik liegt in den ersten
50 s bei −21,6 LUFS, weil dieser Abschnitt der Datei leiser ist als das ganze Stück (−15,5 gegen −14,1 LUFS,
gemessen); für das ganze Stück ergibt die Kette −20,2 LUFS (abgeleitet: −14,1 − 1,0 Kontext − 3,1 Regler
− 1,9 Gesamtlautstärke).

**Mit dem Motor v3 (AU-B, Welle 2)** steht `levels.MSfx` auf 0 dB; die Banken bringen ihren Pegel mit. Dieselbe
Aufnahme für alle fünf Autos (gemessen, Einzelheiten und die Arcade-Werte je Auto in
[motorsound.md](motorsound.md) 6.6):

| Abschnitt | Kompakt | Kombi | Limousine | Sportwagen | Gran Turismo | Plan |
|---|---|---|---|---|---|---|
| Vollgas durch die Gänge | −16,0 | −16,1 | −17,1 | −16,3 | −16,2 | −16 ± 1,5 |
| … Kurzzeit höchstens / Median | −14,8 / −16,0 | −15,1 / −16,0 | −16,2 / −17,2 | −15,1 / −16,6 | −15,5 / −16,2 | |
| Höchsttempo | −16,6 | −15,8 | −15,0 | −16,2 | −15,3 | −16 |
| Leerlauf | −23,9 | −25,1 | −24,2 | −24,2 | −23,5 | ≈ −24 |
| 130 km/h | −21,9 | −21,5 | −21,6 | −20,9 | −22,3 | ≈ −21 |
| True Peak | −6,1 | −6,0 | −6,5 | −5,9 | −6,1 dBTP | ≤ −1 |

Leerlauf und Reisetempo sind gegen den Wind des Platzhalter-Bausteins `road` abgestimmt; mit Fahrbahn und Wind
von AU-C1 ändert sich die Summe.

Pegelkette mit einem Messton (gemessen in `check_modern_audio.gd --live` in Welle 0, also mit `MSfx` auf −3 dB):
1 kHz mit −23,0 dB Effektivwert über `MUI` kommt mit −26,05 dB am Master an (Plan −26,01), über `MMusic` mit
−26,11 dB (Plan −26,11). Mit `MSfx` auf 0 dB liegt der Weg über `MUI` 3 dB höher (abgeleitet; die Prüfung
rechnet ihren Plan aus der Konfiguration und besteht weiter), der über `MMusic` ist unverändert.

### 6.2 Ducking der Musik unter dem Auto

Geskriptet, nicht mit dem Sidechain-Kompressor (D29). Der Fader von `MMusic` folgt

```
Absenkung = −depth_db · clamp((Auto − from_lufs) / (to_lufs − from_lufs), 0, 1)
```

mit Attack 50 ms nach unten und Release 450 ms zurück (`audio.modern.duck`: Tiefe 4,5 dB, von −23 bis −17 LUFS).
„Auto“ ist **die Lautheit, die der Plan dem Auto in seinem Fahrzustand gibt** (`ModernMix.car_lufs()`): Leerlauf im
Stand, zum Reisetempo hin mit dem Rollen (erreicht bei `pace_cruise` × Höchsttempo), zu Vollgas hin mit der
Motorlast aus `frame.engine.load`. Was die Mischzustände dem Auto nehmen, wird abgezogen: Hinter der Ziellinie ist
das Auto 9 dB leiser gestellt und senkt die Musik nicht mehr ab. Ohne fahrendes Auto (Menü, Pause, Sitzung weg) gibt
es keine Absenkung.

Warum nicht der Pegel des Auto-Busses: Die Engine misst an einem Bus nur Spitzen, und weder Spitze noch
Effektivwert folgen der Lautheit eines Motors. Gemessen am Auto-Bus mit dem Platzhalter-Motor bei Leerlauf /
130 km/h / Vollgas (−20,4 / −22,7 / −16,2 LUFS): Spitze −6,4 / −11,1 / −0,3 dBFS, Effektivwert −15,3 / −20,7 /
−14,4 dBFS – ein Spitzenmesser senkte die Musik im Leerlauf tiefer ab als bei Tempo 130. Der Plan als Schlüssel ist
zudem in jedem Lauf gleich.

Gemessen (Platzhalter-Stück, Musik allein über `--mute-bus=MEnv`): −19,7 LUFS im Leerlauf, −24,1 LUFS unter
Vollgas, −23,9 LUFS bei Höchsttempo, −21,7 LUFS bei 130 km/h. Auto und Musik zusammen: Vollgas −15,7 LUFS,
integriert −16,3 LUFS, True Peak −4,0 dBTP.

### 6.3 Renn-EQ der Musik

Im Kontext „race“ macht die Musik dem Motor Platz: zwei Kuhschwanzfilter in Reihe auf `MMusic`
(`audio.modern.music.race_eq`: unterhalb 1100 Hz −3,2 dB, unterhalb 180 Hz +2,2 dB) ergeben eine breite Mulde.
Gemessen (Impulsantwort der Kette): 62 Hz −1,0 dB, 125 Hz −1,4 dB, 250 Hz −2,7 dB, 500 Hz −3,0 dB, 1 kHz −1,9 dB,
2 kHz −0,3 dB, ab 4 kHz 0 dB; die Prüfung misst es mit Tönen nach (62 Hz −1,04 dB, 500 Hz −3,03 dB, 5 kHz
−0,01 dB). Der EQ blendet mit dem Kontext in 0,4 s ein und aus (`race_eq_fade_s`), außerhalb des Rennens sind die
Filter abgeschaltet.

Die Mulde nimmt Musik einen Teil ihrer Lautheit: 1,7 dB beim Platzhalter-Stück (im Spiel gemessen), 1,4 dB bei der
Titelmelodie (mit der gemessenen Impulsantwort berechnet). `context_db.race` = +1,0 dB gleicht das mit aus. Mit echten Stücken stimmt AU-D1/AU-E den Wert nach – oder je
Stück über `gain_db` im Manifest.

### 6.4 Mischzustände

Benannte Zustände mit einem Gewicht 0…1, das weich ein- und ausblendet (`audio.modern.snapshots`); Pegel addieren
sich gewichtet, beim Tiefpass gewinnt die tiefste Eckfrequenz:

| Zustand | wann | Wirkung bei Gewicht 1 | Attack / Release |
|---|---|---|---|
| `pause` | der Baum ist pausiert (Pausenmenü) | Musik −6 dB und Tiefpass 900 Hz; `MEnv`, `MAmb` Tiefpass 1200 Hz | 0,15 s / 0,25 s |
| `impact` | Ereignis `collision` (oder `play("crash")`), 0,25 s gehalten | Musik −5 dB, Ambiente −3 dB | 0,02 s / 0,6 s |
| `siren` | während einer Verfolgung | Musik −3 dB | 0,3 s / 0,8 s |
| `result` | von `stage_finish` bis zum Verlassen der Etappe | Auto −9 dB, Verkehr −9 dB, Ambiente −6 dB | 0,8 s / 0,4 s |

Gemessen: Im Zustand `pause` fällt ein 5-kHz-Ton auf dem Musikbus von −23,0 auf −59,8 dB und kommt danach auf
−23,0 dB zurück. Die Werte der Zustände sind Startwerte (abgeleitet) – AU-E stimmt sie am fertigen Klang ab.

### 6.5 Summenkompressor und Begrenzer

Auf `MMaster` sitzt ein langsamer Kompressor (`audio.modern.glue`: Schwelle −9 dB, wirksames Verhältnis 2:1,
Attack 30 ms, Release 300 ms). `ratio` in der Konfiguration ist das **wirksame** Verhältnis;
`ModernBuses.compressor_ratio()` rechnet es in den Wert um, den Godots Kompressor dafür braucht (Abschnitt 11).

Dahinter (AU-R) der **Begrenzer des Modern-Klangs** (`audio.modern.limiter`: `AudioEffectHardLimiter`, Obergrenze
−2,0 dB, Release 0,12 s): Er sitzt vor der Lautstärke von `Master`, hält also bei jeder Gesamtlautstärke; der
geteilte Arcade-Begrenzer auf `Master` (−0,8 dB) bleibt, wie er ist, und bekommt vom Modern-Klang nie mehr als
−2 dBFS. Grund: Ein schwerer Aufprall und das Höchsttempo erreichten bei Gesamtlautstärke 1,0 −0,7 bzw. −0,9 dBTP
(KRITIK-FAHRBAHN B7), der Plan will ≤ −1 dBTP. Gemessen mit dem Begrenzer: Abschnitt 15.9.

### 6.6 Effekte aus

`MSfx` ist stumm, wenn der Regler „Effekte“ auf 0 steht – und immer dann, wenn der Arcade-Bus `SFX` stumm ist. So
schaltet der Attract-Modus die Effekte stumm (er kennt nur die Arcade-Busse), ebenso `--mute-bus=SFX`. Solange die
Effekte stumm sind, wird die Musik nicht abgesenkt; nach dem Ende wartet `MSfx`, bis der Hall auf `MEnv` unter
−70 dB gefallen ist (höchstens 1,5 s), damit kein Hallrest der stummen Zeit hörbar wird. `--mute-bus=<Modern-Bus>`
hält einzelne Modern-Busse stumm (zum Messen einzelner Gruppen).

## 7. Einmalklänge, Ereignisse, Musik

**Einmalklänge.** `play(name)` geht an die Bausteine in ihrer Reihenfolge; der erste, dessen `play()` `true`
liefert, hat ihn (`SfxBank` zuletzt). Derselbe Klang zweimal innerhalb von 45 ms wird wie in Arcade ignoriert.

**Ereignisse** (Vertrag §4.7.2). Die Rennsitzung meldet seit Welle 0 (KERN) zusätzlich zu ihren `play()`-Aufrufen
Ereignisse: `stage_start`, `countdown`, `go`, `collision`, `rail_hit`, `radar_flash`, `chase_start`, `escaped`,
`busted`, `refuel_start`, `refuel_done`, `out_of_fuel`, `tow`, `stage_finish`. Damit nichts doppelt klingt:
Nennt ein Baustein ein Ereignis in `claims()`, vertont er es selbst – der `play()`-Aufruf desselben Moments
(`crash` ↔ `collision`, `rail` ↔ `rail_hit`, `flash` ↔ `radar_flash`, `go` ↔ `go`, `beep` ↔ `countdown`,
`finish` ↔ `stage_finish`, `fuel_start` ↔ `refuel_start`, `fuel_done` ↔ `refuel_done`) fällt weg, wenn das
Ereignis innerhalb von 50 ms davor oder danach kommt. Kommt keins, wird der Klang 50 ms später doch gespielt.
Beansprucht niemand das Ereignis, klingt der `play()`-Aufruf sofort. In Welle 0 beansprucht kein Baustein etwas;
seit AU-D2 beansprucht der Baustein `music` das Ereignis `stage_finish` (der Zielklang ist der Schluss des
Rennstücks, Abschnitt 14.11) – der Jingle `finish` entfällt dann.

**Musik.** `set_music_context(ctx)` kennt `title`, `menu`, `race_menu` (Bildschirme zwischen den Etappen), `race`,
`result`, `off`. Das Spiel ruft weiterhin `set_music(true/false)` und ab Welle 2 daneben `set_music_context`; der
letzte Aufruf gewinnt: `set_music(false)` = `off`; `set_music(true)` = `menu`, sofern nicht schon ein Menü-Kontext
gilt. Der `MusicDirector` spielt in den Menü-Kontexten das Titel-Remaster (ohne Modern-Datei die heutige
Titelmelodie), zwischen den Etappen (`race_menu`, `result`) das Zwischenspiel und im Rennen ein Rennstück (reihum),
das mit der Etappe beginnt und mit ihr endet; Überblenden zwischen
Stücken 0,6 s aus, 0,4 s ein, gleiche Leistung. Ein Stück gilt erst als begonnen, wenn sein Stream da ist
(`resolve()` antwortet bis dahin mit Stille): Die Titelmelodie wird ohne `audio.music_file` in einem Thread
synthetisiert und trifft mit dem Profil Modern beim Start erst nach dem Menü-Kontext ein. Der Schalter
`set_race_music(false)` („Musik im Rennen: Aus“) lässt den Kontext `race` still. `stop_all()` hält die Musik nicht
an. Der Pegel je Kontext steht in `audio.modern.music.context_db` (bezogen auf eine Datei mit −14 LUFS), dazu
`gain_db` des Stücks im Manifest. Einzelheiten: Abschnitt 14.

## 8. AudioFeed (v1 seit AU-C1)

`AudioFeed` leitet aus der `Track` der Etappe (`set_track`) und dem Fahrzeugzustand des Bildes
(`set_vehicle_state`) ab, was der Klang über die Straße wissen muss – nie aus dem Renderer (D28). Er ist rein und
liest nur: die Bauwerke und Abschnitte der Etappe (feste Daten des Plans) und die Segmente am und hinter dem Auto,
nie davor.

| Feld | Inhalt |
|---|---|
| `surface_l`, `surface_r` | worauf die linken / rechten Räder laufen: der Belag (`asphalt`, `concrete`, `cobbles`, `deck`), `rumble` (profilierte Randlinie und Rüttelstreifen – nur auf `rumble_roads`; rechts nicht, solange das Segment eine Tankspur hat: deren Randlinie – durchgezogen wie in Arcade – hat kein Profil, AU-R), `shoulder` (Schotter), `grass`; in Tunnel, auf Brücken und in den City Limits ist der Rand befestigt (Gehweg, Deck) |
| `paving` | der Belag am Auto: `concrete` je Abschnitt der `concrete_roads` nach dem Anteil seines Landes (`concrete_share`, aus Etappe, Name, Länge, Land und Landschaft des Abschnitts gehasht – in beiden Richtungen gleich; seit AU-R gegen eine Schwelle je Land, `concrete_threshold`, die `tools/audio/modern/calibrate_concrete.gd` so setzt, dass das Land seinen Anteil über alle seine Abschnitte trifft – sie gilt nur für den Anteil, mit dem sie gerechnet wurde), `cobbles` in Blöcken der Altstadt (`cobble_styles`, `cobble_share`, `cobble_block_m`, vom Ziel aus gezählt) – **nie auf einer Brücke ohne Steindeck**: ein Betondeck in der Stadt ist Asphalt, ein Stahldeck `deck` (AU-R3, der Damm nach Venedig) – und auf Steinbrücken, `deck` auf Stahlbrücken, sonst `asphalt`. Der Hash (`unit_hash`) mischt seit AU-R mit dem Finalisierer von MurmurHash3 (fmix32): djb2 allein änderte bei „Stadt\|Block“ nur die letzten Bits, jede Stadt war ganz oder gar nicht gepflastert. Die Altstadt bekommt ihren Anteil seit AU-R genau, seit AU-R3 auf ihren Straßen, seit AU-R4 **wie gehört** (`AudioFeed.cobbled_blocks`: in der Reihenfolge ihrer Hashes wird ein Block gepflastert, solange das die gepflasterte Länge näher an `cobble_share` × Länge der Straßen bringt – auf einen halben Block genau; der Hash wählt nur, welche Blöcke. Die Brücken ohne Steindeck sind keine Straße: `bridge_stretches` nimmt sie aus dem Plan, vom Ziel aus gezählt, bei jeder Ankunft in der Stadt gleich; ein Block zählt nur mit seinen Straßenmetern. Steinbrücken sind Straße, die immer gepflastert klingt: `stone_stretches` zählt sie in der Basis und als schon gepflastert, die Blöcke teilen den Rest (AU-R4). Tunnel der Etappe in der Altstadt (`tunnel_stretches`, Asphalt) sind keine Straße und Daten der Etappe, nicht der Stadt: Die Blöcke der Stadt bleiben, solange der Anteil dieser Ankunft im Band liegt (AU-R4). Liegt eine Altstadt außerhalb `cobble_share` ± `COBBLE_BAND` (0,6 ± 0,05), bringen einzelne Schritte – Block weg, tauschen, dazu – sie näher, seit AU-R4 bei jeder Altstadt. Ohne Brücke und Tunnel in der Altstadt ist die Zuteilung bitgleich wie seit AU-R) (Abschnitte 15.9, 15.11, 15.12) |
| `fuel_lane` | Anteil der Tankspur rechts am Segment des Autos (0 = keine) |
| `deck` | Material der Brücke: `steel` (Schrägseil-, Bogenbrücke), `stone` (Steinbogen), `concrete` (die übrigen); `""` ohne Brücke |
| `rumble_road` | die Straße hat profilierte Randlinien |
| `wet`, `snow` | 0…1 aus dem Wetter (im Tunnel trocken) |
| `zone` | `tunnel`, `bridge`, `city`, `cutting` (Fels oder Klippe höchstens `cutting_dist_m` neben dem Fahrbahnrand auf beiden Seiten innerhalb der letzten `cutting_window_m`), `forest`, `valley` oder `open` |
| `tunnel`, `bridge`, `cover`, `depth_m` | im Tunnel / auf einer Brücke dieses Typs / unter einem Dach (`border`, `fuel`); Abstand zum näheren Ende |
| `road`, `scenery`, `city`, `guardrail`, `lanes` | Straßentyp, Landschaft, Stadt, Leitplanke, Spuren am Auto |
| `events` | seit dem letzten Bild überfahren: `tunnel_in/out`, `bridge_in/out`, `cover_in/out`, `joint {z, kind, deck}` (Dehnfuge; Abstand je Deck aus `joint_every_m`: Stahl an den Enden und etwa alle 100 m zwischen den Feldern, Beton alle 32 m, Steinbogen keine – AU-R), `pass_object {z, side, dist_m, size, kind, set, contact}` (Baum, Gebäude, Pfosten, Schild, Schilderbrücke, Fels – und die Leitpfosten der Straßen ohne Leitplanke, alle `road.delineator_every_m` wie die Straße sie zeichnet; `contact` = die Karosserie streift den Pfosten) |

Die Ereignisse des Feeds erreichen die Bausteine über `event()`. Breiten für Randlinie und Rüttelstreifen und alle
übrigen Regeln stehen in `audio.modern.feed` (eigene Schlüssel – der Klang liest keine `render.*`-Werte; den Abstand
der Leitpfosten liest er wie die Straße aus `road.delineator_every_m`). Sprünge (Etappenstart, mehr als `max_scan_m`
in einem Schritt) setzen die Position ohne Ereignisse. Sendet die Sitzung keinen Zustand, bleibt der Feed ungültig
(`feed.valid` falsch) und die Bausteine arbeiten mit den Werten der alten Aufrufe (trockener Asphalt im Freien).
Mit `concrete_share` DE 0,35 sind auf Kiel – Hamburg „A215 Kiel – Bordesholm“ und „A7 Holstein“ Beton (gemessen).

## 9. Dateien und Manifest

`assets/audio/modern/{engines,vehicle,traffic,sfx,ambience,ui,music}/`, je Ordner ein `manifest.json`:

```json
{"format": "ce-audio-manifest-1", "folder": "ui",
 "sounds": {"platzhalter_blip": {
    "file": "platzhalter_blip.wav",
    "kind": "oneshot", "bus": "MUI", "gain_db": 0.0,
    "lufs": -17.26, "true_peak_db": -9.02, "sample_rate": 44100, "channels": 1, "frames": 5292,
    "loop": null, "bytes": 10628, "sha256": "…", "placeholder": true,
    "generator": "tools/audio/modern/make_placeholders.py"}}}
```

- `file` oder `files` (Varianten eines Einmalklangs, reihum gespielt); `kind`: `oneshot`, `loop`, `music`, `bank`.
- `loop`: `[Anfang, Ende)` in Frames, wie in den Import-Einstellungen; Musik zusätzlich `bpm`, `beats`, `bar_beats`.
- `lufs`, `true_peak_db`, `frames`, `bytes`, `sha256` sind gemessene Werte der Datei – das Prüfwerkzeug misst nach.
- `role`: wofür die Laufzeit den Klang nimmt (Musik: `title`, `interlude`, `result`, `race`).
- `generator`: das Werkzeug, das den Klang schreibt. Mehrere Werkzeuge können sich einen Ordner teilen – jedes
  ersetzt im Manifest nur seine eigenen Einträge (`modern_lib.Manifest`), und `audio_qc.py --determinism` lässt
  jedes genannte Werkzeug zweimal laufen.
- Weitere Schlüssel späterer Pakete bleiben erhalten (`Entry.meta`); eigene Grenzen für die Prüfung unter `"qc"`.

Formate (D-Formate des Vertrags §4.7.3): Musik Ogg Vorbis q5, Ambiente Ogg Vorbis q3–q4, tonale Schleifen und
Einmalklänge 16-Bit-WAV, alles 44,1 kHz; Motorbänke `<auto>.json` + `<auto>.i16` (rohes verschachteltes int16,
32 kHz Stereo). Seit AU-R sind die Rausch-Schleifen des Autos in `vehicle/` (Rollen, Nässe, Schnee, Wind – je
Seite eine eigene Schleife von 4–7,6 s) Ogg Vorbis q5 (q8, wo die Naht es braucht): als WAV hätten 13 Paare
langer Schleifen das Budget überschritten. `audio_qc.py` lässt Ogg für Schleifen in `vehicle/` zu. `*.i16` kommt mit KERN in den Export-Filter und in `.gitattributes`; bis zu dessen Merge erkennt
Git die Datei von selbst als binär.

**Platzhalter** (`"placeholder": true`): Stellvertreter, bis der echte Klang da ist. Im Spiel klingt nie einer –
eine Rolle ohne echten Klang nimmt den Arcade-Klang oder bleibt still. Sichtbar werden Platzhalter nur mit
`audio.modern.placeholders = true` (Tests und Prüfungen der Pipeline). Erzeugt von
`tools/audio/modern/make_placeholders.py` (deterministisch; 15 Dateien, zusammen 0,49 MB – gemessen).

`ModernAudioAssets` lädt die Manifeste beim Start des Profils (fehlt eins, gibt es dort einfach noch keine Klänge;
ein kaputtes ist ein Fehler im Log) und die Streams beim ersten Gebrauch.

## 10. Werkzeuge

| Werkzeug | Zweck |
|---|---|
| `tools/audio/qc/audio_qc.py` | Prüfung aller Modern-Klangdateien gegen Manifest, Format-, Pegel- und Schleifenregeln, Import-Einstellungen und Größenbudget; `--determinism` lässt jeden Generator zweimal laufen |
| `tools/audio/qc/qc_lib.py` | Messfunktionen: Lautheit nach BS.1770 (integriert, Kurzzeit, Bereich), True Peak (vierfach überabgetastet), Gleichanteil, Übersteuerung, Schleifennaht |
| `tools/audio/modern/modern_lib.py` | für Generatoren: WAV / Ogg / `.i16` und ihre `.import`-Dateien schreiben, auf Lautheit normieren, True Peak begrenzen, Manifest führen |
| `tools/audio/modern/make_placeholders.py` | schreibt die Platzhalter und ihre Manifeste |
| `tools/audio/modern/capture_mix.gd` + `measure_mix.py` | nimmt den Master-Bus bei einer festen Fahrt, im Menü oder im Rennen mit Musik auf und misst die Lautheit je Abschnitt gegen den Plan |
| `tools/audio/modern/make_arcade_golden.sh` | schreibt die Fingerabdrücke des Arcade-Klangs aus dem Tag v0.7.0 neu (nur nach einem Engine-Update) |
| `tools/audio/modern/vehicle_loops.py` | die Schleifen von Reifen, Fahrbahn, Wind und Leitplanke (AU-C1; seit AU-R je Seite eine eigene, an die Klangfarbe von AU-C1 angeglichen: 31 Einträge, `assets/audio/modern/vehicle`, Abschnitt 15.2; `--out`, `--wav`) |
| `tools/audio/modern/sfx_modern.py` | die 17 Einmalklänge von Fugen, Vorbeifahrten, Kollisionen, Leitplanke, Leitpfosten (AU-C1; seit AU-R Glas, Kleinteile, Lkw-Schlag je vier Varianten; `assets/audio/modern/sfx`, Abschnitt 15.2) |
| `tools/audio/modern/calibrate_concrete.gd` | AU-R: die Schwelle je Land für die Betonabschnitte (`audio.modern.feed.concrete_threshold`) über alle Etappen; gibt sie als JSON-Zeile aus – neu laufen lassen, wenn Etappen dazukommen oder sich ein Anteil ändert (`godot --headless --path . -s res://tools/audio/modern/calibrate_concrete.gd -- --graphics=arcade`) |
| `tools/audio/music/music_lib.py` | Musik-Kette (AU-D1): moderne Produktionsschicht über `music_synth.py`, Mixer, Master, Vorbis mit Messung nach der Kodierung (Abschnitt 14.2) |
| `tools/audio/music/title_remaster.py`, `linke_spur.py`, `nachtfahrt.py`, `rueckenwind.py`, `zwischenspiel.py` | die Generatoren des Titel-Remasters, der drei Rennstücke (mit Schlüssen und Stingern, über `race_lib.py`) und des Zwischenspiels (`--out`, `--wav`, Skizzen) |
| `tools/audio/music/ui_klaenge.py` | die UI-Klänge des Profils Modern (`assets/audio/modern/ui/`) |
| `tools/audio/music/mischung.json`, `render_all.py` | die gemeinsamen Mischentscheidungen aller Stücke und der Lauf, der danach alles neu rendert (Abschnitt 14.10) |
| `tools/audio/music/check_music.py` | Noten: Tonklassen und Akkord-Grundton je Takt, Tonart – Remaster gegen das Original, jedes Rennstück gegen seine Partitur, die Zusatzclips |

`audio_qc.py` prüft je Datei: Format passend zum Ordner (Schleifen in `vehicle/` auch Ogg Vorbis, AU-R); Manifest gleich Datei (sha256, Bytes, Frames, Kanäle,
Rate, Lautheit und True Peak nachgemessen); True Peak ≤ −1 dBTP; Musik −14 ± 1 LUFS; keine drei Abtastwerte in
Folge am Anschlag; Gleichanteil unter −40 dBFS; Schleifenpunkte in der Datei und die Naht kein Knacken (ihr Sprung
und Knick höchstens das 2-fache – nach Vorbis das 4-fache – der größten im Umkreis von 100 ms, oder nicht größer
als irgendwo sonst in der Schleife, wenn ein Schlag auf dem Schleifenpunkt sitzt); `.import` gleich Manifest. Je
Ordner: Eine Datei, die kein Manifest nennt, ist ein **Fehler** (Rückgabewert 1) – der Export nimmt jede Datei des
Ordners mit, sie würde ohne Pegel-, Spitzen- und Nahtprüfung ausgeliefert; `--allow-unknown` macht daraus für
einen Arbeitsstand einen Hinweis. Insgesamt: Größe gegen die Budgets des Vertrags §4.11 (Klänge 23 MB,
Musik 25 MB). Ausgabe `QC <ordner>/<id> OK|FEHLER …`, Rückgabewert 0, wenn alles besteht.

Grenze des Werkzeugs: Die Nahtprüfung vergleicht die Naht mit ihrer Umgebung. Ein Knacken **mitten in der Datei**
findet sie nicht, und ein Knacken kurz vor der Naht verdeckt eine schlechte Naht (im Versuch nachgestellt). Einen
allgemeinen Knack-Detektor gibt es nicht – Anschläge von Schlagzeug wären davon nicht zu unterscheiden.

```
python3 tools/audio/qc/audio_qc.py --determinism
godot --headless --path . -s res://tools/audio/modern/capture_mix.gd -- --sound=modern --scenario=drive \
    --vehicle=gran_turismo --out=/tmp/mix.wav
python3 tools/audio/modern/measure_mix.py /tmp/mix.wav
```

Szenarien von `capture_mix.gd`: `drive` (feste Fahrt), `menu` (`--seconds=`), `race_music` (Kontext „race“ über der
Fahrt; mit `--placeholders` das Platzhalter-Stück); `--mute-bus=MEnv` lässt nur die Musik übrig.

## 11. Fallen (gemessen, Godot 4.7.2)

1. **Buslautstärke ändert sich ohne Rampe** – ein Sprung am Blockrand (Abschnitt 5). Bewegte Pegel gehören auf
   einen `AudioEffectAmplify` oder auf die Lautstärke eines Players.
2. **`AudioEffectCompressor` arbeitet nicht mit seinem Nennverhältnis**: Er multipliziert die Überschreitung mit
   2,08, bevor er (Verhältnis − 1) / Verhältnis anwendet. Schwelle −12 dB, Verhältnis 2, ein Sinus mit −6 / −3 /
   0 dBFS verlässt ihn mit −11,1 / −11,0 / −11,0 dBFS – ein Begrenzer, kein 2:1. Für ein wirksames Verhältnis `R`
   braucht er `1 / (1 − (1 − 1/R) / 2,081)`.
3. **Ein Send auf einen Bus mit höherem Index** geht stillschweigend an `Master`.
4. **`AudioEffectEQ6/10/21` sind nicht neutral**: Sie summieren Bandpässe. Mit allen Bändern auf 0 dB hebt der EQ10
   das Signal um 1,4 bis 3,3 dB an (Welligkeit von Band zu Band), der EQ21 um etwa 3,9 dB, der EQ6 um 0,5 bis
   2,6 dB. Für eine Klangregelung, die außerhalb ihrer Mulde nichts tut, taugen nur die Kuhschwanzfilter.
5. **Kuhschwanzfilter**: Der Gewinn der Stufe ist das **Quadrat** der Eigenschaft `gain` (0,841 → −3,01 dB,
   1,122 → +2,00 dB); an der Eckfrequenz ist die Hälfte erreicht. Das gilt für die Flankeneinstellung „6 dB“ und
   Resonanz 0,5; mit „12 dB“ ergab `gain` 0,841 nur −2,0 dB.
6. **`AudioEffectLowPassFilter`** ist in der Voreinstellung „6 dB“ ein Biquad (12 dB je Oktave).
7. **`AudioEffectCapture` / `AudioEffectRecord` auf einem Bus sehen das Signal vor dessen Lautstärke.**
8. **Hängender Audio-Thread nach dem Freigeben eines `AudioStreamGenerator`**: Die Wiedergabe eines
   Generator-Streams hält nur einen einfachen Zeiger auf ihren Stream. Wird der Player im selben Bild gestoppt und
   freigegeben, mischt der Audio-Thread noch einen Ausblend-Block und liest die Abtastrate aus freigegebenem
   Speicher. Bei 20 Profilwechseln mit laufendem Motor und Vorschau blieb der Audio-Thread in 4 von 29 Läufen
   hängen (im Debugger: Abtastrate −2,1e37, Endlosschleife im Resampler, Hauptthread wartet auf die Audio-Sperre).
   `ModernAudioContext.keep_alive(stream)` hält solche Streams zwei Sekunden über ihren Player hinaus: 0 von
   66 Läufen. Freigegeben werden sie von einem Zeitgeber des Szenenbaums (`_schedule_release()`), nicht vom
   nächsten Bild von `ModernAudio`: Nach dem Wechsel zurück zu Arcade läuft kein `ModernAudio` mehr, und die
   Streams blieben vorher bis zum nächsten Modern-Start liegen (gemessen nach 20 Wechseln: 40 Streams; jetzt
   1,8 s nach dem letzten Wechsel keiner mehr – die Prüfung `switch_20` verlangt `kept_count() == 0`).
   Dasselbe Muster steht in der eingefrorenen Arcade-Klasse `EngineAudio.detach()`; dort ließ es sich in
   1500 nachgestellten Etappenwechseln nicht auslösen (Abschnitt 13).
9. **Unit-Tests laufen in `_initialize()`**: Der Baum existiert noch nicht, die Autoloads haben kein `_ready()`
   hinter sich, es gibt nur den Bus `Master`. Was den laufenden `AudioManager` braucht, prüft
   `check_modern_audio.gd` in einem eigenen Prozess.
10. **Zeitraffer**: Überspannt ein Bild mehr als 0,35 s Spielzeit (Bildzeit × `Engine.time_scale`, etwa
    Zeitraffer 20 bei 20 ms je Bild), gilt die Sitzung zwischen zwei Bildern als weg – in beiden Profilen, das ist
    die Regel der sicheren Abschaltung. Prüfungen mit Klang fahren deshalb ohne Bildschirm mit Zeitraffer 8.
11. **Typisierte Arrays**: `Array[AudioEffectFilter].has(x)` mit einem `x` anderer Klasse schreibt einen Fehler
    ins Log, statt `false` zu liefern.
12. **Xvfb mit Software-Rendering**: Der Dummy-Treiber mischt in Schüben von etwa 93 ms; bei rund 15 Bildern je
    Sekunde läuft der Motor-Generator dabei gelegentlich leer – in beiden Profilen (je fünf Läufe der letzten
    3,5 km der Testetappe: Arcade 18 / 18 / 60 / 0 / 0, Modern 0 / 0 / 18 / 18 / 21 Aussetzer). Das ist die
    Messumgebung, kein Befund am Klang; der Thread-Mischer von AU-B (D27) nimmt das Thema ohnehin auf.
    `check_modern_audio.gd` richtet sich deshalb nach dem Display und nicht nach `--live`: Was es an Wiedergabe
    erwartet, hängt daran, ob ein Display da ist; das Rennszenario misst auf einem Display seine Bildzeit
    (Bilder 5 bis 10 bei Zeitraffer 1) und fährt dann mit Zeitraffer `clamp(floor(0,15 s / Bildzeit), 1, 8)` –
    frei laufend unter Xvfb 1 bis 2, mit `--fixed-fps 60` 8, ohne Bildschirm wie bisher 8. Mit festem Zeitraffer 8
    übersprang jedes Bild dort mehr als 0,35 s Spielzeit (Falle 10), und das Szenario scheiterte in jedem frei
    laufenden Lauf. Gemessen nach der Korrektur: 7 von 7 Läufen unter Xvfb bestehen (frei laufend mit `--live` 3,
    ohne 2, mit `--fixed-fps 60` je 1).
13. **Naht einer `AudioStreamWAV`-Schleife, die mit ihren Daten endet** (AU-B): Liegt `loop_end` am Ende der
    Daten, spielt Godot an jeder Naht einen Abtastwert, der nicht aus der Schleife stammt. Gemessen mit einer
    Schleife aus dem konstanten Wert 0,5: an jeder Naht ein Frame nahe 0, bei Tonhöhe 1 und 0,77; mit 16 Frames
    Fortsetzung hinter `loop_end` (die ersten Frames der Schleife noch einmal) keiner, und ein Sinus läuft dann
    bei Tonhöhe 0,77 / 1 / 1,63 ohne Knick durch. Der falsche Wert ist von Lauf zu Lauf nicht gleich: Zwei
    Movie-Maker-Läufe mit `--audio-sync` unterschieden sich deshalb an 49 Abtastwerten – mit der Fortsetzung sind
    sie gleich. Hörbar ist das bei Schleifen, deren Signal an der Naht nicht nahe 0 ist (tonale Schleifen).
    `engine_synth3.py` schreibt die Fortsetzung (`LOOP_GUARD`); für die übrigen Schleifen siehe Abschnitt 13.
14. **Meldungen am Prozessende** (AU-B): Endet ein Prozess, während irgendein `AudioStreamPlayer` spielt, schreibt
    Godot „ObjectDB instances were leaked at exit“ und „resources still in use at exit“ – auch mit einem einzigen
    Player ohne jeden Modern-Code (nachgestellt; mit `stop()` vor `quit()` bleibt es still). Prüfungen, die bei
    laufendem Klang enden, übergehen genau diese beiden Hinweise (`test_engine3_checks.gd`).
15. **Ein langes Bild sieht aus wie ein Sitzungsende** (zu Falle 10): Nach einem Hänger von mehr als 0,35 s ist
    `frame.alive` ein Bild lang falsch. Ein Baustein, der durch Hänger hindurch spielen soll, braucht dafür eine
    eigene Regel – der Motor und die Fahrzeugebenen nehmen `EngineAudio3.driven()` (ein Bild ≥ 0,25 s nach einem
    gefahrenen Bild, keine Pause, zählt noch).
16. **Der Dummy-Treiber holt Blöcke von etwa 93 ms**: Ein Generator, der mit 50 ms Vorlauf startet, läuft beim
    ersten Block leer, und ein Vorlauf, der sich erst an den Blöcken hochtastet, noch einige Male (gemessen 30–34
    Aussetzer am Start, alle in der ersten Sekunde). `EngineMixThread` rendert den ersten Vorlauf vor `play()`,
    merkt sich die Blockgröße für den Prozess und hält einen Block plus Reserve: 0 Aussetzer.

## 12. Prüfungen

`tests/unit/audio_modern/` (laufen mit `tools/run_tests.sh`, allein mit `tools/run_tests.sh audio_modern`,
83 Tests, gemessen 87 s – vor AU-B 57 Tests und 46 s):

| Datei | prüft |
|---|---|
| `test_arcade_identity.gd` | **Arcade ist Arcade geblieben**: Ausgabe des Motor-Mischers je Auto mit festem Seed (SHA-256 über 355 733 Abtastwerte je Auto), alle `SfxSynth`-Klänge, das Verkehrs- und Raummodell, die 40 eingefrorenen Audiodateien – gegen Fingerabdrücke, die aus dem Tag v0.7.0 erzeugt sind (`golden/arcade_v070_*.json`) |
| `test_modern_buses.gd` | Namen, Sends, Indexfolge, Effekte, Fader, Tiefpass, Renn-EQ, Kompressor-Umrechnung; Arcade-Busse bleiben unberührt |
| `test_modern_mix.gd` | Pegel aus Plan und Reglern, Ducking (Kurve, Attack, Release, Schlüssel aus dem Fahrzustand), Mischzustände, Effekte aus, die Zahlen des Plans in der Konfiguration |
| `test_modern_assets.gd` | Manifest-Lader, Platzhalter nur auf Wunsch, kaputte Manifeste (`fixtures/broken/`) |
| `test_audio_feed.gd` | Oberflächen je Seite, Zonen, Bauwerke, Fugen, Vorbeifahrten, Sprünge, „nur lesen“; seit AU-C1: Belag (Beton je Abschnitt, in beiden Richtungen gleich; Pflaster; Deck je Brückentyp; Tunnel), Rüttellinie nur auf Rüttelstraßen, Leitpfosten mit Berührung, Einschnitt; seit AU-R: gemischter Hash (Bezugswerte aus Python), Pflasteranteil je Altstadt, Fugenabstand je Deck, keine Rüttellinie neben der Tankspur; seit AU-R3 (echter Plan mit Stadt und Brücke, echte `Track`): kein Altstadtpflaster auf einem Betondeck (Damm wie nach Venedig; Fugen wie bisher, Stahl- und Steinbrücke unverändert), der Pflasteranteil der Straßen um eine Brücke mitten in der Altstadt (0,6 ± 0,05 – auf dem Stand vor AU-R3 0,42), die Zuteilung nur über Straßenmeter (150 Fälle im Band; eine Brücke außerhalb der Altstadt ändert nichts) – die beiden Damm-Tests sind auf dem Stand vor AU-R3 rot; seit AU-R4: Steinbrücke als schon gepflasterte Straße (30 Städte × 8 Fälle wie gehört im Band, kein Block ganz auf der Steinbrücke), Tunnel der Etappe (die Blöcke der Stadt bleiben, solange der Anteil im Band liegt, sonst rücken einzelne nach), echte Etappe mit Steinbrücke und Tunnel im 1-m-Raster (0,58 wie gehört; mit den Blöcken der Stadt wären es 0,42) |
| `test_road_audio.gd` | AU-C1, ohne Szenenbaum: Pegelplan bei Höchsttempo (Wind 3 dB, Reifen 4 dB unter dem gemessenen Motor je Auto), Tempogesetze, Beläge je Seite, Nässe, Schnee, Quietschen und Radieren, Betonplatten im exakten Takt, Brückenfugen mit dem Achsabstand des Autos, Vorbeifahrten, Wind in Zonen und Böen (gleich in jedem Lauf), Ausblenden; Kollisionen nach Schließgeschwindigkeit und Partner, Leitplanke, Schleifen, Leitpfosten; seit AU-R: je Seite eigene Schleife mit Drift (mittlere Leistung unverändert), Quietschen mit eigener Tonhöhe je Ereignis, Aufprall-Varianten zufällig ohne Wiederholung, ±2 dB, späterer Einsatz, Glas-Regel; seit AU-R4 so, dass ein Bruch der Regel auffällt (KRITIK-R2-CODE, Mutationen): Tonhöhe je Bild gleich, solange ein Quietschen klingt; Varianten zufällig statt reihum (Folgen je Variante, 400 Ziehungen); Pegel- und Einsatzzufall über 60 Unfälle; Nachstellen der Plattenmuster mit laufenden Platzhalter-Spielern (nur der leisere, erst über `align_ms`, danach im Takt); Vorbeifahrten ±2 dB und Variante; Glas genau ab 80 km/h; Fahrtwind im Tunnel 0 dB |
| `test_modern_buses.gd`, `test_modern_mix.gd` (AU-R) | der Begrenzer auf `MMaster` hinter dem Summenkompressor aus `audio.modern.limiter`; die Zeile „Höchsttempo“ des Plans |
| `test_modern_audio.gd` | `ModernAudio` ohne Szenenbaum: Lebenszyklus, Frame-Semantik, Einmalklänge und Ereignisse (50 ms), Mischung, Musik-Kontexte, Stummschaltung |
| `test_modern_checks.gd` | startet `check_modern_audio.gd` zweimal (ohne und mit Wiedergabe) und `check_arcade_lean.gd` als eigene Prozesse |
| `test_engine3_bank.gd`, `test_engine3_mix.gd`, `test_engine3_slot.gd`, `test_engine3_checks.gd` | Motor v3 (AU-B): Bank-Lader, Mischer (Knackser an den Zyklusgrenzen, Leistung beim Überblenden, Kanalabgleich, Monosumme), Baustein und Fahrzeugebenen, `check_engine3.gd` als eigene Prozesse (Thread-Bank mit sechs Hängern von 400 ms, Profilwechsel, Beenden) – [motorsound.md](motorsound.md) 6.7 |
| `test_music_director.gd`, `test_music_checks.gd` | Musik (AU-D1, AU-D2): Zustandsmaschine des `MusicDirector` ohne Szenenbaum (Rotation, Zwischenspiel, Schluss-Varianten, Ziel-Schlag, Stinger); `check_music.gd` als eigene Prozesse (Schleife und Schlüsse aller Rennstücke offline gemischt, Naht des Zwischenspiels, Rennen mit Countdown und Ducking, Arcade ohne Neues, Beenden mit Musik) – Abschnitt 14.12 |

`check_modern_audio.gd` prüft im laufenden Spiel: Start mit Arcade und Busliste wie in v0.7.0 · die neue API tut
mit Arcade nichts · 22 Modern-Busse hinter den vorhandenen · **20 × Profilwechsel** ohne zusätzlichen Knoten oder
Bus · Delegation in beide Richtungen · Pegelkette, Ducking, Pause-Tiefpass und Renn-EQ gemessen (`--live`) · ein
Stück der Testetappe mit Modern und Platzhaltern, ohne Wiedergabe zusätzlich die Zieleinfahrt und dieselbe Strecke
mit Arcade bei gleicher Simulation in jeder Sekunde (Regel 3) · danach wieder Arcade wie in v0.7.0 – die
Busliste und der Motor-Mischer mit der Bank, aus der beide Profile gespielt haben, Abtastwert für Abtastwert.

`check_arcade_lean.gd` prüft: Ein Spielstart mit dem Profil Arcade und eine Arcade-Etappe laden **kein** Skript aus
`scripts/audio/modern` oder `scripts/race3d` und nicht `scripts/core/model_db.gd`; erst `set_profile("modern")` lädt
den Modern-Klang. Mit der typisierten Variable von vor der Korrektur schlägt es fehl (19 Skripte geladen).

```
godot --headless --path . -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade [--live] [--only=mix,race]
godot --headless --path . -s res://tests/unit/audio_modern/check_arcade_lean.gd -- --graphics=arcade
```

Die Fingerabdrücke sind für eine Maschine und einen Engine-Stand exakt. Nach einem Godot-Update schreibt
`tools/audio/modern/make_arcade_golden.sh` sie aus dem Tag neu – nie, um einen fehlschlagenden Test grün zu machen.

## 13. Offene Punkte

- **Arcade-Motor und der Generator-Befund** (Falle 8): `EngineAudio.detach()` gibt den Player frei, während die
  Wiedergabe noch ausblenden kann. Die Datei ist eingefroren (Regel 1); der Befund liegt bei der Leitung.
  Vorschlag: den Stream nach `detach()` zwei Sekunden halten.
- **Attract-Modus**: Er schaltet die Arcade-Busse stumm; Modern folgt dem über den Zustand von `SFX`
  (Abschnitt 6.6). `tests/race/check_attract.gd` schaut auf den Arcade-Musikplayer und passt mit dem Profil Modern
  noch nicht (UI2 / AU-E).
- **Motor-Thread** (D27): erledigt mit AU-B – der Motor v3 mischt in einem eigenen Thread, synchron mit
  `--audio-sync` oder `audio.modern.engine_thread = false` ([motorsound.md](motorsound.md) 6.3).
- **Pegel**: Der Motor bringt seine Pegel mit, `levels.MSfx` steht auf 0 dB (Abschnitt 6.1). Die Mischzustände,
  `duck.*` und `context_db` sind Startwerte; AU-C1/C2 (Fahrbahn, Welt) und AU-E (Gesamtabstimmung,
  Movie-Maker-Szenarien) stimmen sie ab. Mit `MSfx` auf 0 dB spielt alles Übrige unter `MSfx` 3 dB lauter als in
  Welle 0 (Wind, Reifen, Kollisionen, Verkehr, Ambiente, Menü- und Countdown-Klänge) – diese Platzhalter waren
  gegen den alten Wert nie abgestimmt; ihr Verhältnis zum Motor ist Sache der genannten Pakete.
- **Schleifen ohne Fortsetzung** (Falle 13): Die Platzhalter-Schleifen (`make_placeholders.py`) und jede künftige
  WAV-Schleife von AU-C2 brauchen Frames hinter `loop_end`, sonst knackt die Naht leise und `--audio-sync` ist
  nicht reproduzierbar (die Schleifen von AU-B und AU-C1 tragen sie). Am saubersten in `modern_lib.py` (eine Stelle
  für alle Generatoren) und als Regel in `audio_qc.py` („hinter dem Schleifenende liegen Daten“). Für die
  Schleifen, die der eingefrorene Arcade-Code zur Laufzeit baut, ist das nicht untersucht.
- **`modern_lib.write_wav_import()` / `write_ogg_import()` verlieren den Kopf der `.import`-Datei**: Sie öffnen
  die Datei zum Schreiben, bevor `_import_head()` sie liest. Nach jedem erneuten Erzeugen fehlen uid und
  Importpfad, und das Spiel meldet „Failed loading resource“, bis `godot --import` gelaufen ist (dann mit neuer
  uid). `engine_synth3.py` umgeht das mit `write_wav_import_keep()`; die Korrektur gehört in `modern_lib.py`.
- **Breite des Motors**: Der Motor v3 ist trocken; bei Kompakt, Kombi und Limousine sitzt er in der Mitte
  (Kanalkorrelation im Spiel 0,97–1,00, der Arcade-Motor mit seinem Hall 0,80–0,99). Raum und Breite sind Sache
  von `env` (AU-C2) – siehe [motorsound.md](motorsound.md) 6.9.

## 14. Musik (Pakete AU-D1, AU-D2)

Vertrag D26, D29, D30, §4.7, A-5. Alle Zahlen gemessen auf der Entwicklungsmaschine (Godot 4.7.2, ohne Bildschirm,
Dummy-Audiotreiber), sofern nicht „abgeleitet“ dasteht. **Wie die Musik klingt, hat hier niemand gehört** – das
beurteilt der Nutzer (Hörproben unter `<scratch>/v080/deliver/AU-D1/` und `<scratch>/v080/deliver/AU-D2/`). Der
Stil der ersten Hörproben (Rennstück 1, Titel-Remaster) ist vom Nutzer bestätigt („der Stil passt super“); Bass und
Pegel beurteilt er noch – dafür liegen alle Mischentscheidungen, die er ändern könnte, an einer Stelle (14.10).

### 14.1 Die Stücke

`assets/audio/modern/music/` (Manifest `manifest.json`, Rollen für den `MusicDirector`):

| Datei | Rolle | bpm | Länge | Schleife | Lautheit / True Peak (nach Vorbis) | Größe |
|---|---|---|---|---|---|---|
| `titel_remaster.ogg` | `title` | 128 | 202,5 s | ab Frame 661500 (15,00 s), 100 Takte = 187,50 s | −14,1 LUFS / −1,7 dBTP | 3,93 MB |
| `zwischenspiel.ogg` | `interlude` | 100 | 81,6 s | ab Frame 211680 (4,80 s), 32 Takte = 76,80 s | −14,1 LUFS / −1,5 dBTP | 1,61 MB |
| `linke_spur.ogg` | `race` | 132 | 176,4 s | ab Frame 721636 (16,36 s), 88 Takte = 160,00 s | −14,2 LUFS / −1,8 dBTP | 3,36 MB |
| `linke_spur_schluss.ogg` | `race_ending` | 132 | 7,8 s | – | −15,7 LUFS / −2,4 dBTP | 0,15 MB |
| `linke_spur_schluss_rekord.ogg` | `race_ending` | 132 | 10,1 s | – | −15,3 LUFS / −2,5 dBTP | 0,17 MB |
| `linke_spur_schluss_finale.ogg` | `race_ending` | 132 | 11,9 s | – | −14,7 LUFS / −2,2 dBTP | 0,21 MB |
| `linke_spur_ziel.ogg` | `race_ziel` | 132 | 6,4 s | – | −17,8 LUFS / −3,0 dBTP | 0,09 MB |
| `linke_spur_polizei.ogg` | `race_stinger` | 132 | 10,1 s | – | −16,1 LUFS / −3,0 dBTP | 0,13 MB |
| `linke_spur_tank.ogg` | `race_stinger` | 132 | 8,2 s | – | −19,2 LUFS / −5,0 dBTP | 0,12 MB |
| `nachtfahrt.ogg` | `race` | 105 | 203,4 s | ab Frame 907199 (20,57 s), 80 Takte = 182,86 s | −14,2 LUFS / −1,5 dBTP | 3,93 MB |
| `nachtfahrt_schluss.ogg` | `race_ending` | 105 | 8,8 s | – | −15,3 LUFS / −2,2 dBTP | 0,17 MB |
| `nachtfahrt_schluss_rekord.ogg` | `race_ending` | 105 | 11,5 s | – | −14,8 LUFS / −1,7 dBTP | 0,20 MB |
| `nachtfahrt_schluss_finale.ogg` | `race_ending` | 105 | 13,7 s | – | −14,3 LUFS / −2,0 dBTP | 0,24 MB |
| `nachtfahrt_ziel.ogg` | `race_ziel` | 105 | 6,9 s | – | −16,5 LUFS / −2,3 dBTP | 0,09 MB |
| `nachtfahrt_polizei.ogg` | `race_stinger` | 105 | 11,5 s | – | −15,4 LUFS / −2,5 dBTP | 0,15 MB |
| `nachtfahrt_tank.ogg` | `race_stinger` | 105 | 9,2 s | – | −17,9 LUFS / −4,8 dBTP | 0,14 MB |
| `rueckenwind.ogg` | `race` | 150 | 155,2 s | ab Frame 635040 (14,40 s), 88 Takte = 140,80 s | −14,2 LUFS / −1,8 dBTP | 2,98 MB |
| `rueckenwind_schluss.ogg` | `race_ending` | 150 | 7,4 s | – | −16,0 LUFS / −2,1 dBTP | 0,14 MB |
| `rueckenwind_schluss_rekord.ogg` | `race_ending` | 150 | 9,4 s | – | −15,7 LUFS / −2,2 dBTP | 0,16 MB |
| `rueckenwind_schluss_finale.ogg` | `race_ending` | 150 | 11,0 s | – | −14,8 LUFS / −2,6 dBTP | 0,19 MB |
| `rueckenwind_ziel.ogg` | `race_ziel` | 150 | 6,2 s | – | −18,7 LUFS / −3,0 dBTP | 0,09 MB |
| `rueckenwind_polizei.ogg` | `race_stinger` | 150 | 9,4 s | – | −15,8 LUFS / −3,2 dBTP | 0,12 MB |
| `rueckenwind_tank.ogg` | `race_stinger` | 150 | 7,8 s | – | −19,3 LUFS / −6,4 dBTP | 0,11 MB |

Mit dem Platzhalter von AU-A zusammen 18,51 MB von 25 MB Budget (§4.11). Alle Dateien tragen `bpm` und
`bar_beats` (in den Import-Einstellungen ebenso, `beat_count` 0). Über das Format hinaus: die Rennstücke `piece`,
`ending` (normaler Schluss), `endings` (`rekord`, `finale`), `ziel` (Schlag an der Ziellinie), `stingers` (`busted`,
`out_of_fuel`), `countin_beats`, `intro_bars`, `loop_bars`, `rotation` (Reihenfolge, 1 = erstes Stück einer Sitzung)
und `key`; Schlüsse und Stinger `piece`, `variant` bzw. `event` und `bars` (musikalische Länge, für die Absenkung
darunter); das Zwischenspiel `intro_bars`, `loop_bars`, `key`. Eigene QC-Grenzen der Lautheit: der normale Schluss
`[-20, -10]`, die Zusatzclips `[-30, -10]` – sie werden mit dem Master und den Spurpegeln ihres Stücks bearbeitet und
nicht für sich auf −14 LUFS gebracht, sonst spränge der Pegel am Übergang.

### 14.2 Die Kette (`tools/audio/music/`)

| Datei | Inhalt |
|---|---|
| `music_lib.py` | die Produktionsschicht über dem eingefrorenen `tools/audio/music_synth.py` (importiert, nie geändert): Sub-Kick- und Snare-Ebenen, Shaker, Sub-Bass, zwei Supersaw-Leads für die Breite, neue Platte und Halle; `Mixer` (eine Spur nach der anderen in Busse und Sends; zeichnet seine Pegelentscheidungen als `fit` auf und mischt mit `ref` eine andere Zeitleiste genau damit); `Master` (EQ, drei Bänder bei 140 Hz und 3,2 kHz, Kleber, M/S, Lautheit, Soft-Clip, True-Peak-Begrenzer) mit `pre()`/`fit_gain()`/`post()`/`post_at()`; `encode_checked()` schreibt Vorbis q5 bitgenau, dekodiert und misst – liegt der True Peak nach der Kodierung über −1,08 dBTP, sinkt die Grenze des Begrenzers und die Datei wird neu geschrieben; `write_ogg_import_keep()`; `prefs()`/`apply_prefs()` (14.10); Chroma, Dreiklang, Tonart für die Prüfung |
| `mischung.json` | die gemeinsamen Mischentscheidungen aller Stücke (14.10) |
| `race_lib.py` | die gemeinsame Rennstück-Kette (AU-D2): Voicings für jede Tonart nach den Regeln von „Linke Spur“, Zeitleiste, Render-Schleife, `RacePiece` (Hauptdatei mit Einzähler, Schleife, Schluss, Import, Manifest) und `Extras` (Zusatzclips, 14.7) |
| `title_remaster.py` | das Titel-Remaster (14.3) |
| `linke_spur.py` | Rennstück 1 (14.4) und seine Zusatzclips |
| `nachtfahrt.py`, `rueckenwind.py` | Rennstücke 2 und 3 (14.5, 14.6) und ihre Zusatzclips |
| `zwischenspiel.py` | das Zwischenspiel (14.8) |
| `ui_klaenge.py` | die UI-Klänge (14.9, schreibt nach `assets/audio/modern/ui/`) |
| `render_all.py` | alle Generatoren nacheinander (nach einer Änderung von `mischung.json`) |
| `check_music.py` | die Noten-Prüfung (14.12) |

```
python3 tools/audio/music/render_all.py                  # alle Stücke und UI-Klänge ins Repository (etwa 25–27 min)
python3 tools/audio/music/title_remaster.py              # 264–295 s auf einem Kern (gemessen)
python3 tools/audio/music/linke_spur.py                  # 330–407 s mit den Zusatzclips (gemessen)
python3 tools/audio/music/nachtfahrt.py                  # 400–447 s (gemessen)
python3 tools/audio/music/rueckenwind.py                 # 305–337 s (gemessen)
python3 tools/audio/music/zwischenspiel.py               # 76–81 s (gemessen)
python3 tools/audio/music/ui_klaenge.py                  # wenige Sekunden
python3 tools/audio/music/nachtfahrt.py --info           # Form, Clip-Längen (jedes Rennstück)
python3 tools/audio/music/nachtfahrt.py --sketch 16 --wav /tmp/x   # Einzähler + 16 Takte
python3 tools/audio/music/check_music.py [--only nachtfahrt] [--music <Ordner eines --out-Laufs>]
python3 tools/audio/qc/audio_qc.py --folders music,ui --determinism
```

Jeder Generator nimmt `--out <Ordner>` (dann ohne Import-Dateien; so ruft `audio_qc.py --determinism` ihn zweimal
auf) und `--wav <Ordner>` (zusätzlich der ganze Master als Float-WAV für Hörproben; `ui_klaenge.py` legt dort eine
Hörprobe aller Klänge ab). Feste Seeds, kein Zeitstempel, Vorbis über ffmpeg mit den Bitexakt-Schaltern: zwei Läufe
schreiben dieselben Bytes. Danach `godot --headless --import`.

### 14.3 Titel-Remaster

Dieselbe Komposition wie die Titelmelodie von v0.5.0: `music_synth.Render` liefert jedes Ereignis des Originals
(Zeitleiste, Abschnitte, Akkorde, Melodien, Schlagzeugmuster, Seeds, Abschnitts-Automation) mit seinem eigenen
Instrument. Neu ist die Produktion aus der Skizze der Audio-Studie, jetzt für das ganze Stück bei 44,1 kHz:
Sub-Kick und Snare mit Knall und Platte unter den alten, Shaker in Refrains, Solo und Schlussrefrain, Sub-Bass unter
der Basslinie, zwei weitere Rhythmusgitarren mit dunklerem Verstärker innen, die Supersaw-Dopplung der Synth-Melodie,
tieferes Pumpen, neue Hallräume, der Mehrband-Master. Die neuen Ebenen folgen der Automation der Spur, die sie
doppeln.

- **Gleiche Noten** (`check_music.py`): Tonklassen je Takt gleich verteilt – Kosinus der Chroma-Vektoren im Median
  0,970, 94 % der Takte ≥ 0,85; Akkord-Grundton in 97 von 108 Takten gleich. Die übrigen elf Takte sind Dreiklänge mit
  zwei gemeinsamen Tönen (a-Moll / C-Dur im Pre-Chorus, wo ein gehaltenes e die Waage kippt; Intro-Takte); das
  Original selbst trifft die Partitur in 94,4 %, das Remaster in 90,7 % der Takte. Tonart vor dem Schlussrefrain (er
  steht einen Ganzton höher) bei beiden e-Moll.
- **Schleife** wie beim Original: Intro 15 s einmal, Schleife bis zum Dateiende; der Körper endet mit der Kehre des
  Intros, die Naht ist Teil der Musik – im Rendering weicht die Fortsetzung vom Schleifenbeginn um −98,4 dBFS ab.
- **Pegel**: −14,12 LUFS, True Peak −1,67 dBTP nach Vorbis (davor −2,22). Im Menü über die Kette gemessen
  (`capture_mix.gd --scenario=menu`): −21,2 LUFS in der ersten Minute (das leise Intro), für das ganze Stück
  −20,2 LUFS (abgeleitet: die erste Minute der Datei ist 1,05 LU leiser als das ganze Stück) – Plan −20.
- **Klangbild** gegen das Original (Terzspektrum, gleiche Lautheit): +11 dB Sub bei 50 Hz, 2–3 dB weniger zwischen
  100 und 500 Hz, +3 bis +6 dB Luft über 6 kHz.

### 14.4 Rennstück 1 „Linke Spur“

Aus der Skizze der Audio-Studie gewachsen (d-Moll, 132 bpm, ihr Groove, Motiv und Hook), im Markenklang der
Titelmelodie: Synthwave-Rock aus den Instrumenten von `music_synth.py` und den neuen Ebenen. 1 Takt = 20/11 s.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | A | Snare-Crescendo, Toms, Riser, Rückwärts-Becken, Arpeggio und Pad schwellen an – keine Kicks, die neben den Countdown-Pieptönen wie Echos klängen |
| A1 | 8 | d d B C d d B C | Groove (Kick auf jeder Viertel, rollende Achtelbässe mit Oktavsprüngen, gedämpfte Gitarren), Motiv der Skizze ab Takt 5 |
| B1 | 8 | B C d d B C F A | der Hook der Skizze mit Supersaw-Dopplung, offene Gitarren 3-3-2, Clap |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre |
| P1 | 8 | g g B B C C A A | Aufstieg mit Bläser-Stößen, Snare-Wirbel in Takt 7–8 |
| B2 | 8 | wie B1 | Hook mit Harmoniestimme und Leadgitarre eine Oktave tiefer |
| D | 8 | B F C d B F C A | Breakdown: FM-Glocken, weiche Melodie, Schlagzeug baut sich auf |
| S | 8 | d B C d d B C A | Gitarrensolo |
| P2 | 8 | wie P1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem: Harmonie, Gitarre, Bläser, Becken jeden zweiten Takt |
| A3 | 8 | wie A1 | Motiv und Antwort in Oktaven (Synth und Gitarre) |
| T | 8 | d d B C g g A A | Kehre: Halbtempo, lange Töne, Riser in A1 |
| Schluss | 2 + Nachklang | B – C – d | Schläge auf B und C, Tom-Wirbel, Schlussakkord d-Moll mit Lead auf f'', klingt 4 s aus |

**Zwei Dateien statt drei Clips.** `linke_spur.ogg` enthält Einzähler und A1 einmal und danach die Schleife
B1 … T, A1 (`loop_offset` auf dem ersten Frame von B1, die Schleife endet am Dateiende) – wie die Titelmelodie. Der
geplante dritte Clip (Einzähler als eigene Datei mit Auto-Advance in die Schleife) scheitert an der Engine: Ein
Auto-Advance startet den nächsten Clip zu früh (gemessen 640 Frames bei der Clip-Reihenfolge Einzähler → Schleife,
128 bei der umgekehrten, Falle 14.13.1) – der Übergang würde doppelt klingen. Die Schleife endet mit A1, so liegt die
Naht mitten in der Musik (A1 → B1) und ist exakt: Was nach dem A1 des Anfangs in B1 nachklingt, klingt auch nach dem
A1 am Ende der Schleife nach. Gemessen: Die Fortsetzung im Rendering weicht vom Schleifenbeginn um −172 dBFS ab, und
in Godot gleicht die Ausgabe nach dem Dateiende dem ersten Durchgang Frame für Frame.

**Ein Rendering, ein Master.** Einzähler, Schleife, eine Fortsetzung (drei Takte B1 für die Nahtprüfung), drei Takte
Stille und der Schluss liegen auf einer Zeitleiste; der Master (Schwellen und Pegel) wird an der Schleife eingestellt
und gilt für alles. So hat der Schluss genau den Klang und das Pegelverhältnis der Schleife.

**Der Schluss** setzt am nächsten Taktstrich nach dem Ziel ein (`AudioStreamInteractive`, Übergang „nächster Takt“,
Schleife endet in 1 ms – `FADE_DISABLED`). Jedes längere Ausblenden lässt den nächsten Schlag der Schleife unter dem
ersten Schlag des Schlusses mitklingen: gemessen über alle 88 Taktstriche +1,7 bis +4,3 dB in den ersten 100 ms und
True Peaks bis +2,2 dBTP (Dateipegel) für 1/16 bis 1/2 Schlag Ausblenden, mit dem Schnitt +0,01 dB. Den Schnitt
verdeckt der Schluss selbst: Er beginnt mit Kick, Becken und Impact.

**Noten** (`check_music.py`): Akkord-Grundton in 85 von 97 Takten wie in der Partitur (87,6 %); die übrigen sind
Dreiklänge mit gemeinsamen Tönen (A → e-Moll in den A7-Takten, B → d-Moll im Breakdown, wo Glocken und Melodie d und f
spielen). Tonart d-Moll, Schluss B – C – d erkannt.

**Pegel im Spiel** (`capture_mix.gd --scenario=race_music`, Gran Turismo, Musik allein über `--mute-bus=MEnv`):
Vollgas durch die Gänge −23,7 LUFS (Plan −24, also 7,7 dB unter dem Auto mit −16), Höchsttempo −23,2, Reisetempo
130 km/h −21,6. Auto und Musik zusammen: Vollgas −15,5 LUFS, ganze Fahrt −16,1 LUFS, True Peak −5,1 dBTP.
`gain_db` bleibt 0: Die Renn-EQ-Mulde und `context_db.race` (+1 dB) gleichen sich für dieses Stück aus.

**Seit AU-D2** schreibt `linke_spur.py` nach Hauptdatei und Schluss auch die Zusatzclips (14.7) in d-Moll; Hauptdatei
und Schluss sind dabei bitgleich geblieben (sha256 nach dem neuen Rendering gleich). Rotation 1: das erste Rennstück
einer Sitzung.

### 14.5 Rennstück 2 „Nachtfahrt“

Das dunkle der drei Rennstücke: c-Moll, 105 bpm (1 Takt = 16/7 s, eine Sechzehntel genau 6300 Frames), eine
Nachtfahrt im Markenklang. Wo „Linke Spur“ (d-Moll, 132 bpm) auf vier Vierteln rollt, pulsiert dieses: Halbtakt-Groove
in den Strophen (Kick auf 1 und auf „und“ von 3, große Snare mit Gate-Hall auf 3, Sechzehntel-Hi-Hats), ein
sequenzierter Sechzehntel-Synth-Bass mit Oktavsprüngen (der Sub folgt den Vierteln), ein hypnotisches Arpeggio
(Grundton – Quinte – Spitze – Terz) über weiten Flächen mit Farbakkorden (Cm9, A♭maj7, E♭add9, Fm7, B♭add9), sparsame
dunkle Gitarren, das Motiv auf der weichen Lead-Stimme und ein hoher Hook über ♭VI – ♭III – ♭VII – i.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | G | Hi-Hats schwellen an, Toms, Riser – keine Kicks neben den Countdown-Pieptönen |
| A1 | 8 | c A♭ f G c A♭ f G | Halbtakt-Groove, Synth-Bass, Arpeggio; Motiv (weiche Lead) ab Takt 5 |
| B1 | 8 | A♭ E♭ B♭ c A♭ E♭ B♭ G | Hook mit Supersaw-Dopplung, Vierviertel-Kick, Gitarrenwand |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre, Shaker, gedämpfte Gitarren |
| C1 | 8 | f f A♭ A♭ B♭ B♭ G G | Aufstieg: Toms, Bläser-Stöße, gedämpfte Sechzehntel, Snare-Wirbel |
| B2 | 8 | wie B1 | Hook mit Harmonie, Leadgitarre eine Oktave tiefer |
| D | 8 | A♭ E♭ f c A♭ E♭ f G | Breakdown: FM-Glocken über dem Arpeggio, weiche Melodie |
| S | 8 | c A♭ E♭ B♭ c A♭ f G | Gitarrensolo |
| C2 | 8 | wie C1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem: Harmonie, Gitarre, Bläser |
| T | 8 | c c A♭ A♭ f f G G | Kehre im Halbtakt, Tom-Wirbel in A1 |
| Schluss | 2 + Nachklang | A♭ – B♭ – c | Schläge, Tom-Wirbel, Schlussakkord Cm9 mit Lead auf es''' |

`nachtfahrt.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (80 Takte = 182,86 s, 8 064 000 Frames) –
dieselbe Bauart wie „Linke Spur“ (die Naht liegt in A1 → B1; der zweite Durchgang weicht vom ersten um −186,7 dBFS
ab, gemessen vor der Kodierung). Bis zur ersten Wiederholung 203,4 s. Rotation 2.

### 14.6 Rennstück 3 „Rückenwind“

Das helle der drei: A-Dur, 150 bpm (1 Takt = 1,6 s, eine Sechzehntel genau 4410 Frames), aufbrechender
Synthwave-Rock. Gegen „Linke Spur“ und „Nachtfahrt“: Dur, das schnellste Tempo, ein Disco-Rock-Beat (Kick auf allen
Vierteln, offene Hi-Hats auf den Achtel-Nachschlägen), Oktav-Achtelbässe, Gitarren im 3-3-2-Rhythmus des Markenklangs,
ein funkelndes aufsteigendes Arpeggio, der heroische Aufstieg ♭VI – ♭VII – I (F – G – A) und ein Hook, der bis zum
hohen a''' steigt.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| Einzähler | 1 | E | Claps schwellen an, Snare-Wirbel, Riser |
| A1 | 8 | A E f♯ D A E D E | Groove, Gitarren 3-3-2, Motiv ab Takt 5 |
| B1 | 8 | D E c♯ f♯ D E A E | Hook mit Supersaw-Dopplung, Crash alle zwei Takte |
| A2 | 8 | wie A1 | Motiv und Antwort auf der Leadgitarre |
| P1 | 8 | F G A A F G E E | Aufstieg ♭VI – ♭VII – I, Bläser, Tom-Groove |
| B2 | 8 | wie B1 | Hook mit Harmonie, Leadgitarre eine Oktave tiefer |
| D | 8 | f♯ D A E f♯ D E E | Breakdown: Glocken, weiche Melodie |
| S | 8 | wie A1 | Gitarrensolo |
| P2 | 8 | wie P1 | Aufstieg, Leadgitarre doppelt |
| B3 | 8 | wie B1 | Hook mit allem |
| A3 | 8 | wie A1 | Motiv und Antwort in Oktaven |
| T | 8 | A A D D f♯ f♯ E E | Kehre: Halbtakt, dann 3-3-2 |
| Schluss | 2 + Nachklang | F – G – A | Schläge, Tom-Wirbel, Schlussakkord Aadd9 mit Lead auf cis''' |

`rueckenwind.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (88 Takte = 140,8 s, 6 209 280 Frames;
Naht −175,7 dBFS, gemessen). Bis zur ersten Wiederholung 155,2 s. Rotation 3.

**Gemessen an beiden Stücken**: Lautheit und True Peak in 14.1; die Klangbalance (Langzeitspektrum in acht Bändern
von 25 Hz bis 18 kHz, bezogen auf die Gesamtenergie) liegt in jedem Band höchstens 1,0 dB von „Linke Spur“ entfernt
(Nachtfahrt: tiefe Mitten +1,0 dB, Bass −0,5 dB; Rückenwind: Mitten bis Luft +0,7 bis +0,8 dB). Noten
(`check_music.py`): „Nachtfahrt“ Grundton in 83 von 89 Takten wie in der Partitur (93,3 %), Tonart c-Moll; „Rückenwind“
in 87 von 97 Takten (89,7 %), Tonart A-Dur – die übrigen sind Farbakkorde und Obertöne (Falle 15).

### 14.7 Schlüsse, Ziel-Schlag und Stinger

Jedes Rennstück hat fünf Zusatzclips in seiner Tonart, gespielt von seinen eigenen Instrumenten (`race_lib.Extras`,
eine Partitur für jede Tonart und jedes Tempo):

| Clip | Takte | Inhalt | wann |
|---|---|---|---|
| `<stück>_ziel` | 1 | Schlag auf der Tonika: Kick, Crash, Snare, Clap, Impact, Gitarren- und Bläserakkord, ein kurzes Quint-Oktav-Motiv | sofort an der Ziellinie, über der abgesenkten Schleife – nur wenn der Taktstrich des Schlusses mehr als 0,3 s entfernt ist |
| `<stück>_schluss_rekord` | 3 | der Schluss (Kadenz – Tonika) mit einer Fanfare im 3-3-2-Rhythmus die Tonika hinauf, Glocken | neuer Rekord: am nächsten Taktstrich statt des normalen Schlusses |
| `<stück>_schluss_finale` | 4 | die Kadenz zweimal (beim zweiten Mal höher, mit Snare-Wirbel), dann die **Dur**-Tonika mit Fanfare auf ihrer Terz (Moll-Stücke enden picardisch in Dur: d → D, c → C) | letzte Etappe eines Rennens: am nächsten Taktstrich |
| `<stück>_polizei` | 3 | „Erwischt“: Schläge auf i – ♭II (phrygisch) – i, dann ein chromatischer Fall von der Quinte zum Grundton, Tom-Wirbel, Schlussschlag | Ereignis `busted`, auf dem nächsten Schlag |
| `<stück>_tank` | 2 | „Tank leer“: ein seufzender chromatischer Abstieg, dann sinkt der Grundton um eine Oktave; das Arpeggio geht aus | Ereignis `out_of_fuel`, auf dem nächsten Schlag |

Dur-Stücke („Rückenwind“) leihen sich für die Stinger das gleichnamige Moll (a-Moll, ♭II = B, iv = d). **Gleicher
Klang, gleicher Pegel wie das Stück**: Die Zusatzclips werden nach der Hauptdatei auf einer eigenen Zeitleiste
gerendert (je Clip gefolgt von vier leeren Takten, damit kein Hall in den nächsten reicht) und mit den Spurpegeln des
Stücks gemischt (`Mixer(ref=fit)`: Normierung, Kompressorschwellen, Sättigungsbezug, Schlagzeugbus aus dem Rendering
des Stücks) und mit seinem gemessenen Master bearbeitet (`Master.post`); ein Clip, dessen True Peak nach Vorbis zu
hoch läge, bekommt nur für sich eine tiefere Begrenzergrenze. So bleibt die Hauptdatei von „Linke Spur“ bitgleich,
und ihre Zusatzclips klingen trotzdem wie sie.

### 14.8 Zwischenspiel

Die ruhige Schleife der Bildschirme zwischen den Etappen (Kontext `race_menu`, und `result`, solange es kein eigenes
Stück gibt): e-Moll wie die Titelmelodie, 100 bpm (1 Takt = 2,4 s, eine Sechzehntel 6615 Frames), im Markenklang,
aber leise gespielt – Flächen (Em9, Cmaj7, Gadd9, Am7, B7), FM-Glocken, ein weiches Achtel-Arpeggio, eine cleane
Gitarre (das Saitenmodell ohne Verstärker), ein runder Synth-Bass, ein weicher Halbtakt-Beat ohne Crash und Impact.

| Abschnitt | Takte | Akkorde | Inhalt |
|---|---|---|---|
| T (Intro) | 2 | a H | die Kehre der Schleife, einmal |
| A | 8 | C G D e C G a H | eine eigene Glockenmelodie über den Flächen |
| B | 8 | e C G D e C G D | **der Hook der Titelmelodie** auf der weichen Lead-Stimme (Wiedererkennung), Arpeggio, Shaker |
| A' | 8 | wie A | die Glockenmelodie auf der weichen Lead eine Oktave tiefer, cleane Gitarre |
| B' | 6 | e C G D e C | der Hook mit Harmonie, cleane Gitarre |
| T | 2 | a H | Kehre, Tom-Auftakt in A |

`zwischenspiel.ogg`: das Intro (= die letzten zwei Takte der Schleife) einmal, dann 32 Takte = 76,8 s
(3 386 880 Frames) in Schleife bis zum Dateiende; die Naht liegt in der Musik (zweiter Durchgang −112,9 dBFS vom
ersten entfernt – der Ausklang der Echos, unhörbar; gemessen). Datei auf −14 LUFS wie jedes Stück;
im Spiel bringt die Kette (Kontext `race_menu` −1 dB, Regler) es auf die Menü-Lautheit von −20 LUFS (abgeleitet wie
beim Titel, 6.1). Vom Ergebnisbildschirm zum Etappenbildschirm läuft es ohne Neustart weiter.

### 14.9 UI-Klänge

`assets/audio/modern/ui/` (Generator `tools/audio/music/ui_klaenge.py`): weiche Menüklänge im Markenklang – der
gezupfte Synth und die FM-Glocke der Musik, e-Moll-Pentatonik (die Tonart von Titel und Zwischenspiel unter den
Menüs), ein Hauch der Platte der Musik-Kette; 16-Bit-WAV, 44,1 kHz Stereo, je auf eine eigene Momentanlautheit
(400 ms) gebracht, True Peak höchstens −3 dBTP.

| id | Dateien | wofür | Lautheit / True Peak (Datei) | Größe |
|---|---|---|---|---|
| `ui_move` | `ui_move_1.wav`, `ui_move_2.wav` | Fokus wandert (Momentanlautheit −23 LUFS) | −23,0 LUFS / −13,1 dBTP | 145 kB |
| `ui_ok` | `ui_ok.wav` | Bestätigen (Momentanlautheit −18 LUFS) | −22,1 LUFS / −8,4 dBTP | 146 kB |
| `ui_back` | `ui_back.wav` | Zurück (Momentanlautheit −19,5 LUFS) | −22,7 LUFS / −9,6 dBTP | 121 kB |
| `ui_tab` | `ui_tab.wav` | Reiter wechseln (Momentanlautheit −20,5 LUFS) | −22,5 LUFS / −10,8 dBTP | 138 kB |
| `ui_toggle` | `ui_toggle.wav` | Wert ändern (Momentanlautheit −21,5 LUFS) | −24,2 LUFS / −11,1 dBTP | 86 kB |
| `ui_error` | `ui_error.wav` | Geht nicht (Momentanlautheit −20 LUFS) | −20,1 LUFS / −11,2 dBTP | 78 kB |

Zusammen 713 kB (ohne den Platzhalter von AU-A). Pegel im Spiel (abgeleitet): `MUI` 0 dB, `MSfx` 0 dB,
Gesamtlautstärke 0,8 (−1,9 dB): „Bestätigen“ erreicht etwa −20 LUFS momentan – so laut wie die Menümusik integriert,
„Fokus“ etwa −25 LUFS; der Arcade-Klang „ui_ok“ liegt ebenso bei etwa −21 LUFS momentan (berechnet aus `SfxSynth`
und `ONESHOT_DB`).

**Verdrahtung**: `ui_move`, `ui_ok` und `ui_back` sind die Namen, die die Menüs heute spielen (`UiKit.sound()`,
`AudioManager.play()`): Mit dem Profil Modern nimmt `SfxBank` dafür die Datei aus `ui/` (`ROUTES`), `ui_move` mit zwei
Varianten reihum. `ui_tab`, `ui_toggle` und `ui_error` gibt es als Namen im Spiel noch nicht: Die UI spielt sie mit
`AudioManager.play("ui/ui_tab")` usw. (`SfxBank` nimmt „<Ordner>/<id>“; das Profil Arcade kennt die Namen nicht und
bleibt still) – offener Punkt für UI2 (14.14). Das Profil Arcade behält seine Klänge.

### 14.10 Gemeinsame Mischung (`tools/audio/music/mischung.json`)

Was der Nutzer am Klang noch ändern könnte, steht für alle Stücke an einer Stelle; jeder Generator liest die Datei.

| Schlüssel | wirkt auf | Standard |
|---|---|---|
| `sub_db` | Tiefbass: Sub-Bass unter der Basslinie und Sub-Kick (auf den Pegel jedes Stücks addiert) | 0 |
| `bass_db` | gezupfter Bass und Synth-Bass | 0 |
| `high_shelf_db`, `high_shelf_hz` | Höhen der Summe: ein Kuhschwanzfilter im Master (bei 0 dB gibt es keinen) | 0 dB, 6000 Hz |
| `low_shelf_db`, `low_shelf_hz` | Tiefen der Summe: ein Kuhschwanzfilter im Master (bei 0 dB gibt es keinen; AU-R) – der wirksame Knopf für „zu viel / zu wenig Bass“: `sub_db` und `bass_db` bewegen den Bass der Summe kaum, die Kick hat keinen eigenen (KRITIK-MISCHUNG 2) | 0 dB, 120 Hz |
| `race_music_db` | Musik im Rennen gegen das Auto: `gain_db` der Rennstücke, ihrer Schlüsse und Stinger | 0 |
| `menu_music_db` | `gain_db` von Titel-Remaster und Zwischenspiel | 0 |
| `ui_db` | `gain_db` der UI-Klänge | 0 |

Nach einer Änderung: `python3 tools/audio/music/render_all.py` (alle Stücke, etwa 25 Minuten auf einem Kern), dann
`godot --headless --import`. `race_music_db`, `menu_music_db` und `ui_db` ändern nur `gain_db` im Manifest, nicht
den Klang der Dateien; dorthin kommen sie trotzdem mit einem ganzen Lauf (einen schnelleren Weg gibt es nicht). Bei
allen Werten 0 schreiben die Generatoren die Dateien vom 11.11.2026
bitgleich (gemessen: Titel-Remaster und „Linke Spur“ nach dem Umbau mit gleicher sha256).

### 14.11 Der `MusicDirector`

| Kontext | Stück |
|---|---|
| `title`, `menu` | Rolle `title`: das Titel-Remaster (ohne Modern-Datei die Titelmelodie von heute) |
| `race_menu` | Rolle `interlude`: das Zwischenspiel (ohne es das Titel-Remaster) |
| `result` | Rolle `result`; ohne eigenes Stück das Zwischenspiel, dann das Titel-Remaster |
| `race` | ein Rennstück (Rolle `race`, reihum eins je Etappe in der Reihenfolge `rotation`: Linke Spur, Nachtfahrt, Rückenwind, …) |
| `off` | Stille |

Das Rennstück und die Etappe:

| Phase | wann | was |
|---|---|---|
| `armed` | `set_music_context("race")` – jede Etappe, auch ein Neustart | die Menümusik blendet aus, das nächste Stück der Rotation wartet |
| `waiting` | Ereignis `stage_start` {countdown_s} | Start in countdown_s − Einzähler; jede Countdown-Zahl (`countdown` {n}) verankert neu: Start in n − Einzähler |
| `playing` | der Start ist da (das Bild, das dem geplanten Moment am nächsten liegt), `go` ohne `stage_start`, oder 0,5 s Fahrt ohne jedes Ereignis (Werkzeuge) | `play()` des `AudioStreamInteractive`; der erste Schlag nach dem Einzähler fällt auf „LOS!“ |
| `ending` | `stage_finish` {record, last_stage} | der Schluss am nächsten Taktstrich: `finale` auf der letzten Etappe, sonst `rekord` bei neuem Rekord, sonst der normale; davor sofort der Ziel-Schlag, wenn der Taktstrich mehr als 0,3 s entfernt ist |
| `over` | `stage_finish` ohne spielendes Stück („Musik im Rennen: Aus“ oder vor dem Start) | der passende Schluss sofort als Einzelklang – der Zielklang der Etappe |

- **Das Ziel gehört der Musik**: Der Director beansprucht `stage_finish` (`claims()`, nur wenn ein Rennstück Schlüsse
  hat) – der „finish“-Jingle des `AudioManager` (C-Dur-Arpeggio) entfällt in diesem Moment (Abschnitt 7) und klingt
  nicht gegen den Schluss in d-Moll, c-Moll oder A-Dur. Folge: Mit dem Regler „Musik“ auf 0 ist das Ziel im Profil
  Modern still (der Zielklang ist Musik).
- **Der Schluss klingt aus**: Verlässt das Spiel die Etappe in einen Menü-Kontext (Ergebnisbildschirm 6 s nach dem
  Ziel), spielt der Schluss weiter, bis er bis auf 1,2 s ausgeklungen ist (höchstens 10 s); erst dann blendet das
  Zwischenspiel ein. Ein Kontext außerhalb der Menüs (`off`, `race`) beendet das sofort.
- **Stinger**: `busted` und `out_of_fuel` spielen den Stinger des laufenden Stücks auf dem nächsten Schlag auf einem
  eigenen Player (`MusicSting` auf `MMusic`); das Rennstück sinkt darunter um `sting_duck_db` (−9 dB, Attack 50 ms),
  hält die musikalische Länge des Stingers und kommt in `sting_release_s` (1 s) zurück. Nur solange das Stück spielt
  (Stinger sind Musik): ohne „Musik im Rennen“, vor dem Start und nach dem Ziel keine. Beide Werte liest der Director
  aus `audio.modern.music`, falls jemand sie dort einträgt (heute steht dort keiner – Standardwerte im Code).
- **Die Taktuhr** `music_t`: Sekunden, die der Stream spielt – auch in der Pause nach „LOS!“, in der die Musik nur
  gefiltert weiterläuft (die Spielzeit-Uhr `race_t` steht dort). Aus ihr folgen der nächste Taktstrich (Ziel-Schlag)
  und der nächste Schlag (Stinger); das Taktraster beginnt mit Frame 0 der Datei, die Schleife ist ganze Takte lang.
- Weiter wie bei AU-D1: **Uhr des Starts** (Physikschritte), **Pause im Einzähler**, **„Musik im Rennen: Aus“** (das
  Stück bleibt still; wieder an, beginnt es mit seinem Einzähler), **Platzhalter** nur ohne echtes Stück, **Pegel**
  `context_db` + `gain_db`, **Ende** (`teardown()` gibt alle drei Player frei).

### 14.12 Prüfungen

| Datei | prüft |
|---|---|
| `tests/unit/audio_modern/test_music_director.gd` | ohne Szenenbaum: Stücke je Kontext, das Zwischenspiel (race_menu, result, ohne Neustart zwischen beiden), Start und „LOS!“, Rotation der drei Stücke (Einzähler je Tempo, Schlüsse, Stinger), Neuverankerung, kurzer Countdown, `go`, Start ohne Ereignisse, Ziel mit Ausklingen in den Ergebnisbildschirm, Neustart, Ziel vor dem Start (Schluss als Zielklang), Schluss-Varianten und Ziel-Schlag (nur fern vom Taktstrich, Absenkung bis zum Taktstrich), Stinger auf dem Schlag mit Absenkung und Rückkehr, keine Stinger ohne Rennmusik oder nach dem Ziel, Ziel ohne Rennmusik, „Musik im Rennen“, Pause im Einzähler, die Taktuhr in der Pause, der gebaute `AudioStreamInteractive` (vier Clips), Platzhalter |
| `tests/unit/audio_modern/check_music.gd` | eigene Prozesse: **interactive** – jedes Rennstück offline in 512er-Schritten wie der Mischer: die ganze Hauptdatei Frame für Frame, nach dem Dateiende Abweichung 0 zum ersten Durchgang, der normale Schluss nach der Schleife am Taktstrich (höchstens 3 ms davor), ohne Lücke, ohne doppelten Schlag; die Varianten `rekord` und `finale` (Nachtfahrt, im ersten Durchgang) ebenso (gemessen: alle Schlüsse 2,90–2,93 ms vor dem Taktstrich, leisestes 5-ms-Fenster 6,4–7,6 dB unter der Musik davor, erste 100 ms −0,04 bis +0,01 dB gegenüber dem Clip allein); die Naht des Zwischenspiels (nach dem Dateiende Abweichung 0 zum ersten Durchgang); **arcade** – wie bei AU-D1, dazu nach den Ereignissen `busted`, `out_of_fuel`, den UI-Klängen und dem Kontext `race_menu`: keine Datei aus `music/` oder `ui/` geladen; **race**, **quit_menu**, **quit_race** wie bei AU-D1 |
| `tests/unit/audio_modern/test_music_checks.gd` | startet `check_music.gd` (so deckt `tools/run_tests.sh` es ab) |
| `tools/audio/music/check_music.py` | Noten: Titel gegen Original; jedes Rennstück gegen seine Partitur (Grundton je Takt oder ein Dreiklang aus den Tönen des gespielten Farbakkords), Tonart, Schluss; die Zusatzclips (Ziel-Schlag auf der Tonika, Rekord auf der Tonika, Finale in Dur, Stinger in der Moll-Tonart des Stücks) |
| `tools/audio/qc/audio_qc.py` | Dateien, Pegel, Nähte, Import, Größe; `--determinism` |

### 14.13 Fallen (gemessen, Godot 4.7.2)

1. **Auto-Advance startet zu früh**: `_queue()` rechnet die Wartezeit von der Position des Decoders, der dem Ausgang
   bis zu 128 Frames voraus ist, und der neue Clip zählt den laufenden Mischblock schon mit – gemessen 640 Frames zu
   früh (Clip 0 → 1), 128 Frames (1 → 0). Gegenmittel: Intro und Schleife in einer Datei mit `loop_offset`.
2. **„Nächster Takt“ rechnet vom Decoder**: Der Schluss beginnt bis zu 128 Frames (2,9 ms) vor dem Taktstrich.
3. **Ausblenden unter dem Schluss verdoppelt den Schlag** (14.4) – `FADE_DISABLED` nehmen.
4. **`AudioStreamPlaybackInteractive.start()` übergeht die Startposition**: Der erste Clip beginnt immer bei 0. Den
   Einzähler deshalb als ganze Takte an den Dateianfang legen und den Start zeitlich planen.
5. **`beat_count` zählt vom Dateianfang**: Mit `bpm` und `beat_count` springt eine Ogg-Schleife nach beat_count
   Schlägen ab Frame 0 zurück, nicht ab `loop_offset`. Dateien mit Intro tragen deshalb `beat_count` 0 (die Schleife
   endet am Dateiende) – und im Manifest kein `beats`, denn `audio_qc.py` setzt `beats` gleich der Schleifenlänge.
6. **`loop_offset` braucht alle Stellen**: Godot schneidet loop_offset × Rate auf einen Frame ab; mit 6 Stellen
   (16,3636) läge der Rücksprung zwei Frames daneben. Der Generator schreibt (Frame + 0,25) / Rate.
7. **Der eingefrorene Oszillator wählt seine Bandbegrenzung nach dem höchsten Ton der ganzen Phrase**: Eine vor dem
   Rendern gekürzte Phrase klingt heller oder dunkler. Phrasen werden immer ganz gerendert und danach abgeschnitten.
8. **`AudioStreamPlayback.mix_audio()` eines zu Ende gespielten Streams** liefert weniger Frames (Schleifen in Prüfungen
   auffüllen, sonst endlos). Jeder Clip erreicht den Ausgang 2 Frames später (kubischer Resampler).
9. **Der Dummy-Treiber** startet jeden Klang an seiner nächsten Portion (4096 Frames, 93 ms): Zeitmessungen zwischen
   zwei Klängen ohne Bildschirm schwanken um eine Portion.
10. **„leaked at exit“ nach `quit()`**: Ein gestoppter Klang wird vom AudioServer erst nach dem Ausblenden im Mischer
    und in einem späteren Bild des Hauptthreads freigegeben. Ein `quit()` gleich danach meldet „ObjectDB instances were
    leaked at exit“ – mit dem Profil Arcade (Menümusik von v0.7.0) in 3 von 6 Läufen, mit Modern in 2 von 6. Mit 0,3 s
    zwischen dem Ende des Profils und `quit()`: 0 von 16.
11. **`modern_lib.write_ogg_import()` verliert den Kopf der `.import`-Datei** (Abschnitt 13): `music_lib` hat dafür
    `write_ogg_import_keep()`.
12. **Tempo und Schleife** (AU-D2): Damit die zwei Durchgänge über den Schleifenbeginn gleich sind, braucht ein
    Stück zwei Dinge. (a) Eine Sechzehntel ist eine ganze Zahl von Frames – bei 112 und 144 bpm (5906,25 / 4593,75
    Frames) lagen Einsätze auf halben Frames und rundeten im ersten und im zweiten Durchgang verschieden: die
    Fortsetzung wich vom Schleifenbeginn um −30 dBFS ab (gemessen; die Lead-Noten ab dem zweiten Ton jedes Takts um
    einen Frame verschoben). (b) Die Schleife ist ein Vielfaches von 63 Frames: Der eingefrorene Kompressor
    (`music_synth.compressor_gain`) misst den Pegel in Blöcken zu 63 Frames ab Frame 0 – sonst liegt das Raster in
    beiden Durchgängen anders und die Kompressoren regeln um etwa 0,1 dB verschieden (gemessen bei 108 bpm: −34 dBFS
    über die ganze Schleife). Beides erfüllen 100, 105, 125, 140, 150 bpm für jede Taktzahl (eine Sechzehntel ist ein
    Vielfaches von 63 Frames); `race_lib.check_tempo()` lehnt andere Tempi ab. „Linke Spur“ (132 bpm, Schleife
    7 056 000 = 63 × 112 000 Frames) trifft nie genau einen halben Frame und ist exakt (−172 dBFS).
13. **Sub-Faltung** (AU-D2): `sub_bass` faltet in 36–75 Hz; in c-Moll und A-Dur landen F und E dabei bei 42–44 Hz –
    im 40-Hz-Terzband +5,8 / +6,3 dB gegenüber „Linke Spur“ (gemessen). Die neuen Stücke falten in 45–94 Hz
    (`RacePiece.SUB_FOLD`); Titel und „Linke Spur“ bleiben bei 36 Hz (bitgleich).
14. **Ende einer Synth-Phrase** (AU-D2): `music_synth.synth_lead` rendert eine Phrase bis 0,6 s nach ihrer letzten
    Note und schneidet dort ab. Mit dem Patch „soft“ (Ausklang 0,16 s) liegt der Ausklang an der Schnittstelle noch
    34 dB unter der Spitze der Phrase (gemessen; „lead“: −63 dB) – ein leises Knacken in ruhigen Stellen.
    `race_lib.phrase_end()` blendet die letzten 60 ms aus (alle Stücke über `race_lib`, das Zwischenspiel); die
    Hauptdatei von „Linke Spur“ behält es (bitgleich zu AU-D1, offener Punkt). Dieselbe Länge (`int` einer
    Fließkomma-Zeitspanne) kann in zwei Durchgängen um einen Frame verschieden sein – endet eine Phrase nach dem
    Schleifenpunkt, weicht die Naht dort um einen Frame ab (Zwischenspiel vor der Korrektur: −67 dBFS, danach
    −112,9 dBFS).
15. **Akkorderkennung der Prüfung** (AU-D2): Farbakkorde (A♭maj7 enthält c-Moll, Cm9 enthält E♭-Dur) und die dritte
    Harmonische der Quinten im Bläser- und Gitarrenakkord (D4 → A5) ziehen die Chroma zum Nachbar-Dreiklang. Die
    Prüfung zählt deshalb einen Dreiklang aus den Tönen des gespielten Akkords als Treffer, beurteilt beim Schluss
    den ersten Akkord und die Tonika und bei den Stingern die Tonart.

### 14.14 Offene Punkte

- **Hören**: „Nachtfahrt“, „Rückenwind“, Zwischenspiel, Schlüsse, Stinger und UI-Klänge muss der Nutzer beurteilen
  (Hörproben `<scratch>/v080/deliver/AU-D2/`). Bass und Pegel ändert `mischung.json` für alle Stücke zugleich (14.10).
- **UI2**: `ui_tab` (Reiter LB/RB der Optionen), `ui_toggle` (Wert einer Optionszeile) und `ui_error` (nicht möglich)
  aufrufen – Vorschlag: `UiKit.sound("ui/ui_tab")` usw. an den Stellen, die heute `ui_move` spielen, und für Arcade
  dort weiter `ui_move` (das Profil Arcade kennt die neuen Namen nicht). Sauberer wäre ein Eintrag in
  `SfxBank.ROUTES` und `AudioManager.ONESHOT_DB` (Ersatz: der Arcade-Klang `ui_move` bzw. `ui_back`) – das gehört
  AU-E bzw. dem Eigentümer des `AudioManager`.
- **AU-E**: die Stinger im Rennen mit der ganzen Kette messen (`capture_mix.gd`), `sting_duck_db`/`sting_release_s`
  gegebenenfalls in `audio.modern.music` eintragen; ob der Ziel-Schlag mit echtem Treiber auf den Taktstrich passt
  (die Taktuhr zählt ab `play()`, die Ausgabe beginnt eine Treiberportion später – abgeleitet: Absenkung endet bis zu
  einer Portion zu früh).
- **Beenden des Spiels** (UI / AU-E): `GameFlow.quit_game()` sollte den Klang anhalten und 0,3 s warten, bevor es
  `quit()` ruft (Falle 10) – betrifft beide Profile.
- **`capture_mix.gd --scenario=race_music`** sendet kein `stage_start` (AU-D1) – für das Leerlauf-Ziel nicht
  vergleichbar.
- **QC-Regel und Godot**: `audio_qc.py` vergleicht `beats` mit der Schleifenlänge, Godot zählt `beat_count` vom
  Dateianfang (Falle 5).
- **„Linke Spur“, Hauptdatei**: Die weiche Lead-Stimme (Breakdown D, Kehre T) endet je Phrase mit dem leisen Schnitt
  von Falle 14.13.14. Beim nächsten Rendering von Stück 1 (etwa nach dem Urteil des Nutzers zu Bass und Pegel) lässt
  sich das in `linke_spur.py` mit `race_lib.phrase_end()` beheben – dann ist die Datei nicht mehr bitgleich zu den
  Hörproben vom 11.11.2026, darum ist es heute nicht geschehen.
- **Stücke 4–5**: nur, wenn alles andere fertig ist (Vertrag D30); `race_lib.RacePiece` macht ein weiteres Stück zu
  einer Partitur-Datei (Muster: `nachtfahrt.py`).

## 15. Fahrbahn, Wind, Aufprall (Paket AU-C1)

Vertrag D27–D29, §4.7.2, §4.7.3, A-5. Alle Zahlen gemessen (Godot 4.7.2, ohne Bildschirm, Dummy-Audiotreiber,
aufgenommen am Master bei Standardreglern), sofern nicht „abgeleitet“ dasteht. **Gehört hat es hier niemand** – das
Urteil über den Klang liegt beim Nutzer (Hörproben unter `<scratch>/v080/deliver/AU-C1/`).

### 15.1 Was zu hören ist

| Ebene | wann | Klang | Bus |
|---|---|---|---|
| Rollen | immer beim Fahren, je Seite der Belag unter den Rädern | Asphalt, Beton (rauer, leises Singen der Rillen), Stahldeck (hohles Dröhnen), Kopfsteinpflaster, Bankett (Schotter, Steine gegen die Radhäuser), Gras (dumpfe Schläge), Rüttelstreifen; zwei geschwenkte Spieler je Belag (linke und rechte Räder), seit AU-R **jede Seite mit ihrer eigenen Schleife** (gleicher Generator, anderer Seed, andere Länge), Start an zufälliger Stelle, langsame Pegeldrift je Seite, rechts Tonhöhe × 1,02 (nicht beim Rüttelstreifen) – nichts wiederholt sich mehr im Sekundentakt | `MRoad` |
| Nässe, Schnee | Regen auf befestigtem Belag; Schnee | Sprühzischen; Schnee dämpft das Rollen (Tiefpass auf `MRoad`, −3 dB) und knirscht – seit AU-R mit einer eigenen Schnee-Schleife (weiches Knirschen gepressten Schnees, ohne die Steinschläge des Schotters) | `MRoad` |
| Betonplatten | Belag Beton | „ta-tock“ von Vorder- und Hinterachse über die Fugen (5 m, Radstand 2,7 m): eine Schleife mit Tonhöhe v / Entwurfstempo, darum stimmt der Takt bei jedem Tempo; zwei Entwürfe (90 und 180 km/h) überblendet zwischen 110 und 150 km/h; seit AU-R 32 Platten je Muster (vorher 8: das Akzentmuster kam alle 40 m wieder) und beide Entwürfe immer im selben Takt (Abschnitt 15.9); seit AU-R2 sind die 32 Platten die 8 Fugen von AU-C1 in gemischter Folge, und über 150 km/h wird der Pegel nur noch um 4 statt 20 dB je Dekade lauter (`slabs.high_slope_db`, Abschnitt 15.10) | `MRoad` |
| Brückenfugen | Feed-Ereignis `joint` | Doppelschlag beider Achsen in einem Klang (Stahl: Fingerfuge klappert; Beton: dumpf); die Variante mit dem nächsten Achsabstand, die Tonhöhe so verschoben, dass der Abstand Radstand / Tempo genau trifft (Radstand = 0,6 × Länge des Autos); Abstand je Deck (AU-R): Stahl an den Enden und etwa alle 100 m, Beton alle 32 m, Steinbogen keine | `MRoad` |
| Vorbeifahrten | Feed-Ereignis `pass_object` | der eigene Klang, von Pfosten, Schild, Baum, Gebäude, Schilderbrücke, Fels zurückgeworfen; seitenrichtig, lauter und kürzer mit dem Tempo, leiser mit dem Abstand; unter 40 km/h nicht; Variante zufällig, ±2 dB (AU-R) | `MRoad` |
| Quietschen, Radieren | Untersteuern (`understeer`), Querbewegung (`lat_speed`), Rutschen beim Unfall (`crash`) | Ton an der Haftgrenze, je Quietschen ±5 % in der Tonhöhe (AU-R); nass und auf Schotter kaum Ton, dafür Radieren | `MRoad` |
| Wind | ab etwa 20 km/h | drei Bänder (Brausen, Rauschen, Zischen mit leisem Dichtungspfeifen) und nahe dem Höchsttempo das Wummern wie bei offenem Fenster; Böen, seit AU-R je Seite (eigene Schleifen); Tunnel 0 dB ohne Böen (der Fahrtwind bleibt im Tunnel, AU-R), Einschnitt −2,5, Wald und Stadt −1, Brücke +2 dB und böiger | `MWind` |
| Kollision | Ereignis `collision` | Schichten nach Schließgeschwindigkeit (leicht < 15 km/h, mittel < 45, schwer): Stoßstangen-Plopp, tiefer Schlag, Blech faltet sich, Glas, Kleinteile; gegen Lkw/Bus ersetzt der Schlag des großen Aufbaus den eigenen; seitenrichtig. Seit AU-R: Varianten zufällig (Glas, Kleinteile, Lkw-Schlag je vier), jede Schicht ±2 dB und bis 20 ms später, Glas ab 80 km/h Schließgeschwindigkeit, darunter in 40 % der Unfälle | `MImpact` |
| Leitplanke | Ereignis `rail_hit`, Zustand `rail_contact` | ab 1,2 m/s Schlag mit schwingender Planke, darunter Streifen; Schleifen in Körnern mit Funken, solange das Auto an der Planke ist, an ihrer Seite | `MImpact` |
| Leitpfosten | `pass_object` mit `contact` | hohles Plopp, der Pfosten schnellt zurück | `MImpact` |

Der Baustein `impact` beansprucht `collision` und `rail_hit` (Abschnitt 7): Der `play("crash")` / `play("rail")`
desselben Moments fällt weg; ein Aufruf ohne Ereignis spielt 50 ms später die mittlere Kollision bzw. die
Leitplanke nach seinem Pegel (`−10 + 2 × m/s` der Sitzung). Das Profil Arcade spielt nichts davon.

### 15.2 Die Klänge

`assets/audio/modern/vehicle/` (`vehicle_loops.py`, Mono, nahtlos, True Peak ≤ −2,7 dBTP), Stand AU-R:

- **je Seite eine eigene Schleife, Ogg Vorbis q5** (`<id>` links, `<id>_b` rechts; der linke Eintrag nennt den
  rechten in `pair`; gleicher Generator, Seed + 50, andere Länge): `tyre_asphalt` (5,3 / 6,7 s), `tyre_concrete`
  (5,1 / 6,3), `tyre_deck` (4,9 / 6,1; alle drei Entwurf 120 km/h, Tonhöhe (v/120)^0,35), `tyre_cobbles` (5,7 / 7,1;
  50 km/h, ^0,9; rechts seit AU-R2 Seed + 64 statt + 50, Abschnitt 15.10), `tyre_gravel` (4,7 / 5,9; 80 km/h, ^0,55), `tyre_grass` (4,3 / 5,5; 60 km/h, ^0,4), `tyre_wet`
  (5,5 / 6,9; 120 km/h, ^0,3), `tyre_snow` (5,0 / 6,4; 80 km/h, ^0,5; neu), `tyre_rumble` (4,1 / 5,3; 100 Schläge je
  Sekunde bei Tonhöhe 1 = 108 km/h, ^1), `wind_low` (5,9 / 7,3), `wind_mid` (5,6 / 6,8), `wind_high` (5,2 / 6,6; alle
  drei 160 km/h, ^0,3 / ^0,5 / ^0,5), `wind_buffet` (6,2 / 7,6; 230 km/h, ^0,25; die linke in q8 – Vorbis kodiert
  das Ende eines Datenstroms ungenauer als die Mitte, bei der tiefen, glatten Schleife wurde die Naht sonst zur
  rauesten Stelle; der Generator nimmt die erste Qualität ab q5, deren Naht höchstens doppelt so rau ist wie ihr
  Umfeld);
- **16-Bit-WAV** mit 16 Fortsetzungsframes hinter `loop_end`: `slab_slow` / `slab_fast` (32 Platten: 6,4 / 3,2 s,
  90 / 180 km/h, ^1; seit AU-R2 aus den 8 Fugen – je Vorder- und Hinterachse ein Schlag – der 8-Platten-Entwürfe
  von AU-C1: gemischte Folge, für beide Entwürfe dieselbe, jede Fuge je Platte ±1,2 dB härter oder weicher, nie
  härter als 1 dB unter der härtesten von AU-C1; Abschnitt 15.10), `squeal` (2,0 s, 820 Hz), `scrub` (1,5 s),
  `rail_scrape` (2,0 s, 100 km/h, ^0,35)

– zusammen 3,00 MB (vorher 2,95 MB). Jeder Eintrag trägt `ref_kmh`, `pitch_exp` und `lufs_pitch` (die Lautheit der
Schleife, wie sie geschrieben ist, bei 14 Tonhöhen von 0,2 bis 3,36): Die Laufzeit rechnet ihre Pegel als Lautheit
dessen, was bei der gespielten Tonhöhe zu hören ist – je Seite mit der Kurve der eigenen Schleife.

**Klangfarbe wie AU-C1** (`match_loop`, `heard`): Ein anderer Seed und eine andere Länge verschieben bei den
Ereignis-Texturen (Pflaster, Schotter, Rüttelstreifen, Plattenmuster) die tiefen Terzen um 1–3,5 dB – wenige
Ereignisse je Band. Der Generator rechnet darum die Schleife von AU-C1 noch einmal (Seed und Länge von damals,
bitgleich nachgeprüft) und gleicht jede neue Schleife in 1/12-Oktav-Bändern an sie an: eine glatte
Verstärkungskurve über der Frequenz, höchstens 4 dB, kreisförmig über die ganze Schleife (die Naht bleibt nahtlos).
Feiner als in Terzen, damit die Terzen auch dann stimmen, wenn die Laufzeit beide Schleifen höher oder tiefer
spielt. Bezug ist, was von AU-C1 **zu hören war**: zwei Spieler auf ±`pan`, die dieselbe Schleife eine halbe Länge
versetzt lasen – in jedem Kanal addierten sich ihre Harmonischen abwechselnd gleich- und gegenphasig, bei einer
rhythmischen Textur ein Kamm in den Terzen (Pflaster 50 km/h: +1,0 dB bei 126 Hz, im Spiel gemessen). `heard()`
bildet das nach (Schleife + a × Schleife um eine halbe Länge verschoben, 2a / (1 + a²) = cos(pan · π/2)); der
Rüttelstreifen nicht, er klingt immer nur auf einer Seite. Gemessen in der Nachbildung bei den Bezugstempi (neue
Seiten unabhängig, rechts 2 % höher; Terzen 25 Hz–12,5 kHz bis 30 dB unter der lautesten, gleiche Lautheit):
höchstens 0,71 dB daneben (Pflaster bei 10 kHz), die meisten unter 0,5 dB; ohne Angleichung bis 3,5 dB.

`assets/audio/modern/sfx/` (`sfx_modern.py`, Mono, True Peak −3 dBTP): `joint_steel`, `joint_concrete` (je drei
Varianten mit Achsabständen 160 / 90 / 50 ms in `gaps_s`), `pass_post` (2), `pass_sign`, `pass_tree` (2),
`pass_building`, `pass_gantry`, `pass_rock` (alle bei 100 km/h), `hit_light` (2), `hit_heavy` (2), `crunch` (2,
4 ms Vorlauf), `glass` (4, 9 ms), `debris` (4, 40 ms), `truck_boom` (4), `rail_hit` (2), `rail_touch` (2),
`post_hit` (2) – zusammen 2,57 MB; `lufs_m` = Momentanlautheit je Variante. Seit AU-R: Glas, Kleinteile und
Lkw-Schlag haben je vier Varianten – die Datei von AU-C1 (a) und drei aus anderen Seeds desselben Generators, an die
Terzbalance von a angeglichen (`match_spectrum`, glatte nullphasige Korrektur, höchstens 4 dB je Band: Abweichung
danach höchstens 0,9 dB in den Bändern bis 30 dB unter dem lautesten); die Schichten eines Aufpralls tragen 20 ms
Stille vor (`jitter_lead_ms`), aus der die Laufzeit den zufälligen späteren Einsatz nimmt. Beide Generatoren sind
deterministisch (`audio_qc.py --determinism`).

Größe (Stand AU-R3, gemessen als Größe der Dateien im Repository ohne Manifeste und `.import`): die Schleifen von
`vehicle_loops.py` 3,00 MB, die Einmalklänge von `sfx_modern.py` 2,57 MB; alle Modern-Klänge außer Musik 18,9 MB
von 23 MB (bei AU-C1 17,9 MB).

### 15.3 Pegelplan

Der Vertrag will bei Höchsttempo den Wind 3 dB und die Reifen 4 dB unter dem Motor (Plan der Audio-Studie). Bezug
ist der **gemessene Motor allein bei Höchsttempo** je Auto (`road.engine_top_lufs`; `capture_mix.gd` mit
`--mute-bus=MRoad,MWind`, Abschnitt „Höchsttempo“): die Motoren erreichen dort die −16 LUFS des Plans nicht.

| | Kompakt | Kombi | Limousine | Sportwagen | Gran Turismo |
|---|---|---|---|---|---|
| Motor allein bei Höchsttempo (LUFS) | −18,5 | −17,2 | −17,7 | −17,8 | −17,5 |
| Wind / Reifen bei Höchsttempo (Ziel) | −21,5 / −22,5 | −20,2 / −21,2 | −20,7 / −21,7 | −20,8 / −21,8 | −20,5 / −21,5 |

Unter dem Höchsttempo folgen sie `slope_db` je Dekade (Reifen 30 dB, Wind 55 dB): bei 130 km/h liegen die Reifen
etwa 7–9 dB, der Wind etwa 12–16 dB unter dem Motor (abgeleitet aus den Gesetzen und dem gemessenen Motor allein bei
130 km/h, Kompakt −23,0 / Gran Turismo −22,0 LUFS; wie in der Studie). Beläge und Ereignisse sind auf die Reifen
bei Höchsttempo bezogen (`tyres.surface_db`, `slope_by_surface`, `wet_db`, `slabs.db`, `joints.lufs`, `passes.lufs`
…). Alle Ziele gelten am Master mit der Gesamtlautstärke 0,8 (`ref_path_db` −1,94 dB). Böen (Ornstein-Uhlenbeck,
±1,5 dB, in jedem Lauf gleich) sind so verschoben, dass sie die mittlere Leistung nicht anheben.

Gemessen mit dem Plan-Bezug (vor der Umstellung auf den gemessenen Motor), Gran Turismo: Reifen allein bei Höchsttempo
−19,98 LUFS (Ziel −20,0), Wind allein −18,99 (Ziel −19,0) – die Rechnung über `lufs_pitch` trifft im Spiel auf 0,1 dB.
Ganze Fahrt (`capture_mix.gd`, Motor + Fahrzeugebenen + Reifen + Wind):

| Abschnitt | Gran Turismo | Kompakt | Plan |
|---|---|---|---|
| Leerlauf | −23,9 | −24,2 | ≈ −24 |
| Vollgas durch die Gänge | −15,3 | −15,3 | −16 ± 1,5 |
| Höchsttempo | −14,4 | −14,6 | −16 |
| 130 km/h | −21,5 | −20,8 | ≈ −21 |

Die Zeile „Höchsttempo“ liegt über dem Plan: Wind −3 und Reifen −4 dB unter dem Motor heben die Summe um 2,8 dB
(abgeleitet). Mit dem gemessenen Motor als Bezug ist es etwa 0,5 dB weniger (abgeleitet). Plan D29 (−16) und die
Beziehung der Studie gelten bei Höchsttempo nicht zugleich, solange der Motor dort nicht leiser wird.

Probefahrt Kiel – Hamburg (Limousine, Spielmix ohne Musik und Verkehr) – Fahrbahn und Wind allein gegen den ganzen
Mix je Abschnitt: Autobahn 170 km/h −5,6 dB, Brücke −8,7 dB, Rüttelstreifen −6,4 dB, Bankett −3,4 dB, Leitplanke
−2,4 dB, Pflaster 50 km/h −4,6 dB. True Peak der Fahrt −3,7 dBTP, der Begrenzer greift nicht.

### 15.4 Aufprall: Pegel als Spitze

Einmalklänge des Aufpralls werden nach ihrer Spitze am Master eingestellt (`impact.*`: `peak_db` je Schicht bei der
Bezugsgeschwindigkeit der Stufe, ±`slope_db` je Dekade, höchstens `max_db`), weil ein Schlag mit 15–18 dB
Scheitelfaktor sonst den Begrenzer trifft, bevor er laut wirkt. Das Schleifen ist eine Schleife mit Lautheit
(`rail.scrape_lufs` bei 100 km/h, 12 dB je Dekade, höchstens `scrape_max_lufs` −17). Der Mischzustand `impact` senkt
Musik −5, Ambiente −3, Auto −3 und Welt −4 dB (0,25 s gehalten).

Gemessen (nur `MImpact` hörbar, Limousine mit 110 km/h, Abtastspitze des lauteren Kanals am Master, Einsätze im Ton
gesucht): Rempler 6 km/h −11,2 dBFS, Auffahren 30 km/h −7,8, schwerer Aufprall 70 / 130 km/h −3,8 / −2,8, Lkw
40 / 110 km/h −5,3 / −3,8; Leitplanke 0,5 / 2 / 5 m/s −15,5 / −8,2 / −4,5; Leitpfosten 90 km/h −11,2; Schleifen
−11,7 dBFS (−10,8 dBTP). Seitenrichtig: der leisere Kanal liegt 12,4 dB darunter (`pan` 0,7). Die Werte treffen
`peak_db` + Gesetz + Schwenk auf etwa 1 dB; wo mehrere Schichten zugleich einsetzen, liegt die Summe höher.

Seit AU-R (Werte oben von AU-C1): Jede Schicht kommt zufällig ±2 dB und 0–20 ms später, eine Variante zufällig.
Damit der Begrenzer einen schweren Aufprall um höchstens 3 dB drückt, liegt nur die lauteste Schicht der schweren
Stufe tiefer: der tiefe Schlag `hit_heavy` −11,5 statt −9,0 dB, gegen Lkw/Bus der Schlag des Aufbaus `truck` −11
statt −10 dB (gemessen in Abschnitt 15.9; Blech, Glas und Kleinteile unverändert). AU-R2 hat beides über je 60
Unfälle nachgemessen (Abschnitt 15.10): 95-%-Wert der Begrenzung gegen Pkw 2,14 dB, gegen Lkw 2,42 dB; der Lkw-Schlag
mit −10 dB käme auf 3,02 dB (4 von 60 Unfällen über 3 dB) – die Senkung bleibt. Seit AU-R4 liegt der Schlag des
Aufbaus wie der eigene tiefe Schlag bei −11,5 dB: Mit −11 lag der 95-%-Wert über 120 Unfälle bei 2,78 dB, und eine
Abnahme mit 60 neuen Unfällen wäre in etwa jedem siebten Fall allein durch den Zufall über 3 dB gekommen
(Abschnitt 15.12).

### 15.5 Der schlimmste Fall

Tunnel (Hall), zwei Lkw und ein Pkw dicht, Polizei mit Martinshorn, Rennmusik, Gran Turismo mit 230 km/h und
Untersteuern, schwerer Aufprall auf einen Lkw (140 km/h Schließgeschwindigkeit), harter Leitplankenschlag mit
Schleifen, zweiter Aufprall – am Master nach dem Begrenzer **−2,26 dBTP**, auf dem Endstand wiederholt **−2,44 dBTP**
(Plan ≤ −0,5; Standardregler; die Wiedergabe ohne Bildschirm ist nicht bildgenau gleich). Vor dem Begrenzer liegt die
Summe bis +4,1 dBFS über 0 dBFS: Das treiben die Platzhalter von Verkehr und Martinshorn (Arcade-Pegel, AU-C2) – auf
dem Endstand ohne `MWorld` 22 statt 4 087 Frames über der Begrenzerschwelle. Die Klänge von AU-C1 allein erreichen
vor dem Begrenzer 0,0 dBFS. Bei Gesamtlautstärke 1,0 läge der schlimmste Fall bei etwa −0,5 bis −0,1 dBTP
(abgeleitet: Begrenzer bei −0,8 dBFS vor der Lautstärke des Masters, gemessenes Überschwingen 0,3–0,7 dB).

AU-R, bei Gesamtlautstärke 1,0 gemessen: auf dem Stand von AU-C1 **−0,47 dBTP**, mit dem Begrenzer auf `MMaster`
**−1,59 dBTP** (Plan ≤ −1). Vor dem neuen Begrenzer liegt die Summe in dieser Szene fast durchgehend über −2 dBFS
(Spitze +6,0 dBFS; Martinshorn, Lkw und Musik im Tunnel bei Vollgas) – die Lautheit der Szene sinkt dadurch um
1,2 LU (−8,1 → −9,3 LUFS).

### 15.6 Rechenzeit

GDScript je Bild (Wiedergabe an, echte Strecke, Mittel / Maximum): Feed 0,06 / 3,0 ms, `road` 0,14 / 1,2 ms,
`impact` 0,01 / 0,7 ms (gemessen auf der belasteten Entwicklungsmaschine; die Maxima sind einzelne Bilder).
Auf Beton (km 42, AU-R2, je drei Läufe im Wechsel mit AU-C1 unter derselben Last): `road` im Mittel 0,27–0,34 ms,
95 % 0,29–0,38 ms (AU-C1 0,17–0,20 / 0,19–0,23 ms; AU-R mit der Sperre in jedem Bild 0,37–0,40 / 0,59–0,62 ms). Der
Rest gegenüber AU-C1 sind die eigenen Schleifen und die Pegeldrift je Seite (abgeleitet), nicht die Sperre: Die
Plattenschleifen sperren den Audioserver nur noch beim Start und alle 0,5 s (Abschnitt 15.10).

### 15.7 Fallen (gemessen, Godot 4.7.2)

1. **`AudioStreamPlayer` hat keine Panorama-Einstellung**; ein `AudioStreamPlayer2D` in einem eigenen
   `SubViewport` mit `AudioListener2D` hat sie (wie der Arcade-Verkehr), schwenkt aber linear: mittig je Kanal
   6 dB leiser als ein gewöhnlicher Player. `ModernAudioPan.apply()` rechnet das in ein Gesetz gleicher Leistung um.
2. **Weich begrenzte Schleifen überschwingen zwischen den Abtastwerten**: die Schleif-Schleife mit −3 dBFS
   Abtastspitze hatte −0,1 dBTP. Die Generatoren normieren darum auch auf den True Peak.
3. **Gleichanteil von Einmalklängen nicht abziehen**: der Abzug lässt im stillen Ende eine Stufe, die die
   Endblende zu einem tiefen Schlag macht (im Spektrogramm gesehen).
4. **Ein harter Begrenzer überschwingt** zwischen den Abtastwerten: 0,3–1,5 dB True Peak über seiner Schwelle
   (nach dem Begrenzer bei Aufprall-Spitzen, gemessen; er begrenzt Abtastwerte).
5. **Die `Track` erzeugt nur vorwärts**: Werkzeuge, die zurückspringen, bauen sie neu und geben sie mit
   `set_track` wieder an den Klang (wie eine neue Etappe).
6. **Zeitmarken einer Aufnahme mit dem Dummy-Treiber** liegen hinter dem Klang: anfangs etwa einen Block (93 ms),
   nach 30 s bis 0,4 s (die Uhr des Skripts und die aufgenommenen Frames laufen auseinander). Pegel je Ereignis darum
   an den Einsätzen im Ton messen, nicht an den Marken.
7. **Zwei Schleifen im Gleichschritt addieren sich nicht wie Rauschen** (AU-R2): Schläge, die auf denselben
   Zeitpunkt fallen und ihre Schwingungen bei Phase 0 beginnen, addieren sich teilweise kohärent – die Klangfarbe des
   Paares hängt dann davon ab, welcher Schlag auf welchen trifft (Betonplatten bei 130 km/h: bis ±2,5 dB in
   200–1000 Hz). Wer ein Paar im Gleichschritt angleicht, muss das Paar angleichen, nicht jede Schleife allein.
8. **`AudioEffectHardLimiter` gibt nicht ganz frei** (AU-R2, gemessen): Nachdem er einmal begrenzt hat, bleiben
   0,05–0,14 dB Absenkung stehen, auch wenn das Signal danach 8 dB unter der Obergrenze liegt – bis zum Ende der
   Aufnahme. Unhörbar; wer die Begrenzung als Verhältnis vor/nach dem Begrenzer misst, sieht danach dauerhaft
   „Begrenzung > 0,1 dB“ und darf das nicht als Eingriffe zählen.

### 15.8 Offene Punkte

- **Hören**: alle Ebenen; Prüfpunkte im Bericht von AU-C1. Die Pegel stehen in `audio.modern.feed`, `.road`,
  `.impact`; die Klangfarbe in den beiden Generatoren.
- **Bezug neu messen**, wenn sich die Motoren ändern (AU-E): `road.engine_top_lufs` ist gemessen, nicht gerechnet.
- **Verkehr und Martinshorn** (Platzhalter, AU-C2) treiben im schlimmsten Fall den Begrenzer um 4 dB.
- **Höchsttempo-Zeile des Plans** (siehe 15.3; seit AU-R im Plan: −15 ± 1 LUFS).
- **Betonplatten bei 200 km/h**: Seit AU-R2 steigt der Plattenpegel über 150 km/h nur noch um 4 dB je Dekade
  (`slabs.high_kmh`, `slabs.high_slope_db`; bei 200 km/h 2,0 dB unter AU-R). Der Begrenzer nimmt beim Reisen mit
  200 km/h auf Beton in vier Läufen höchstens 0,44 / 0,43 / 0,08 / 0,08 dB (Abschnitt 15.10) – zwei Läufe knapp unter
  0,5 dB: Die Spitzen sind die Summe aller Schichten (Motor, Reifen, Wind, Platten) und schwanken von Lauf zu Lauf um
  etwa ±0,5 dB. Kriterium seit dem Leitungsentscheid V3 (Abschnitt 15.11): höchste Begrenzung je 60-s-Lauf ≤ 0,5 dB
  in jedem von mindestens vier Läufen – erfüllt. `slabs.db` bleibt 3 (V1).
- **Beton je Land** (AU-R gemessen, Schwelle je Land `concrete_threshold`): Beurteilt werden seit dem Leitungsentscheid
  V2 nur Länder mit mindestens 10 Autobahnabschnitten über alle Etappen – alle 13 liegen im Anteil ±0,05. Kroatien
  (8 Abschnitte, 0,141), Slowenien (5, 0,19), Litauen (3, 0), Bulgarien und Lettland (je 1, 0) werden genannt, nicht
  beurteilt: ihr nächster möglicher Anteil ist 0 oder mindestens 0,19. Kommen Etappen dazu oder ändert sich ein
  Anteil, die Schwellen mit `calibrate_concrete.gd` neu rechnen (ein Test meldet einen geänderten Anteil).
- **Wiederholung auf Beton** (entschieden, V1): Der Takt der Platten ist gewollt (eine Fuge alle 5 m) und Teil des
  Klangs, den der Nutzer gehört und gut gefunden hat; Beton wird darum **ohne die Plattenschicht** beurteilt. AU-R2
  gemessen (130 km/h, 2,5–8 kHz): ohne Platten 0,196 – hält; mit den Platten bei `slabs.db` 3 0,687 (bei 0 dB 0,518,
  bei −3 dB 0,369; Abschnitt 15.10). `slabs.db` bleibt 3: ihn zu senken ist eine Mischentscheidung nach der
  Testversion, kein Fehler.
- **Steinbrücken und Tunnel in Altstädten**: erledigt mit AU-R4 (Abschnitt 15.12) – die Steinbrücke zählt als schon
  gepflasterte Straße, der Anteil gilt wie gehört; ein Tunnel der Etappe ändert die Blöcke der Stadt nur, wenn er den
  Anteil dieser Ankunft aus dem Band schiebt (auf keiner Etappe der Fall: Hamburg aus Hannover 0,617, Paris aus
  Lüttich 0,644). Offen ist die Lesart des Kriteriums im Vertrag (§11.2): Auf den Straßen allein, ohne die
  Steinbrücke, kann keine Wahl der Blöcke Dresden, Tours, Saragossa und Toulouse zugleich mit „wie gehört“ ins Band
  bringen (alle Teilmengen der Blöcke durchgerechnet).
- **Rand der Tankspur** (KRITIK-R2-CODE L1, offen): Ein rechtes Rad bis 0,5 m außerhalb der Randlinie der Tankspur
  hört den Belag statt Schotter (`wheel_surface` mit `plain_edge`); selten befahren.
- **Radstand** aus der Länge des Autos (0,6 ×, keine Daten); die Betonplatten-Schleifen sind für 2,7 m entworfen
  (Kompakt 2,46 m: Abstand der Achsschläge 9 % zu lang, abgeleitet).
- **Einschnitt** ist eine Regel aus Felsen am Rand (die Daten kennen keine Einschnitte); AU-C2 kann sie verfeinern.
- **`capture_mix.gd`** sendet keinen Fahrzeugzustand: Seine Fahrt rollt ohne Feed auf trockenem Asphalt.

### 15.9 AU-R: gemessene Fehler behoben (vorher → nachher)

KRITIK-FAHRBAHN hatte am Klang von AU-C1 Fehler gemessen; der Nutzer fand den Klang auf Kopfhörern solide. AU-R
behebt darum nur die gemessenen Fehler und hält die Klangfarbe. „Vorher“ ist der Stand von AU-C1 (`4209268`), mit
denselben Skripten aufgenommen; alle Zahlen gemessen (Godot 4.7.2, ohne Bildschirm, Dummy-Treiber, Limousine,
Kiel – Hamburg), sofern nicht „abgeleitet“ dasteht.

**Wiederholung (R1).** Spielmix (Motor + Fahrbahn + Wind), 20 s bei festem Tempo; Hüllkurve aus 10-ms-RMS der
Monosumme im Band, Autokorrelation ohne Mittelwert; Grenzwert: keine Spitze ≥ 0,40 bei 0,3–3 s.

| Aufnahme | Band | vorher (Spitzen 0,3–3 s) | nachher (Spitzen 0,3–3 s) | nachher, Spitzen 3–8 s |
|---|---|---|---|---|
| Asphalt 130 km/h | 0,6–1,6 kHz | 0,603 bei 0,97 s, 0,572 bei 2,92, 0,452 bei 1,94 | 0,111 bei 0,39 s, 0,049 bei 0,90 | 0,177 bei 6,39 s, 0,118 bei 5,15 (die beiden Schleifen) |
| Beton 130 km/h | 2,5–8 kHz | 0,887 bei 0,97 s, 0,806 bei 1,94, 0,716 bei 2,77 | 0,647 bei 1,80 s, 0,616 bei 0,83, 0,594 bei 2,63 | 0,635 bei 3,60 s, 0,600 bei 4,43 |
| Beton 130 km/h ohne Plattenschicht¹ | 2,5–8 kHz | – | 0,113 bei 1,87 s | 0,125 bei 3,09 s |
| Pflaster 50 km/h | 2,5–8 kHz | 0,982 bei 2,50 s, 0,981 bei 1,25 | 0,146 bei 0,57 s | 0,471 bei 6,96 s, 0,401 bei 5,70 |
| Pflaster 50 km/h | 0,6–1,6 kHz | 0,701 bei 1,25 s, 0,693 bei 2,50 | 0,104 bei 1,51 s | 0,255 bei 6,96 s |

¹ aufgenommen mit dem Zwischenstand der Schleifen vor der Angleichung der Klangfarbe (die Angleichung ist ein festes
Filter und ändert die Hüllkurve kaum).

Asphalt und Pflaster halten den Grenzwert; die Spitzen jenseits von 3 s sind die Längen der beiden Schleifen. Auf
Beton bleibt der **Takt der Platten** (eine Fuge alle 5 m: 0,83 s = 6 Platten bei 130 km/h, 1,80 s = 13): ohne die
Plattenschicht liegt Beton bei 0,11. Die Platten bleiben, wie sie sind (`slabs.db` 3, Vorgabe) – der Grenzwert passt
nicht zu einem gewollten Takt; seit dem Leitungsentscheid V1 wird Beton ohne die Plattenschicht beurteilt
(Abschnitt 15.11).

**Hash (R2).** Über alle sichtbaren Etappen, jeder Abschnitt und jede Altstadt einmal:

| | AU-C1 (djb2) | nur fmix32 | AU-R |
|---|---|---|---|
| Pflaster gesamt (Soll 0,6) | 0,623 | 0,609 | 0,566 |
| Altstädte ganz / gar nicht gepflastert | 29 / 18 von 47 | 0 / 0 | 0 / 0 |
| Altstädte im Anteil ±0,05 | 0 | 11 (0,34–0,90) | 47 (0,55–0,64) |
| Beton gesamt (Soll 0,207) | 0,244 | 0,166 | 0,205 |
| Länder im Anteil ±0,05 | 5 von 18 | 8 | 14 |

Beton je Land, AU-R: DE 0,349 (Soll 0,35), FR 0,104, ES 0,085, PL 0,238 (0,25), RS 0,060, HU 0,125, RO 0,094,
CZ 0,418 (0,40), BE 0,296 (0,30), CH 0,096, IT 0,075, NL 0,103, AT 0,155 (0,15), HR 0,141; daneben SI 0,190 (5
Abschnitte), LT 0 (3), BG 0 (1), LV 0 (1). Hamburg (800 m Altstadt, vom Ziel aus): `P--PP-P-P`.

**Plattentakt (R3).** Fahrt 100 → 160 → 95 → 140 km/h, 141 s, beide Muster zugleich hörbar in 660 Proben: größter
Abstand 4,5 ms, kein Nachstellen nötig (Schwelle 6 ms; Godot meldet die Abspielposition in Schritten von 64 Frames).
`slabs.db` 3 unverändert; Wind im Tunnel 0 dB statt −3.

**Brückenfugen (R4).** Autopilot über die ganze Etappe, Ereignisse des Feeds gezählt:

| Brücke | Deck, Länge | vorher | nachher (Lage ab Brückenanfang) |
|---|---|---|---|
| Köhlbrandbrücke (Kiel – Hamburg) | Stahl, 261 m | 12 (alle 24 m) | 4 (0, 100, 200, 261 m) |
| Elbbrücken (Kiel – Hamburg) | Stahl, 201 m | 9 | 3 (0, 100, 201 m) |
| Damm nach Venedig (Mailand – Venedig) | Beton, 378 m | 17 | 13 (alle 32 m) |
| Steinbogen vor Paris (Lüttich – Paris) | Stein, 129 m | 6 | 0 |

Rüttellinie rechts neben der Tankspur (Kiel – Hamburg, km 13,8): vorher 5 Bilder, nachher 0.

**Begrenzer (R5)**, True Peak des Masters bei Gesamtlautstärke 1,0 (4-fach überabgetastet), Begrenzung = Spitze vor
dem Begrenzer − Obergrenze:

| Szene | vorher | nachher | Begrenzung nachher |
|---|---|---|---|
| schwerer Aufprall, 130 km/h Schließgeschwindigkeit (Pkw, 24 Unfälle) | −0,62 dBTP | −1,71 dBTP | höchstens 2,4 dB, Median 0,2 |
| dasselbe gegen einen Lkw (16 Unfälle) | −0,63 | −1,66 | höchstens 2,1 dB |
| Höchsttempo, Motor + Fahrbahn + Wind (Asphalt) | −2,77 | −2,93 | 0 |
| schlimmster Fall von AU-C1 (15.5) | −0,47 | −1,59 | bis 8 dB (die Szene liegt fast durchgehend darüber) |
| Reisen 130 (Asphalt, Beton), 170 (Beton), 200 (Asphalt) | – | – | 0 |
| Reisen 200 km/h auf Beton, eine Minute (56 s Ton) | – | – | 11 Eingriffe, höchstens 1,0 dB, 2,4 % der Zeit (Pegel von AU-C1: 15 in 57 s, 1,5 dB, 3,5 %) |

Mit `hit_heavy` −9 (wie AU-C1) nahm der Begrenzer bei schweren Unfällen bis 4,0 dB, mit −10,5 noch 3,7, mit −11,0
3,4 und mit −11,5 höchstens 2,4 dB (dieselben 24 Zufallsfolgen): Die zufälligen Versätze der Schichten (±2 dB,
0–20 ms) treffen manchmal genauer zusammen als die feste Anordnung. Das Höchsttempo liegt bei −14,9 LUFS
(Gesamtlautstärke 0,8; Plan −15 ± 1, Test `test_top_speed_row_of_the_plan`).

**Abwechslung (R6).** Varianten gegen die Datei von AU-C1 (Terzen bis 30 dB unter der lautesten, bei gleicher
Spitze): Glas 0,20 / 0,84 / 0,31 dB, Kleinteile 0,89 / 0,91 / 0,76, Lkw-Schlag 0,42 / 0,32 / 0,62; Variante a ist
nach den 20 ms Vorlauf die alte Datei. Zufällig ohne direkte Wiederholung, jede Schicht ±2 dB und 0–20 ms (auch die
Vorbeifahrten: ±2 dB, Variante zufällig); Glas ab 80 km/h Schließgeschwindigkeit, darunter in 40 %; Quietschen
±5 % je Ereignis; Schnee mit eigener Schleife.

**Klangfarbe.** Im Spiel aufgenommen, ohne Zufall (Drift, Böen und Vorbeifahrten aus), 20 s, Gesamtlautstärke 1,0;
Terzen 25 Hz–12,5 kHz bis 30 dB unter der lautesten:

| Aufnahme | Lautheit vorher → nachher | größte Terz-Abweichung |
|---|---|---|
| Asphalt 130 km/h, nur Fahrbahn | −27,80 → −27,64 LUFS (+0,16 LU) | 0,49 dB bei 251 Hz |
| Beton 130 km/h, nur Fahrbahn | −22,38 → −22,34 (+0,04) | 0,97 dB bei 398 Hz |
| Pflaster 50 km/h, nur Fahrbahn | −20,98 → −21,20 (−0,22) | 0,74 dB bei 40 Hz |
| Wind 130 km/h, nur Wind | −34,77 → −34,75 (+0,03) | 0,38 dB bei 32 Hz |
| Spielmix Asphalt 130 | −14,91 → −14,99 (−0,08) | 0,39 dB |
| Spielmix Beton 130 | −14,85 → −15,11 (−0,27) | 0,68 dB |
| Spielmix Pflaster 50 | −17,09 → −16,93 (+0,15) | 0,50 dB |

Vor der Angleichung an den gehörten Klang lag Pflaster bei 1,00 dB (126 Hz) und der Spielmix Pflaster bei 1,05 dB:
Der Kamm der zwei versetzten Spieler von AU-C1 fehlte (Abschnitt 15.2).

### 15.10 AU-R2: Nachbesserung nach der Nachmessung (vorher → nachher)

Eine unabhängige Nachmessung (KRITIK-R) fand am Stand von AU-R zwei hohe und fünf mittlere Befunde. AU-R2 behebt
sie, hält den Klang von AU-C1 und misst jeden Befund mit den Skripten der Nachmessung nach: „AU-C1“ = vorher, mit
denselben Skripten aufgenommen; „AU-R“ = die Zahl der Nachmessung; alles gemessen (Godot 4.7.2, ohne Bildschirm,
Dummy-Treiber, Limousine, Kiel – Hamburg, Gesamtlautstärke 1,0, belastete Maschine), sofern nicht „abgeleitet“
dasteht. Gehört hat es niemand.

**Plattenschicht in der Klangfarbe (H1).** Ursache war nicht die Angleichung der einzelnen Entwürfe – jeder lag
allein innerhalb 0,8 dB von AU-C1 –, sondern das Spielen im Gleichschritt (Abschnitt 15.7, Falle 7): Zwischen 110
und 150 km/h klingen beide Entwürfe zugleich, ihre Schläge fallen auf dieselben Zeitpunkte, und welche Fuge des
einen auf welche des anderen trifft, formte 200–1000 Hz um. Ein Modell der Schicht aus den Dateien (Tonhöhen,
Überblendung und Pegel wie `road_audio.gd`) trifft die Messung der Nachmessung (+1,72 statt +1,75 dB bei 398 Hz).
Von 64 Paaren neuer Zufallsmuster lag keines bei 120–140 km/h innerhalb 1 dB. Seit AU-R2 bestehen die
32 Platten jedes Entwurfs aus den 8 Fugen des Entwurfs von AU-C1 (Abschnitt 15.2), für beide Entwürfe in derselben
Folge – Fuge j des langsamen trifft wie bei AU-C1 auf Fuge j des schnellen. Modell: 90–230 km/h, das Paar bei
120–140 km/h eingeschlossen, höchstens 0,43 dB je Terz und 0,14 LU neben AU-C1.

| Aufnahme (130 km/h, ohne Zufall) | AU-R | AU-R2 |
|---|---|---|
| nur Platten | +1,75 dB bei 398 Hz (+0,06 LU) | +0,55 dB bei 631 Hz (+0,13 LU) |
| Beton, nur Fahrbahn (Reifen + Platten) | +1,09 dB bei 398 Hz (+0,04 LU) | +0,32 dB bei 398 Hz (+0,07 LU) |
| Spielmix Beton | +0,78 dB (−0,04 LU) | +0,52 dB bei 25 Hz (+0,03 LU) |

**Wiederholung auf Beton (H2; seit V1 entschieden: ohne Plattenschicht beurteilt, hält – Abschnitt 15.11).**
130 km/h, Spielmix, 2,5–8 kHz, größte Spitze 0,3–3 s:
AU-C1 0,889 (0,97 s), AU-R 0,642 (1,80 s), AU-R2 0,687 (1,80 s; 3–8 s: 0,704 bei 7,20 s, 0,696 bei 3,60 s). Alle
Spitzen liegen auf Vielfachen der Plattenzeit – der Takt, keine Schleife. Ohne Plattenschicht 0,196 (0,48 s); mit
`slabs.db` 0 statt 3: 0,518, mit −3: 0,369 – mit dem Pegel, den die Nachmessungen für die nächste Runde vorschlagen,
hält Beton den Grenzwert. Der Pegel bleibt in dieser Runde (Vorgabe).

**Sperre des Audioservers (M1).** `_update_slabs()` sperrt nur noch, wenn eine Plattenschleife startet, und für den
Abgleich alle 0,5 s (Test `test_slab_loops_lock_the_mixer_only_to_start`). Rechenzeit `road` auf Beton: Abschnitt
15.6.

**Begrenzer beim Reisen auf Beton (M3).** Über 150 km/h steigt der Plattenpegel nur noch um 4 dB je Dekade (bis
150 km/h unverändert; 170 km/h −0,9 dB, 200 km/h −2,0 dB gegen AU-R). Begrenzung bei 200 km/h, je Lauf 57 s:

| Stand | Läufe (höchste Begrenzung) | Spitze vor dem Begrenzer |
|---|---|---|
| AU-R (Nachmessung / AU-R selbst) | 0,44 / 0,96 dB | −1,56 / −1,04 dBFS |
| neue Muster mit dem Pegel von AU-R | 1,50 / 1,32 dB | −0,50 / −0,68 dBFS |
| 8 dB je Dekade (−1,5 dB) | 0,65 / 0,30 / 0,10 / 0,00 dB | −1,35 … −2,15 dBFS |
| **4 dB je Dekade (−2,0 dB, Stand)** | **0,44 / 0,43 / 0,08 / 0,08 dB** | −1,56 / −1,57 / −2,11 / −2,58 dBFS |

Die 0,08 dB der Läufe 3 und 4 sind der Rest des vorigen Laufs (Falle 8), die Spitzen dort liegen unter der
Obergrenze. Bei 170 km/h 0 dB (True Peak −2,4 dBTP). Die Spitzen sind die Summe aller Schichten und schwanken von
Lauf zu Lauf um etwa ±0,5 dB (Abschnitt 15.8).

**Aufprall (M2, M4).** Je 60 schwere Unfälle mit 130 km/h Schließgeschwindigkeit (eigene Zufallsfolgen):

| Partner, Pegel | Begrenzung Median / 95 % / höchstens | Unfälle über 3 dB | True Peak höchstens |
|---|---|---|---|
| Pkw, `hit_heavy` −11,5 (Stand) | 0,27 / 2,14 / 4,05 dB | 1 von 60 | −1,32 dBTP |
| Lkw, `truck.heavy` −11 (Stand) | 0,69 / 2,42 / 3,25 dB | 1 von 60 | −1,63 dBTP |
| Lkw, `truck.heavy` −10 (AU-C1) | 1,24 / 3,02 / 3,41 dB | 4 von 60 | −1,58 dBTP |

Als 95-%-Wert über 60 Unfälle gelesen (Vorschlag der Nachmessung) hält der Stand die 3 dB; mit dem Lkw-Pegel von AU-C1
läge er knapp darüber – die Senkung um 1 dB bleibt. Das Maximum einzelner Unfälle wächst mit ihrer Zahl
(Vertragsfrage: Kriterium als Perzentil über eine feste Zahl).

**Pflaster (M5).** Die rechte Schleife (Seed + 50) hatte zwei Schläge, bei denen alle vier Räder binnen 1–3 ms
zusammentrafen – ihre lautesten Spitzen lagen 2 dB über allem in AU-C1 und kamen alle 7 s wieder. Seit AU-R2 Seed + 64
(von 40 geprüften Seeds der mit den niedrigsten Spitzen), angeglichen für die Tonhöhe, mit der die rechte Seite spielt
(`match_loop(…, pitch)`: der steile Anstieg des Karosserie-Grollens unter 48 Hz nahm sonst 0,5 dB aus der 40-Hz-Terz).
Ohne Zufall, 50 km/h, nur Fahrbahn, je Kanal:

| | AU-C1 | AU-R | AU-R2 |
|---|---|---|---|
| True Peak der Schicht | −9,02 dBTP | −6,34 dBTP | −8,59 dBTP |
| lautester Stein gegen AU-C1, links / rechts | – | +1,6 / +3,0 dB | +0,12 / +0,21 dB |
| Scheitelfaktor links / rechts | 13,56 / 13,58 dB | 15,2 / 16,6 dB | 13,87 / 13,94 dB |
| Klangfarbe nur Fahrbahn / Spielmix | – | −0,77 / −1,02 dB bei 40 Hz | −0,56 dB bei 25 Hz / −0,44 dB bei 40 Hz |

Wie gespielt (mit Pegeldrift) wiederholt sich jede Seite weiter mit ihrer Länge: nur Fahrbahn 0,485 bei 5,70 s und
0,247 bei 6,96 s (AU-R 0,478 / 0,339) – außerhalb des Fensters 0,3–3 s, dort höchstens 0,121.

### 15.11 AU-R3: kein Altstadtpflaster auf Brücken ohne Steindeck; Abnahmekriterien

KRITIK-R (L2) hatte im Triggerlog gemessen: Seit dem gemischten Hash lag auf dem Damm nach Venedig (Ponte della
Libertà, Betondeck, 378 m in der Altstadtzone von Mailand – Venedig) auf 16 von 28 Zeilen Pflaster, dazu Betonfugen
alle 32 m – in Wirklichkeit ist er Asphalt. AU-R3 ändert nur `audio_feed.gd` (und die Beschreibung von `cobble_share`
in der Konfiguration): keine Klangdatei, kein Pegel, keine Musik. Alle Zahlen gemessen (Godot 4.7.2, ohne Bildschirm); „vorher“ ist der Feed von AU-R2 (`3600eb7`), im selben
Lauf als Kopie mitgefahren.

**Regel.** Altstadtpflaster liegt nie auf einer Brücke ohne Steindeck: Ein Betondeck in der Stadt hat den Belag wie
vor AU-R (Asphalt), ein Stahldeck bleibt `deck`, eine Steinbrücke Pflaster; die Fugen je Deck bleiben, wie sie sind
(Damm: 13 – alle 32 m und an beiden Enden). Diese Brücken sind keine Straße der Altstadt: `cobbled_blocks` teilt den
Anteil über die Straßenmeter zu (Abschnitt 8), bei jeder Ankunft in einer Stadt dieselben Blöcke.

**Alle 64 sichtbaren Etappen in beiden Richtungen** (beide Feeds selbst, in 1-m-Schritten durch jede Altstadt, über
die Brücken der echten `Track`): 34 Brücken ohne Steindeck liegen in 30 Altstädten. Auf 16 von ihnen lag vorher
Pflaster (der Damm 211 von 378 m, die Kirchenfeldbrücke in Bern 111 m, der Pont Lafayette in Lyon 111 m, die
Warthebrücke in Posen 90 m, die Eiserne Brücke in Regensburg 89 m, vier Grachtenbrücken in Amsterdam 121 m …; dazu
je 1 m am Brückenende in Linz und Nürnberg bei einer Ankunft), nachher auf keiner; die Stahlbrücken (Belgrad,
Budapest, Riga, Köln) bleiben `deck`; die Fugen sind auf jeder Brücke dieselben. 18 Altstädte klingen anders, alle
mit einer solchen Brücke – 13 mit anderen Pflasterblöcken, 5 nur auf der Brücke; jede andere ist bitgleich.
Pflasteranteil der Straßen (Altstadt ohne Brücken und Tunnel), vorher → nachher:

| Altstadt | vorher → nachher | Altstadt | vorher → nachher | Altstadt | vorher → nachher |
|---|---|---|---|---|---|
| Amsterdam | 0,532 → 0,603 | Kaunas | 0,653 → 0,582 | Posen | 0,510 → 0,623 |
| Bern | 0,479 → 0,608 | Linz | 0,654 → 0,598 | Regensburg | 0,526 → 0,618 |
| Bremen | 0,575 → 0,575 | Lyon | 0,532 → 0,677 ¹ | Riga | 0,554 → 0,602 |
| Brüssel | 0,569 → 0,569 | Montpellier | 0,526 → 0,646 | Timişoara | 0,535 → 0,601 |
| Budapest | 0,572 → 0,602 | Nürnberg | 0,589 → 0,589 | Venedig | 0,645 → 0,642 ² |
| Bukarest | 0,627 → 0,627 | Passau | 0,563 → 0,632 | Wien | 0,632 → 0,632 |

¹ Lyon hat dazu eine Steinbrücke (Pont Bonaparte, 69 m): Als Straße gezählt wie in der Zuteilung 0,61; sie klingt
aber immer nach Pflaster – offen, Abschnitt 15.8. ² In Venedig endet die Straße hinter dem Damm am Piazzale Roma:
282 m Straße, davon 180 m gepflastert (dieselben Blöcke wie vorher). Mit der Zuteilung in Hashfolge allein lagen
Amsterdam, Regensburg, Timişoara, Kaunas und Linz bei 0,65–0,66 (halber Block einer kürzeren Basis); `COBBLE_BAND`
rückt nur sie nach.

**Kiel – Hamburg** ist unverändert: Hamburgs Brücken liegen 11 und 17 km vor dem Ziel, außerhalb der 8 km Altstadt.
Feed von AU-R2 und AU-R3 über die ganze Etappe in 1-m-Schritten: 0 von 9 500 Zuständen und Ereignissen verschieden;
der Triggerlog mit Autopilot vorher und nachher: dieselben 329 Ereignisse, 316 Zeilen in denselben Belägen, dasselbe
`ERGEBNIS`. Die Hörproben von AU-R/AU-R2 gelten weiter. Mailand – Venedig: 212 m werden von Pflaster zu Asphalt, alle
auf dem Damm (1 m am Planbeginn des Damms, den die `Track` auf das nächste 3-m-Segment rundet); im Triggerlog liegen
auf dem Damm 28 von 28 Zeilen auf Asphalt (vorher 13), die Fugen und alles Übrige sind gleich.

**Abnahmekriterien des Modern-Klangs** (Leitungsentscheide V1–V3, Vertrag §11.2; Stand nach AU-R3; die Zahlen der
Klangschichten stammen aus AU-R2 und gelten weiter, weil AU-R3 keine Schicht ändert):

| Kriterium | Grenze | Stand (gemessen) |
|---|---|---|
| keine exakte Wiederholung (R1, V1) | keine Spitze der Hüllkurven-Autokorrelation ≥ 0,40 bei 0,3–3 s, 20 s bei festem Tempo: Asphalt 130 km/h 0,6–1,6 kHz, Pflaster 50 km/h 2,5–8 kHz, Beton 130 km/h 2,5–8 kHz **ohne die Plattenschicht** (der 5-m-Takt ist gewollt; `slabs.db` bleibt 3 – ihn zu senken ist eine Mischentscheidung nach der Testversion, kein Fehler) | Asphalt 0,151, Pflaster 0,128, Beton ohne Platten 0,196 |
| Betonanteil je Land (V2) | ±0,05 des eingestellten Anteils, beurteilt nur für Länder mit mindestens 10 Autobahnabschnitten über alle Etappen; kleinere werden genannt | 13 von 13 im Band; genannt: HR 0,141 (8 Abschnitte), SI 0,19 (5), LT 0 (3), BG 0 (1), LV 0 (1) |
| Begrenzer beim schweren Aufprall (V3) | 130 km/h Schließgeschwindigkeit, 60 Unfälle: 95-%-Wert der Begrenzung ≤ 3 dB (Pkw und Lkw), jeder Unfall ≤ −1,0 dBTP bei Gesamtlautstärke 1,0 | Pkw 2,14 dB (AU-R2; KRITIK-R2-MESS 2,05 dB); Lkw seit AU-R4 mit `truck.heavy` −11,5: 2,13 / 2,51 dB in zwei Folgen, 2,34 dB über 120 Unfälle (mit −11: 2,78 / 2,72 dB, über 120 Unfälle 2,78 dB); höchstens −1,39 dBTP |
| Begrenzer beim Reisen (V3) | 130–200 km/h: größte Begrenzung je 60-s-Lauf ≤ 0,5 dB in jedem von mindestens vier Läufen; die 0,05–0,14 dB, die `AudioEffectHardLimiter` nach einem Eingriff stehen lässt (Falle 8), sind kein Eingriff | 200 km/h auf Beton (der schärfste Fall), vier Läufe à 57 s: 0,44 / 0,43 / 0,08 / 0,08 dB; 130 und 170 km/h in kürzeren Läufen 0 dB |
| Charakter halten | eine geänderte Schicht hält ihr Terzspektrum ±1 dB und ihre Lautheit ±0,5 LU von AU-C1 bei den Bezugstempi (130 km/h Asphalt und Beton, 50 km/h Pflaster) | höchstens 0,56 dB und 0,17 LU (AU-R2); AU-R3 ändert keine Schicht |
| Musik | keine Änderung | AU-R3 ändert keine Musikdatei und keinen Musikpegel |
| Altstadtpflaster (AU-R3, AU-R4) | kein Altstadtpflaster auf Brücken ohne Steindeck; jede Altstadt 0,6 ± 0,05 **wie gehört**: gepflasterte Straße und Steinbrücken über Straße und Steinbrücken (Straße = Altstadt ohne Brücken und Tunnel; Lesart von AU-R4, Vertragsfrage §11.2) | Brücken: erfüllt (alle Etappen, beide Richtungen). Anteil (AU-R4, Abschnitt 15.12): alle 100 Ankünfte in Altstädten mit Pflaster im Band, zugeteilt 0,550–0,645; im 1-m-Raster der Prüfung liegen Barcelona (ohne Brücke, seit AU-R) und Ljubljana bei 0,549 – zugeteilt genau 0,550 |

### 15.12 AU-R4: Tests als Wächter, Altstadtpflaster wie gehört, Lkw-Aufprall (vorher → nachher)

Zwei unabhängige Abnahmen des Stands AU-R3 (KRITIK-R2-CODE: Code, Auslösung, Regressionen; KRITIK-R2-MESS: Messung)
fanden keinen Blocker – aber vier Regeln, die kein Test schützte (hoch), den Altstadtanteil in Altstädten mit
Steinbrücke oder Tunnel, den Zufall der Vorbeifahrten ohne Test und die knappe Marge von V3 beim Lkw (mittel). AU-R4
ändert `audio_feed.gd` (Zuteilung des Altstadtpflasters), die Tests, die Doku und einen Pegel (`truck.heavy`); keine
Klangdatei, keine Musik. Jeder Befund ist mit dem Werkzeug seines Prüfers nachgestellt; alles gemessen (Godot 4.7.2,
ohne Bildschirm, Dummy-Treiber), gehört hat es niemand.

**Tests (KRITIK-R2-CODE H1–H4, M2, L3).** Verfahren der Prüfung: eine Zeile des Codes brechen, die zuständige
Testdatei laufen lassen – sie muss rot werden.

| Regel | Mutation | vorher | nachher | Test (`test_road_audio.gd`) |
|---|---|---|---|---|
| Quietschen: Tonhöhe je Ereignis, nicht je Bild | M01 | grün | rot – 348 Tonhöhenwechsel in 612 hörbaren Bildern (ohne Bruch 0) | `test_squeal_pitch_per_event` |
| Aufprall-Varianten zufällig statt reihum | M03 | grün | rot – auf jede Variante folgt genau eine | `test_collision_variety` |
| Plattenmuster: der leisere wird nachgestellt | M11 | grün | rot | `test_slab_loops_are_put_back_in_step` (neu) |
| Plattenmuster: erst über `align_ms` | M12 | grün | rot – 0-mal nachgestellt, 30 ms Versatz | dito |
| Pegel je Schicht ±2 dB / überhaupt zufällig / späterer Einsatz | M14 / M15 / M16 | grün | rot | `test_collision_layers_vary_in_level_and_onset` (neu) |
| Vorbeifahrt ±2 dB / Variante zufällig | M17 / M18 | grün | rot | `test_pass_by_variants_and_levels_at_random` (neu) |
| Fahrtwind im Tunnel 0 dB / Glas genau ab 80 km/h | M31 / M32 | grün | rot | `test_wind_zones_gusts_and_fades`, `test_collision_variety` |

Ohne Bruch messen die neuen Tests (gemessen): Plattenmuster bei 120 km/h mit 5·10⁻⁴ Drift in 60 s 4-mal nachgestellt,
jedes Mal bei 6,2 ms (Schwelle 6 ms), danach 0,00 ms, das lautere läuft ungestört; 240 Aufprallschichten: Pegel
−2,00 … +2,00 dB, Streuung 1,13 dB (gleich verteilt 1,15), Einsatz in 100 % später, im Mittel 10,4 ms, höchstens
20,0 ms; 60 Vorbeifahrten: −1,92 … +1,98 dB, beide Varianten des Pfostens, 35 Wiederholungen (zwei Varianten:
zufällig, nicht im Wechsel); 12 Quietscher, 12 verschiedene Tonhöhen, 0 Wechsel während eines Quietschens.
Endstand: 40 von 40 Mutationen rot – die 32 der Prüfung (M22–M24 an den neuen Zeilen der Zuteilung) und 8 neue für
die Zuteilung des Pflasters (Steinbrücke, Tunnel, Nachrücken für jede Altstadt, Weitergabe aus dem Plan).

**Altstadtpflaster (KRITIK-R2-CODE M1).** Die Zuteilung zählte Steinbrücken und Tunnel als freie Straße; der Feed
spielt dort aber immer Pflaster bzw. Asphalt. Seit AU-R4 gilt der Anteil **wie gehört**: Straße = Altstadt ohne
Brücken und Tunnel; eine Steinbrücke ist Straße, die schon gepflastert ist (`stone_stretches`); ein Tunnel der Etappe
(`tunnel_stretches`) ist keine Straße und ändert die Blöcke der Stadt nur, wenn er den Anteil dieser Ankunft aus dem
Band schiebt; nachgerückt wird bei jeder Altstadt (Abschnitt 8). Werkzeug der Prüfung (`kc_trigger.gd`, alle 64
sichtbaren Etappen in beiden Richtungen, echte `Track`, 1-m-Schritte):

| | AU-R3 | AU-R4 |
|---|---|---|
| Ankünfte außerhalb 0,6 ± 0,05 wie gehört (1-m-Raster) | 14 (Bordeaux, Dresden, Lyon, Paris, Toulouse, Tours 0,70–0,78; Barcelona, Ljubljana 0,549) | 3 (Barcelona 2 ×, Ljubljana: 0,549 im Raster, zugeteilt genau 0,550) |
| dasselbe in genauen Metern aus dem Plan (`cobble_alloc.gd`) | 11 von 100 | 0 von 100 (0,550–0,645) |
| Straßen allein, ohne Steinbrücke (Lesart AU-R3) | 22 außerhalb | 26 außerhalb – Lesart verlassen |
| Regeln der Auslösung (Pflaster, Deck, Beton, Fugen, Zonen, Tankspur) | 0 Verstöße | 0 Verstöße |
| Städte mit verschiedenen Mustern je Ankunft | 0 | 0 |
| Pläne mit gleicher Ausgabe des Prüfskripts | – | 114 von 128, darunter Kiel – Hamburg in beiden Richtungen (Hamburg `P--PP-P-P`) |

Anders klingen nur Bordeaux (0,70 → 0,60), Dresden (0,70 → 0,59), Lyon (0,71 → 0,61), Paris (0,72 / 0,78 → 0,60 /
0,64), Toulouse und Tours (0,70 → 0,60) – je ein Block weniger Pflaster, in Lyon ein Block an anderer Stelle, in Paris
zwei weg und einer dazu; in Saragossa wechselt nur das Kennzeichen eines
Blocks, der ganz auf der Steinbrücke liegt (dort klingt es ohnehin nach Pflaster; im 1-m-Raster 1 m am Brückenende).
Die Tunnel von Hannover – Hamburg (330 m) und Lüttich – Paris (130 m) lassen den Anteil im Band (0,617 / 0,644):
Beide Städte hören bei jeder Ankunft dieselben Blöcke. Beide Lesarten zugleich gehen nicht: Für Dresden, Tours,
Saragossa und Toulouse bringt keine Wahl der Blöcke die Straßen allein und „wie gehört“ zugleich ins Band (alle
Teilmengen durchgerechnet) – die Lesart gehört in §11.2.

**Lkw-Aufprall (KRITIK-R2-MESS M1).** V3 hielt beim Lkw nur knapp: Der 95-%-Wert aus 60 Unfällen ist selbst eine
Zufallsgröße, eine Abnahme mit neuen Zufallsfolgen konnte ohne jede Änderung am Klang scheitern. Werkzeug der Prüfung
(`kr_crash.gd`, Limousine mit 110 km/h auf Kiel – Hamburg km 15, 130 km/h Schließgeschwindigkeit, je 60 schwere
Unfälle gegen einen Lkw, Gesamtlautstärke 1,0; Bootstrap: 10 000 Ziehungen aus den gemessenen Unfällen – die Anteile
sind abgeleitet):

| `truck.heavy` | Folge | 95 % der Begrenzung | Unfälle > 3 dB | True Peak höchstens | Abnahmen mit 60 Unfällen > 3 dB (Bootstrap) |
|---|---|---|---|---|---|
| −11 (AU-R3), KRITIK-R2-MESS | 9312 | 2,66 dB | 3 von 60 | −1,21 dBTP | 35 % |
| −11, nachgestellt | 9312 / 9313 / beide | 2,78 / 2,72 / 2,78 dB | 2 / 2 / 4 von 120 | −1,23 dBTP | 14 % (über 120: 11 %) |
| **−11,5 (AU-R4)** | 9312 / 9313 / beide | **2,13 / 2,51 / 2,34 dB** | 1 / 1 / 2 von 120 | **−1,39 dBTP** | **2 %** (über 120: 0,5 %) |
| Pkw, `hit_heavy` −11,5 (zum Vergleich), KRITIK-R2-MESS | 9311 | 2,05 dB | 1 von 60 | −1,38 dBTP | 1,5 % |

Der Schlag des Lkw-Aufbaus liegt damit wie der eigene tiefe Schlag schwerer Unfälle bei −11,5 dB (vorher −11; AU-C1
−10). Er ist eine von vier Schichten, deren Pegel ohnehin je Unfall um ±2 dB gewürfelt wird; dass 0,5 dB weniger den
Charakter ändern, ist nicht zu erwarten (abgeleitet – gehört hat es niemand). Zusätzlich gehört in §11.2, V3 über
mindestens 120 Unfälle aus zwei Folgen zu beurteilen (Vorschlag der Prüfung): Ein 95-%-Wert aus 60 Unfällen streut um
0,3–0,4 dB (Bootstrap).
