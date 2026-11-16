import sys
p = sys.argv[1] + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''	var r := PILLAR_W * 0.5 + LOS_MARGIN
	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var grid: Dictionary = {}''',
'''	var r := PILLAR_W * 0.5 + LOS_MARGIN
	# only the boards behind the column, and only the cameras some of them need
	var rel: Array = []
	var lo := INF
	var hi := -INF
	for bd: Array in boards:
		var zs := float(bd[0])
		if zs <= z + 0.3 or zs > z + LOS_FAR or not p.has(tr.segment_index_at(zs) + 1):
			continue
		rel.append(bd)
		lo = minf(lo, zs - LOS_FAR)
		hi = maxf(hi, zs - LOS_NEAR)
	if rel.is_empty():
		return out
	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var grid: Dictionary = {}''')

rep('''	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if p.has(tr.segment_index_at(zc)):
			var at: Variant = grid.get(zc)''',
'''	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if zc >= lo and zc <= hi and p.has(tr.segment_index_at(zc)):
			var at: Variant = grid.get(zc)''')

rep('''	for bd: Array in boards:
		var zs := float(bd[0])
		if zs <= z + 0.3 or zs > z + LOS_FAR or not p.has(tr.segment_index_at(zs) + 1):
			continue
		var e0 := p.world(zs, float(bd[1]) - float(bd[2]), 0.0)''',
'''	for bd: Array in rel:
		var zs := float(bd[0])
		var e0 := p.world(zs, float(bd[1]) - float(bd[2]), 0.0)''')
open(p, 'w').write(s)
print('ok')
