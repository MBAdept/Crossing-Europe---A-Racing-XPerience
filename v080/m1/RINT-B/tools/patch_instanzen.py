#!/usr/bin/env python3
"""Adds the check "instanzen" to tests/race3d/check_vehicles.gd (RINT-B helper)."""
import sys

p = sys.argv[1]
s = open(p).read()
old = '''##   ueberblendung  the far levels of a model (lod1 <-> lod2) cross-fade with complementary dither masks for XFADE_S
##              of view time, then only the new level is drawn (RINT-B)
'''
new = '''##   ueberblendung  the far levels of a model (lod1 <-> lod2) cross-fade with complementary dither masks for XFADE_S
##              of view time, then only the new level is drawn (RINT-B)
##   instanzen  a minute of Kiel–Hamburg with traffic at four times the speed: the geometry instances of all built
##              levels (active and pooled cars – each takes 16 of the 4096 slots of Godot's global shader buffer in
##              the Compatibility renderer) stay within the layer's INSTANCE_BUDGET after every frame, the layer's
##              count matches the nodes under the car roots, and the budget really frees (RINT-B)
'''
assert old in s
s = s.replace(old, new)
a = 'const CHECKS := ["lampen", "kasten", "leistung", "schilder", "lampen_fest", "schatten", "ueberblendung"]'
assert a in s
s = s.replace(a, 'const CHECKS := ["lampen", "kasten", "leistung", "schilder", "lampen_fest", "schatten", "ueberblendung", "instanzen"]')
anchor = '# --- ueberblendung ---'
i = s.index(anchor)
check = '''# --- instanzen -------------------------------------------------------------------------------------------------------

## RINT-B: Godot's Compatibility renderer gives each geometry instance whose material has instance uniforms 16 slots of
## its global shader buffer (4096 slots with a 64 KB uniform block): beyond about 250 such instances it refuses one
## ("Too many instances using shader instance variables") and draws it with another one's values. Pooled cars keep
## their levels, so the layer bounds the instances of all built levels by INSTANCE_BUDGET (pooled cars freed first).
func _check_instanzen() -> void:
	var p: Array[String] = []
	_probe.call("reset")
	var sc := _launch({"traffic_warmup": true, "start_speed_kmh": 130.0})
	var r := await _ready_stage(sc)
	var vl: Node = r.layer("vehicles")
	var budget := int((vl.get_script() as GDScript).get_script_constant_map().get("INSTANCE_BUDGET", 0))
	_need(p, budget > 0 and budget <= 200, "INSTANCE_BUDGET gesetzt und mit Platz für den Rest der Szene (%d)" % budget)
	var old_scale := Engine.time_scale
	Engine.time_scale = 4.0
	var worst := 0
	var checks := 0
	var mismatches: Array[String] = []
	for i in 900:
		await process_frame
		var pf: Dictionary = vl.call("perf")
		worst = maxi(worst, int(pf.get("vehicle_instances", 0)))
		if i % 100 == 99:
			checks += 1
			var counted := _level_instances(r)
			if counted != int(pf.get("vehicle_instances", -1)):
				mismatches.append("Bild %d: Zähler %d, Knoten %d" % [i + 1, int(pf.get("vehicle_instances", -1)), counted])
	Engine.time_scale = old_scale
	var pf_end: Dictionary = vl.call("perf")
	_need(p, worst <= budget, "höchstens %d Instanzen nach jedem Bild (%d)" % [budget, worst])
	_need(p, mismatches.is_empty(), "Zähler = Knoten unter den Autos (%s)" % "; ".join(mismatches.slice(0, 3)))
	_need(p, int(pf_end.get("vehicle_trims", 0)) > 0, "das Budget hat freigegeben (vehicle_trims %d)" % int(pf_end.get("vehicle_trims", 0)))
	_report("instanzen", p, "900 Bilder bei 4-facher Zeit: höchstens %d Instanzen der gebauten Stufen (Budget %d, %d Stichproben Zähler = Knoten), %d freigegeben, %d Bauten" % [
		worst, budget, checks, int(pf_end.get("vehicle_trims", 0)), int(pf_end.get("vehicle_builds", 0))])
	await _free(sc)


## Geometry instances under the car roots of the layer (active and pooled; what is queued for deletion is gone).
func _level_instances(r: ModernRenderer) -> int:
	var world: Variant = r.get("world")
	if not (world is Node3D):
		return -1
	var n := 0
	for c: Node in (world as Node3D).get_children():
		if not str(c.name).begins_with("car_") or c.is_queued_for_deletion():
			continue
		var stack: Array[Node] = [c]
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			if x.is_queued_for_deletion():
				continue
			if x is GeometryInstance3D:
				n += 1
			for k in x.get_children():
				stack.append(k)
	return n


'''
s = s[:i] + check + s[i:]
open(p, 'w').write(s)
print("ok")
