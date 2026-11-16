import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''var _sched_left := 0.0
var _phys_seen := 0
var _phys_steps := 0
var _wait_dt := 0.0
const WAIT_NO_PHYSICS_S := 0.25''',
'''var _sched_left := 0.0
var _phys_seen := 0
var _phys_steps := 0
var _wait_dt := 0.0
var _physics_runs := false               ## a physics step came while waiting: race_t is counted in steps too
const WAIT_NO_PHYSICS_S := 0.25'''),
('''		"go":
			if race_phase == RACE_ARMED or race_phase == RACE_WAITING:
				_start_race()
			if race_phase == RACE_PLAYING and is_nan(go_offset_s):
				go_offset_s = race_t - float(_race_piece.get("countin_s", 0.0))''',
'''		"go":
			if race_phase == RACE_ARMED or race_phase == RACE_WAITING:
				_start_race()
			if race_phase == RACE_PLAYING and is_nan(go_offset_s):
				# "go" comes inside a physics step: count the steps since the last frame as well
				var steps := _phys_steps + (Engine.get_physics_frames() - _phys_seen)
				var t := steps * _step_s() if _physics_runs else race_t
				go_offset_s = t - float(_race_piece.get("countin_s", 0.0))'''),
('''func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0''',
'''func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0
	# from here on the same physics clock measures how long the piece has played
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0


## Game seconds per physics step (the countdown's dt).
static func _step_s() -> float:
	return Engine.time_scale / float(Engine.physics_ticks_per_second)'''),
('''	_sched_left = left
	start_in = left
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0''',
'''	_sched_left = left
	start_in = left
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0
	_physics_runs = false'''),
('''	var now := Engine.get_physics_frames()
	if not frame.paused:
		_phys_steps += now - _phys_seen
		_wait_dt += frame.dt
	_phys_seen = now
	if _phys_steps > 0:
		return _phys_steps * Engine.time_scale / float(Engine.physics_ticks_per_second)
	return _wait_dt if _wait_dt >= WAIT_NO_PHYSICS_S else 0.0''',
'''	var now := Engine.get_physics_frames()
	if not frame.paused:
		_phys_steps += now - _phys_seen
		_wait_dt += frame.dt
	_phys_seen = now
	if _phys_steps > 0:
		_physics_runs = true
		return _phys_steps * _step_s()
	return _wait_dt if _wait_dt >= WAIT_NO_PHYSICS_S else 0.0'''),
('''		RACE_PLAYING, RACE_ENDING:
			if not frame.paused:
				race_t += frame.dt''',
'''		RACE_PLAYING, RACE_ENDING:
			if _physics_runs:
				var now := Engine.get_physics_frames()
				if not frame.paused:
					_phys_steps += now - _phys_seen
				_phys_seen = now
				race_t = _phys_steps * _step_s()
			elif not frame.paused:
				race_t += frame.dt'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("ok")
