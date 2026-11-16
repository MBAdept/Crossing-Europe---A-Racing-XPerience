#!/usr/bin/env python3
"""Adds audio.profile and audio.modern to config/game_config.json (text insertion, the file's formatting stays)."""
import json
import sys

P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/config/game_config.json"
s = open(P, encoding="utf-8").read()
OLD = '\t\t"engine_width": 0.6,\n\t\t"engine_width_hipass": 0.1\n\t},\n'
if s.count(OLD) != 1:
    sys.exit("Anker nicht eindeutig")

DOC = (
    "Klangprofil „Modern“ (v0.8.0, docs/audio-modern.md). profile = Profil erzwingen: \\\"\\\" (Einstellung „Klang“ gilt), "
    "\\\"arcade\\\" oder \\\"modern\\\" – für Tests und als Schalter neben der ausführbaren Datei; die Kommandozeile --sound= gewinnt. "
    "Alles Weitere unter modern liest nur das Profil „Modern“; Arcade liest nichts davon. "
    "placeholders = Platzhalter-Klänge aus den Manifesten benutzen (nur für Tests und Pipeline-Prüfungen: im Spiel "
    "klingt nie ein Platzhalter, eine Rolle ohne echten Klang nimmt den Arcade-Klang oder bleibt still). "
    "engine_thread = Motor-Mischer in einem eigenen Thread (false oder --audio-sync: im Hauptthread). "
    "loudness = Ziele des Pegelplans bei Standardreglern (Gesamt 0,8, Effekte 1,0, Musik 0,7): Vollgas "
    "full_throttle_lufs (Kurzzeit), Reisetempo cruise_lufs, Leerlauf idle_lufs, Musik im Rennen music_under_car_db "
    "unter dem Auto, Menümusik menu_music_lufs, Musikdateien gemastert auf master_lufs mit höchstens true_peak_dbtp. "
    "levels = fester Pegel je Bus in dB (der Regler „Effekte“ wirkt zusätzlich auf MSfx, „Musik“ auf MMusic, "
    "„Gesamtlautstärke“ auf Master); MSfx −3 dB, solange die Platzhalter-Bausteine die Arcade-Klänge spielen (deren "
    "Vollgas liegt bei −13 LUFS). glue = Summenkompressor auf MMaster: threshold_db, ratio = wirksames Verhältnis "
    "(der Code rechnet es in den Wert um, den Godots Kompressor dafür braucht), attack_ms, release_ms, gain_db. "
    "duck = Absenken der Musik unter dem Auto: Pegel des Busses key (Spitze in dBFS) von from_db bis to_db senkt bus "
    "um 0 bis depth_db, schnell hinunter (attack_s), langsam zurück (release_s). snapshots = Mischzustände, die "
    "weich ein- (attack_s) und ausblenden (release_s): gain_db je Bus, lowpass_hz je Bus (Tiefpass), hold_s für "
    "ausgelöste Zustände – pause (Pausenmenü), impact (Kollision), siren (Verfolgung), result (nach der Ziellinie). "
    "music = Pegel der Musik je Kontext context_db (auf eine Datei mit master_lufs bezogen), race_eq_db = "
    "Equalizer der Musik im Rennen (Band in Hz → dB; Bänder 31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000), "
    "fade_in_s / fade_out_s = Überblenden zwischen Stücken. feed = was aus der Strecke abgeleitet wird (AudioFeed): "
    "rumble_in_m / rumble_out_m = Breite von Randlinie und Rüttelstreifen innerhalb / außerhalb des Fahrbahnrands, "
    "pass_max_m = bis zu diesem seitlichen Abstand zählen Objekte am Rand als Vorbeifahrt, max_scan_m = größerer "
    "Sprung des Autos in einem Bild gilt als Versetzen (keine Ereignisse), joint_every_m = Abstand der Dehnfugen auf "
    "Brücken. env = Raumklang auf MEnv: überschreibt für Modern einzelne Schlüssel des Arcade-Raumklangs "
    "(reverb_*, reflections_*). traffic = überschreibt für Modern einzelne Verkehrs-Schlüssel (traffic_*, siren_*); "
    "traffic_voices höchstens 8 (Busse MTrafficV0–7). Alle Werte außer den Zielen sind Startwerte (abgeleitet, noch "
    "an keinem echten Modern-Klang gemessen); die Pakete AU-B bis AU-E stimmen sie ab."
)

NEW = (
    '\t\t"engine_width": 0.6,\n\t\t"engine_width_hipass": 0.1,\n'
    '\t\t"_doc_modern": "' + DOC + '",\n'
    '\t\t"profile": "",\n'
    '\t\t"modern": {\n'
    '\t\t\t"placeholders": false,\n'
    '\t\t\t"engine_thread": true,\n'
    '\t\t\t"loudness": {"full_throttle_lufs": -16.0, "cruise_lufs": -21.0, "idle_lufs": -24.0, "music_under_car_db": 8.0, "menu_music_lufs": -20.0, "master_lufs": -14.0, "true_peak_dbtp": -1.0},\n'
    '\t\t\t"levels": {"MMaster": 0.0, "MMusic": 0.0, "MSfx": -3.0, "MUI": 0.0, "MEnv": 0.0, "MCar": 0.0, "MEngine": 0.0, "MEngineFx": 0.0, "MRoad": 0.0, "MWind": 0.0, "MImpact": 0.0, "MWorld": 0.0, "MSiren": 0.0, "MAmb": 0.0},\n'
    '\t\t\t"glue": {"enabled": true, "threshold_db": -9.0, "ratio": 2.0, "attack_ms": 30.0, "release_ms": 300.0, "gain_db": 0.0},\n'
    '\t\t\t"duck": {"key": "MCar", "bus": "MMusic", "from_db": -24.0, "to_db": -10.0, "depth_db": 4.5, "attack_s": 0.05, "release_s": 0.45},\n'
    '\t\t\t"snapshots": {\n'
    '\t\t\t\t"pause": {"attack_s": 0.15, "release_s": 0.25, "gain_db": {"MMusic": -6.0}, "lowpass_hz": {"MMusic": 900.0, "MEnv": 1200.0, "MAmb": 1200.0}},\n'
    '\t\t\t\t"impact": {"attack_s": 0.02, "release_s": 0.6, "hold_s": 0.25, "gain_db": {"MMusic": -5.0, "MAmb": -3.0}},\n'
    '\t\t\t\t"siren": {"attack_s": 0.3, "release_s": 0.8, "gain_db": {"MMusic": -3.0}},\n'
    '\t\t\t\t"result": {"attack_s": 0.8, "release_s": 0.4, "gain_db": {"MCar": -9.0, "MWorld": -9.0, "MAmb": -6.0}}\n'
    '\t\t\t},\n'
    '\t\t\t"music": {"context_db": {"title": -1.0, "menu": -1.0, "race_menu": -1.0, "race": -0.5, "result": -1.0}, "race_eq_db": {"62": -1.0, "500": -3.0}, "fade_in_s": 0.4, "fade_out_s": 0.6},\n'
    '\t\t\t"feed": {"rumble_in_m": 0.3, "rumble_out_m": 0.5, "pass_max_m": 14.0, "max_scan_m": 90.0, "joint_every_m": 24.0},\n'
    '\t\t\t"env": {},\n'
    '\t\t\t"traffic": {"traffic_voices": 8}\n'
    '\t\t}\n'
    '\t},\n'
)
s = s.replace(OLD, NEW)
json.loads(s)   # still valid JSON
open(P, "w", encoding="utf-8").write(s)
print("game_config.json: audio.profile und audio.modern eingefügt")
