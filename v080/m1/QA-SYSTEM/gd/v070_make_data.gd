extends SceneTree
## QA-SYSTEM: runs in the v0.7.0 reference tree. Writes a realistic v0.7.0 user folder: settings with non-default
## values (fullscreen chosen OFF, volumes, vibration off, name with umlaut, leaderboard filter), two leaderboard
## entries (stage + race board). The savegame is written separately by run_race.gd --max-legs=1.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var st: Node = root.get_node("Settings")
	st.set("master_volume", 0.55)
	st.set("sfx_volume", 0.35)
	st.set("music_volume", 0.25)
	st.set("fullscreen", false)
	st.set("vibration", false)
	st.set("player_name", "Jörg Ü")
	st.set("leaderboard_filter", "kompakt")
	var ok: bool = st.call("save_settings")
	print("SETTINGS saved ", ok, " ", JSON.stringify(st.call("to_dict")))
	var lb: Node = root.get_node("Leaderboards")
	var e1 := {"name": "Jörg Ü", "time_s": 301.5, "avg_kmh": 113.4, "vehicle": "kompakt", "weather": "normal",
		"start_hour": 12.0, "daytime": "day", "date": "2026-10-01"}
	var r1: int = lb.call("submit", "stage:kiel_hamburg:fwd", e1, "")
	var e2 := {"name": "Jörg Ü", "time_s": 12345.0, "avg_kmh": 101.0, "vehicle": "limousine", "weather": "rain",
		"start_hour": 8.0, "daytime": "day", "date": "2026-10-02", "route": ["kiel", "hamburg", "hannover"]}
	var r2: int = lb.call("submit", "race:kiel_nuernberg", e2, "")
	print("LB ranks ", r1, " ", r2, " keys=", lb.call("board_keys"))
	quit(0)
