import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''var _alive_t := 0.0
var _streams: Dictionary = {}            ## piece id -> AudioStreamInteractive (built once per profile)''',
'''var _alive_t := 0.0
var _streams: Dictionary = {}            ## piece id -> AudioStreamInteractive (built once per profile)
## The clock of the scheduled start: the session's countdown runs in physics steps, so the start is counted in
## physics steps too (Engine.get_physics_frames(), without the paused ones) – a long frame, after which the physics
## catches up or drops time, then shifts the countdown and the music alike. Without physics (unit tests, tools that
## drive the slots themselves) the frame time counts once no physics step has come for WAIT_NO_PHYSICS_S.
var _sched_left := 0.0
var _phys_seen := 0
var _phys_steps := 0
var _wait_dt := 0.0
const WAIT_NO_PHYSICS_S := 0.25'''),
('''		"stage_start":
			if race_phase == RACE_ARMED:
				var countdown := maxf(float(args.get("countdown_s", 0.0)), 0.0)
				start_in = maxf(countdown - float(_race_piece.get("countin_s", 0.0)), 0.0)
				race_phase = RACE_WAITING
		"countdown":
			# each new countdown number is n seconds before "LOS!": schedule from the latest one – the start does not
			# depend on how evenly the frames of the first second came (loading hitches, catch-up of the physics)
			if race_phase == RACE_WAITING:
				var left := float(args.get("n", 0)) - float(_race_piece.get("countin_s", 0.0))
				if left >= 0.0:
					start_in = left''',
'''		"stage_start":
			if race_phase == RACE_ARMED:
				var countdown := maxf(float(args.get("countdown_s", 0.0)), 0.0)
				_schedule(maxf(countdown - float(_race_piece.get("countin_s", 0.0)), 0.0))
				race_phase = RACE_WAITING
		"countdown":
			# each new countdown number is n seconds before "LOS!": schedule from the latest one
			if race_phase == RACE_WAITING:
				var left := float(args.get("n", 0)) - float(_race_piece.get("countin_s", 0.0))
				if left >= 0.0:
					_schedule(left)'''),
('''func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0''',
'''func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0


## The start comes `left` seconds of game time after now (called from the session's events, inside a physics step).
func _schedule(left: float) -> void:
	_sched_left = left
	start_in = left
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0


## Game seconds since the last _schedule(): physics steps × their length, or the frame time without physics.
func _waited(frame: ModernAudioFrame) -> float:
	var now := Engine.get_physics_frames()
	if not frame.paused:
		_phys_steps += now - _phys_seen
		_wait_dt += frame.dt
	_phys_seen = now
	if _phys_steps > 0:
		return _phys_steps * Engine.time_scale / float(Engine.physics_ticks_per_second)
	return _wait_dt if _wait_dt >= WAIT_NO_PHYSICS_S else 0.0'''),
('''		RACE_WAITING:
			if not frame.paused:
				start_in -= frame.dt
				# start in the frame nearest to the planned moment (the next frame would be about frame.dt late):
				# the start is off by at most half a frame instead of up to a whole one
				if start_in <= 0.5 * frame.dt:
					_start_race()''',
'''		RACE_WAITING:
			start_in = _sched_left - _waited(frame)
			# start in the frame nearest to the planned moment (the next frame would be about frame.dt late):
			# the start is off by at most half a frame instead of up to a whole one
			if not frame.paused and start_in <= 0.5 * frame.dt:
				_start_race()'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("ok")
