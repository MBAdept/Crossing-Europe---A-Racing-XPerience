class_name RoadPath3D
extends RefCounted
## Spike (v0.8.0 design study): true world-space centreline of a Track. Heading integrated from the curve value
## (curvature = curve / road.curve_radius_at_1_m), one boundary per segment start. World axes: +X right, +Y up,
## heading 0 looks along -Z (Godot camera convention); a positive curve turns right.
## Coordinates are kept as doubles relative to the first integrated boundary; node positions subtract an origin.

var track: Track
var seg_len := 3.0
var inv_r1 := 1.0 / 120.0
var first := 0                          ## segment index of the first integrated boundary
var px := PackedFloat64Array()          ## boundary positions (m, world x / z), heading (rad), road height
var pz := PackedFloat64Array()
var th := PackedFloat64Array()
var py := PackedFloat64Array()
var origin_x := 0.0                     ## floating origin (subtracted from every returned position)
var origin_z := 0.0


func setup(t: Track, start_index: int, curve_radius_at_1: float) -> void:
	track = t
	seg_len = t.seg_len
	inv_r1 = 1.0 / maxf(1.0, curve_radius_at_1)
	first = maxi(0, start_index)
	px.clear(); pz.clear(); th.clear(); py.clear()
	var s := track.get_segment(first)
	px.append(0.0); pz.append(0.0); th.append(0.0); py.append(s.y)


func last() -> int:
	return first + px.size() - 1


## Integrates boundaries up to segment index `index` (needs the segments first..index-1 from the track: call it
## while they are still inside the track window).
func ensure(index: int) -> void:
	index = mini(index, track.segment_count - 1)
	var n := px.size()
	var k := first + n - 1
	while k < index:
		var s := track.get_segment(k)
		var kap := s.curve * inv_r1
		var a: float = th[n - 1]
		var mid := a + kap * seg_len * 0.5
		px.append(px[n - 1] + sin(mid) * seg_len)
		pz.append(pz[n - 1] - cos(mid) * seg_len)
		th.append(a + kap * seg_len)
		py.append(track.get_segment(k + 1).y)
		n += 1
		k += 1


func has(index: int) -> bool:
	return index >= first and index <= last()


## Road centre at boundary k (origin-relative, with the road height).
func point(k: int) -> Vector3:
	var i := clampi(k - first, 0, px.size() - 1)
	return Vector3(px[i] - origin_x, py[i], pz[i] - origin_z)


func heading(k: int) -> float:
	return th[clampi(k - first, 0, px.size() - 1)]


static func right_of(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))


static func fwd_of(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, -cos(a))


## Road centre (with height) at track z, linear inside the segment.
func centre_at(z: float) -> Vector3:
	var f := z / seg_len
	var k := int(floor(f))
	var t := f - float(k)
	ensure(k + 1)
	return point(k).lerp(point(k + 1), t)


func heading_at(z: float) -> float:
	var f := z / seg_len
	var k := int(floor(f))
	var t := f - float(k)
	ensure(k + 1)
	return lerpf(heading(k), heading(k + 1), t)


## World point of road coordinates (z along the road, x lateral, h above the road).
func world(z: float, x: float, h: float) -> Vector3:
	var c := centre_at(z)
	return c + right_of(heading_at(z)) * x + Vector3(0.0, h, 0.0)
