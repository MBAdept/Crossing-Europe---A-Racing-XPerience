extends Node3D
## EnvironmentRig of the mode "Modern" (v0.8.0, contract D5–D7, D14 F4, §4.5.6): light, shadow, fog, sky reflections
## and the ce_* globals of a race, driven by the palette of every frame (Palette.compute – any hour, any weather).
## ModernRenderer finds this file by its name, adds the node as "Environment" and exposes it as `renderer.env`.
## No class name: other packages reach it through the facade only (env.get("state"), env.get("sun") …).
##
## It owns
##  * the Environment: background BG_CANVAS behind canvas layer -10 (D7), ambient light as a colour, linear
##    tonemapper, the post path pinned on with neutral adjustments (D6), linear depth fog from begin 0.45 × to
##    1.0 × visibility in the palette's fog colour (fairness rule F4; inside a tunnel Arcade's tunnel law),
##    a small Sky (palette gradient, no sun disc, never TIME) that is ONLY the source of reflections (D7) and is
##    refreshed at most every graphics.modern.sky_update_s seconds of view.time, glow and SSAO per quality level;
##  * exactly ONE DirectionalLight3D – the sun by day, the moon by night –, always with shadow_enabled = true
##    (D5: the lit brightness depends on the flag). In a tunnel its energy goes to 0; it is never hidden;
##  * the ce_* globals a light source defines: ce_time, ce_night, ce_wet, ce_snow, ce_wind, ce_fog_color,
##    ce_fog_range, ce_sun_dir, ce_sun_color, ce_ambient (linear light values, ModernMaterials.light_value()),
##    ce_tunnel. (ce_headlight* belong to the lights layer, ce_far_y to the far-ground layer.)
##
## Light law (light_state(), pure, unit tested). Arcade shows every surface as albedo × palette.ambient. Here a
## LEVEL surface of the reference albedo shows exactly that, and the light is split so that the picture gets depth:
##  - a directed part ("share" of the display value: half of it under a clear day sky, an eighth under rain or
##    snow, a fifth as moonlight) and the rest as ambient light. Shadows show the ambient part alone, faces towards
##    the sun are brighter than level ground. The sun is warm, so the ambient part comes out cooler: blue shadows.
##  - The GL Compatibility renderer turns the ambient pass and the pass of the one shadow-casting light into
##    display values separately and adds them, and the pinned post path runs the sum through both of its
##    approximations once more (docs/modelle.md §4) – that second pass crushed every dark value of the 3D picture
##    and of the backdrop canvas (10 -> 4, 16 -> 11, 22 -> 18 of 255, below 7 black; measured, RINT-B). The
##    Environment therefore carries a colour-correction LUT (post_lut()) that undoes it: with it the post path is
##    exact from 8/255 up (measured) and the split is made in plain display values (post_out / post_in are the
##    identity while POST_EXACT is on; post_shown / post_inverse stay the model of the raw engine path).
##  - Night floor (A-4): those curves crush dark values (a surface of albedo 0.2 would show a tenth of Arcade's
##    night value). Towards the night the reference albedo goes down from REF_DAY to REF_NIGHT, which lifts the
##    night ambient; the moon is added on top of most of it (MOON_TAKE) instead of being taken out of it.
##  - Tunnel: the palette's ambient blends to Palette.TUNNEL_AMBIENT and the directed part to 0 over a few metres
##    around the portal (tunnel_blend – a function of the camera position, so the same place shows the same light).
## Where the sun stands. Arcade's panorama keeps the sun in front of the car all day (sun_pos.x × 1.1 rad), which
## in real 3D means: car rears, sign faces and everything else the chase camera looks at lie in shadow at noon.
## Modern swings the sun to the side and behind with its height (SIDE_SWING × smoothstep of sun_pos.y): low suns –
## dawn and dusk, with the glow on the horizon – stand where Arcade draws them, the midday sun stands behind the
## left shoulder, where Arcade's sprites are lit from. The backdrop layer draws the sun at the same place
## (state.sun_pos replaces palette.sun_pos there), so light, shadows and the disc in the sky always agree.
## The direction is held against the road heading at the car: it does not swing with the bends.
##
## --gfx-debug=cover switches the fog off (terrain cover checks), nolight puts all light into the ambient part.
## Owner: renderer core (R1). Docs: docs/renderer-modern.md.

const BACKDROP_LAYER := -10        ## canvas layers up to this one are the background of the 3D picture
const AZIMUTH_GAIN := 1.1          ## RaceBackdrop.draw_sky: the sun stands at sun_pos.x * 1.1 rad of the panorama
const MOON_AZIMUTH := 0.4          ## … and the moon 0.4 rad beside its arc
const SIDE_SWING := 2.0            ## rad the high sun stands to the left of Arcade's place (behind the left shoulder)
const SIDE_FROM := 0.2             ## sun_pos.y from which the swing starts …
const SIDE_TO := 0.75              ## … and where it is complete
const ELEV_MIN_DEG := 13.0         ## elevation of the light at height 0 (a flatter light gives endless shadows)
const ELEV_MAX_DEG := 46.0         ## … and at height 1: long enough shadows to see them from the chase camera
const OVERCAST_ELEV_DEG := 68.0    ## rain / snow: what is left of the directed light falls from above
## R4 night law for vertical faces (lead decision 8 of wave 3): the moon's light falls from at least this high. A low
## moon lit the walls that face it far more than level ground (cos 30° / sin 30° = 1.7 × at 22:00; M2ZS1 measured
## the light-concrete pylon of the Köhlbrandbrücke 40 % above Arcade, whose night is ambient light only), and the law
## of the light split is made for level ground. From 55° up a vertical face gets at most 0.7 × what level ground gets –
## every bright wall, bridge part and car body stays at or below the level ground's share. The moon in the sky
## (backdrop) stays where the palette puts it.
const MOON_MIN_ELEV_DEG := 55.0
const SHARE_DAY := 0.5             ## directed part of the display value on level ground under a clear day sky
const SHARE_MOON := 0.2            ## … as moonlight in a clear night
const OVERCAST_CUT := 0.75         ## rain / snow: this much of the directed part becomes diffuse
const NIGHT_FROM := 0.1            ## palette.night from which the sun's part fades …
const NIGHT_TO := 0.4              ## … and where it is gone
const MOON_FROM := 0.55            ## palette.night from which the moon's part rises …
const MOON_TO := 0.85              ## … and where it is complete
const MOON_TAKE := 0.4             ## part of the moonlight on level ground that is taken out of the ambient light
const SUN_TINT := 0.7              ## how much of the hue of palette.sun the directed part takes
const SUN_WARM := Color(1.0, 0.975, 0.93)   ## … and a little warmth on top: the shadows turn towards the sky's blue
const GAIN_FLOOR := 0.5            ## the energy makes up for a low sun only down to sin(elevation) = 0.5
const REF_DAY := 0.38              ## albedo (display value) the law is exact for by day (asphalt, the darker greens)
const REF_NIGHT := 0.29            ## … and in the dark (night floor, A-4)
const REF_LUM_NIGHT := 0.3         ## luminance of palette.ambient at which REF_NIGHT applies …
const REF_LUM_DAY := 0.75          ## … and from which REF_DAY applies
const TUNNEL_RAMP_OUT_M := 12.0    ## the tunnel light fades in from this far before the portal …
const TUNNEL_RAMP_IN_M := 14.0     ## … to this far inside
const TUNNEL_FOG_BEGIN_M := 12.0   ## Arcade's tunnel fog: pow((d - 12) / darkness_m, 0.8)
const TUNNEL_FOG_CURVE := 0.8
const SHADOW_DISTANCE_M := 80.0    ## shadow reach when the quality levels give none
const SKY_STEP := 1.5 / 255.0      ## the reflection sky is refreshed when a colour moved by more than this
const GLOW_INTENSITY := 0.55
const GLOW_THRESHOLD := 1.0
const SSAO_RADIUS := 1.2
const SSAO_INTENSITY := 1.4
## R4: exposure ramp at a tunnel exit by day (Arcade: eyes adapted to the tunnel – the outside looks over-exposed,
## RoadRenderer: ambient × 1.7 + 0.25, fog 55 % towards white). A quad across the exit portal, depth tested (the
## tube hides it outside the opening), mixes everything seen through the opening towards EXIT_GLARE_COLOR: EXIT_GLARE_FAR
## of it while the exit is far, EXIT_GLARE_NEAR right at the portal (the eyes are still adapted to the tube – it stays
## bright up to the portal, as Arcade's outside stays over-exposed while the camera is inside); after the exit the
## whole picture is over-exposed for EXIT_AFTER_M of the camera's way (EXIT_AFTER at the portal: the eyes adapt in
## about 1.5 s at 140 km/h). By day only (the ambient's luminance from EXIT_DAY_FROM to EXIT_DAY_TO); a function of
## the camera position, no clock. (First pictures with 0.12 at the portal and 0.22 after it: the exit read normal.)
const EXIT_GLARE_FAR := 0.6
const EXIT_GLARE_NEAR := 0.45
const EXIT_NEAR_M := 10.0
const EXIT_FAR_M := 150.0
const EXIT_AFTER := 0.4
const EXIT_AFTER_M := 60.0
const EXIT_DAY_FROM := 0.35
const EXIT_DAY_TO := 0.75
const EXIT_GLARE_COLOR := Color(1.0, 1.0, 0.97)
const EXIT_QUAD_H := 9.0           ## the glare quad reaches this high above the road (tube ceiling 6.2 m)
## … and stands at least this far beyond the front of the player's car: when the car has already left the tube, the
## outside behind it is over-exposed but the car is not veiled (Arcade's player sprite stays as it is; seen from inside
## the tube, the portal still frames the quad)
const EXIT_CAR_GAP_M := 1.5
const POST_EXACT := true           ## the post path carries post_lut(): it shows what the passes wrote (RINT-B)
const POST_LUT_SIZE := 256         ## texels of the 1D LUT (half floats; texel j belongs to the input (j + 0.5) / size)

const GLARE_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 glare = vec4(1.0, 1.0, 0.97, 0.0);
void fragment() {
	ALBEDO = glare.rgb;
	ALPHA = glare.a;
}
"""

var environment: Environment
var sun: DirectionalLight3D
var sky: Sky
var sky_material: ProceduralSkyMaterial
## light_state() of the last update() plus: "tunnel01", "fog_color" (Color), "fog_begin", "fog_end" (m),
## "heading" (road heading at the car), "sky_updates" (int).
var state: Dictionary = {}

var _renderer: Node
var _track: Track
var _fog_begin := 0.45
var _fog_end := 1.0
var _tunnel_dark_m := 260.0
var _sky_every := 2.0
var _sky_last_t := -1.0e9
var _sky_sig: Array = []
var _sky_updates := 0
var _sky_reflections := true
var _heading := 0.0                ## road heading at the car, of the last update() inside the integrated path
var _light_sig: Array = []         ## what the light of the last frame was computed from (the split is only redone on a change)
var _sent: Dictionary = {}         ## ce_* globals as they were set last (only changes are sent)
var _cover := false
var _nolight := false
## set_zone(): kind -> amount 0..1 as the owner of the zone set it last (a kind nobody set is absent)
var _zones: Dictionary = {}
var _glare: MeshInstance3D         ## R4: the exposure quad of a tunnel exit (null until the first tunnel)
var _glare_mat: ShaderMaterial
var _after: ColorRect              ## R4: over-exposure of the whole picture just after a tunnel exit
var _after_layer: CanvasLayer
var _exit_state := Vector2.ZERO    ## (glare alpha, after-glow alpha) of the last update()


func _init() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = BACKDROP_LAYER
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.adjustment_enabled = true          # the post path is pinned on in every preset (D6)
	if POST_EXACT:
		environment.adjustment_color_correction = post_lut()
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.0
	environment.fog_sun_scatter = 0.0
	environment.fog_aerial_perspective = 0.0
	environment.fog_sky_affect = 0.0
	# the sky is the source of reflections only – never the background, never the ambient light (D7)
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.01
	sky_material.use_debanding = false
	sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true                        # always: D5
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # no disc in the reflection sky: it would re-render every frame
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE_M
	sun.directional_shadow_split_1 = 0.3
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	add_child(sun)


func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	_track = renderer.get("track")
	var cfg: Variant = renderer.get("cfg")
	if cfg is Dictionary:
		var fog: Variant = ConfigLoader.lookup(cfg, "graphics.modern.fog", {})
		if fog is Dictionary:
			_fog_begin = clampf(float((fog as Dictionary).get("begin_frac", _fog_begin)), 0.0, 1.0)
			_fog_end = maxf(_fog_begin + 0.01, float((fog as Dictionary).get("end_frac", _fog_end)))
		_tunnel_dark_m = maxf(20.0, float(ConfigLoader.lookup(cfg, "render.tunnel.darkness_m", _tunnel_dark_m)))
		_sky_every = maxf(0.0, float(ConfigLoader.lookup(cfg, "graphics.modern.sky_update_s", _sky_every)))
	var flags: Variant = renderer.get("debug_flags")
	if flags is Array:
		_cover = (flags as Array).has("cover")
		_nolight = (flags as Array).has("nolight")
	if _cover:
		environment.fog_enabled = false


## Shadow mode and reach, glow, SSAO and sky reflections of the stage – constant for the whole stage (D10). The
## casters are the business of whoever builds them (levels.shadow_casters); the flag of the light stays on in
## every preset (D5). Viewport and RenderingServer states (MSAA, 3D scale, shadow atlas, filter) are set by the
## renderer (scripts/race3d/quality.gd).
func apply_quality(levels: Dictionary) -> void:
	var splits := int(levels.get("shadow_splits", 2))
	if splits <= 1:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	elif splits == 2:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.3
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_split_1 = 0.08
		sun.directional_shadow_split_2 = 0.2
		sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = bool(levels.get("shadow_blend", false))
	var reach := float(levels.get("shadow_distance_m", 0.0))
	sun.directional_shadow_max_distance = reach if reach > 0.0 else SHADOW_DISTANCE_M
	environment.glow_enabled = bool(levels.get("glow", false))
	environment.glow_intensity = GLOW_INTENSITY
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = GLOW_THRESHOLD
	environment.ssao_enabled = bool(levels.get("ssao", false))
	environment.ssao_radius = SSAO_RADIUS
	environment.ssao_intensity = SSAO_INTENSITY
	_sky_reflections = bool(levels.get("sky_reflections", true))
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if _sky_reflections else Environment.REFLECTION_SOURCE_DISABLED


## The slowness watchdog stepped the preset down while the stage runs: what selects no shader variant follows –
## shadow reach, glow, SSAO, sky reflections. Shadow mode and split blending stay as they are (D10).
func quality_lowered(levels: Dictionary) -> void:
	var reach := float(levels.get("shadow_distance_m", 0.0))
	sun.directional_shadow_max_distance = reach if reach > 0.0 else SHADOW_DISTANCE_M
	environment.glow_enabled = bool(levels.get("glow", false))
	environment.ssao_enabled = bool(levels.get("ssao", false))
	_sky_reflections = bool(levels.get("sky_reflections", true))
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if _sky_reflections else Environment.REFLECTION_SOURCE_DISABLED


## Zones of the structure builders (contract §6 R5, lead decision of wave 3): the builder that knows where its
## structure begins and ends tells the rig how much the camera is inside it – duck-typed, every frame it matters:
##   var env = renderer.get("env"); if env != null and env.has_method("set_zone"): env.call("set_zone", "tunnel", a)
## kind "tunnel": amount 0 (open air) .. 1 (inside) blends the light to the tunnel's (Palette.TUNNEL_AMBIENT, sun
## energy 0), the fog to Arcade's tunnel law (Palette.TUNNEL_FOG from 12 m over render.tunnel.darkness_m) and the
## ce_* globals (ce_tunnel = amount; ce_wet, ce_snow and the wind go to 0); the backdrop shows no sky while the
## exit is out of sight, and towards the exit the outside looks over-exposed (exposure ramp, exit_glare()).
## kind "bridge": amount 0..1 over open water – the wind blows stronger (ce_wind).
## Any other kind is kept and reported in snapshot() but changes nothing. The value holds until the next call of the
## same kind; amounts are clamped to 0..1. As long as nobody calls set_zone("tunnel", …) in a stage the rig derives
## the tunnel itself from the plan's tunnel list (tunnel_blend(), a function of the camera position) – exactly the
## light of the minimal tube. The call is cheap (a dictionary write); the rig reads it in its next update(), which
## runs before the builders' update() of the frame: a zone set by a builder's update() acts one frame later.
func set_zone(kind: String, amount: float) -> void:
	_zones[kind] = clampf(amount, 0.0, 1.0)


## The amount of a zone as it was set last, or `fallback` when nobody set that kind in this stage.
func zone(kind: String, fallback: float = 0.0) -> float:
	return float(_zones.get(kind, fallback))


func update(view: Dictionary, _dt: float) -> void:
	var pal: Dictionary = view.get("palette", {})
	var cam_z := float(view.get("camera_z", 0.0))
	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	if _zones.has("tunnel"):
		tunnel01 = float(_zones["tunnel"])
	elif _track != null:
		tunnel01 = tunnel_blend(_track, cam_z + 1.0)
	if _renderer != null:
		var path: RoadPath3D = _renderer.get("path")
		var proj: RoadProjection = _renderer.get("proj")
		if path != null and path.is_ready() and proj != null:
			# only inside the integrated path (the streamer extends it after this update; a position beyond it
			# would make the path integrate all the way there): else the heading of the last frame stays
			var z := cam_z + proj.cam_distance
			if z >= float(path.first) * path.seg_len and z <= float(path.last()) * path.seg_len:
				_heading = path.heading_at(z)
	# the split of the light only changes with the palette and the tunnel; the direction also with the road
	var bg_offset := float(view.get("bg_offset", 0.0))
	var sig := [pal.get("ambient"), pal.get("night"), pal.get("overcast"), pal.get("moon_visible"), pal.get("sun"), pal.get("sun_pos"),
		pal.get("moon_pos"), tunnel01]
	var st: Dictionary
	if sig == _light_sig and not state.is_empty():
		st = state
		st["to_sun"] = light_direction(float(st["azimuth"]), float(st["elevation"]), _heading, bg_offset)
	else:
		_light_sig = sig
		st = light_state(pal, tunnel01, _heading, bg_offset, _nolight)
		var direct: Array = light_for(st["sun"])
		var ambient: Array = light_for(st["ambient"])
		sun.light_color = direct[0]
		sun.light_energy = direct[1]
		environment.ambient_light_color = ambient[0]
		environment.ambient_light_energy = ambient[1]
	var to_sun: Vector3 = st["to_sun"]
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	# fog: the palette's colour between begin and end of the sight (F4); inside a tunnel Arcade's tunnel law
	var vis := maxf(1.0, float(view.get("visibility_m", 900.0)))
	var fog_out: Color = pal.get("fog", Color(0.75, 0.8, 0.85))
	var fog_color := fog_out.lerp(Palette.TUNNEL_FOG, tunnel01)
	var begin := lerpf(vis * _fog_begin, TUNNEL_FOG_BEGIN_M, tunnel01)
	var end := lerpf(vis * _fog_end, TUNNEL_FOG_BEGIN_M + _tunnel_dark_m, tunnel01)
	environment.fog_light_color = fog_color
	environment.fog_depth_begin = begin
	environment.fog_depth_end = maxf(end, begin + 1.0)
	environment.fog_depth_curve = lerpf(1.0, TUNNEL_FOG_CURVE, tunnel01)
	st["tunnel01"] = tunnel01
	st["fog_color"] = fog_color
	st["fog_begin"] = begin
	st["fog_end"] = end
	st["heading"] = _heading
	var t := float(view.get("time", 0.0))
	_update_sky(pal, fog_color, tunnel01, t)
	st["sky_updates"] = _sky_updates
	_update_exit(view, pal, tunnel01, fog_out)
	st["exit_glare"] = _exit_state.x
	st["exit_after"] = _exit_state.y
	state = st
	var night := float(pal.get("lights", 0.0))
	var overcast := float(pal.get("overcast", 0.0))
	_send("ce_time", t)
	_send("ce_night", maxf(night, tunnel01))
	_send("ce_wet", float(pal.get("wet", 0.0)) * (1.0 - tunnel01))
	_send("ce_snow", float(pal.get("snow", 0.0)) * (1.0 - tunnel01))
	_send("ce_wind", wind(t, overcast, tunnel01, zone("bridge")))
	_send("ce_fog_color", fog_color)
	_send("ce_fog_range", Vector2(begin, end))
	_send("ce_sun_dir", to_sun)
	_send("ce_sun_color", st["sun"])
	_send("ce_ambient", st["ambient"])
	_send("ce_ambient_display", st["display"])
	_send("ce_tunnel", tunnel01)
	# R4: the sky wet ground mirrors (display values; inside a tunnel its darkness)
	if not pal.is_empty():
		_send("ce_sky_top", (pal.get("sky_top", Color.BLACK) as Color).lerp(Palette.TUNNEL_FOG, tunnel01))
		_send("ce_sky_horizon", (pal.get("sky_bottom", Color.BLACK) as Color).lerp(Palette.TUNNEL_AMBIENT * 0.35, tunnel01))


## R4: the exposure ramp of a tunnel exit (EXIT_* above): the glare quad across the exit portal while the camera is
## inside a tunnel whose exit is within the sight, the over-exposure of the whole picture just after the exit. Only
## with a tunnel builder (its tube hides the quad outside the opening) and by day.
func _update_exit(view: Dictionary, pal: Dictionary, tunnel01: float, fog_out: Color) -> void:
	_exit_state = Vector2.ZERO
	if _track == null or _track.plan == null or _track.plan.tunnels.is_empty() or _renderer == null or _cover:
		_show_exit(Vector2.ZERO, null, 0.0, fog_out)
		return
	var day := smoothstep(EXIT_DAY_FROM, EXIT_DAY_TO, Palette.luminance(pal.get("ambient", Color.BLACK)))
	var path: RoadPath3D = _renderer.get("path")
	if day <= 0.0 or path == null or not path.is_ready() or _renderer.call(&"builder", "tunnel") == null:
		_show_exit(Vector2.ZERO, null, 0.0, fog_out)
		return
	var cam_z := float(view.get("camera_z", 0.0))
	var vis := float(view.get("visibility_m", 900.0))
	var exit := exit_ahead(_track, cam_z, vis)
	var glare := 0.0
	var z_exit := 0.0
	if not exit.is_empty() and tunnel01 > 0.5:
		z_exit = float(exit["z"])
		glare = day * exit_glare(z_exit - cam_z)
	var after := day * exit_after(exit_behind(_track, cam_z))
	_exit_state = Vector2(glare, after)
	var pl: Dictionary = view.get("player", {})
	var z_quad := z_exit - 0.6
	if not pl.is_empty():
		z_quad = maxf(z_quad, float(pl.get("z", 0.0)) + float(pl.get("length", 4.5)) + EXIT_CAR_GAP_M)
	_show_exit(_exit_state, path if glare > 0.0 else null, z_quad, fog_out)


## Alpha of the glare quad for an exit `d` metres ahead of the camera (pure): EXIT_GLARE_FAR far away, EXIT_GLARE_NEAR
## at the portal.
static func exit_glare(d: float) -> float:
	if d <= 0.0:
		return 0.0
	return lerpf(EXIT_GLARE_NEAR, EXIT_GLARE_FAR, smoothstep(EXIT_NEAR_M, EXIT_FAR_M, d))


## Alpha of the over-exposure of the whole picture `d` metres after a tunnel exit (pure; d < 0: none).
static func exit_after(d: float) -> float:
	if d < 0.0 or d >= EXIT_AFTER_M:
		return 0.0
	return EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M, d))


## The exit of the tunnel the camera is in, when it lies within `vis` metres: {"z": road z of the exit}; else {}.
static func exit_ahead(track: Track, cam_z: float, vis: float) -> Dictionary:
	if track == null or track.plan == null:
		return {}
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		if cam_z >= z0 and cam_z < z1 and z1 - cam_z <= vis:
			return {"z": z1}
	return {}


## Metres the camera is past the exit of a tunnel (-1 when it is not just behind one, EXIT_AFTER_M at most).
static func exit_behind(track: Track, cam_z: float) -> float:
	if track == null or track.plan == null:
		return -1.0
	for t: Dictionary in track.plan.tunnels:
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		var d := cam_z - z1
		if d >= 0.0 and d < EXIT_AFTER_M:
			return d
	return -1.0


## (z_quad: road z of the glare quad – just inside the exit portal, or beyond the player's car)
func _show_exit(a: Vector2, path: RoadPath3D, z_quad: float, fog_out: Color) -> void:
	var col := fog_out.lerp(EXIT_GLARE_COLOR, 0.7)
	if a.x > 0.0 and path != null:
		if _glare == null:
			_glare = _glare_node()
			add_child(_glare)
		var edges := _track.road_edges_at(z_quad) if _track.has_method(&"road_edges_at") else Vector2(-8.0, 8.0)
		var w := (edges.y - edges.x) + 2.0 * 2.5 + 8.0
		var centre := (edges.x + edges.y) * 0.5
		# (the rig stands at the renderer's origin with no transform: local = origin-relative world)
		var fr := path.frame_at(z_quad, centre, EXIT_QUAD_H * 0.5 - 0.5)
		_glare.transform = Transform3D(fr.basis * Basis.from_scale(Vector3(w, EXIT_QUAD_H, 1.0)), fr.origin)
		_glare_mat.set_shader_parameter(&"glare", Vector4(col.r, col.g, col.b, a.x))
		_glare.visible = true
	elif _glare != null:
		_glare.visible = false
	if a.y > 0.0:
		if _after == null:
			_after_layer = CanvasLayer.new()
			_after_layer.layer = 1
			_after_layer.name = "ExitGlare"
			_after = ColorRect.new()
			_after.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_after.set_anchors_preset(Control.PRESET_FULL_RECT)
			_after_layer.add_child(_after)
			add_child(_after_layer)
		_after.color = Color(EXIT_GLARE_COLOR.r, EXIT_GLARE_COLOR.g, EXIT_GLARE_COLOR.b, a.y)
		_after_layer.visible = true
	elif _after_layer != null:
		_after_layer.visible = false


## The glare quad: unshaded, mixed over what lies behind it, depth tested, never written to depth, one draw call.
func _glare_node() -> MeshInstance3D:
	if _glare_mat == null:
		var sh := Shader.new()
		sh.code = GLARE_SHADER
		_glare_mat = ShaderMaterial.new()
		_glare_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "ExitGlare"
	mi.mesh = q
	mi.material_override = _glare_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2       # no light of the lights layer touches it (it is unshaded anyway)
	return mi


## R4: a fresh glare quad for the shader warm-up (the first tunnel exit must not compile it while driving).
func warmup_nodes() -> Array:
	var mi := _glare_node()
	_glare_mat.set_shader_parameter(&"glare", Vector4(1.0, 1.0, 0.97, 0.05))
	mi.scale = Vector3(0.5, 0.5, 1.0)
	return [mi]


## Sets a ce_* global when its value changed (most of them stand still for minutes).
func _send(global_name: String, value: Variant) -> void:
	if _sent.get(global_name) == value:
		return
	_sent[global_name] = value
	ModernMaterials.set_global(global_name, value)


## The palette the backdrop draws. R4 (lead decision of wave 3, "Keine Sonnenscheibe" of the first test build): the
## sun disc stands where Arcade draws it – in front of the car, high at noon – also while the light of a high sun comes
## from behind the left shoulder (sun_azimuth: the chase camera would otherwise look into the back-lit side of
## everything). That is Arcade's own convention: its panorama shows the sun ahead while its sprites are lit from
## behind-left. A low sun (dawn, dusk) is not swung, so there disc, horizon glow, light and shadows agree exactly;
## between, the light turns away from the disc with the sun's height (SIDE_FROM … SIDE_TO).
func sky_palette(pal: Dictionary) -> Dictionary:
	return pal


## Plain data for debug_snapshot(): {"environment": {…}}.
func snapshot() -> Dictionary:
	var to_sun: Vector3 = state.get("to_sun", Vector3.UP)
	var s: Color = state.get("sun", Color.BLACK)
	var a: Color = state.get("ambient", Color.BLACK)
	var fc: Color = state.get("fog_color", Color.BLACK)
	return {"environment": {"plain": false, "to_sun": [snappedf(to_sun.x, 0.0001), snappedf(to_sun.y, 0.0001), snappedf(to_sun.z, 0.0001)],
		"sun": [snappedf(s.r, 0.0001), snappedf(s.g, 0.0001), snappedf(s.b, 0.0001)],
		"ambient": [snappedf(a.r, 0.0001), snappedf(a.g, 0.0001), snappedf(a.b, 0.0001)],
		"share": snappedf(float(state.get("share", 0.0)), 0.0001), "moon": bool(state.get("moon", false)),
		"tunnel01": snappedf(float(state.get("tunnel01", 0.0)), 0.0001),
		"fog": [environment.fog_enabled, snappedf(environment.fog_depth_begin, 0.01), snappedf(environment.fog_depth_end, 0.01)],
		"fog_color": [snappedf(fc.r, 0.0001), snappedf(fc.g, 0.0001), snappedf(fc.b, 0.0001)],
		"shadow": sun.shadow_enabled, "shadow_mode": sun.directional_shadow_mode, "shadow_distance_m": sun.directional_shadow_max_distance,
		"lights_directional": 1, "glow": environment.glow_enabled, "ssao": environment.ssao_enabled,
		"sky_reflections": _sky_reflections, "sky_updates": _sky_updates, "post_pinned": environment.adjustment_enabled,
		"zones": _zones.duplicate()}}


## The reflection sky: the palette's gradient, refreshed at most every sky_update_s of view time and only when a
## colour really moved (a constant sky costs nothing; a radiance map is rebuilt on every change).
func _update_sky(pal: Dictionary, fog_color: Color, tunnel01: float, t: float) -> void:
	if not _sky_reflections or pal.is_empty():
		return
	var top: Color = (pal.get("sky_top", Color.BLACK) as Color).lerp(Palette.TUNNEL_FOG, tunnel01)
	var horizon: Color = (pal.get("sky_bottom", Color.BLACK) as Color).lerp(Palette.TUNNEL_AMBIENT * 0.35, tunnel01)
	var ground := fog_color.darkened(0.45)
	var sig := [top, horizon, ground]
	if not _sky_sig.is_empty():
		if absf(t - _sky_last_t) < _sky_every:
			return
		var moved := 0.0
		for i in 3:
			var a: Color = sig[i]
			var b: Color = _sky_sig[i]
			moved = maxf(moved, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
		if moved <= SKY_STEP:
			return
	_sky_sig = sig
	_sky_last_t = t
	_sky_updates += 1
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon.lerp(ground, 0.5)
	sky_material.ground_bottom_color = ground


## ce_wind (direction x, direction z, strength, gust): a steady direction, stronger under rain and snow and over open
## water (zone "bridge"), with a slow gust from view time (no wall clock, Rule 10); still inside a tunnel.
static func wind(t: float, overcast: float, tunnel01: float, bridge: float = 0.0) -> Vector4:
	var strength := lerpf(0.3, 0.6, clampf(overcast, 0.0, 1.0)) * (1.0 + 0.5 * clampf(bridge, 0.0, 1.0)) * (1.0 - tunnel01)
	var gust := (0.5 + 0.5 * sin(t * 0.31) * sin(t * 0.17 + 1.3)) * (1.0 - tunnel01)
	return Vector4(0.8, 0.6, strength, gust)


## Panorama angle (rad, the angle RaceBackdrop.draw_sky uses for sun_pos.x * AZIMUTH_GAIN) at which Modern's sun
## stands: Arcade's place for a low sun, swung to the left and behind the car with its height.
static func sun_azimuth(sun_pos: Vector2) -> float:
	return sun_pos.x * AZIMUTH_GAIN - SIDE_SWING * smoothstep(SIDE_FROM, SIDE_TO, clampf(sun_pos.y, 0.0, 1.0))


## How much the camera is inside a tunnel, 0..1: 0 in the open, rising from TUNNEL_RAMP_OUT_M before a portal to 1
## at TUNNEL_RAMP_IN_M inside it. A function of the position alone (the plan's tunnel list).
static func tunnel_blend(track: Track, z: float) -> float:
	if track == null or track.plan == null or track.plan.tunnels.is_empty() or z > track.length_z + TUNNEL_RAMP_OUT_M:
		return 0.0
	var signed := -1.0e9
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		signed = maxf(signed, minf(z - z0, z1 - z))
	return smoothstep(-TUNNEL_RAMP_OUT_M, TUNNEL_RAMP_IN_M, signed)


## The light of a palette (Palette.compute), pure. tunnel01: 0 in the open .. 1 inside a tunnel; road_heading =
## heading of the road at the car (RoadPath3D.heading_at), bg_offset = view.bg_offset. Returns {"to_sun": unit
## vector towards the sun / moon (world), "sun": linear light value on a surface that faces it (Color),
## "ambient": linear ambient light value (Color), "display": the palette's ambient as Arcade uses it (display
## factors, blended with the tunnel's), "share": directed part of the display value on level ground,
## "moon": the direction is the moon's, "ref": the reference albedo, "sun_display" / "ambient_display" / "level":
## what a level surface of the reference albedo shows in the sun pass, in the ambient pass and after the post
## path (display values), "azimuth" / "elevation" (rad): panorama angle and height of the light}.
static func light_state(pal: Dictionary, tunnel01: float, road_heading: float, bg_offset: float, flat: bool = false) -> Dictionary:
	var night := clampf(float(pal.get("night", 0.0)), 0.0, 1.0)
	var overcast := clampf(float(pal.get("overcast", 0.0)), 0.0, 1.0)
	var in_tunnel := clampf(tunnel01, 0.0, 1.0)
	var moon := night > 0.5
	var azimuth := 0.0
	var height := 1.0
	if moon:
		var mp: Vector2 = pal.get("moon_pos", Vector2(0.0, 0.5))
		azimuth = mp.x * AZIMUTH_GAIN + MOON_AZIMUTH
		height = mp.y
	else:
		var sp: Vector2 = pal.get("sun_pos", Vector2(0.0, 1.0))
		azimuth = sun_azimuth(sp)
		height = sp.y
	var elev_deg := lerpf(lerpf(ELEV_MIN_DEG, ELEV_MAX_DEG, clampf(height, 0.0, 1.0)), OVERCAST_ELEV_DEG, overcast)
	if moon:
		elev_deg = maxf(elev_deg, MOON_MIN_ELEV_DEG)
	var elev := deg_to_rad(elev_deg)
	var to_sun := light_direction(azimuth, elev, road_heading, bg_offset)
	# directed part of the display value: the sun by day, the moon in a clear night, little under clouds, none inside
	var share_sun := SHARE_DAY * (1.0 - smoothstep(NIGHT_FROM, NIGHT_TO, night))
	var share_moon := SHARE_MOON * smoothstep(MOON_FROM, MOON_TO, night) if bool(pal.get("moon_visible", false)) else 0.0
	var share := (share_sun + share_moon) * (1.0 - OVERCAST_CUT * overcast) * (1.0 - in_tunnel)
	if flat:
		share = 0.0
	var take := 1.0 if share_sun + share_moon <= 0.0 else lerpf(1.0, MOON_TAKE, share_moon / (share_sun + share_moon))
	var p: Color = (pal.get("ambient", Color.WHITE) as Color).lerp(Palette.TUNNEL_AMBIENT, in_tunnel)
	var ref := lerpf(REF_NIGHT, REF_DAY, smoothstep(REF_LUM_NIGHT, REF_LUM_DAY, Palette.luminance(p)))
	var a_ref := engine_to_linear(ref)
	var sun_color: Color = pal.get("sun", Color.WHITE)
	var peak := maxf(maxf(sun_color.r, sun_color.g), maxf(sun_color.b, 0.001))
	var tint := Color.WHITE.lerp(Color(sun_color.r / peak, sun_color.g / peak, sun_color.b / peak), SUN_TINT)
	if not moon:
		tint = Color(tint.r * SUN_WARM.r, tint.g * SUN_WARM.g, tint.b * SUN_WARM.b)
	# a low sun: the energy makes up for the flat angle only down to GAIN_FLOOR, below that level ground gets less
	var ndl := sin(elev)
	var on_ground := minf(ndl / GAIN_FLOOR, 1.0)
	var sun_lin := Color.BLACK
	var amb_lin := Color.BLACK
	var sun_d := Color.BLACK
	var amb_d := Color.BLACK
	var level := Color.BLACK
	for ch in 3:
		var d := post_in(ref * p[ch])                         # what the two passes have to add up to
		var facing := engine_unshow(d * share * tint[ch])    # linear value of the sun pass on a face towards the sun …
		var ground_d := engine_show(facing * on_ground)       # … and its display value on level ground
		var rest_d := maxf(d - take * ground_d, 0.0)
		sun_lin[ch] = facing / (a_ref * maxf(ndl, GAIN_FLOOR))
		amb_lin[ch] = engine_unshow(rest_d) / a_ref
		sun_d[ch] = ground_d
		amb_d[ch] = rest_d
		level[ch] = post_out(rest_d + ground_d)
	return {"to_sun": to_sun, "sun": sun_lin, "ambient": amb_lin, "share": share, "moon": moon, "ref": ref, "display": Color(p.r, p.g, p.b),
		"sun_display": sun_d, "ambient_display": amb_d, "level": level, "azimuth": azimuth, "elevation": elev,
		"sun_pos": Vector2(azimuth / AZIMUTH_GAIN, height)}


## Unit vector towards the light (world): its panorama angle is held against the road heading at the car.
static func light_direction(azimuth: float, elevation: float, road_heading: float, bg_offset: float) -> Vector3:
	var a := road_heading + wrapf(azimuth - bg_offset, -PI, PI)
	return (RoadPath3D.fwd_of(a) * cos(elevation) + Vector3.UP * sin(elevation)).normalized()


## What a level surface of display albedo `albedo` shows under a light_state() (display value per channel): the
## ambient pass and the sun pass, each turned into display values, added, then the post path.
static func shown_level(albedo: float, st: Dictionary) -> Color:
	var a := engine_to_linear(albedo)
	var amb: Color = st["ambient"]
	var s: Color = st["sun"]
	var ndl := maxf((st["to_sun"] as Vector3).y, 0.0)
	var out := Color.BLACK
	for ch in 3:
		out[ch] = post_out(engine_show(a * amb[ch]) + engine_show(a * s[ch] * ndl))
	return out


## What the post path of the race makes of the display value d of the 3D picture: d itself while the Environment
## carries post_lut() (POST_EXACT), else the raw engine path (post_shown).
static func post_out(d: float) -> float:
	return d if POST_EXACT else post_shown(d)


## The display value the passes have to write so that the post path of the race shows `shown`.
static func post_in(shown: float) -> float:
	return shown if POST_EXACT else post_inverse(shown)


## The colour-correction LUT of the race's Environment (RINT-B): 1D, POST_LUT_SIZE texels of half floats, texel j
## holds post_inverse() of the input at its centre, (j + 0.5) / size, and texel 0 holds 0 (black stays black). The
## post path runs the 3D picture through the engine's two approximations (post_shown) and then through this LUT:
## measured on llvmpipe, every value from 8/255 up comes out as it went in (before: 10 -> 4, 16 -> 11, 22 -> 18);
## what the approximations crushed to 0 (below about 7/255) stays black. A 3D LUT does not work (measured).
static func post_lut() -> Texture2D:
	var img := Image.create(POST_LUT_SIZE, 1, false, Image.FORMAT_RGBH)
	for j in POST_LUT_SIZE:
		var v := 0.0 if j == 0 else minf(post_inverse((float(j) + 0.5) / float(POST_LUT_SIZE)), 1.0)
		img.set_pixel(j, 0, Color(v, v, v))
	return ImageTexture.create_from_image(img)


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


## What the pinned post path makes of the display value d of the 3D picture: both approximations once more.
static func post_shown(d: float) -> float:
	return engine_show(engine_to_linear(d))


## Display value of the 3D picture that the post path turns into `shown` (inverse of post_shown, bisection).
static func post_inverse(shown: float) -> float:
	if shown <= 0.0:
		return 0.0
	var lo := 0.0
	var hi := 2.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		if post_shown(mid) < shown:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
