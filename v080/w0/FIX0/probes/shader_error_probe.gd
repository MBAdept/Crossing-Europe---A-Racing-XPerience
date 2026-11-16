extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nvoid fragment() {\n\tALBEDO = vec3(1.0) * undefined_thing;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = mat
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	root.add_child(cam)
	root.add_child(mi)
	for i in 5:
		await process_frame
	print("PROBE done")
	quit(0)
