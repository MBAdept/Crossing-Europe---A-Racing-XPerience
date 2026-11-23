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
##               vegetation – the WHOLE object (A-24: the AABB of its model, turned as placed, footprint()); one
##               whose foot stands outside but whose model reaches in is first pushed away from the road, at most
##               PUSH_MAX_M (push_out()); attached props likewise. A dropped plant is replaced by ground cover (amendment A-3): pieces of the sets of
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
## R7c (A-16, A-22, lead decisions of R7c): the level of detail of a model is chosen PER INSTANCE by its distance from
## the camera, with a dither cross-fade, in the shaders (inc/lod_band.gdshaderinc): every level draws through
## materials of its own (one per mesh, ModernMaterials) that carry its distance band (lod_band()); the chunk only
## switches off the MultiMesh nodes none of whose instances lies inside their band (update(): straight-line distances
## of the instance origins, like the shaders). The distances: Details' prop_lod0_m / prop_lod1_m scaled by the model's
## own max_dist_m (model.json; graphics.modern.props.lod0_m overrides it per model until the asset owner writes it)
## against lod_ref_m / lod1_ref_m. Beyond the reach of the real-time shadows a model that casts takes its mean
## shadowed share of the sun (far_sun, graphics.modern.props.far_sun). Per instance the MultiMesh custom data carry the
## tint AND a phase (a = 1 + phase): the rotors of turbines and windmills and the sway of trees no longer jump at a
## rebase of the floating origin. Placement tags of the models (A-16): ground_align, ground_sink, face_road. A model may
## place separate props with itself ("attach" in model.json, PropLibrary.attachments()).
## Owner: package terrain / props / far ground; R7c in wave 5.

const OBJECT_SETS := {"streetlight": "props/streetlight"}   ## Track "object" items drawn here while builders/city.gd is missing
const RIBBON_MARGIN_M := 1.0       ## a prop needs this much ribbon beyond its foot
## A-24 (FIX-R7a's patch, RINT-M3): a prop whose foot stands outside the sight lines of a bend but whose model reaches
## into them moves away from the road by that depth + PUSH_MARGIN_M – at most PUSH_MAX_M (FIX-R7a measured: 6 m lost
## 180 city houses of the base, 12 m 8) – and is left out only when that is not enough (push_out(), footprint())
const PUSH_MARGIN_M := 0.3
const PUSH_MAX_M := 12.0
const SLOPE_PROBE_M := 1.5         ## the ground plane under a prop is taken from points this far apart
const BLOB_LIFT_M := 0.03
const SHADOW_KEEP_M := 40.0        ## shadow casters stay on this far beyond the reach of the shadow map
## RINT-M2 (A-19): every MultiMesh of this builder carries an instance colour AND custom data – 20 floats per
## instance: transform, colour, custom. A stand-in: colour = its tint, custom = NO_CUSTOM; a model: colour = white
## (MODEL_COLOR – Godot multiplies it into the vertex colour, which the models use as data), custom = its tint (r, g, b, 1).
## Godot's Compatibility renderer (4.7.2, measured with probes on llvmpipe) reads INSTANCE_CUSTOM wrongly in the two
## other layouts: with colours but no custom data as (0, 1, 0, 1), and with custom data but no colours, set through
## MultiMesh.buffer, as garbage on the real prop meshes (bright green windows, trees and turbines) – fine only through
## set_instance_custom_data(), which is too slow per instance. A MultiMesh with neither reads (0, 0, 0, 0) and a
## MeshInstance3D 0: a < 0.5, the shaders leave the albedo as it is.
const NO_CUSTOM := [0.0, 0.0, 0.0, 0.0]
const MODEL_COLOR := [1.0, 1.0, 1.0, 1.0]
const INSTANCE_FLOATS := 20
const LOD_HYSTERESIS_M := 6.0      ## a chunk leaves a level this much later than it enters it
## update() looks at the chunk levels again after this much driving; a level node is switched on this much before its
## band begins and off this much after it ends (FIX-R7c, QR7c-05: between two looks an instance may enter a band while
## the node of its finer level is still off – the coarser one fading out would leave dither holes)
const LOD_STEP_M := 2.0
## FIX-R7c (QR7c-06): below this camera speed (m/s) the camera "stands": ce_lod_still goes to 1 over LOD_STILL_S seconds
## (the vehicles' xfade is 0.3–0.5 s, A-16) and every band narrows to a hard swap at its middle – no dithered tree or
## house in the countdown, a traffic jam or a police stop; driving off widens the bands again over the same time
const LOD_STILL_SPEED := 1.5
const LOD_STILL_S := 0.4
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
## 60.1, ZS1 (dark stand-in) 58.4, the model with its night atlas 84.4, without it 79.5, with 0.55 60.2, with 0.5
## 58.0 – but 2 levels above Arcade at km 79.7, where the street lamps light the cables beside the deck; 0.45 keeps the
## pylon at or below Arcade along the whole bridge (docs/renderer-modern.md 14.7).
const PYLON_NIGHT_ALBEDO := 0.45
## R7c: the level distances. A model's own max_dist_m of level 0 (1) is read against these reference values – the
## exporter's defaults, which are the distances of "Details: Mittel" – so the model keeps its share at every Details level.
const LOD_REF_M := 60.0
const LOD1_REF_M := 200.0
## Half width of the cross-fade band around a level distance D: clamp(D x frac, min, max) metres – 0.4 s at 100 km/h
## around 60 m (the vehicles' xfade is 0.3–0.5 s, A-16), wider far away where a metre moves less on the screen.
const LOD_FADE := Vector3(0.12, 4.0, 25.0)
const LOD_ENDLESS := 1.0e9
## ground_align: at most this tilt (degrees) towards the ground normal; face_road: at most this turn away from the road
const ALIGN_MAX_DEG := 30.0
const FACE_ROAD_DEG := 20.0
const ATTACH_ITEM_BASE := 200000   ## item numbers of attached props (hashes, lists): beyond every real and cover item
const ATTACH_MAX := 8              ## attachments per model at most (item numbers ATTACH_ITEM_BASE + item × 8 + k)
## R7c: what the materials of the prop models get on top of their bands ([uniform, value]; baked.gdshader – its defaults
## keep the earlier picture, so the panels of stations, borders and gantries keep their sharp lettering, check_structures
## "zieltor"):
##   cutout_bias 2        the alpha test of baked_cutout two mip levels coarser (railings, leaf cards flicker less,
##                        lead decision 3; the bake keeps the coverage of every level, A-22)
##   window_ramp 0.6      the night atlas at its full light from ce_night 0.6 (Arcade's light layer: lights 0.65 at 19:30)
##   window_cover 1       a lit window replaces the facade's lit colour (lead decision 4)
## and albedo_bias / albedo_bias_m per model (albedo_bias_of(): graphics.modern.props.albedo_bias) – the colour up to that
## many levels coarser, growing between the two distances. FIX-R7c (QR7c-04): R7c put 1.25 from 30 to 120 m on every
## model, which turned the white window frames of far facades grey (Nürnberg, ~100 m: 1.09 levels there). Measured
## (sparkcam, lod1, "Mittel"): without the bias the Barockhaus flickers 2.5 x its sprite at 150 m and the Grachtenhaus B
## 2.25 x – so the bias stays, but from 60 to 150 m (0.52 levels at 100 m); the half-timbered rows keep 30 to 120 m.
const PROP_LOOK: Array = [["cutout_bias", 2.0], ["window_ramp", 0.6], ["window_cover", 1.0]]

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
const BRIDGE_WATER_LIFT := 0.15     ## builders/bridge.gd WATER_LIFT (A-7: no class of a builder of the same wave named)
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
## R7c: level distances and far light
var _lod_ref := Vector2(LOD_REF_M, LOD1_REF_M)
var _lod_fade := LOD_FADE
var _lod0_override: Dictionary = {} ## model id -> lod0 distance (m at "Mittel"), graphics.modern.props.lod0_m
var _far_sun: Dictionary = {}       ## class ("building", "tree", …) or model id -> mean shadowed share of the sun
var _albedo_bias: Dictionary = {}   ## "default" or model id -> [mip bias of the colour far away, from m, to m] (QR7c-04)
var _banded: Dictionary = {}        ## model id -> true: its materials carry the bands of the current levels
var _bands: Dictionary = {}         ## model id -> {rep: Vector4}
var _models_seen: Dictionary = {}   ## model id -> a set it was drawn for (quality_lowered)
## FIX-R7c (QR7c-06): ce_lod_still – 1 while the camera stands (the start of a stage is a standing camera)
var _still := 1.0
var _still_z := -1.0e12             ## camera position of the last frame (-1e12: none yet)
var _still_t := -1.0e12             ## view time of the last frame (-1e12: none yet)
var _still_sent := -1.0             ## value of ce_lod_still last set (-1: never)


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
		var pd: Dictionary = p
		var list: Variant = pd.get("bend_cover", [])
		_cover_sets = list if list is Array else []
		_cover_max_h = maxf(0.05, float(pd.get("bend_cover_max_h_m", 0.5)))
		# R7c: level distances, cross-fade band, far light
		_lod_ref = Vector2(maxf(1.0, float(pd.get("lod_ref_m", LOD_REF_M))), maxf(1.0, float(pd.get("lod1_ref_m", LOD1_REF_M))))
		var fade: Variant = pd.get("lod_fade", {})
		if fade is Dictionary:
			_lod_fade = Vector3(float((fade as Dictionary).get("frac", LOD_FADE.x)), float((fade as Dictionary).get("min_m", LOD_FADE.y)),
				float((fade as Dictionary).get("max_m", LOD_FADE.z)))
		var ov: Variant = pd.get("lod0_m", {})
		_lod0_override = (ov as Dictionary).duplicate() if ov is Dictionary else {}
		_lod0_override.erase("_doc")
		var fs: Variant = pd.get("far_sun", {})
		_far_sun = (fs as Dictionary).duplicate() if fs is Dictionary else {}
		_far_sun.erase("_doc")
		var ab: Variant = pd.get("albedo_bias", {})
		_albedo_bias = (ab as Dictionary).duplicate() if ab is Dictionary else {}
		_albedo_bias.erase("_doc")
	_banded.clear()


func apply_quality(levels: Dictionary) -> void:
	_lod0_m = float(levels.get("prop_lod0_m", _lod0_m))
	_lod1_m = maxf(_lod0_m, float(levels.get("prop_lod1_m", _lod1_m)))
	_density = float(levels.get("deco_density", _density))
	_casters = int(levels.get("shadow_casters", _casters))
	_shadow_m = float(levels.get("shadow_distance_m", _shadow_m))
	_banded.clear()
	_bands.clear()


## The slowness watchdog stepped the preset down during the countdown (modern_renderer.gd): new level distances and
## shadow reach for the models already drawn – their materials get the new bands at once, the chunks follow in update().
func quality_lowered(levels: Dictionary) -> void:
	apply_quality(levels)
	for mid: Variant in _models_seen.keys():
		_ensure_bands(str(mid), str(_models_seen[mid]))
	# the level nodes already committed switch by the new bands too (their meta "band" decides in _apply_lod())
	for h: Variant in _holders:
		if not is_instance_valid(h):
			continue
		for c: Node in (h as Node).get_children():
			if c.has_meta(&"band") and c.has_meta(&"model"):
				var bands := model_bands(str(c.get_meta(&"model")))
				c.set_meta(&"band", bands.get(str(c.get_meta(&"rep")), c.get_meta(&"band")))
		_thresholds(h)          # new bands and shadow reach: new thresholds (and no stale key)
	_lod_z = -1.0e12


## R7c: the distance band of every representation of a model, for the shaders (lod_band, inc/lod_band.gdshaderinc):
## {rep: Vector4(in0, in1, out0, out1)}. reps = the representations at chunk levels 0, 1, 2 (PropLibrary: lod0, lod1,
## impostor or the coarsest level); lod_m = the model's own ends of level 0 and 1 (0 = no such level); lod0_m, lod1_m =
## the Details distances; ref = the reference distances they are read against; override0 > 0 replaces lod_m.x; fade =
## LOD_FADE. A representation that serves several levels gets their union; a model of one level is always shown.
static func lod_bands(reps: Array, lod_m: Vector2, lod0_m: float, lod1_m: float, ref: Vector2, override0: float, fade: Vector3) -> Dictionary:
	var out := {}
	if reps.is_empty():
		return out
	var always := Vector4(-2.0, -1.0, LOD_ENDLESS, 2.0 * LOD_ENDLESS)
	var own0 := override0 if override0 > 0.0 else lod_m.x
	if own0 <= 0.0 or (str(reps[0]) == str(reps[mini(1, reps.size() - 1)]) and str(reps[0]) == str(reps[reps.size() - 1])):
		for r: Variant in reps:
			out[str(r)] = always
		return out
	var d0 := lod0_m * own0 / maxf(1.0, ref.x)
	var w0 := clampf(d0 * fade.x, fade.y, fade.z)
	var d1 := LOD_ENDLESS
	var w1 := 0.0
	if lod_m.y > 0.0:
		d1 = lod1_m * lod_m.y / maxf(1.0, ref.y)
		w1 = clampf(d1 * fade.x, fade.y, fade.z)
		d1 = maxf(d1, d0 + w0 + w1 + 2.0)
	var lv: Array[Vector4] = [Vector4(-2.0, -1.0, d0 - w0, d0 + w0),
		Vector4(d0 - w0, d0 + w0, d1 - w1 if d1 < LOD_ENDLESS else LOD_ENDLESS, d1 + w1 if d1 < LOD_ENDLESS else 2.0 * LOD_ENDLESS),
		Vector4(d1 - w1, d1 + w1, LOD_ENDLESS, 2.0 * LOD_ENDLESS) if d1 < LOD_ENDLESS else Vector4(LOD_ENDLESS, 2.0 * LOD_ENDLESS, LOD_ENDLESS, 2.0 * LOD_ENDLESS)]
	for level in mini(3, reps.size()):
		var r := str(reps[level])
		var b: Vector4 = lv[level]
		if out.has(r):
			var a: Vector4 = out[r]
			b = Vector4(minf(a.x, b.x), minf(a.y, b.y), maxf(a.z, b.z), maxf(a.w, b.w))
		out[r] = b
	return out


## The bands of a model at the current levels (cached until the levels change).
func model_bands(model_id: String) -> Dictionary:
	var b: Variant = _bands.get(model_id)
	if b != null:
		return b
	var md: Dictionary = _lib().models.get(model_id, {})
	var lod_m: Vector2 = md.get("lod_m", Vector2.ZERO)
	var out := lod_bands(md.get("reps", []), lod_m, _lod0_m, _lod1_m, _lod_ref, lod0_override(model_id), _lod_fade)
	_bands[model_id] = out
	return out


## The lod0 distance (m at "Mittel") graphics.modern.props.lod0_m gives a model: its own entry, else that of the first of
## its tags that has one ("city": the city houses); 0 = the model's own max_dist_m.
func lod0_override(model_id: String) -> float:
	if _lod0_override.has(model_id):
		return float(_lod0_override[model_id])
	for t: Variant in ModelDB.model(model_id).get("tags", []):
		if _lod0_override.has("tag:" + str(t)):
			return float(_lod0_override["tag:" + str(t)])
	return 0.0


## Mean shadowed share of the sun beyond the shadow reach for a model of class cls (1 = no change): the model's own
## entry of graphics.modern.props.far_sun, else that of its class.
func far_sun_of(model_id: String, cls: String) -> float:
	return clampf(float(_far_sun.get(model_id, _far_sun.get(cls, 1.0))), 0.0, 1.0)


## FIX-R7c (QR7c-04): the far mip bias of a model's colour (baked.gdshader albedo_bias, albedo_bias_m) as
## Vector3(levels, from m, to m): its own entry of graphics.modern.props.albedo_bias, else "default"; an entry is
## [levels, from, to] or a plain number (from 30 to 120 m). (0, …) = the atlas as sharp as near the camera.
func albedo_bias_of(model_id: String) -> Vector3:
	var v: Variant = _albedo_bias.get(model_id, _albedo_bias.get("default", 0.0))
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Vector3(maxf(0.0, float(a[0])), float(a[1]), maxf(float(a[1]) + 1.0, float(a[2])))
	return Vector3(maxf(0.0, float(v)), 30.0, 120.0)


## Puts the bands and the far light of a model on the materials of its representations (main thread). set_id: a set
## the model is drawn for (its class and whether it casts at the current shadow level).
func _ensure_bands(model_id: String, set_id: String) -> void:
	if _banded.has(model_id):
		return
	_banded[model_id] = true
	_models_seen[model_id] = set_id
	var lib := _lib()
	var e: Dictionary = lib.sets.get(set_id, {})
	var casts := not e.is_empty() and _casters >= int(e.get("cast", 3)) and _casters >= 2
	var fs := far_sun_of(model_id, str(e.get("cls", "other"))) if casts else 1.0
	var reach := _shadow_m if _shadow_m > 0.0 else 0.0
	var far := Vector2(reach * 0.85, reach) if casts and fs < 0.999 and reach > 0.0 else Vector2.ZERO
	var bands := model_bands(model_id)
	for rep: String in bands:
		for m: ShaderMaterial in lib.rep_materials(model_id, rep):
			m.set_shader_parameter("lod_band", bands[rep])
			m.set_shader_parameter("shadow_far", far)
			m.set_shader_parameter("far_sun", fs)
			for l: Array in PROP_LOOK:
				m.set_shader_parameter(str(l[0]), l[1])
			var ab := albedo_bias_of(model_id)
			m.set_shader_parameter("albedo_bias", ab.x)
			m.set_shader_parameter("albedo_bias_m", Vector2(ab.y, ab.z))


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


func update(view: Dictionary, dt: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	_update_still(cam_z, dt, float(view["time"]) if view.has("time") else NAN)
	if absf(cam_z - _far_z) >= LOD_STEP_M or _far_z < -1.0e11:
		_far_z = cam_z
		_update_far_landmarks(view, cam_z)
	if absf(cam_z - _lod_z) < LOD_STEP_M:
		return      # the levels are a matter of tens of metres: looked at every few metres of driving
	_lod_z = cam_z
	var eye: Variant = _eye()
	var i := _holders.size() - 1
	while i >= 0:
		var h: Variant = _holders[i]
		if not is_instance_valid(h):
			_holders.remove_at(i)
		else:
			_apply_lod(h, cam_z, eye)
		i -= 1


## FIX-R7c (QR7c-06): ce_lod_still from the camera's motion along the road. The clock is the view's own "time" (Rule 10)
## where the view has one – the same view drawn twice (render checks, a paused game) changes nothing, the picture stays
## the same –, else dt (dt = 0 while the stage is prepared: no change). Sets the global only when its value changes.
func _update_still(cam_z: float, dt: float, view_time: float = NAN) -> void:
	var step := dt
	if not is_nan(view_time):
		step = view_time - _still_t if _still_t > -1.0e11 else 0.0
		if step > 0.0 or _still_t < -1.0e11:
			_still_t = view_time
		step = maxf(0.0, step)
	var speed := 0.0
	if step > 0.0 and _still_z > -1.0e11:
		speed = absf(cam_z - _still_z) / step
	if step > 0.0 or _still_z < -1.0e11:
		_still_z = cam_z
	_still = still_step(_still, speed, step)
	if _still != _still_sent:
		_still_sent = _still
		ModernMaterials.set_global("ce_lod_still", _still)


## The next value of ce_lod_still: towards 1 while the camera moves slower than LOD_STILL_SPEED (m/s), towards 0
## otherwise, LOD_STILL_S seconds for the whole way.
static func still_step(still: float, speed: float, dt: float) -> float:
	if dt <= 0.0:
		return still
	return move_toward(still, 1.0 if speed < LOD_STILL_SPEED else 0.0, dt / LOD_STILL_S)


## The current ce_lod_still of this builder (tests, debug).
func lod_still() -> float:
	return _still


## Position of the main camera (origin-relative world), or null without a renderer camera in the tree (tests).
func _eye() -> Variant:
	if _renderer == null:
		return null
	var cam: Variant = _renderer.get("camera")
	if cam is Camera3D and (cam as Camera3D).is_inside_tree():
		return (cam as Camera3D).global_position
	return null


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
					one.append_array(PackedFloat32Array(NO_CUSTOM))
					var mm := _mmi(pd, one, 1, false)
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
	one_c.append_array(PackedFloat32Array(MODEL_COLOR))
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
						var node := _mmi(part, one_c, 1, false)
						node.scale = Vector3.ONE * k
						node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if bool(part["shadow"]) \
							else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
						out.append(node)
		elif int(e["kind"]) == PropLibrary.SPRITE and not standin:
			var s := lib.standin(set_id)
			if not s.is_empty():
				standin = true
				out.append(_mmi(s, one_c, 1, false))
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
		"dropped": {"ribbon": 0, "corridor": 0, "missing": 0, "density": 0}, "attach_list": [],
		"box_min": Vector3(INF, INF, INF), "box_max": Vector3(-INF, -INF, -INF), "iz": Vector3(INF, -INF, 0.0)}
	var rows := ctx.row_count()
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		var sprites: Array = seg["sprites"]
		for j in sprites.size():
			_place(ctx, inp, out, i, seg, j, sprites[j], false)
	var bmin: Vector3 = out["box_min"]
	var bmax: Vector3 = out["box_max"]
	var iz: Vector3 = out["iz"]
	return {"groups": out["groups"], "blobs": out["blobs"], "blob_n": out["blob_n"], "lamps": out["lamps"], "list": out["list"],
		"cover_list": out["cover_list"], "attach_list": out["attach_list"], "counts": out["counts"], "dropped": out["dropped"],
		"z0": float(ctx.seg_a) * ctx.seg_len, "z1": float(ctx.seg_b) * ctx.seg_len,
		"box": AABB(bmin, bmax - bmin) if bmin.x <= bmax.x else AABB(), "iz0": iz.x if iz.x <= iz.y else float(ctx.seg_a) * ctx.seg_len,
		"iz1": iz.y if iz.x <= iz.y else float(ctx.seg_b) * ctx.seg_len, "lat": iz.z}


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
	# A-24: the whole object against the sight lines of a bend – the model's AABB turned as it will stand
	var yaw := place_yaw(e, seg_index, j) if is_model else 0.0
	var fp := footprint(e, sc, side, flipped, it.has("align"), yaw)
	if not is_cover:
		x = push_out(ctx, it, e, z, x, side, fp, cover)
	var reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover, fp)
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
		# given relative to the road (ships on the water); RINT-M2 (QR5-08): with the bridge builder the water lies
		# WATER_LIFT (0.15 m) above the terrain's water rows – the boats float on it, not 15 cm below
		h = float(it["h"]) + (BRIDGE_WATER_LIFT if bool(inp.get("skip_bridge", false)) else 0.0)
	elif not it.has("bridge"):
		h = ctx.ground(z, x)
		if bool(e.get("ground_sink", false)):
			# R7c (A-16): rocks and cliffs stand on the lowest ground point of their footprint (no edge in the air)
			h = sink_height(ctx, z, x, 0.5 * maxf(float(e["width"]), float(e.get("length", e["width"]))) * sc, h)
	h += float(it.get("lift", 0.0))
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
		tr = ctx.frame(z, x, h, yaw).scaled_local(Vector3(sc, sc, sc))
		if bool(e.get("ground_align", false)) and not it.has("h") and not it.has("bridge"):
			tr.basis = align_basis(ctx, z, x, h, tr.basis)          # R7c (A-16): tilted to the ground normal
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
	# the placement tint (tint × fallback_tint, white without one): a stand-in carries it as its instance colour, a model
	# as its instance custom data (r, g, b, 1) – RINT-M2 (A-19): baked, vpbr_static, leaves and billboard multiply the
	# albedo by it as Arcade multiplies the sprite; never an instance uniform (the global shader buffer, A-19). Layout:
	# INSTANCE_FLOATS (see NO_CUSTOM)
	if is_model:
		buf.append_array(PackedFloat32Array(MODEL_COLOR))
		# R7c: a = 1 + phase (0 .. 0.999): the shaders read the tint for a > 0.5 as before and the phase of rotors and
		# sway from fract(a) – the custom data are half floats in the Compatibility renderer (1/1024 steps of the phase)
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0 + instance_phase(seg_index, j)]))
	else:
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
		buf.append_array(PackedFloat32Array(NO_CUSTOM))
	g["buf"] = buf
	g["n"] = int(g["n"]) + 1
	# R7c: the box of the instance origins (chunk-local) and their path range – update() decides from it which level
	# nodes have an instance inside their band
	var bmin: Vector3 = out["box_min"]
	var bmax: Vector3 = out["box_max"]
	out["box_min"] = bmin.min(tr.origin)
	out["box_max"] = bmax.max(tr.origin)
	var iz: Vector3 = out["iz"]
	out["iz"] = Vector3(minf(iz.x, z), maxf(iz.y, z), maxf(iz.z, absf(x)))
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
	var attached := bool(it.get("attached", false))
	counts[str(e["set"]) if is_cover else set_id] = int(counts.get(str(e["set"]) if is_cover else set_id, 0)) + 1
	# [seg, item, set, x, z, scale, mirrored, kind, yaw (rad, as placed – A-24: tests/race3d/check_props_footprint.gd)]
	(out["cover_list"] if is_cover else (out["attach_list"] if attached else out["list"])).append([seg_index, j, str(e["set"]),
		snappedf(x, 0.001), snappedf(z, 0.001), snappedf(sc, 0.0001), 1 if flipped else 0, int(e["kind"]), snappedf(yaw, 0.0001)])
	# R7c (lead decision 6): the props the model places with itself – ordinary items of their own sets (own level of
	# detail, own drops: an attached tree inside a bend corridor is left out like any tree)
	if is_model and not attached and not is_cover:
		var md: Dictionary = models.get(model_id, {})
		var k := 0
		var z_lo := float(ctx.seg_a) * ctx.seg_len
		var z_hi := float(ctx.seg_b) * ctx.seg_len
		for a: Dictionary in md.get("attach", []):
			if k >= ATTACH_MAX:
				break           # FIX-R7c (QR7c-08): item numbers item × ATTACH_MAX + k stay apart
			var ai := attach_item(it, a, z, x, sc, side, flipped, seg_index, j, k)
			k += 1
			# FIX-R7c (QR7c-08): an attachment beyond this chunk is not placed – ground() and the corridor test would
			# read the edge row there (wrong height on a slope; a corridor that begins just beyond the edge, F7), and the
			# neighbouring chunk does not see this item. Offsets of a few metres lose it only near a chunk end.
			if float(ai["z"]) < z_lo or float(ai["z"]) >= z_hi:
				continue
			_place(ctx, inp, out, i, seg, int(ai["j"]), ai, false)


## R7c (lead decision 6): the item of a prop a model places with itself ("attach" of model.json, PropLibrary.attachments()):
## offset in model space (+X right of travel, -Z along the road away from the near face – a building's depth), mirrored
## with a mirrored model, turned with the road; the prop stands on the ground at that point (+ the offset's y).
## Not for models turned by a random yaw (they have no attachments today: trees, rocks).
static func attach_item(it: Dictionary, a: Dictionary, z: float, x: float, sc: float, side: int, flipped: bool, seg_index: int, item: int,
		k: int) -> Dictionary:
	var off: Vector3 = a["offset"]
	var ox := -off.x if flipped else off.x
	var out := {"kind": "prop", "set": str(a["prop"]), "side": side if side != 0 else 1, "x": x + ox * sc, "z": z - off.z * sc,
		"scale": float(a["scale"]) * sc, "attached": true, "j": ATTACH_ITEM_BASE + item * ATTACH_MAX + k}
	if absf(off.y) > 0.001:
		out["lift"] = off.y * sc
	if it.has("tint"):
		out["tint"] = it["tint"]
	return out


## R7c (A-16): the phase of an instance (0 .. 0.999) for rotors and sway – stable per item, independent of the origin.
static func instance_phase(seg_index: int, item: int) -> float:
	return hash01(seg_index, item, 29) * 0.999


## R7c (A-16, tag ground_sink): ground height under a footprint of radius r around (z, x): the lowest of the centre and
## eight points on the circle – a rock or cliff on a slope is set down to its low side instead of floating there.
static func sink_height(ctx: ChunkContext, z: float, x: float, r: float, h0: float) -> float:
	var h := h0
	if r <= 0.05:
		return h
	for k in 8:
		var a := float(k) * TAU / 8.0
		h = minf(h, ctx.ground(z + cos(a) * r, x + sin(a) * r))
	return h


## R7c (A-16, tag ground_align): a basis tilted from its up axis towards the ground normal at (z, x) (at most
## ALIGN_MAX_DEG) – heather and ground cover lie on the slope instead of standing upright out of it.
static func align_basis(ctx: ChunkContext, z: float, x: float, h: float, basis: Basis) -> Basis:
	var p0 := ctx.local(z, x, h)
	var px := ctx.local(z, x + SLOPE_PROBE_M, ctx.ground(z, x + SLOPE_PROBE_M)) - p0
	var pz := ctx.local(z + SLOPE_PROBE_M, x, ctx.ground(z + SLOPE_PROBE_M, x)) - p0
	var n := px.cross(pz).normalized()
	if n.y < 0.0:
		n = -n
	if n.y < 0.2:
		return basis
	var up := basis.y.normalized()
	var ang := up.angle_to(n)
	if ang < 0.001:
		return basis
	var axis := up.cross(n).normalized()
	if axis.length() < 0.5:
		return basis
	return Basis(axis, minf(ang, deg_to_rad(ALIGN_MAX_DEG))) * basis


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


## Why a prop is left out ("" = it is drawn): see the header. e = its PropLibrary entry, (z, x) its foot, fp its
## footprint (footprint(): reach towards the road, middle and half length along the road; Vector3.ZERO = the foot
## only) – A-24: no part of the object in the sight lines of a bend (ChunkContext.in_sight_envelope()).
static func drop_reason(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		density: float, cover: Array, fp: Vector3 = Vector3.ZERO) -> String:
	if side == 0:
		return ""
	var decorative := not it.has("offset")           # placed by a scenery rule, not by an event of the stage
	var row := clampi(int(floor(ctx.row_of(z))), 0, ctx.row_count() - 1)
	var beyond := absf(x) - ctx.shoulder_edge(row, side)
	if beyond > ctx.ribbon_width(z, side) - RIBBON_MARGIN_M:
		return "ribbon"
	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) \
			and ctx.in_sight_envelope(z + fp.y, x, fp.x, fp.z) and not cover.has(str(e["set"])):
		return "corridor"
	if density < 1.0 and decorative and thinnable(e) and hash01(seg_index, item, 7) >= density:
		return "density"
	return ""


## A-24 (FIX-R7a's push-out, RINT-M3): a prop whose foot stands outside the envelope of the sight lines of a bend but
## whose model (fp = footprint()) reaches into it moves away from the road by that depth + PUSH_MARGIN_M – at most
## PUSH_MAX_M – and keeps its place in the picture instead of being left out; drop_reason() leaves out what still
## reaches in or then lies beyond the ribbon. Never props the builder does not drop (landmarks, items of a stage event
## that are not plants, ground cover). Returns the new x.
static func push_out(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, fp: Vector3,
		cover: Array) -> float:
	if side == 0 or bool(it.get("landmark", false)) or cover.has(str(e["set"])):
		return x
	if it.has("offset") and not bool(e["veg"]):
		return x
	if ctx.bend_intrusion(z, x) >= 0.0:
		return x       # the foot itself stands in the sight lines: left out (a plant becomes ground cover)
	var depth := ctx.bend_intrusion(z + fp.y, x, fp.x, fp.z)
	if depth < 0.0 or depth > PUSH_MAX_M:
		return x
	return x + float(side) * (depth + PUSH_MARGIN_M)


## Yaw (rad) a model of entry e stands with (item `item` of segment `seg_index`): a stable random turn for trees,
## plants and rocks, at most ±FACE_ROAD_DEG for face_road models (R7c, A-16), 0 for everything else.
static func place_yaw(e: Dictionary, seg_index: int, item: int) -> float:
	var u := hash01(seg_index, item, 5)
	if bool(e.get("face_road", false)):
		return (u - 0.5) * 2.0 * deg_to_rad(FACE_ROAD_DEG)
	if bool(e["veg"]) or str(e["cls"]) == "rock":
		return u * TAU
	return 0.0


## A-24 (RINT-M3, lead decision): the footprint of a prop for the sight lines of a bend, from the model itself – the
## AABB of the union of its variants (PropLibrary "aabb"), scaled, mirrored and turned by yaw as _place() places it
## (ChunkContext.frame(): model +X = right of travel, model -Z = forward). Returns Vector3(reach: how far it extends
## from its foot towards the road, dz: the middle of its extent along the road relative to the foot, half_len: half
## that extent). Edge-aligned items reach at least to Arcade's near edge (the extent of the set; props/city_french_sud's
## upper floors reach 2.08 m beyond it). A stand-in (no AABB): half its width as crown, the extent for aligned items,
## centred on the foot – FIX-R7a's model.
static func footprint(e: Dictionary, sc: float, side: int, flipped: bool, aligned: bool, yaw: float) -> Vector3:
	var half_w := float(e["width"]) * sc * 0.5
	var edge := 0.0
	if aligned and side != 0:
		edge = (float(e["extent_l"]) if (side > 0 or flipped) else float(e["extent_r"])) * sc
	var a: Array = e.get("aabb", [])
	if a.size() != 6:
		return Vector3(edge if aligned and side != 0 else half_w, 0.0, half_w)
	var c := cos(yaw)
	var s := sin(yaw)
	var lat := Vector2(INF, -INF)
	var fwd := Vector2(INF, -INF)
	for mx: float in [float(a[0]), float(a[3])]:
		for mz: float in [float(a[2]), float(a[5])]:
			var px := -mx if flipped else mx
			var l := (px * c - mz * s) * sc
			var f := (-px * s - mz * c) * sc
			lat = Vector2(minf(lat.x, l), maxf(lat.y, l))
			fwd = Vector2(minf(fwd.x, f), maxf(fwd.y, f))
	var reach := -lat.x if side >= 0 else lat.y      # the road lies at -x of a prop on the right, at +x on the left
	if aligned and side != 0:
		reach = maxf(reach, edge)
	return Vector3(maxf(reach, 0.0), 0.5 * (fwd.x + fwd.y), 0.5 * (fwd.y - fwd.x))


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
			_ensure_bands(model_id, str(g["set"]))
			var bands := model_bands(model_id)
			for rep: String in rep_levels:
				for p: Variant in lib.mesh_parts(model_id, rep):
					var mp: Dictionary = p
					if bool(mp["shadow"]):
						continue
					var node := _mmi(mp, buf, n, bool(g["mirror"]))
					if bool(g.get("landmark", false)):
						_landmark_override(node, mp)
					elif bool(g.get("dark", false)):
						_dark_model_override(node, mp)
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_ok and not has_caster and not bool(mp["billboard"]) \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.set_meta(&"levels", int(rep_levels[rep]))
					node.set_meta(&"rep", rep)
					node.set_meta(&"band", bands.get(rep, Vector4(-2.0, -1.0, LOD_ENDLESS, 2.0 * LOD_ENDLESS)))
					node.set_meta(&"model", model_id)
					holder.add_child(node)
			if has_caster and cast_ok and not reps.is_empty():
				for p: Variant in lib.mesh_parts(model_id, str(reps[mini(1, reps.size() - 1)])):
					var mp: Dictionary = p
					if not bool(mp["shadow"]):
						continue
					var node := _mmi(mp, buf, n, bool(g["mirror"]))
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
			var node := _mmi(s, buf, n, bool(g["mirror"]))
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
	holder.set_meta(&"box", part.get("box", AABB()))
	holder.set_meta(&"iz0", float(part.get("iz0", part.get("z0", 0.0))))
	holder.set_meta(&"iz1", float(part.get("iz1", part.get("z1", 0.0))))
	holder.set_meta(&"lat", float(part.get("lat", 0.0)))
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
	_apply_lod(holder, cam_z, _eye())


## A MultiMeshInstance3D for one mesh; buf: INSTANCE_FLOATS per instance (transform, colour, custom – see NO_CUSTOM).
static func _mmi(part: Dictionary, buf: PackedFloat32Array, n: int, mirrored: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = part["mesh"]
	mm.instance_count = n
	var own: Transform3D = part.get("transform", Transform3D.IDENTITY)
	if own == Transform3D.IDENTITY:
		mm.buffer = buf
	else:
		# a part with a pose of its own inside the model (none of the prop models has one today)
		for i in n:
			var o := i * INSTANCE_FLOATS
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			mm.set_instance_transform(i, t * own)
			mm.set_instance_color(i, Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15]))
			mm.set_instance_custom_data(i, Color(buf[o + 16], buf[o + 17], buf[o + 18], buf[o + 19]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if part.get("material") != null:
		node.material_override = part["material"]
	if mirrored:
		node.basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	return node


## R7c: switches on every representation node that has at least one instance inside its distance band (the shaders
## choose per instance, inc/lod_band.gdshaderinc) and the shadow casters inside the reach of the shadow map. The range
## of distances of the chunk's instances: straight-line distances of the box of their origins from the camera (eye),
## like the shaders; without a renderer camera (tests) the path distances of the instances along the road instead.
## meta "lod" = the coarsest chunk level any instance is at (0 / 1 / 2, for debug and tests).
## FIX-R7c (QR7c-03): the walk over the children runs only when the span crosses one of the holder's thresholds
## (_thresholds(): every distance at which a child's visibility or the holder's level changes) – the key is the place of
## the span among them, not the span itself (the 1-m key of R7c changed at every look and walked every child of every
## chunk every 2 m of driving: the hook cost 2.5–3 x and peaked at 3.8–4.4 ms on the Deck preset, QA-R7c).
## QR7c-05: a level node is on from LOD_STEP_M before its band to LOD_STEP_M after it (the look comes every LOD_STEP_M).
func _apply_lod(holder: Node, cam_z: float, eye: Variant = null) -> void:
	var span := _span(holder, cam_z, eye)
	if not holder.has_meta(&"thr_lo"):
		_thresholds(holder)
	var lo: PackedFloat32Array = holder.get_meta(&"thr_lo")
	var hi: PackedFloat32Array = holder.get_meta(&"thr_hi")
	var key := Vector2i(lo.bsearch(span.y, false), hi.bsearch(span.x, true))
	if holder.get_meta(&"span_key", Vector2i(-1, -1)) == key:
		return
	holder.set_meta(&"span_key", key)
	var cast := _casters >= 2 and span.x < _shadow_m + SHADOW_KEEP_M
	holder.set_meta(&"lod", lod_level(span.y, -1, _lod0_m, _lod1_m))
	holder.set_meta(&"cast", cast)
	for c: Node in holder.get_children():
		var n3 := c as Node3D
		if n3 == null:
			continue
		if c.has_meta(&"caster"):
			n3.visible = cast
		elif c.has_meta(&"band"):
			var b: Vector4 = c.get_meta(&"band")
			n3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M
		else:
			n3.visible = true


## FIX-R7c (QR7c-03): the sorted thresholds of a holder for _apply_lod(): "thr_lo" against the farthest instance (band
## starts − LOD_STEP_M, the level distances of the meta "lod"), "thr_hi" against the nearest one (band ends + LOD_STEP_M,
## the reach of the casters). Again after the bands or the shadow reach change (quality_lowered()).
func _thresholds(holder: Node) -> void:
	var lo := PackedFloat32Array([_lod0_m, _lod1_m])
	var hi := PackedFloat32Array([_shadow_m + SHADOW_KEEP_M])
	for c: Node in holder.get_children():
		if c.has_meta(&"band"):
			var b: Vector4 = c.get_meta(&"band")
			lo.append(b.x - LOD_STEP_M)
			hi.append(b.w + LOD_STEP_M)
	lo.sort()
	hi.sort()
	holder.set_meta(&"thr_lo", lo)
	holder.set_meta(&"thr_hi", hi)
	holder.remove_meta(&"span_key")


## (nearest, farthest) distance of the instance origins of a holder from the camera.
func _span(holder: Node, cam_z: float, eye: Variant) -> Vector2:
	var box: AABB = holder.get_meta(&"box", AABB())
	if eye is Vector3 and holder is Node3D and (holder as Node3D).is_inside_tree():
		var wb: AABB = (holder as Node3D).global_transform * box
		var p: Vector3 = eye
		var near := p.clamp(wb.position, wb.end).distance_to(p)
		# the farthest corner: per axis the end farther from the eye
		var far := (p - wb.position).abs().max((wb.end - p).abs()).length()
		return Vector2(near, far)
	var z0 := float(holder.get_meta(&"iz0", holder.get_meta(&"z0", 0.0)))
	var z1 := float(holder.get_meta(&"iz1", holder.get_meta(&"z1", 0.0)))
	var lat := float(holder.get_meta(&"lat", 0.0))
	var dn := maxf(0.0, maxf(z0 - cam_z, cam_z - z1))
	var df := maxf(absf(z1 - cam_z), absf(cam_z - z0))
	return Vector2(dn, sqrt(df * df + lat * lat))


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
