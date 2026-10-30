class_name RoadProjection
extends RefCounted
## Pseudo-3D camera projection shared by the renderer and gameplay (1/3-visibility rule).
## The camera looks horizontally; the horizon sits at a fixed screen row (render.horizon_y_frac).
## Coordinates relative to the camera: dx lateral metres (+ right), dy metres (+ up), dz depth metres.

var screen := Vector2(1280, 720)
var horizon_y := 302.4
var focal := 537.0              ## pixels per metre at 1 m depth
var cam_height := 3.2           ## camera height above the road at the player position (m)
var cam_distance := 6.6         ## camera distance behind the player car centre (m)
var near := 0.3


func setup(render_cfg: Dictionary, screen_size: Vector2) -> void:
	screen = screen_size
	horizon_y = screen.y * float(render_cfg.get("horizon_y_frac", 0.42))
	focal = (screen.x * 0.5) / tan(deg_to_rad(float(render_cfg.get("fov_deg", 100.0))) * 0.5)
	cam_height = float(render_cfg.get("camera_height_m", 3.2))
	cam_distance = float(render_cfg.get("camera_distance_m", 6.6))


## Returns (screen_x, screen_y, scale) where scale = pixels per metre at that depth.
func project(dx: float, dy: float, dz: float) -> Vector3:
	var s := focal / maxf(dz, near)
	return Vector3(screen.x * 0.5 + dx * s, horizon_y - dy * s, s)


## Fraction (0..1) of an object of height_m standing on (flat) ground at depth dz that is on screen
## vertically. Used for "cars from behind collide only when at least 1/3 is visible".
func visible_fraction(dz: float, height_m: float) -> float:
	if dz <= near or height_m <= 0.0:
		return 0.0
	var s := focal / dz
	var bottom := horizon_y + cam_height * s
	var top := bottom - height_m * s
	var vis := minf(bottom, screen.y) - maxf(top, 0.0)
	return clampf(vis / maxf(bottom - top, 0.001), 0.0, 1.0)
