class_name GfxSelfTest
extends RefCounted
## "Can this computer draw the mode Modern at all?" (v0.8.0, fallback layer (a) of docs/dev/v080_contract.md D34):
## renders a tiny lit 3D scene – a white sphere under a shadow-casting directional light and a quad with a custom
## spatial shader in a known colour, on a black background – into a 96×96 SubViewport with its own world, reads the
## picture back and judges three pixels. A driver that cannot compile the 3D shaders or draws nothing gives a black,
## uniform or wrong picture: the Modern renderer then reports healthy() == false and the race session starts the
## stage in Arcade with a message. Called by the renderer inside prepare(), behind the loading overlay, once per run.
## Without a renderer (headless) the test is skipped and counts as passed.

const SIZE := 96
const QUAD_COLOR := Color(0.1, 0.8, 0.3)
## Pixels judged (fractions of the picture): the sunlit front of the sphere, the shader quad, the background.
## The sphere stands 0.9 m left of the axis, 4 m in front of the camera (fov 75°): 0.5 − 0.9 / (2 · 4 · tan 37.5°).
const LIT_AT := Vector2(0.353, 0.5)
const QUAD_AT := Vector2(0.68, 0.5)
const DARK_AT := Vector2(0.04, 0.04)
const LIT_MIN := 0.35          ## luminance the lit sphere must reach
const DARK_MAX := 0.2          ## luminance the background must stay below
const QUAD_TOLERANCE := 0.12   ## per channel


## Builds the test scene under `parent`, waits `frames` frames plus the next drawn one, and returns
## {"ok": bool, "reason": "" | "black" | "shader" | "readback", "ms": float} (+ the judged values "lit", "dark",
## "quad" for logs; "skipped": true without a renderer). Awaitable: `var r: Dictionary = await GfxSelfTest.run(self)`.
static func run(parent: Node, frames: int = 3) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"ok": true, "reason": "", "ms": 0.0, "skipped": true}
	var t0 := Time.get_ticks_usec()
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	sun.shadow_enabled = true   # the light path of Modern: its one directional light always has the flag (D5)
	vp.add_child(sun)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.position = Vector3(-0.9, 0, 0)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	ball.material_override = white
	vp.add_child(ball)
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.position = Vector3(0.9, 0, 0)
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nuniform vec4 tint : source_color;\nvoid fragment() { ALBEDO = tint.rgb; }\n"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("tint", QUAD_COLOR)
	quad.material_override = sm
	vp.add_child(quad)
	for i in maxi(1, frames):
		await parent.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	var res := judge(img)
	res["ms"] = snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	return res


## Verdict on the picture read back (pure, unit tested with synthetic pictures): "readback" = no picture or a
## background that is not the cleared black, "black" = the lit sphere is missing, "shader" = the custom-shader quad
## does not show its colour.
static func judge(img: Image) -> Dictionary:
	if img == null or img.is_empty():
		return {"ok": false, "reason": "readback", "ms": 0.0}
	var w := img.get_width()
	var h := img.get_height()
	var lit := img.get_pixel(int(w * LIT_AT.x), int(h * LIT_AT.y))
	var dark := img.get_pixel(int(w * DARK_AT.x), int(h * DARK_AT.y))
	var q := img.get_pixel(int(w * QUAD_AT.x), int(h * QUAD_AT.y))
	var quad_ok := absf(q.r - QUAD_COLOR.r) < QUAD_TOLERANCE and absf(q.g - QUAD_COLOR.g) < QUAD_TOLERANCE \
		and absf(q.b - QUAD_COLOR.b) < QUAD_TOLERANCE
	var reason := ""
	if lit.get_luminance() <= LIT_MIN:
		reason = "black"
	elif not quad_ok:
		reason = "shader"
	elif dark.get_luminance() >= DARK_MAX:
		reason = "readback"
	return {"ok": reason == "", "reason": reason, "ms": 0.0, "lit": snappedf(lit.get_luminance(), 0.01),
		"dark": snappedf(dark.get_luminance(), 0.01), "quad": "%.2f %.2f %.2f" % [q.r, q.g, q.b]}
