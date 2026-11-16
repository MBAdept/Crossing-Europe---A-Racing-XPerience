extends ChunkBuilder
## Example builder of docs/renderer-modern.md §9.5 (file name = id(), here "roadside"): a post every 24 m on the
## right shoulder; every fourth post carries a lamp.

const POST_EVERY := 8             # rows (segments of 3 m)

var _mesh: BoxMesh
var _material: StandardMaterial3D


func id() -> String:
	return "roadside"


func setup(_renderer: Node) -> void:
	# main thread, once per stage: resources that every chunk shares
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.12, 1.0, 0.12)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.85, 0.85, 0.82)


func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	# WORKER THREAD: only the snapshot arrays of ctx – no nodes, no resources, no ctx.services / path / terrain
	var frames: Array[Transform3D] = []
	for i in range(0, ctx.row_count() - 1, POST_EVERY):
		var z := float(ctx.seg_a + i) * ctx.seg_len
		var x := ctx.rows_edge[i].y + ctx.shoulder_w - 0.3
		frames.append(ctx.frame(z, x, ctx.ground(z, x) + 0.5))      # rigid frame, chunk-local
	return {"frames": frames}


func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	# main thread: nodes under the chunk node; the streamer owns and moves that node
	var frames: Array = part["frames"]
	if frames.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = frames.size()
	var lamps: Array = []
	for i in frames.size():
		var tr: Transform3D = frames[i]
		mm.set_instance_transform(i, tr)
		if i % 4 == 0:
			lamps.append({"pos": tr.origin + Vector3(0.0, 0.6, 0.0), "dir": Vector3.DOWN, "role": "street",
				"color": Color(1.0, 0.9, 0.7), "size": 0.3, "range": 8.0, "energy": 1.0})
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _material
	parent.add_child(node)
	var renderer: Variant = ctx.services.get("renderer")           # {} in a test without a renderer
	if renderer != null:
		(renderer as Object).call("add_lamps", node, lamps)        # positions are local to `node`


func debug(part: Dictionary) -> Dictionary:
	return {"posts": (part["frames"] as Array).size()}


func snapshot() -> Dictionary:
	return {"props": {"roadside_post": 0}}
