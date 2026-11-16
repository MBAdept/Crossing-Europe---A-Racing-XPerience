extends SceneTree
## RINT-M2 probe: the props builder's warm-up nodes (every prop model, custom data (1, 1, 1, 1)) in a grid – top half
## as built, bottom half the same meshes in a MultiMesh WITHOUT custom data. Prints the share of bright green pixels
## of each half and saves the picture. Args: --out=<png> [--only=<substring of the mesh path>]

const PropsB := preload("res://scripts/race3d/builders/props.gd")

var _frames := 0
var _out := ""
var _b: Variant
var _built := false
var _only := ""
var _mode := "none"
const SETS := ["props/bush_low", "props/city_german_gruenderzeit", "props/city_german_house", "props/city_german_mietshaus",
	"props/city_hanse_gabled", "props/city_hanse_kontor", "props/farmhouse", "props/tree_oak", "props/wind_turbine"]


func _initialize() -> void:
	var a := CliArgs.all()
	_out = str(a.get("out", "/tmp/mm_models.png"))
	_only = str(a.get("only", ""))
	_mode = str(a.get("mode", "none"))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 44.0
	cam.position = Vector3(30.0, 0.0, 40.0)
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	root.add_child(sun)
	_b = PropsB.new()
	(_b.call("_lib") as Object).call("request", SETS, self)


func _build() -> void:
	var only := _only
	var nodes: Array = _b.warmup_nodes()
	var i := 0
	for v: Variant in nodes:
		var n := v as MultiMeshInstance3D
		if n == null or n.multimesh == null or n.multimesh.mesh == null:
			continue
		if not n.multimesh.use_custom_data:
			continue
		if only != "" and not n.multimesh.mesh.resource_path.contains(only):
			continue
		if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var col := i % 20
		var row := i / 20
		if row >= 7:
			break
		n.position = Vector3(col * 3.0, 18.0 - row * 3.0, 0.0)
		root.add_child(n)
		# the same mesh without custom data, mirrored to the lower half
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = _mode == "colors" or _mode == "both" or _mode == "bufboth"
		mm.use_custom_data = _mode == "custom" or _mode == "both" or _mode.begins_with("buf")
		mm.mesh = n.multimesh.mesh
		mm.instance_count = 3 if _mode == "buffer3" else 1
		if _mode.begins_with("buf"):
			var bb := PackedFloat32Array()
			for k in mm.instance_count:
				bb.append_array(PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1]))
				if mm.use_colors:
					bb.append_array(PackedFloat32Array([1, 1, 1, 1]))
			mm.buffer = bb
		else:
			mm.set_instance_transform(0, n.multimesh.get_instance_transform(0))
		if mm.use_colors:
			mm.set_instance_color(0, Color(1, 1, 1, 1))
		if mm.use_custom_data:
			mm.set_instance_custom_data(0, Color(1, 1, 1, 1))
		var m2 := MultiMeshInstance3D.new()
		m2.multimesh = mm
		m2.material_override = n.material_override
		m2.scale = n.scale
		m2.position = Vector3(col * 3.0, -4.0 - row * 3.0, 0.0)
		root.add_child(m2)
		i += 1
	print("MMMODELS nodes=%d" % i)


func _process(_d: float) -> bool:
	if not _built:
		var lib: Object = _b.call("_lib")
		lib.call("pending")
		if not bool(lib.call("ready")):
			return false
		_build()
		_built = true
		return false
	_frames += 1
	if _frames < 10:
		return false
	var img := root.get_texture().get_image()
	img.save_png(_out)
	var h := img.get_height()
	for half in 2:
		var g := 0
		var tot := 0
		for y in range(half * h / 2, (half + 1) * h / 2, 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				tot += 1
				if c.g > 0.6 and c.r < 0.45 and c.b < 0.45:
					g += 1
		print("MMMODELS half=%s bright_green=%.3f %%" % ["built (custom buffer)" if half == 0 else _mode, 100.0 * g / tot])
	return true
