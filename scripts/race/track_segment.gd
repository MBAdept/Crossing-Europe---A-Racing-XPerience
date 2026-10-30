class_name TrackSegment
extends RefCounted
## One road segment (render.segment_length_m visual metres). Generated ahead of the player and
## discarded behind him by Track.

const FUEL_ISLAND := 1        ## pump island beside the fuel lane
const FUEL_CANOPY := 2        ## canopy roof over the pump island (and half the fuel lane)
const FUEL_CANOPY_FRONT := 4  ## a canopy starts at the near edge of this segment

var index := 0
var z := 0.0              ## visual metres at the segment start
var km := 0.0             ## odometer km at the segment start
var curve := 0.0          ## -1..1, + = right bend (1 = road.curve_radius_at_1_m)
var y := 0.0              ## road height (m, visual) at the segment start
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
var runout := false       ## behind the finish line
var fuel_zone := 0        ## FUEL_* bit flags (fuel station structures beside the fuel lane)
var cover := ""           ## "" or "border": canopy of a border control station over the road
var cover_front := false  ## the cover starts at the near edge of this segment
var country_to := ""      ## for border covers: country entered
## Static props on this segment: {kind: "prop"|"sign"|"object", set: String, x: float (m from road
## centre), scale: float, side: -1|0|1, sign: String, text: String, value: int, obj: String,
## proc: String (procedural fallback when the sprite set is missing), fallback: String (other set)}
var sprites: Array[Dictionary] = []
