extends Node3D
## Built-in plain environment of the Modern renderer (skeleton of wave 1, v0.8.0): what ModernRenderer uses while
## scripts/race3d/environment_rig.gd does not exist, so that every package sees lit geometry from the first day.
## Loaded by the renderer only (no class name: nothing else may rely on it). It has the same duck-typed interface
## as the real rig – setup(renderer), apply_quality(levels), update(view, dt), snapshot() – and owns
##  * the Environment: BG_CANVAS behind canvas layer -10 (D7), ambient light as a colour from the palette, linear
##    tonemapper, the post path pinned on with neutral adjustments (D6), linear depth fog from
##    graphics.modern.fog (begin 0.45 x visibility, end 1.0 x visibility, colour palette.fog – rule F4),
##  * exactly ONE DirectionalLight3D, always with shadow_enabled = true (D5): the sun by day; towards the night
##    its energy goes to 0 (two dark passes would both fall below the display floor), in a tunnel as well – the
##    light is never hidden or disabled,
##  * the ce_* globals a light source defines: ce_time, ce_night, ce_wet, ce_snow, ce_fog_color, ce_fog_range,
##    ce_sun_dir, ce_sun_color, ce_ambient (both through ModernMaterials.light_value()), ce_tunnel.
##
## Light law (light_state(), pure and unit tested). Arcade shows every surface as albedo x palette.ambient. Here a
## LEVEL surface shows the same: the palette's ambient is split into a directed part ("share": half of it by day,
## 35 % under rain or snow, none at night) and the rest as ambient light. The GL Compatibility renderer converts
## the ambient pass and the pass of the one shadow-casting light to display values separately and adds them
## (docs/modelle.md §4), so the split is made in display values and turned into linear light with the renderer's
## own approximations for one albedo (REF_ALBEDO). Level ground then shows Arcade's colour by day within -4 ..
## +7 % for albedos 0.3 .. 0.9 (computed, unit test; -13 % at 0.2); at dusk and at night dark albedos come out far
## darker (down to -59 % at 0.2 in rain) and bright ones up to a third brighter (+35 % at 0.9) – the renderer's
## display curve is not a plain factor on dark values (computed table: docs/renderer-modern.md §9.6). Shadows show the
## ambient part only, faces towards the sun are a little brighter than level ground.
## Direction: where RaceBackdrop draws the sun (sun_pos.x * 1.1 rad of the panorama, turned with view.bg_offset),
## held against the road heading at the car, so it does not swing with the bends; elevation 12 .. 62 degrees,
## under an overcast sky a soft light from above (75 degrees).
## --gfx-debug=cover switches the fog off (terrain cover checks).
## Owner: renderer package (R1 replaces it by environment_rig.gd). Docs: docs/renderer-modern.md.

const BACKDROP_LAYER := -10        ## canvas layers up to this one are the background of the 3D picture
const AZIMUTH_GAIN := 1.1          ## RaceBackdrop.draw_sky: the sun stands at sun_pos.x * 1.1 rad
const MOON_AZIMUTH := 0.4          ## … and the moon 0.4 rad beside its arc
const ELEV_MIN_DEG := 12.0         ## elevation of the light at sun_pos.y = 0 (a flatter light gives endless shadows)
const ELEV_MAX_DEG := 62.0         ## … and at sun_pos.y = 1
const SHARE_DAY := 0.5             ## part of the palette's ambient that arrives as directed light on level ground
const OVERCAST_CUT := 0.3          ## rain / snow: this much of the directed part becomes diffuse …
const OVERCAST_ELEV_DEG := 75.0    ## … and what is left falls from above (a soft top light, short shadows)
const NIGHT_FROM := 0.1            ## palette.night from which the directed part fades …
const NIGHT_TO := 0.4              ## … and where it is gone
const SUN_TINT := 0.6              ## how much of the hue of palette.sun the directed part takes
const GAIN_FLOOR := 0.5            ## the energy compensates a low sun only down to sin(elevation) = 0.5
const REF_ALBEDO := 0.38           ## albedo (display value) the split is exact for (asphalt, the darker greens)
const SHADOW_DISTANCE_M := 80.0    ## shadow reach when the quality levels give none

var environment: Environment
var sun: DirectionalLight3D
var state: Dictionary = {}         ## light_state() of the last update()

var _renderer: Node
var _fog_begin := 0.45
var _fog_end := 1.0
var _heading := 0.0                ## road heading at the car, of the last update() inside the integrated path


func _init() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = BACKDROP_LAYER
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.adjustment_enabled = true
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.0
	environment.fog_sun_scatter = 0.0
	environment.fog_aerial_perspective = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE_M
	add_child(sun)


func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var cfg: Variant = renderer.get("cfg")
	var fog: Variant = ConfigLoader.lookup(cfg, "graphics.modern.fog", {}) if cfg is Dictionary else {}
	if fog is Dictionary:
		_fog_begin = clampf(float((fog as Dictionary).get("begin_frac", _fog_begin)), 0.0, 1.0)
		_fog_end = maxf(_fog_begin + 0.01, float((fog as Dictionary).get("end_frac", _fog_end)))
	var flags: Variant = renderer.get("debug_flags")
	if flags is Array and (flags as Array).has("cover"):
		environment.fog_enabled = false


## Shadow mode and reach of the stage (constant for the whole stage, D10). The casters are the business of
## whoever builds them (levels.shadow_casters); the flag of the light stays on in every preset (D5).
func apply_quality(levels: Dictionary) -> void:
	var splits := int(levels.get("shadow_splits", 2))
	if splits <= 1:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	elif splits == 2:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = bool(levels.get("shadow_blend", false))
	var reach := float(levels.get("shadow_distance_m", 0.0))
	sun.directional_shadow_max_distance = reach if reach > 0.0 else SHADOW_DISTANCE_M


func update(view: Dictionary, _dt: float) -> void:
	var pal: Dictionary = view.get("palette", {})
	var tunnel := bool(view.get("camera_in_tunnel", false))
	if _renderer != null:
		var path: RoadPath3D = _renderer.get("path")
		var proj: RoadProjection = _renderer.get("proj")
		if path != null and path.is_ready() and proj != null:
			# only inside the integrated path (the streamer extends it after this update; a position beyond it
			# would make the path integrate all the way there): else the heading of the last frame stays
			var z := float(view.get("camera_z", 0.0)) + proj.cam_distance
			if z >= float(path.first) * path.seg_len and z <= float(path.last()) * path.seg_len:
				_heading = path.heading_at(z)
	state = light_state(pal, tunnel, _heading, float(view.get("bg_offset", 0.0)))
	var direct: Array = light_for(state["sun"])
	var ambient: Array = light_for(state["ambient"])
	var to_sun: Vector3 = state["to_sun"]
	sun.light_color = direct[0]
	sun.light_energy = direct[1]
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	environment.ambient_light_color = ambient[0]
	environment.ambient_light_energy = ambient[1]
	var vis := maxf(1.0, float(view.get("visibility_m", 900.0)))
	var fog_color: Color = Palette.TUNNEL_FOG if tunnel else pal.get("fog", Color(0.75, 0.8, 0.85))
	environment.fog_light_color = fog_color
	environment.fog_depth_begin = vis * _fog_begin
	environment.fog_depth_end = vis * _fog_end
	ModernMaterials.set_global("ce_time", float(view.get("time", 0.0)))
	ModernMaterials.set_global("ce_night", float(pal.get("lights", 0.0)))
	ModernMaterials.set_global("ce_wet", float(pal.get("wet", 0.0)))
	ModernMaterials.set_global("ce_snow", float(pal.get("snow", 0.0)))
	ModernMaterials.set_global("ce_fog_color", fog_color)
	ModernMaterials.set_global("ce_fog_range", Vector2(vis * _fog_begin, vis * _fog_end))
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(sun.light_color, sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(environment.ambient_light_color, environment.ambient_light_energy))
	ModernMaterials.set_global("ce_tunnel", 1.0 if tunnel else 0.0)


## Plain data for debug_snapshot(): {"environment": {plain, to_sun, sun, ambient, share, moon, fog}}.
func snapshot() -> Dictionary:
	var to_sun: Vector3 = state.get("to_sun", Vector3.UP)
	var s: Color = state.get("sun", Color.BLACK)
	var a: Color = state.get("ambient", Color.BLACK)
	return {"environment": {"plain": true, "to_sun": [snappedf(to_sun.x, 0.0001), snappedf(to_sun.y, 0.0001), snappedf(to_sun.z, 0.0001)],
		"sun": [snappedf(s.r, 0.0001), snappedf(s.g, 0.0001), snappedf(s.b, 0.0001)],
		"ambient": [snappedf(a.r, 0.0001), snappedf(a.g, 0.0001), snappedf(a.b, 0.0001)],
		"share": snappedf(float(state.get("share", 0.0)), 0.0001), "moon": bool(state.get("moon", false)),
		"fog": [environment.fog_enabled, snappedf(environment.fog_depth_begin, 0.01), snappedf(environment.fog_depth_end, 0.01)],
		"shadow": sun.shadow_enabled}}


## The light of a palette (Palette.compute), pure: {"to_sun": unit vector towards the sun / moon (world),
## "sun": linear light value on a surface that faces it (Color), "ambient": linear ambient light value (Color),
## "share": directed part of the palette's ambient on level ground (0 .. SHARE_DAY, display values),
## "moon": the direction is the moon's, "sun_display" / "ambient_display": the two parts as display factors}.
## road_heading = heading of the road at the car (RoadPath3D.heading_at), bg_offset = view.bg_offset.
static func light_state(pal: Dictionary, in_tunnel: bool, road_heading: float, bg_offset: float) -> Dictionary:
	var p: Color = pal.get("ambient", Color.WHITE)
	var night := clampf(float(pal.get("night", 0.0)), 0.0, 1.0)
	var overcast := clampf(float(pal.get("overcast", 0.0)), 0.0, 1.0)
	var moon := night > 0.5
	var body: Vector2 = pal.get("moon_pos", Vector2(0.0, 0.5)) if moon else pal.get("sun_pos", Vector2(0.0, 1.0))
	var azimuth := body.x * AZIMUTH_GAIN + (MOON_AZIMUTH if moon else 0.0)
	var elev := deg_to_rad(lerpf(lerpf(ELEV_MIN_DEG, ELEV_MAX_DEG, clampf(body.y, 0.0, 1.0)), OVERCAST_ELEV_DEG, overcast))
	var a := road_heading + wrapf(azimuth - bg_offset, -PI, PI)
	var to_sun := (RoadPath3D.fwd_of(a) * cos(elev) + Vector3.UP * sin(elev)).normalized()
	var share := SHARE_DAY * (1.0 - smoothstep(NIGHT_FROM, NIGHT_TO, night)) * (1.0 - OVERCAST_CUT * overcast)
	if in_tunnel:
		p = Palette.TUNNEL_AMBIENT
		share = 0.0
	var sun_color: Color = pal.get("sun", Color.WHITE)
	var peak := maxf(maxf(sun_color.r, sun_color.g), maxf(sun_color.b, 0.001))
	var tint := Color.WHITE.lerp(Color(sun_color.r / peak, sun_color.g / peak, sun_color.b / peak), SUN_TINT)
	# a low sun: the energy makes up for the flat angle only down to GAIN_FLOOR, below that level ground gets less
	var ndl := sin(elev)
	var gain := 1.0 / maxf(ndl, GAIN_FLOOR)
	var ground := pow(minf(ndl * gain, 1.0), 1.0 / 2.2)   # display factor of the directed part on level ground
	var direct := Color(p.r * share * tint.r, p.g * share * tint.g, p.b * share * tint.b)
	var rest := Color(maxf(p.r - direct.r * ground, 0.0), maxf(p.g - direct.g * ground, 0.0), maxf(p.b - direct.b * ground, 0.0))
	var s := linear_for(direct)
	return {"to_sun": to_sun, "sun": Color(s.r * gain, s.g * gain, s.b * gain), "ambient": linear_for(rest), "share": share,
		"moon": moon, "sun_display": direct, "ambient_display": rest}


## Linear light value under which a surface of albedo REF_ALBEDO shows REF_ALBEDO x `display` (per channel).
static func linear_for(display: Color) -> Color:
	var k := engine_to_linear(REF_ALBEDO)
	return Color(engine_unshow(REF_ALBEDO * display.r) / k, engine_unshow(REF_ALBEDO * display.g) / k, engine_unshow(REF_ALBEDO * display.b) / k)


## [light colour (as a light node takes it: sRGB), energy] for a linear light value – the inverse of
## ModernMaterials.light_value().
static func light_for(linear: Color) -> Array:
	var energy := maxf(maxf(linear.r, linear.g), linear.b)
	if energy <= 0.0:
		return [Color.WHITE, 0.0]
	return [Color(linear.r / energy, linear.g / energy, linear.b / energy).linear_to_srgb(), energy]


## The Compatibility renderer's sRGB -> linear for albedo values (measured, docs/modelle.md §4).
static func engine_to_linear(c: float) -> float:
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


## … and its linear -> display value at the end of every pass.
static func engine_show(x: float) -> float:
	return maxf(1.055 * pow(maxf(x, 0.0), 0.416666667) - 0.055, 0.0)


## Linear value that shows as display value d (0 for d <= 0: a pass below the floor contributes nothing).
static func engine_unshow(d: float) -> float:
	return pow((d + 0.055) / 1.055, 2.4) if d > 0.0 else 0.0
