extends SceneTree
## M2INT debug: which lines of the static vpbr source still mention instance uniforms.


func _initialize() -> void:
	var mats_script: GDScript = load("res://scripts/race3d/modern_materials.gd")
	var mats: Object = mats_script.call("shared")
	var src: String = (mats.call("shader", "vpbr") as Shader).code
	var st: String = mats_script.call("static_code", src)
	var n := 0
	for l: String in st.split("\n"):
		if l.contains("instance uniform") or l.contains("instance_index"):
			print("LEFT: ", l)
			n += 1
	print("DBG lines left ", n, " src len ", src.length(), " static len ", st.length())
	var rx := RegEx.create_from_string("(,\\s*|\\s*:\\s*)instance_index\\(\\s*\\d+\\s*\\)")
	print("DBG regex valid ", rx.is_valid(), " matches ", rx.search_all(src).size())
	quit(0)
