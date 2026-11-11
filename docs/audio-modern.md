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
- Niemand schaltet das Profil bisher im Spiel um: Die Einstellung „Klang“ und der Aufruf
  `AudioManager.set_profile(Settings.sound())` kommen mit Welle 2 (UI1). Bis dahin wählt man Modern mit
  `--sound=modern` oder `audio.profile` (Abschnitt 2).

## 2. Profil wählen

| Weg | Wirkung |
|---|---|
| `AudioManager.set_profile("arcade" \| "modern")` | schaltet um; ein zweiter Aufruf mit demselben Profil tut nichts. **Nie während einer Etappe** aufrufen (Vertrag §4.7.1) – laufende Klänge werden hart beendet. |
| `AudioManager.profile()` | das Profil in Kraft |
| Kommandozeile `--sound=arcade\|modern` | Profil beim Start; gewinnt gegen die Konfiguration |
| `audio.profile` in `config/game_config.json` oder `user://game_config.json` | Profil beim Start (`""` = keins erzwingen) |
| Einstellung „Klang“ [Wie Grafik \| Arcade \| Modern] | ab Welle 2: `GameFlow` ruft `set_profile(Settings.sound())` beim Start und bei jeder Änderung |

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
| `road` | `road_audio.gd` · `RoadAudio` | `MRoad`, `MWind` | Wind und Reifenquietschen mit den Arcade-Formeln | AU-C1 |
| `impact` | `impact_audio.gd` · `ImpactAudio` | `MImpact` | `crash` und `rail` als Einmalklänge mit den Arcade-Pegeln | AU-C1 |
| `ambience` | `ambience_audio.gd` · `AmbienceAudio` | `MAmb` | Regenschleife | AU-C2 |
| `traffic` | `traffic_extras.gd` · `TrafficExtras` | `MTrafficV0`–`7`, `MSiren` | das Arcade-Modell `TrafficAudio` unverändert (Unterklasse, die nur auf die Modern-Busse ausgibt), acht Stimmen, Arcade-Klänge | AU-C2 |
| `music` | `music_director.gd` · `MusicDirector` | `MMusic` | je Kontext ein Stück in Schleife, Überblenden mit zwei Playern | AU-D1 – **erledigt**: Titel-Remaster, Rennstück mit Einzähler, Schleife und Schluss über `AudioStreamInteractive` (Abschnitt 14) |
| `sfx` | `sfx_bank.gd` · `SfxBank` | `MUI`, `MSfx` | alle übrigen Einmalklänge; nimmt eine Modern-Datei, sobald ein Manifest sie nennt, sonst den `SfxSynth`-Klang | bleibt (Klänge: AU-C1, AU-D2) |

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
└─ MMaster                 Summenkompressor (audio.modern.glue)
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

### 6.5 Summenkompressor

Auf `MMaster` sitzt ein langsamer Kompressor (`audio.modern.glue`: Schwelle −9 dB, wirksames Verhältnis 2:1,
Attack 30 ms, Release 300 ms). `ratio` in der Konfiguration ist das **wirksame** Verhältnis;
`ModernBuses.compressor_ratio()` rechnet es in den Wert um, den Godots Kompressor dafür braucht (Abschnitt 11).

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
Beansprucht niemand das Ereignis, klingt der `play()`-Aufruf sofort. In Welle 0 beansprucht kein Baustein etwas.

**Musik.** `set_music_context(ctx)` kennt `title`, `menu`, `race_menu` (Bildschirme zwischen den Etappen), `race`,
`result`, `off`. Das Spiel ruft weiterhin `set_music(true/false)` und ab Welle 2 daneben `set_music_context`; der
letzte Aufruf gewinnt: `set_music(false)` = `off`; `set_music(true)` = `menu`, sofern nicht schon ein Menü-Kontext
gilt. Der `MusicDirector` spielt in den Menü-Kontexten das Titel-Remaster (ohne Modern-Datei die heutige
Titelmelodie) und im Rennen ein Rennstück, das mit der Etappe beginnt und mit ihr endet; Überblenden zwischen
Stücken 0,6 s aus, 0,4 s ein, gleiche Leistung. Ein Stück gilt erst als begonnen, wenn sein Stream da ist
(`resolve()` antwortet bis dahin mit Stille): Die Titelmelodie wird ohne `audio.music_file` in einem Thread
synthetisiert und trifft mit dem Profil Modern beim Start erst nach dem Menü-Kontext ein. Der Schalter
`set_race_music(false)` („Musik im Rennen: Aus“) lässt den Kontext `race` still. `stop_all()` hält die Musik nicht
an. Der Pegel je Kontext steht in `audio.modern.music.context_db` (bezogen auf eine Datei mit −14 LUFS), dazu
`gain_db` des Stücks im Manifest. Einzelheiten: Abschnitt 14.

## 8. AudioFeed v0

`AudioFeed` leitet aus der `Track` der Etappe (`set_track`) und dem Fahrzeugzustand des Bildes
(`set_vehicle_state`) ab, was der Klang über die Straße wissen muss – nie aus dem Renderer (D28). Er ist rein und
liest nur: die Bauwerke der Etappe und die Segmente am und hinter dem Auto, nie davor.

| Feld | Inhalt |
|---|---|
| `surface_l`, `surface_r` | worauf die linken / rechten Räder laufen: `asphalt`, `rumble` (Randlinie und Rüttelstreifen), `shoulder`, `grass` |
| `wet`, `snow` | 0…1 aus dem Wetter (im Tunnel trocken) |
| `zone` | `tunnel`, `bridge`, `city`, `forest`, `valley` oder `open` |
| `tunnel`, `bridge`, `cover`, `depth_m` | im Tunnel / auf einer Brücke dieses Typs / unter einem Dach (`border`, `fuel`); Abstand zum näheren Ende |
| `road`, `scenery`, `city`, `guardrail`, `lanes` | Straßentyp, Landschaft, Stadt, Leitplanke, Spuren am Auto |
| `events` | seit dem letzten Bild überfahren: `tunnel_in/out`, `bridge_in/out`, `cover_in/out`, `joint` (Dehnfuge), `pass_object {z, side, dist_m, size, kind, set}` (Baum, Gebäude, Pfosten, Schild, Schilderbrücke, Fels) |

Die Ereignisse des Feeds erreichen die Bausteine über `event()`. Breiten für Randlinie und Rüttelstreifen stehen
in `audio.modern.feed` (eigene Schlüssel – der Klang liest keine `render.*`-Werte). Sprünge (Etappenstart, mehr als
`max_scan_m` in einem Schritt) setzen die Position ohne Ereignisse. Sendet die Sitzung keinen Zustand, bleibt der
Feed ungültig (`feed.valid` falsch) und die Bausteine arbeiten mit den Werten der alten Aufrufe. AU-C1 baut den
Feed aus.

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
32 kHz Stereo). `*.i16` kommt mit KERN in den Export-Filter und in `.gitattributes`; bis zu dessen Merge erkennt
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
| `tools/audio/music/music_lib.py` | Musik-Kette (AU-D1): moderne Produktionsschicht über `music_synth.py`, Mixer, Master, Vorbis mit Messung nach der Kodierung (Abschnitt 14.2) |
| `tools/audio/music/title_remaster.py`, `linke_spur.py` | die Generatoren des Titel-Remasters und von Rennstück 1 (`--out`, `--wav`, Skizzen) |
| `tools/audio/music/check_music.py` | Noten: Tonklassen und Akkord-Grundton je Takt, Tonart – Remaster gegen das Original, Rennstück gegen seine Partitur |

`audio_qc.py` prüft je Datei: Format passend zum Ordner; Manifest gleich Datei (sha256, Bytes, Frames, Kanäle,
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
| `test_audio_feed.gd` | Oberflächen je Seite, Zonen, Bauwerke, Fugen, Vorbeifahrten, Sprünge, „nur lesen“ |
| `test_modern_audio.gd` | `ModernAudio` ohne Szenenbaum: Lebenszyklus, Frame-Semantik, Einmalklänge und Ereignisse (50 ms), Mischung, Musik-Kontexte, Stummschaltung |
| `test_modern_checks.gd` | startet `check_modern_audio.gd` zweimal (ohne und mit Wiedergabe) und `check_arcade_lean.gd` als eigene Prozesse |
| `test_engine3_bank.gd`, `test_engine3_mix.gd`, `test_engine3_slot.gd`, `test_engine3_checks.gd` | Motor v3 (AU-B): Bank-Lader, Mischer (Knackser an den Zyklusgrenzen, Leistung beim Überblenden, Kanalabgleich, Monosumme), Baustein und Fahrzeugebenen, `check_engine3.gd` als eigene Prozesse (Thread-Bank mit sechs Hängern von 400 ms, Profilwechsel, Beenden) – [motorsound.md](motorsound.md) 6.7 |
| `test_music_director.gd`, `test_music_checks.gd` | Musik (AU-D1): Zustandsmaschine des `MusicDirector` ohne Szenenbaum; `check_music.gd` als eigene Prozesse (Schleife und Schluss offline gemischt, Rennen mit Countdown und Ducking, Arcade ohne Neues, Beenden mit Musik) – Abschnitt 14.5 |

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
  WAV-Schleife von AU-C1/C2 brauchen Frames hinter `loop_end`, sonst knackt die Naht leise und `--audio-sync` ist
  nicht reproduzierbar. Am saubersten in `modern_lib.py` (eine Stelle für alle Generatoren) und als Regel in
  `audio_qc.py` („hinter dem Schleifenende liegen Daten“). Für die Schleifen, die der eingefrorene Arcade-Code
  zur Laufzeit baut, ist das nicht untersucht.
- **`modern_lib.write_wav_import()` / `write_ogg_import()` verlieren den Kopf der `.import`-Datei**: Sie öffnen
  die Datei zum Schreiben, bevor `_import_head()` sie liest. Nach jedem erneuten Erzeugen fehlen uid und
  Importpfad, und das Spiel meldet „Failed loading resource“, bis `godot --import` gelaufen ist (dann mit neuer
  uid). `engine_synth3.py` umgeht das mit `write_wav_import_keep()`; die Korrektur gehört in `modern_lib.py`.
- **Breite des Motors**: Der Motor v3 ist trocken; bei Kompakt, Kombi und Limousine sitzt er in der Mitte
  (Kanalkorrelation im Spiel 0,97–1,00, der Arcade-Motor mit seinem Hall 0,80–0,99). Raum und Breite sind Sache
  von `env` (AU-C2) – siehe [motorsound.md](motorsound.md) 6.9.

## 14. Musik (Paket AU-D1)

Vertrag D26, D29, D30, §4.7, A-5. Alle Zahlen gemessen auf der Entwicklungsmaschine (Godot 4.7.2, ohne Bildschirm,
Dummy-Audiotreiber), sofern nicht „abgeleitet“ dasteht. **Wie die Musik klingt, hat hier niemand gehört** – das
beurteilt der Nutzer (Hörproben unter `<scratch>/v080/deliver/AU-D1/`).

### 14.1 Die Stücke

`assets/audio/modern/music/` (Manifest `manifest.json`, Rollen für den `MusicDirector`):

| Datei | Rolle | Länge | Schleife | Lautheit / True Peak (nach Vorbis) | Größe |
|---|---|---|---|---|---|
| `titel_remaster.ogg` | `title` | 202,5 s | Intro 15 s einmal, dann Takte 9–108 (187,5 s) | −14,1 LUFS / −1,7 dBTP | 3,93 MB |
| `linke_spur.ogg` | `race` | 176,4 s | Einzähler + A1 (9 Takte, 16,36 s) einmal, dann 88 Takte = 160,0 s | −14,2 LUFS / −1,8 dBTP | 3,36 MB |
| `linke_spur_schluss.ogg` | `race_ending` | 7,8 s | – | −15,7 LUFS / −2,4 dBTP | 0,15 MB |

Mit dem Platzhalter von AU-A zusammen 7,48 MB von 25 MB Budget (§4.11). `audio_qc.py` besteht für alle
Dateien (Naht ×0,11 / ×0,08). Alle drei Einträge tragen `bpm` und `bar_beats` (Titel 128, Rennstück 132; in den
Import-Einstellungen ebenso, `beat_count` 0), über das Format hinaus `piece`, Titel und Rennstück `intro_bars` und
`loop_bars` (8 + 100 bzw. 9 + 88 Takte), das Rennstück `ending` (die id des Schlusses) und `countin_beats`; der
Schluss eigene QC-Grenzen der Lautheit
(`"qc": {"lufs": [-20, -10]}`): Er wird mit dem Master der Schleife bearbeitet und nicht für sich auf −14 LUFS
gebracht, sonst spränge der Pegel am Übergang.

### 14.2 Die Kette (`tools/audio/music/`)

| Datei | Inhalt |
|---|---|
| `music_lib.py` | die Produktionsschicht über dem eingefrorenen `tools/audio/music_synth.py` (importiert, nie geändert): Sub-Kick- und Snare-Ebenen, Shaker, Sub-Bass, zwei Supersaw-Leads für die Breite, neue Platte und Halle; `Mixer` (eine Spur nach der anderen in Busse und Sends – ein Stück von drei Minuten liegt nie mit allen Spuren im Speicher); `Master` (EQ, drei Bänder bei 140 Hz und 3,2 kHz, Kleber, M/S, Lautheit, Soft-Clip, True-Peak-Begrenzer) mit `pre()`/`fit_gain()`/`post()`; `encode_checked()` schreibt Vorbis q5 bitgenau, dekodiert und misst – liegt der True Peak nach der Kodierung über −1,08 dBTP, sinkt die Grenze des Begrenzers und die Datei wird neu geschrieben; `write_ogg_import_keep()` (Import mit erhaltener uid, `loop_offset` mit allen Stellen); Chroma, Dreiklang, Tonart für die Prüfung |
| `title_remaster.py` | das Titel-Remaster (14.3) |
| `linke_spur.py` | Rennstück 1 (14.4) |
| `check_music.py` | die Noten-Prüfung (14.6) |

```
python3 tools/audio/music/title_remaster.py            # 295 s auf einem Kern (gemessen)
python3 tools/audio/music/linke_spur.py                # 283–291 s
python3 tools/audio/music/linke_spur.py --info         # Form, Clip-Längen
python3 tools/audio/music/title_remaster.py --bars 32:48 --wav /tmp/x   # Skizze einzelner Takte (37 s)
python3 tools/audio/music/linke_spur.py --sketch 12 --wav /tmp/x        # Einzähler + 12 Takte (25 s)
python3 tools/audio/music/check_music.py
python3 tools/audio/qc/audio_qc.py --folders music --determinism
```

Jeder Generator nimmt `--out <Ordner>` (dann ohne Import-Dateien; so ruft `audio_qc.py --determinism` ihn zweimal
auf) und `--wav <Ordner>` (zusätzlich der ganze Master als Float-WAV für Hörproben). Feste Seeds, kein Zeitstempel,
Vorbis über ffmpeg mit den Bitexakt-Schaltern: zwei Läufe schreiben dieselben Bytes. Danach `godot --headless --import`.

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
128 bei der umgekehrten, Falle 14.7.1) – der Übergang würde doppelt klingen. Die Schleife endet mit A1, so liegt die
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

### 14.5 Der `MusicDirector`

| Kontext | Stück |
|---|---|
| `title`, `menu` | Rolle `title`: das Titel-Remaster (ohne Modern-Datei die Titelmelodie von heute) |
| `race_menu`, `result` | Rolle `interlude` bzw. `result`, solange es keine gibt das Titel-Remaster – es läuft dann ohne Neustart weiter |
| `race` | ein Rennstück (Rolle `race`, reihum eins je Etappe) |
| `off` | Stille |

Das Rennstück und die Etappe:

| Phase | wann | was |
|---|---|---|
| `armed` | `set_music_context("race")` – jede Etappe, auch ein Neustart | die Menümusik blendet aus, das Stück wartet |
| `waiting` | Ereignis `stage_start` {countdown_s} | Start in countdown_s − Einzähler; jede Countdown-Zahl (`countdown` {n}) verankert neu: Start in n − Einzähler |
| `playing` | der Start ist da (das Bild, das dem geplanten Moment am nächsten liegt), `go` ohne `stage_start`, oder 0,5 s Fahrt ohne jedes Ereignis (Werkzeuge) | `play()` des `AudioStreamInteractive`; der erste Schlag nach dem Einzähler fällt auf „LOS!“ |
| `ending` | `stage_finish` | Wechsel zum Schluss am nächsten Taktstrich |
| `over` | `stage_finish`, bevor das Stück begonnen hat | bleibt still |

- **Die Uhr des Starts** sind die Physikschritte (`Engine.get_physics_frames()`, ohne die pausierten) – die Uhr des
  Countdowns. Ein langes Bild, nach dem die Physik aufholt oder Zeit verwirft, verschiebt Countdown und Musik gleich.
  Ohne Physik (Unit-Tests) zählt die Bildzeit. Gemessen in einem Rennen mit Countdown: der Schlag liegt in Spielzeit
  1,5 ms vor „LOS!“; in der Ausgabe eines Laufs ohne Bildschirm 53,4 ms oder eine Treiber-Portion mehr danach – der
  Dummy-Treiber startet jeden Klang an seiner nächsten Portion von 4096 Frames (Falle 14.7.9); ein echter Treiber mischt
  in Schritten von 512 Frames (abgeleitet: dann bestimmt das halbe Bild die Genauigkeit).
- **Pause im Einzähler**: Der Stream pausiert mit dem Countdown (`stream_paused`). Nach „LOS!“ läuft die Musik in
  der Pause weiter, gefiltert vom Mischzustand `pause`.
- **„Musik im Rennen: Aus“** lässt das Rennstück still; wieder an, beginnt es mit seinem Einzähler.
- **Platzhalter** spielen nur, solange eine Rolle kein echtes Stück hat (`audio.modern.placeholders`).
- **Pegel**: Player auf `context_db` + `gain_db`; Ducking, Renn-EQ, Pause-Tiefpass und Dips wirken auf dem Bus.
  Überblenden mit gleicher Leistung über die Player-Lautstärke (die der Mischer je Block rampt).
- **Ende**: `teardown()` hält und gibt die Player frei. Ein `quit()` direkt danach kann bei jedem Profil
  „leaked at exit“ melden (Falle 14.7.10).

### 14.6 Prüfungen

| Datei | prüft |
|---|---|
| `tests/unit/audio_modern/test_music_director.gd` | 8 Tests ohne Szenenbaum: Stücke je Kontext, Start und „LOS!“ (Spielzeit), Neuverankerung an den Countdown-Zahlen, kurzer Countdown, `go`, Start ohne Ereignisse, Ziel, Neustart, Ziel vor dem Start, „Musik im Rennen“, Pause im Einzähler, der gebaute `AudioStreamInteractive`, Platzhalter |
| `tests/unit/audio_modern/check_music.gd` | eigene Prozesse: **interactive** – das Rennstück offline in 512er-Schritten wie der Mischer: Hauptdatei Frame für Frame, nach dem Dateiende Abweichung 0 zum ersten Durchgang, Schluss 2,9 ms vor dem Taktstrich, keine Lücke, kein doppelter Schlag (+0,01 dB); **race** – Kiel – Hamburg mit Countdown und Autopilot: Schlag auf „LOS!“, Musik nach dem Fader −4,5 dB unter Vollgas, ohne Sitzung wieder −0,1 dB, kein Bild über 0,35 s Spielzeit; **arcade** – mit dem Profil Arcade nach Menü, Rennkontext und Etappenereignissen kein `ModernAudio`, kein Modern-Bus, keine Modern-Musik geladen, die Menümusik ist die Titelmelodie von v0.7.0; **quit_menu**, **quit_race** – Musik spielt, Profil endet, nichts bleibt übrig |
| `tests/unit/audio_modern/test_music_checks.gd` | startet `check_music.gd` (so deckt `tools/run_tests.sh` es ab); keine Fehler- oder Warnzeile, auch kein „leaked at exit“ |
| `tools/audio/music/check_music.py` | Noten und Tonart (14.3, 14.4) |
| `tools/audio/qc/audio_qc.py` | Dateien, Pegel, Nähte, Import, Größe; `--determinism` |

### 14.7 Fallen (gemessen, Godot 4.7.2)

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

### 14.8 Offene Punkte

- **Hören**: Titel-Remaster, Rennstück 1, Schluss und Pegel muss der Nutzer beurteilen.
- **Stücke 2–3, Zwischenspiel, Stinger, UI-Klänge** (AU-D2): je Stück ein Generator nach dem Muster von
  `linke_spur.py` (ein Rendering, ein Master, Hauptdatei mit Intro und Schleife, Schluss). Der Director nimmt weitere
  Rennstücke reihum und Rollen `interlude`/`result` ohne Änderung.
- **Beenden des Spiels** (UI / AU-E): `GameFlow.quit_game()` sollte den Klang anhalten und 0,3 s warten, bevor es
  `quit()` ruft (Falle 10) – betrifft beide Profile.
- **`capture_mix.gd --scenario=race_music`** sendet kein `stage_start`: Das Rennstück beginnt nach 0,5 s Fahrt, sein
  Einzähler und der erste Schlag fallen in das Messfenster „idle“ (gemessen −18,75 LUFS gegen Plan −19,5) – für das
  Leerlauf-Ziel nicht vergleichbar.
- **QC-Regel und Godot**: `audio_qc.py` vergleicht `beats` mit der Schleifenlänge, Godot zählt `beat_count` vom
  Dateianfang (Falle 5).
