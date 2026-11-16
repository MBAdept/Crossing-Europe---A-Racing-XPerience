extends SceneTree
## Scratch probe (not part of the repository): boots the game like a normal start (main scene -> GameFlow) and logs,
## frame by frame, the clock of GameFlow's Screenshotter and the simulation steps of the race session that an
## attract demo started. Prints the state of the frame in which the clock passed each shot time.
##   godot --path . --fixed-fps 60 -s attract_state.gd -- --attract-after=1 --attract-scene=hamburg \
##       --screenshot=<prefix> --shot-times=6 --graphics=arcade|modern
var _frame := 0
var _log: Array = []
var _printed := 0


func _initialize() -> void:
	change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


func _find_session(n: Node) -> Node:
	if n.get("_sim_steps") != null and n.get("plan") != null:
		return n
	for c in n.get_children():
		var r := _find_session(c)
		if r != null:
			return r
	return null


func _process(_delta: float) -> bool:
	_frame += 1
	var shot: Node = null
	for c in root.get_children():
		if c is Screenshotter:
			shot = c
	var sess := _find_session(root)
	var row := {"frame": _frame, "t": float(shot.get("_t")) if shot != null else -1.0, "next": int(shot.get("_next")) if shot != null else -1,
		"steps": int(sess.get("_sim_steps")) if sess != null else -1, "pos_z": float(sess.get("pos_z")) if sess != null else -1.0,
		"speed": float(sess.get("speed")) if sess != null and sess.get("speed") != null else -1.0,
		"gfx": str(sess.get("gfx")) if sess != null else "", "preparing": Screenshotter.preparing}
	_log.append(row)
	if shot != null and int(row["next"]) > _printed:
		_printed = int(row["next"])
		# the row before this one is the frame whose _process took the shot decision
		print("STATE-AT-SHOT ", JSON.stringify(_log[_log.size() - 2]), " -> ", JSON.stringify(row))
	return false


func _finalize() -> void:
	var first_demo := -1
	var prep := 0
	for r: Dictionary in _log:
		if int(r["steps"]) >= 0 and first_demo < 0:
			first_demo = int(r["frame"])
		if int(r["preparing"]) > 0:
			prep += 1
	print("STATE-END frames ", _frame, ", demo scene first seen in frame ", first_demo, ", frames with preparing > 0: ", prep,
		", last ", JSON.stringify(_log[_log.size() - 1]))
