extends ChunkBuilder
## Mode "Modern" (v0.8.0): the scenery props of a road chunk – trees, bushes, rocks, bales, houses, pylons, the
## structures of fuel stations and borders – as MultiMesh nodes (contract §4.5.5, D21–D24, amendments A-3, A-4, A-7;
## German docs: docs/renderer-modern-gelaende.md).
##
## Source: the props of the chunk's TrackSegment.sprites (kind "prop", and the objects of OBJECT_SETS – the street
## lights of the City Limits – while no builder "city" exists), exactly the list Arcade draws, minus the documented
## drops (drop_reason()):
##   "ribbon"    the prop stands beyond the clamped terrain ribbon (inside of a bend, medial axis): no ground there
##   "corridor"  decorative scenery inside the sight corridor of a bend (fairness rule F7): scenery-rule props and all
##               vegetation. A dropped plant is replaced by ground cover (amendment A-3): pieces of the sets of
##               graphics.modern.props.bend_cover (props/cover_bush, props/cover_grass), at most bend_cover_max_h_m
##               (0.5 m) high – one for a bush, three for a tree, not in the City Limits (cover_pieces(); debug
##               "cover", list "cover_list");
##               a set of that list that the track itself places stays, scaled down to that height
##   "missing"   the set (and its fallback set) has neither a model nor a sprite sheet. A LANDMARK whose set has
##               neither is one that Arcade draws procedurally ("proc": Track._build_landmark drops its "fallback" for
##               that): here the fallback set of its stage-plan entry stands in (landmark_fallbacks(), FIX-WASSER-R,
##               QA-WASSER B1 – Belgrad, Hannover, Leipzig, Dortmund, Calais and Madrid had no landmark at all)
##   "density"   "Details" below 1.0 thins decorative trees, bushes, rocks and bales (thinnable(); never buildings,
##               landmarks or tall structures)
## What a set is comes from the PropLibrary: a MODEL is placed like a vehicle (local -Z along the road, origin = the
## sprite anchor) on ChunkContext.ground(), trees, plants and rocks with a stable random yaw, one variant model per
## chunk and set (chunk_variant(): a set costs at most its surfaces in draw calls per chunk and side); a SPRITE
## stand-in is a billboard of the Arcade sprite cell (assets/shaders/modern/billboard.gdshader), lit from the scene.
## Per chunk and (model | set, mirrored) there is ONE MultiMesh per representation:
##   models     level 0 / 1 / 2 of the chunk (lod0, lod1, impostor or the coarsest level) – one is visible at a time,
##              chosen in update() from the path distance of the chunk to the camera and levels.prop_lod0_m /
##              prop_lod1_m (hard swaps, D9); + the low-poly shadow caster of card trees (shadows only)
##   stand-ins  one billboard MultiMesh
## Props of the left roadside whose set is built for the right one (tag mirror_left; for sprites also the "mirror"
## of a scenery rule) go into a second MultiMesh under a node mirrored in x (D24); landmarks are never mirrored.
## One more MultiMesh per chunk lays the contact shadows (contact_shadow.gdshader). Lamps of prop models (anchors
## with a direction: street lights) are registered through ctx.services.renderer.add_lamps() (A-7).
## A stand-in of an item that Arcade draws procedurally instead of its sprite ("prefer_proc": the pylons of the
## cable-stayed bridges) never shows the sprite's light layer and takes no light of the player's headlights
## (dark_material(), FIX-WASSER-R, QA-WASSER B2): Arcade's procedural pylon stays concrete grey at night, while the
## light layer of the sprite – a floodlit pylon – made the Köhlbrandbrücke's pylons glow almost white.
## build() runs on worker threads: ctx snapshot arrays and the plain tables of collect() only.
## Owner: package terrain / props / far ground.

const OBJECT_SETS := {"streetlight": "props/streetlight"}   ## Track "object" items drawn here while builders/city.gd is missing
const RIBBON_MARGIN_M := 1.0       ## a prop needs this much ribbon beyond its foot
const SLOPE_PROBE_M := 1.5         ## the ground plane under a prop is taken from points this far apart
const BLOB_LIFT_M := 0.03
const SHADOW_KEEP_M := 40.0        ## shadow casters stay on this far beyond the reach of the shadow map
const LOD_HYSTERESIS_M := 6.0      ## a chunk leaves a level this much later than it enters it
const LOD_STEP_M := 2.0            ## update() looks at the chunk levels again after this much driving
const COVER_PER_TREE := 3          ## pieces of ground cover for a tree dropped in a bend corridor (one for a bush)
const COVER_SPREAD_M := 2.5        ## … scattered at most this far around its foot
const COVER_MIN_BEYOND_M := 0.8    ## … and never closer than this to the paved edge
const COVER_ITEM_BASE := 100000    ## item numbers of the pieces (hashes, lists): beyond every real item
## Arcade's procedural pylon of a cable-stayed bridge (item "proc": "pylon") blinks its red aviation light
## (RoadRenderer._pylon: lit while fmod(time + side × 0.4, 1.6) < 0.8, at night): the beacon lamps of the pylon model
## (anchors at least PropLibrary.BEACON_MIN_H_M high) get that rhythm as "blink" = (period s, lit s, phase s per side),
## which the flare layer reads with view.time (M2ZS1)
const PYLON_BLINK := Vector3(1.6, 0.8, 0.4)
## Albedo of a "prefer_proc" pylon model at night (baked.gdshader night_albedo): Arcade's procedural pylon is concrete ×
## the ambient light (RoadRenderer._oc), the moon lights the model's light-concrete faces. Measured in FIX-WASSER-R's
## pylon region (x 500–780, y 150–350) at the Köhlbrandbrücke km 78.1, 22:00, "Hoch" (M2ZS1): mean luminance Arcade
## 60.1, ZS1 (dark stand-in) 58.4, the model with its night atlas 84.4, without it 79.5, with 0.55 60.2 – 0.5 keeps
## the pylon a little darker than Arcade, like ZS1's stand-in.
const PYLON_NIGHT_ALBEDO := 0.5

var library: PropLibrary

var _renderer: Node                ## untyped: packages talk to each other through the facade only
var _lod0_m := 60.0
var _lod1_m := 200.0
var _density := 1.0
var _casters := 2
var _shadow_m := 120.0
var _cover_sets: Array = []
var _cover_max_h := 0.5
var _skip_objects := false
var _skip_landmarks := false
var _skip_bridge := false
var _holders: Array = []           ## committed "Props" nodes (main thread: commit / update)
var _lod_z := -1.0e12              ## camera position of the last look at the chunk levels
var _prepared := false
## FIX1 (QA QB-03): landmarks keep Arcade's landmark law (RoadRenderer.landmark_fade: visible up to visibility ×
## render.landmark_range_factor, at most render.landmark_far_m, with its haze) – in their chunk through a material of
## their own (billboard.gdshader landmark_law), beyond the committed chunks as single stand-ins on the path (update()),
## so Elbphilharmonie and Michel stand on the horizon as early as in Arcade (they appeared only at ~765 m).
var _lm_law := Vector2(2.0, 1900.0)
var _lm_mats: Dictionary = {}      ## set id -> landmark material (main thread)
var _far: Dictionary = {}          ## index into Track.landmarks -> MeshInstance3D beyond the committed chunks
var _far_z := -1.0e12              ## camera position of the last look at the far landmarks
var _lm_fallback: Dictionary = {}  ## landmark set Arcade draws procedurally -> fallback set of the stage plan (B1)
var _dark_mats: Dictionary = {}    ## set id -> stand-in material without light layer and headlights (B2)


func id() -> String:
	return "props"


func _lib() -> PropLibrary:
	if library == null:
		library = PropLibrary.new()
	return library


# --- hooks of the renderer (all optional; the builder also works without a renderer) ----------------------------

func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer != null and renderer.has_method(&"builder"):
		_skip_objects = renderer.call(&"builder", "city") != null
		_skip_landmarks = renderer.call(&"builder", "landmarks") != null
		_skip_bridge = renderer.call(&"builder", "bridge") != null
	var cfg: Variant = renderer.get("cfg") if renderer != null else null
	if cfg is Dictionary:
		_read_config(cfg)


func _read_config(cfg: Dictionary) -> void:
	_lm_law = Vector2(float(ConfigLoader.lookup(cfg, "render.landmark_range_factor", 2.0)),
		float(ConfigLoader.lookup(cfg, "render.landmark_far_m", 1900.0)))
	var p: Variant = ConfigLoader.lookup(cfg, "graphics.modern.props", {})
	if p is Dictionary:
		var list: Variant = (p as Dictionary).get("bend_cover", [])
		_cover_sets = list if list is Array else []
		_cover_max_h = maxf(0.05, float((p as Dictionary).get("bend_cover_max_h_m", 0.5)))


func apply_quality(levels: Dictionary) -> void:
	_lod0_m = float(levels.get("prop_lod0_m", _lod0_m))
	_lod1_m = maxf(_lod0_m, float(levels.get("prop_lod1_m", _lod1_m)))
	_density = float(levels.get("deco_density", _density))
	_casters = int(levels.get("shadow_casters", _casters))
	_shadow_m = float(levels.get("shadow_distance_m", _shadow_m))


## ctx.sets = every sprite set id the stage can show: the prop and landmark sets are resolved and loaded here.
func prepare(ctx: Dictionary) -> void:
	var wanted: Array = []
	for id_v: Variant in ctx.get("sets", []):
		var set_id := str(id_v)
		if set_id.begins_with("props/") or set_id.begins_with("landmarks/"):
			wanted.append(set_id)
	for obj: String in OBJECT_SETS:
		wanted.append(str(OBJECT_SETS[obj]))
	for c: Variant in _cover_sets:
		if not wanted.has(str(c)):
			wanted.append(str(c))       # ground cover of the bend corridors: modern-only sets, never in the stage list
	# a set that is missing is drawn by its fallback set (Track.sprite_fallbacks): the stage list does not name those
	var track: Variant = _renderer.get("track") if _renderer != null else null
	if track is Track:
		var fallbacks: Dictionary = (track as Track).sprite_fallbacks()
		for set_id: String in wanted.duplicate():
			if fallbacks.has(set_id) and not wanted.has(str(fallbacks[set_id])):
				wanted.append(str(fallbacks[set_id]))
		# landmarks Arcade draws procedurally: their stand-in sets (B1)
		_lm_fallback = landmark_fallbacks(track as Track)
		for set_id: String in _lm_fallback:
			if not wanted.has(str(_lm_fallback[set_id])):
				wanted.append(str(_lm_fallback[set_id]))
	_lib().request(wanted, self)
	_prepared = true


## Landmark set -> fallback set, for the landmarks of the stage plan that Arcade draws procedurally ("proc"). The
## frozen Track._build_landmark drops the "fallback" of such a landmark – Arcade draws its procedural picture
## instead – so the items carry no fallback set; the plan's entries (CityData.landmark_entry) still name it. Used
## only when the landmark's own set has neither a model nor a sprite (FIX-WASSER-R, QA-WASSER B1).
static func landmark_fallbacks(track: Track) -> Dictionary:
	var out := {}
	if track == null or track.plan == null:
		return out
	for lm: Dictionary in track.plan.landmarks:
		if lm.has("proc") and str(lm.get("fallback", "")) != "":
			out[str(lm.get("set", ""))] = str(lm["fallback"])
	return out


func prepare_pending() -> int:
	return _lib().pending() if _prepared else 0


func fail_reason() -> String:
	return _lib().fail_reason() if _prepared else ""


func update(view: Dictionary, _dt: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	if absf(cam_z - _far_z) >= LOD_STEP_M or _far_z < -1.0e11:
		_far_z = cam_z
		_update_far_landmarks(view, cam_z)
	if absf(cam_z - _lod_z) < LOD_STEP_M:
		return      # the levels are a matter of tens of metres: looked at every few metres of driving
	_lod_z = cam_z
	var i := _holders.size() - 1
	while i >= 0:
		var h: Variant = _holders[i]
		if not is_instance_valid(h):
			_holders.remove_at(i)
		else:
			_apply_lod(h, cam_z)
		i -= 1


func perf() -> Dictionary:
	var n := 0
	for h: Variant in _holders:
		if is_instance_valid(h):
			n += int((h as Node).get_meta(&"instances", 0))
	return {"instances": n, "fallback_sets": _lib().fallback_sets}


func snapshot() -> Dictionary:
	var counts := {}
	for h: Variant in _holders:
		if not is_instance_valid(h):
			continue
		var c: Dictionary = (h as Node).get_meta(&"counts", {})
		for k: String in c:
			counts[k] = int(counts.get(k, 0)) + int(c[k])
	return {"props": counts}


## The stand-in material of a landmark set: the set's billboard material with Arcade's landmark law (main thread).
func landmark_material(set_id: String) -> ShaderMaterial:
	var m: Variant = _lm_mats.get(set_id)
	if m != null:
		return m
	var s := _lib().standin(set_id)
	if s.is_empty():
		return null
	var mat := (s["material"] as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("landmark_law", _lm_law)
	_lm_mats[set_id] = mat
	return mat


## The stand-in material of a set for items Arcade draws procedurally instead of the sprite ("prefer_proc": bridge
## pylons): without the sprite's light layer and without the player's headlights – the light layer of the pylon
## sprite is a floodlit pylon that Arcade never shows (its procedural pylon stays concrete grey at night: base colour
## x ambient light), and the headlights would light the whole 88 m billboard from its foot (main thread).
func dark_material(set_id: String) -> ShaderMaterial:
	var m: Variant = _dark_mats.get(set_id)
	if m != null:
		return m
	var s := _lib().standin(set_id)
	if s.is_empty():
		return null
	var mat := (s["material"] as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("lights_rect", Vector4.ZERO)
	mat.set_shader_parameter("headlight_color", Vector3.ZERO)
	_dark_mats[set_id] = mat
	return mat


## The model of an item Arcade draws procedurally ("prefer_proc": bridge pylons, M2ZS1): its one surface's material
## (baked.gdshader) duplicated without the night atlas (emit_energy 0), as the override of the node – AS4R baked the
## sprite's floodlit pylon into the model's emission, which Arcade never shows (its procedural pylon is concrete x
## ambient light at night: the Köhlbrandbrücke's pylons glowed light grey at 22:00). Same shader, no new variant; the
## red aviation light stays as a blinking lamp of the flare layer (PYLON_BLINK). One copy per source material.
func _dark_model_override(node: GeometryInstance3D, part: Dictionary) -> void:
	var mesh: Variant = part.get("mesh")
	if not (mesh is Mesh) or (mesh as Mesh).get_surface_count() != 1:
		return
	var src := (mesh as Mesh).surface_get_material(0)
	if not (src is ShaderMaterial):
		return
	var key := "model%d" % src.get_instance_id()
	var m: Variant = _dark_mats.get(key)
	if m == null:
		var dup := (src as ShaderMaterial).duplicate() as ShaderMaterial
		dup.set_shader_parameter("emit_energy", 0.0)
		dup.set_shader_parameter("night_albedo", PYLON_NIGHT_ALBEDO)
		_dark_mats[key] = dup
		m = dup
	node.material_override = m


## A landmark model drawn with Arcade's landmark law: its one surface's material (baked.gdshader) duplicated with
## landmark_law set, as the override of the node. Models with several surfaces keep their materials (none in M1).
func _landmark_override(node: GeometryInstance3D, part: Dictionary) -> void:
	var mesh: Variant = part.get("mesh")
	if not (mesh is Mesh) or (mesh as Mesh).get_surface_count() != 1:
		return
	var src := (mesh as Mesh).surface_get_material(0)
	if not (src is ShaderMaterial):
		return
	var key := "m%d" % src.get_instance_id()
	var m: Variant = _lm_mats.get(key)
	if m == null:
		var dup := (src as ShaderMaterial).duplicate() as ShaderMaterial
		dup.set_shader_parameter("landmark_law", _lm_law)
		_lm_mats[key] = dup
		m = dup
	node.material_override = m


## Arcade's landmark range for a visibility (RoadRenderer._landmark_range).
func landmark_range(vis: float) -> float:
	return clampf(vis * _lm_law.x, minf(vis, 600.0), maxf(_lm_law.y, vis))


## How far ahead landmarks stand beyond the committed chunks in the frame `view`: Arcade's landmark range – and at
## night (palette "lights" > 0.05) at least render.landmark_far_m, where Arcade still draws their illumination
## (RoadRenderer._draw_far_landmarks; M2INT). Beyond the range of the picture billboard.gdshader / baked.gdshader keep
## only the lit pixels.
func far_reach(view: Dictionary) -> float:
	var reach := landmark_range(float(view.get("visibility_m", 900.0)))
	var pal: Variant = view.get("palette", {})
	if pal is Dictionary and float((pal as Dictionary).get("lights", 0.0)) > 0.05:
		reach = maxf(reach, _lm_law.y)
	return reach


## Landmarks ahead whose chunk is not committed yet, up to Arcade's landmark range: one stand-in each on the path
## (the path is integrated up to graphics.modern.landmark_path_m ahead). Placed like _place() places them, so the
## stand-in of the chunk takes over at the same spot; sets with a model are left to their chunk (none in M1).
func _update_far_landmarks(view: Dictionary, cam_z: float) -> void:
	if _renderer == null or not _prepared or _skip_landmarks:
		return
	var track: Variant = _renderer.get("track")
	var streamer: Variant = _renderer.get("streamer")
	var world: Variant = _renderer.get("world")
	if not (track is Track) or streamer == null or not (world is Node3D):
		return
	var trk := track as Track
	var lib := _lib()
	var reach := far_reach(view)
	var chunk_m := float(int(streamer.get("chunk_segments"))) * trk.seg_len
	var terrain: Variant = _renderer.get("terrain")
	var keep := {}
	for li in trk.landmarks.size():
		var it: Dictionary = trk.landmarks[li]
		var z := float(it.get("z", 0.0))
		var dz := z - cam_z
		if dz <= 0.0 or dz > reach or streamer.call(&"chunk_node", int(floor(z / chunk_m))) != null:
			continue
		var set_id := str(it.get("set", ""))
		var e: Dictionary = lib.sets.get(set_id, {})
		var sc := float(it.get("scale", 1.0))
		var tint := Color(str(it["tint"])) if it.has("tint") else Color.WHITE
		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			set_id = str(it.get("fallback", _lm_fallback.get(set_id, "")))
			e = lib.sets.get(set_id, {}) if set_id != "" else {}
			sc *= float(it.get("fallback_scale", 1.0))
			if it.has("fallback_tint"):
				tint *= Color(str(it["fallback_tint"]))
		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			continue
		var is_model := int(e["kind"]) == PropLibrary.MODEL
		var parts: Array = []
		if is_model:
			var variants: Array = e.get("variants", [])
			var md: Dictionary = lib.models.get(str(variants[0]) if not variants.is_empty() else "", {})
			var reps: Array = md.get("reps", [])
			if reps.is_empty():
				continue
			for pv: Variant in lib.mesh_parts(str(variants[0]), str(reps[reps.size() - 1])):
				if not bool((pv as Dictionary)["shadow"]):
					parts.append(pv)
		else:
			var mat := landmark_material(str(e["set"]))
			var st := lib.standin(str(e["set"]))
			if mat != null and not st.is_empty():
				parts.append({"mesh": st["mesh"], "material": mat, "transform": Transform3D.IDENTITY})
		if parts.is_empty():
			continue
		var side := int(it.get("side", 1))
		var x := float(it.get("x", 0.0))
		if it.has("align") and side != 0:
			x = edge_anchor_x(x, side, false, float(e["extent_l"]), float(e["extent_r"]), sc)
		var h := 0.0
		if terrain is TerrainProfile and side != 0:
			var edges := trk.road_edges_at(z)
			var beyond := (x - edges.y if x > 0.0 else -x + edges.x) - trk.shoulder_w
			h = (terrain as TerrainProfile).height(int(floor(z / trk.seg_len)), -1 if x < 0.0 else 1, maxf(0.0, beyond))
		var node: Node3D = _far.get(li)
		if node == null or not is_instance_valid(node):
			node = Node3D.new()
			node.name = "FarLandmark%d" % li
			for pv: Variant in parts:
				var pd: Dictionary = pv
				if not is_model and tint != Color.WHITE:
					# a tinted stand-in (the fallback of a procedural landmark, B1): the tint is the instance colour,
					# as in its chunk (_place()) – a plain MeshInstance3D would show it untinted until the chunk comes
					var one := PackedFloat32Array()
					_put(one, Transform3D.IDENTITY)
					one.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
					var mm := _mmi(pd, one, 1, true, false)
					mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.add_child(mm)
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = pd["mesh"]
				mi.transform = pd.get("transform", Transform3D.IDENTITY)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if pd.get("material") != null:
					mi.material_override = pd["material"]
				elif is_model:
					_landmark_override(mi, pd)
				node.add_child(mi)
			(world as Node3D).add_child(node)
			_far[li] = node
		var basis := Basis.from_scale(Vector3(sc, sc, sc))
		if is_model:
			# a model stands like in its chunk: ChunkContext.frame() – turned with the road at z, never mirrored
			var path: Variant = _renderer.get("path")
			if path is RoadPath3D:
				var a := (path as RoadPath3D).heading_at(z)
				basis = Basis(RoadPath3D.right_of(a), Vector3.UP, -RoadPath3D.fwd_of(a)).scaled_local(Vector3(sc, sc, sc))
		node.transform = Transform3D(basis, _renderer.call(&"road_to_world", z, x, h))
		keep[li] = true
	for li: Variant in _far.keys():
		if not keep.has(li):
			var n: Variant = _far[li]
			if is_instance_valid(n):
				(n as Node).queue_free()
			_far.erase(li)


## The floating origin moved: the far landmarks hang under renderer.world (origin-relative).
func rebased(shift: Vector3) -> void:
	for n: Variant in _far.values():
		if is_instance_valid(n):
			(n as Node3D).position += shift


## Hook of the renderer: what the props draw, compiled behind the loading cover – every representation of every
## model the stage loaded, as commit() draws it (a MultiMesh of one instance; shadow parts as casters), one stand-in
## billboard and the contact shadows. Per model, not per material class: a model whose textures or vertex layout
## differ from the first model of its class needs program variants of its own on some drivers (one node per class
## left two variants to the drive at Kiel – Hamburg km 2, cold-cache check of the assembly of M1).
func warmup_nodes() -> Array:
	var out: Array = []
	var lib := _lib()
	if not lib.ready():
		return out
	var one := PackedFloat32Array()
	_put(one, Transform3D.IDENTITY)
	var one_c := one.duplicate()
	one_c.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))
	var models := {}
	var standin := false
	for set_id: String in lib.sets:
		var e: Dictionary = lib.sets[set_id]
		if int(e["kind"]) == PropLibrary.MODEL:
			for v: Variant in e["variants"]:
				var mid := str(v)
				if models.has(mid) or not lib.models.has(mid):
					continue
				models[mid] = true
				var k := 2.0 / maxf(1.0, float(e["height"]))
				var reps := {}
				for r: Variant in (lib.models[mid] as Dictionary).get("reps", []):
					reps[str(r)] = true
				for r: String in reps:
					for p: Variant in lib.mesh_parts(mid, r):
						var part: Dictionary = p
						var node := _mmi(part, one, 1, false, false)
						node.scale = Vector3.ONE * k
						node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if bool(part["shadow"]) \
							else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
						out.append(node)
		elif int(e["kind"]) == PropLibrary.SPRITE and not standin:
			var s := lib.standin(set_id)
			if not s.is_empty():
				standin = true
				out.append(_mmi(s, one_c, 1, true, false))
	var c := lib.contact()
	var blob := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = c["mesh"]
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)))
	mm.set_instance_custom_data(0, Color(1.0, 1.0, 0.0, 0.0))
	blob.multimesh = mm
	blob.material_override = c["material"]
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.append(blob)
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and library != null:
		library.clear(self)


# --- chunk building ---------------------------------------------------------------------------------------------

## Main thread: the plain tables build() reads. Without a prepare() (tests of the kernel without a renderer) the sets
## of this chunk are resolved and loaded here, synchronously.
func collect(ctx: ChunkContext) -> Variant:
	var lib := _lib()
	if not _prepared:
		_read_config(ctx.cfg)
		if not ctx.levels.is_empty():
			apply_quality(ctx.levels)
	# sets the library does not know yet: a stage without prepare() (tests of the kernel), or a set the stage list
	# did not name – resolved and loaded now, synchronously (PropLibrary.request copies its tables before it adds
	# to them, so builds that are running keep reading the old ones)
	var wanted: Array = []
	if not _prepared and ctx.track != null:
		_lm_fallback = landmark_fallbacks(ctx.track)
	for set_id: String in _lm_fallback:
		if not lib.sets.has(str(_lm_fallback[set_id])) and not wanted.has(str(_lm_fallback[set_id])):
			wanted.append(str(_lm_fallback[set_id]))
	for seg: Dictionary in ctx.segs:
		for it: Dictionary in seg["sprites"]:
			for key: String in ["set", "fallback"]:
				if it.has(key) and not lib.sets.has(str(it[key])) and not wanted.has(str(it[key])):
					wanted.append(str(it[key]))
	for obj: String in OBJECT_SETS:
		if not lib.sets.has(str(OBJECT_SETS[obj])):
			wanted.append(str(OBJECT_SETS[obj]))
	for c: Variant in _cover_sets:
		if not lib.sets.has(str(c)) and not wanted.has(str(c)):
			wanted.append(str(c))
	if not wanted.is_empty() or not lib.ready():
		lib.request(wanted, self)
		var guard := 0
		while lib.pending() > 0 and guard < 20000:
			OS.delay_msec(1)
			guard += 1
	return {"sets": lib.sets, "models": lib.models, "density": _density, "casters": _casters, "cover": _cover_sets,
		"cover_max_h": _cover_max_h, "skip_objects": _skip_objects, "skip_landmarks": _skip_landmarks,
		"skip_bridge": _skip_bridge, "lm_fallback": _lm_fallback}


func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	# out: what the chunk part collects – groups: key -> {"model" | "set", "mirror", "buf": PackedFloat32Array, "n"}
	var out := {"groups": {}, "blobs": PackedFloat32Array(), "blob_n": 0, "lamps": [], "list": [], "cover_list": [], "counts": {},
		"dropped": {"ribbon": 0, "corridor": 0, "missing": 0, "density": 0}}
	var rows := ctx.row_count()
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		var sprites: Array = seg["sprites"]
		for j in sprites.size():
			_place(ctx, inp, out, i, seg, j, sprites[j], false)
	return {"groups": out["groups"], "blobs": out["blobs"], "blob_n": out["blob_n"], "lamps": out["lamps"], "list": out["list"],
		"cover_list": out["cover_list"], "counts": out["counts"], "dropped": out["dropped"],
		"z0": float(ctx.seg_a) * ctx.seg_len, "z1": float(ctx.seg_b) * ctx.seg_len}


## One item of a segment (row i of the chunk, item j of TrackSegment.sprites) into the part `out` (build(), worker
## thread). is_cover: a piece of ground cover that stands in for a dropped plant (the list "cover_list", not "list").
static func _place(ctx: ChunkContext, inp: Dictionary, out: Dictionary, i: int, seg: Dictionary, j: int, it: Dictionary,
		is_cover: bool) -> void:
	var sets: Dictionary = inp.get("sets", {})
	var models: Dictionary = inp.get("models", {})
	var density := float(inp.get("density", 1.0))
	var casters := int(inp.get("casters", 2))
	var cover: Array = inp.get("cover", [])
	var cover_max_h := float(inp.get("cover_max_h", 0.5))
	var dropped: Dictionary = out["dropped"]
	var seg_index := int(seg["index"])
	var set_id := item_set(it, inp)
	if set_id == "":
		return
	var sc := float(it.get("scale", 1.0))
	var tint := Color(str(it["tint"])) if it.has("tint") else Color.WHITE
	var e: Dictionary = sets.get(set_id, {})
	if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
		var fb := str(it.get("fallback", ""))
		if fb == "" and bool(it.get("landmark", false)):
			fb = str((inp.get("lm_fallback", {}) as Dictionary).get(set_id, ""))   # a procedural landmark (B1)
		e = sets.get(fb, {}) if fb != "" else {}
		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			if not is_cover:
				dropped["missing"] += 1
			return
		sc *= float(it.get("fallback_scale", 1.0))
		if it.has("fallback_tint"):
			tint *= Color(str(it["fallback_tint"]))
	if it.has("fit_w"):
		sc = float(it["fit_w"]) / maxf(0.5, float(e["width"]))      # overhead structures span the whole deck
	var side := int(it.get("side", 1))
	var z := float(it.get("z", seg["z"]))
	var x := float(it.get("x", 0.0))
	var landmark := bool(it.get("landmark", false))
	var is_model := int(e["kind"]) == PropLibrary.MODEL
	var flipped := side < 0 and not landmark and (bool(e["mirror_left"]) or (not is_model and bool(it.get("mirror", false))))
	if it.has("align") and side != 0:
		x = edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
	var reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)
	if reason != "":
		if is_cover:
			return
		dropped[reason] += 1
		if reason == "corridor" and bool(e["veg"]) and not cover.is_empty() and not bool(seg.get("city", false)):
			# A-3 (lead decision): ground cover of at most 0.5 m stands in for the plant the sight corridor drops
			for c: Dictionary in cover_pieces(ctx, it, e, z, x, side, seg_index, j, cover, sets):
				_place(ctx, inp, out, i, seg, int(c["j"]), c, true)
		return
	if side != 0 and not it.has("offset") and cover.has(str(e["set"])) and ctx.in_bend_corridor(z, x):
		sc = minf(sc, cover_max_h / maxf(0.01, float(e["height"])))   # ground cover inside the corridor
	var h := 0.0
	if it.has("h"):
		h = float(it["h"])              # given relative to the road (ships on the water)
	elif not it.has("bridge"):
		h = ctx.ground(z, x)
	var key := ""
	var model_id := ""
	var tr: Transform3D
	# an item Arcade draws procedurally instead of its sprite ("prefer_proc": the pylons of the cable-stayed bridges)
	# shows no floodlight: neither the light layer of the sprite (stand-in, FIX-WASSER-R B2) nor the night atlas of
	# the model (AS4R's pylon model carries the sprite's floodlit pylon in it, M2ZS1) – Arcade's procedural pylon stays
	# concrete grey at night; its red aviation light is a blinking lamp (PYLON_BLINK)
	var dark := not landmark and bool(it.get("prefer_proc", false))
	if is_model:
		model_id = chunk_variant(ctx.index, str(e["set"]), e["variants"])
		var yaw := hash01(seg_index, j, 5) * TAU if bool(e["veg"]) or str(e["cls"]) == "rock" else 0.0
		tr = ctx.frame(z, x, h, yaw).scaled_local(Vector3(sc, sc, sc))
		key = "%s|%s|%d" % ["md" if dark else "m", model_id, 1 if flipped else 0]
		var lamps: Array = out["lamps"]
		var pylon := str(it.get("proc", "")) == "pylon"
		for lamp: Dictionary in (models.get(model_id, {}) as Dictionary).get("lamps", []):
			var lp: Vector3 = lamp["pos"]
			var ld: Vector3 = lamp["dir"]
			if flipped:
				lp.x = -lp.x
				ld.x = -ld.x
			var entry := lamp.duplicate()
			entry["pos"] = tr * lp
			entry["dir"] = (tr.basis * ld).normalized()
			entry["size"] = float(lamp["size"]) * sc
			if pylon and lp.y >= PropLibrary.BEACON_MIN_H_M:
				entry["blink"] = Vector3(PYLON_BLINK.x, PYLON_BLINK.y, float(side) * PYLON_BLINK.z)   # Arcade blinks it
			lamps.append(entry)
	if not is_model:
		tr = Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), ctx.local(z, x, h))
		# a stand-in of an item Arcade draws procedurally (bridge pylons): no light layer, no headlights (B2)
		key = "%s|%s|%d" % ["l" if landmark else ("d" if dark else "s"), str(e["set"]), 1 if flipped else 0]
	var groups: Dictionary = out["groups"]
	var g: Dictionary = groups.get(key, {})
	if g.is_empty():
		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0,
			"landmark": landmark, "dark": dark}
		groups[key] = g
	var buf: PackedFloat32Array = g["buf"]
	_put(buf, mirror_x(tr) if flipped else tr)
	if not is_model:
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
	g["buf"] = buf
	g["n"] = int(g["n"]) + 1
	# contact shadow on the ground plane under the prop
	if float(e["blob"]) > 0.0 and not it.has("h") and not it.has("bridge") and not landmark:
		var w := float(e["width"]) * sc
		var r := maxf(0.3, w * (0.45 if str(e["cls"]) == "tree" else 0.55))
		var p0 := ctx.local(z, x, h)
		var px := ctx.local(z, x + SLOPE_PROBE_M, ctx.ground(z, x + SLOPE_PROBE_M))
		var pz := ctx.local(z + SLOPE_PROBE_M, x, ctx.ground(z + SLOPE_PROBE_M, x))
		var tx := (px - p0).normalized()
		var n := tx.cross(pz - p0).normalized()
		if n.y < 0.2:
			n = Vector3.UP
			tx = ctx.rows_r[i]
		var tz := tx.cross(n).normalized()
		var blobs: PackedFloat32Array = out["blobs"]
		_put(blobs, Transform3D(Basis(tx * r, n, tz * r), p0 + n * BLOB_LIFT_M))
		var real := 1.0 if is_model and casters >= int(e["cast"]) else 0.0
		blobs.append_array(PackedFloat32Array([float(e["height"]) / maxf(0.1, float(e["width"])), float(e["blob"]), real, 0.0]))
		out["blobs"] = blobs
		out["blob_n"] = int(out["blob_n"]) + 1
	var counts: Dictionary = out["counts"]
	counts[str(e["set"]) if is_cover else set_id] = int(counts.get(str(e["set"]) if is_cover else set_id, 0)) + 1
	(out["cover_list"] if is_cover else out["list"]).append([seg_index, j, str(e["set"]), snappedf(x, 0.001), snappedf(z, 0.001),
		snappedf(sc, 0.0001), 1 if flipped else 0, int(e["kind"])])


## Variant model of a set in a chunk (§4.6.6 variants): ONE per chunk and set, by a stable hash of the chunk index and
## the set – every instance of the set in the chunk shares the seed variant, so a set costs one node per mirror state
## and at most its surfaces in draw calls per chunk (two for a card tree) instead of that per variant. The trees of
## neighbouring chunks differ; inside a chunk the random yaw per tree hides the repetition.
static func chunk_variant(chunk_index: int, set_id: String, variants: Array) -> String:
	if variants.is_empty():
		return ""
	var k := int(hash01(chunk_index, set_id.hash() & 0xffff, 3) * float(variants.size())) % variants.size()
	return str(variants[k])


## Ground cover for a plant the sight corridor of a bend drops (amendment A-3, lead decision): pieces of the sets of
## graphics.modern.props.bend_cover (props/cover_bush, props/cover_grass: at most 0.5 m – they cannot hide a vehicle
## from the 3.4 m eye) – one for a bush, COVER_PER_TREE scattered over the crown's footprint for a tree. Pieces that
## would lie on the shoulder are left out; the ribbon test of drop_reason() applies to each. Plain items for _place().
## Not inside the City Limits: the ground there is paved (grass tufts on the pavement of a city centre, seen at C1).
static func cover_pieces(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		cover: Array, sets: Dictionary) -> Array:
	var usable: Array = []
	for c: Variant in cover:
		var ce: Dictionary = sets.get(str(c), {})
		if not ce.is_empty() and int(ce["kind"]) == PropLibrary.MODEL:
			usable.append(str(c))
	if usable.is_empty() or side == 0:
		return []
	var n := COVER_PER_TREE if str(e["cls"]) == "tree" else 1
	var spread := clampf(float(e["width"]) * float(it.get("scale", 1.0)) * 0.35, 0.0, COVER_SPREAD_M)
	var out: Array = []
	for k in n:
		var dz := (hash01(seg_index, item * 8 + k, 13) - 0.5) * 2.0 * spread if n > 1 else 0.0
		var dx := (hash01(seg_index, item * 8 + k, 17) - 0.5) * 2.0 * spread if n > 1 else 0.0
		var px := x + dx
		var pz := clampf(z + dz, float(ctx.seg_a) * ctx.seg_len, float(ctx.seg_b) * ctx.seg_len - 0.01)
		var row := clampi(int(floor(ctx.row_of(pz))), 0, ctx.row_count() - 1)
		if absf(px) - ctx.shoulder_edge(row, side) < COVER_MIN_BEYOND_M:
			continue
		var set_id := str(usable[int(hash01(seg_index, item * 8 + k, 19) * float(usable.size())) % usable.size()])
		out.append({"kind": "prop", "set": set_id, "side": side, "x": px, "z": pz,
			"scale": lerpf(0.8, 1.15, hash01(seg_index, item * 8 + k, 23)), "j": COVER_ITEM_BASE + item * 8 + k})
	return out


## Set id an item of TrackSegment.sprites is drawn with here ("" = not a prop of this builder).
static func item_set(it: Dictionary, inp: Dictionary) -> String:
	var kind := str(it.get("kind", "prop"))
	if kind == "prop":
		if bool(it.get("landmark", false)) and bool(inp.get("skip_landmarks", false)):
			return ""
		if it.has("bridge") and bool(inp.get("skip_bridge", false)):
			return ""
		return str(it.get("set", ""))
	if kind == "object" and not bool(inp.get("skip_objects", false)):
		return str(OBJECT_SETS.get(str(it.get("obj", "")), ""))
	return ""


## Why a prop is left out ("" = it is drawn): see the header. e = its PropLibrary entry, (z, x) its foot.
static func drop_reason(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		density: float, cover: Array) -> String:
	if side == 0:
		return ""
	var decorative := not it.has("offset")           # placed by a scenery rule, not by an event of the stage
	var row := clampi(int(floor(ctx.row_of(z))), 0, ctx.row_count() - 1)
	var beyond := absf(x) - ctx.shoulder_edge(row, side)
	if beyond > ctx.ribbon_width(z, side) - RIBBON_MARGIN_M:
		return "ribbon"
	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_bend_corridor(z, x) \
			and not cover.has(str(e["set"])):
		return "corridor"
	if density < 1.0 and decorative and thinnable(e) and hash01(seg_index, item, 7) >= density:
		return "density"
	return ""


## True for the small decoration "Details" may thin out: trees, bushes, rocks and other low things (bales). Never
## buildings, landmarks or tall structures (wind turbines, pylons, windmills) – they make the landscape.
static func thinnable(e: Dictionary) -> bool:
	var cls := str(e["cls"])
	return cls == "tree" or cls == "plant" or cls == "rock" or (cls == "other" and float(e["height"]) <= 6.0)


## Anchor x of an edge-aligned prop whose near edge shall be at x – Arcade's RoadRenderer.edge_anchor_x (pinned by
## tests/unit/race3d/test_props.gd).
static func edge_anchor_x(x: float, side: int, flipped: bool, extent_l: float, extent_r: float, scale: float) -> float:
	return x + float(side) * (extent_l if (side > 0 or flipped) else extent_r) * scale


## The mirror image of a transform in the plane x = 0 as a proper transform: what an instance needs inside a
## MultiMesh node that is itself mirrored in x (D24), so that node x instance = the transform with the model mirrored.
static func mirror_x(t: Transform3D) -> Transform3D:
	var b := t.basis
	return Transform3D(Basis(Vector3(b.x.x, -b.x.y, -b.x.z), Vector3(-b.y.x, b.y.y, b.y.z), Vector3(-b.z.x, b.z.y, b.z.z)),
		Vector3(-t.origin.x, t.origin.y, t.origin.z))


## Stable pseudo-random number 0..1 for (segment index, item index, salt).
static func hash01(seg_index: int, item: int, salt: int) -> float:
	var h := (seg_index * 73856093) ^ ((item + 1) * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0


## Appends a transform in the layout of MultiMesh.buffer (three rows of basis and origin).
static func _put(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	var o := t.origin
	buf.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]))


func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var groups: Dictionary = part.get("groups", {})
	if groups.is_empty():
		return
	var lib := _lib()
	var holder := Node3D.new()
	holder.name = "Props"
	var instances := 0
	for key: String in groups:
		var g: Dictionary = groups[key]
		var n := int(g["n"])
		var buf: PackedFloat32Array = g["buf"]
		instances += n
		if str(g["model"]) != "":
			var model_id := str(g["model"])
			var md: Dictionary = lib.models.get(model_id, {})
			var reps: Array = md.get("reps", [])
			var e: Dictionary = lib.sets.get(str(g["set"]), {})
			var cast_ok := _casters >= int(e.get("cast", 3))
			var has_caster := bool(md.get("caster", false))
			var rep_levels := {}          # representation -> bit mask of the chunk LOD levels that show it
			for level in reps.size():
				rep_levels[str(reps[level])] = int(rep_levels.get(str(reps[level]), 0)) | (1 << level)
			for rep: String in rep_levels:
				for p: Variant in lib.mesh_parts(model_id, rep):
					var mp: Dictionary = p
					if bool(mp["shadow"]):
						continue
					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					if bool(g.get("landmark", false)):
						_landmark_override(node, mp)
					elif bool(g.get("dark", false)):
						_dark_model_override(node, mp)
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_ok and not has_caster and not bool(mp["billboard"]) \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.set_meta(&"levels", int(rep_levels[rep]))
					node.set_meta(&"rep", rep)
					holder.add_child(node)
			if has_caster and cast_ok and not reps.is_empty():
				for p: Variant in lib.mesh_parts(model_id, str(reps[mini(1, reps.size() - 1)])):
					var mp: Dictionary = p
					if not bool(mp["shadow"]):
						continue
					var node := _mmi(mp, buf, n, false, bool(g["mirror"]))
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					node.set_meta(&"caster", true)
					holder.add_child(node)
		else:
			var s := lib.standin(str(g["set"]))
			if s.is_empty():
				continue
			if bool(g.get("landmark", false)):
				s = {"mesh": s["mesh"], "material": landmark_material(str(g["set"]))}
			elif bool(g.get("dark", false)):
				s = {"mesh": s["mesh"], "material": dark_material(str(g["set"]))}
			var node := _mmi(s, buf, n, true, bool(g["mirror"]))
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.set_meta(&"levels", 7)
			holder.add_child(node)
	var blob_n := int(part.get("blob_n", 0))
	if blob_n > 0:
		var c := lib.contact()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = c["mesh"]
		mm.instance_count = blob_n
		mm.buffer = part["blobs"]
		var node := MultiMeshInstance3D.new()
		node.name = "Contact"
		node.multimesh = mm
		node.material_override = c["material"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta(&"levels", 7)
		holder.add_child(node)
		if _casters >= 2 and _shadow_m > 0.0:
			(c["material"] as ShaderMaterial).set_shader_parameter("real_from_m", _shadow_m * 0.6)
			(c["material"] as ShaderMaterial).set_shader_parameter("real_to_m", _shadow_m)
	holder.set_meta(&"z0", float(part.get("z0", 0.0)))
	holder.set_meta(&"z1", float(part.get("z1", 0.0)))
	holder.set_meta(&"counts", part.get("counts", {}))
	holder.set_meta(&"instances", instances)
	holder.set_meta(&"lod", -1)
	parent.add_child(holder)
	_holders.append(holder)
	var cam_z := float(part.get("z0", 0.0))
	var renderer: Variant = ctx.services.get("renderer")
	if renderer != null:
		var view: Variant = (renderer as Object).get("view")
		if view is Dictionary and (view as Dictionary).has("camera_z"):
			cam_z = float((view as Dictionary)["camera_z"])
		var lamps: Array = part.get("lamps", [])
		if not lamps.is_empty() and (renderer as Object).has_method(&"add_lamps"):
			(renderer as Object).call(&"add_lamps", holder, lamps)
	_apply_lod(holder, cam_z)


## A MultiMeshInstance3D for one mesh: with_color = the buffer carries an instance colour (stand-ins).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, with_color: bool, mirrored: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = with_color
	mm.mesh = part["mesh"]
	mm.instance_count = n
	var own: Transform3D = part.get("transform", Transform3D.IDENTITY)
	if own == Transform3D.IDENTITY:
		mm.buffer = buf
	else:
		# a part with a pose of its own inside the model (none of the prop models has one today)
		var stride := 16 if with_color else 12
		for i in n:
			var o := i * stride
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			mm.set_instance_transform(i, t * own)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if part.get("material") != null:
		node.material_override = part["material"]
	if mirrored:
		node.basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	return node


## Shows the representation of every model group that belongs to the chunk's distance from the camera (path
## distance of its nearest row) and switches the shadow casters off beyond the reach of the shadow map.
func _apply_lod(holder: Node, cam_z: float) -> void:
	var d := maxf(0.0, maxf(float(holder.get_meta(&"z0", 0.0)) - cam_z, cam_z - float(holder.get_meta(&"z1", 0.0))))
	var old := int(holder.get_meta(&"lod", -1))
	var level := lod_level(d, old, _lod0_m, _lod1_m)
	var cast := _casters >= 2 and d < _shadow_m + SHADOW_KEEP_M
	if level == old and cast == bool(holder.get_meta(&"cast", false)):
		return
	holder.set_meta(&"lod", level)
	holder.set_meta(&"cast", cast)
	for c: Node in holder.get_children():
		var n3 := c as Node3D
		if n3 == null:
			continue
		if c.has_meta(&"caster"):
			n3.visible = cast
		else:
			n3.visible = (int(c.get_meta(&"levels", 7)) & (1 << level)) != 0


## Chunk LOD level 0 / 1 / 2 for a path distance, with a little hysteresis against the level it has (old; -1 = none).
static func lod_level(dist: float, old: int, lod0_m: float, lod1_m: float) -> int:
	var a := lod0_m + (LOD_HYSTERESIS_M if old == 0 else 0.0)
	var b := lod1_m + (LOD_HYSTERESIS_M if old >= 0 and old <= 1 else 0.0)
	if dist < a:
		return 0
	if dist < b:
		return 1
	return 2


func debug(part: Dictionary) -> Dictionary:
	var groups: Dictionary = part.get("groups", {})
	var per_group := {}
	for key: String in groups:
		per_group[key] = int((groups[key] as Dictionary)["n"])
	return {"props": (part.get("list", []) as Array).size(), "groups": per_group, "counts": part.get("counts", {}),
		"dropped": part.get("dropped", {}), "lamps": (part.get("lamps", []) as Array).size(), "contact": int(part.get("blob_n", 0)),
		"list": part.get("list", []), "cover": (part.get("cover_list", []) as Array).size()}
