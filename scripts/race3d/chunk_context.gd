class_name ChunkContext
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): everything a chunk builder may know about one chunk of road
## (chunk_segments segments = 96 m), snapshotted on the main thread so that ChunkBuilder.build() can run on a
## worker thread.
##
## Rows: the chunk has rows seg_a .. seg_b (33 boundaries); row i is the start of segment seg_a + i. The last row is
## the first row of the next chunk – its segs entry is only the far edge (the sprites of that segment belong to the
## next chunk). Chunk-local coordinates are relative to the road centre of row 0 (rows_o[0] = 0); the streamer puts
## the chunk node there and owns its transform.
##
## The three builder rules (they keep the fallback mapping of the contract possible):
##  1. every position comes from local() / frame() / ground() (or, on the main thread, from the RoadPath3D),
##  2. never assume the transform of a chunk node is static, never cache world positions,
##  3. rigid instances (props, signs, structures) are placed with frame().
## local(), frame(), ground() and the other helpers below interpolate the snapshot arrays only – they are safe on a
## worker thread. path, terrain, track and services are MAIN THREAD ONLY (collect / commit).
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

## Every TrackSegment field that is copied into segs (tests/unit/race3d/test_chunk_streamer.gd checks the list
## against the class).
const SEG_FIELDS: Array[String] = ["index", "z", "km", "curve", "y", "lanes", "lane_count", "fuel_lane", "road", "scenery",
	"country", "speed_limit", "tunnel", "city", "guardrail", "runout", "fuel_zone", "cover", "cover_front", "country_to",
	"bridge", "bridge_i", "water", "water_depth", "water_level", "bank", "sprites"]

var index := 0                          ## chunk index (seg_a / chunk_segments)
var seg_a := 0
var seg_b := 0
var segs: Array[Dictionary] = []        ## snapshot of every TrackSegment field incl. a deep copy of `sprites`
var rows_o := PackedVector3Array()      ## road centre per row, chunk-local
var rows_r := PackedVector3Array()      ## unit right vector per row
var rows_f := PackedVector3Array()      ## unit forward vector per row
var rows_heading := PackedFloat64Array()  ## road heading per row (rad, RoadPath3D convention)
var rows_edge := PackedVector2Array()   ## paved road edges per row (left, right incl. fuel lane), m from the centre
var floor_y := PackedFloat32Array()     ## valley floor per row, chunk-local y
var rings := 0                          ## terrain rings per side
var ring_x := PackedFloat32Array()      ## terrain ring distances beyond the shoulder per row and side
var ring_h := PackedFloat32Array()      ## terrain heights at those rings, relative to the road of the row
var corridor := PackedVector2Array()    ## sight corridor beyond the shoulder per row (left, right), fairness rule F7
var corridor_min := 5.5                 ## its width away from bends (TerrainProfile.corridor_min_m - shoulder)
var origin := Vector3.ZERO              ## origin-relative position of row 0 when the snapshot was taken
var seg_len := 3.0
var lane_w := 3.75
var shoulder_w := 2.5
var length_z := 0.0                     ## road position of the finish line (Track.length_z)
var path: RoadPath3D                    ## MAIN THREAD ONLY
var terrain: TerrainProfile             ## MAIN THREAD ONLY
var track: Track                        ## MAIN THREAD ONLY
## What the renderer hands to the builders (ChunkStreamer.services): {"renderer": ModernRenderer, "materials":
## ModernMaterials}. MAIN THREAD ONLY (collect / commit). {} in tests without a renderer – a builder must work
## without it (materials through ModernMaterials.shared(), no lamp registration).
var services: Dictionary = {}
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var levels: Dictionary = {}
var sync := false


## Takes the snapshot of the rows a..b (main thread). The path must reach row b and the track must still hold the
## segments (ChunkStreamer checks both).
func capture(chunk_index: int, a: int, b: int, p: RoadPath3D, t: TerrainProfile, tr: Track) -> void:
	index = chunk_index
	seg_a = a
	seg_b = b
	path = p
	terrain = t
	track = tr
	seg_len = tr.seg_len
	lane_w = tr.lane_w
	shoulder_w = tr.shoulder_w
	length_z = tr.length_z
	var rl := p.rows_local(a, b)
	origin = rl["origin"]
	rows_o = rl["o"]
	rows_r = rl["r"]
	rows_f = rl["f"]
	rows_heading = rl["heading"]
	var count := b - a + 1
	segs.clear()
	rows_edge.resize(count)
	for q in count:
		var s := tr.get_segment(a + q)
		segs.append(seg_snapshot(s))
		var half := s.lanes * lane_w * 0.5
		rows_edge[q] = Vector2(-half, half + s.fuel_lane * lane_w)
	var tp := t.rows(a, b)
	rings = int(tp["rings"])
	ring_x = tp["x"]
	ring_h = tp["h"]
	corridor = tp["corridor"]
	corridor_min = maxf(0.0, t.corridor_min_m - shoulder_w)
	var floors: PackedFloat64Array = tp["floor"]
	floor_y.resize(count)
	for q in count:
		floor_y[q] = floors[q] - origin.y


## Plain copy of a TrackSegment (deep copy of its sprites).
static func seg_snapshot(s: TrackSegment) -> Dictionary:
	return {"index": s.index, "z": s.z, "km": s.km, "curve": s.curve, "y": s.y, "lanes": s.lanes, "lane_count": s.lane_count,
		"fuel_lane": s.fuel_lane, "road": s.road, "scenery": s.scenery, "country": s.country, "speed_limit": s.speed_limit,
		"tunnel": s.tunnel, "city": s.city, "guardrail": s.guardrail, "runout": s.runout, "fuel_zone": s.fuel_zone,
		"cover": s.cover, "cover_front": s.cover_front, "country_to": s.country_to, "bridge": s.bridge, "bridge_i": s.bridge_i,
		"water": s.water, "water_depth": s.water_depth, "water_level": s.water_level, "bank": s.bank,
		"sprites": s.sprites.duplicate(true)}


## Number of rows (segments + 1).
func row_count() -> int:
	return rows_o.size()


## Road position z as a fractional row (0 = row 0).
func row_of(z: float) -> float:
	return z / seg_len - float(seg_a)


## Road coordinates (z along the road in visible metres, x lateral + right, h above the road) -> chunk-local.
## Bilinear between the two rows, like RoadPath3D.world(); positions a little outside the chunk are extrapolated.
func local(z: float, x: float, h: float) -> Vector3:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := f - float(i)
	return rows_o[i].lerp(rows_o[i + 1], t) + rows_r[i].lerp(rows_r[i + 1], t) * x + Vector3(0.0, h, 0.0)


## Road heading (rad) at road position z.
func heading(z: float) -> float:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	return lerpf(rows_heading[i], rows_heading[i + 1], f - float(i))


## Rigid chunk-local frame at road coordinates: +X right, +Y up, -Z = road forward at z, turned by yaw_rad
## (+ = to the right, like a road heading). Yaw only – props stand upright.
func frame(z: float, x: float, h: float, yaw_rad: float = 0.0) -> Transform3D:
	var a := heading(z) + yaw_rad
	return Transform3D(Basis(RoadPath3D.right_of(a), Vector3.UP, -RoadPath3D.fwd_of(a)), local(z, x, h))


## Height of the ground at road coordinates (z, x) relative to the road at z – the value to pass as h to local() /
## frame(): 0 on the road and its shoulders, the terrain ribbon beside them, the valley floor beyond the ribbon.
func ground(z: float, x: float) -> float:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	return lerpf(_ground_row(i, x), _ground_row(i + 1, x), t)


func _ground_row(i: int, x: float) -> float:
	var e := rows_edge[i]
	var si := 0 if x < 0.0 else 1
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	if m <= 0.0 or rings <= 0:
		return 0.0
	var o := (i * 2 + si) * rings
	return TerrainProfile.interp(ring_x, o, ring_h, o, rings, m)


## Outer shoulder edge of a row: metres from the centreline (positive on both sides); side -1 left, +1 right.
func shoulder_edge(row: int, side: int) -> float:
	var e := rows_edge[clampi(row, 0, rows_edge.size() - 1)]
	return (-e.x if side < 0 else e.y) + shoulder_w


## Distance of terrain ring `ring` of a row beyond the shoulder (side -1 left, +1 right).
func ring_offset(row: int, side: int, ring: int) -> float:
	return ring_x[(row * 2 + (0 if side < 0 else 1)) * rings + ring]


## Height of that ring relative to the road of the row.
func ring_height(row: int, side: int, ring: int) -> float:
	return ring_h[(row * 2 + (0 if side < 0 else 1)) * rings + ring]


## Width of the terrain ribbon beyond the shoulder at road position z (the distance of the last ring).
func ribbon_width(z: float, side: int) -> float:
	if rings <= 0:
		return 0.0
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if side < 0 else 1
	return lerpf(ring_x[(i * 2 + si) * rings + rings - 1], ring_x[((i + 1) * 2 + si) * rings + rings - 1], t)


## True when road coordinates (z, x) lie inside the sight corridor (fairness rule F7: no ground above the road) or
## on the road itself.
func in_corridor(z: float, x: float) -> bool:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := rows_edge[i].lerp(rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	var c := corridor[i].lerp(corridor[i + 1], t)
	return m <= (c.x if si == 0 else c.y)


## True when (z, x) lies inside the sight corridor of a bend, on its inside – where fairness rule F7 allows no
## decorative vegetation (the props builder leaves such props out). Away from bends the corridor is only the
## corridor_min strip beside the road, and that strip does not count here.
func in_bend_corridor(z: float, x: float) -> bool:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := rows_edge[i].lerp(rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	var c := corridor[i].lerp(corridor[i + 1], t)
	var cw := c.x if si == 0 else c.y
	return cw > corridor_min + 0.5 and m > 0.0 and m <= cw
