import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6')
p = 'scripts/race3d/builders/tunnel.gd'
s = open(p, encoding='utf-8').read()
old = '''var tunnel_state: Dictionary = {}  ## {"amount", "inside", "portal_z", "exit_m", "portal_m", "exit_in_sight"}: read by tests and the rig'''
new = '''var tunnel_state: Dictionary = {}  ## {"amount", "inside", "exit_m", "portal_m", "exit_in_sight", "light"}: read by tests and the rig
## FIX-R5: the tube's light of this frame for whoever draws something inside a tube (R4's road: QA-R5 QR5-02 – seen
## from outside, the road in the tube must show Arcade's tunnel light, not the open sky's): {"ambient_in",
## "ambient_out" (display factors, Color), "fog" (Palette.TUNNEL_FOG), "darkness_m", "peek_m", "cam_tunnel_z"
## (portal z of the tunnel the camera is in, -1e9 outside), "lights"} – the uniforms of tunnel.gdshader.
var _light: Dictionary = {}'''
assert old in s
s = s.replace(old, new)
old = '''	if key == _state_key:
		return
	_state_key = key
	var m := tube_material()
	m.set_shader_parameter("ambient_in", Vector3(amb.r, amb.g, amb.b))
	var k := 0.5 + 0.5 * lights            # Arcade: the tube seen from outside, eyes adapted to the daylight
	m.set_shader_parameter("ambient_out", Vector3(amb.r * k, amb.g * k, amb.b * k))
	m.set_shader_parameter("cam_tunnel_z", cam_tunnel)
	m.set_shader_parameter("lights", clampf(lights, 0.0, 1.0))
'''
new = '''	if key == _state_key:
		tunnel_state["light"] = _light
		return
	_state_key = key
	var m := tube_material()
	m.set_shader_parameter("ambient_in", Vector3(amb.r, amb.g, amb.b))
	var k := 0.5 + 0.5 * lights            # Arcade: the tube seen from outside, eyes adapted to the daylight
	m.set_shader_parameter("ambient_out", Vector3(amb.r * k, amb.g * k, amb.b * k))
	m.set_shader_parameter("cam_tunnel_z", cam_tunnel)
	m.set_shader_parameter("lights", clampf(lights, 0.0, 1.0))
	_light = {"ambient_in": amb, "ambient_out": Color(amb.r * k, amb.g * k, amb.b * k), "fog": Palette.TUNNEL_FOG,
		"darkness_m": _dark_m, "peek_m": _peek_m, "cam_tunnel_z": cam_tunnel, "lights": clampf(lights, 0.0, 1.0)}
	tunnel_state["light"] = _light
'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = 'tests/unit/race3d/test_tunnel.gd'
s = open(p, encoding='utf-8').read()
old = '''	b.call("update", {"camera_z": _portal_z(t, tu) + 200.0, "palette": pal, "visibility_m": 360.0, "camera_in_tunnel": true}, 0.016)
	assert_near(float(m.get_shader_parameter("cam_tunnel_z")), _portal_z(t, tu), 0.01, "drin: die Röhre des eigenen Tunnels ohne Kappe")
'''
new = '''	var light: Dictionary = (b.get("tunnel_state") as Dictionary).get("light", {})
	assert_true(float(light.get("cam_tunnel_z", 0.0)) < -1.0e8, "tunnel_state.light: draußen")
	b.call("update", {"camera_z": _portal_z(t, tu) + 200.0, "palette": pal, "visibility_m": 360.0, "camera_in_tunnel": true}, 0.016)
	assert_near(float(m.get_shader_parameter("cam_tunnel_z")), _portal_z(t, tu), 0.01, "drin: die Röhre des eigenen Tunnels ohne Kappe")
	# FIX-R5: the tube's light for others (R4's road in the tube, QR5-02) – the tube material's values, every frame
	b.call("update", {"camera_z": _portal_z(t, tu) + 201.0, "palette": pal, "visibility_m": 360.0, "camera_in_tunnel": true}, 0.016)
	light = (b.get("tunnel_state") as Dictionary).get("light", {})
	assert_near(float(light.get("cam_tunnel_z", 0.0)), _portal_z(t, tu), 0.01, "tunnel_state.light: Portal des eigenen Tunnels")
	var amb_in: Vector3 = m.get_shader_parameter("ambient_in")
	var amb_l: Color = light.get("ambient_in", Color.BLACK)
	assert_near(amb_l.r, amb_in.x, 1.0e-6, "tunnel_state.light.ambient_in = Röhre")
	assert_eq(light.get("fog"), Palette.TUNNEL_FOG, "tunnel_state.light.fog = Arcades Tunnelnebel")
	assert_near(float(light.get("darkness_m", 0.0)), float(ConfigLoader.lookup(_config(), "render.tunnel.darkness_m", 260.0)), 1.0e-6,
		"tunnel_state.light.darkness_m")
'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = 'docs/renderer-modern.md'
s = open(p, encoding='utf-8').read()
old = '''  `exit_in_sight` (Ausfahrt innerhalb der Sicht) – für eine Belichtungsrampe an der Ausfahrt, ohne eigene Rechnung.'''
new = '''  `exit_in_sight` (Ausfahrt innerhalb der Sicht) – für eine Belichtungsrampe an der Ausfahrt, ohne eigene Rechnung;
  `light` (FIX-R5) = das Licht der Röhre in diesem Bild, wie es `tunnel.gdshader` bekommt: `ambient_in`, `ambient_out`
  (Anzeigefaktoren der Tunnelumgebung für eine Kamera drinnen / draußen, Arcades × (0,5 + 0,5 × Lichter)), `fog`
  (`Palette.TUNNEL_FOG`), `darkness_m`, `peek_m`, `cam_tunnel_z` (Portal-z des Tunnels der Kamera, −1e9 draußen),
  `lights` – damit die Fahrbahn in der Röhre (R4) von außen Arcades warmes Tunnellicht zeigen kann (Befund QR5-02).'''
assert old in s
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
