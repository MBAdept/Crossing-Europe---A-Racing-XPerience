#!/usr/bin/env python3
"""KRITIK-R2-CODE: break one line per guarded rule in the scratch copy heads/mut and run the test file that claims to
guard it. A mutation must make its test fail. One Godot process at a time, nice 19. Restores every file.
    python3 mutate.py [ids...]      -> res/mutations.json, prints a table
"""
import json, os, subprocess, sys, time

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE"
MUT = S + "/heads/mut"
RA = "scripts/audio/modern/road_audio.gd"
AF = "scripts/audio/modern/audio_feed.gd"
IA = "scripts/audio/modern/impact_audio.gd"
MB = "scripts/audio/modern/modern_buses.gd"
CF = "config/game_config.json"
TR = "test_road_audio.gd"
TF = "test_audio_feed.gd"
TB = "test_modern_buses.gd"

# id, file, old, new, test file filter, test that claims the rule, rule (German, for the report)
MUTS = [
    ("M01", RA, "if sq > 0.002 and squeal.level < ModernAudioPan.SILENT:", "if sq > 0.002:", TR,
     "test_squeal_pitch_per_event", "Quietschen: Tonhöhe je Ereignis (nicht jedes Bild neu)"),
    ("M02", RA, "squeal_factor = 1.0 + _rng_start.randf_range(-_squeal_spread, _squeal_spread)", "squeal_factor = 1.0", TR,
     "test_squeal_pitch_per_event", "Quietschen: Tonhöhe ±5 % zufällig"),
    ("M03", RA, "\tvar v := rng.randi_range(0, n - 2)\n\treturn v + 1 if v >= last else v",
     "\treturn (last + 1) % n", TR, "test_collision_variety", "Varianten zufällig statt reihum (n ≥ 3)"),
    ("M04", RA, "\tif n == 2 or last < 0:\n\t\treturn rng.randi_range(0, n - 1)",
     "\tif true:\n\t\treturn rng.randi_range(0, n - 1)", TR, "test_collision_variety",
     "nie dieselbe Variante zweimal hintereinander (n ≥ 3)"),
    ("M05", RA, "return db_to_linear(_drift_db * d[i] - 0.1151 * _drift_db * _drift_db)",
     "return db_to_linear(_drift_db * d[i])", TR, "test_each_side_has_its_own_loop_and_drift",
     "Drift: mittlere Leistung des Plans erhalten (−0,1151·s²)"),
    ("M06", RA, "return db_to_linear(_drift_db * d[i] - 0.1151 * _drift_db * _drift_db)",
     "return db_to_linear(0.0 * d[i] - 0.1151 * _drift_db * _drift_db)", TR,
     "test_each_side_has_its_own_loop_and_drift", "Drift je Seite vorhanden"),
    ("M07", RA, "[-_tyre_pan, _tyre_pan], not _exact_pitch.has(s))", "[-_tyre_pan, _tyre_pan], true)", TR,
     "test_each_side_has_its_own_loop_and_drift", "Rüttelstreifen ohne Tonhöhenversatz rechts"),
    ("M08", RA, "\tif v > _slab_high_kmh:\n\t\tdb -=", "\tif false:\n\t\tdb -=", TR,
     "test_concrete_slabs_keep_their_rhythm", "Plattenpegel über 150 km/h flacher"),
    ("M09", RA, "\tif not starting and not check:\n\t\treturn\n\tAudioServer.lock()",
     "\tAudioServer.lock()", TR, "test_slab_loops_lock_the_mixer_only_to_start",
     "Sperre nur beim Start und alle 0,5 s"),
    ("M10", RA, "var at := run.share() if run != null else _rng_start.randf()", "var at := _rng_start.randf()", TR,
     "test_slab_loops_lock_the_mixer_only_to_start", "startendes Muster übernimmt die Stelle des laufenden"),
    ("M11", RA, "var quiet: Layer = slab_fast if loud else slab_slow", "var quiet: Layer = slab_slow if loud else slab_fast",
     TR, "(keiner: test_slab_loops_lock_the_mixer_only_to_start prüft nur slab_realigned == 0)",
     "Nachstellen: der leisere wird auf den lauteren gesetzt"),
    ("M12", RA, "if absf(d) * period_s * 1000.0 > _slab_align_ms:", "if absf(d) * period_s * 1000.0 > 1.0e9:", TR,
     "(keiner)", "Nachstellen ab slabs.align_ms"),
    ("M13", IA, "return closing_kmh >= _glass_from or _rng.randf() < _glass_chance", "return true", TR,
     "test_collision_variety", "Glas unter 80 km/h nur mit 40 %"),
    ("M14", IA, "var jitter := _rng.randf_range(-_vary_db, _vary_db) if vary else 0.0",
     "var jitter := _rng.randf_range(-2.0 * _vary_db, 2.0 * _vary_db) if vary else 0.0", TR,
     "test_collisions_by_closing_speed_and_partner", "Pegel je Schicht höchstens ±2 dB"),
    ("M15", IA, "var jitter := _rng.randf_range(-_vary_db, _vary_db) if vary else 0.0",
     "var jitter := 0.0", TR, "test_collisions_by_closing_speed_and_partner / test_collision_variety",
     "Pegel je Schicht zufällig (überhaupt)"),
    ("M16", IA, "var delay_s := minf(_rng.randf_range(0.0, 2.0 * _vary_ms / 1000.0), lead_s) if (vary and lead_s > 0.0) else 0.0",
     "var delay_s := 0.0", TR, "test_collisions_by_closing_speed_and_partner", "späterer Einsatz je Schicht (überhaupt)"),
    ("M17", RA, "var jitter := _rng_start.randf_range(-_pass_jitter_db, _pass_jitter_db)", "var jitter := 0.0", TR,
     "(keiner)", "Vorbeifahrt ±2 dB"),
    ("M18", RA, "var variant := pick_variant(_rng_start, n, int(_pass_last.get(id, -1)))", "var variant := 0", TR,
     "(keiner)", "Vorbeifahrt: Variante zufällig"),
    ("M19", AF, "fuel_lane > 0.0)", "false)", TF, "test_no_rumble_at_the_fuel_lane", "keine Rüttellinie an der Tankspur"),
    ("M20", AF, "var every := joint_spacing(dk) if kind == \"bridge\" else -1.0",
     "var every := 24.0 if kind == \"bridge\" else -1.0", TF, "test_joints_per_deck", "Fugen je Deck"),
    ("M21", AF, "if city and deck == \"\" and _cobbled(km):", "if city and _cobbled(km):", TF,
     "test_no_old_town_cobbles_on_a_concrete_deck", "kein Altstadtpflaster auf Brücken ohne Steindeck"),
    ("M22", AF, "cobble_block_m, cobble_share, bridge_stretches(plan, float(length), _time_scale))",
     "cobble_block_m, cobble_share)", TF, "test_old_town_share_on_its_streets_around_a_bridge",
     "Anteil auf den Straßen (Brücken aus der Zuteilung)"),
    ("M23", AF, "\tif cut_all > 0.0:\n\t\t_closer(", "\tif false:\n\t\t_closer(", TF,
     "test_cobbled_blocks_count_only_the_streets", "Nachrücken ins Band 0,6 ± 0,05"),
    ("M24", AF, "\t\tif deck_of(str((b as Dictionary).get(\"type\", \"\"))) == \"stone\":\n\t\t\tcontinue\n", "", TF,
     "test_cobbled_blocks_count_only_the_streets", "Steinbrücken zählen als Straße"),
    ("M25", AF, "h = _mul32(h, 0x85EBCA6B)", "h = _mul32(h, 0x85EBCA6C)", TF,
     "test_unit_hash_mixes_neighbouring_keys", "fmix32 (Bezugswerte)"),
    ("M26", AF, "if cal is Array and (cal as Array).size() >= 2 and absf(float(cal[0]) - share) < 1.0e-6:",
     "if cal is Array and (cal as Array).size() >= 2:", TF, "test_concrete_threshold_per_country",
     "Schwelle nur für den kalibrierten Anteil"),
    ("M27", AF, "\t\tif absf(got + w - target) < absf(got - target):", "\t\tif unit_hash(\"%s|%d\" % [city, b]) < share:", TF,
     "test_cobbled_blocks_hit_the_share_per_centre", "Zuteilung je Altstadt genau (statt Hash je Block)"),
    ("M28", MB, "AudioServer.add_bus_effect(index(\"MMaster\"), _limiter)", "AudioServer.add_bus_effect(index(\"MMaster\"), _limiter, 0)",
     TB, "test_base_effects / test_limiter_from_config", "Begrenzer hinter dem Kleber"),
    ("M29", MB, "_limiter.ceiling_db = float(lim.get(\"ceiling_db\", -2.0))", "_limiter.ceiling_db = float(lim.get(\"ceiling_db\", -1.0))",
     TB, "test_limiter_from_config", "Obergrenze ohne Eintrag −2 dB"),
    ("M30", RA, "* tyre_fade * _snow_crunch * snow_amount", "* tyre_fade * snow_amount", TR,
     "test_surfaces_per_side_wet_and_snow", "Schnee-Knirschen mit snow_crunch"),
    ("M31", CF, "\"bridge\": 2.0, \"tunnel\": 0.0}", "\"bridge\": 2.0, \"tunnel\": -3.0}", TR,
     "test_wind_zones_gusts_and_fades", "Wind im Tunnel 0 dB (AU-R)"),
    ("M32", IA, "return closing_kmh >= _glass_from or _rng.randf() < _glass_chance",
     "return closing_kmh > _glass_from + 0.5 or _rng.randf() < _glass_chance", TR, "test_collision_variety",
     "Glas ab genau 80 km/h"),
]


def run_filter(filt: str, tag: str) -> tuple[int, list[str], str]:
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = S + "/xdg/mut"
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    cmd = ["nice", "-n", "19", "timeout", "600", "godot", "--headless", "--path", MUT, "-s", "res://tests/run_tests.gd",
           "--", "--filter=" + filt]
    t = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, env=env)
    out = p.stdout + p.stderr
    with open(f"{S}/logs/mut_{tag}.log", "w") as fh:
        fh.write(out)
    fails = [ln.split("::")[1].strip() for ln in out.splitlines() if ln.startswith("FAIL") and "::" in ln]
    errs = [ln for ln in out.splitlines() if "SCRIPT ERROR" in ln or "Parse Error" in ln]
    return p.returncode, fails, f"{time.time() - t:.0f}s" + (f" errors={len(errs)}" if errs else "")


def main() -> None:
    want = set(sys.argv[1:])
    res_path = S + "/res/mutations.json"
    results = json.load(open(res_path)) if os.path.exists(res_path) else {}
    for mid, f, old, new, filt, claim, rule in MUTS:
        if want and mid not in want:
            continue
        path = os.path.join(MUT, f)
        src = open(path, encoding="utf-8").read()
        n = src.count(old)
        if n != 1:
            print(f"{mid}: old text found {n} times – skipped")
            results[mid] = {"error": f"old text found {n} times"}
            continue
        open(path, "w", encoding="utf-8").write(src.replace(old, new))
        try:
            code, fails, info = run_filter(filt, mid)
        finally:
            open(path, "w", encoding="utf-8").write(src)
        results[mid] = {"file": f, "rule": rule, "claim": claim, "filter": filt, "exit": code, "failed": fails, "info": info,
                        "caught": len(fails) > 0}
        print(f"{mid} {'GEFANGEN' if fails else 'NICHT GEFANGEN'} exit={code} fails={fails} ({info}) – {rule}")
        json.dump(results, open(res_path, "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
