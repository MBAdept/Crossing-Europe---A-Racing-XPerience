import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
('''var _lod_z := -1.0e12              ## camera position of the last look at the chunk levels
var _prepared := false
''', '''var _lod_z := -1.0e12              ## camera position of the last look at the chunk levels
var _prepared := false
## FIX1 (QA QB-03): landmarks keep Arcade's landmark law (RoadRenderer.landmark_fade: visible up to visibility ×
## render.landmark_range_factor, at most render.landmark_far_m, with its haze) – in their chunk through a material of
## their own (billboard.gdshader landmark_law), beyond the committed chunks as single stand-ins on the path (update()),
## so Elbphilharmonie and Michel stand on the horizon as early as in Arcade (they appeared only at ~765 m).
var _lm_law := Vector2(2.0, 1900.0)
var _lm_mats: Dictionary = {}      ## set id -> landmark material (main thread)
var _far: Dictionary = {}          ## index into Track.landmarks -> MeshInstance3D beyond the committed chunks
var _far_z := -1.0e12              ## camera position of the last look at the far landmarks
'''),
('''func _read_config(cfg: Dictionary) -> void:
''', '''func _read_config(cfg: Dictionary) -> void:
	_lm_law = Vector2(float(ConfigLoader.lookup(cfg, "render.landmark_range_factor", 2.0)),
		float(ConfigLoader.lookup(cfg, "render.landmark_far_m", 1900.0)))
'''),
('''func update(view: Dictionary, _dt: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	if absf(cam_z - _lod_z) < LOD_STEP_M:''', '''func update(view: Dictionary, _dt: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	if absf(cam_z - _far_z) >= LOD_STEP_M or _far_z < -1.0e11:
		_far_z = cam_z
		_update_far_landmarks(view, cam_z)
	if absf(cam_z - _lod_z) < LOD_STEP_M:'''),
('''	else:
		tr = Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), ctx.local(z, x, h))
		key = "s|%s|%d" % [str(e["set"]), 1 if flipped else 0]
	var groups: Dictionary = out["groups"]
	var g: Dictionary = groups.get(key, {})
	if g.is_empty():
		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0}
		groups[key] = g''', '''	else:
		tr = Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), ctx.local(z, x, h))
		key = "%s|%s|%d" % ["l" if landmark else "s", str(e["set"]), 1 if flipped else 0]
	var groups: Dictionary = out["groups"]
	var g: Dictionary = groups.get(key, {})
	if g.is_empty():
		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0,
			"landmark": landmark and not is_model}
		groups[key] = g'''),
('''		else:
			var s := lib.standin(str(g["set"]))
			if s.is_empty():
				continue
			var node := _mmi(s, buf, n, true, bool(g["mirror"]))''', '''		else:
			var s := lib.standin(str(g["set"]))
			if s.is_empty():
				continue
			if bool(g.get("landmark", false)):
				s = {"mesh": s["mesh"], "material": landmark_material(str(g["set"]))}
			var node := _mmi(s, buf, n, true, bool(g["mirror"]))'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:70]
    s = s.replace(old, new)
anchor = '''## Hook of the renderer: what the props draw, compiled behind the loading cover'''
assert s.count(anchor) == 1
helpers = open(sys.argv[2], encoding='utf-8').read()
s = s.replace(anchor, helpers + anchor)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
