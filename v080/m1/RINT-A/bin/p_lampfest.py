import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/race3d/check_vehicles.gd'
rep(p, '''		var cam_z := float(r.view.get("camera_z", 0.0))
		var near := Node3D.new()
		var far := Node3D.new()''', '''		var cam_z := float(r.view.get("camera_z", 0.0))
		# the stage's own static lamps (street lights, wall lamps and beacons of the prop models since the assembly of
		# M1) are the baseline: the two test lamps come on top and must go again (the car stands, nothing streams)
		var base_flares := _statics(fl).size()
		var base_lamps := int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"])
		var near := Node3D.new()
		var far := Node3D.new()''')
rep(p, '''		var st := _statics(fl)
		if hour < 18.0:
			_need(p, st.is_empty(), "bei Tag leuchten die Lampen nicht (%d Lichtpunkte)" % st.size())
		else:
			_need(p, st.size() == 2, "nachts beide Lampen als Lichtpunkt (%d)" % st.size())
			if st.size() == 2:''', '''		var st := _own(_statics(fl), [near, far])
		if hour < 18.0:
			_need(p, st.is_empty() and _statics(fl).size() == base_flares, "bei Tag leuchten die Lampen nicht (%d Lichtpunkte)" % st.size())
		else:
			_need(p, st.size() == 2, "nachts beide Lampen als Lichtpunkt (%d, dazu %d der Etappe)" % [st.size(), base_flares])
			if st.size() == 2:''')
rep(p, '''		_need(p, _statics(fl).is_empty(), "%.0f Uhr: Lampen vergessen, wenn der Knoten den Baum verlässt" % hour)
		_need(p, int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"]) == 0, "%.0f Uhr: keine Lampe mehr angemeldet" % hour)''',
    '''		_need(p, _statics(fl).size() == base_flares, "%.0f Uhr: Lampen vergessen, wenn der Knoten den Baum verlässt (%d statt %d)" % [
			hour, _statics(fl).size(), base_flares])
		_need(p, int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"]) == base_lamps, "%.0f Uhr: die Test-Lampen sind abgemeldet (%d statt %d)" % [
			hour, int((fl.call("snapshot") as Dictionary)["lights"]["static_lamps"]), base_lamps])''')
rep(p, '''func _check_lampen_fest() -> void:''', '''## The static flares that belong to the test lamps: within 12 m of one of the given nodes.
func _own(flares: Array, nodes: Array) -> Array:
	var out: Array = []
	for f: Dictionary in flares:
		for n: Variant in nodes:
			if is_instance_valid(n) and (f["pos"] as Vector3).distance_to((n as Node3D).global_position) < 12.0:
				out.append(f)
				break
	return out


func _check_lampen_fest() -> void:''')
print('ok')
