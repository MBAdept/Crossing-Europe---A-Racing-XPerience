extends SceneTree
## AS3 scratch: alpha-test load of the leaves at 20 m - per model the summed screen area of all triangles of the
## class "leaves" of lod0 (both faces are drawn: every triangle counts once, wherever it lies) seen by the game
## camera (3.4 m high, focal 711 px at 720 px, horizon at 45 %) with the model 9 m beside the road and 20 m ahead.
## Divided by the pixels the model covers in the rendered picture (prop_scene --mode=lods --d0=20) it gives the
## mean number of leaf fragments the GPU shades (and alpha-tests) per covered pixel.
##   godot --headless --path . -s overdraw.gd -- --models=a,b,...

const FOCAL := 711.0
const CAM := Vector3(0.0, 3.4, 0.0)
const CY := 324.0                    # the horizon row: 45 % of 720 px

var _dist := 20.0


func _initialize() -> void:
	var models: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--models="):
			models = a.substr(9).split(",", false)
		if a.begins_with("--dist="):
			_dist = float(a.substr(7))
	if not ModelDB.load_manifest():
		print("kein Manifest")
		quit(1)
		return
	for m: Variant in models:
		var mid := str(m)
		var model := ModelDB.model(mid)
		var lod: Dictionary = ModelDB.lod(model, "lod0")
		var area := 0.0
		var tris := 0
		var cards := int((model.get("cards", {}) as Dictionary).get("lod0", 0))
		for p: Variant in lod.get("parts", []):
			var mesh := load("res://assets/models/" + str((p as Dictionary).get("mesh", ""))) as ArrayMesh
			if mesh == null:
				continue
			for si in mesh.get_surface_count():
				if mesh.surface_get_name(si) != "leaves":
					continue
				var arr := mesh.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var n := idx.size() / 3 if idx.size() > 0 else v.size() / 3
				for t in n:
					var a := v[idx[t * 3]] if idx.size() > 0 else v[t * 3]
					var b := v[idx[t * 3 + 1]] if idx.size() > 0 else v[t * 3 + 1]
					var c := v[idx[t * 3 + 2]] if idx.size() > 0 else v[t * 3 + 2]
					var pa := _proj(a)
					var pb := _proj(b)
					var pc := _proj(c)
					area += absf((pb - pa).cross(pc - pa)) * 0.5
					tris += 1
		print("UEBERZEICHNUNG %s @%d m Kuppeln/Karten %d Dreiecke leaves %d Bildfläche %.0f px" % [mid, int(_dist), cards, tris, area])
	quit(0)


func _proj(p: Vector3) -> Vector2:
	var w := p + Vector3(9.0, 0.0, -_dist) - CAM
	var z := -w.z
	return Vector2(640.0 + w.x / z * FOCAL, CY - w.y / z * FOCAL)
