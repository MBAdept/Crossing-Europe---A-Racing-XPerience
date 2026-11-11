extends SceneTree
## Headless checks of the model pipeline of the mode "Modern" (v0.8.0; docs/modelle.md), run by the generic hook of
## tools/run_tests.sh (tests/race3d/check_*.gd):
##   godot --headless --path . -s res://tests/race3d/check_models.gd [-- --only=validator,defekte_dateien]
##   models           tools/blender/validate_models.py passes on the committed models: manifest, files, budgets,
##                    vertex codes, sizes, and the lamp rules (every lamp a driver reacts to shows enough area at
##                    every level of detail, light anchors on their lamps, no surface wound inside out). The
##                    validator decodes the baked files with this Godot (tools/models/inspect_models.gd).
##   defekte_dateien  a model whose file is truncated or is no resource at all is not built – never half a model
##                    (a car of four wheels without its body); ModelDB.missing() names the file once it was
##                    loaded, the other models of the manifest stay usable. (Not a unit test: loading a broken
##                    file makes the engine print errors, which the unit test run counts as failures.)
## Prints "CHECK <name> OK|FEHLER …"; exit code 0 when all pass.

const CHECKS := ["models", "defekte_dateien"]
const FIX_DIR := "user://test_models_broken"

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			call("_check_" + c)
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-15s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


# --- models: the validator ---------------------------------------------------------------------------------------

func _check_models() -> void:
	var p: Array[String] = []
	var tool := ProjectSettings.globalize_path("res://tools/blender/validate_models.py")
	# the validator starts Godot itself to decode the meshes: this very binary
	OS.set_environment("GODOT", OS.get_executable_path())
	var out: Array = []
	var code := OS.execute("python3", [tool], out, true)
	var text := "\n".join(out)
	var summary := ""
	var errors: Array[String] = []
	for line: String in text.split("\n"):
		if line.begins_with("validate_models:"):
			summary = line.substr(17).strip_edges()
		elif line.begins_with("FEHLER "):
			errors.append(line.substr(7).strip_edges())
	_need(p, code == 0 and text.contains("CHECK models OK"), "validate_models.py besteht (Exit %d%s)" % [code,
		"" if code != -1 else " – python3 ließ sich nicht starten"])
	for e: String in errors.slice(0, 6):
		p.append(e)
	if errors.size() > 6:
		p.append("… und %d weitere" % (errors.size() - 6))
	_report("models", p, "validate_models.py: %s" % (summary if summary != "" else text.strip_edges().right(200)))


# --- defekte_dateien -----------------------------------------------------------------------------------------------

## Copies a model folder of the shipped manifest next to a manifest of its own; `damage`: {file name: "truncate" |
## "garbage" | "remove"}. Returns the manifest path.
func _fixture(model_ids: Array, damage: Dictionary) -> String:
	var src := ModelDB.ROOT
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + ModelDB.MANIFEST))
	var manifest := {"version": 1, "exporter": shipped.get("exporter", ""), "models": {}, "sets": {}}
	for mid: String in model_ids:
		manifest["models"][mid] = shipped["models"][mid]
		for sid: String in shipped["sets"]:
			if str((shipped["sets"][sid] as Dictionary).get("model", "")) == mid:
				manifest["sets"][sid] = shipped["sets"][sid]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIX_DIR.path_join(mid)))
		for f: String in DirAccess.get_files_at(src + mid):
			if f.ends_with(".import") or f.ends_with(".json"):
				continue        # textures are read as plain pictures next to a manifest outside the import system
			var bytes := FileAccess.get_file_as_bytes(src + mid + "/" + f)
			var how := str(damage.get(mid + "/" + f, ""))
			if how == "remove":
				continue
			if how == "truncate":
				bytes = bytes.slice(0, bytes.size() / 3)
			elif how == "garbage":
				bytes = "das ist keine Ressource\n".repeat(40).to_utf8_buffer()
			var fh := FileAccess.open(FIX_DIR.path_join(mid).path_join(f), FileAccess.WRITE)
			fh.store_buffer(bytes)
			fh.close()
	var path := FIX_DIR.path_join("manifest.json")
	var mf := FileAccess.open(path, FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest))
	mf.close()
	return path


func _children(node: Node) -> Array:
	var out: Array = []
	if node != null:
		for c in node.get_children():
			out.append(str(c.name))
	return out


func _check_defekte_dateien() -> void:
	var p: Array[String] = []
	ModelDB.load_manifest()
	_need(p, ModelDB.available(), "das ausgelieferte Manifest lädt")
	var path := _fixture(["traffic/sedan", "props/streetlight", "props/tree_oak"], {"traffic/sedan/lod0_body.res": "truncate",
		"props/streetlight/lod0_body.res": "garbage", "traffic/sedan/shadow.res": "remove"})
	ModelDB.warn_missing = false
	_need(p, ModelDB.load_manifest(path), "das Manifest mit den beschädigten Dateien ist gültig (es nennt, was fehlt)")
	_need(p, ModelDB.has_model("traffic/sedan_red") and ModelDB.has_model("props/streetlight"), "die Sets nennen weiter ihr Modell")
	# before anything was loaded only the file that is not there at all is known
	_need(p, ModelDB.missing(["traffic/sedan_red"]) == (["traffic/sedan/shadow.res"] as Array[String]), "missing() vor dem Laden: die fehlende Datei (%s)" % str(ModelDB.missing(["traffic/sedan_red"])))
	# what a renderer does: request, wait, ask
	var sets := ["traffic/sedan_red", "props/streetlight", "props/tree_oak"]
	ModelDB.request(sets)
	var guard := 0
	while ModelDB.pending() > 0 and guard < 4000:
		OS.delay_msec(5)
		guard += 1
	var missing := ModelDB.missing(sets)
	_need(p, missing == (["props/streetlight/lod0_body.res", "traffic/sedan/lod0_body.res", "traffic/sedan/shadow.res"] as Array[String]),
		"missing() nach dem Laden nennt die abgeschnittene, die fremde und die fehlende Datei (%s)" % str(missing))
	_need(p, ModelDB.missing(["props/tree_oak"]).is_empty(), "am unbeschädigten Modell fehlt nichts")
	var built := {}
	for job: Array in [["traffic/sedan_red", "lod0"], ["traffic/sedan_red", "lod1"], ["props/streetlight", ""], ["props/tree_oak", "lod0"]]:
		var node := ModelFactory.build(str(job[0]), str(job[1]), null)
		built["%s %s" % [job[0], job[1]]] = _children(node)
		if node != null:
			node.free()
	_need(p, (built["traffic/sedan_red lod0"] as Array).is_empty(), "Auto mit abgeschnittener Karosserie: kein halbes Modell (%s)" % str(built["traffic/sedan_red lod0"]))
	_need(p, (built["traffic/sedan_red lod1"] as Array).is_empty(), "Auto ohne Schattenwerfer-Datei: auch die ferne Stufe nicht (%s)" % str(built["traffic/sedan_red lod1"]))
	_need(p, (built["props/streetlight "] as Array).is_empty(), "Requisit mit fremder Datei: kein leerer Knoten")
	_need(p, (built["props/tree_oak lod0"] as Array).size() == 2, "das unbeschädigte Modell wird gebaut (%s)" % str(built["props/tree_oak lod0"]))
	_need(p, ModelFactory.multimesh_parts("traffic/sedan_red", "lod0").is_empty() and ModelFactory.multimesh_parts("props/streetlight", "").is_empty(),
		"multimesh_parts() liefert für die beschädigten Modelle nichts")
	_need(p, ModelFactory.multimesh_parts("props/tree_oak", "lod1").size() == 2, "multimesh_parts() des unbeschädigten Modells (Netz + Schattenwerfer)")
	ModelDB.warn_missing = true
	ModelDB.load_manifest()
	_need(p, ModelDB.missing(ModelDB.set_ids()).is_empty(), "im ausgelieferten Manifest fehlt keine Datei")
	_report("defekte_dateien", p, "abgeschnittene, fremde und fehlende Netzdatei: build() und multimesh_parts() liefern nichts statt eines halben Modells, missing() nennt %d Dateien, das unbeschädigte Modell bleibt nutzbar" % missing.size())
