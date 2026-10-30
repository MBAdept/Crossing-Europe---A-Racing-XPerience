class_name TrackSegment
extends RefCounted
## One road segment (render.segment_length_m visual metres). Generated ahead of the player and
## discarded behind him by Track.

var index := 0
var z := 0.0              ## visual metres at the segment start
var km := 0.0             ## odometer km at the segment start
var curve := 0.0          ## -1..1, + = right bend (1 = road.curve_radius_at_1_m)
var y := 0.0              ## road height (m) at the segment start
var lanes := 3.0          ## effective lane count (fractional during transitions)
var lane_count := 3       ## lanes usable by traffic
var fuel_lane := 0.0      ## 0..1 width factor of the fuel lane on the right
var road := "autobahn"
var scenery := "north_plain"
var country := "DE"
var speed_limit := 0
var tunnel := false
var city := false
var guardrail := true
## Static props on this segment: {set: String, x: float (m from road centre), scale: float,
## kind: "prop"|"sign", sign: String, text: String, value: int, side: -1|1, lit: bool}
var sprites: Array[Dictionary] = []
