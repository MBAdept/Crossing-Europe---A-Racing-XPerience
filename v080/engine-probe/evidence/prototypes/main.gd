extends Node
# Entry point: -- --suite=<name> --test=<name> --out=<dir>

func _ready() -> void:
	var suite := "light"
	var test := ""
	var out := "user://"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite = a.substr(8)
		elif a.begins_with("--test="):
			test = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var scr: GDScript = load("res://t_%s.gd" % suite)
	if scr == null:
		print("PROBE: unknown suite ", suite)
		get_tree().quit(2)
		return
	var node: Node = scr.new()
	node.name = "Suite"
	node.set("out_dir", out)
	node.set("suite_name", suite)
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	var tests: PackedStringArray = PackedStringArray()
	if test == "":
		for m: Dictionary in node.get_method_list():
			var mn: String = m["name"]
			if mn.begins_with("test_"):
				tests.append(mn.substr(5))
	else:
		tests = test.split(",")
	for t: String in tests:
		if not node.has_method("test_" + t):
			print("PROBE: unknown test ", t)
			continue
		print("PROBE: ---- ", suite, ".", t)
		node.call("begin_test", t)
		await node.call("test_" + t)
		node.call("end_test")
	get_tree().quit(0)
