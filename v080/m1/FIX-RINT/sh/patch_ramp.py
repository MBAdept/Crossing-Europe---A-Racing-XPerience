import sys
W = sys.argv[1]


def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        assert old in s, (path, old[:70])
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)


patch(W + '/scripts/race3d/environment_rig.gd', [
    ('''const TUNNEL_RAMP_IN_M := 14.0     ## … to this far inside
''', '''const TUNNEL_RAMP_IN_M := 14.0     ## … to this far inside
## FIX-RINT (QA-RINT-SYSTEM F-01): at the EXIT the light of the open sky is back once the camera leaves the tube – the
## ramp runs from TUNNEL_RAMP_IN_M inside to the exit itself (Arcade switches its palette there, at camera + 1 m). With
## the old symmetric ramp (to 12 m outside) the first 26 m after the exit were lit by the warm tunnel light: a snowy
## landscape read sand-brown for three frames before it turned white.
'''),
    ('''## How much the camera is inside a tunnel, 0..1: 0 in the open, rising from TUNNEL_RAMP_OUT_M before a portal to 1
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
''', '''## How much the camera is inside a tunnel, 0..1: 0 in the open, rising from TUNNEL_RAMP_OUT_M before a portal to 1
## at TUNNEL_RAMP_IN_M inside it, and falling from TUNNEL_RAMP_IN_M before the exit to 0 at the exit (FIX-RINT). A
## function of the position alone (the plan's tunnel list).
static func tunnel_blend(track: Track, z: float) -> float:
	if track == null or track.plan == null or track.plan.tunnels.is_empty() or z > track.length_z + TUNNEL_RAMP_OUT_M:
		return 0.0
	var amount := 0.0
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		amount = maxf(amount, minf(smoothstep(-TUNNEL_RAMP_OUT_M, TUNNEL_RAMP_IN_M, z - z0), smoothstep(0.0, TUNNEL_RAMP_IN_M, z1 - z)))
	return amount
'''),
    ('''	if not exit.is_empty() and tunnel01 > 0.5:
''', '''	# (FIX-RINT: the light ramp ends at the exit itself now – the quad stays up to the exit while the camera is inside)
	if not exit.is_empty() and (tunnel01 > 0.5 or float(exit["z"]) - cam_z < TUNNEL_RAMP_IN_M):
'''),
])

patch(W + '/scripts/race3d/builders/tunnel.gd', [
    ('''## The zone amount at road position z (0 in the open, rising from ZONE_OUT_M before a portal to 1 at ZONE_IN_M
## inside) – EnvironmentRig.tunnel_blend's law, a function of the position alone.
static func zone_amount(track: Track, z: float) -> float:
	if track == null or track.plan == null or track.plan.tunnels.is_empty() or z > track.length_z + ZONE_OUT_M:
		return 0.0
	var signed := -1.0e9
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		signed = maxf(signed, minf(z - z0, z1 - z))
	return smoothstep(-ZONE_OUT_M, ZONE_IN_M, signed)
''', '''## The zone amount at road position z (0 in the open, rising from ZONE_OUT_M before a portal to 1 at ZONE_IN_M
## inside, falling from ZONE_IN_M before the exit to 0 at the exit – FIX-RINT, QA-RINT-BILD F-01: the open sky's light
## is back once the camera leaves the tube, as Arcade's palette) – EnvironmentRig.tunnel_blend's law, a function of
## the position alone.
static func zone_amount(track: Track, z: float) -> float:
	if track == null or track.plan == null or track.plan.tunnels.is_empty() or z > track.length_z + ZONE_OUT_M:
		return 0.0
	var amount := 0.0
	for t: Dictionary in track.plan.tunnels:
		var z0 := track.km_to_z(float(t["start_km"]))
		var z1 := minf(track.km_to_z(float(t["end_km"])), track.length_z)
		amount = maxf(amount, minf(smoothstep(-ZONE_OUT_M, ZONE_IN_M, z - z0), smoothstep(0.0, ZONE_IN_M, z1 - z)))
	return amount
'''),
])

patch(W + '/tests/unit/race3d/test_environment_rig.gd', [
    ('''	assert_between(Rig.tunnel_blend(t, z0), 0.2, 0.6, "am Portal etwa die Hälfte")
''', '''	assert_between(Rig.tunnel_blend(t, z0), 0.2, 0.6, "am Portal etwa die Hälfte")
	# FIX-RINT (QA-RINT-BILD F-01): at the exit the open sky's light is back once the camera leaves the tube
	assert_eq(Rig.tunnel_blend(t, z1), 0.0, "an der Ausfahrt: Tageslicht (Arcade schaltet dort um)")
	assert_eq(Rig.tunnel_blend(t, z1 + 3.0), 0.0, "3 m nach der Ausfahrt: Tageslicht")
	assert_eq(Rig.tunnel_blend(t, z1 - Rig.TUNNEL_RAMP_IN_M - 1.0), 1.0, "vor der Rampe der Ausfahrt: Tunnellicht")
	last = 1.0
	z = z1 - 18.0
	while z < z1 + 2.0:
		var w := Rig.tunnel_blend(t, z)
		assert_true(w <= last and last - w < 0.2, "die Rampe zur Ausfahrt fällt stetig (%.1f m: %.3f)" % [z - z1, w])
		last = w
		z += 1.0
'''),
])
print("ok")
