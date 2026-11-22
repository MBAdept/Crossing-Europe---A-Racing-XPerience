import sys
p = sys.argv[1]
s = open(p).read()
old_doc = """## Not drawn here: skyline landmark silhouettes of the destination city (they need the landmark sets – the
## landmarks package) – RaceBackdrop.landmarks stays empty.
## Duck-typed layer: setup(renderer), update(view, dt), snapshot(). Owner: renderer core (R1)."""
new_doc = """##  * R7b: the SKYLINE of the destination city (cities.json "skyline") inside the City Limits, as Arcade draws it
##    (RoadRenderer._skyline_silhouettes / _draw_skyline_landmark, frozen): each silhouette anchored to the panorama
##    when first seen – one that also stands on the road as a landmark starts in its true direction from the camera
##    (in 3D: the direction of its anchor on the path) – then turning with the panorama, faded out while that
##    landmark is within its landmark range (the 3D landmark of builders/landmarks.gd takes over: no double), at
##    render.skyline_distance_m in size. A sprite silhouette is the "c" cell of its sheet (and its light layer at night),
##    a procedural one Arcade's own 2D drawing (RoadRenderer._draw_landmark_proc through a RoadRenderer instance that is
##    never in the tree, drawing into this canvas through its GeoBatch). Sheets are resolved in prepare().
## Duck-typed layer: setup(renderer), prepare(ctx), update(view, dt), snapshot(). Owner: renderer core (R1); the
## skyline: package R7 (wave 5: R7b)."""
assert old_doc in s
s = s.replace(old_doc, new_doc)
old_vars = """var _redraws := 0
var _frames := 0
"""
new_vars = """var _redraws := 0
var _frames := 0
# R7b: skyline silhouettes (Arcade's RoadRenderer._skyline_silhouettes)
var _sky_painter: RoadRenderer          ## draws Arcade's procedural silhouettes into this canvas; never in the tree
var _sky_anchor: Dictionary = {}        ## skyline index -> panorama angle (rad), fixed when first seen
var _sky_dist := 1800.0                 ## render.skyline_distance_m
var _lm_law := Vector2(2.0, 1900.0)     ## render.landmark_range_factor, render.landmark_far_m
var _sky_sig: Array = []
var _sky_list: Array = []               ## this frame's silhouettes (snapshot)
"""
assert old_vars in s
s = s.replace(old_vars, new_vars)
old_setup = """		blend_s = float(ConfigLoader.lookup(cfg, "render.background_blend_s", blend_s))
		_draw_distance = maxf(1.0, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", _draw_distance)))
"""
new_setup = """		blend_s = float(ConfigLoader.lookup(cfg, "render.background_blend_s", blend_s))
		_draw_distance = maxf(1.0, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", _draw_distance)))
		_sky_dist = maxf(200.0, float(ConfigLoader.lookup(cfg, "render.skyline_distance_m", _sky_dist)))
		_lm_law = Vector2(float(ConfigLoader.lookup(cfg, "render.landmark_range_factor", 2.0)),
			float(ConfigLoader.lookup(cfg, "render.landmark_far_m", 1900.0)))
"""
assert old_setup in s
s = s.replace(old_setup, new_setup)
old_bs = """	_fit(_size)
	backdrop.setup(sky_proj, batch, blend_s)
"""
new_bs = """	_fit(_size)
	backdrop.setup(sky_proj, batch, blend_s)
	backdrop.sprite_cb = _draw_skyline_landmark


## R7b: the skyline's pictures are resolved (and their sheets loaded) behind the loading cover, not in the race.
func prepare(_ctx: Dictionary) -> void:
	var track: Track = _renderer.get("track") if _renderer != null else null
	if track == null or track.plan == null or track.plan.skyline.is_empty():
		return
	var p := _painter()
	for e: Dictionary in track.plan.skyline:
		p.call(&"_prep_prop", e)


func _painter() -> RoadRenderer:
	if _sky_painter == null:
		_sky_painter = RoadRenderer.new()
		_sky_painter.batch = batch
		_sky_painter.proj = sky_proj
	return _sky_painter


func _exit_tree() -> void:
	if _sky_painter != null:
		_sky_painter.free()
		_sky_painter = null
"""
assert old_bs in s
s = s.replace(old_bs, new_bs)
old_upd = """	canvas.position = Vector2(-MARGIN, 0.0) + (view.get("shake", Vector2.ZERO) as Vector2)
	var lift := crest_lift(view)"""
new_upd = """	canvas.position = Vector2(-MARGIN, 0.0) + (view.get("shake", Vector2.ZERO) as Vector2)
	backdrop.landmarks = skyline(view, heading)
	var lift := crest_lift(view)"""
assert old_upd in s
s = s.replace(old_upd, new_upd)
old_sig = """		pal.get("sun_pos"), pal.get("moon_pos"), pal.get("stars"), backdrop._blend < 1.0, _drawn_lift]"""
new_sig = """		pal.get("sun_pos"), pal.get("moon_pos"), pal.get("stars"), backdrop._blend < 1.0, _drawn_lift, _sky_sig]"""
assert old_sig in s
s = s.replace(old_sig, new_sig)
old_snap = """		"lift_rows": snappedf(lift_rows, 0.01), "base_row": snappedf(sky_proj.horizon_y - lift_rows, 0.01)}}"""
new_snap = """		"lift_rows": snappedf(lift_rows, 0.01), "base_row": snappedf(sky_proj.horizon_y - lift_rows, 0.01),
		"skyline": _sky_list.duplicate(true)}}"""
assert old_snap in s
s = s.replace(old_snap, new_snap)
s += open(sys.argv[2]).read()
open(p, 'w').write(s)
print("ok")
