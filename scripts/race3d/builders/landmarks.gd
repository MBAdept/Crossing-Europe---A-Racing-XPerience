extends ChunkBuilder
## Mode "Modern" (v0.8.0, package R7b): the LANDMARKS of a stage – every landmark Arcade shows, where Arcade shows it
## (contract §4.5.5 table: "landmarks anchored on the path up to landmark_path_m"; §6 wave 5 "R7"; lead decisions of
## R7b). German docs: docs/renderer-modern.md, section "Wahrzeichen und Skyline".
##
## Source: Track.landmarks – one entry per landmark of the stage plan (Track._build_landmark: set, side, x = its near
## edge, z, scale, the procedural kind "proc" and the catalogue values). They are NOT chunk parts: a landmark stands on
## the path as one node under renderer.world from Arcade's landmark range on (RoadRenderer._draw_far_landmarks: the
## range L = clamp(visibility × render.landmark_range_factor, min(visibility, 600), max(render.landmark_far_m,
## visibility)); at night at least render.landmark_far_m, where Arcade still draws its illumination) until it has
## been passed, and is freed then (no world-space cache: D2). The path is integrated far enough ahead for that
## (graphics.modern.landmark_path_m, A-3). With this builder present builders/props.gd leaves every landmark item to
## it (its duck-typed skip: renderer.builder("landmarks") != null).
##
## What a landmark is drawn with (lead decision 3 – the interface for the landmark models of AS6):
##   1 MODEL     the set has a model in the manifest (ModelDB): the model, placed like a prop model (origin = the
##               sprite anchor, +Z the side the sprite shows) but facing its approach (_place) and mirrored only where
##               Arcade mirrors the picture (a plain prop with the tag mirror_left on the left side). Surfaces of the classes
##               baked / baked_cutout / vpbr draw with assets/shaders/modern/landmark.gdshader (CE_ATLAS / CE_VCOL),
##               the classes glass and leaves keep their own materials (they have no landmark law)
##   2 PICTURE   else Arcade's own picture: the sprite cell, as Arcade draws it (CE_PICTURE)
##   3 PROC      else the procedural kind Arcade draws ("proc" without a sprite: Hannover, Dortmund, Leipzig, Madrid,
##               Belgrad, Calais): its shape in 3D, built here from Arcade's dimensions (proc_mesh(): domed_church,
##               tv_tower, lighthouse, skyscrapers – N2: a slim tower stays a slim tower), lit like a model, with
##               floodlight, lit windows and aviation lights at night (CE_VCOL, CE_GLOW)
##   4 FALLBACK  else the fallback set of its stage-plan entry (a model or picture, with fallback_scale and
##               fallback_tint) – today only for a procedural kind without a 3D shape here
## Arcade's landmark law for all of them, per landmark and frame from the distance of its anchor (_fade()):
## alpha 1 - smoothstep(0.72 L, L, d), haze 0.85 × (d - fog begin) / (L - fog begin) towards the fog colour × 1.15,
## illumination at night up to render.landmark_far_m (lights 0.8 → 1.0 of it), a plain prop standing as a landmark
## floodlit at night (RoadRenderer.LANDMARK_FLOOD, × 0.55). SOFT FADE (B-09): from BLEND_FROM × L on the landmark draws
## with the translucent variant of its material (CE_BLEND) – nearer with the opaque one (shadows, depth).
## Never an instance uniform (A-19): each landmark has its own small set of materials.
## Hooks (duck-typed, A-7): setup, apply_quality, prepare, prepare_pending, fail_reason, warmup_nodes, update,
## rebased, perf, snapshot. collect/build/commit do nothing: no chunk part.
## Owner: package R7 (wave 5: R7b).

const SHADER_PATH := "res://assets/shaders/modern/landmark.gdshader"
const FLOOD_K := 0.55               ## RoadRenderer.LANDMARK_FLOOD_K: floodlight on a plain prop standing as a landmark
const BLEND_FROM := 0.70            ## share of the range L from which the translucent variant draws (the fade starts at 0.72)
const KEEP_BEHIND_M := 320.0        ## a passed landmark stays this long behind the camera (its body reaches ahead of its anchor)
const APPROACH_M := 600.0           ## FIX-R7b (B-05): a model or shape faces the road point this far before its anchor …
const MAX_TURN := 0.6981317         ## … turned at most this far (40°) from the road's heading at the anchor
const PROC_KINDS: Array[String] = ["domed_church", "tv_tower", "lighthouse", "skyscrapers"]
## Arcade's procedural reference heights (RoadRenderer._lm_*: s = px per m × height / reference)
const PROC_REF := {"domed_church": 80.0, "tv_tower": 368.0, "lighthouse": 51.0, "skyscrapers": 259.0}
## FIX-R7b (B-05): depth (reference m) of the main axis behind the front face of a shape as _domed_church … build it –
## proc_mesh() moves it onto the anchor
const PROC_AXIS_Z := {"domed_church": 22.0, "tv_tower": 16.0, "lighthouse": 7.0, "skyscrapers": 18.0}
const REP_NAMES: Array[String] = ["none", "model", "picture", "proc"]
enum { NONE, MODEL, PICTURE, PROC }

var library: PropLibrary

var _renderer: Node                 ## untyped: packages talk to each other through the facade only
var _track: Track
var _law := Vector2(2.0, 1900.0)    ## render.landmark_range_factor, render.landmark_far_m
var _path_m := 1900.0               ## graphics.modern.landmark_path_m
var _fog_frac := 0.45               ## graphics.modern.fog.begin_frac (render.fog_start_frac in Arcade)
var _casters := 2
var _blend_from := BLEND_FROM       ## graphics.modern.landmark_blend_from (tests force the translucent variant with 0)
var _prepared := false
var _plans: Array = []              ## per index of Track.landmarks: the resolved plan (_resolve)
var _resolved := false
var _live: Dictionary = {}          ## index -> live landmark (_make)
var _shaders: Dictionary = {}       ## variant key -> Shader
var _proc_cache: Dictionary = {}    ## proc key -> {"mesh", "glows"}
var _last_view: Dictionary = {}


func id() -> String:
	return "landmarks"


func _lib() -> PropLibrary:
	if library == null:
		library = PropLibrary.new()
	return library


# --- hooks of the renderer -----------------------------------------------------------------------------------------

func setup(renderer: Node) -> void:
	_renderer = renderer
	var t: Variant = renderer.get("track") if renderer != null else null
	_track = t if t is Track else null
	var cfg: Variant = renderer.get("cfg") if renderer != null else null
	if cfg is Dictionary:
		read_config(cfg)


func read_config(cfg: Dictionary) -> void:
	_law = Vector2(float(ConfigLoader.lookup(cfg, "render.landmark_range_factor", 2.0)),
		float(ConfigLoader.lookup(cfg, "render.landmark_far_m", 1900.0)))
	_path_m = float(ConfigLoader.lookup(cfg, "graphics.modern.landmark_path_m", 1900.0))
	_fog_frac = float(ConfigLoader.lookup(cfg, "graphics.modern.fog.begin_frac", 0.45))
	_blend_from = float(ConfigLoader.lookup(cfg, "graphics.modern.landmark_blend_from", BLEND_FROM))


func apply_quality(levels: Dictionary) -> void:
	_casters = int(levels.get("shadow_casters", _casters))


## Loads what the stage's landmarks are drawn with: their sets, the fallback sets of their entries and of the
## stage plan (models through ModelDB, sprite sheets threaded – PropLibrary).
func prepare(_ctx: Dictionary) -> void:
	if _track == null:
		return
	_lib().request(wanted_sets(_track), self)
	_prepared = true


## Every set the landmarks of track `t` may be drawn with.
static func wanted_sets(t: Track) -> Array:
	var out: Array = []
	var plan_fb := plan_fallbacks(t)
	for it: Dictionary in t.landmarks:
		for key: String in ["set", "fallback"]:
			var s := str(it.get(key, ""))
			if s != "" and not out.has(s):
				out.append(s)
		var fb := str(plan_fb.get(str(it.get("set", "")), ""))
		if fb != "" and not out.has(fb):
			out.append(fb)
	return out


## Landmark set -> fallback set of its stage-plan entry, for the landmarks Arcade draws procedurally (the frozen
## Track._build_landmark drops their "fallback"; CityData.landmark_entry keeps it in the plan).
static func plan_fallbacks(t: Track) -> Dictionary:
	var out := {}
	if t == null or t.plan == null:
		return out
	for lm: Dictionary in t.plan.landmarks:
		if lm.has("proc") and str(lm.get("fallback", "")) != "":
			out[str(lm.get("set", ""))] = str(lm["fallback"])
	return out


func prepare_pending() -> int:
	return _lib().pending() if _prepared else 0


func fail_reason() -> String:
	return _lib().fail_reason() if _prepared else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and library != null:
		library.clear(self)


func perf() -> Dictionary:
	return {"landmarks": _live.size()}


func snapshot() -> Dictionary:
	var list: Array = []
	for li: Variant in _live.keys():
		var e: Dictionary = _live[li]
		var p: Dictionary = _plans[int(li)] if int(li) < _plans.size() else {}
		list.append({"index": int(li), "set": str(p.get("set", "")), "landmark": str(p.get("landmark", "")),
			"rep": REP_NAMES[int(p.get("rep", NONE))], "kind": str(p.get("kind", "")), "z": snappedf(float(p.get("z", 0.0)), 0.01),
			"x": snappedf(float(p.get("x", 0.0)), 0.01), "d": snappedf(float(e.get("d", 0.0)), 0.01),
			"keep": snappedf(float(e.get("keep", 0.0)), 0.001), "lights": snappedf(float(e.get("lights", 0.0)), 0.001),
			"blend": bool(e.get("blend", false)), "visible": bool(e.get("visible", false)),
			"mirror": bool(p.get("mirror", false)), "turn_deg": snappedf(float(p.get("turn_deg", 0.0)), 0.01),
			"shift_m": snappedf(float(p.get("shift_m", 0.0)), 0.01)})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["index"]) < int(b["index"]))
	return {"landmarks": list}


## The floating origin moved: the landmarks hang under renderer.world (origin-relative).
func rebased(shift: Vector3) -> void:
	for e: Variant in _live.values():
		var n: Variant = (e as Dictionary).get("node")
		if is_instance_valid(n):
			(n as Node3D).position += shift


# --- Arcade's law ----------------------------------------------------------------------------------------------------

## Arcade's landmark range for a visibility (RoadRenderer._landmark_range).
static func landmark_range(vis: float, law: Vector2) -> float:
	return clampf(vis * law.x, minf(vis, 600.0), maxf(law.y, vis))


## How far ahead landmarks are drawn: the landmark range, at night (palette "lights" > 0.05) at least
## render.landmark_far_m (RoadRenderer._draw_far_landmarks).
static func reach(vis: float, night: float, law: Vector2) -> float:
	return maxf(landmark_range(vis, law), law.y if night > 0.05 else 0.0)


## RoadRenderer.landmark_fade and _draw_landmark for a landmark at depth d: Vector4(alpha of the picture, haze,
## alpha of its illumination, floodlight share). flood = the landmark is a plain prop (no illumination of its own).
static func fade(d: float, vis: float, fog_start: float, night: float, law: Vector2, flood: bool) -> Vector4:
	var l := landmark_range(vis, law)
	var keep := 1.0 - smoothstep(l * 0.72, l, d)
	var haze := clampf((d - fog_start) / maxf(1.0, l - fog_start), 0.0, 1.0) * 0.85
	var lights := 0.0
	if night > 0.05:
		lights = night * (1.0 - smoothstep(law.y * 0.8, law.y, d))
	return Vector4(keep, haze, lights, FLOOD_K * lights if flood else 0.0)


# --- resolving -------------------------------------------------------------------------------------------------------

## The plan of every landmark of the track (after the library is ready): what it is drawn with and where.
func _resolve() -> void:
	_plans.clear()
	var lib := _lib()
	var plan_fb := plan_fallbacks(_track)
	for it: Dictionary in _track.landmarks:
		_plans.append(resolve_item(it, lib.sets, plan_fb))
	_resolved = true


## What landmark item `it` (an entry of Track.landmarks) is drawn with: {"rep": MODEL | PICTURE | PROC | NONE, "set",
## "model", "kind", "scale", "tint", "x" (anchor), "z", "side", "flood"}. sets = PropLibrary.sets (plain data).
static func resolve_item(it: Dictionary, sets: Dictionary, plan_fb: Dictionary) -> Dictionary:
	var set_id := str(it.get("set", ""))
	var side := int(it.get("side", 1))
	var sc := float(it.get("scale", 1.0))
	var tint := Color(str(it["tint"])) if it.has("tint") else Color.WHITE
	var p := {"rep": NONE, "landmark": set_id, "set": set_id, "model": "", "kind": "", "scale": sc, "tint": tint,
		"z": float(it.get("z", 0.0)), "x": float(it.get("x", 0.0)), "side": side, "flood": false,
		"height_m": float(it.get("height_m", 40.0)), "width_m": float(it.get("width_m", 30.0))}
	var e: Dictionary = sets.get(set_id, {})
	var proc := str(it.get("proc", ""))
	if e.is_empty() or int(e.get("kind", PropLibrary.NONE)) == PropLibrary.NONE:
		if proc != "" and PROC_KINDS.has(proc):
			# Arcade's procedural landmark (no sprite, no model): its shape in 3D, centred where Arcade centres it
			p["rep"] = PROC
			p["kind"] = proc
			p["set"] = ""
			p["x"] = float(p["x"]) + float(side) * float(it.get("width_m", 30.0)) * 0.5 * sc
			p["proc_key"] = proc_key(it)
			p["item"] = it
			return p
		var fb := str(it.get("fallback", plan_fb.get(set_id, "")))
		e = sets.get(fb, {}) if fb != "" else {}
		if e.is_empty() or int(e.get("kind", PropLibrary.NONE)) == PropLibrary.NONE:
			return p
		p["set"] = fb
		sc *= float(it.get("fallback_scale", 1.0))
		p["scale"] = sc
		if it.has("fallback_tint"):
			tint *= Color(str(it["fallback_tint"]))
			p["tint"] = tint
	var kind := int(e["kind"])
	p["rep"] = MODEL if kind == PropLibrary.MODEL else PICTURE
	if kind == PropLibrary.MODEL:
		var variants: Array = e.get("variants", [])
		p["model"] = str(variants[0]) if not variants.is_empty() else ""
	# a plain prop standing as a landmark (props/church as a cathedral …): Arcade floodlights its facade at night
	p["flood"] = not str(p["set"]).begins_with("landmarks/")
	# FIX-R7b (B-04): mirrored where Arcade mirrors the picture (RoadRenderer.prop_flipped in _draw_landmark: a set
	# built for the right roadside – tag mirror_left – on the left side; props/church as a cathedral). No landmarks/*
	# set carries the tag: a real landmark is never mirrored (D24, the AS6 models).
	p["mirror"] = RoadRenderer.prop_flipped(side, bool(it.get("mirror", false)), bool(e.get("mirror_left", false)))
	if it.has("align") and side != 0:
		p["x"] = PropsBuilderMath.edge_anchor_x(float(p["x"]), side, bool(p["mirror"]), float(e.get("extent_l", 0.5)),
			float(e.get("extent_r", 0.5)), sc)
	return p


## Key of a procedural shape: kind, height and colours of the entry – what proc_mesh() builds the mesh from. The
## placement scale is not part of it: the node carries it (_place). FIX-R7b (B-07): the key used height_m × scale, so
## two entries of the same kind with an equal product but a different scale would have shared a wrongly sized mesh.
static func proc_key(it: Dictionary) -> String:
	return "%s|%.2f|%s|%s|%s" % [str(it.get("proc", "")), float(it.get("height_m", 40.0)),
		str(it.get("wall", "")), str(it.get("dome", "")), str(it.get("cross", true))]


## The anchor arithmetic of builders/props.gd and Arcade (RoadRenderer.edge_anchor_x): x is the near edge; a mirrored
## picture or model measures it with the other extent. Kept here so that this builder never names another builder of
## the same wave (A-1).
class PropsBuilderMath:
	static func edge_anchor_x(x: float, side: int, flipped: bool, extent_l: float, extent_r: float, scale: float) -> float:
		return x + float(side) * (extent_l if (side > 0 or flipped) else extent_r) * scale


# --- every frame -----------------------------------------------------------------------------------------------------

func update(view: Dictionary, _dt: float) -> void:
	if _renderer == null or _track == null or not _prepared or not _lib().ready():
		return
	if not _resolved:
		_resolve()
	_last_view = view
	var world: Variant = _renderer.get("world")
	if not (world is Node3D):
		return
	var cam_z := float(view.get("camera_z", 0.0))
	var vis := float(view.get("visibility_m", 900.0))
	var pal: Variant = view.get("palette", {})
	var night := clampf(float((pal as Dictionary).get("lights", 0.0)), 0.0, 1.0) if pal is Dictionary else 0.0
	var fog_start := vis * _fog_frac
	var env: Variant = _renderer.get("env")
	if env != null:
		var st: Variant = (env as Object).get("state")
		if st is Dictionary and (st as Dictionary).has("fog_begin"):
			fog_start = float((st as Dictionary)["fog_begin"])
	var r := minf(reach(vis, night, _law), maxf(_path_m, vis))
	var l := landmark_range(vis, _law)
	for li in _plans.size():
		var p: Dictionary = _plans[li]
		var d := float(p["z"]) - cam_z
		var e: Variant = _live.get(li)
		if int(p["rep"]) == NONE or d > r or d < -KEEP_BEHIND_M:
			if e != null:
				_drop(li)
			continue
		if e == null:
			e = _make(li, p, world as Node3D)
			if e == null:
				continue
		var f := fade(maxf(d, 0.0), vis, fog_start, night, _law, bool(p["flood"]))
		_apply(e as Dictionary, d, f, d >= _blend_from * l)


## Shows the opaque or the translucent materials and sets the law of this frame on them.
func _apply(e: Dictionary, d: float, f: Vector4, blend: bool) -> void:
	e["d"] = d
	e["keep"] = f.x
	e["lights"] = f.z
	var node: Node3D = e["node"]
	var vis := f.x > 0.002 or (f.z > 0.002 and bool(e.get("has_lights", true)))
	if node.visible != vis:
		node.visible = vis
	e["visible"] = vis
	if not vis:
		return
	if bool(e.get("blend", false)) != blend or not e.has("blend"):
		e["blend"] = blend
		for s: Array in e["slots"]:
			var gi: GeometryInstance3D = s[0]
			var mat: Material = s[2] if blend else s[1]
			if int(s[3]) < 0:
				gi.material_override = mat
			else:
				(gi as MeshInstance3D).set_surface_override_material(int(s[3]), mat)
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if blend or not bool(s[4]) \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for m: Variant in e["mats"]:
		(m as ShaderMaterial).set_shader_parameter("lm_fade", f)


func _drop(li: int) -> void:
	var e: Dictionary = _live[li]
	var n: Variant = e.get("node")
	if is_instance_valid(n):
		(n as Node).queue_free()
	_live.erase(li)


## Creates landmark li under `world` at its place: the node, its parts and their two material sets.
func _make(li: int, p: Dictionary, world: Node3D) -> Variant:
	var node := Node3D.new()
	node.name = "Landmark%d" % li
	var e := {"node": node, "slots": [], "mats": [], "has_lights": true}
	var rep := int(p["rep"])
	var cast_ok := _casters >= 1
	var box := AABB()                 # footprint of the model or shape in its own space (_place)
	match rep:
		PICTURE:
			var st := _lib().standin(str(p["set"]))
			if st.is_empty():
				node.free()
				return null
			var src: ShaderMaterial = st["material"]
			var mi := MeshInstance3D.new()
			mi.mesh = st["mesh"]
			node.add_child(mi)
			var pair := picture_materials(src, p["tint"])
			_slot(e, mi, -1, pair, false)
			var lr: Variant = src.get_shader_parameter("lights_rect")
			e["has_lights"] = lr is Vector4 and (lr as Vector4).z > 0.0 or bool(p["flood"])
			if bool(p.get("mirror", false)):
				for m: ShaderMaterial in pair:
					m.set_shader_parameter("mirror", -1.0)
		MODEL:
			var md: Dictionary = _lib().models.get(str(p["model"]), {})
			var reps: Array = md.get("reps", [])
			if reps.is_empty():
				node.free()
				return null
			var parts := _lib().mesh_parts(str(p["model"]), str(reps[0]))
			for pv: Variant in parts:
				var part: Dictionary = pv
				if bool(part.get("shadow", false)) or bool(part.get("billboard", false)):
					continue
				var mesh: Mesh = part["mesh"]
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.transform = part.get("transform", Transform3D.IDENTITY)
				box = mi.transform * mesh.get_aabb() if box.size == Vector3.ZERO else box.merge(mi.transform * mesh.get_aabb())
				node.add_child(mi)
				for si in mesh.get_surface_count():
					var cls := surface_class(mesh, si)
					var src: Material = mesh.surface_get_material(si)
					var pair := model_materials(cls, src, p["tint"], md)
					if pair.is_empty():
						continue      # glass, leaves: their own material, no landmark law
					_slot(e, mi, si, pair, cast_ok)
		PROC:
			var pm := _proc(str(p["proc_key"]), p["item"])
			var mi := MeshInstance3D.new()
			mi.mesh = pm["mesh"]
			box = (pm["mesh"] as Mesh).get_aabb()
			node.add_child(mi)
			_slot(e, mi, -1, [_material("vcol", false), _material("vcol", true)], cast_ok)
			var gm: Variant = pm.get("glow_mesh")
			if gm is Mesh:
				var gi := MeshInstance3D.new()
				gi.mesh = gm
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var glow := _material("glow", false)
				glow.set_shader_parameter("viewport_h", _viewport_h())
				gi.material_override = glow
				(e["mats"] as Array).append(glow)
				node.add_child(gi)
	if rep == PICTURE:
		e["has_lights"] = bool(e["has_lights"])
	world.add_child(node)
	node.transform = _place(p, rep, box)
	_live[li] = e
	return e


## Height of the picture in pixels (the glow points keep a minimum size in pixels).
func _viewport_h() -> float:
	if _renderer is Node and (_renderer as Node).is_inside_tree():
		var h := (_renderer as Node).get_viewport().get_visible_rect().size.y
		if h > 0.0:
			return h
	return 720.0


## One drawable slot: [geometry, opaque material, translucent material, surface (-1 = override), casts].
func _slot(e: Dictionary, gi: GeometryInstance3D, surface: int, pair: Array, casts: bool) -> void:
	(e["slots"] as Array).append([gi, pair[0], pair[1], surface, casts])
	(e["mats"] as Array).append(pair[0])
	(e["mats"] as Array).append(pair[1])


## Transform of landmark plan p (drawn as `rep`, footprint `box` in its own space): on the ground at its anchor; a
## picture upright (its shader turns it to the screen); a model or shape FACING ITS APPROACH (FIX-R7b, B-05 – Arcade
## always shows a landmark's front: its +Z side looks at the road point APPROACH_M before the anchor, at most
## MAX_TURN away from the road's heading there; R7b turned it with the road at the anchor, so in bends it showed its
## side wall), mirrored in x where Arcade mirrors the picture (B-04, p.mirror), and never nearer the road than turned
## with the road (near_shift: the turn must not swing a corner of a long church towards the road).
func _place(p: Dictionary, rep: int, box: AABB) -> Transform3D:
	var z := float(p["z"])
	var x := float(p["x"])
	var side := int(p["side"])
	var sc := float(p["scale"])
	var h := 0.0
	var terrain: Variant = _renderer.get("terrain")
	if terrain is TerrainProfile and side != 0:
		var edges := _track.road_edges_at(z)
		var beyond := (x - edges.y if x > 0.0 else -x + edges.x) - _track.shoulder_w
		h = (terrain as TerrainProfile).height(int(floor(z / _track.seg_len)), -1 if x < 0.0 else 1, maxf(0.0, beyond))
	var origin: Vector3 = _renderer.call(&"road_to_world", z, x, h)
	var mx := -sc if bool(p.get("mirror", false)) else sc
	var path: Variant = _renderer.get("path")
	if rep == PICTURE or not (path is RoadPath3D):
		return Transform3D(Basis.from_scale(Vector3(mx if rep != PICTURE else sc, sc, sc)), origin)
	var rp := path as RoadPath3D
	var a := rp.heading_at(z)
	var from := rp.world(maxf(z - APPROACH_M, rp.z_min()), 0.0, 0.0)
	var t := face_heading(a, from, origin)
	var basis := heading_basis(t, Vector3(mx, sc, sc))
	var shift := near_shift(heading_basis(a, Vector3(mx, sc, sc)), basis, box, a, side)
	p["turn_deg"] = rad_to_deg(t - a)
	p["shift_m"] = shift
	return Transform3D(basis, origin + RoadPath3D.right_of(a) * float(side) * shift)


## Heading (RoadPath3D convention: fwd = (sin t, 0, -cos t)) of a landmark at `origin` that faces the road point
## `from` before it: the bearing from there, at most MAX_TURN away from the road's heading `a` at the anchor (and `a`
## itself when the two points nearly coincide).
static func face_heading(a: float, from: Vector3, origin: Vector3) -> float:
	var d := Vector3(origin.x - from.x, 0.0, origin.z - from.z)
	if d.length() < 50.0:
		return a
	return a + clampf(wrapf(atan2(d.x, -d.z) - a, -PI, PI), -MAX_TURN, MAX_TURN)


## Basis of a model standing along heading t (local -Z forward, +Z towards the driver), scaled by s (x < 0 mirrors).
static func heading_basis(t: float, s: Vector3) -> Basis:
	return Basis(RoadPath3D.right_of(t), Vector3.UP, -RoadPath3D.fwd_of(t)).scaled_local(s)


## How far (m) a footprint `box` placed with basis `turned` must move away from the road (side ±1) so that no corner
## comes nearer the road – across the road's heading `a` at the anchor – than with basis `along`: 0 when it does not.
static func near_shift(along: Basis, turned: Basis, box: AABB, a: float, side: int) -> float:
	if side == 0 or box.size == Vector3.ZERO:
		return 0.0
	var r := RoadPath3D.right_of(a)
	var near_a := INF
	var near_t := INF
	for cx: float in [box.position.x, box.end.x]:
		for cz: float in [box.position.z, box.end.z]:
			var c := Vector3(cx, 0.0, cz)
			near_a = minf(near_a, float(side) * (along * c).dot(r))
			near_t = minf(near_t, float(side) * (turned * c).dot(r))
	return maxf(0.0, near_a - near_t)


# --- materials -------------------------------------------------------------------------------------------------------

## Shader of a variant: "picture", "atlas", "atlas_cutout", "vcol", "glow"; blend = the translucent one.
func shader(variant: String, blend: bool) -> Shader:
	var key := variant + ("|blend" if blend else "")
	var sh: Variant = _shaders.get(key)
	if sh != null:
		return sh
	ModernMaterials.ensure_globals()
	var base := load(SHADER_PATH) as Shader
	var defs := ""
	match variant:
		"picture":
			defs = "#define CE_PICTURE\n"
		"atlas":
			defs = "#define CE_ATLAS\n"
		"atlas_cutout":
			defs = "#define CE_ATLAS\n#define CE_CUTOUT\n"
		"vcol":
			defs = "#define CE_VCOL\n"
		"glow":
			defs = "#define CE_GLOW\n"
	if blend:
		defs += "#define CE_BLEND\n"
	var s := Shader.new()
	s.code = base.code.replace("shader_type spatial;", "shader_type spatial;\n" + defs)
	_shaders[key] = s
	return s


func _material(variant: String, blend: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(variant, blend)
	return m


## Opaque and translucent material of a landmark picture, from the stand-in material of PropLibrary (its sheet and
## cells) and the placement tint.
func picture_materials(src: ShaderMaterial, tint: Color) -> Array:
	var out: Array = []
	for blend: bool in [false, true]:
		var m := _material("picture", blend)
		for k: String in ["tex", "uv_rect", "lights_rect"]:
			m.set_shader_parameter(k, src.get_shader_parameter(k))
		m.set_shader_parameter("sun_k", PropLibrary.STANDIN_SUN)
		m.set_shader_parameter("shadow_cut", PropLibrary.STANDIN_SHADOW_CUT)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		out.append(m)
	return out


## Material class of surface si of a model mesh (its surface name, §4.6.3).
static func surface_class(mesh: Mesh, si: int) -> String:
	return (mesh as ArrayMesh).surface_get_name(si) if mesh is ArrayMesh else ""


## Opaque and translucent material of a model surface of class `cls` ([] = keep the class material).
func model_materials(cls: String, src: Material, tint: Color, _md: Dictionary) -> Array:
	var variant := ""
	match cls:
		"baked":
			variant = "atlas"
		"baked_cutout":
			variant = "atlas_cutout"
		"vpbr", ModernMaterials.VPBR_STATIC:
			variant = "vcol"
		_:
			return []
	var out: Array = []
	for blend: bool in [false, true]:
		var m := _material(variant, blend)
		if variant.begins_with("atlas") and src is ShaderMaterial:
			for k: String in ["albedo_tex", "emit_tex", "roughness", "emit_energy"]:
				var v: Variant = (src as ShaderMaterial).get_shader_parameter(k)
				if v != null:
					m.set_shader_parameter(k, v)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		out.append(m)
	return out


## Hook of the renderer: every material variant the stage's landmarks use, on the real meshes (a vertex layout of its
## own can select a program variant of its own), each opaque one also as a shadow caster, shown once behind the
## loading cover and freed by the renderer. Small (about 2 m): they stand in front of the camera.
func warmup_nodes() -> Array:
	var out: Array = []
	if _track == null or not _lib().ready():
		return out
	if not _resolved:
		_resolve()
	var done := {}
	for p: Dictionary in _plans:
		match int(p["rep"]):
			PICTURE:
				var st := _lib().standin(str(p["set"]))
				if not st.is_empty() and not done.has("picture"):
					done["picture"] = true
					var pair := picture_materials(st["material"], Color.WHITE)
					for b in 2:
						out.append(_warm_node(st["mesh"], -1, pair[b], b == 1, false, 2.0 / maxf(1.0, (st["mesh"] as Mesh).get_aabb().size.y)))
			PROC:
				var key := "proc|" + str(p["proc_key"])
				if done.has(key):
					continue
				done[key] = true
				var pm := _proc(str(p["proc_key"]), p["item"])
				var mesh: Mesh = pm["mesh"]
				var k := 2.0 / maxf(1.0, mesh.get_aabb().size.y)
				for b in 2:
					out.append(_warm_node(mesh, -1, _material("vcol", b == 1), b == 1, b == 0, k))
				if pm.get("glow_mesh") is Mesh:
					out.append(_warm_node(pm["glow_mesh"], -1, _material("glow", false), true, false, k))
			MODEL:
				var key := "model|" + str(p["model"])
				if done.has(key):
					continue
				done[key] = true
				var md: Dictionary = _lib().models.get(str(p["model"]), {})
				var reps: Array = md.get("reps", [])
				for pv: Variant in (_lib().mesh_parts(str(p["model"]), str(reps[0])) if not reps.is_empty() else []):
					var mesh: Mesh = (pv as Dictionary)["mesh"]
					var k := 2.0 / maxf(1.0, mesh.get_aabb().size.y)
					for si in mesh.get_surface_count():
						var pair := model_materials(surface_class(mesh, si), mesh.surface_get_material(si), Color.WHITE, md)
						for b in (2 if not pair.is_empty() else 0):
							out.append(_warm_node(mesh, si, pair[b], b == 1, b == 0, k))
	return out


func _warm_node(mesh: Mesh, surface: int, mat: Material, blend: bool, casts: bool, k: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if surface < 0:
		mi.material_override = mat
	else:
		mi.set_surface_override_material(surface, mat)
	(mat as ShaderMaterial).set_shader_parameter("lm_fade", Vector4(0.5 if blend else 1.0, 0.2, 0.5, 0.2))
	mi.scale = Vector3.ONE * k
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --- procedural shapes ----------------------------------------------------------------------------------------------

func _proc(key: String, it: Dictionary) -> Dictionary:
	var c: Variant = _proc_cache.get(key)
	if c != null:
		return c
	var out := proc_mesh(it)
	_proc_cache[key] = out
	return out


## The 3D shape of Arcade's procedural landmark of item `it` (proc, height_m × scale, wall / dome colours, cross):
## {"mesh": ArrayMesh (CE_VCOL vertex format), "glow_mesh": ArrayMesh or null (CE_GLOW), "glows": int, "tris": int}.
## Model space in metres of the real landmark (height_m / Arcade's reference height; the node carries the placement
## scale), origin = the foot of its MAIN AXIS – the main dome, the tower, the tallest high-rise – on the ground, the
## front towards +Z. FIX-R7b (B-05): Arcade draws the whole landmark in the plane of its anchor, the dome at the
## anchor; with the front face at the anchor the dome stood 25 m further away – lower and smaller than Arcade's, hidden
## behind a tree at Leipzig.
static func proc_mesh(it: Dictionary) -> Dictionary:
	var kind := str(it.get("proc", ""))
	var hgt := float(it.get("height_m", 40.0))
	var k := hgt / float(PROC_REF.get(kind, hgt))
	var kit := ShapeKit.new()
	kit.k = k
	kit.oz = float(PROC_AXIS_Z.get(kind, 0.0))
	match kind:
		"domed_church":
			_domed_church(kit, Color(str(it.get("wall", "#ece6d6"))), Color(str(it.get("dome", "#d8b04a"))), bool(it.get("cross", true)))
		"tv_tower":
			_tv_tower(kit)
		"lighthouse":
			_lighthouse(kit)
		"skyscrapers":
			_skyscrapers(kit)
	return {"mesh": kit.mesh(), "glow_mesh": kit.glow_mesh(), "glows": kit.glow_count(), "tris": kit.tris()}


## Domed church (RoadRenderer._lm_domed, reference height 80 m): body 64 × 30 m with cornice and a low hipped roof,
## arched windows in two rows on every side and a portal, two side domes on drums, the main drum with its windows,
## the main dome with lantern, spike and (unless "cross": false) cross. Walls and domes floodlit at night.
static func _domed_church(kit: ShapeKit, wall: Color, dome: Color, cross: bool) -> void:
	var shade := wall.darkened(0.16)
	var win := wall.darkened(0.45)
	var dome_d := dome.darkened(0.25)
	var dz := -22.0                   # the body's middle (depth 44 m)
	kit.set_paint(wall, 0.85, 0.0, 14, 0.42)
	kit.box(Vector3(-32.0, 0.0, -44.0), Vector3(32.0, 30.0, 0.0))
	kit.set_paint(wall.darkened(0.25), 0.85, 0.0, 14, 0.4)
	kit.box(Vector3(-32.6, 28.8, -44.6), Vector3(32.6, 30.4, 0.6))
	kit.set_paint(shade, 0.8, 0.0, -1, 0.0)
	kit.hip_roof(Vector3(-33.6, 30.4, -45.2), Vector3(33.6, 30.4, 0.6), 6.0, 4.0)
	# windows: two rows of tall arched windows between the ends, a portal in the middle of the front
	kit.set_paint(win, 0.6, 0.0, 12, 0.35)
	for row in 2:
		var y0 := 5.0 + float(row) * 12.0
		var xw := -29.0
		while xw < 27.0:
			if absf(xw + 1.1) > 5.0 or row == 1:
				kit.arch_window(Vector3(xw + 1.1, y0, 0.0), 2.2, 7.0, Vector3.BACK)
				kit.arch_window(Vector3(xw + 1.1, y0, -44.0), 2.2, 7.0, Vector3.FORWARD)
			xw += 5.4
		var zw := -40.0
		while zw < -3.0:
			kit.arch_window(Vector3(-32.0, y0, zw + 1.1), 2.2, 7.0, Vector3.LEFT)
			kit.arch_window(Vector3(32.0, y0, zw + 1.1), 2.2, 7.0, Vector3.RIGHT)
			zw += 5.4
	kit.set_paint(wall.darkened(0.55), 0.7, 0.0, 12, 0.5)
	kit.arch_window(Vector3(0.0, 0.0, 0.0), 7.2, 11.0, Vector3.BACK)
	# side domes on their drums
	for sd: float in [-1.0, 1.0]:
		var c := Vector3(sd * 22.0, 0.0, dz)
		kit.set_paint(wall, 0.85, 0.0, 14, 0.5)
		kit.cylinder(c, 30.4, 44.0, 5.5, 5.5, 14, false)
		kit.set_paint(win, 0.6, 0.0, 12, 0.35)
		for i in 6:
			kit.slit(c, 5.5, TAU * float(i) / 6.0 + 0.26, 37.5, 42.0, 1.2)
		kit.set_paint(dome, 0.45, 0.25, 14, 0.3)
		kit.dome(c, 44.0, 6.5, 7.5, 14, 6)
		kit.set_paint(dome_d, 0.5, 0.3, -1, 0.0)
		kit.box(Vector3(c.x - 0.3, 51.0, dz - 0.3), Vector3(c.x + 0.3, 56.0, dz + 0.3))
	# main drum, dome, lantern, spike, cross
	var mc := Vector3(0.0, 0.0, dz)
	kit.set_paint(wall, 0.85, 0.0, 14, 0.5)
	kit.cylinder(mc, 30.4, 54.0, 12.0, 12.0, 24, false)
	kit.set_paint(wall.darkened(0.25), 0.85, 0.0, 14, 0.4)
	kit.cylinder(mc, 53.0, 54.6, 12.8, 12.8, 24, true)
	kit.set_paint(win, 0.6, 0.0, 12, 0.5)
	for i in 12:
		kit.slit(mc, 12.0, TAU * float(i) / 12.0 + 0.13, 43.0, 51.0, 1.4)
	kit.set_paint(dome, 0.45, 0.25, 14, 0.3)
	kit.dome(mc, 54.6, 13.5, 16.0, 24, 10)
	kit.set_paint(dome, 0.5, 0.2, 14, 0.4)
	kit.cylinder(mc, 69.0, 74.0, 2.0, 2.0, 10, true)
	kit.set_paint(dome_d, 0.5, 0.3, -1, 0.0)
	kit.box(Vector3(-0.3, 74.0, dz - 0.3), Vector3(0.3, 80.0, dz + 0.3))
	if cross:
		kit.box(Vector3(-1.6, 77.75, dz - 0.25), Vector3(1.6, 78.25, dz + 0.25))
	# Arcade's warm glow round the main dome at night (RoadRenderer._lm_domed: radius 16 m, alpha 0.4)
	kit.glow(Vector3(0.0, 56.0, dz), Color(1.0, 0.82, 0.5), 0.4, 16.0, 4.0, Vector4(0.0, 0.0, 0.0, 0.0))


## Television tower (RoadRenderer._lm_tv, reference height 368 m – the Berlin Fernsehturm; Arcade scales it for every
## tower): tapered shaft, the sphere with its window ring (lit at night), the upper shaft and the antenna with red and
## white bands; red aviation lights at 252 m (steady) and 300 / 368 m (blinking, 1.5 s).
static func _tv_tower(kit: ShapeKit) -> void:
	var conc := Color("dcdbd6")
	var c := Vector3(0.0, 0.0, -16.0)
	kit.set_paint(conc, 0.8, 0.0, -1, 0.0)
	kit.cylinder(c, 0.0, 40.0, 16.0, 11.5, 20, false)
	kit.cylinder(c, 40.0, 100.0, 11.5, 7.5, 20, false)
	kit.cylinder(c, 100.0, 200.0, 7.5, 4.5, 16, false)
	kit.set_paint(Color("c4c9d1"), 0.35, 0.35, -1, 0.0)
	kit.sphere(c + Vector3(0.0, 213.0, 0.0), 16.0, 24, 14)
	kit.set_paint(Color("4f5a68"), 0.2, 0.2, 12, 1.0)
	kit.cylinder(c, 211.4, 214.6, 16.25, 16.25, 24, false)
	kit.set_paint(conc, 0.8, 0.0, -1, 0.0)
	kit.cylinder(c, 228.0, 252.0, 3.2, 2.6, 12, true)
	for i in 10:
		var h0 := 252.0 + float(i) * 11.6
		kit.set_paint(Color("c8402e") if i % 2 == 0 else Color("eeeeea"), 0.6, 0.1, -1, 0.0)
		kit.cylinder(c, h0, h0 + 11.6, lerpf(1.9, 0.6, float(i) / 10.0), lerpf(1.9, 0.6, float(i + 1) / 10.0), 8, i == 9)
	# Arcade's _lm_glow: radius max(2.5 px, 6 m), alpha 0.85 (FIX-R7b, B-02: the size now holds – see CE_GLOW)
	var red := Color(1.0, 0.12, 0.08)
	kit.glow(c + Vector3(0.0, 252.0, 0.0), red, 0.85, 6.0, 2.5, Vector4(0.0, 0.0, 0.0, 0.0))
	kit.glow(c + Vector3(0.0, 300.0, 0.0), red, 0.85, 6.0, 2.5, Vector4(1.0, 1.5, 0.75, 0.0))
	kit.glow(c + Vector3(0.0, 368.0, 0.0), red, 0.85, 6.0, 2.5, Vector4(1.0, 1.5, 0.75, 0.0))


## Lighthouse (RoadRenderer._lm_lighthouse, reference height 51 m – Calais): white tapered tower with small windows on
## the keeper's house, the black gallery, the lantern room (lit at night) under its cupola; the lamp flashes four times
## a revolution (15 s) as a glow.
static func _lighthouse(kit: ShapeKit) -> void:
	var c := Vector3(0.0, 0.0, -7.0)
	kit.set_paint(Color("f0f0ec"), 0.7, 0.0, 14, 0.4)
	kit.cylinder(c, 0.0, 40.0, 5.0, 3.4, 16, false)
	kit.set_paint(Color("3a3e44"), 0.5, 0.0, 12, 0.4)
	for i in 4:
		kit.slit(c + Vector3(0.0, 0.0, 0.0), lerpf(5.0, 3.4, (10.0 + float(i) * 8.0) / 40.0) + 0.02, PI * 0.5, 9.0 + float(i) * 8.0, 11.0 + float(i) * 8.0, 1.0)
	kit.set_paint(Color("e6e3dc"), 0.85, 0.0, 14, 0.3)
	kit.box(Vector3(-9.0, 0.0, -14.0), Vector3(9.0, 5.0, 0.0))
	kit.set_paint(Color("4f565e"), 0.7, 0.0, -1, 0.0)
	kit.hip_roof(Vector3(-9.6, 5.0, -14.6), Vector3(9.6, 5.0, 0.6), 2.4, 1.4)
	kit.set_paint(Color("2b2d30"), 0.6, 0.3, -1, 0.0)
	kit.cylinder(c, 40.0, 41.5, 4.6, 4.6, 16, true)
	kit.set_paint(Color("5d6670"), 0.25, 0.3, 12, 0.9)
	kit.cylinder(c, 41.5, 47.0, 2.4, 2.4, 12, false)
	kit.set_paint(Color("2b2d30"), 0.5, 0.4, -1, 0.0)
	kit.dome(c, 47.0, 2.6, 3.0, 12, 5)
	kit.box(c + Vector3(-0.2, 50.0, -0.2), c + Vector3(0.2, 51.0, 0.2))
	# Arcade's lamp: radius max(2.5 px, 3.5 m … 25.5 m with the flash), alpha 0.5 … 1 (the shader's mode 2)
	kit.glow(c + Vector3(0.0, 44.2, 0.0), Color(1.0, 0.95, 0.75), 1.0, 3.5, 2.5, Vector4(2.0, 15.0, 0.0, 0.0))
	# Arcade's four beams (RoadRenderer.LIGHTHOUSE_BEAM_M 240 m, one revolution in LIGHTHOUSE_PERIOD_S 15 s)
	for i in 4:
		kit.beam(c + Vector3(0.0, 44.2, 0.0), Color(1.0, 0.96, 0.82), 0.22, 240.0 / kit.k, 15.0, float(i) * PI * 0.5)


## Skyscraper cluster (RoadRenderer._lm_skyscrapers, reference height 259 m – Frankfurt, Cuatro Torres): five towers
## with glass facades (floor bands and mullions in the shader, random lit windows at night), a mast or a pyramid on
## top, a blinking red aviation light on each.
static func _skyscrapers(kit: ShapeKit) -> void:
	var towers: Array = [[-62.0, 14.0, 150.0, "7f97ad", 0], [58.0, 13.0, 175.0, "c9bfa8", 2], [-20.0, 18.0, 259.0, "6a8098", 1],
		[22.0, 15.0, 205.0, "95aec4", 1], [86.0, 11.0, 120.0, "8aa0b4", 0]]
	var i := 0
	for t: Array in towers:
		var xo := float(t[0])
		var hw := float(t[1])
		var th := float(t[2])
		var base := Color(str(t[3]))
		var zc := -hw - (8.0 if i % 2 == 1 else 0.0)
		kit.set_paint(base, 0.3, 0.3, 16, 1.0)
		kit.box(Vector3(xo - hw, 0.0, zc - hw), Vector3(xo + hw, th, zc + hw))
		kit.set_paint(base.darkened(0.3), 0.6, 0.2, -1, 0.0)
		kit.box(Vector3(xo - hw - 0.3, th, zc - hw - 0.3), Vector3(xo + hw + 0.3, th + 1.2, zc + hw + 0.3))
		var top := th + 1.2
		match int(t[4]):
			1:
				kit.box(Vector3(xo - 0.5, top, zc - 0.5), Vector3(xo + 0.5, top + 22.0, zc + 0.5))
				top += 22.0
			2:
				kit.set_paint(base.darkened(0.1), 0.5, 0.2, -1, 0.0)
				kit.pyramid(Vector3(xo - hw, top, zc - hw), Vector3(xo + hw, top, zc + hw), 24.0)
				top += 24.0
		# on a flat roof the light sits on the front edge, a little above it (FIX-R7b: in the roof's middle the parapet
		# hid the Arcade-sized light from below); on a mast or pyramid at its tip
		var lp := Vector3(xo, top + 0.6, zc + hw) if int(t[4]) == 0 else Vector3(xo, top, zc)
		kit.glow(lp, Color(1.0, 0.12, 0.08), 0.85, 3.0, 2.5, Vector4(1.0, 1.6, 0.8, absf(xo) * 0.01))
		i += 1


## Builder of the procedural shapes: triangles with vertex colour, roughness / metallic in UV and a lamp channel in
## UV2 (the CE_VCOL format of landmark.gdshader); positions in the reference metres of Arcade's drawing × k.
class ShapeKit:
	var k := 1.0
	var oz := 0.0                     ## reference metres added along Z before the scale k (proc_mesh: main axis on the anchor)
	var _v := PackedVector3Array()
	var _n := PackedVector3Array()
	var _c := PackedColorArray()
	var _uv := PackedVector2Array()
	var _uv2 := PackedVector2Array()
	var _i := PackedInt32Array()
	var _col := Color.WHITE
	var _ru := Vector2(0.85, 0.0)
	var _ch := Vector2(-1.0, 0.0)
	# glow points: position, colour + strength, (size m, min px), (mode, period, lit, phase)
	var _gp := PackedVector3Array()
	var _gc := PackedColorArray()
	var _gs := PackedVector2Array()
	var _gm: Array[Vector4] = []
	# lighthouse beams: position, colour + strength, (3, period, length, phase)
	var _bp := PackedVector3Array()
	var _bc := PackedColorArray()
	var _bm: Array[Vector4] = []

	func set_paint(col: Color, rough: float, metal: float, channel: int, weight: float) -> void:
		_col = col
		_ru = Vector2(rough, metal)
		_ch = Vector2(float(channel) + 0.5, weight) if channel >= 0 else Vector2(-1.0, 0.0)

	func _vert(p: Vector3, nrm: Vector3) -> int:
		_v.append((p + Vector3(0.0, 0.0, oz)) * k)
		_n.append(nrm.normalized())
		_c.append(_col)
		_uv.append(_ru)
		_uv2.append(_ch)
		return _v.size() - 1

	## Triangle p0 p1 p2 facing `out` (Godot draws clockwise faces as front faces), vertex normals n0..n2.
	func tri(p0: Vector3, p1: Vector3, p2: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, out: Vector3) -> void:
		var fn := (p1 - p0).cross(p2 - p0)
		var a := _vert(p0, n0)
		var b := _vert(p1, n1)
		var c := _vert(p2, n2)
		if fn.dot(out) > 0.0:
			_i.append_array(PackedInt32Array([a, c, b]))
		else:
			_i.append_array(PackedInt32Array([a, b, c]))

	## Flat quad p0..p3 (in order round its edge) facing `out`.
	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, out: Vector3) -> void:
		tri(p0, p1, p2, out, out, out, out)
		tri(p0, p2, p3, out, out, out, out)

	func box(a: Vector3, b: Vector3) -> void:
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var y0 := minf(a.y, b.y)
		var y1 := maxf(a.y, b.y)
		var z0 := minf(a.z, b.z)
		var z1 := maxf(a.z, b.z)
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK)
		quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3.FORWARD)
		quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT)
		quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3.RIGHT)
		quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.UP)

	## Hipped roof on the rectangle a..b (y = a.y), ridge `rise` higher, its ends `inset` in from the short sides.
	func hip_roof(a: Vector3, b: Vector3, rise: float, inset: float) -> void:
		var y := a.y
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var z0 := minf(a.z, b.z)
		var z1 := maxf(a.z, b.z)
		var zm := (z0 + z1) * 0.5
		var depth := z1 - z0
		var r0 := Vector3(x0 + inset, y + rise, zm)
		var r1 := Vector3(x1 - inset, y + rise, zm)
		if x1 - x0 < depth:
			r0 = Vector3((x0 + x1) * 0.5, y + rise, z0 + inset)
			r1 = Vector3((x0 + x1) * 0.5, y + rise, z1 - inset)
		var c00 := Vector3(x0, y, z0)
		var c10 := Vector3(x1, y, z0)
		var c11 := Vector3(x1, y, z1)
		var c01 := Vector3(x0, y, z1)
		if x1 - x0 >= depth:
			_slope(c01, c11, r1, r0, Vector3(0.0, 1.0, 1.0))
			_slope(c10, c00, r0, r1, Vector3(0.0, 1.0, -1.0))
			_slope3(c00, c01, r0, Vector3(-1.0, 1.0, 0.0))
			_slope3(c11, c10, r1, Vector3(1.0, 1.0, 0.0))
		else:
			_slope(c00, c01, r1, r0, Vector3(-1.0, 1.0, 0.0))
			_slope(c11, c10, r0, r1, Vector3(1.0, 1.0, 0.0))
			_slope3(c01, c11, r1, Vector3(0.0, 1.0, 1.0))
			_slope3(c10, c00, r0, Vector3(0.0, 1.0, -1.0))

	func _slope(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, out: Vector3) -> void:
		var nrm := (p1 - p0).cross(p2 - p0).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		tri(p0, p1, p2, nrm, nrm, nrm, nrm)
		tri(p0, p2, p3, nrm, nrm, nrm, nrm)

	func _slope3(p0: Vector3, p1: Vector3, p2: Vector3, out: Vector3) -> void:
		var nrm := (p1 - p0).cross(p2 - p0).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		tri(p0, p1, p2, nrm, nrm, nrm, nrm)

	func pyramid(a: Vector3, b: Vector3, rise: float) -> void:
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var z0 := minf(a.z, b.z)
		var z1 := maxf(a.z, b.z)
		var top := Vector3((x0 + x1) * 0.5, a.y + rise, (z0 + z1) * 0.5)
		var cs := [Vector3(x0, a.y, z1), Vector3(x1, a.y, z1), Vector3(x1, a.y, z0), Vector3(x0, a.y, z0)]
		for i in 4:
			var p0: Vector3 = cs[i]
			var p1: Vector3 = cs[(i + 1) % 4]
			var mid := (p0 + p1) * 0.5
			var out := Vector3(mid.x - top.x, 0.0, mid.z - top.z).normalized() + Vector3.UP * 0.5
			_slope3(p0, p1, top, out)

	## Frustum about the vertical axis through centre c: from y0 (radius r0) to y1 (radius r1), smooth sides,
	## optionally a flat top.
	func cylinder(c: Vector3, y0: float, y1: float, r0: float, r1: float, sides: int, top: bool) -> void:
		var slope := (r0 - r1) / maxf(y1 - y0, 0.001)
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var n0 := Vector3(d0.x, slope, d0.z)
			var n1 := Vector3(d1.x, slope, d1.z)
			var p00 := c + d0 * r0 + Vector3(0.0, y0, 0.0)
			var p10 := c + d1 * r0 + Vector3(0.0, y0, 0.0)
			var p11 := c + d1 * r1 + Vector3(0.0, y1, 0.0)
			var p01 := c + d0 * r1 + Vector3(0.0, y1, 0.0)
			var out := (d0 + d1).normalized()
			tri(p00, p10, p11, n0, n1, n1, out)
			tri(p00, p11, p01, n0, n1, n0, out)
			if top and r1 > 0.0:
				var ct := c + Vector3(0.0, y1, 0.0)
				tri(ct, p01, p11, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)

	## Upper half of an ellipsoid (radius rx across, ry up) standing on y0 round the vertical axis through c.
	func dome(c: Vector3, y0: float, rx: float, ry: float, sides: int, rings: int) -> void:
		_ellipsoid(c + Vector3(0.0, y0, 0.0), rx, ry, sides, rings, 0.0)

	func sphere(centre: Vector3, r: float, sides: int, rings: int) -> void:
		_ellipsoid(centre, r, r, sides, rings, -PI * 0.5)

	func _ellipsoid(o: Vector3, rx: float, ry: float, sides: int, rings: int, phi0: float) -> void:
		var span := PI * 0.5 - phi0
		for j in rings:
			var f0 := phi0 + span * float(j) / float(rings)
			var f1 := phi0 + span * float(j + 1) / float(rings)
			for i in sides:
				var a0 := TAU * float(i) / float(sides)
				var a1 := TAU * float(i + 1) / float(sides)
				var p00 := _ell(o, rx, ry, a0, f0)
				var p10 := _ell(o, rx, ry, a1, f0)
				var p11 := _ell(o, rx, ry, a1, f1)
				var p01 := _ell(o, rx, ry, a0, f1)
				var n00 := _ell_n(o, rx, ry, p00)
				var n10 := _ell_n(o, rx, ry, p10)
				var n11 := _ell_n(o, rx, ry, p11)
				var n01 := _ell_n(o, rx, ry, p01)
				var out := (n00 + n11).normalized()
				if p11.distance_to(p01) > 1.0e-5:
					tri(p00, p10, p11, n00, n10, n11, out)
				tri(p00, p11, p01, n00, n11, n01, out)

	static func _ell(o: Vector3, rx: float, ry: float, a: float, f: float) -> Vector3:
		return o + Vector3(cos(a) * cos(f) * rx, sin(f) * ry, sin(a) * cos(f) * rx)

	static func _ell_n(o: Vector3, rx: float, ry: float, p: Vector3) -> Vector3:
		var d := p - o
		return Vector3(d.x / (rx * rx), d.y / (ry * ry), d.z / (rx * rx)).normalized()

	## An arched window (width w, height h: a rectangle with a half disc on top) on a wall facing `out`, its foot
	## centred at p; a few centimetres in front of the wall.
	func arch_window(p: Vector3, w: float, h: float, out: Vector3) -> void:
		var o := out.normalized()
		var across := Vector3.UP.cross(o).normalized()
		var base := p + o * 0.06
		var hw := w * 0.5
		var hr := h - hw
		quad(base - across * hw, base + across * hw, base + across * hw + Vector3.UP * hr, base - across * hw + Vector3.UP * hr, o)
		var c := base + Vector3.UP * hr
		for i in 6:
			var a0 := PI * float(i) / 6.0
			var a1 := PI * float(i + 1) / 6.0
			tri(c, c + across * cos(a0) * hw + Vector3.UP * sin(a0) * hw, c + across * cos(a1) * hw + Vector3.UP * sin(a1) * hw, o, o, o, o)

	## A narrow vertical window on a round wall of radius r about c, at angle a, from y0 to y1, width w.
	func slit(c: Vector3, r: float, a: float, y0: float, y1: float, w: float) -> void:
		var d := Vector3(cos(a), 0.0, sin(a))
		var across := Vector3(-d.z, 0.0, d.x)
		var p := c + d * (r + 0.06)
		quad(p - across * w * 0.5 + Vector3(0.0, y0, 0.0), p + across * w * 0.5 + Vector3(0.0, y0, 0.0),
			p + across * w * 0.5 + Vector3(0.0, y1, 0.0), p - across * w * 0.5 + Vector3(0.0, y1, 0.0), d)

	## A glow point (CE_GLOW): colour, strength, size (reference m), minimum px, (mode, period, lit, phase).
	func glow(p: Vector3, col: Color, strength: float, size_m: float, min_px: float, mode: Vector4) -> void:
		_gp.append((p + Vector3(0.0, 0.0, oz)) * k)
		_gc.append(Color(col.r, col.g, col.b, strength))
		_gs.append(Vector2(size_m * k, min_px))
		_gm.append(mode)

	## A lighthouse beam (CE_GLOW mode 3): from p, `length_m` long (reference metres), turning once in `period` s.
	func beam(p: Vector3, col: Color, strength: float, length_m: float, period: float, phase: float) -> void:
		_bp.append((p + Vector3(0.0, 0.0, oz)) * k)
		_bc.append(Color(col.r, col.g, col.b, strength))
		_bm.append(Vector4(3.0, period, length_m * k, phase))

	func tris() -> int:
		return _i.size() / 3

	func glow_count() -> int:
		return _gp.size()

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _v
		arr[Mesh.ARRAY_NORMAL] = _n
		arr[Mesh.ARRAY_COLOR] = _c
		arr[Mesh.ARRAY_TEX_UV] = _uv
		arr[Mesh.ARRAY_TEX_UV2] = _uv2
		arr[Mesh.ARRAY_INDEX] = _i
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	func glow_mesh() -> ArrayMesh:
		if _gp.is_empty() and _bp.is_empty():
			return null
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var col := PackedColorArray()
		var cu := PackedFloat32Array()
		var idx := PackedInt32Array()
		var lo := _gp[0] if not _gp.is_empty() else _bp[0]
		var hi := lo
		for g in _gp.size():
			var b := v.size()
			for corner: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
				v.append(_gp[g])
				uv.append(corner)
				uv2.append(_gs[g])
				col.append(_gc[g])
				var m: Vector4 = _gm[g]
				cu.append_array(PackedFloat32Array([m.x, m.y, m.z, m.w]))
			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			lo = lo.min(_gp[g])
			hi = hi.max(_gp[g])
		for g in _bp.size():
			var b := v.size()
			var m: Vector4 = _bm[g]
			for corner: Vector2 in [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
				v.append(_bp[g])
				uv.append(corner)
				uv2.append(Vector2(0.07 * m.z, 0.0))
				col.append(_bc[g])
				cu.append_array(PackedFloat32Array([m.x, m.y, m.z, m.w]))
			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			lo = lo.min(_bp[g] - Vector3.ONE * m.z)
			hi = hi.max(_bp[g] + Vector3.ONE * m.z)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_CUSTOM0] = cu
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		# the shader spreads every quad round its point (at least a few pixels): room for that in the bounds
		var pad := Vector3.ONE * 60.0
		m.custom_aabb = AABB(lo - pad, hi - lo + pad * 2.0)
		return m
