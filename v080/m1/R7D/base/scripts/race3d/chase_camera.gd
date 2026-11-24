class_name ChaseCamera3D
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): the chase camera = Arcade's projection, exactly, plus a look-into-the-curve
## yaw. Pure maths, no node: the renderer copies transform() and frustum() to its Camera3D
## (PROJECTION_FRUSTUM, keep_aspect = KEEP_HEIGHT), tests use project().
##
## Projection: the focal length of the simulation's RoadProjection (711 logical px at 1280 x 720) at every aspect
## ratio, the horizon on the same fraction of the picture height (render.horizon_y_frac), no pitch, no roll:
##   size = near * H / focal, frustum_offset = (0, -(0.5 - horizon_frac) * size).
## A wider or taller window only adds view. Camera shake = frustum-offset jitter (the picture moves by `shake`
## logical pixels like Arcade's draw transform), never a camera rotation.
## Position = (camera_z, camera_x, camera_y) of the view dictionary on the true path.
## Yaw = look_gain * bearing of the centreline look_m ahead, at most yaw_max_deg – a function of the position
## only, so the same place always shows the same picture.
## Config: graphics.modern.camera {look_gain, look_m, yaw_max_deg, near_m, far_m}.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

var focal := 711.0                 ## logical pixels per metre at 1 m depth (RoadProjection.focal)
var horizon_frac := 0.45           ## horizon row / picture height
var look_gain := 0.6
var look_m := 100.0
var yaw_max := deg_to_rad(14.0)
var near := 1.0
var far := 2600.0


func setup(proj: RoadProjection, cam_cfg: Dictionary) -> void:
	focal = proj.focal
	horizon_frac = proj.horizon_y / maxf(1.0, proj.screen.y)
	look_gain = float(cam_cfg.get("look_gain", 0.6))
	look_m = maxf(1.0, float(cam_cfg.get("look_m", 100.0)))
	yaw_max = deg_to_rad(maxf(0.0, float(cam_cfg.get("yaw_max_deg", 14.0))))
	near = maxf(0.05, float(cam_cfg.get("near_m", 1.0)))
	far = maxf(near + 1.0, float(cam_cfg.get("far_m", 2600.0)))


## Look-into-the-curve yaw (rad, + = to the right) of a camera at road position cam_z: look_gain times the bearing
## of the centreline look_m ahead, relative to the road heading at cam_z.
func look_yaw(path: RoadPath3D, cam_z: float) -> float:
	if look_gain == 0.0:
		return 0.0
	var a := path.heading_at(cam_z)
	var d := path.centre_at(cam_z + look_m) - path.centre_at(cam_z)
	var across := d.x * cos(a) + d.z * sin(a)
	var along := d.x * sin(a) - d.z * cos(a)
	if absf(across) < 1.0e-9 and absf(along) < 1.0e-9:
		return 0.0
	return clampf(look_gain * atan2(across, along), -yaw_max, yaw_max)


## Camera transform (origin-relative) for a view dictionary: on the path at camera_z, camera_x to the right of the
## centreline, at the height camera_y, looking along the road heading plus look_yaw().
func transform(view: Dictionary, path: RoadPath3D) -> Transform3D:
	var cam_z := float(view.get("camera_z", 0.0))
	var c := path.centre_at(cam_z)
	var a := path.heading_at(cam_z)
	var pos := Vector3(c.x, float(view.get("camera_y", c.y)), c.z) + RoadPath3D.right_of(a) * float(view.get("camera_x", 0.0))
	var yaw := a + look_yaw(path, cam_z)
	return Transform3D(Basis(RoadPath3D.right_of(yaw), Vector3.UP, -RoadPath3D.fwd_of(yaw)), pos)


## Frustum of a Camera3D (keep_aspect = KEEP_HEIGHT) for a viewport of `viewport_size` logical pixels:
## {"size", "offset": Vector2, "near", "far"}. `shake` moves the picture by that many logical pixels (+x right,
## +y down).
func frustum(viewport_size: Vector2, shake: Vector2 = Vector2.ZERO) -> Dictionary:
	var size := near * viewport_size.y / focal
	var per_px := near / focal
	return {"size": size, "offset": Vector2(-shake.x * per_px, -(0.5 - horizon_frac) * size + shake.y * per_px),
		"near": near, "far": far}


## Projects an origin-relative point through camera transform `cam` and frustum `fr` (of frustum()) into a viewport of
## `viewport_size` logical pixels: (pixel x, pixel y, depth in m along the view axis). Depth <= 0: behind the camera
## (the pixel values are then meaningless). The same mapping as Camera3D.unproject_position().
static func project(cam: Transform3D, fr: Dictionary, viewport_size: Vector2, p: Vector3) -> Vector3:
	var v := cam.affine_inverse() * p
	var depth := -v.z
	var size: float = fr["size"]
	var off: Vector2 = fr["offset"]
	var n: float = fr["near"]
	var k := viewport_size.y / size
	var s := n / maxf(depth, 1.0e-6)
	return Vector3(viewport_size.x * 0.5 + (v.x * s - off.x) * k, viewport_size.y * 0.5 - (v.y * s - off.y) * k, depth)


## True when a projected point (of project()) lies inside the picture and between the near and far plane.
static func on_screen(px: Vector3, fr: Dictionary, viewport_size: Vector2) -> bool:
	return px.z > float(fr["near"]) and px.z < float(fr["far"]) and px.x >= 0.0 and px.x <= viewport_size.x \
		and px.y >= 0.0 and px.y <= viewport_size.y
