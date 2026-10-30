extends Node
## Autoload "AudioManager": procedural sound (engine tied to speed with a virtual gearbox, wind,
## siren, crash, radar flash, fuel, countdown/UI blips, rain). Owner: UI/audio module.
## Public API = contract (ARCHITECTURE.md §Audio). STUB: silent.


## Engine sound: speed (km/h), throttle 0..1, current vmax, active = engine running.
func set_engine(_speed_kmh: float, _throttle: float, _vmax_kmh: float, _active: bool) -> void:
	pass


func set_wind(_speed_kmh: float) -> void:
	pass


## Police siren on/off; distance01 = 1 close … 0 far.
func set_siren(_on: bool, _distance01: float) -> void:
	pass


func set_rain(_intensity: float) -> void:
	pass


func set_skid(_amount01: float) -> void:
	pass


## One-shot effects: "crash", "flash", "go", "beep", "finish", "fuel_start", "fuel_done", "ui_move",
## "ui_ok", "ui_back".
func play(_name: String) -> void:
	pass


func stop_all() -> void:
	pass
