p='tests/unit/race3d/test_tunnel.gd'
s=open(p,encoding='utf-8').read()
old='''## Stands for the renderer: the facade members the tunnel builder reads.'''
new='''## A rig without set_zone (the wave-2 rig, or R4's before set_zone exists): the builder must not call it.
class EnvWithoutZone extends RefCounted:
	var tunnel01 := 0.0


## Stands for the renderer: the facade members the tunnel builder reads.'''
assert old in s; s=s.replace(old,new)
old='''	assert_near(float(st.get("exit_m", 0.0)), t.km_to_z(float(tu["end_km"])) - z0 - 100.0, 0.01, "Weg bis zur Ausfahrt")
'''
new='''	assert_near(float(st.get("exit_m", 0.0)), t.km_to_z(float(tu["end_km"])) - z0 - 100.0, 0.01, "Weg bis zur Ausfahrt")
	# a rig without set_zone: no call (a call would be a script error), the state is kept (QA-R5 QR5-05)
	r.env = EnvWithoutZone.new()
	b.call("update", {"camera_z": z0 - 5.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	b.call("update", {"camera_z": z0 + 3.0, "palette": pal, "visibility_m": 900.0}, 0.016)
	var snap: Dictionary = (b.call("snapshot") as Dictionary).get("tunnel", {})
	assert_eq(int(snap.get("zone_calls", -1)), 0, "Rig ohne set_zone: kein Aufruf")
	assert_near(float((b.get("tunnel_state") as Dictionary).get("amount", -1.0)), Tunnel.zone_amount(t, z0 + 4.0), 1.0e-6,
		"Rig ohne set_zone: tunnel_state folgt trotzdem dem Gesetz")
'''
assert old in s; s=s.replace(old,new)
s=s.rstrip('\n')+'''


## QA-R5 QR5-01: the portal (frame, headwall, wing walls, hill) lies on the ground's render layer – the low beam's
## spots and the lamp omnis (cull mask: everything but that layer) leave it out, as Arcade's portal is never lit by the
## headlights (RoadRenderer._draw_portal: colour × ambient + fog); it stays in the sun and casts its shadow. The tube
## (unshaded, its own analytic beam) keeps the default layer.
func test_portal_on_the_ground_layer_out_of_the_low_beam() -> void:
	var t := _track("bern_mailand", "bern")
	var tu := _tunnel(t, "Gotthard-Strassentunnel")
	var built := _build(t, tu, 3)
	var mask := int((load("res://scripts/race3d/layers/lights.gd") as GDScript).get_script_constant_map().get("LIGHT_MASK", 0))
	assert_true(mask != 0, "LIGHT_MASK der Lichtebene gelesen")
	var b: Object = Tunnel.new()
	var portals := 0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		var part: Dictionary = e[1]
		if (part.get("portal", []) as Array).is_empty():
			continue
		var holder := Node3D.new()
		b.call("commit", ctx, part, holder)
		for n: Node in holder.get_children():
			if n.name == &"TunnelPortal":
				portals += 1
				var gi := n as GeometryInstance3D
				assert_eq(gi.layers, Tunnel.PORTAL_LAYERS, "Portal auf der Bodenebene (Renderlayer 2)")
				assert_eq(gi.layers & mask, 0, "kein Spot- oder Omnilicht der Lichtebene erreicht das Portal")
				assert_true(gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "das Portal wirft weiter Schatten")
			elif n.name == &"TunnelTube":
				assert_eq((n as GeometryInstance3D).layers, 1, "die Röhre bleibt auf Renderlayer 1")
		holder.free()
	assert_eq(portals, 1, "ein Portal am Gotthard gebaut und übergeben")
'''
open(p,'w',encoding='utf-8').write(s)
print('ok')
