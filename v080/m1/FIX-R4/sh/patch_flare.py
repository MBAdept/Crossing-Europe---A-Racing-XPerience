import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, ("pattern", old[:70], s.count(old))
    s = s.replace(old, new)
rep("""// Its instance: origin = the lamp, COLOR = lamp colour and strength, INSTANCE_CUSTOM = (half width m, height of the
// lamp above the road m, length m, lamp radius m for the taps).""",
"""// Its instance: origin = the lamp, COLOR = lamp colour and strength, INSTANCE_CUSTOM = (half width m, height of the
// lamp above the road m, length m, lamp radius m for the taps), and in the BASIS of the instance transform (unused by a
// flare otherwise) the height profile of the road from the lamp's foot to the camera's foot (FIX-R4, QA-R4 B1): the
// road heights relative to the foot at 1/6 … 6/6 of that way in basis columns 0 and 1 (x, y, z each), column 2 x = 1
// when a profile is given. The streak follows that profile (Catmull-Rom through the seven points) instead of lying
// level at the height of the foot: where the road climbs towards a far car, a level quad hung in the air between the
// car and the camera and showed as a red column above the car. Without a profile (column 2 x = 0) the streak lies level.""")
rep("""varying vec3 v_rh;                  // (reach m: foot to the camera's foot, camera height m, 1 = Fresnel along it)

void vertex() {""",
"""varying vec3 v_rh;                  // (reach m: foot to the camera's foot, camera height m, 1 = Fresnel along it)

// Height of the road profile at fraction f (0 = the lamp's foot, 1 = the camera's foot) of the way: Catmull-Rom through
// the seven samples q[0] = 0 (the foot) … q[6], linear beyond the ends.
float profile_at(float q[7], float f) {
	float u = clamp(f, 0.0, 1.0) * 6.0;
	int i = min(int(floor(u)), 5);
	float t = u - float(i);
	float p1 = q[i];
	float p2 = q[i + 1];
	float p0 = i > 0 ? q[i - 1] : 2.0 * p1 - p2;
	float p3 = i < 5 ? q[i + 2] : 2.0 * p2 - p1;
	return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t);
}

void vertex() {""")
rep("""	// the quad on the road: from the ground under the lamp towards the camera, 3 cm above the road
	vec3 ground = lamp - vec3(0.0, INSTANCE_CUSTOM.y - 0.03, 0.0);
	vec3 to_cam = CAMERA_POSITION_WORLD - ground;
	to_cam.y = 0.0;
	float reach = length(to_cam);
	vec3 dir = reach > 0.01 ? to_cam / reach : vec3(0.0, 0.0, 1.0);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), dir));
	// the mirror point: where the camera sees the lamp's mirror image on the road – the eye at height hc and
	// `reach` metres away, the lamp hl above the road: hl / (hc + hl) of the way from the foot to the camera. A rough
	// water film smears the reflection along the view around it, more towards the camera.
	float hc = max(CAMERA_POSITION_WORLD.y - ground.y, 0.5);""",
"""	// the strip on the road: from the ground under the lamp towards the camera, 3 cm above the road (a little more far
	// away, where the depth buffer is coarse and the profile between its samples is a curve)
	vec3 ground = lamp - vec3(0.0, INSTANCE_CUSTOM.y - 0.03, 0.0);
	vec3 to_cam = CAMERA_POSITION_WORLD - ground;
	to_cam.y = 0.0;
	float reach = length(to_cam);
	vec3 dir = reach > 0.01 ? to_cam / reach : vec3(0.0, 0.0, 1.0);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), dir));
	bool has_prof = MODEL_MATRIX[2].x > 0.5;
	float q[7] = float[](0.0, MODEL_MATRIX[0].x, MODEL_MATRIX[0].y, MODEL_MATRIX[0].z, MODEL_MATRIX[1].x,
		MODEL_MATRIX[1].y, MODEL_MATRIX[1].z);
	if (!has_prof) {
		for (int k = 1; k < 7; k++) {
			q[k] = 0.0;
		}
	}
	// the mirror point: where the camera sees the lamp's mirror image on the road – the eye hc above the road at its
	// own foot (the road's plane between the two: on a steady grade the law of the level road holds in that plane) and
	// `reach` metres away, the lamp hl above the road: hl / (hc + hl) of the way from the foot to the camera. A rough
	// water film smears the reflection along the view around it, more towards the camera.
	float hc = max(CAMERA_POSITION_WORLD.y - ground.y - q[6], 0.5);""")
rep("""	float t = VERTEX.y * 0.5 + 0.5;
	float len = clamp(max(3.2 * sm + 1.0, INSTANCE_CUSTOM.z * 0.5), 1.5, max(reach - 0.8, 0.4));
	vec3 p = ground + dir * (t * len - 0.2);""",
"""	float t = VERTEX.y * 0.5 + 0.5;
	float len = clamp(max(3.2 * sm + 1.0, INSTANCE_CUSTOM.z * 0.5), 1.5, max(reach - 0.8, 0.4));
	float s_along = t * len - 0.2;
	float lift = 0.0006 * max(reach - s_along, 0.0);
	vec3 p = ground + dir * s_along + vec3(0.0, profile_at(q, s_along / max(reach, 0.01)) + lift, 0.0);""")
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
