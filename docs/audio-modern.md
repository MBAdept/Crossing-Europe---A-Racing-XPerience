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
| `engine` | `engine_audio3.gd` · `EngineAudio3` | `MEngine` | Arcade-Zyklenbank über die unveränderten Klassen `EngineAudio` / `EngineBank` / `EngineGearbox`, im Hauptthread, mit dem Breiten-Hall des Arcade-Motorbusses | AU-B |
| `layers` | `vehicle_layers.gd` · `VehicleLayers` | `MEngineFx` | still (die Arcade-Bank trägt ihr Turbopfeifen selbst) | AU-B |
| `road` | `road_audio.gd` · `RoadAudio` | `MRoad`, `MWind` | Wind und Reifenquietschen mit den Arcade-Formeln | AU-C1 |
| `impact` | `impact_audio.gd` · `ImpactAudio` | `MImpact` | `crash` und `rail` als Einmalklänge mit den Arcade-Pegeln | AU-C1 |
| `ambience` | `ambience_audio.gd` · `AmbienceAudio` | `MAmb` | Regenschleife | AU-C2 |
| `traffic` | `traffic_extras.gd` · `TrafficExtras` | `MTrafficV0`–`7`, `MSiren` | das Arcade-Modell `TrafficAudio` unverändert (Unterklasse, die nur auf die Modern-Busse ausgibt), acht Stimmen, Arcade-Klänge | AU-C2 |
| `music` | `music_director.gd` · `MusicDirector` | `MMusic` | je Kontext ein Stück in Schleife, Überblenden mit zwei Playern | AU-D1 |
| `sfx` | `sfx_bank.gd` · `SfxBank` | `MUI`, `MSfx` | alle übrigen Einmalklänge; nimmt eine Modern-Datei, sobald ein Manifest sie nennt, sonst den `SfxSynth`-Klang | bleibt (Klänge: AU-C1, AU-D2) |

Reihenfolge je Bild (`ModernAudio.SLOTS`): `env`, `engine`, `layers`, `road`, `impact`, `ambience`, `traffic`,
`music`, `sfx`. Nach dem Motor steht dessen Zustand als `frame.engine` (`rpm`, `gear`, `load`, `boost`) für die
folgenden Bausteine bereit.

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

Pegelkette mit einem Messton (gemessen in `check_modern_audio.gd --live`): 1 kHz mit −23,0 dB Effektivwert über
`MUI` kommt mit −26,05 dB am Master an (Plan −26,01), über `MMusic` mit −26,11 dB (Plan −26,11).

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
gilt. Der Platzhalter-`MusicDirector` spielt je Kontext ein Stück in Schleife und blendet zwischen Stücken über
(0,6 s aus, 0,4 s ein): die Modern-Datei mit der passenden Rolle aus `assets/audio/modern/music/manifest.json`
(`title`, `interlude`, `result`, `race`; mehrere Rennstücke reihum, eins je Etappe), sonst in den Menü-Kontexten
die heutige Titelmelodie und im Rennen nichts. Ein Stück gilt erst als begonnen, wenn sein Stream da ist
(`resolve()` antwortet bis dahin mit Stille): Die Titelmelodie wird ohne `audio.music_file` in einem Thread
synthetisiert und trifft mit dem Profil Modern beim Start erst nach dem Menü-Kontext ein – vor der Korrektur
blieb sie dann für immer stumm. Das Rennstück blendet bei `stage_finish` aus. Der Schalter
`set_race_music(false)` („Musik im Rennen: Aus“) lässt den Kontext `race` still. `stop_all()` hält die Musik nicht
an. Der Pegel je Kontext steht in `audio.modern.music.context_db` (bezogen auf eine Datei mit −14 LUFS).

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

## 12. Prüfungen

`tests/unit/audio_modern/` (laufen mit `tools/run_tests.sh`, allein mit `tools/run_tests.sh audio_modern`,
57 Tests, gemessen 46 s):

| Datei | prüft |
|---|---|
| `test_arcade_identity.gd` | **Arcade ist Arcade geblieben**: Ausgabe des Motor-Mischers je Auto mit festem Seed (SHA-256 über 355 733 Abtastwerte je Auto), alle `SfxSynth`-Klänge, das Verkehrs- und Raummodell, die 40 eingefrorenen Audiodateien – gegen Fingerabdrücke, die aus dem Tag v0.7.0 erzeugt sind (`golden/arcade_v070_*.json`) |
| `test_modern_buses.gd` | Namen, Sends, Indexfolge, Effekte, Fader, Tiefpass, Renn-EQ, Kompressor-Umrechnung; Arcade-Busse bleiben unberührt |
| `test_modern_mix.gd` | Pegel aus Plan und Reglern, Ducking (Kurve, Attack, Release, Schlüssel aus dem Fahrzustand), Mischzustände, Effekte aus, die Zahlen des Plans in der Konfiguration |
| `test_modern_assets.gd` | Manifest-Lader, Platzhalter nur auf Wunsch, kaputte Manifeste (`fixtures/broken/`) |
| `test_audio_feed.gd` | Oberflächen je Seite, Zonen, Bauwerke, Fugen, Vorbeifahrten, Sprünge, „nur lesen“ |
| `test_modern_audio.gd` | `ModernAudio` ohne Szenenbaum: Lebenszyklus, Frame-Semantik, Einmalklänge und Ereignisse (50 ms), Mischung, Musik-Kontexte, Stummschaltung |
| `test_modern_checks.gd` | startet `check_modern_audio.gd` zweimal (ohne und mit Wiedergabe) und `check_arcade_lean.gd` als eigene Prozesse |

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
- **Motor-Thread** (D27): `audio.modern.engine_thread` und `--audio-sync` werden gelesen (`ctx.sync`); der
  Thread-Mischer selbst ist AU-B. Der Platzhalter-Motor mischt im Hauptthread.
- **Pegel**: `levels.MSfx`, die Mischzustände, `duck.*` und `context_db` sind Startwerte; AU-B (Motor), AU-C1/C2
  (Fahrbahn, Welt) und AU-E (Gesamtabstimmung, Movie-Maker-Szenarien) stimmen sie ab.
