class_name Gfx
extends RefCounted
## Graphics mode ("arcade" | "modern") and the quality settings of the mode "Modern" (v0.8.0): pure static helpers
## without autoload access (unit tested, tests/unit/core/test_gfx_settings.gd) – which mode a run really gets, the
## sound profile that follows it, the tier of the graphics adapter, quality presets and their renderer parameters,
## the verdict of the slowness watchdog. The autoload Settings stores the player's choices and feeds these helpers
## with the command line, the configuration (config/game_config.json "graphics") and the crash-guard marker.
## Interfaces: docs/dev/v080_contract.md §4.1–§4.3, §4.10; ARCHITECTURE.md §15.

const ARCADE := "arcade"
const MODERN := "modern"
const MODES: Array[String] = [ARCADE, MODERN]
## Values of the setting "sound_profile" ("auto" = the sound follows the chosen graphics mode).
const SOUND_PROFILES: Array[String] = ["auto", ARCADE, MODERN]

## Quality presets of Modern in the order of the option row. "custom" = the single values were set by hand.
const PRESET_ORDER: Array[String] = ["deck", "low", "medium", "high", "custom"]
## Fields of a quality set: shadows 0..3 (Aus, Niedrig, Mittel, Hoch), details 0..2 (Niedrig, Mittel, Hoch),
## scale = 3D resolution in percent (one of SCALE_STEPS), aa 0..2 (Aus, MSAA 2×, MSAA 4×), effects 0..2 (Aus,
## Einfach, Voll).
const QUALITY_KEYS: Array[String] = ["shadows", "details", "scale", "aa", "effects"]
const SCALE_STEPS: Array[int] = [50, 67, 75, 85, 100, 125, 150]
const QUALITY_MAX := {"shadows": 3, "details": 2, "aa": 2, "effects": 2}

## Crash-guard marker: written before the first Modern scene of a run is built, removed once it has drawn for a
## while. Still there at the next start = Modern crashed or hung the last time -> that run starts in Arcade.
const BOOT_MARKER := "user://modern_start.lock"

## Start values of config graphics.presets – used where the configuration has no (valid) entry.
const DEFAULT_PRESETS := {
	"deck": {"shadows": 1, "details": 1, "scale": 100, "aa": 1, "effects": 1},
	"low": {"shadows": 0, "details": 0, "scale": 75, "aa": 0, "effects": 0},
	"medium": {"shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1},
	"high": {"shadows": 3, "details": 2, "scale": 100, "aa": 2, "effects": 2},
}
## Start values of config graphics.levels (contract §4.10): what each step of a quality value means for the
## renderer. levels() merges the entries of the chosen steps into one flat dictionary; the types below are binding
## (JSON numbers are converted), keys the configuration adds are passed through.
## shadow_casters: 0 none (blob shadows), 1 vehicles and structures, 2 + buildings and tree proxies, 3 + all props.
## shadow_splits: 1 = orthogonal. shadow_filter: 0 hard, 1 soft low, 2 soft medium.
const DEFAULT_LEVELS := {
	"shadows": [
		{"shadow_casters": 0, "shadow_splits": 1, "shadow_blend": false, "shadow_atlas": 1024, "shadow_distance_m": 0.0,
			"shadow_filter": 0, "blob_shadows": true},
		{"shadow_casters": 1, "shadow_splits": 2, "shadow_blend": false, "shadow_atlas": 2048, "shadow_distance_m": 80.0,
			"shadow_filter": 1, "blob_shadows": false},
		{"shadow_casters": 2, "shadow_splits": 2, "shadow_blend": false, "shadow_atlas": 2048, "shadow_distance_m": 120.0,
			"shadow_filter": 1, "blob_shadows": false},
		{"shadow_casters": 3, "shadow_splits": 4, "shadow_blend": true, "shadow_atlas": 4096, "shadow_distance_m": 200.0,
			"shadow_filter": 2, "blob_shadows": false},
	],
	"details": [
		{"vehicle_lod0_m": 25.0, "vehicle_lod1_m": 90.0, "prop_lod0_m": 40.0, "prop_lod1_m": 120.0, "deco_density": 0.6,
			"terrain_outer_m": 480.0},
		{"vehicle_lod0_m": 40.0, "vehicle_lod1_m": 120.0, "prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "deco_density": 1.0,
			"terrain_outer_m": 480.0},
		{"vehicle_lod0_m": 60.0, "vehicle_lod1_m": 160.0, "prop_lod0_m": 120.0, "prop_lod1_m": 350.0, "deco_density": 1.3,
			"terrain_outer_m": 1000.0},
	],
	"aa": [0, 2, 4],
	"effects": [
		{"glow": false, "particles": 300, "spray": false, "wet_reflections": false, "ssao": false, "ssao_quality": 0,
			"sky_reflections": false, "omni_pool": 2},
		{"glow": true, "particles": 1500, "spray": true, "wet_reflections": false, "ssao": false, "ssao_quality": 0,
			"sky_reflections": true, "omni_pool": 4},
		{"glow": true, "particles": 4000, "spray": true, "wet_reflections": true, "ssao": true, "ssao_quality": 1,
			"sky_reflections": true, "omni_pool": 8},
	],
}
## Start values of config graphics.watchdog. slow_factor / too_slow_factor: watchdog_verdict() below.
## countdown_min_fps is not read by anything in this file: it belongs to the renderer's watchdog
## (scripts/race3d/perf_probe.gd, renderer package of wave 1; tuned by the performance package of wave 8), which
## steps the preset down once during the countdown when the measured frame rate there is below it (contract D34 c).
const DEFAULT_WATCHDOG := {"countdown_min_fps": 30.0, "slow_factor": 1.3, "too_slow_factor": 2.0}
## Frame time watchdog_verdict() judges against when the caller has no usable target (60 Hz).
const WATCHDOG_FALLBACK_TARGET_MS := 1000.0 / 60.0
## Shortest frame time watchdog_verdict() judges against: 60 pictures per second are never "slow", whatever the
## display could show – on a 120 or 144 Hz screen a steady 60 fps would otherwise step the quality down (A-2).
const WATCHDOG_MIN_TARGET_MS := 1000.0 / 60.0
## Leistungstest: the next higher preset is suggested when the slowest scene needs at most 1 / BENCH_HEADROOM of
## the target frame time (and its 99th percentile stays inside the target).
const BENCH_HEADROOM := 1.5

## Adapter tiers (classify_adapter): "software" = CPU rasteriser (llvmpipe, SwiftShader, WARP …); "weak" = old or
## small integrated graphics; "deck" = Steam Deck APU (or an AMD handheld under gamescope); "ok" = everything else.
const SOFTWARE_HINTS: Array[String] = ["llvmpipe", "softpipe", "swiftshader", "lavapipe", "basic render", "gdi generic",
	"warp", "software"]
const DECK_HINTS: Array[String] = ["vangogh", "van gogh", "custom gpu 0405", "custom gpu 0932", "sephiroth"]
## Intel "HD Graphics" and "UHD Graphics" are judged in classify_adapter (UHD 7xx is not weak).
const WEAK_HINTS: Array[String] = ["iris graphics", "gma ", "radeon hd", "radeon r5", "radeon r7", "geforce gt ",
	"geforce 9", "geforce 6", "geforce 7", "geforce 8", "videocore", "mali", "adreno", "powervr"]


## Tier of a graphics adapter – "software" | "weak" | "deck" | "ok" – from its name and vendor
## (RenderingServer.get_video_adapter_name() / _vendor()), the API string (get_video_adapter_api_version(); a
## software path behind ANGLE shows up there) and whether the game runs under gamescope. By name: the adapter
## type is always "other" in the Compatibility renderer.
static func classify_adapter(adapter: String, vendor: String = "", api: String = "", gamescope: bool = false) -> String:
	var n := (adapter + " " + vendor).to_lower()
	var with_api := n + " " + api.to_lower()
	for h in SOFTWARE_HINTS:
		if with_api.contains(h):
			return "software"
	for h in DECK_HINTS:
		if n.contains(h):
			return "deck"
	if gamescope and (n.contains("amd") or n.contains("radeon")):
		return "deck"
	# Intel: "HD Graphics" (until 2017) and "UHD Graphics" up to the 6xx series and without a number are weak; the
	# "UHD Graphics 7xx" of the desktop chips since 2021 is not
	if n.contains("hd graphics") and not n.contains("uhd graphics 7"):
		return "weak"
	for h in WEAK_HINTS:
		if n.contains(h):
			return "weak"
	return "ok"


## The mode the first-start chooser preselects: Modern for the tiers deck / ok, Arcade for software / weak.
static func recommended_mode(tier: String) -> String:
	return MODERN if tier == "deck" or tier == "ok" else ARCADE


## Quality preset recommended for an adapter tier.
static func recommended_preset(tier: String) -> String:
	match tier:
		"deck":
			return "deck"
		"weak", "software":
			return "low"
	return "medium"


## The graphics mode of a run (contract D32): command line --graphics= > config graphics.force_mode > crash-guard
## marker of the last run (-> Arcade) > the player's stored choice > Arcade. `chosen` "" = no choice stored yet:
## the game is Arcade then, so every existing tool, test and command line start behaves as before v0.8.0.
## Returns {"mode": "arcade"|"modern", "reason": "" (as chosen) | "cli" | "config" | "crash_guard" | "default"}.
## With a stored choice "arcade" the marker changes nothing (reason "").
static func resolve_mode(chosen: String, cli: String, force: String, marker: bool) -> Dictionary:
	if MODES.has(cli):
		return {"mode": cli, "reason": "cli"}
	if MODES.has(force):
		return {"mode": force, "reason": "config"}
	if marker and chosen != ARCADE:
		return {"mode": ARCADE, "reason": "crash_guard"}
	if MODES.has(chosen):
		return {"mode": chosen, "reason": ""}
	return {"mode": ARCADE, "reason": "default"}


## The sound profile of a run – "arcade" | "modern" (contract D31): command line --sound= > config audio.profile >
## the setting `profile`; "auto" follows the CHOSEN graphics mode (not the effective one: a graphics fallback or a
## --graphics= of a test never changes the sound), Arcade while nothing is chosen.
static func resolve_sound(profile: String, chosen_graphics: String, cli: String = "", force: String = "") -> String:
	if MODES.has(cli):
		return cli
	if MODES.has(force):
		return force
	if MODES.has(profile):
		return profile
	return chosen_graphics if MODES.has(chosen_graphics) else ARCADE


## Quality set of a preset: {"preset", "shadows", "details", "scale", "aa", "effects"}. `presets` = config
## graphics.presets (missing or damaged entries fall back to DEFAULT_PRESETS). "custom" takes the values of
## `custom`, completed from "medium"; an unknown preset id counts as "medium".
static func quality(preset: String, custom: Dictionary, presets: Dictionary) -> Dictionary:
	var id := preset
	var q: Dictionary
	if id == "custom":
		q = preset_values("medium", presets)
		for k in QUALITY_KEYS:
			if custom.has(k):
				q[k] = custom[k]
		q = sanitized(q)
	else:
		if not DEFAULT_PRESETS.has(id):
			id = "medium"
		q = preset_values(id, presets)
	q["preset"] = id
	return q


## The five values of a fixed preset (deck, low, medium, high) from the configuration, clamped.
static func preset_values(id: String, presets: Dictionary) -> Dictionary:
	var base: Dictionary = DEFAULT_PRESETS.get(id, DEFAULT_PRESETS["medium"])
	var v: Variant = presets.get(id, null)
	if not (v is Dictionary):
		return sanitized(base)
	var q := base.duplicate()
	for k in QUALITY_KEYS:
		if (v as Dictionary).has(k) and _is_number((v as Dictionary)[k]):
			q[k] = (v as Dictionary)[k]
	return sanitized(q)


## Id of the fixed preset whose values equal `q` ("custom" if none does).
static func preset_of(q: Dictionary, presets: Dictionary) -> String:
	var s := sanitized(q)
	for id in PRESET_ORDER:
		if id != "custom" and s == preset_values(id, presets):
			return id
	return "custom"


## The five quality values of `q`, each forced into its range (a hand-edited settings file or command line must
## not break the renderer): missing or non-numeric values and NaN = "medium", the scale snaps to the nearest
## SCALE_STEPS. The range is applied to the float before it becomes an integer – a huge number (--gfx=aa=1e30,
## scale=-1e400) would overflow the integer and come out at the wrong end.
static func sanitized(q: Dictionary) -> Dictionary:
	var medium: Dictionary = DEFAULT_PRESETS["medium"]
	var out := {}
	for k in QUALITY_KEYS:
		var raw: Variant = q.get(k, null)
		var f := float(raw) if _is_number(raw) and not is_nan(float(raw)) else float(medium[k])
		if k == "scale":
			var v := int(round(clampf(f, float(SCALE_STEPS[0]), float(SCALE_STEPS[SCALE_STEPS.size() - 1]))))
			var best := SCALE_STEPS[0]
			for s in SCALE_STEPS:
				if absi(s - v) < absi(best - v):
					best = s
			out[k] = best
		else:
			out[k] = int(round(clampf(f, 0.0, float(QUALITY_MAX[k]))))
	return out


## `q` with the overrides of the command line: --gfx-preset=deck|low|medium|high replaces the whole set,
## --gfx=shadows=0,scale=75,… single values (keys of QUALITY_KEYS; anything else is ignored). With single values
## the "preset" of the result names the fixed preset they equal, else "custom".
static func with_cli(q: Dictionary, preset_arg: String, set_arg: String, presets: Dictionary) -> Dictionary:
	var out := q.duplicate()
	if DEFAULT_PRESETS.has(preset_arg):
		out = quality(preset_arg, {}, presets)
	var changed := false
	for part in set_arg.split(",", false):
		var kv := part.split("=", true, 1)
		var k := kv[0].strip_edges()
		if kv.size() == 2 and QUALITY_KEYS.has(k) and kv[1].strip_edges().is_valid_float():
			out[k] = kv[1].strip_edges().to_float()
			changed = true
	if changed:
		var id := preset_of(out, presets)
		out = sanitized(out)
		out["preset"] = id
	return out


## Renderer parameters of a quality set (ModernRenderer.apply_quality): the set itself ("preset", the five values)
## plus the entries of config graphics.levels for its steps, flat – shadow_casters, shadow_splits, shadow_blend,
## shadow_atlas, shadow_distance_m, shadow_filter, blob_shadows, vehicle_lod0_m, vehicle_lod1_m, prop_lod0_m,
## prop_lod1_m, deco_density, terrain_outer_m, glow, particles, spray, wet_reflections, ssao, ssao_quality,
## sky_reflections, omni_pool, msaa (0, 2, 4), scale_3d (0.5 … 1.5). `gfx_cfg` = config section "graphics".
static func levels(q: Dictionary, gfx_cfg: Dictionary) -> Dictionary:
	var s := sanitized(q)
	var presets: Variant = gfx_cfg.get("presets", {})
	var lv: Variant = gfx_cfg.get("levels", {})
	var table: Dictionary = lv if lv is Dictionary else {}
	var out := {"preset": str(q.get("preset", preset_of(s, presets if presets is Dictionary else {})))}
	out.merge(s)
	for key: String in ["shadows", "details", "effects"]:
		out.merge(_level_entry(table, key, int(s[key])))
	var aa_default: Array = DEFAULT_LEVELS["aa"]
	var aa: Variant = table.get("aa", null)
	var msaa := int(aa_default[int(s["aa"])])
	if aa is Array and (aa as Array).size() > int(s["aa"]) and _is_number((aa as Array)[int(s["aa"])]):
		msaa = int((aa as Array)[int(s["aa"])])
	out["msaa"] = msaa if [0, 2, 4, 8].has(msaa) else int(aa_default[int(s["aa"])])
	out["scale_3d"] = float(s["scale"]) / 100.0
	return out


## Entry `index` of a level table: the defaults, overlaid with the configuration's entry (values converted to the
## type of the default; additional keys kept as they are).
static func _level_entry(table: Dictionary, key: String, index: int) -> Dictionary:
	var defaults: Array = DEFAULT_LEVELS[key]
	var out: Dictionary = (defaults[clampi(index, 0, defaults.size() - 1)] as Dictionary).duplicate()
	var list: Variant = table.get(key, null)
	if not (list is Array) or (list as Array).size() <= index or not ((list as Array)[index] is Dictionary):
		return out
	var entry: Dictionary = (list as Array)[index]
	for k: Variant in entry:
		var v: Variant = entry[k]
		if not out.has(k):
			out[k] = v
		elif out[k] is bool:
			if v is bool:
				out[k] = v
		elif _is_number(v):
			if out[k] is int:
				out[k] = int(round(float(v)))
			else:
				out[k] = float(v)
	return out


## Verdict of the slowness watchdog for a measured window of a stage driven in Modern: "ok" | "slow" (step the
## preset down once / suggest a lower one) | "too_slow" (nothing lower is left: offer Arcade). median_ms / p95_ms =
## frame times of the window, target_ms = frame time of the display refresh or the frame cap (a Steam Deck capped
## at 40 Hz is not slow at 25 ms), wd_cfg = config graphics.watchdog (slow_factor, too_slow_factor), lowest = the
## lowest preset is already in use. A target of 0 or less (or NaN) means "unknown" – DisplayServer.
## screen_get_refresh_rate() returns -1 when it cannot tell – and is judged against 60 Hz
## (WATCHDOG_FALLBACK_TARGET_MS), never as "everything is too slow".
## The verdict is taken against max(target_ms, 1/60 s) (WATCHDOG_MIN_TARGET_MS, A-2): a display faster than 60 Hz
## does not make 60 pictures per second "slow" – at 144 Hz (6.9 ms) a steady 16.7 ms would be 2.4 × the target.
static func watchdog_verdict(median_ms: float, p95_ms: float, target_ms: float, wd_cfg: Dictionary, lowest: bool) -> String:
	var slow_f := maxf(1.0, _num(wd_cfg.get("slow_factor", null), float(DEFAULT_WATCHDOG["slow_factor"])))
	var bad_f := maxf(slow_f, _num(wd_cfg.get("too_slow_factor", null), float(DEFAULT_WATCHDOG["too_slow_factor"])))
	var t := watchdog_target_ms(target_ms)
	if median_ms > t * bad_f or p95_ms > t * bad_f * 2.0:
		return "too_slow" if lowest else "slow"
	if median_ms > t * slow_f:
		return "slow"
	return "ok"


## The frame time watchdog_verdict() really judges against: `target_ms` (frame time of the display refresh or of the
## frame cap), 60 Hz when it is unknown (0 or less, NaN, infinite), and never less than 1/60 s.
static func watchdog_target_ms(target_ms: float) -> float:
	var t := target_ms if target_ms > 0.0 and is_finite(target_ms) else WATCHDOG_FALLBACK_TARGET_MS
	return maxf(t, WATCHDOG_MIN_TARGET_MS)


## Target frame time in ms for a display refresh rate in Hz (DisplayServer.screen_get_refresh_rate(); -1 or 0 =
## unknown -> 60 Hz), never shorter than 1/60 s.
static func target_ms_for_refresh(refresh_hz: float) -> float:
	return watchdog_target_ms(1000.0 / refresh_hz if refresh_hz > 0.0 and is_finite(refresh_hz) else -1.0)


## The one-time chooser "GRAFIK WÄHLEN" is due at this start (contract D32): no graphics mode is stored yet – new
## and existing players alike, so nobody is switched silently –, the game was started without any user argument
## (every tool, test and command line start passes at least one: they keep behaving as before v0.8.0), with a
## display, and the configuration forces no mode (the choice would do nothing). `user_args` = number of arguments
## after "--" (OS.get_cmdline_user_args().size()).
static func chooser_due(chosen: String, user_args: int, headless: bool, force: String = "") -> bool:
	return not MODES.has(chosen) and user_args <= 0 and not headless and not MODES.has(force)


# --- Leistungstest (built-in benchmark of the mode "Modern") ---------------------------------------------------

## Statistics of a measured window: `frame_ms` = duration of every frame in milliseconds (wall clock).
## {"frames", "avg_fps" (frames / total time), "low1_fps" (1000 / mean of the slowest 1 % of the frames, at least
## one frame – the usual "1 % low"), "frame_ms_median", "frame_ms_p95", "frame_ms_p99", "frame_ms_max"}; all 0
## for an empty window. Percentiles by nearest rank. Frame times that are not positive and finite are left out.
static func frame_stats(frame_ms: PackedFloat32Array) -> Dictionary:
	var sorted := PackedFloat32Array()
	var total := 0.0
	for v in frame_ms:
		if v > 0.0 and is_finite(v):
			sorted.append(v)
			total += v
	var n := sorted.size()
	if n == 0 or total <= 0.0:
		return {"frames": 0, "avg_fps": 0.0, "low1_fps": 0.0, "frame_ms_median": 0.0, "frame_ms_p95": 0.0,
			"frame_ms_p99": 0.0, "frame_ms_max": 0.0}
	sorted.sort()
	var worst := maxi(1, int(ceil(float(n) * 0.01)))
	var worst_sum := 0.0
	for i in worst:
		worst_sum += sorted[n - 1 - i]
	return {"frames": n, "avg_fps": float(n) * 1000.0 / total, "low1_fps": 1000.0 * float(worst) / worst_sum,
		"frame_ms_median": _percentile(sorted, 0.5), "frame_ms_p95": _percentile(sorted, 0.95),
		"frame_ms_p99": _percentile(sorted, 0.99), "frame_ms_max": sorted[n - 1]}


## Nearest-rank percentile of an ascending list (p in 0..1).
static func _percentile(sorted: PackedFloat32Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(ceil(p * float(sorted.size()))) - 1, 0, sorted.size() - 1)]


## Rough cost of a quality set, only to order sets: the sum of the four steps plus the 3D resolution (25 % = one
## step). low −1, deck 4, medium 5, high 9 with the start values.
static func quality_cost(q: Dictionary) -> float:
	var s := sanitized(q)
	return float(int(s["shadows"]) + int(s["details"]) + int(s["aa"]) + int(s["effects"])) + (float(s["scale"]) - 100.0) / 25.0


## The fixed presets a machine of `tier` is offered, cheapest first ("deck" only on the Steam Deck tier).
static func preset_ladder(tier: String, presets: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in PRESET_ORDER:
		if id == "custom" or (id == "deck" and tier != "deck"):
			continue
		out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return quality_cost(preset_values(a, presets)) < quality_cost(preset_values(b, presets)))
	return out


## What the Leistungstest suggests after measuring `scenes` (entries with "id", "frame_ms_median", "frame_ms_p95",
## "frame_ms_p99", "frames") with the quality set `q` ({"preset", five values}): the slowest scene decides.
## {"verdict": "ok" | "slow" | "too_slow" | "" (nothing measured), "suggested_preset", "suggested_mode": "modern" |
## "arcade", "worst": scene id, "headroom": target frame time / median of that scene}.
## too_slow (already at the cheapest preset and still far too slow) -> Arcade; slow -> the next cheaper preset;
## ok with BENCH_HEADROOM to spare -> the next more expensive one; else the preset stays. target_ms = frame time
## judged against (target_ms_for_refresh), gfx_cfg = config "graphics" (presets, watchdog).
static func bench_suggestion(q: Dictionary, scenes: Array, target_ms: float, tier: String, gfx_cfg: Dictionary) -> Dictionary:
	var p: Variant = gfx_cfg.get("presets", {})
	var presets: Dictionary = p if p is Dictionary else {}
	var w: Variant = gfx_cfg.get("watchdog", {})
	var wd: Dictionary = w if w is Dictionary else {}
	var current := str(q.get("preset", preset_of(q, presets)))
	var out := {"verdict": "", "suggested_preset": current, "suggested_mode": MODERN, "worst": "", "headroom": 0.0}
	var worst: Dictionary = {}
	for s: Variant in scenes:
		if s is Dictionary and int((s as Dictionary).get("frames", 0)) > 0 and _num((s as Dictionary).get("frame_ms_median", null), 0.0) > 0.0:
			if worst.is_empty() or float((s as Dictionary)["frame_ms_median"]) > float(worst["frame_ms_median"]):
				worst = s
	if worst.is_empty():
		return out
	var t := watchdog_target_ms(target_ms)
	var ladder := preset_ladder(tier, presets)
	var cost := quality_cost(q)
	var cheaper := ""
	var dearer := ""
	for id in ladder:
		var c := quality_cost(preset_values(id, presets))
		if c < cost - 0.001:
			cheaper = id            # the ladder rises: the last one below is the nearest
		elif c > cost + 0.001 and dearer == "":
			dearer = id
	var median := float(worst["frame_ms_median"])
	var verdict := watchdog_verdict(median, _num(worst.get("frame_ms_p95", null), median), t, wd, cheaper == "")
	out["verdict"] = verdict
	out["worst"] = str(worst.get("id", ""))
	out["headroom"] = t / median
	if verdict == "too_slow":
		out["suggested_mode"] = ARCADE
		if not ladder.is_empty():
			out["suggested_preset"] = ladder[0]
	elif verdict == "slow":
		if cheaper != "":
			out["suggested_preset"] = cheaper
	elif dearer != "" and median * BENCH_HEADROOM <= t and _num(worst.get("frame_ms_p99", null), median) <= t:
		out["suggested_preset"] = dearer
	return out


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _num(v: Variant, default: float) -> float:
	return float(v) if _is_number(v) else default
