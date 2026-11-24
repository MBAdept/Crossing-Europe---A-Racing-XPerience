class_name ModernAudioFrame
extends RefCounted
## What ModernAudio hands to every slot once per frame (ModernAudioModule.update): the collected calls of the
## AudioManager API with their Arcade semantics already applied – values of calls made while the tree is paused or
## in the frame of stop_all() are ignored, a race session that stopped calling counts as gone after
## ModernAudio.ALIVE_S – plus what the AudioFeed derived from the track. One object, reused every frame.

var dt := 0.0
var time := 0.0                 ## seconds since the profile started (runs while paused)
var paused := false             ## the tree is paused (pause menu): loops and the engine fade out
var live := false               ## players exist (false: headless, unit tests)

# set_engine(): the player's car
var alive := false              ## the session drove the car within ALIVE_S and the tree is not paused
var speed := 0.0                ## km/h
var throttle := 0.0             ## 0..1
var vmax := 250.0               ## km/h
var active := false             ## the engine drives the car (false: rolling out after the finish, …)

var wind_speed := 0.0           ## km/h, set_wind()
var rain := 0.0                 ## 0..1: set_rain() of the last second, else the HUD hint
var skid := 0.0                 ## 0..1: set_skid() of the last second, else the HUD hint
var siren_on := false           ## set_siren() / HUD hints: a chase is on
var siren_level := 0.0          ## 0..1 centred level as in Arcade (0.18 far … 0.8 close; 0 = off)

# set_traffic()
var traffic_alive := false
var vehicles: Array = []        ## [{id, set, z (rear), x, length, speed (km/h), heavy?}], police car id −2
var listener: Dictionary = {}   ## chase camera {z, x, speed}

var tunnel := false             ## set_environment(): the camera is in a tunnel

# set_vehicle_state() (contract §4.7.2); empty while the session does not send it
var has_state := false
var state: Dictionary = {}
## Derived from the track at the car (AudioFeed): surfaces per side, zone, tunnel, bridge, …
var feed: AudioFeed = null
## engine_state() of the engine slot in this frame: {rpm, gear (0 = neutral), load 0..1, boost 0..1}
var engine: Dictionary = {}
## The effects are muted (volume 0, attract demo): nothing has to sound
var effects_muted := false
## Music context as set by the game ("title", "menu", "race_menu", "race", "result", "off")
var music_context := "off"


## A value of the vehicle state with a default (the session may not send it yet).
func st(key: String, default: Variant = 0.0) -> Variant:
	return state.get(key, default)
