extends RefCounted
## Frame-time probe of the mode "Modern" (v0.8.0, contract §4.4.5, D34 c): the wall clock between the render() calls
## of a stage – median and 95th percentile of the last WINDOW frames for perf_stats(), the longest frame of the
## first seconds of a stage for the shader warm-up check – and the slowness watchdog of the countdown.
##
## Watchdog (pure state machine, unit tested): while the countdown runs (view.countdown > 0) the frame times are
## collected, the first SKIP_S seconds left out (the loading cover has just gone). Once MIN_FRAMES frames and
## MIN_S seconds are in, the window is judged ONCE per stage: Gfx.watchdog_verdict() against the display's frame
## time (at least 1/60 s – a 144 Hz display is not a reason to call 60 fps slow), or a median frame rate below
## graphics.watchdog.countdown_min_fps. "slow" asks the renderer to step the preset down one step (it emits
## quality_lowered(preset)); with nothing lower left the verdict stays "too_slow" for the result screen.
## The watchdog is off in the deterministic test mode (--gfx-sync, Rule 10), with --no-watchdog, headless and
## for a stage without a countdown.
## Loaded by modern_renderer.gd only (no class name). Owner: renderer core (R1).

const WINDOW := 240                ## frames behind frame_ms_median / frame_ms_p95
const START_S := 30.0              ## the longest frame is recorded for this long after the start of a stage
const SKIP_S := 0.4
const MIN_S := 1.0
const MIN_FRAMES := 20
const MAX_FRAME_MS := 1000.0       ## a longer gap is a pause (window minimised, debugger), not a frame

var enabled := false               ## the watchdog judges this stage
var verdict := ""                  ## "" (not judged) | "ok" | "slow" | "too_slow"
var judged_median_ms := 0.0
var judged_p95_ms := 0.0
var judged_frames := 0
var target_ms := 1000.0 / 60.0
var min_fps := 30.0
var wd_cfg: Dictionary = {}

var _us := PackedInt32Array()
var _i := 0
var _last_tick := 0
var _frames := 0
var _start_us := 0
var _start_max_us := 0
var _start_frames := PackedInt32Array()   ## every frame of the first START_S seconds (warm-up check)
var _count_us := PackedInt32Array()
var _count_t := 0.0


## cfg_watchdog = config graphics.watchdog; display_hz = refresh rate of the screen (<= 0: unknown), frame_cap =
## Engine.max_fps (0 = none).
func configure(cfg_watchdog: Dictionary, display_hz: float, frame_cap: int, on: bool) -> void:
	wd_cfg = cfg_watchdog
	min_fps = maxf(1.0, float(cfg_watchdog.get("countdown_min_fps", Gfx.DEFAULT_WATCHDOG["countdown_min_fps"])))
	target_ms = target_frame_ms(display_hz, frame_cap)
	enabled = on


## Frame time the watchdog judges against: the display's (or the frame cap's, whichever is longer), at least 1/60 s.
static func target_frame_ms(display_hz: float, frame_cap: int) -> float:
	var hz := display_hz if display_hz > 1.0 and is_finite(display_hz) else 60.0
	if frame_cap > 0:
		hz = minf(hz, float(frame_cap))
	return maxf(1000.0 / hz, 1000.0 / 60.0)


## One render() call of a prepared stage at wall clock `now_us`. Returns the time since the last one in µs (0 for the
## first frame).
func frame(now_us: int) -> int:
	var us := 0
	if _last_tick > 0:
		us = now_us - _last_tick
		if _us.size() < WINDOW:
			_us.append(us)
		else:
			_us[_i] = us
			_i = (_i + 1) % WINDOW
		if now_us - _start_us <= int(START_S * 1.0e6):
			_start_frames.append(us)
			_start_max_us = maxi(_start_max_us, us)
	else:
		_start_us = now_us
	_last_tick = now_us
	_frames += 1
	return us


## Feeds the watchdog with the frame of `us` µs while the countdown shows `countdown` seconds (<= 0: it is over).
## lowest = the lowest preset is in use. Returns "slow" in the one frame in which the renderer has to step the
## preset down, "" otherwise.
func watch(us: int, countdown: float, lowest: bool) -> String:
	if not enabled or verdict != "" or us <= 0 or float(us) > MAX_FRAME_MS * 1000.0:
		return ""
	if countdown <= 0.0:
		if _count_us.size() >= MIN_FRAMES and _count_t - SKIP_S >= MIN_S * 0.5:
			return _judge(lowest)
		enabled = false          # the countdown was too short to judge anything
		return ""
	_count_t += float(us) / 1.0e6
	if _count_t <= SKIP_S:
		return ""
	_count_us.append(us)
	if _count_us.size() >= MIN_FRAMES and _count_t - SKIP_S >= MIN_S:
		return _judge(lowest)
	return ""


func _judge(lowest: bool) -> String:
	var sorted := _count_us.duplicate()
	sorted.sort()
	judged_frames = sorted.size()
	judged_median_ms = float(sorted[sorted.size() / 2]) / 1000.0
	judged_p95_ms = float(sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))]) / 1000.0
	verdict = Gfx.watchdog_verdict(judged_median_ms, judged_p95_ms, target_ms, wd_cfg, lowest)
	if verdict == "ok" and judged_median_ms > 1000.0 / min_fps:
		verdict = "too_slow" if lowest else "slow"
	return "slow" if verdict == "slow" else ""


func median_ms() -> float:
	return _percentile(0.5)


func p95_ms() -> float:
	return _percentile(0.95)


func _percentile(q: float) -> float:
	if _us.is_empty():
		return 0.0
	var sorted := _us.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(float(sorted.size()) * q))]) / 1000.0


## Flat keys for perf_stats(): frame_ms_median, frame_ms_p95, start_frame_ms_max / start_frame_ms_median /
## start_frames (the first START_S seconds), watchdog, watchdog_median_ms, watchdog_p95_ms, watchdog_target_ms.
func stats() -> Dictionary:
	var start_median := 0.0
	if not _start_frames.is_empty():
		var s := _start_frames.duplicate()
		s.sort()
		start_median = float(s[s.size() / 2]) / 1000.0
	return {"frame_ms_median": median_ms(), "frame_ms_p95": p95_ms(), "start_frame_ms_max": float(_start_max_us) / 1000.0,
		"start_frame_ms_median": start_median, "start_frames": _start_frames.size(), "watchdog": verdict,
		"watchdog_median_ms": judged_median_ms, "watchdog_p95_ms": judged_p95_ms, "watchdog_target_ms": target_ms}


## The frames of the first START_S seconds in milliseconds (warm-up check).
func start_frames_ms() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_start_frames.size())
	for i in _start_frames.size():
		out[i] = float(_start_frames[i]) / 1000.0
	return out
