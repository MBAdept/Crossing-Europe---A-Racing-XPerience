class_name RoadProjection
extends RefCounted
## Pseudo-3D camera projection shared by the renderer and gameplay (1/3-visibility rule).
## The camera looks horizontally along the road; the horizon sits at a fixed screen row
## (render.horizon_y_frac). Coordinates relative to the camera: dx lateral metres (+ right),
## dy metres (+ up), dz depth metres (+ ahead).
##
## Tuning knobs (config "render"): fov_deg (horizontal field of view), camera_height_m,
## camera_distance_m (behind the player car centre), horizon_y_frac, near_m.
## Where the player car ends up on screen: rear bottom edge at
##   y = horizon_y + camera_height_m * focal / (camera_distance_m - car_length / 2).
## Owner: race module.

var screen := Vector2(1280, 720)
var horizon_y := 324.0
var focal := 711.0               ## pixels per metre at 1 m depth (derived from fov_deg)
var cam_height := 2.55           ## camera height above the road at the player position (m)
var cam_distance := 7.6          ## camera distance behind the player car centre (m)
var near := 0.3                  ## nearest depth that is projected (m)


func setup(render_cfg: Dictionary, screen_size: Vector2) -> void:
	screen = screen_size
	horizon_y = screen.y * float(render_cfg.get("horizon_y_frac", 0.45))
	focal = (screen.x * 0.5) / tan(deg_to_rad(float(render_cfg.get("fov_deg", 84.0))) * 0.5)
	cam_height = float(render_cfg.get("camera_height_m", 2.55))
	cam_distance = float(render_cfg.get("camera_distance_m", 7.6))
	near = float(render_cfg.get("near_m", 0.3))


## Returns (screen_x, screen_y, scale) where scale = pixels per metre at that depth.
func project(dx: float, dy: float, dz: float) -> Vector3:
	var s := focal / maxf(dz, near)
	return Vector3(screen.x * 0.5 + dx * s, horizon_y - dy * s, s)


## Pixels per metre at depth dz.
func scale_at(dz: float) -> float:
	return focal / maxf(dz, near)


## Screen row of flat ground (camera cam_height above it) at depth dz.
func ground_row(dz: float) -> float:
	return horizon_y + cam_height * scale_at(dz)


## Depth of flat ground seen at screen row y (INF at or above the horizon).
func depth_at_row(y: float) -> float:
	if y <= horizon_y + 0.0001:
		return INF
	return cam_height * focal / (y - horizon_y)


## Horizontal view angle (radians) of a lateral offset dx at depth dz.
func view_angle(dx: float, dz: float) -> float:
	return atan2(dx, maxf(dz, near))


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
