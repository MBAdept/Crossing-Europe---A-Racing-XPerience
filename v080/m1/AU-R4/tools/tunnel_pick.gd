extends SceneTree
## AU-R4: which tunnel position in the "damm4" old town (800 m, stone bridge 160–300 m before the finish) pushes the
## city allocation out of its band – for a test where the feed must pass the tunnels of the plan.


func _initialize() -> void:
	var stones := [[160.0, 300.0]]
	var city := AudioFeed.cobbled_blocks("damm4", 800.0, 90.0, 0.6, [], stones)
	var pat := ""
	for b in 9:
		pat += "P" if bool(city[b]) else "-"
	print("city pattern ", pat)
	for a in range(330, 480, 10):
		for length in [150.0, 200.0, 250.0, 330.0]:
			var t := [[float(a), float(a) + length]]
			if float(a) + length > 800.0:
				continue
			var late := AudioFeed.cobbled_blocks("damm4", 800.0, 90.0, 0.6, [], stones, t)
			var h0 := _heard(city, t, stones)
			var h1 := _heard(late, t, stones)
			if absf(h0 - 0.6) > 0.05:
				print("tunnel %s: city %.3f out -> late %.3f" % [str(t), h0, h1])
	quit(0)


func _inside(a0: float, a1: float, spans: Array) -> float:
	var m := 0.0
	for s: Array in AudioFeed._merged_stretches(spans):
		m += maxf(minf(a1, float(s[1])) - maxf(a0, float(s[0])), 0.0)
	return m


func _heard(alloc: Dictionary, gaps: Array, stones: Array) -> float:
	var street := 0.0
	var stone := 0.0
	var cob := 0.0
	for b: int in alloc:
		var a0 := b * 90.0
		var a1 := minf(a0 + 90.0, 800.0)
		var gap := _inside(a0, a1, gaps)
		var st := _inside(a0, a1, stones + gaps) - gap
		var w := (a1 - a0) - gap - st
		street += w
		stone += st
		cob += w if bool(alloc[b]) else 0.0
	return (cob + stone) / (street + stone)
