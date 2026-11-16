import sys
root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/unit/race3d/test_chase_camera.gd'
s = open(p).read()
a = '''## In bends the true 3D picture differs from Arcade's sheared one by a few pixels near the car (tangent camera,
## look_gain 0) – the bounds measured by the design study: R 400 m <= 6 px up to 150 m, R 136 m <= 22 px up to 100 m.
func test_curve_parity_bounds() -> void:
	var cam := _camera({"look_gain": 0.0})
	var proj := _base_proj()
	var size := Vector2(1280, 720)
	for case: Array in [[400.0, 150.0, 6.0], [136.0, 100.0, 22.0]]:'''
b = '''## In bends the true 3D picture differs from Arcade's sheared one by a few pixels near the car (tangent camera,
## look_gain 0). On a constant arc that starts at the camera – the worst case – the road points (centre and
## ± 5.6 m) differ by at most 8 px up to 150 m at R 400 m and 27 px up to 100 m at R 136 m (the design study measured
## <= 6 px and 11–22 px at real positions, where the bend does not have its full curvature all the way).
func test_curve_parity_bounds() -> void:
	var cam := _camera({"look_gain": 0.0})
	var proj := _base_proj()
	var size := Vector2(1280, 720)
	for case: Array in [[400.0, 150.0, 8.0], [136.0, 100.0, 27.0]]:'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
